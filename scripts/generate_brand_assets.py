#!/usr/bin/env python3
"""Generate Beacon brand assets from the master app icon and transparent emblem."""

from __future__ import annotations

import math
import os
from pathlib import Path
from typing import Iterable, Tuple

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
APP_ICON_MASTER = ROOT / "docs" / "assets" / "beacon-app-icon-master.png"
EMBLEM = ROOT / "docs" / "assets" / "beacon-emblem.png"

DARK = (3, 4, 3)
DARK_2 = (10, 8, 3)
AMBER = (255, 216, 77)
AMBER_DEEP = (217, 65, 20)
CYAN = (125, 215, 255)


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def cover_square(img: Image.Image, size: int) -> Image.Image:
    img = img.convert("RGBA")
    side = min(img.size)
    left = (img.width - side) // 2
    top = (img.height - side) // 2
    img = img.crop((left, top, left + side, top + side))
    return img.resize((size, size), Image.Resampling.LANCZOS)


def save_png(img: Image.Image, path: Path) -> None:
    ensure_parent(path)
    img.save(path, "PNG", optimize=True)


def rounded_mask(size: int, radius_ratio: float = 0.225) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    radius = int(size * radius_ratio)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def circular_mask(size: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    inset = max(1, int(size * 0.015))
    draw.ellipse((inset, inset, size - inset - 1, size - inset - 1), fill=255)
    return mask


def mask_alpha(img: Image.Image, mask: Image.Image) -> Image.Image:
    out = img.convert("RGBA")
    alpha = out.getchannel("A")
    out.putalpha(Image.composite(alpha, Image.new("L", out.size, 0), mask))
    return out


def favicon_source(icon: Image.Image, size: int) -> Image.Image:
    # Favicons get a little extra contrast because they collapse to tiny sizes.
    out = cover_square(icon, size).convert("RGBA")
    return out


def centered_emblem(size: Tuple[int, int], scale: float = 0.42) -> Image.Image:
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    emblem = Image.open(EMBLEM).convert("RGBA")
    bbox = emblem.getbbox()
    if bbox:
        emblem = emblem.crop(bbox)
    target_h = int(min(size) * scale)
    ratio = target_h / emblem.height
    target_w = int(emblem.width * ratio)
    emblem = emblem.resize((target_w, target_h), Image.Resampling.LANCZOS)
    x = (size[0] - target_w) // 2
    y = int(size[1] * 0.48 - target_h / 2)
    canvas.alpha_composite(emblem, (x, y))
    return canvas


def radial_gradient(size: Tuple[int, int], center: Tuple[float, float], radius: float, color: Tuple[int, int, int], opacity: float) -> Image.Image:
    w, h = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    px = layer.load()
    cx, cy = center
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - cx, y - cy) / radius
            a = max(0.0, 1.0 - d) ** 2
            if a <= 0:
                continue
            px[x, y] = (*color, int(255 * opacity * a))
    return layer


def topo_lines(size: Tuple[int, int]) -> Image.Image:
    w, h = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx, cy = w / 2, h * 0.42
    step = max(18, min(w, h) // 18)
    for r in range(step, int(max(w, h) * 0.9), step):
        alpha = int(34 * max(0.25, 1 - r / (max(w, h) * 0.9)))
        bbox = (cx - r * 0.72, cy - r, cx + r * 0.72, cy + r)
        draw.ellipse(bbox, outline=(*AMBER, alpha), width=max(1, min(w, h) // 900))
    return layer.filter(ImageFilter.GaussianBlur(radius=max(0.25, min(w, h) / 1800)))


def splash(size: Tuple[int, int]) -> Image.Image:
    w, h = size
    base = Image.new("RGBA", size, (*DARK, 255))
    # Vertical rescue-black background with a warm center glow.
    for y in range(h):
        t = y / max(1, h - 1)
        r = int(DARK[0] * (1 - t) + DARK_2[0] * t)
        g = int(DARK[1] * (1 - t) + DARK_2[1] * t)
        b = int(DARK[2] * (1 - t) + DARK_2[2] * t)
        ImageDraw.Draw(base).line([(0, y), (w, y)], fill=(r, g, b, 255))
    base.alpha_composite(radial_gradient(size, (w * 0.5, h * 0.43), min(w, h) * 0.45, AMBER, 0.42))
    base.alpha_composite(radial_gradient(size, (w * 0.62, h * 0.38), min(w, h) * 0.22, CYAN, 0.10))
    base.alpha_composite(topo_lines(size))
    glow = centered_emblem(size, scale=0.38)
    glow_alpha = glow.getchannel("A").filter(ImageFilter.GaussianBlur(radius=max(10, min(w, h) // 70)))
    glow_layer = Image.new("RGBA", size, (*AMBER, 0))
    glow_layer.putalpha(glow_alpha.point(lambda p: int(p * 0.38)))
    base.alpha_composite(glow_layer)
    base.alpha_composite(glow)
    return base.convert("RGB")


def save_ico(icon: Image.Image, path: Path) -> None:
    ensure_parent(path)
    source = cover_square(icon, 256)
    source.save(path, format="ICO", sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])


def main() -> None:
    if not APP_ICON_MASTER.exists():
        raise SystemExit(f"Missing {APP_ICON_MASTER}")
    if not EMBLEM.exists():
        raise SystemExit(f"Missing {EMBLEM}")

    icon = Image.open(APP_ICON_MASTER).convert("RGBA")
    icon1024 = cover_square(icon, 1024).convert("RGB")
    save_png(icon1024, ROOT / "beacon-logo.png")
    save_png(icon1024, ROOT / "ios" / "App" / "App" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon-512@2x.png")

    for path, size in [
        (ROOT / "docs" / "assets" / "beacon-icon.png", 192),
        (ROOT / "public" / "icon-192.png", 192),
        (ROOT / "public" / "icon-512.png", 512),
        (ROOT / "public" / "apple-touch-icon.png", 180),
        (ROOT / "public" / "favicon.png", 512),
        (ROOT / "public" / "favicon-16x16.png", 16),
        (ROOT / "public" / "favicon-32x32.png", 32),
    ]:
        save_png(cover_square(icon, size), path)
    save_ico(icon, ROOT / "public" / "favicon.ico")

    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    emblem = Image.open(EMBLEM).convert("RGBA")
    bbox = emblem.getbbox()
    emblem = emblem.crop(bbox) if bbox else emblem
    for folder, size in android_sizes.items():
        base = cover_square(icon, size)
        res = ROOT / "android" / "app" / "src" / "main" / "res" / folder
        save_png(base, res / "ic_launcher.png")
        save_png(mask_alpha(base, circular_mask(size)), res / "ic_launcher_round.png")

        fg_canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        target_h = int(size * 0.83)
        ratio = target_h / emblem.height
        fg = emblem.resize((int(emblem.width * ratio), target_h), Image.Resampling.LANCZOS)
        fg_canvas.alpha_composite(fg, ((size - fg.width) // 2, int(size * 0.49 - fg.height / 2)))
        save_png(fg_canvas, res / "ic_launcher_foreground.png")

    # Capacitor/iOS splash keeps one universal image for each scale entry.
    for name in ["splash-2732x2732.png", "splash-2732x2732-1.png", "splash-2732x2732-2.png"]:
        save_png(splash((2732, 2732)), ROOT / "ios" / "App" / "App" / "Assets.xcassets" / "Splash.imageset" / name)

    android_splashes = {
        "drawable-port-mdpi": (320, 480),
        "drawable-port-hdpi": (480, 800),
        "drawable-port-xhdpi": (720, 1280),
        "drawable-port-xxhdpi": (960, 1600),
        "drawable-port-xxxhdpi": (1280, 1920),
        "drawable-land-mdpi": (480, 320),
        "drawable-land-hdpi": (720, 480),
        "drawable-land-xhdpi": (960, 640),
        "drawable-land-xxhdpi": (1440, 960),
        "drawable-land-xxxhdpi": (1920, 1280),
        "drawable-nodpi": (480, 320),
    }
    for folder, size in android_splashes.items():
        save_png(splash(size), ROOT / "android" / "app" / "src" / "main" / "res" / folder / "splash.png")

    print("Generated Beacon brand assets from:")
    print(f"  {APP_ICON_MASTER}")
    print(f"  {EMBLEM}")


if __name__ == "__main__":
    main()
