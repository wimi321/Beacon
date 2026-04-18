# Beacon

<p align="center">
  <strong>Beacon macht aus einem Smartphone ein Offline-First-Notfallwerkzeug mit echter Gemma 4 Inferenz direkt auf dem Geraet.</strong>
</p>

<p align="center">
  Repository Docs:
  <a href="./README.md">English</a>
  ·
  <a href="./README.zh-CN.md">简体中文</a>
  ·
  <a href="./README.zh-TW.md">繁體中文</a>
  ·
  <a href="./README.ja.md">日本語</a>
  ·
  <a href="./README.ko.md">한국어</a>
  ·
  <a href="./README.es.md">Español</a>
  ·
  <a href="./README.fr.md">Français</a>
  ·
  <a href="./README.de.md">Deutsch</a>
  ·
  <a href="./README.pt.md">Português</a>
  ·
  <a href="./README.ar.md">العربية</a>
</p>

<p align="center">
  <a href="./docs/assets/beacon-demo-hero.mp4">
    <img src="./docs/assets/beacon-demo-hero.gif" alt="Beacon README demo" width="960">
  </a>
</p>

> Dieses README ist eine kurze deutschsprachige Einstiegsversion. Die vollstaendige und massgebliche technische Referenz bleibt [`README.md`](./README.md) auf Englisch.

## Download

- Das neueste Android-ARM64-APK von [GitHub Releases](https://github.com/wimi321/Beacon/releases) installieren
- Beim ersten Start `Settings & Models` oeffnen
- Zuerst `Gemma 4 E2B` als empfohlenes Modell laden; auf staerkeren Geraeten optional `Gemma 4 E4B`

Beacon nutzt einen schlanken Distributionsweg: kleines APK zuerst, das eigentliche Gemma-Modell danach direkt in der App.

## Warum Beacon

- echte On-Device-KI statt Cloud-Wrapper
- Offline-Retrieval aus medizinischen und Survival-Quellen
- mobile UI fuer Stress, Zeitdruck und geringe Aufmerksamkeit
- nativer Kamera- und lokaler Foto-Flow
- 20 UI-Sprachen mit manuellem Sprachwechsel und arabischem RTL
- Session-Memory, SOS und native Hooks fuer Akku, Ortung und Diagnostik

## Hauptfunktionen

- Text-Triage mit lokalem Gemma 4
- visuelle Hilfe ueber Kamera oder lokale Fotos
- Offline-Wissenssuche vor der Inferenz
- Gespraechsspeicher fuer Folgefragen
- native Android- und iOS-Shells im Repo

## Dokumentation

- Englisches Haupt-README: [`README.md`](./README.md)
- Vereinfachtes Chinesisch: [`README.zh-CN.md`](./README.zh-CN.md)
- Beitragshinweise: [`CONTRIBUTING.md`](./CONTRIBUTING.md), [`CONTRIBUTING.zh-CN.md`](./CONTRIBUTING.zh-CN.md)
- Sicherheitsrichtlinie: [`SECURITY.md`](./SECURITY.md), [`SECURITY.zh-CN.md`](./SECURITY.zh-CN.md)
- i18n-Hinweise: [`docs/I18N.md`](./docs/I18N.md), [`docs/I18N.zh-CN.md`](./docs/I18N.zh-CN.md)

## Schnellstart

```bash
npm install
npm run mobile:build
npm run mobile:android
npm run mobile:ios
```

Leichtes GitHub-Release-APK bauen:

```bash
npm run mobile:android:release:github
```

## Projektstatus

Beacon ist eine ernsthafte, lauffaehige oeffentliche Pre-Release. Kein Fake-Demo, aber auch noch kein fertiges Medizinprodukt.

Bereits vorhanden:

- native Android- und iOS-Projekte
- echte Gemma-4-Inferenz auf dem Geraet
- eingebundene Offline-Wissensbasis
- mehrsprachige UI
- Session-Memory und lokaler Bild-Flow

Wird weiter verstaerkt:

- breitere Tests auf echten Geraeten
- iOS GPU- / Runtime-Stabilisierung
- Mesh-Relay und erweiterte SOS-Wege
- Store-taugliches Packaging und Release-Finish
