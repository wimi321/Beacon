#!/usr/bin/env python3
"""Generate a premium social preview image (1280x640) for the Beacon GitHub repo."""

from __future__ import annotations

import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "assets" / "beacon-social-preview.png"
PUBLIC_OUT = ROOT / "public" / "social-preview.png"
ICON = ROOT / "docs" / "assets" / "beacon-icon.png"
PHONE = ROOT / "docs" / "assets" / "beacon-home-android-en.png"

W, H = 1280, 640
BG = (3, 4, 3)
WHITE = (248, 247, 240)
MUTED = (178, 178, 168)
AMBER = (255, 216, 77)
AMBER_DEEP = (217, 65, 65)
CYAN = (125, 215, 255)
PANEL = (7, 10, 9)


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/SF-Pro-Display-Bold.otf" if bold else "/System/Library/Fonts/SF-Pro-Display-Regular.otf",
        "/System/Library/Fonts/SFCompact.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for path in candidates:
        if path and Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                pass
    return ImageFont.load_default()


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def add_glow(base: Image.Image, center, radius, color, opacity):
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    px = overlay.load()
    cx, cy = center
    for y in range(base.height):
        for x in range(base.width):
            d = math.hypot(x - cx, y - cy) / radius
            if d < 1:
                a = int(255 * opacity * ((1 - d) ** 2))
                if a:
                    px[x, y] = (*color, a)
    base.alpha_composite(overlay)


def draw_topo(draw: ImageDraw.ImageDraw):
    cx, cy = 660, 280
    for r in range(60, 900, 46):
        alpha = int(32 * max(0.16, 1 - r / 900))
        bbox = (cx - r * 1.28, cy - r * 0.72, cx + r * 1.28, cy + r * 0.72)
        draw.ellipse(bbox, outline=(*AMBER, alpha), width=1)


def draw_text(draw: ImageDraw.ImageDraw, xy, text, fnt, fill):
    draw.text(xy, text, font=fnt, fill=fill)


def pill(draw: ImageDraw.ImageDraw, x, y, text, accent=None):
    f = font(22, bold=True)
    bbox = draw.textbbox((0, 0), text, font=f)
    w = bbox[2] - bbox[0] + 34
    h = 42
    draw.rounded_rectangle((x, y, x + w, y + h), radius=21, fill=(9, 14, 14), outline=(47, 54, 48), width=1)
    if accent:
        draw.ellipse((x + 14, y + 15, x + 24, y + 25), fill=accent)
        tx = x + 32
    else:
        tx = x + 17
    draw.text((tx, y + 9), text, font=f, fill=WHITE)
    return x + w + 16


def paste_phone(base: Image.Image):
    if not PHONE.exists():
        return
    phone = Image.open(PHONE).convert("RGBA")
    target_h = 574
    target_w = int(phone.width * target_h / phone.height)
    phone = phone.resize((target_w, target_h), Image.Resampling.LANCZOS)
    frame_w, frame_h = target_w + 30, target_h + 30
    frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle((0, 0, frame_w - 1, frame_h - 1), radius=42, fill=(4, 5, 5, 255), outline=(67, 70, 62, 255), width=2)
    d.rounded_rectangle((10, 10, frame_w - 11, frame_h - 11), radius=34, fill=(0, 0, 0, 255))
    mask = rounded_mask(phone.size, 27)
    frame.alpha_composite(Image.composite(phone, Image.new("RGBA", phone.size, (0, 0, 0, 0)), mask), (15, 15))
    shadow = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    shadow.putalpha(rounded_mask(frame.size, 42).filter(ImageFilter.GaussianBlur(26)).point(lambda p: int(p * 0.48)))
    base.alpha_composite(shadow, (894, 17))
    base.alpha_composite(frame, (892, 16))


def main():
    img = Image.new("RGBA", (W, H), (*BG, 255))
    add_glow(img, (300, 240), 430, AMBER, 0.23)
    add_glow(img, (1060, 180), 280, CYAN, 0.08)
    d = ImageDraw.Draw(img, "RGBA")
    draw_topo(d)

    d.rounded_rectangle((56, 54, 838, 226), radius=26, fill=(*PANEL, 226), outline=(242, 242, 220, 110), width=2)
    icon = Image.open(ICON).convert("RGBA").resize((116, 116), Image.Resampling.LANCZOS)
    img.alpha_composite(icon, (82, 82))

    draw_text(d, (224, 78), "Beacon", font(58, bold=True), WHITE)
    draw_text(d, (226, 142), "Offline survival AI for no-signal moments", font(29), WHITE)
    draw_text(d, (226, 182), "On-device Gemma 4. Offline knowledge. 20 languages.", font(21), MUTED)

    d.rounded_rectangle((76, 264, 760, 424), radius=24, fill=(4, 8, 9, 232))
    d.rounded_rectangle((76, 264, 88, 424), radius=6, fill=(*AMBER, 255))
    draw_text(d, (112, 292), "Real local guidance", font(40, bold=True), WHITE)
    draw_text(d, (112, 346), "Built for panic: tap, ask, scan, survive.", font(25), WHITE)
    draw_text(d, (112, 384), "No cloud dependency on the critical path.", font(23), MUTED)

    x = 76
    x = pill(d, x, 496, "ANDROID APK", AMBER_DEEP)
    x = pill(d, x, 496, "20 LANGUAGES", CYAN)
    x = pill(d, x, 496, "OFFLINE FIRST", AMBER)

    paste_phone(img)

    d.rectangle((0, 0, W - 1, H - 1), outline=(45, 49, 42, 255), width=1)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    rgb = img.convert("RGB")
    rgb.save(OUT, "PNG", optimize=True)
    PUBLIC_OUT.parent.mkdir(parents=True, exist_ok=True)
    rgb.save(PUBLIC_OUT, "PNG", optimize=True)
    print(f"Created social preview: {OUT}")
    print(f"Created web social preview: {PUBLIC_OUT}")
    print(f"Size: {OUT.stat().st_size} bytes")


if __name__ == "__main__":
    main()
