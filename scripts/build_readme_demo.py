#!/usr/bin/env python3

from __future__ import annotations

import argparse
import math
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

try:
    import arabic_reshaper  # type: ignore
    from bidi.algorithm import get_display  # type: ignore
except Exception:
    arabic_reshaper = None
    get_display = None


ROOT_DIR = Path(__file__).resolve().parent.parent
DEFAULT_INPUT_IMAGE = ROOT_DIR / "docs/assets/beacon-home-android-en.png"
DEFAULT_FRAMES_DIR = ROOT_DIR / "docs/assets/.readme-demo-frames"
DEFAULT_OUTPUT_MP4 = ROOT_DIR / "docs/assets/beacon-demo-hero.mp4"
DEFAULT_OUTPUT_GIF = ROOT_DIR / "docs/assets/beacon-demo-hero.gif"
DEFAULT_OUTPUT_POSTER = ROOT_DIR / "docs/assets/beacon-demo-hero-poster.png"
LATIN_BOLD = "/System/Library/Fonts/Supplemental/Verdana Bold.ttf"
LATIN_REG = "/System/Library/Fonts/Supplemental/Verdana.ttf"
CJK_FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"
KO_FONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"
AR_FONT = "/System/Library/Fonts/GeezaPro.ttc"
UNICODE_FONT = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"

WIDTH = 1280
HEIGHT = 720
FPS = 20
DURATION_SECONDS = 8
FRAME_COUNT = FPS * DURATION_SECONDS
PHONE_WIDTH = 302
PHONE_X = 912
PHONE_Y = 22
PHONE_FRAME_PADDING = 16
HEADER_BOX = (56, 52, 808, 220)
HEADER_TEXT_LEFT = 76
HEADER_TEXT_TOP = 76
HEADER_TEXT_WIDTH = 690
CARD_BOX = (76, 248, 704, 424)
CARD_TEXT_LEFT = 104
CARD_TEXT_TOP = 272
CARD_TEXT_WIDTH = 564
BADGES_Y = 616
BADGE_HEIGHT = 44
BADGE_GAP = 16
BADGE_X = 76
RTL_LOCALES = {"ar"}

LOCALE_COPY: dict[str, dict[str, object]] = {
    "en": {
        "headline": "Offline-first emergency survival guidance",
        "caption": "Real on-device Gemma 4 + multilingual UX + offline knowledge",
        "cards": [
            {
                "title": "Real on-device Gemma 4",
                "line1": "No cloud dependency on the critical path.",
                "line2": "Built for no-signal, low-battery, high-stress scenarios.",
            },
            {
                "title": "20 UI languages + Arabic RTL",
                "line1": "Manual language switch is always visible in the UI.",
                "line2": "English, Chinese, Japanese, Korean, Arabic, Spanish and more.",
            },
            {
                "title": "Offline knowledge + native mobile hooks",
                "line1": "Camera, battery, geolocation, SOS packaging, and safe reset.",
                "line2": "Bundled emergency and survival sources keep grounding local.",
            },
        ],
        "badges": ["ANDROID + IOS", "20 LANGUAGES", "OFFLINE FIRST"],
    },
    "zh-CN": {
        "headline": "离线优先的紧急求生与应急指引",
        "caption": "端侧 Gemma 4 + 多语言交互 + 本地知识库",
        "cards": [
            {
                "title": "真实端侧 Gemma 4",
                "line1": "关键路径不依赖云端。",
                "line2": "为断网、低电量、高压场景而设计。",
            },
            {
                "title": "20 种界面语言 + 阿拉伯语 RTL",
                "line1": "手动语言切换始终可见。",
                "line2": "英语、中文、日语、韩语、阿拉伯语、西语等均已支持。",
            },
            {
                "title": "离线知识库 + 原生移动能力",
                "line1": "相机、电量、定位、SOS 封包与安全重置都已接入。",
                "line2": "急救与求生知识在本地完成检索与约束。",
            },
        ],
        "badges": ["ANDROID + IOS", "20 种语言", "离线优先"],
    },
    "zh-TW": {
        "headline": "離線優先的緊急求生與應急指引",
        "caption": "端側 Gemma 4 + 多語言互動 + 本地知識庫",
        "cards": [
            {
                "title": "真實端側 Gemma 4",
                "line1": "關鍵路徑不依賴雲端。",
                "line2": "為斷網、低電量、高壓場景設計。",
            },
            {
                "title": "20 種介面語言 + 阿拉伯語 RTL",
                "line1": "手動語言切換始終可見。",
                "line2": "英文、中文、日文、韓文、阿拉伯文、西文等均已支援。",
            },
            {
                "title": "離線知識庫 + 原生行動能力",
                "line1": "相機、電量、定位、SOS 封包與安全重置都已接入。",
                "line2": "急救與求生知識在本地完成檢索與約束。",
            },
        ],
        "badges": ["ANDROID + IOS", "20 種語言", "離線優先"],
    },
    "ja": {
        "headline": "オフライン優先の緊急サバイバル支援",
        "caption": "端末上の Gemma 4 + 多言語 UX + ローカル知識ベース",
        "cards": [
            {
                "title": "実機上で動く Gemma 4",
                "line1": "重要な判断経路をクラウドに依存させません。",
                "line2": "圏外、低電力、高ストレス環境を前提にしています。",
            },
            {
                "title": "20 言語 UI + アラビア語 RTL",
                "line1": "手動の言語切替は常に見える位置にあります。",
                "line2": "英語、中国語、日本語、韓国語、アラビア語、スペイン語などを収録。",
            },
            {
                "title": "オフライン知識 + ネイティブ機能",
                "line1": "カメラ、電池、位置情報、SOS、セーフリセットを統合。",
                "line2": "救急と生存知識をローカルで検索し、推論に反映します。",
            },
        ],
        "badges": ["ANDROID + IOS", "20 言語", "オフライン優先"],
    },
    "ko": {
        "headline": "오프라인 우선 긴급 생존 안내",
        "caption": "온디바이스 Gemma 4 + 다국어 UX + 로컬 지식 기반",
        "cards": [
            {
                "title": "실제 기기에서 실행되는 Gemma 4",
                "line1": "핵심 경로를 클라우드에 의존하지 않습니다.",
                "line2": "무통신, 저전력, 고스트레스 상황을 기준으로 설계했습니다.",
            },
            {
                "title": "20개 UI 언어 + 아랍어 RTL",
                "line1": "수동 언어 전환은 항상 화면에 보입니다.",
                "line2": "영어, 중국어, 일본어, 한국어, 아랍어, 스페인어 등을 지원합니다.",
            },
            {
                "title": "오프라인 지식 + 네이티브 모바일 기능",
                "line1": "카메라, 배터리, 위치, SOS 패키징, 안전 초기화를 통합했습니다.",
                "line2": "응급 및 생존 지식을 기기 안에서 검색해 추론에 반영합니다.",
            },
        ],
        "badges": ["ANDROID + IOS", "20개 언어", "오프라인 우선"],
    },
    "es": {
        "headline": "Guia de supervivencia y emergencia offline-first",
        "caption": "Gemma 4 local + UX multilenguaje + conocimiento offline",
        "cards": [
            {
                "title": "Gemma 4 real en el dispositivo",
                "line1": "La ruta critica no depende de la nube.",
                "line2": "Disenado para escenarios sin senal, poca bateria y alto estres.",
            },
            {
                "title": "20 idiomas UI + arabe RTL",
                "line1": "El selector manual de idioma siempre permanece visible.",
                "line2": "Incluye ingles, chino, japones, coreano, arabe, espanol y mas.",
            },
            {
                "title": "Conocimiento offline + capacidades nativas",
                "line1": "Camara, bateria, geolocalizacion, SOS y reinicio seguro integrados.",
                "line2": "Las fuentes de emergencia y supervivencia siguen siendo locales.",
            },
        ],
        "badges": ["ANDROID + IOS", "20 IDIOMAS", "OFFLINE FIRST"],
    },
    "fr": {
        "headline": "Guidage d urgence et de survie offline-first",
        "caption": "Gemma 4 sur l appareil + UX multilingue + connaissances locales",
        "cards": [
            {
                "title": "Gemma 4 reel sur l appareil",
                "line1": "Le chemin critique ne depend pas du cloud.",
                "line2": "Concu pour absence de reseau, batterie faible et stress eleve.",
            },
            {
                "title": "20 langues UI + arabe RTL",
                "line1": "Le changement manuel de langue reste toujours visible.",
                "line2": "Anglais, chinois, japonais, coreen, arabe, espagnol et plus encore.",
            },
            {
                "title": "Connaissances offline + hooks mobiles natifs",
                "line1": "Camera, batterie, geolocalisation, SOS et reinitialisation sure.",
                "line2": "Les sources de survie et d urgence restent ancrees en local.",
            },
        ],
        "badges": ["ANDROID + IOS", "20 LANGUES", "OFFLINE FIRST"],
    },
    "de": {
        "headline": "Offline-First-Notfall- und Survival-Hilfe",
        "caption": "Lokales Gemma 4 + mehrsprachige UX + Offline-Wissensbasis",
        "cards": [
            {
                "title": "Echtes Gemma 4 auf dem Geraet",
                "line1": "Der kritische Pfad haengt nicht von der Cloud ab.",
                "line2": "Entwickelt fuer Funkloch, wenig Akku und hohe Belastung.",
            },
            {
                "title": "20 UI-Sprachen + Arabisch RTL",
                "line1": "Der manuelle Sprachwechsel bleibt immer sichtbar.",
                "line2": "Mit Englisch, Chinesisch, Japanisch, Koreanisch, Arabisch, Spanisch und mehr.",
            },
            {
                "title": "Offline-Wissen + native Mobilfunktionen",
                "line1": "Kamera, Akku, Ortung, SOS und sicheres Zuruecksetzen integriert.",
                "line2": "Notfall- und Survival-Quellen bleiben lokal im Prompt verankert.",
            },
        ],
        "badges": ["ANDROID + IOS", "20 SPRACHEN", "OFFLINE FIRST"],
    },
    "pt": {
        "headline": "Guia de emergencia e sobrevivencia offline-first",
        "caption": "Gemma 4 no dispositivo + UX multilingue + conhecimento local",
        "cards": [
            {
                "title": "Gemma 4 real no proprio aparelho",
                "line1": "O caminho critico nao depende da nuvem.",
                "line2": "Feito para falta de sinal, pouca bateria e alto estresse.",
            },
            {
                "title": "20 idiomas de UI + arabe RTL",
                "line1": "A troca manual de idioma permanece sempre visivel.",
                "line2": "Inclui ingles, chines, japones, coreano, arabe, espanhol e mais.",
            },
            {
                "title": "Conhecimento offline + recursos nativos",
                "line1": "Camera, bateria, geolocalizacao, SOS e reset seguro integrados.",
                "line2": "As fontes de emergencia e sobrevivencia continuam locais.",
            },
        ],
        "badges": ["ANDROID + IOS", "20 IDIOMAS", "OFFLINE FIRST"],
    },
    "ar": {
        "headline": "إرشاد طوارئ وبقاء يعمل أولا دون اتصال",
        "caption": "Gemma 4 على الجهاز + واجهة متعددة اللغات + معرفة محلية",
        "cards": [
            {
                "title": "Gemma 4 حقيقي على الجهاز",
                "line1": "المسار الحرج لا يعتمد على السحابة.",
                "line2": "مصمم لانقطاع الشبكة وضعف البطارية والضغط الشديد.",
            },
            {
                "title": "20 لغة واجهة + RTL للعربية",
                "line1": "مبدل اللغة اليدوي ظاهر دائما داخل الواجهة.",
                "line2": "الإنجليزية والصينية واليابانية والكورية والعربية والإسبانية وغيرها.",
            },
            {
                "title": "معرفة محلية + قدرات جوال أصلية",
                "line1": "الكاميرا والبطارية والموقع وSOS وإعادة الضبط الآمنة مدمجة.",
                "line2": "تبقى مصادر الطوارئ والبقاء محلية داخل عملية الاستدلال.",
            },
        ],
        "badges": ["أندرويد + آيفون", "20 لغة", "دون اتصال"],
    },
}

CARD_ACCENTS = [
    (245, 158, 11, 242),
    (37, 99, 235, 242),
    (22, 163, 74, 242),
]


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def ease_in_out(progress: float) -> float:
    return 0.5 - 0.5 * math.cos(progress * math.pi)


def rounded_box(draw: ImageDraw.ImageDraw, xy, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def normalize_locale(locale: str) -> str:
    raw = locale.strip()
    if raw in LOCALE_COPY:
        return raw
    lowered = raw.lower()
    aliases = {
        "zh_tw": "zh-TW",
        "zh-cn": "zh-CN",
        "zh_cn": "zh-CN",
        "pt-br": "pt",
        "pt_br": "pt",
        "jp": "ja",
        "kr": "ko",
    }
    return aliases.get(lowered, lowered)


def is_cjk_locale(locale: str) -> bool:
    return locale in {"zh-CN", "zh-TW", "ja"}


def choose_font_paths(locale: str) -> tuple[str, str]:
    if locale in {"zh-CN", "zh-TW", "ja"}:
        return CJK_FONT, CJK_FONT
    if locale == "ko":
        return KO_FONT, KO_FONT
    if locale == "ar":
        return UNICODE_FONT, UNICODE_FONT
    return LATIN_BOLD, LATIN_REG


def build_fonts(locale: str) -> dict[str, ImageFont.FreeTypeFont]:
    bold_path, reg_path = choose_font_paths(locale)
    if locale in {"zh-CN", "zh-TW", "ja", "ko"}:
        sizes = {
            "title": 46,
            "headline": 28,
            "caption": 18,
            "card_title": 30,
            "card_body": 21,
            "card_small": 18,
            "badge": 18,
        }
    elif locale == "ar":
        sizes = {
            "title": 46,
            "headline": 28,
            "caption": 18,
            "card_title": 29,
            "card_body": 21,
            "card_small": 18,
            "badge": 18,
        }
    else:
        sizes = {
            "title": 46,
            "headline": 28,
            "caption": 18,
            "card_title": 32,
            "card_body": 22,
            "card_small": 18,
            "badge": 18,
        }
    return {
        key: ImageFont.truetype(
            LATIN_REG if key == "title" else (bold_path if key in {"card_title", "badge"} else reg_path),
            size,
        )
        for key, size in sizes.items()
    }


def prepare_text(text: str, locale: str) -> str:
    if locale != "ar" or arabic_reshaper is None or get_display is None:
        return text
    try:
        return get_display(arabic_reshaper.reshape(text))
    except Exception:
        return text


def tokenize_text(text: str, locale: str) -> list[str]:
    if is_cjk_locale(locale):
        return list(text)
    return text.split()


def measure_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont) -> tuple[int, int]:
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def wrap_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, max_width: int, locale: str) -> list[str]:
    prepared = prepare_text(text, locale)
    if not prepared:
        return [""]

    tokens = tokenize_text(prepared, locale)
    lines: list[str] = []
    current = ""
    separator = "" if is_cjk_locale(locale) else " "

    for token in tokens:
        candidate = token if not current else f"{current}{separator}{token}"
        width, _ = measure_text(draw, candidate, font)
        if width <= max_width or not current:
            current = candidate
            continue
        lines.append(current)
        current = token

    if current:
        lines.append(current)

    return lines or [prepared]


def draw_wrapped_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    font: ImageFont.FreeTypeFont,
    xy: tuple[int, int],
    fill: tuple[int, int, int, int],
    max_width: int,
    locale: str,
    spacing: int = 8,
) -> tuple[int, int, int, int]:
    lines = wrap_text(draw, text, font, max_width, locale)
    prepared = "\n".join(lines)
    draw.multiline_text(xy, prepared, font=font, fill=fill, spacing=spacing)
    return draw.multiline_textbbox(xy, prepared, font=font, spacing=spacing)


def draw_badges(
    frame: Image.Image,
    fonts: dict[str, ImageFont.FreeTypeFont],
    locale: str,
    labels: list[str],
):
    draw = ImageDraw.Draw(frame, "RGBA")
    cursor_x = BADGE_X
    for label in labels:
        display = prepare_text(label, locale)
        width, _ = measure_text(draw, display, fonts["badge"])
        badge_width = width + 44
        rounded_box(draw, (cursor_x, BADGES_Y, cursor_x + badge_width, BADGES_Y + BADGE_HEIGHT), 18, (8, 12, 18, 100))
        draw.text((cursor_x + 22, BADGES_Y + 12), display, font=fonts["badge"], fill=(255, 255, 255, 255))
        cursor_x += badge_width + BADGE_GAP


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


def build_frame(
    source: Image.Image,
    phone: Image.Image,
    fonts: dict[str, ImageFont.FreeTypeFont],
    index: int,
    locale: str,
    copy: dict[str, object],
) -> Image.Image:
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
    draw.text((HEADER_TEXT_LEFT, HEADER_TEXT_TOP), "Beacon", font=fonts["title"], fill=(255, 255, 255, 255))
    header_cursor_y = HEADER_TEXT_TOP + 52
    headline_bbox = draw_wrapped_text(
        draw,
        copy["headline"],
        fonts["headline"],
        (HEADER_TEXT_LEFT, header_cursor_y),
        (255, 255, 255, 255),
        HEADER_TEXT_WIDTH,
        locale,
        spacing=6,
    )
    header_cursor_y = headline_bbox[3] + 10
    draw_wrapped_text(
        draw,
        copy["caption"],
        fonts["caption"],
        (HEADER_TEXT_LEFT, header_cursor_y),
        (235, 241, 248, 220),
        HEADER_TEXT_WIDTH,
        locale,
        spacing=5,
    )

    cards = copy["cards"]
    card_index = min(int(t / 2.67), 2)
    card = cards[card_index]
    fade_window = 0.22
    card_start = card_index * 2.67
    card_end = 8.0 if card_index == 2 else (card_index + 1) * 2.67
    alpha = 1.0
    if t < card_start + fade_window:
        alpha = (t - card_start) / fade_window
    elif t > card_end - fade_window:
        alpha = (card_end - t) / fade_window
    alpha = clamp(alpha, 0.0, 1.0)

    card_fill = (8, 12, 18, int(160 * alpha))
    accent_fill = (*CARD_ACCENTS[card_index][:3], int(242 * alpha))
    rounded_box(draw, CARD_BOX, 24, card_fill)
    draw.rounded_rectangle((CARD_BOX[0], CARD_BOX[1], CARD_BOX[0] + 10, CARD_BOX[3]), radius=12, fill=accent_fill)
    card_cursor_y = CARD_TEXT_TOP
    title_bbox = draw_wrapped_text(
        draw,
        card["title"],
        fonts["card_title"],
        (CARD_TEXT_LEFT, card_cursor_y),
        (255, 255, 255, int(255 * alpha)),
        CARD_TEXT_WIDTH,
        locale,
        spacing=6,
    )
    card_cursor_y = title_bbox[3] + 12
    line1_bbox = draw_wrapped_text(
        draw,
        card["line1"],
        fonts["card_body"],
        (CARD_TEXT_LEFT, card_cursor_y),
        (244, 247, 252, int(235 * alpha)),
        CARD_TEXT_WIDTH,
        locale,
        spacing=6,
    )
    card_cursor_y = line1_bbox[3] + 12
    draw_wrapped_text(
        draw,
        card["line2"],
        fonts["card_small"],
        (CARD_TEXT_LEFT, card_cursor_y),
        (222, 228, 236, int(210 * alpha)),
        CARD_TEXT_WIDTH,
        locale,
        spacing=5,
    )

    draw_badges(frame, fonts, locale, copy["badges"])
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
    parser.add_argument("--locale", default="en", help="Locale key used for overlay copy.")
    return parser.parse_args()


def main():
    args = parse_args()
    locale = normalize_locale(args.locale)
    if locale not in LOCALE_COPY:
        raise SystemExit(f"Unsupported locale: {locale}")

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
    fonts = build_fonts(locale)
    copy = LOCALE_COPY[locale]

    for index in range(FRAME_COUNT):
        frame = build_frame(source, phone, fonts, index, locale, copy)
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
