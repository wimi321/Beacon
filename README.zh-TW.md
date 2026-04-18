# Beacon

<p align="center">
  <strong>一個離線優先的緊急求生與應急指引 App，核心依賴真實端側 Gemma 4 推理，而不是雲端聊天介面。</strong>
</p>

<p align="center">
  倉庫文件：
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
  <a href="./docs/assets/beacon-demo-hero-zh-TW.mp4">
    <img src="./docs/assets/beacon-demo-hero-zh-TW.gif" alt="Beacon README demo" width="960">
  </a>
</p>

> 這份 README 是繁體中文快速入口頁。更完整的技術細節與最新措辭，仍以英文版 [`README.md`](./README.md) 為主。

## 下載方式

- 從 [GitHub Releases](https://github.com/wimi321/Beacon/releases) 下載最新 Android ARM64 APK
- 首次開啟 App 後進入 `Settings & Models`
- 優先下載 `Gemma 4 E2B` 作為推薦預設模型；裝置更強時可再下載 `Gemma 4 E4B`

Beacon 採用輕量 APK 先安裝、模型在 App 內下載的方式，避免把超大模型直接塞進 GitHub 安裝包。

## 為什麼是 Beacon

- 真實端側 AI，不是雲端聊天包裝
- 內建離線醫療與野外求生知識庫檢索
- 為高壓、低注意力、斷網場景設計的傻瓜化 UI
- 支援相機與本機相簿圖片輸入
- 支援 20 種 UI 語言與阿拉伯語 RTL
- 保留會話記憶、SOS 封包與原生裝置能力

## 核心能力

- 文字急救與求生問答
- 拍照或導入照片後的本地視覺求助流程
- 先檢索離線知識，再做本地模型推理
- 會話摘要、最近輪次與視覺上下文記憶
- Android / iOS 原生殼已包含在倉庫中

## 文件入口

- 英文主 README：[`README.md`](./README.md)
- 簡體中文 README：[`README.zh-CN.md`](./README.zh-CN.md)
- 貢獻指南：[`CONTRIBUTING.zh-TW.md`](./CONTRIBUTING.zh-TW.md)、[`CONTRIBUTING.md`](./CONTRIBUTING.md)
- 安全策略：[`SECURITY.zh-TW.md`](./SECURITY.zh-TW.md)、[`SECURITY.md`](./SECURITY.md)
- 國際化說明：[`docs/I18N.md`](./docs/I18N.md)、[`docs/I18N.zh-CN.md`](./docs/I18N.zh-CN.md)

## 快速開始

```bash
npm install
npm run mobile:build
npm run mobile:android
npm run mobile:ios
```

Android GitHub 發布包可使用：

```bash
npm run mobile:android:release:github
```

## 專案狀態

Beacon 是一個認真可運行的公開預發布版本，不是假 Demo，但也還不是最終醫療產品。

已具備：

- Android / iOS 原生工程
- 端側 Gemma 4 推理鏈路
- 離線知識庫與檢索拼裝
- 多語言 UI
- 真機導向的移動端交互

仍在持續打磨：

- 更多真機驗證矩陣
- iOS runtime / GPU 路徑進一步收口
- Mesh 中繼與 SOS 擴展能力
- 商店級釋出包與發佈流程
