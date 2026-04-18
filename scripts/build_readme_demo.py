#!/usr/bin/env python3

from __future__ import annotations

import argparse
import math
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


ROOT_DIR = Path(__file__).resolve().parent.parent
DEFAULT_INPUT_IMAGE = ROOT_DIR / "docs/assets/beacon-home-android-en.png"
DEFAULT_FRAMES_DIR = ROOT_DIR / "docs/assets/.readme-demo-frames"
DEFAULT_OUTPUT_MP4 = ROOT_DIR / "docs/assets/beacon-demo-hero.mp4"
DEFAULT_OUTPUT_GIF = ROOT_DIR / "docs/assets/beacon-demo-hero.gif"
DEFAULT_OUTPUT_POSTER = ROOT_DIR / "docs/assets/beacon-demo-hero-poster.png"
FONT_BOLD = "/System/Library/Fonts/Supplemental/Verdana Bold.ttf"
FONT_REG = "/System/Library/Fonts/Supplemental/Verdana.ttf"

WIDTH = 1280
HEIGHT = 720
FPS = 20
DURATION_SECONDS = 8
FRAME_COUNT = FPS * DURATION_SECONDS
PHONE_WIDTH = 302
PHONE_X = 912
PHONE_Y = 22
PHONE_FRAME_PADDING = 16
HEADER_BOX = (56, 52, 808, 204)
HEADER_TITLE_Y = 76
HEADER_HEADLINE_Y = 126
HEADER_CAPTION_Y = 168


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def ease_in_out(progress: float) -> float:
    return 0.5 - 0.5 * math.cos(progress * math.pi)


def scene_progress(t: float, start: float, end: float) -> float:
    if t <= start:
        return 0.0
    if t >= end:
        return 1.0
    return ease_in_out((t - start) / (end - start))


def rounded_box(draw: ImageDraw.ImageDraw, xy, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def draw_text_block(draw: ImageDraw.ImageDraw, text: str, font, xy, fill):
    draw.text(xy, text, font=font, fill=fill)


def build_background(source: Image.Image, t: float) -> Image.Image:
    bg = source.resize((WIDTH, int(source.height * WIDTH / source.width)), Image.Resampling.LANCZOS)
    max_y = bg.height - HEIGHT
    y = int(clamp((max_y / 2) + 140 * math.sin(t * 0.55), 0, max_y))
    bg = bg.crop((0, y, WIDTH, y + HEIGHT))
    bg = bg.filter(ImageFilter.GaussianBlur(18))
    bg = ImageEnhance.Brightness(bg).enhance(0.68)
    bg = ImageEnhance.Color(bg).enhance(1.08)
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (8, 12, 18, 92))
    return Image.alpha_composite(bg.convert("RGBA"), overlay)


def build_phone(source: Image.Image) -> Image.Image:
    phone_height = int(source.height * PHONE_WIDTH / source.width)
    phone = source.resize((PHONE_WIDTH, phone_height), Image.Resampling.LANCZOS).convert("RGBA")
    mask = Image.new("L", phone.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle((0, 0, phone.width, phone.height), radius=34, fill=255)
    rounded_phone = Image.new("RGBA", phone.size, (0, 0, 0, 0))
    rounded_phone.paste(phone, (0, 0), mask)
    return rounded_phone


def build_frame(source: Image.Image, phone: Image.Image, fonts: dict[str, ImageFont.FreeTypeFont], index: int) -> Image.Image:
    t = index / FPS
    frame = build_background(source, t)

    shadow = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow, "RGBA")
    phone_frame_left = PHONE_X - PHONE_FRAME_PADDING
    phone_frame_top = 16
    phone_frame_right = PHONE_X + phone.width + PHONE_FRAME_PADDING
    phone_frame_bottom = 704
    rounded_box(
        shadow_draw,
        (phone_frame_left, phone_frame_top, phone_frame_right, phone_frame_bottom),
        28,
        (0, 0, 0, 62),
        outline=(255, 255, 255, 28),
        width=2,
    )
    frame = Image.alpha_composite(frame, shadow)
    frame.alpha_composite(phone, (PHONE_X, PHONE_Y))
    draw = ImageDraw.Draw(frame, "RGBA")

    rounded_box(draw, HEADER_BOX, 22, (8, 12, 18, 120), outline=(255, 255, 255, 24), width=2)
    draw_text_block(draw, "Beacon", fonts["title"], (76, HEADER_TITLE_Y), (255, 255, 255, 255))
    draw_text_block(draw, "Offline-first emergency survival guidance", fonts["headline"], (76, HEADER_HEADLINE_Y), (255, 255, 255, 255))
    draw_text_block(
        draw,
        "Real on-device Gemma 4 + multilingual UX + offline knowledge",
        fonts["caption"],
        (76, HEADER_CAPTION_Y),
        (235, 241, 248, 220),
    )

    cards = [
        {
            "start": 0.0,
            "end": 2.67,
            "accent": (245, 158, 11, 242),
            "title": "Real on-device Gemma 4",
            "line1": "No cloud dependency on the critical path.",
            "line2": "Built for no-signal, low-battery, high-stress scenarios.",
        },
        {
            "start": 2.67,
            "end": 5.34,
            "accent": (37, 99, 235, 242),
            "title": "20 UI languages + Arabic RTL",
            "line1": "Manual language switch is always visible in the UI.",
            "line2": "English, Chinese, Japanese, Korean, Arabic, Spanish and more.",
        },
        {
            "start": 5.34,
            "end": 8.0,
            "accent": (22, 163, 74, 242),
            "title": "Offline knowledge + native mobile hooks",
            "line1": "Camera, battery, geolocation, SOS packaging, and safe reset.",
            "line2": "Bundled emergency and survival sources keep grounding local.",
        },
    ]

    for card in cards:
        if not (card["start"] <= t <= card["end"]):
            continue
        fade_window = 0.22
        alpha = 1.0
        if t < card["start"] + fade_window:
            alpha = (t - card["start"]) / fade_window
        elif t > card["end"] - fade_window:
            alpha = (card["end"] - t) / fade_window
        alpha = clamp(alpha, 0.0, 1.0)

        card_fill = (8, 12, 18, int(160 * alpha))
        accent_fill = (*card["accent"][:3], int(242 * alpha))
        rounded_box(draw, (76, 248, 704, 424), 24, card_fill)
        draw.rounded_rectangle((76, 248, 86, 424), radius=12, fill=accent_fill)
        draw_text_block(draw, card["title"], fonts["card_title"], (104, 274), (255, 255, 255, int(255 * alpha)))
        draw_text_block(draw, card["line1"], fonts["card_body"], (104, 321), (244, 247, 252, int(235 * alpha)))
        draw_text_block(draw, card["line2"], fonts["card_small"], (104, 358), (222, 228, 236, int(210 * alpha)))

    badges = [
        ("ANDROID + IOS", 76, 616, 246),
        ("20 LANGUAGES", 262, 616, 438),
        ("OFFLINE FIRST", 454, 616, 622),
    ]
    for label, left, top, right in badges:
        rounded_box(draw, (left, top, right, top + 44), 18, (8, 12, 18, 100))
        draw_text_block(draw, label, fonts["badge"], (left + 22, top + 12), (255, 255, 255, 255))

    return frame


def ensure_clean_dir(path: Path):
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def run_ffmpeg(*args: str):
    subprocess.run(["ffmpeg", "-y", *args], check=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build README demo hero assets from a mobile screenshot.")
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT_IMAGE, help="Input mobile screenshot path.")
    parser.add_argument("--frames-dir", type=Path, default=DEFAULT_FRAMES_DIR, help="Temporary frames directory.")
    parser.add_argument("--mp4", type=Path, default=DEFAULT_OUTPUT_MP4, help="Output MP4 path.")
    parser.add_argument("--gif", type=Path, default=DEFAULT_OUTPUT_GIF, help="Output GIF path.")
    parser.add_argument("--poster", type=Path, default=DEFAULT_OUTPUT_POSTER, help="Output poster PNG path.")
    return parser.parse_args()


def main():
    args = parse_args()
    input_image = args.input.resolve()
    frames_dir = args.frames_dir.resolve()
    output_mp4 = args.mp4.resolve()
    output_gif = args.gif.resolve()
    output_poster = args.poster.resolve()

    if not input_image.exists():
        raise SystemExit(f"Missing input screenshot: {input_image}")

    output_mp4.parent.mkdir(parents=True, exist_ok=True)
    output_gif.parent.mkdir(parents=True, exist_ok=True)
    output_poster.parent.mkdir(parents=True, exist_ok=True)

    ensure_clean_dir(frames_dir)
    source = Image.open(input_image).convert("RGB")
    phone = build_phone(source)
    fonts = {
        "title": ImageFont.truetype(FONT_BOLD, 46),
        "headline": ImageFont.truetype(FONT_REG, 28),
        "caption": ImageFont.truetype(FONT_REG, 18),
        "card_title": ImageFont.truetype(FONT_BOLD, 32),
        "card_body": ImageFont.truetype(FONT_REG, 22),
        "card_small": ImageFont.truetype(FONT_REG, 18),
        "badge": ImageFont.truetype(FONT_BOLD, 18),
    }

    for index in range(FRAME_COUNT):
        frame = build_frame(source, phone, fonts, index)
        frame.save(frames_dir / f"frame-{index:04d}.png", optimize=True)

    run_ffmpeg(
        "-framerate",
        str(FPS),
        "-i",
        str(frames_dir / "frame-%04d.png"),
        "-an",
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        "-movflags",
        "+faststart",
        str(output_mp4),
    )

    run_ffmpeg(
        "-i",
        str(output_mp4),
        "-vf",
        "fps=12,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=sierra2_4a",
        str(output_gif),
    )

    run_ffmpeg(
        "-i",
        str(output_mp4),
        "-vf",
        "select=eq(n\\,0)",
        "-vframes",
        "1",
        "-update",
        "1",
        str(output_poster),
    )

    print(f"Generated {output_mp4}")
    print(f"Generated {output_gif}")
    print(f"Generated {output_poster}")


if __name__ == "__main__":
    main()
