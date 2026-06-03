#!/usr/bin/env python3
from __future__ import annotations

import argparse
import asyncio
import http.client
import json
import os
import socket
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
DOCS_DIR = ROOT / "docs/app-store"
LOCALIZATION_DIR = DOCS_DIR / "localizations"
ARTIFACT_DIR = ROOT / ".artifacts/app-store-localization-package"
SCREENSHOT_DIR = ARTIFACT_DIR / "screenshots"
RAW_SCREENSHOT_DIR = ARTIFACT_DIR / "raw-ui-screenshots"
METADATA_ARTIFACT_DIR = ARTIFACT_DIR / "metadata"

# iPhone 15 / 6.3-inch native screenshots. App Store Connect accepts device-native
# screenshot sets for supported display sizes; keep raw UI screenshots device-faithful.
VIEWPORT = {"width": 393, "height": 852}
DEVICE_SCALE_FACTOR = 3
EXPECTED_SCREENSHOT_SIZE = (1179, 2556)
DEFAULT_APP_STORE_VERSION = "0.2.28"
APP_STORE_VERSION = DEFAULT_APP_STORE_VERSION

SCREENSHOT_STATES = [
    ("01-home", "Home panic-first surface"),
    ("02-chat", "Offline guidance with citations"),
    ("03-visual", "Camera and photo visual help"),
    ("04-language", "Manual language switcher"),
]

LOCALE_DATA: list[dict[str, Any]] = [
    {
        "appLocale": "en",
        "appleLocale": "en-US",
        "displayName": "English (U.S.)",
        "appName": "Beacon Survival SOS",
        "subtitle": "Offline emergency AI",
        "promotionalText": "Offline Gemma emergency guidance with bundled public-safety knowledge, visual help, and visible source citations.",
        "keywords": "emergency,survival,first aid,disaster,offline AI,wilderness,Gemma,safety,crisis",
        "description": "Beacon Survival SOS is an offline emergency assistant built for moments when networks are down and every second matters.\n\nBeacon runs local Gemma guidance on your iPhone and retrieves bundled public-safety knowledge before answering. It helps you reason through wilderness survival, disaster response, injuries, burns, bleeding, radiation sheltering, power outages, and other crisis scenarios.\n\nKey features:\n- On-device Gemma emergency guidance\n- Offline public-safety knowledge retrieval\n- Camera or photo-based visual help\n- Source citations for medical and public-safety references\n- Simple panic-first mobile interface\n- 20 UI languages including RTL support\n- No account, no cloud inference, no advertising, no tracking\n\nBeacon is not a replacement for emergency services, medical care, rescue professionals, or official public-safety instructions. When communication is available, contact local emergency services or qualified professionals.",
        "releaseNotes": "Beacon 0.2.27 improves the iOS App Store build with updated on-device Gemma runtime packaging, safer visual help handling, visible citations, and smoother offline chat/navigation.",
        "screenshotCaptions": [
            "Start fast when every second matters.",
            "Local Gemma guidance with cited sources.",
            "Use the camera or photos for visual help.",
            "Switch languages manually at any time.",
        ],
        "chatPrompt": "I am lost in the forest and my phone has low battery.",
    },
    {
        "appLocale": "zh-CN",
        "appleLocale": "zh-Hans",
        "displayName": "简体中文",
        "appName": "Beacon Survival SOS",
        "subtitle": "离线急救生存助手",
        "promotionalText": "离线 Gemma 应急指引，内置公共安全知识库、视觉求助和清晰来源引用，断网时也能使用。",
        "keywords": "急救,生存,灾害,离线AI,野外,安全,地震,火灾,创伤,应急",
        "description": "Beacon Survival SOS 是为断网、低电量和极端压力场景准备的离线应急助手。\n\nBeacon 在 iPhone 本机运行 Gemma，并在回答前检索内置公共安全资料。它可以帮助你梳理野外求生、灾害避险、创伤、烧伤、出血、辐射避险、停电断网等危机场景中的下一步行动。\n\n核心能力：\n- 端侧 Gemma 应急指引\n- 离线公共安全知识库检索\n- 拍照或相册图片视觉求助\n- 医疗和公共安全建议显示来源引用\n- 傻瓜化的大按钮求助界面\n- 支持 20 种界面语言和 RTL 排版\n- 无账号、无云端推理、无广告、无追踪\n\nBeacon 不能替代急救电话、专业医疗、救援人员或官方公共安全指令。一旦恢复通信，请尽快联系当地急救、救援或专业人员。",
        "releaseNotes": "Beacon 0.2.27 优化了 iOS App Store 构建、端侧 Gemma 运行时打包、视觉求助安全处理、来源引用展示，以及离线对话和导航体验。",
        "screenshotCaptions": ["危急时刻，一点即用。", "本地 Gemma 给出带来源的建议。", "拍照或从相册选择进行视觉求助。", "随时手动切换界面语言。"],
        "chatPrompt": "我在森林里迷路了，手机快没电了。",
    },
    {
        "appLocale": "zh-TW",
        "appleLocale": "zh-Hant",
        "displayName": "繁體中文",
        "appName": "Beacon Survival SOS",
        "subtitle": "離線急救生存助手",
        "promotionalText": "離線 Gemma 應急指引，內建公共安全知識庫、視覺求助與清楚來源引用，斷網時也能使用。",
        "keywords": "急救,生存,災害,離線AI,野外,安全,地震,火災,創傷,應急",
        "description": "Beacon Survival SOS 是為斷網、低電量與高壓危急情境準備的離線應急助手。\n\nBeacon 在 iPhone 本機執行 Gemma，並在回答前檢索內建公共安全資料。它可協助你梳理野外求生、災害避險、創傷、燒傷、出血、輻射避險、停電斷網等危機中的下一步。\n\n核心能力：\n- 端側 Gemma 應急指引\n- 離線公共安全知識庫檢索\n- 拍照或相簿圖片視覺求助\n- 醫療與公共安全建議顯示來源引用\n- 易懂的大按鈕求助介面\n- 支援 20 種介面語言與 RTL 排版\n- 無帳號、無雲端推理、無廣告、無追蹤\n\nBeacon 不能取代急救電話、專業醫療、救援人員或官方公共安全指令。一旦恢復通訊，請盡快聯絡當地急救、救援或專業人員。",
        "releaseNotes": "Beacon 0.2.27 改善 iOS App Store 構建、端側 Gemma 运行時打包、視覺求助安全處理、來源引用展示，以及離線對話和導覽體驗。",
        "screenshotCaptions": ["危急時刻，一點即用。", "本地 Gemma 給出帶來源的建議。", "拍照或從相簿選擇進行視覺求助。", "隨時手動切換介面語言。"],
        "chatPrompt": "我在森林裡迷路了，手機快沒電了。",
    },
    {
        "appLocale": "ja",
        "appleLocale": "ja",
        "displayName": "日本語",
        "appName": "Beacon Survival SOS",
        "subtitle": "オフライン緊急AI",
        "promotionalText": "端末上の Gemma、オフライン公共安全知識、視覚ヘルプ、出典表示を備えた緊急サポートです。",
        "keywords": "救急,防災,サバイバル,オフラインAI,応急手当,災害,安全,野外",
        "description": "Beacon Survival SOS は、通信が不安定な時や一刻を争う場面のためのオフライン緊急アシスタントです。\n\nBeacon は iPhone 上で Gemma を実行し、回答前に内蔵の公共安全知識を参照します。山や森での迷子、災害、けが、やけど、出血、放射線退避、停電、通信障害などで次に何を確認し、どう動くべきかを整理します。\n\n主な機能：\n- 端末上の Gemma による緊急ガイダンス\n- オフライン公共安全知識の検索\n- カメラまたは写真による視覚ヘルプ\n- 医療・公共安全情報の出典表示\n- 迷わず押せる大きな緊急ボタン\n- 20 種類の UI 言語と RTL 対応\n- アカウント不要、クラウド推論なし、広告なし、追跡なし\n\nBeacon は救急サービス、医療従事者、救助隊、公式の安全指示の代替ではありません。通信が使える場合は、地域の緊急窓口や専門家に連絡してください。",
        "releaseNotes": "Beacon 0.2.27 では、iOS App Store ビルド、端末上の Gemma パッケージ、視覚ヘルプ、出典表示、オフラインチャットとナビゲーションを改善しました。",
        "screenshotCaptions": ["危険な時ほど、すぐ始められます。", "出典付きのローカル Gemma ガイダンス。", "カメラや写真で視覚ヘルプ。", "いつでも手動で言語を切り替え。"],
        "chatPrompt": "森で道に迷い、スマートフォンの電池も少ないです。",
    },
    {
        "appLocale": "ko",
        "appleLocale": "ko",
        "displayName": "한국어",
        "appName": "Beacon Survival SOS",
        "subtitle": "오프라인 긴급 AI",
        "promotionalText": "기기 내 Gemma, 오프라인 공공 안전 지식, 시각 도움, 출처 표시를 갖춘 긴급 생존 도우미입니다.",
        "keywords": "응급,생존,재난,오프라인AI,응급처치,안전,야외,지진",
        "description": "Beacon Survival SOS는 네트워크가 끊기고 시간이 중요한 순간을 위한 오프라인 긴급 도우미입니다.\n\nBeacon은 iPhone에서 Gemma를 실행하고, 답변 전에 내장된 공공 안전 지식을 검색합니다. 숲이나 산에서 길을 잃었을 때, 재난, 부상, 화상, 출혈, 방사선 대피, 정전, 통신 장애 같은 상황에서 다음 행동을 정리하도록 돕습니다.\n\n주요 기능:\n- 기기 내 Gemma 긴급 안내\n- 오프라인 공공 안전 지식 검색\n- 카메라 또는 사진 기반 시각 도움\n- 의료 및 공공 안전 정보의 출처 표시\n- 쉽게 누를 수 있는 큰 긴급 버튼\n- 20개 UI 언어 및 RTL 지원\n- 계정 없음, 클라우드 추론 없음, 광고 없음, 추적 없음\n\nBeacon은 응급 서비스, 전문 의료, 구조대 또는 공식 안전 지침을 대체하지 않습니다. 통신이 가능하면 지역 응급 서비스나 전문가에게 연락하세요.",
        "releaseNotes": "Beacon 0.2.27은 iOS App Store 빌드, 온디바이스 Gemma 패키징, 시각 도움 처리, 출처 표시, 오프라인 채팅과 내비게이션을 개선했습니다.",
        "screenshotCaptions": ["위급한 순간, 바로 시작하세요.", "출처가 보이는 로컬 Gemma 안내.", "카메라나 사진으로 시각 도움을 받으세요.", "언어를 언제든 직접 바꾸세요."],
        "chatPrompt": "숲에서 길을 잃었고 휴대폰 배터리가 거의 없습니다.",
    },
    {
        "appLocale": "es",
        "appleLocale": "es-ES",
        "displayName": "Español",
        "appName": "Beacon Survival SOS",
        "subtitle": "IA de emergencia offline",
        "promotionalText": "Guía de emergencia con Gemma local, conocimiento público offline, ayuda visual y citas visibles de las fuentes.",
        "keywords": "emergencia,supervivencia,primeros auxilios,desastre,IA offline,seguridad",
        "description": "Beacon Survival SOS es un asistente de emergencia offline para momentos en los que no hay red y cada segundo importa.\n\nBeacon ejecuta Gemma en tu iPhone y consulta conocimiento público incluido en la app antes de responder. Puede ayudarte a pensar los próximos pasos en supervivencia al aire libre, desastres, heridas, quemaduras, sangrado, refugio ante radiación, cortes de energía y otras crisis.\n\nFunciones principales:\n- Guía de emergencia Gemma en el dispositivo\n- Búsqueda offline de conocimiento público de seguridad\n- Ayuda visual con cámara o fotos\n- Citas de fuentes médicas y de seguridad pública\n- Interfaz simple con botones grandes de pánico\n- 20 idiomas de interfaz, incluido RTL\n- Sin cuenta, sin inferencia en la nube, sin anuncios, sin rastreo\n\nBeacon no reemplaza a los servicios de emergencia, atención médica, rescatistas ni instrucciones oficiales. Cuando tengas comunicación, contacta a emergencias o a profesionales calificados.",
        "releaseNotes": "Beacon 0.2.27 mejora la compilación iOS para App Store, el empaquetado local de Gemma, la ayuda visual, las citas visibles y la navegación/chat offline.",
        "screenshotCaptions": ["Actúa rápido cuando cada segundo cuenta.", "Guía local de Gemma con fuentes citadas.", "Usa cámara o fotos para ayuda visual.", "Cambia el idioma manualmente cuando quieras."],
        "chatPrompt": "Estoy perdido en el bosque y me queda poca batería.",
    },
    {
        "appLocale": "fr",
        "appleLocale": "fr-FR",
        "displayName": "Français",
        "appName": "Beacon Survival SOS",
        "subtitle": "IA d'urgence hors ligne",
        "promotionalText": "Guidage d'urgence avec Gemma local, connaissances publiques hors ligne, aide visuelle et citations visibles.",
        "keywords": "urgence,survie,premiers secours,catastrophe,IA hors ligne,sécurité",
        "description": "Beacon Survival SOS est un assistant d'urgence hors ligne conçu pour les moments où le réseau tombe et où chaque seconde compte.\n\nBeacon exécute Gemma sur votre iPhone et consulte des connaissances publiques intégrées avant de répondre. Il peut aider à organiser les prochaines actions en survie extérieure, catastrophe, blessure, brûlure, saignement, abri contre les radiations, panne de courant ou autre crise.\n\nFonctions clés :\n- Guidage Gemma sur l'appareil\n- Recherche hors ligne de connaissances de sécurité publique\n- Aide visuelle avec caméra ou photos\n- Citations de sources médicales et de sécurité publique\n- Interface simple avec grands boutons d'urgence\n- 20 langues d'interface, y compris RTL\n- Aucun compte, aucune inférence cloud, aucune publicité, aucun suivi\n\nBeacon ne remplace pas les services d'urgence, les soins médicaux, les secours professionnels ni les consignes officielles. Si la communication est disponible, contactez les secours locaux ou un professionnel qualifié.",
        "releaseNotes": "Beacon 0.2.27 améliore le build iOS App Store, le packaging Gemma local, l'aide visuelle, les citations visibles et le chat/navigation hors ligne.",
        "screenshotCaptions": ["Agir vite quand chaque seconde compte.", "Guidage Gemma local avec sources citées.", "Caméra ou photos pour l'aide visuelle.", "Changez de langue manuellement à tout moment."],
        "chatPrompt": "Je suis perdu dans la forêt et mon téléphone a peu de batterie.",
    },
    {
        "appLocale": "de",
        "appleLocale": "de-DE",
        "displayName": "Deutsch",
        "appName": "Beacon Survival SOS",
        "subtitle": "Offline-Notfall-KI",
        "promotionalText": "Notfallhilfe mit lokalem Gemma, Offline-Sicherheitswissen, visueller Hilfe und sichtbaren Quellenangaben.",
        "keywords": "notfall,überleben,erste hilfe,katastrophe,offline KI,sicherheit",
        "description": "Beacon Survival SOS ist ein Offline-Notfallassistent für Situationen ohne Netz, in denen jede Sekunde zählt.\n\nBeacon führt Gemma direkt auf dem iPhone aus und durchsucht integriertes öffentliches Sicherheitswissen, bevor es antwortet. Es hilft bei Wildnis, Katastrophen, Verletzungen, Verbrennungen, Blutungen, Strahlenschutz, Stromausfällen und anderen Krisen die nächsten Schritte zu ordnen.\n\nHauptfunktionen:\n- Gemma-Notfallhilfe auf dem Gerät\n- Offline-Suche in öffentlichen Sicherheitsquellen\n- Visuelle Hilfe per Kamera oder Foto\n- Quellenangaben für medizinische und öffentliche Sicherheitshinweise\n- Einfache Oberfläche mit großen Notfalltasten\n- 20 UI-Sprachen inklusive RTL\n- Kein Konto, keine Cloud-Inferenz, keine Werbung, kein Tracking\n\nBeacon ersetzt keine Rettungsdienste, medizinische Versorgung, Einsatzkräfte oder offiziellen Sicherheitsanweisungen. Sobald Kommunikation möglich ist, kontaktiere lokale Notdienste oder qualifizierte Fachleute.",
        "releaseNotes": "Beacon 0.2.27 verbessert den iOS App Store Build, das lokale Gemma-Paket, visuelle Hilfe, sichtbare Quellen und Offline-Chat/Navigation.",
        "screenshotCaptions": ["Schnell handeln, wenn Sekunden zählen.", "Lokale Gemma-Hilfe mit Quellen.", "Kamera oder Fotos für visuelle Hilfe.", "Sprache jederzeit manuell wechseln."],
        "chatPrompt": "Ich habe mich im Wald verirrt und mein Akku ist fast leer.",
    },
    {
        "appLocale": "pt",
        "appleLocale": "pt-BR",
        "displayName": "Português (Brasil)",
        "appName": "Beacon Survival SOS",
        "subtitle": "IA emergencial offline",
        "promotionalText": "Orientação emergencial com Gemma local, conhecimento público offline, ajuda visual e citações visíveis.",
        "keywords": "emergência,sobrevivência,primeiros socorros,desastre,IA offline",
        "description": "Beacon Survival SOS é um assistente de emergência offline para momentos sem rede em que cada segundo importa.\n\nBeacon executa Gemma no iPhone e consulta conhecimento público incluído no app antes de responder. Ele ajuda a organizar próximos passos em sobrevivência ao ar livre, desastres, ferimentos, queimaduras, sangramento, abrigo contra radiação, falta de energia e outras crises.\n\nPrincipais recursos:\n- Orientação Gemma no dispositivo\n- Busca offline em fontes de segurança pública\n- Ajuda visual com câmera ou fotos\n- Citações de fontes médicas e de segurança pública\n- Interface simples com botões grandes de emergência\n- 20 idiomas de interface, incluindo RTL\n- Sem conta, sem inferência em nuvem, sem anúncios, sem rastreamento\n\nBeacon não substitui serviços de emergência, atendimento médico, equipes de resgate nem instruções oficiais. Quando houver comunicação, contate emergências locais ou profissionais qualificados.",
        "releaseNotes": "Beacon 0.2.27 melhora o build iOS para App Store, o pacote Gemma local, a ajuda visual, citações visíveis e o chat/navegação offline.",
        "screenshotCaptions": ["Comece rápido quando cada segundo conta.", "Guia local Gemma com fontes citadas.", "Use câmera ou fotos para ajuda visual.", "Troque o idioma manualmente quando quiser."],
        "chatPrompt": "Estou perdido na floresta e meu celular está com pouca bateria.",
    },
    {
        "appLocale": "ru",
        "appleLocale": "ru",
        "displayName": "Русский",
        "appName": "Beacon Survival SOS",
        "subtitle": "Офлайн ИИ для ЧС",
        "promotionalText": "Экстренная помощь с локальной Gemma, офлайн-базой общественной безопасности, визуальной помощью и ссылками на источники.",
        "keywords": "экстренно,выживание,первая помощь,катастрофа,офлайн ИИ,безопасность",
        "description": "Beacon Survival SOS — офлайн-помощник для чрезвычайных ситуаций, когда связи нет, а каждая секунда важна.\n\nBeacon запускает Gemma прямо на iPhone и перед ответом обращается к встроенным материалам общественной безопасности. Приложение помогает продумать действия при выживании на природе, бедствиях, травмах, ожогах, кровотечении, радиационном укрытии, отключении электричества и других кризисах.\n\nВозможности:\n- Экстренная подсказка Gemma на устройстве\n- Офлайн-поиск по материалам общественной безопасности\n- Визуальная помощь через камеру или фото\n- Ссылки на медицинские и публичные источники\n- Простые крупные кнопки для стрессовых ситуаций\n- 20 языков интерфейса, включая RTL\n- Без аккаунта, облачного вывода, рекламы и трекинга\n\nBeacon не заменяет экстренные службы, медицинскую помощь, спасателей или официальные инструкции. Если связь доступна, обратитесь в местные службы или к квалифицированным специалистам.",
        "releaseNotes": "Beacon 0.2.27 улучшает iOS-сборку для App Store, упаковку локальной Gemma, визуальную помощь, видимые источники и офлайн-чат/навигацию.",
        "screenshotCaptions": ["Начните быстро, когда важна каждая секунда.", "Локальная Gemma с указанием источников.", "Камера или фото для визуальной помощи.", "Меняйте язык вручную в любое время."],
        "chatPrompt": "Я заблудился в лесу, телефон почти разряжен.",
    },
    {
        "appLocale": "ar",
        "appleLocale": "ar-SA",
        "displayName": "العربية",
        "appName": "Beacon Survival SOS",
        "subtitle": "ذكاء طوارئ بلا اتصال",
        "promotionalText": "إرشاد طوارئ باستخدام Gemma على الجهاز، معرفة سلامة عامة بلا اتصال، مساعدة بصرية، ومراجع واضحة.",
        "keywords": "طوارئ,نجاة,إسعاف,كارثة,ذكاء اصطناعي,أمان",
        "description": "Beacon Survival SOS مساعد طوارئ يعمل بلا اتصال للحظات التي تنقطع فيها الشبكة وتصبح كل ثانية مهمة.\n\nيشغل Beacon نموذج Gemma على iPhone ويبحث في معرفة السلامة العامة المدمجة قبل الرد. يساعدك على ترتيب الخطوات التالية في النجاة خارج المنزل، الكوارث، الإصابات، الحروق، النزيف، الاحتماء من الإشعاع، انقطاع الكهرباء وغيرها من الأزمات.\n\nالميزات الرئيسية:\n- إرشاد Gemma على الجهاز\n- بحث بلا اتصال في مصادر السلامة العامة\n- مساعدة بصرية بالكاميرا أو الصور\n- مراجع لمعلومات طبية ومعلومات سلامة عامة\n- واجهة بسيطة بأزرار طوارئ كبيرة\n- 20 لغة واجهة مع دعم RTL\n- لا حساب، لا استدلال سحابي، لا إعلانات، لا تتبع\n\nBeacon لا يستبدل خدمات الطوارئ أو الرعاية الطبية أو فرق الإنقاذ أو التعليمات الرسمية. عند توفر الاتصال، تواصل مع خدمات الطوارئ المحلية أو المختصين.",
        "releaseNotes": "Beacon 0.2.27 يحسن إصدار iOS لمتجر App Store، حزمة Gemma المحلية، المساعدة البصرية، عرض المراجع، وتجربة الدردشة والتنقل بلا اتصال.",
        "screenshotCaptions": ["ابدأ بسرعة عندما تكون كل ثانية مهمة.", "إرشاد Gemma محلي مع مصادر واضحة.", "استخدم الكاميرا أو الصور للمساعدة البصرية.", "بدّل اللغة يدوياً في أي وقت."],
        "chatPrompt": "أنا تائه في الغابة وبطارية الهاتف منخفضة.",
    },
    {
        "appLocale": "hi",
        "appleLocale": "hi",
        "displayName": "हिन्दी",
        "appName": "Beacon Survival SOS",
        "subtitle": "ऑफलाइन आपात AI",
        "promotionalText": "डिवाइस पर Gemma, ऑफलाइन सार्वजनिक सुरक्षा ज्ञान, दृश्य सहायता और स्रोत उद्धरणों वाला आपातकालीन सहायक।",
        "keywords": "आपात,जीवनरक्षा,प्राथमिक उपचार,आपदा,ऑफलाइन AI,सुरक्षा",
        "description": "Beacon Survival SOS उन क्षणों के लिए बनाया गया ऑफलाइन आपात सहायक है जब नेटवर्क न हो और हर सेकंड मायने रखता हो।\n\nBeacon iPhone पर Gemma चलाता है और उत्तर देने से पहले ऐप में मौजूद सार्वजनिक सुरक्षा जानकारी देखता है। यह जंगल में खो जाने, आपदा, चोट, जलन, खून बहने, विकिरण से बचाव, बिजली कटने और अन्य संकटों में अगले कदम सोचने में मदद करता है।\n\nमुख्य सुविधाएँ:\n- डिवाइस पर Gemma आपात मार्गदर्शन\n- ऑफलाइन सार्वजनिक सुरक्षा ज्ञान खोज\n- कैमरा या फोटो से दृश्य सहायता\n- चिकित्सा और सार्वजनिक सुरक्षा स्रोतों के उद्धरण\n- बड़े आपात बटन वाला सरल इंटरफेस\n- RTL सहित 20 UI भाषाएँ\n- कोई खाता नहीं, कोई क्लाउड अनुमान नहीं, कोई विज्ञापन नहीं, कोई ट्रैकिंग नहीं\n\nBeacon आपात सेवाओं, चिकित्सा देखभाल, बचाव कर्मियों या आधिकारिक निर्देशों का विकल्प नहीं है। संपर्क उपलब्ध हो तो स्थानीय आपात सेवा या योग्य विशेषज्ञ से संपर्क करें।",
        "releaseNotes": "Beacon 0.2.27 iOS App Store build, स्थानीय Gemma पैकेजिंग, दृश्य सहायता, स्रोत उद्धरण और ऑफलाइन चैट/नेविगेशन को सुधारता है।",
        "screenshotCaptions": ["हर सेकंड जरूरी हो तो तुरंत शुरू करें।", "स्रोतों के साथ स्थानीय Gemma मार्गदर्शन।", "कैमरा या फोटो से दृश्य सहायता।", "भाषा कभी भी हाथ से बदलें।"],
        "chatPrompt": "मैं जंगल में खो गया हूँ और फोन की बैटरी कम है।",
    },
    {
        "appLocale": "id",
        "appleLocale": "id",
        "displayName": "Bahasa Indonesia",
        "appName": "Beacon Survival SOS",
        "subtitle": "AI darurat offline",
        "promotionalText": "Panduan darurat Gemma lokal dengan pengetahuan keselamatan publik offline, bantuan visual, dan kutipan sumber.",
        "keywords": "darurat,bertahan hidup,pertolongan pertama,bencana,AI offline,aman",
        "description": "Beacon Survival SOS adalah asisten darurat offline untuk saat jaringan tidak tersedia dan setiap detik penting.\n\nBeacon menjalankan Gemma di iPhone dan mencari pengetahuan keselamatan publik bawaan sebelum menjawab. Aplikasi ini membantu memikirkan langkah berikutnya dalam situasi bertahan hidup di alam, bencana, cedera, luka bakar, perdarahan, perlindungan radiasi, listrik padam, dan krisis lain.\n\nFitur utama:\n- Panduan darurat Gemma di perangkat\n- Pencarian pengetahuan keselamatan publik offline\n- Bantuan visual lewat kamera atau foto\n- Kutipan sumber medis dan keselamatan publik\n- Antarmuka sederhana dengan tombol darurat besar\n- 20 bahasa UI termasuk RTL\n- Tanpa akun, tanpa inferensi cloud, tanpa iklan, tanpa pelacakan\n\nBeacon bukan pengganti layanan darurat, perawatan medis, penyelamat, atau instruksi resmi. Saat komunikasi tersedia, hubungi layanan darurat lokal atau profesional yang memenuhi syarat.",
        "releaseNotes": "Beacon 0.2.27 meningkatkan build iOS App Store, paket Gemma lokal, bantuan visual, kutipan sumber, serta chat/navigasi offline.",
        "screenshotCaptions": ["Mulai cepat saat setiap detik berarti.", "Panduan Gemma lokal dengan sumber.", "Gunakan kamera atau foto untuk bantuan visual.", "Ubah bahasa secara manual kapan saja."],
        "chatPrompt": "Saya tersesat di hutan dan baterai ponsel hampir habis.",
    },
    {
        "appLocale": "it",
        "appleLocale": "it",
        "displayName": "Italiano",
        "appName": "Beacon Survival SOS",
        "subtitle": "IA emergenza offline",
        "promotionalText": "Guida d'emergenza con Gemma locale, conoscenza pubblica offline, aiuto visivo e citazioni visibili.",
        "keywords": "emergenza,sopravvivenza,primo soccorso,disastro,IA offline,sicurezza",
        "description": "Beacon Survival SOS è un assistente di emergenza offline per i momenti senza rete in cui ogni secondo conta.\n\nBeacon esegue Gemma su iPhone e consulta conoscenze pubbliche integrate prima di rispondere. Aiuta a ragionare sui prossimi passi in sopravvivenza all'aperto, disastri, ferite, ustioni, sanguinamento, riparo da radiazioni, blackout e altre crisi.\n\nFunzioni principali:\n- Guida Gemma sul dispositivo\n- Ricerca offline in fonti di sicurezza pubblica\n- Aiuto visivo con fotocamera o foto\n- Citazioni di fonti mediche e di sicurezza pubblica\n- Interfaccia semplice con grandi pulsanti di emergenza\n- 20 lingue UI incluso RTL\n- Nessun account, nessuna inferenza cloud, nessuna pubblicità, nessun tracciamento\n\nBeacon non sostituisce servizi di emergenza, cure mediche, soccorritori o istruzioni ufficiali. Quando la comunicazione è disponibile, contatta i servizi locali o professionisti qualificati.",
        "releaseNotes": "Beacon 0.2.27 migliora la build iOS App Store, il pacchetto Gemma locale, l'aiuto visivo, le citazioni visibili e chat/navigazione offline.",
        "screenshotCaptions": ["Parti subito quando ogni secondo conta.", "Guida Gemma locale con fonti citate.", "Usa fotocamera o foto per aiuto visivo.", "Cambia lingua manualmente quando vuoi."],
        "chatPrompt": "Mi sono perso nel bosco e il telefono ha poca batteria.",
    },
    {
        "appLocale": "tr",
        "appleLocale": "tr",
        "displayName": "Türkçe",
        "appName": "Beacon Survival SOS",
        "subtitle": "Çevrimdışı acil AI",
        "promotionalText": "Yerel Gemma, çevrimdışı kamu güvenliği bilgisi, görsel yardım ve görünür kaynaklarla acil durum rehberi.",
        "keywords": "acil,hayatta kalma,ilk yardım,afet,çevrimdışı AI,güvenlik",
        "description": "Beacon Survival SOS, ağ olmadığında ve her saniye önemli olduğunda kullanılan çevrimdışı bir acil durum yardımcısıdır.\n\nBeacon, Gemma'yı iPhone üzerinde çalıştırır ve yanıtlamadan önce uygulamadaki kamu güvenliği bilgisini arar. Doğada kaybolma, afet, yaralanma, yanık, kanama, radyasyondan korunma, elektrik kesintisi ve diğer krizlerde sonraki adımları düşünmeye yardımcı olur.\n\nÖne çıkanlar:\n- Cihaz üzerinde Gemma acil rehberliği\n- Çevrimdışı kamu güvenliği bilgisi arama\n- Kamera veya fotoğrafla görsel yardım\n- Tıbbi ve kamu güvenliği kaynaklarına atıflar\n- Büyük acil durum düğmeleriyle basit arayüz\n- RTL dahil 20 UI dili\n- Hesap yok, bulut çıkarımı yok, reklam yok, izleme yok\n\nBeacon acil servislerin, tıbbi bakımın, kurtarma ekiplerinin veya resmi talimatların yerine geçmez. İletişim varsa yerel acil servisler veya uzmanlarla iletişime geçin.",
        "releaseNotes": "Beacon 0.2.27 iOS App Store yapısını, yerel Gemma paketini, görsel yardımı, kaynak atıflarını ve çevrimdışı sohbet/navigasyonu iyileştirir.",
        "screenshotCaptions": ["Her saniye önemliyken hızlı başlayın.", "Kaynaklı yerel Gemma rehberliği.", "Görsel yardım için kamera veya fotoğraf kullanın.", "Dili istediğiniz zaman elle değiştirin."],
        "chatPrompt": "Ormanda kayboldum ve telefonumun pili az.",
    },
    {
        "appLocale": "vi",
        "appleLocale": "vi",
        "displayName": "Tiếng Việt",
        "appName": "Beacon Survival SOS",
        "subtitle": "AI khẩn cấp offline",
        "promotionalText": "Hướng dẫn khẩn cấp với Gemma chạy cục bộ, kiến thức an toàn offline, trợ giúp hình ảnh và trích dẫn nguồn.",
        "keywords": "khẩn cấp,sinh tồn,sơ cứu,thảm họa,AI offline,an toàn",
        "description": "Beacon Survival SOS là trợ lý khẩn cấp offline cho những lúc mất mạng và từng giây đều quan trọng.\n\nBeacon chạy Gemma trên iPhone và tra cứu kiến thức an toàn công cộng tích hợp trước khi trả lời. Ứng dụng giúp bạn suy nghĩ các bước tiếp theo khi sinh tồn ngoài trời, gặp thảm họa, chấn thương, bỏng, chảy máu, trú ẩn bức xạ, mất điện và các khủng hoảng khác.\n\nTính năng chính:\n- Hướng dẫn khẩn cấp Gemma trên thiết bị\n- Tra cứu kiến thức an toàn công cộng offline\n- Trợ giúp hình ảnh bằng camera hoặc ảnh\n- Trích dẫn nguồn y tế và an toàn công cộng\n- Giao diện đơn giản với nút khẩn cấp lớn\n- 20 ngôn ngữ UI gồm RTL\n- Không tài khoản, không suy luận đám mây, không quảng cáo, không theo dõi\n\nBeacon không thay thế dịch vụ khẩn cấp, chăm sóc y tế, lực lượng cứu hộ hoặc hướng dẫn chính thức. Khi có liên lạc, hãy gọi dịch vụ khẩn cấp địa phương hoặc chuyên gia đủ năng lực.",
        "releaseNotes": "Beacon 0.2.27 cải thiện bản iOS App Store, đóng gói Gemma cục bộ, trợ giúp hình ảnh, trích dẫn nguồn và chat/điều hướng offline.",
        "screenshotCaptions": ["Bắt đầu nhanh khi từng giây quan trọng.", "Hướng dẫn Gemma cục bộ có nguồn.", "Dùng camera hoặc ảnh để trợ giúp hình ảnh.", "Đổi ngôn ngữ thủ công bất cứ lúc nào."],
        "chatPrompt": "Tôi bị lạc trong rừng và điện thoại sắp hết pin.",
    },
    {
        "appLocale": "th",
        "appleLocale": "th",
        "displayName": "ไทย",
        "appName": "Beacon Survival SOS",
        "subtitle": "AI ฉุกเฉินออฟไลน์",
        "promotionalText": "คำแนะนำฉุกเฉินด้วย Gemma บนอุปกรณ์ ความรู้ความปลอดภัยออฟไลน์ ความช่วยเหลือจากภาพ และแหล่งอ้างอิงชัดเจน",
        "keywords": "ฉุกเฉิน,เอาชีวิตรอด,ปฐมพยาบาล,ภัยพิบัติ,AI ออฟไลน์,ปลอดภัย",
        "description": "Beacon Survival SOS คือผู้ช่วยฉุกเฉินแบบออฟไลน์สำหรับช่วงเวลาที่ไม่มีเครือข่ายและทุกวินาทีมีความสำคัญ\n\nBeacon ใช้ Gemma บน iPhone และค้นหาความรู้ด้านความปลอดภัยสาธารณะที่ฝังไว้ก่อนตอบ ช่วยจัดลำดับขั้นตอนในสถานการณ์หลงป่า ภัยพิบัติ บาดเจ็บ ไฟไหม้ เลือดออก การหลบภัยจากรังสี ไฟดับ และวิกฤตอื่น ๆ\n\nคุณสมบัติหลัก:\n- คำแนะนำฉุกเฉิน Gemma บนอุปกรณ์\n- ค้นหาความรู้ความปลอดภัยสาธารณะแบบออฟไลน์\n- ความช่วยเหลือจากกล้องหรือรูปภาพ\n- อ้างอิงแหล่งข้อมูลทางการแพทย์และความปลอดภัย\n- หน้าจอเรียบง่ายพร้อมปุ่มฉุกเฉินขนาดใหญ่\n- 20 ภาษา UI รวม RTL\n- ไม่ต้องมีบัญชี ไม่ใช้คลาวด์ ไม่มีโฆษณา ไม่ติดตาม\n\nBeacon ไม่ใช่สิ่งทดแทนบริการฉุกเฉิน การรักษาพยาบาล เจ้าหน้าที่กู้ภัย หรือคำแนะนำทางการ เมื่อมีสัญญาณ ให้ติดต่อบริการฉุกเฉินหรือผู้เชี่ยวชาญในพื้นที่",
        "releaseNotes": "Beacon 0.2.27 ปรับปรุงบิลด์ iOS App Store แพ็กเกจ Gemma บนอุปกรณ์ ความช่วยเหลือจากภาพ การแสดงแหล่งอ้างอิง และแชท/นำทางออฟไลน์",
        "screenshotCaptions": ["เริ่มได้เร็วเมื่อทุกวินาทีสำคัญ", "คำแนะนำ Gemma บนอุปกรณ์พร้อมแหล่งอ้างอิง", "ใช้กล้องหรือรูปภาพเพื่อช่วยดูสถานการณ์", "เปลี่ยนภาษาเองได้ทุกเวลา"],
        "chatPrompt": "ฉันหลงอยู่ในป่าและแบตโทรศัพท์ใกล้หมด",
    },
    {
        "appLocale": "nl",
        "appleLocale": "nl-NL",
        "displayName": "Nederlands",
        "appName": "Beacon Survival SOS",
        "subtitle": "Offline noodhulp-AI",
        "promotionalText": "Noodhulp met lokale Gemma, offline publieke veiligheidskennis, visuele hulp en zichtbare bronvermeldingen.",
        "keywords": "nood,overleven,eerste hulp,ramp,offline AI,veiligheid",
        "description": "Beacon Survival SOS is een offline noodassistent voor momenten zonder netwerk waarin elke seconde telt.\n\nBeacon draait Gemma op je iPhone en raadpleegt ingebouwde publieke veiligheidskennis voordat het antwoord geeft. Het helpt bij buiten overleven, rampen, letsel, brandwonden, bloedingen, stralingsschuilen, stroomuitval en andere crisissituaties.\n\nBelangrijkste functies:\n- Gemma-noodhulp op het apparaat\n- Offline zoeken in publieke veiligheidsbronnen\n- Visuele hulp met camera of foto's\n- Bronvermeldingen voor medische en veiligheidsinformatie\n- Eenvoudige interface met grote noodknoppen\n- 20 UI-talen inclusief RTL\n- Geen account, geen cloud-inferentie, geen advertenties, geen tracking\n\nBeacon vervangt geen hulpdiensten, medische zorg, reddingsprofessionals of officiële instructies. Als communicatie beschikbaar is, neem contact op met lokale hulpdiensten of gekwalificeerde professionals.",
        "releaseNotes": "Beacon 0.2.27 verbetert de iOS App Store-build, lokale Gemma-verpakking, visuele hulp, zichtbare bronnen en offline chat/navigatie.",
        "screenshotCaptions": ["Begin snel wanneer elke seconde telt.", "Lokale Gemma-hulp met bronnen.", "Gebruik camera of foto's voor visuele hulp.", "Wijzig de taal handmatig wanneer je wilt."],
        "chatPrompt": "Ik ben verdwaald in het bos en mijn telefoon heeft weinig batterij.",
    },
    {
        "appLocale": "pl",
        "appleLocale": "pl",
        "displayName": "Polski",
        "appName": "Beacon Survival SOS",
        "subtitle": "Awaryjna AI offline",
        "promotionalText": "Pomoc awaryjna z lokalną Gemma, wiedzą bezpieczeństwa offline, pomocą wizualną i widocznymi źródłami.",
        "keywords": "awaria,przetrwanie,pierwsza pomoc,katastrofa,AI offline,bezpieczeństwo",
        "description": "Beacon Survival SOS to offline'owy asystent awaryjny na chwile bez sieci, gdy liczy się każda sekunda.\n\nBeacon uruchamia Gemma na iPhonie i przed odpowiedzią przeszukuje wbudowaną wiedzę z zakresu bezpieczeństwa publicznego. Pomaga uporządkować kolejne kroki podczas przetrwania w terenie, katastrof, urazów, oparzeń, krwawienia, schronienia przed promieniowaniem, awarii prądu i innych kryzysów.\n\nNajważniejsze funkcje:\n- Wskazówki Gemma na urządzeniu\n- Offline wyszukiwanie w źródłach bezpieczeństwa publicznego\n- Pomoc wizualna z aparatu lub zdjęć\n- Cytowania źródeł medycznych i publicznych\n- Prosty interfejs z dużymi przyciskami awaryjnymi\n- 20 języków UI, w tym RTL\n- Bez konta, bez chmury, bez reklam, bez śledzenia\n\nBeacon nie zastępuje służb ratunkowych, opieki medycznej, ratowników ani oficjalnych instrukcji. Gdy komunikacja jest dostępna, skontaktuj się z lokalnymi służbami lub specjalistami.",
        "releaseNotes": "Beacon 0.2.27 ulepsza build iOS App Store, lokalne pakowanie Gemma, pomoc wizualną, widoczne źródła oraz offline chat/nawigację.",
        "screenshotCaptions": ["Zacznij szybko, gdy liczy się każda sekunda.", "Lokalna Gemma z podanymi źródłami.", "Użyj aparatu lub zdjęć do pomocy wizualnej.", "Zmień język ręcznie w każdej chwili."],
        "chatPrompt": "Zgubiłem się w lesie, a telefon ma mało baterii.",
    },
    {
        "appLocale": "uk",
        "appleLocale": "uk",
        "displayName": "Українська",
        "appName": "Beacon Survival SOS",
        "subtitle": "Офлайн AI для НС",
        "promotionalText": "Екстрені підказки з локальною Gemma, офлайн-знаннями безпеки, візуальною допомогою та посиланнями на джерела.",
        "keywords": "екстрено,виживання,перша допомога,катастрофа,офлайн AI,безпека",
        "description": "Beacon Survival SOS — офлайн-помічник для надзвичайних ситуацій, коли немає мережі й важлива кожна секунда.\n\nBeacon запускає Gemma на iPhone і перед відповіддю звертається до вбудованих матеріалів громадської безпеки. Він допомагає продумати дії під час виживання на природі, катастроф, травм, опіків, кровотечі, радіаційного укриття, відключення електрики та інших криз.\n\nОсновні можливості:\n- Екстрені підказки Gemma на пристрої\n- Офлайн-пошук у джерелах громадської безпеки\n- Візуальна допомога з камери або фото\n- Посилання на медичні та безпекові джерела\n- Простий інтерфейс із великими екстреними кнопками\n- 20 мов UI, зокрема RTL\n- Без акаунта, без хмарного виводу, без реклами, без відстеження\n\nBeacon не замінює екстрені служби, медичну допомогу, рятувальників або офіційні інструкції. Якщо зв'язок доступний, зверніться до місцевих служб або кваліфікованих фахівців.",
        "releaseNotes": "Beacon 0.2.27 покращує iOS App Store build, локальне пакування Gemma, візуальну допомогу, видимі джерела та офлайн-чат/навігацію.",
        "screenshotCaptions": ["Починайте швидко, коли важлива кожна секунда.", "Локальна Gemma з посиланнями на джерела.", "Камера або фото для візуальної допомоги.", "Мову можна змінити вручну будь-коли."],
        "chatPrompt": "Я заблукав у лісі, телефон майже розряджений.",
    },
]


def ensure_dirs() -> None:
    LOCALIZATION_DIR.mkdir(parents=True, exist_ok=True)
    METADATA_ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
    RAW_SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)


def normalized_record(record: dict[str, Any]) -> dict[str, Any]:
    screenshot_files = [f"{slug}.png" for slug, _ in SCREENSHOT_STATES]
    return {
        "appLocale": record["appLocale"],
        "appleLocale": record["appleLocale"],
        "displayName": record["displayName"],
        "appName": record["appName"],
        "subtitle": record["subtitle"],
        "promotionalText": record["promotionalText"],
        "description": record["description"],
        "keywords": record["keywords"],
        "releaseNotes": record["releaseNotes"].replace("0.2.27", APP_STORE_VERSION),
        "screenshotCaptions": record["screenshotCaptions"],
        "screenshotFiles": screenshot_files,
        "supportUrl": "https://github.com/wimi321/Beacon/issues",
        "marketingUrl": "https://github.com/wimi321/Beacon",
        "privacyPolicyUrl": "https://github.com/wimi321/Beacon/blob/main/docs/PRIVACY.md",
    }


def write_metadata_files(version: str = DEFAULT_APP_STORE_VERSION) -> None:
    global APP_STORE_VERSION
    APP_STORE_VERSION = version
    ensure_dirs()
    records = [normalized_record(record) for record in LOCALE_DATA]
    (LOCALIZATION_DIR / "app-store-localizations.json").write_text(
        json.dumps(records, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (METADATA_ARTIFACT_DIR / "app-store-localizations.json").write_text(
        json.dumps(records, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    for record in records:
        locale_dir = LOCALIZATION_DIR / record["appleLocale"]
        locale_dir.mkdir(parents=True, exist_ok=True)
        lines = [
            f"# {record['displayName']} ({record['appleLocale']})",
            "",
            f"App locale: `{record['appLocale']}`",
            "",
            "## App Store Fields",
            "",
            f"- App Name: {record['appName']}",
            f"- Subtitle: {record['subtitle']}",
            f"- Promotional Text: {record['promotionalText']}",
            f"- Keywords: {record['keywords']}",
            f"- Support URL: {record['supportUrl']}",
            f"- Marketing URL: {record['marketingUrl']}",
            f"- Privacy Policy URL: {record['privacyPolicyUrl']}",
            "",
            "## Description",
            "",
            record["description"],
            "",
            "## What's New",
            "",
            record["releaseNotes"],
            "",
            "## Screenshot Order",
            "",
        ]
        for idx, ((slug, state_name), caption) in enumerate(zip(SCREENSHOT_STATES, record["screenshotCaptions"]), start=1):
            lines.append(f"{idx}. `{slug}.png` — {state_name}: {caption}")
        lines.append("")
        (locale_dir / "metadata.md").write_text("\n".join(lines), encoding="utf-8")


def validate_metadata() -> list[str]:
    errors: list[str] = []
    seen_apple: set[str] = set()
    for record in [normalized_record(record) for record in LOCALE_DATA]:
        prefix = f"{record['appleLocale']}"
        if record["appleLocale"] in seen_apple:
            errors.append(f"{prefix}: duplicate Apple locale")
        seen_apple.add(record["appleLocale"])
        limits = {
            "appName": 30,
            "subtitle": 30,
            "promotionalText": 170,
            "keywords": 100,
            "description": 4000,
            "releaseNotes": 4000,
        }
        for field, limit in limits.items():
            value = str(record[field])
            if len(value) > limit:
                errors.append(f"{prefix}: {field} is {len(value)} chars, max {limit}")
        if len(record["screenshotCaptions"]) != len(SCREENSHOT_STATES):
            errors.append(f"{prefix}: screenshot caption count mismatch")
    return errors


def validate_screenshots(selected_locales: set[str] | None = None) -> list[str]:
    errors: list[str] = []
    try:
        from PIL import Image
    except Exception as exc:  # pragma: no cover
        return [f"Pillow unavailable: {exc}"]

    for record in LOCALE_DATA:
        if selected_locales is not None and record["appLocale"] not in selected_locales and record["appleLocale"] not in selected_locales:
            continue
        upload_dir = SCREENSHOT_DIR / record["appleLocale"] / "iphone-6.3"
        for slug, _ in SCREENSHOT_STATES:
            path = upload_dir / f"{slug}.png"
            if not path.exists():
                errors.append(f"missing screenshot: {path}")
                continue
            with Image.open(path) as image:
                if image.size != EXPECTED_SCREENSHOT_SIZE:
                    errors.append(f"{path}: expected {EXPECTED_SCREENSHOT_SIZE}, got {image.size}")
    return errors


def find_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def wait_for_server(port: int, timeout_seconds: int = 45) -> None:
    deadline = time.time() + timeout_seconds
    last_error: Exception | None = None
    while time.time() < deadline:
        try:
            conn = http.client.HTTPConnection("127.0.0.1", port, timeout=1.5)
            conn.request("GET", "/")
            response = conn.getresponse()
            response.read()
            conn.close()
            if response.status < 500:
                return
        except Exception as exc:  # noqa: PERF203
            last_error = exc
        time.sleep(0.5)
    raise RuntimeError(f"Vite server did not become ready on port {port}: {last_error}")


MOCK_BRIDGE_SCRIPT = r"""
(locale, chatPrompt) => {
  localStorage.setItem('beacon_locale', locale);
  const model = {
    id: 'gemma-4-e2b',
    tier: 'e2b',
    name: 'Gemma 4 E2B',
    localPath: 'models/gemma-4-e2b.litertlm',
    sizeLabel: '2B / Offline Rescue',
    isLoaded: true,
    isDownloaded: true,
    supportsImageInput: true,
    supportsVision: true,
    downloadStatus: 'succeeded',
    artifactFormat: 'litertlm',
    runtimeStack: 'litert-lm-c-api',
    preferredBackend: 'gpu'
  };
  const copy = {
    'zh-CN': '先停下，节省电量，确认周围是否有水、风、崖边或坠落风险。\n\n1. 找到能挡风避雨的位置，保持身体温暖。\n2. 不要盲目下山或穿越陌生溪沟。\n3. 用衣物、灯光或声音做明显求救标记。\n\n如果有人受伤、失温、天快黑或天气恶化，优先原地避险并等待救援。',
    'zh-TW': '先停下，節省電量，確認周圍是否有水、風、崖邊或墜落風險。\n\n1. 找到能擋風避雨的位置，保持身體溫暖。\n2. 不要盲目下山或穿越陌生溪溝。\n3. 用衣物、燈光或聲音做明顯求救標記。\n\n如果有人受傷、失溫、天快黑或天氣惡化，優先原地避險並等待救援。',
    ja: 'まず立ち止まり、電池を節約し、転落・水・風・寒さの危険を確認してください。\n\n1. 風雨を避けられる場所で体温を守ります。\n2. 知らない沢や斜面へ無理に進まないでください。\n3. 衣類、ライト、音で見つけやすい合図を作ります。\n\nけが、低体温、日没、天候悪化がある場合は、その場で安全を確保して救助を待ちます。',
    ko: '먼저 멈추고 배터리를 아끼며 추락, 물, 바람, 저체온 위험을 확인하세요.\n\n1. 비와 바람을 피할 수 있는 곳에서 체온을 유지합니다.\n2. 낯선 계곡이나 비탈을 무리하게 내려가지 마세요.\n3. 옷, 불빛, 소리로 구조 신호를 눈에 띄게 만드세요.\n\n부상, 저체온, 해질녘, 악천후가 있으면 이동보다 안전한 대기와 구조 요청이 우선입니다.',
    es: 'Detente primero, ahorra bateria y revisa riesgos de caida, agua, viento o frio.\n\n1. Busca un punto que te proteja de viento y lluvia.\n2. No bajes a ciegas por barrancos o arroyos desconocidos.\n3. Marca tu posicion con ropa, luz o sonido.\n\nSi hay lesion, hipotermia, anochece o empeora el clima, prioriza refugio y espera ayuda.',
    fr: 'Arrêtez-vous d’abord, économisez la batterie et vérifiez les risques de chute, d’eau, de vent ou de froid.\n\n1. Cherchez un endroit abrité du vent et de la pluie.\n2. Ne descendez pas au hasard dans un ravin ou un ruisseau inconnu.\n3. Signalez votre position avec un vêtement, une lumière ou un son.\n\nEn cas de blessure, d’hypothermie, de nuit proche ou de mauvais temps, abritez-vous et attendez les secours.',
    de: 'Bleib zuerst stehen, spare Akku und prüfe Sturz-, Wasser-, Wind- und Kälterisiken.\n\n1. Suche Schutz vor Wind und Regen.\n2. Gehe nicht blind durch unbekannte Rinnen oder Bachläufe.\n3. Markiere deinen Standort mit Kleidung, Licht oder Geräuschen.\n\nBei Verletzung, Unterkühlung, Dunkelheit oder Wetterumschwung hat Schutz vor Weitergehen Priorität.',
    pt: 'Pare primeiro, economize bateria e verifique riscos de queda, água, vento ou frio.\n\n1. Procure um local protegido de vento e chuva.\n2. Não desça às cegas por encostas ou riachos desconhecidos.\n3. Marque sua posição com roupa, luz ou som.\n\nSe houver lesão, hipotermia, anoitecer ou piora do clima, priorize abrigo e aguarde ajuda.',
    ru: 'Сначала остановитесь, экономьте батарею и проверьте риск падения, воды, ветра и холода.\n\n1. Найдите место, защищенное от ветра и дождя.\n2. Не спускайтесь вслепую по неизвестным оврагам или ручьям.\n3. Обозначьте себя одеждой, светом или звуком.\n\nПри травме, переохлаждении, темноте или ухудшении погоды важнее укрыться и ждать помощи.',
    ar: 'توقف أولاً ووفّر البطارية وتحقق من مخاطر السقوط أو الماء أو الرياح أو البرد.\n\n1. ابحث عن مكان يحميك من الرياح والمطر.\n2. لا تتحرك عشوائياً في وادٍ أو مجرى ماء مجهول.\n3. اجعل موقعك واضحاً بقطعة قماش أو ضوء أو صوت.\n\nإذا كانت هناك إصابة أو برد شديد أو اقتراب الليل أو سوء طقس، فالأولوية للاحتماء وانتظار المساعدة.',
    hi: 'पहले रुकें, बैटरी बचाएँ और गिरने, पानी, हवा या ठंड के खतरे देखें।\n\n1. हवा और बारिश से बचाने वाली जगह खोजें।\n2. अनजान नाले या ढलान में अंधाधुंध न उतरें।\n3. कपड़े, रोशनी या आवाज से अपनी जगह दिखाएँ।\n\nचोट, ठंड, अंधेरा या खराब मौसम हो तो पहले सुरक्षित रहें और मदद का इंतजार करें।',
    id: 'Berhenti dulu, hemat baterai, lalu periksa risiko jatuh, air, angin, atau dingin.\n\n1. Cari tempat yang terlindung dari angin dan hujan.\n2. Jangan turun sembarangan lewat jurang atau aliran air yang tidak dikenal.\n3. Tandai posisi dengan kain, cahaya, atau suara.\n\nJika ada cedera, hipotermia, malam mendekat, atau cuaca memburuk, utamakan berlindung dan menunggu bantuan.',
    it: 'Fermati prima, risparmia batteria e controlla rischi di caduta, acqua, vento o freddo.\n\n1. Cerca un punto riparato da vento e pioggia.\n2. Non scendere alla cieca in canaloni o corsi d’acqua sconosciuti.\n3. Segnala la posizione con vestiti, luce o suoni.\n\nSe ci sono ferite, ipotermia, buio o maltempo, prima riparati e attendi aiuto.',
    tr: 'Önce dur, pili koru ve düşme, su, rüzgar ya da soğuk riskini kontrol et.\n\n1. Rüzgar ve yağmurdan koruyan bir yer bul.\n2. Bilmediğin dere yatağına veya yamaca körlemesine inme.\n3. Giysi, ışık veya sesle yerini belirginleştir.\n\nYaralanma, hipotermi, karanlık veya kötü hava varsa önce sığın ve yardım bekle.',
    vi: 'Dừng lại trước, tiết kiệm pin và kiểm tra nguy cơ ngã, nước, gió hoặc lạnh.\n\n1. Tìm nơi tránh gió và mưa.\n2. Đừng đi xuống suối hoặc dốc lạ một cách mù quáng.\n3. Đánh dấu vị trí bằng quần áo, ánh sáng hoặc âm thanh.\n\nNếu có chấn thương, hạ thân nhiệt, trời tối hoặc thời tiết xấu, hãy trú ẩn và chờ trợ giúp.',
    th: 'หยุดก่อน ประหยัดแบตเตอรี่ และตรวจดูความเสี่ยงจากการตก น้ำ ลม หรือความหนาว\n\n1. หาที่หลบลมและฝน\n2. อย่าลงทางลาดหรือร่องน้ำที่ไม่รู้จักแบบสุ่ม\n3. ทำสัญญาณตำแหน่งด้วยเสื้อผ้า แสง หรือเสียง\n\nถ้ามีบาดเจ็บ หนาวจัด ใกล้มืด หรืออากาศแย่ ให้หลบภัยและรอความช่วยเหลือก่อน',
    nl: 'Stop eerst, spaar batterij en controleer risico op vallen, water, wind of kou.\n\n1. Zoek beschutting tegen wind en regen.\n2. Daal niet blind af door onbekende geulen of beken.\n3. Markeer je plek met kleding, licht of geluid.\n\nBij letsel, onderkoeling, donker worden of slecht weer: schuilen en hulp afwachten.',
    pl: 'Najpierw się zatrzymaj, oszczędzaj baterię i sprawdź ryzyko upadku, wody, wiatru lub zimna.\n\n1. Znajdź osłonę przed wiatrem i deszczem.\n2. Nie schodź na ślepo w nieznane jary lub strumienie.\n3. Oznacz pozycję ubraniem, światłem albo dźwiękiem.\n\nPrzy urazie, wychłodzeniu, zmroku lub złej pogodzie najpierw schronienie i czekanie na pomoc.',
    uk: 'Спершу зупиніться, заощаджуйте батарею і перевірте ризики падіння, води, вітру чи холоду.\n\n1. Знайдіть місце, захищене від вітру й дощу.\n2. Не спускайтеся навмання в невідомі яри чи потоки.\n3. Позначте себе одягом, світлом або звуком.\n\nЯкщо є травма, переохолодження, сутінки або погана погода, спершу сховайтеся й чекайте допомоги.',
    en: 'Stop first, save battery, and check for fall, water, wind, or cold exposure risks.\n\n1. Move to a spot that blocks wind and rain.\n2. Do not blindly descend into unknown ravines or stream beds.\n3. Mark your position with clothing, light, or sound.\n\nIf anyone is injured, hypothermic, night is coming, or weather is worsening, shelter and wait for rescue.'
  };
  function localizedText(request) {
    return copy[request.locale] || copy[locale] || copy.en;
  }
  function evidence() {
    return {
      authoritative: [{
        id: 'store-demo-nps-ten-essentials',
        sourceId: 'nps-ten-essentials',
        title: 'Ten Essentials',
        source: 'National Park Service',
        sourceUrl: 'https://www.nps.gov/articles/10essentials.htm',
        summary: 'Trip planning, emergency shelter, signaling, and first aid basics.',
        steps: [],
        contraindications: [],
        escalation: '',
        strategy: 'directRule',
        score: 1
      }],
      supporting: [],
      matchedCategories: ['survival_field'],
      queryTerms: ['lost', 'shelter', 'signal']
    };
  }
  window.beaconBridge = {
    initialize: async () => undefined,
    listModels: async () => [model],
    loadModel: async () => [model],
    downloadModel: async function* () { yield { modelId: model.id, progress: 1, status: 'succeeded' }; },
    cancelActiveInference: async () => undefined,
    getBatteryStatus: async () => ({ level: 0.72, isLowPowerMode: false, forcedPowerMode: 'normal' }),
    setPowerMode: async (mode) => ({ level: 0.72, isLowPowerMode: mode === 'doomsday', forcedPowerMode: mode }),
    getRuntimeDiagnostics: async () => ({
      platform: 'ios', loadedModelId: model.id, isLoaded: true, activeBackend: 'gpu', activeVisionBackend: 'gpu',
      acceleratorFamily: 'metal', runtimeStack: 'litert-lm-c-api', artifactFormat: 'litertlm', capabilityClass: 'supported',
      gpuEligible: true, gpuWarmupPassed: true, gpuWarmupAttempted: true, gpuBlockedReason: '', supportedDeviceClass: 'iphone_primary',
      preferredBackend: 'gpu', visionArtifactValid: true, visionArtifactReason: 'App Store screenshot bridge', visionInputMode: 'imageUri'
    }),
    triage: async (request) => {
      const text = localizedText(request);
      return { summary: text, steps: [], disclaimer: '', isKnowledgeBacked: true, guidanceMode: 'grounded', evidence: evidence(), usedProfileName: model.name };
    },
    analyzeVisual: async (request) => {
      const text = localizedText(request);
      return { summary: text, steps: [], disclaimer: '', isKnowledgeBacked: true, guidanceMode: 'grounded', evidence: evidence(), usedProfileName: model.name };
    },
    triageStream: async function* (request) {
      const text = localizedText(request);
      const chunks = text.match(/(\n\n|\n|.{1,18})/gs) || [text];
      for (const chunk of chunks) {
        await new Promise((resolve) => setTimeout(resolve, 18));
        yield { delta: chunk };
      }
      yield { delta: '', done: true, final: { summary: text, steps: [], disclaimer: '', isKnowledgeBacked: true, guidanceMode: 'grounded', evidence: evidence(), usedProfileName: model.name } };
    },
    toggleSos: async () => ({ active: false, connectedPeers: 0 })
  };
}
"""


async def capture_screenshots(port: int, selected_locales: set[str] | None = None) -> None:
    try:
        from playwright.async_api import async_playwright
    except Exception as exc:  # pragma: no cover
        raise RuntimeError(
            "Python Playwright is required. Install it with: python3 -m pip install playwright && python3 -m playwright install chromium"
        ) from exc

    records = [record for record in LOCALE_DATA if selected_locales is None or record["appLocale"] in selected_locales or record["appleLocale"] in selected_locales]
    if not records:
        raise RuntimeError("No matching locales selected.")

    async with async_playwright() as p:
        try:
            browser = await p.chromium.launch(headless=True, channel="chrome")
        except Exception:
            browser = await p.chromium.launch(headless=True)
        try:
            for record in records:
                context = await browser.new_context(
                    viewport=VIEWPORT,
                    device_scale_factor=DEVICE_SCALE_FACTOR,
                    is_mobile=True,
                    has_touch=True,
                    locale=record["appLocale"].replace("_", "-"),
                )
                init_script = (
                    f"({MOCK_BRIDGE_SCRIPT})("
                    f"{json.dumps(record['appLocale'], ensure_ascii=False)}, "
                    f"{json.dumps(record['chatPrompt'], ensure_ascii=False)}"
                    ");"
                )
                await context.add_init_script(init_script)
                page = await context.new_page()
                page.set_default_timeout(20_000)
                base_url = f"http://127.0.0.1:{port}"
                raw_dir = RAW_SCREENSHOT_DIR / record["appleLocale"]
                upload_dir = SCREENSHOT_DIR / record["appleLocale"] / "iphone-6.3"
                raw_dir.mkdir(parents=True, exist_ok=True)
                upload_dir.mkdir(parents=True, exist_ok=True)

                async def fresh_page() -> None:
                    await page.goto(base_url, wait_until="networkidle")
                    await page.wait_for_selector(".panic-btn", state="visible")
                    await page.wait_for_timeout(500)

                async def save(slug: str) -> None:
                    raw_path = raw_dir / f"{slug}.png"
                    upload_path = upload_dir / f"{slug}.png"
                    await page.screenshot(path=str(raw_path), full_page=False)
                    raw_path.replace(upload_path)

                await fresh_page()
                await save("01-home")

                await fresh_page()
                await page.locator(".panic-btn").first.click()
                await page.wait_for_selector(".message.ai", state="visible")
                try:
                    await page.wait_for_selector(".streaming-indicator", state="detached", timeout=12_000)
                except Exception:
                    await page.wait_for_timeout(2_000)
                await page.wait_for_timeout(700)
                await save("02-chat")

                await fresh_page()
                await page.locator(".viewfinder-btn").click()
                await page.wait_for_selector(".visual-picker-panel", state="visible")
                await page.wait_for_timeout(500)
                await save("03-visual")

                await fresh_page()
                await page.locator(".language-trigger").click()
                await page.wait_for_selector(".language-menu", state="visible")
                await page.wait_for_timeout(500)
                await save("04-language")

                await context.close()
                print(f"screenshots: {record['appleLocale']} -> {upload_dir}")
        finally:
            await browser.close()


@dataclass
class ViteServer:
    process: subprocess.Popen[str]
    port: int

    def stop(self) -> None:
        if self.process.poll() is not None:
            return
        self.process.terminate()
        try:
            self.process.wait(timeout=8)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=5)


def start_vite() -> ViteServer:
    port = find_free_port()
    env = os.environ.copy()
    env.setdefault("BROWSER", "none")
    command = ["npm", "run", "dev", "--", "--host", "127.0.0.1", "--port", str(port)]
    process = subprocess.Popen(
        command,
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    wait_for_server(port)
    return ViteServer(process=process, port=port)


def write_readme(version: str = DEFAULT_APP_STORE_VERSION) -> None:
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    locale_table = "\n".join(
        f"| `{record['appleLocale']}` | {record['displayName']} | `{record['appLocale']}` |"
        for record in LOCALE_DATA
    )
    readme = f"""# App Store Localization Package\n\nBeacon supports region-specific App Store listings. This package keeps App Store Connect copy and screenshot generation reproducible instead of relying on manual copy/paste.\n\n## Locales\n\n| Apple Locale | Store Language | App Locale |\n| --- | --- | --- |\n{locale_table}\n\n## Generate Metadata\n\n```bash\npython3 scripts/generate_app_store_localizations.py --metadata --version {version}\n```\n\nGenerated metadata is written to:\n\n- `docs/app-store/localizations/app-store-localizations.json`\n- `docs/app-store/localizations/<apple-locale>/metadata.md`\n- `.artifacts/app-store-localization-package/metadata/app-store-localizations.json`\n\n## Generate Localized Screenshots\n\nInstall Python screenshot dependencies once, then render localized screenshots:\n\n```bash\npython3 -m pip install pillow playwright\npython3 -m playwright install chromium\npython3 scripts/generate_app_store_localizations.py --metadata --screenshots --version {version}\n```\n\nUpload-ready screenshots are written to:\n\n```text\n.artifacts/app-store-localization-package/screenshots/<apple-locale>/iphone-6.3/\n```\n\nEach locale gets four device-faithful iPhone screenshots:\n\n1. `01-home.png` — panic-first home screen\n2. `02-chat.png` — offline guidance with citations\n3. `03-visual.png` — camera/photo visual help picker\n4. `04-language.png` — manual language switcher\n\n## Validate\n\n```bash\npython3 scripts/validate_app_store_localizations.py\npython3 scripts/validate_app_store_localizations.py --screenshots\n```\n\nThe validator checks App Store field length limits and screenshot dimensions.\n\n## App Store Connect Workflow\n\n1. Open App Store Connect → Beacon Survival SOS → version metadata.\n2. Add each localization listed above.\n3. Copy fields from `metadata.md` or the combined JSON.\n4. Upload the matching screenshots from `.artifacts/app-store-localization-package/screenshots/<apple-locale>/iphone-6.3/`.\n5. Save and submit the metadata update.\n\nNotes:\n\n- China mainland should use `zh-Hans` metadata and Chinese screenshots.\n- Taiwan/Hong Kong/Macau should use `zh-Hant`.\n- U.S. should use `en-US`.\n- The description intentionally mentions citations and professional-care limitations to satisfy medical-information review expectations.\n"""
    (DOCS_DIR / "README.md").write_text(readme, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Beacon App Store localization metadata and screenshots.")
    parser.add_argument("--metadata", action="store_true", help="Write metadata JSON and per-locale markdown files.")
    parser.add_argument("--screenshots", action="store_true", help="Render localized upload-ready screenshots.")
    parser.add_argument("--validate", action="store_true", help="Validate generated metadata and optional screenshots.")
    parser.add_argument("--locale", action="append", help="Limit screenshot generation or screenshot validation to app or Apple locale code. Repeatable.")
    parser.add_argument("--version", default=DEFAULT_APP_STORE_VERSION, help="App Store version string used in localized release notes.")
    args = parser.parse_args()

    if not args.metadata and not args.screenshots and not args.validate:
        args.metadata = True

    ensure_dirs()
    global APP_STORE_VERSION
    APP_STORE_VERSION = args.version
    if args.metadata:
        write_metadata_files(args.version)
        write_readme(args.version)
        print(f"metadata: {LOCALIZATION_DIR}")

    if args.screenshots:
        server = start_vite()
        try:
            selected = set(args.locale) if args.locale else None
            asyncio.run(capture_screenshots(server.port, selected))
        finally:
            server.stop()

    if args.validate:
        selected = set(args.locale) if args.locale else None
        errors = validate_metadata()
        if args.screenshots:
            errors.extend(validate_screenshots(selected))
        if errors:
            for error in errors:
                print(f"ERROR: {error}", file=sys.stderr)
            return 1
        print("validation: ok")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
