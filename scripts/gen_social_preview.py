#!/usr/bin/env python3
"""Generate a social preview image (1280x640) for the Beacon GitHub repo."""

from PIL import Image, ImageDraw, ImageFont
import os

W, H = 1280, 640
BG = (0, 0, 0)
WHITE = (255, 255, 255)
AMBER = (245, 158, 11)
GRAY = (156, 163, 175)

img = Image.new("RGB", (W, H), BG)
draw = ImageDraw.Draw(img)

# Load the app icon
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(script_dir)
icon_path = os.path.join(project_root, "docs", "assets", "beacon-icon.png")

icon = Image.open(icon_path).convert("RGBA")
icon = icon.resize((120, 120), Image.LANCZOS)

# Paste icon centered near top
icon_x = (W - 120) // 2
icon_y = 80
# Create a black background for compositing
icon_bg = Image.new("RGB", (120, 120), BG)
icon_bg.paste(icon, mask=icon.split()[3])
img.paste(icon_bg, (icon_x, icon_y))

# Try to use a good font, fall back to default
def get_font(size, bold=False):
    font_paths = [
        "/System/Library/Fonts/SFCompact.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/Library/Fonts/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for fp in font_paths:
        if os.path.exists(fp):
            try:
                return ImageFont.truetype(fp, size)
            except Exception:
                continue
    return ImageFont.load_default()

font_title = get_font(72, bold=True)
font_tagline = get_font(28)
font_features = get_font(22)
font_badge = get_font(18)

# Title
title = "Beacon"
bbox = draw.textbbox((0, 0), title, font=font_title)
tw = bbox[2] - bbox[0]
draw.text(((W - tw) // 2, 220), title, fill=WHITE, font=font_title)

# Tagline
tagline = "Your phone becomes a survival AI"
bbox = draw.textbbox((0, 0), tagline, font=font_tagline)
tw = bbox[2] - bbox[0]
draw.text(((W - tw) // 2, 310), tagline, fill=AMBER, font=font_tagline)

# Sub-tagline
sub = "Powered by Gemma 4 running entirely on-device. No internet needed."
bbox = draw.textbbox((0, 0), sub, font=font_features)
tw = bbox[2] - bbox[0]
draw.text(((W - tw) // 2, 360), sub, fill=GRAY, font=font_features)

# Feature pills
features = [
    "Offline-First",
    "Gemma 4 On-Device",
    "14,229 Knowledge Entries",
    "20 Languages",
    "Visual AI",
]

pill_y = 430
pill_h = 36
pill_pad = 16
pill_gap = 14
pill_radius = 18

# Calculate total width for centering
pill_widths = []
for feat in features:
    bbox = draw.textbbox((0, 0), feat, font=font_badge)
    pw = bbox[2] - bbox[0] + pill_pad * 2
    pill_widths.append(pw)

total_w = sum(pill_widths) + pill_gap * (len(features) - 1)
start_x = (W - total_w) // 2

for i, feat in enumerate(features):
    pw = pill_widths[i]
    x1 = start_x
    y1 = pill_y
    x2 = x1 + pw
    y2 = y1 + pill_h

    draw.rounded_rectangle([x1, y1, x2, y2], radius=pill_radius, fill=(30, 30, 30), outline=(60, 60, 60))

    bbox = draw.textbbox((0, 0), feat, font=font_badge)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    tx = x1 + (pw - text_w) // 2
    ty = y1 + (pill_h - text_h) // 2 - 2
    draw.text((tx, ty), feat, fill=WHITE, font=font_badge)

    start_x = x2 + pill_gap

# Bottom line
bottom = "Emergency survival guidance with on-device AI inference"
bbox = draw.textbbox((0, 0), bottom, font=font_features)
tw = bbox[2] - bbox[0]
draw.text(((W - tw) // 2, 510), bottom, fill=(100, 100, 100), font=font_features)

# Subtle border
draw.rectangle([0, 0, W-1, H-1], outline=(40, 40, 40), width=1)

out_path = os.path.join(project_root, "docs", "assets", "beacon-social-preview.png")
img.save(out_path, "PNG", optimize=True)
print(f"Created social preview: {out_path}")
print(f"Size: {os.path.getsize(out_path)} bytes")
