from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
import textwrap

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "assets" / "competition-video" / "storyboards"
OUT.mkdir(parents=True, exist_ok=True)

W, H = 1920, 1080
CARD_W, CARD_H = 620, 350

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Supplemental/Helvetica.ttf",
    "/Library/Fonts/Arial Unicode.ttf",
]

def font(size: int, bold: bool = False):
    paths = FONT_CANDIDATES
    for p in paths:
        if Path(p).exists():
            return ImageFont.truetype(p, size=size)
    return ImageFont.load_default()

F_TITLE = font(58)
F_SUB = font(30)
F_BODY = font(28)
F_SMALL = font(22)
F_TINY = font(18)

SHOTS = [
    {
        "id": "01", "time": "0:00-0:12", "title": "No Signal", "kind": "AI CINEMATIC",
        "visual": "Phone glow in a dark forest. The cloud fails first.",
        "vo": "In an emergency, the cloud is often the first thing you lose.",
        "palette": ((8, 18, 31), (28, 58, 76)), "motif": "forest",
    },
    {
        "id": "02", "time": "0:12-0:24", "title": "Crisis Montage", "kind": "AI CINEMATIC",
        "visual": "Storm street, remote trail, cell tower silhouette.",
        "vo": "A storm knocks out towers. A hiking trail has no signal.",
        "palette": ((16, 20, 28), (60, 72, 84)), "motif": "triptych",
    },
    {
        "id": "03", "time": "0:24-0:38", "title": "Beacon Opens", "kind": "REAL PHONE PROOF",
        "visual": "Open Beacon home screen. Large simple emergency actions.",
        "vo": "Beacon is built for that gap.",
        "palette": ((4, 24, 32), (8, 76, 84)), "motif": "phone_home", "screenshot": ".artifacts/android/home-en-current.png",
    },
    {
        "id": "04", "time": "0:38-0:55", "title": "Model Ready", "kind": "REAL PHONE PROOF",
        "visual": "Gemma 4 ready. Airplane mode before asking.",
        "vo": "No server. No API key. No network required after setup.",
        "palette": ((16, 25, 36), (23, 100, 93)), "motif": "model",
    },
    {
        "id": "05", "time": "0:55-1:15", "title": "Lost In Forest", "kind": "REAL PHONE PROOF",
        "visual": "User types: lost, no signal, getting cold.",
        "vo": "Imagine someone is lost in a forest near sunset.",
        "palette": ((6, 22, 23), (57, 79, 57)), "motif": "phone_chat", "screenshot": ".artifacts/android/en-input-focus.png",
    },
    {
        "id": "06", "time": "1:15-1:38", "title": "Streaming Guidance", "kind": "REAL PHONE PROOF",
        "visual": "Answer streams: stop, warm, mark, signal, conserve.",
        "vo": "Gemma turns local guidance into simple actions.",
        "palette": ((3, 17, 27), (11, 101, 112)), "motif": "stream", "screenshot": ".artifacts/android/en-chat-streaming.png",
    },
    {
        "id": "07", "time": "1:38-1:55", "title": "Follow-Up Memory", "kind": "REAL PHONE PROOF",
        "visual": "Ask: Should I keep walking? Context stays alive.",
        "vo": "Follow-up questions stay grounded in the same situation.",
        "palette": ((7, 20, 31), (47, 91, 94)), "motif": "memory", "screenshot": ".artifacts/android/en-followup-streaming.png",
    },
    {
        "id": "08", "time": "1:55-2:12", "title": "Photo Enters Chat", "kind": "REAL PHONE PROOF",
        "visual": "Camera/gallery flow. Image bubble appears before analysis.",
        "vo": "If words are not enough, the user can send a photo.",
        "palette": ((12, 20, 31), (85, 70, 52)), "motif": "photo", "screenshot": ".artifacts/android/visual-photo-captured.png",
    },
    {
        "id": "09", "time": "2:12-2:27", "title": "Visual Answer", "kind": "REAL PHONE PROOF",
        "visual": "Beacon uses the image context and gives next steps.",
        "vo": "The image stays on the device.",
        "palette": ((8, 21, 30), (65, 103, 94)), "motif": "visual", "screenshot": ".artifacts/android/visual-analysis-final.png",
    },
    {
        "id": "10", "time": "2:27-2:42", "title": "20 Languages", "kind": "REAL PHONE PROOF",
        "visual": "Switch language. Show simple stress-friendly UI.",
        "vo": "Beacon supports 20 UI languages, including RTL Arabic.",
        "palette": ((18, 20, 32), (79, 61, 118)), "motif": "language", "screenshot": ".artifacts/android/lang-picker-current.png",
    },
    {
        "id": "11", "time": "2:42-2:52", "title": "Local Stack", "kind": "TECH PROOF",
        "visual": "React + Capacitor + Kotlin + LiteRT-LM + Gemma 4.",
        "vo": "Under the hood, Beacon combines mobile UI, edge runtime, and local knowledge.",
        "palette": ((7, 11, 19), (25, 84, 96)), "motif": "architecture",
    },
    {
        "id": "12", "time": "2:52-3:00", "title": "Beacon Promise", "kind": "AI CLOSING HERO",
        "visual": "Phone on emergency blanket. Dawn after the storm.",
        "vo": "When the network is gone, your phone still has a guide.",
        "palette": ((9, 16, 25), (74, 92, 82)), "motif": "closing",
    },
]


def gradient(bg1, bg2):
    img = Image.new("RGB", (W, H), bg1)
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        for x in range(W):
            u = x / (W - 1)
            m = min(1, 0.72 * t + 0.28 * u)
            r = int(bg1[0] * (1 - m) + bg2[0] * m)
            g = int(bg1[1] * (1 - m) + bg2[1] * m)
            b = int(bg1[2] * (1 - m) + bg2[2] * m)
            px[x, y] = (r, g, b)
    return img


def add_noise(img):
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    for i in range(0, W, 22):
        alpha = 10 if i % 44 else 18
        d.line((i, 0, i + 180, H), fill=(255, 255, 255, alpha), width=1)
    for y in range(0, H, 36):
        d.line((0, y, W, y), fill=(255, 255, 255, 8), width=1)
    return Image.alpha_composite(img.convert("RGBA"), overlay)


def rounded_rect(draw, xy, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def draw_phone(canvas, center=(1180, 550), scale=1.0, screenshot=None, glow=(30, 220, 190)):
    d = ImageDraw.Draw(canvas, "RGBA")
    pw, ph = int(360 * scale), int(740 * scale)
    x0, y0 = int(center[0] - pw / 2), int(center[1] - ph / 2)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow, "RGBA")
    sd.rounded_rectangle((x0 - 26, y0 - 18, x0 + pw + 26, y0 + ph + 36), 58, fill=(0, 0, 0, 130))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas.alpha_composite(shadow)
    d.rounded_rectangle((x0, y0, x0 + pw, y0 + ph), 48, fill=(8, 13, 18, 255), outline=(160, 250, 234, 70), width=4)
    screen = (x0 + 22, y0 + 34, x0 + pw - 22, y0 + ph - 34)
    d.rounded_rectangle(screen, 34, fill=(7, 24, 28, 255))
    d.rounded_rectangle((x0 + pw * 0.36, y0 + 14, x0 + pw * 0.64, y0 + 24), 5, fill=(30, 38, 44, 255))
    if screenshot and Path(screenshot).exists():
        shot = Image.open(screenshot).convert("RGBA")
        sw, sh = screen[2] - screen[0], screen[3] - screen[1]
        shot_ratio = shot.width / shot.height
        target_ratio = sw / sh
        if shot_ratio > target_ratio:
            new_h = sh
            new_w = int(sh * shot_ratio)
        else:
            new_w = sw
            new_h = int(sw / shot_ratio)
        shot = shot.resize((new_w, new_h), Image.LANCZOS)
        left = max(0, (new_w - sw) // 2)
        top = max(0, (new_h - sh) // 2)
        shot = shot.crop((left, top, left + sw, top + sh))
        mask = Image.new("L", (sw, sh), 0)
        md = ImageDraw.Draw(mask)
        md.rounded_rectangle((0, 0, sw, sh), 30, fill=255)
        canvas.paste(shot, (screen[0], screen[1]), mask)
    else:
        sx0, sy0, sx1, sy1 = screen
        # simple app-like UI, no fake readable product text beyond generic marks
        d.rounded_rectangle((sx0 + 24, sy0 + 30, sx1 - 24, sy0 + 96), 20, fill=(16, 54, 58, 255))
        for i in range(4):
            yy = sy0 + 132 + i * 100
            color = (18, 78 + i * 15, 76 + i * 12, 255)
            d.rounded_rectangle((sx0 + 26, yy, sx1 - 26, yy + 76), 22, fill=color, outline=(120, 255, 220, 50), width=2)
        d.rounded_rectangle((sx0 + 26, sy1 - 100, sx1 - 26, sy1 - 36), 26, fill=(220, 250, 242, 230))
    # glow line
    d.arc((x0 - 14, y0 - 14, x0 + pw + 14, y0 + ph + 14), 205, 330, fill=glow + (120,), width=5)


def draw_forest(canvas):
    d = ImageDraw.Draw(canvas, "RGBA")
    for i, x in enumerate(range(-80, W, 120)):
        h = 520 + (i % 4) * 95
        d.polygon([(x, H), (x + 75, H - h), (x + 150, H)], fill=(3, 14, 17, 190))
        d.rectangle((x + 68, H - h * 0.55, x + 82, H), fill=(3, 12, 14, 210))
    # hand/phone abstract
    d.ellipse((1050, 590, 1390, 890), fill=(80, 58, 45, 230))
    draw_phone(canvas, center=(1210, 500), scale=0.72)


def draw_triptych(canvas):
    d = ImageDraw.Draw(canvas, "RGBA")
    panels = [(160, 210, 640, 760), (720, 210, 1200, 760), (1280, 210, 1760, 760)]
    colors = [(25, 38, 48, 210), (28, 47, 42, 210), (37, 42, 54, 210)]
    for idx, box in enumerate(panels):
        d.rounded_rectangle(box, 34, fill=colors[idx], outline=(215, 255, 246, 50), width=3)
    # city
    for x in range(210, 610, 70):
        d.rectangle((x, 470 - (x % 140), x + 42, 760), fill=(6, 12, 18, 230))
    # trail
    d.polygon([(820, 760), (950, 380), (1080, 760)], fill=(82, 65, 43, 190))
    d.rectangle((940, 300, 960, 520), fill=(28, 35, 25, 240))
    d.rectangle((900, 305, 1005, 352), fill=(139, 112, 67, 230))
    # tower
    d.line((1520, 760, 1520, 330), fill=(12, 16, 22, 240), width=10)
    for off in [80, 150, 230]:
        d.line((1520, 340 + off, 1400, 760), fill=(12, 16, 22, 190), width=4)
        d.line((1520, 340 + off, 1640, 760), fill=(12, 16, 22, 190), width=4)
    d.arc((1410, 250, 1630, 470), 210, 330, fill=(125, 229, 214, 65), width=4)


def draw_model(canvas):
    d = ImageDraw.Draw(canvas, "RGBA")
    draw_phone(canvas, center=(670, 545), scale=0.86)
    # airplane mode proof side card
    d.rounded_rectangle((1080, 315, 1620, 690), 42, fill=(8, 21, 28, 220), outline=(132, 255, 229, 70), width=3)
    d.text((1130, 360), "MODEL READY", font=F_SUB, fill=(218, 255, 246, 255))
    d.text((1130, 428), "Gemma 4 E2B / E4B", font=F_BODY, fill=(165, 238, 226, 255))
    d.text((1130, 494), "Airplane mode ON", font=F_BODY, fill=(255, 221, 155, 255))
    # airplane icon
    d.polygon([(1420, 580), (1580, 530), (1502, 612), (1540, 690), (1460, 630), (1385, 700), (1418, 610)], fill=(142, 251, 224, 210))


def draw_stream_lines(canvas, x=1050, y=310):
    d = ImageDraw.Draw(canvas, "RGBA")
    for i, w in enumerate([600, 520, 570, 470, 610, 390]):
        yy = y + i * 70
        d.rounded_rectangle((x, yy, x + w, yy + 28), 14, fill=(195, 255, 239, 185))
    d.ellipse((x + 650, y + 350, x + 692, y + 392), fill=(105, 255, 221, 220))


def draw_architecture(canvas):
    d = ImageDraw.Draw(canvas, "RGBA")
    draw_phone(canvas, center=(960, 560), scale=0.72)
    nodes = [
        (430, 315, "React"), (430, 540, "Capacitor"), (430, 765, "Kotlin"),
        (1490, 315, "LiteRT-LM"), (1490, 540, "Gemma 4"), (1490, 765, "Offline KB"),
    ]
    for x, y, label in nodes:
        d.line((960, 560, x, y), fill=(118, 248, 224, 90), width=4)
        d.rounded_rectangle((x - 140, y - 44, x + 140, y + 44), 24, fill=(8, 28, 34, 230), outline=(126, 252, 228, 120), width=3)
        tw = d.textlength(label, font=F_SMALL)
        d.text((x - tw/2, y - 14), label, font=F_SMALL, fill=(225, 255, 248, 255))


def draw_language(canvas):
    d = ImageDraw.Draw(canvas, "RGBA")
    draw_phone(canvas, center=(610, 545), scale=0.78)
    languages = ["English", "简体中文", "日本語", "한국어", "Español", "العربية", "हिन्दी", "ไทย"]
    d.rounded_rectangle((1020, 230, 1665, 825), 44, fill=(14, 18, 32, 225), outline=(196, 174, 255, 90), width=3)
    for i, lang in enumerate(languages):
        yy = 290 + i * 62
        d.rounded_rectangle((1080, yy, 1605, yy + 42), 20, fill=(255, 255, 255, 18 if i else 42))
        d.text((1112, yy + 8), lang, font=F_SMALL, fill=(238, 240, 255, 245))
    d.text((1120, 765), "20 UI languages", font=F_SUB, fill=(221, 255, 246, 255))


def draw_closing(canvas):
    d = ImageDraw.Draw(canvas, "RGBA")
    # emergency blanket
    for i in range(0, W, 58):
        color = (170, 125, 65, 140) if i % 116 else (225, 170, 88, 170)
        d.polygon([(i, H), (i + 130, H), (i + 55, 610)], fill=color)
    # dawn
    d.ellipse((1320, 120, 1800, 600), fill=(255, 202, 132, 50))
    # phone + beacon mark
    draw_phone(canvas, center=(910, 560), scale=0.8)
    d.ellipse((836, 487, 984, 635), fill=(112, 255, 219, 210))
    d.polygon([(910, 505), (950, 588), (910, 615), (870, 588)], fill=(7, 34, 39, 255))
    d.ellipse((892, 548, 928, 584), fill=(248, 255, 238, 255))


def draw_motif(canvas, shot):
    motif = shot["motif"]
    screenshot = shot.get("screenshot")
    if screenshot:
        screenshot = ROOT / screenshot
    if motif == "forest":
        draw_forest(canvas)
    elif motif == "triptych":
        draw_triptych(canvas)
    elif motif == "model":
        draw_model(canvas)
    elif motif in {"phone_home", "phone_chat", "photo", "visual"}:
        draw_phone(canvas, center=(1180, 555), scale=0.86, screenshot=screenshot)
    elif motif == "stream":
        draw_phone(canvas, center=(650, 555), scale=0.78, screenshot=screenshot)
        draw_stream_lines(canvas)
    elif motif == "memory":
        draw_phone(canvas, center=(650, 555), scale=0.78, screenshot=screenshot)
        d = ImageDraw.Draw(canvas, "RGBA")
        d.arc((1040, 330, 1530, 750), 40, 330, fill=(125, 255, 226, 130), width=10)
        d.polygon([(1515, 520), (1585, 535), (1538, 586)], fill=(125, 255, 226, 130))
        draw_stream_lines(canvas, x=1080, y=380)
    elif motif == "language":
        draw_language(canvas)
    elif motif == "architecture":
        draw_architecture(canvas)
    elif motif == "closing":
        draw_closing(canvas)
    else:
        draw_phone(canvas, center=(1120, 555), scale=0.86, screenshot=screenshot)


def draw_text_block(canvas, shot):
    d = ImageDraw.Draw(canvas, "RGBA")
    # Top ribbon
    d.rounded_rectangle((70, 64, 620, 138), 28, fill=(4, 15, 20, 205), outline=(136, 255, 229, 95), width=2)
    d.text((100, 84), f"SHOT {shot['id']}  {shot['time']}", font=F_SMALL, fill=(186, 255, 238, 255))
    # kind pill
    kind_w = int(d.textlength(shot["kind"], font=F_TINY)) + 42
    d.rounded_rectangle((70, 155, 70 + kind_w, 198), 20, fill=(114, 255, 222, 45), outline=(148, 255, 229, 80), width=1)
    d.text((92, 166), shot["kind"], font=F_TINY, fill=(210, 255, 246, 255))

    d.text((70, 245), shot["title"], font=F_TITLE, fill=(245, 255, 250, 255))
    y = 340
    for label, text, color in [("VISUAL", shot["visual"], (218, 238, 235, 240)), ("VO CUE", shot["vo"], (255, 224, 168, 245))]:
        d.text((74, y), label, font=F_TINY, fill=(126, 255, 228, 220))
        y += 35
        for line in textwrap.wrap(text, width=34):
            d.text((74, y), line, font=F_BODY, fill=color)
            y += 37
        y += 24

    # bottom guide
    guide = "Use real app recording" if "REAL" in shot["kind"] or "TECH" in shot["kind"] else "Generate as cinematic B-roll"
    d.rounded_rectangle((70, 850, 670, 930), 28, fill=(5, 18, 24, 225), outline=(138, 255, 229, 110), width=2)
    d.text((100, 875), guide, font=F_SUB, fill=(222, 255, 248, 255))


def make_frame(shot):
    img = gradient(*shot["palette"])
    img = add_noise(img)
    # soft vignette
    vignette = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vignette)
    for r in range(0, 900, 14):
        alpha = int(255 * (r / 900) ** 1.7)
        vd.ellipse((W/2-r*1.7, H/2-r, W/2+r*1.7, H/2+r), fill=alpha)
    vignette = Image.eval(vignette, lambda p: 255 - min(255, p))
    dark = Image.new("RGBA", (W, H), (0, 0, 0, 135))
    img = Image.composite(dark, img, vignette).convert("RGBA")
    draw_motif(img, shot)
    draw_text_block(img, shot)
    # frame border
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle((28, 28, W - 28, H - 28), 36, outline=(190, 255, 240, 40), width=3)
    return img.convert("RGB")

frames = []
for shot in SHOTS:
    frame = make_frame(shot)
    path = OUT / f"shot-{shot['id']}.png"
    frame.save(path, quality=95)
    frames.append((shot, frame))

# Contact sheet 4x3
thumb_w, thumb_h = 640, 360
sheet = Image.new("RGB", (thumb_w * 3, thumb_h * 4 + 120), (6, 10, 16))
sd = ImageDraw.Draw(sheet)
sd.text((40, 35), "Beacon 3-Minute Competition Video Storyboard", font=font(42), fill=(235, 255, 250))
sd.text((40, 86), "12 shots: real phone proof + cinematic B-roll + Seedance prompts", font=F_SMALL, fill=(166, 226, 216))
for idx, (shot, frame) in enumerate(frames):
    row, col = divmod(idx, 3)
    thumb = frame.resize((thumb_w, thumb_h), Image.LANCZOS)
    x, y = col * thumb_w, 120 + row * thumb_h
    sheet.paste(thumb, (x, y))
    sd.rectangle((x, y, x + thumb_w - 1, y + thumb_h - 1), outline=(30, 80, 82), width=2)
sheet.save(OUT / "contact-sheet.png", quality=95)

print(f"Generated {len(frames)} storyboard frames under {OUT}")
