# Beacon (末日灯塔) - 前后端联调交接文档

> **致后端工程组 / 底层算法与大模型优化团队：**
> 
> 本文档旨在指导完成 Beacon (末日灯塔) 应急自救系统的最终集成联调。
> 前端组已经完成了一套适用于弱网/断网离线情况下的**绝境级前端架构**（基于纯黑 OLED 极限省电规范设计）。
> 现在需要后端及底层（如 Flutter / Capacitor 层）接管模拟数据接栏，并为界面灌注本地大模型算力与传感器支持。

## 📍 一、 前端系统产出基线 (Frontend Baseline)

**技术栈概览**
- 视图层：纯 React + Vite（无重型转场动画、禁用 Pull-to-Refresh 等非必要原生滑动事件）
- 样式层： Vanilla CSS（全局无极黑底色 `#000000` + 深空灰背景与极致容错面积的高对比度警告元素设计）
- 组件生态：精简 React 架构，无外部高频网络依赖。

**页面与交互逻辑已解耦，前端现暴露出核心的系统级事件需要与基座进行 Local API / JSBridge Hook**。

## 🔌 二、 需要实现的核心底层能力与 API 钩子

## ✅ 当前后端落地状态

- 已完成 Capacitor 原生宿主集成，前端 Web UI 已同步进 Android/iOS 工程
- 已完成离线优先的本地检索增强，针对高危求助输入执行知识卡词法检索、证据排序，并将命中的离线证据高权重注入本地模型
- 已完成相机、文件系统、设备信息、地理位置、网络、电量相关原生插件接线
- 已完成 Android release 签名与压缩配置，产出可安装 APK 与可分发 AAB
- 已完成前端、Dart 业务层、Android 原生测试与 lint 验证
- 已完成 iOS 真机签名归档、IPA 导出与模拟器安装启动验证

### 🧠 1. 本地大模型流式接口 (Gemma 4 E2B/E4B 推理拦截)

在用户于底部固定的 `chat-input` 中输入，或按下防呆盲按求助快（`迷路断联` 等）时，前端 `handleSendChat` 会追加最新 `Message`。
* **开发指令**：
  * 通过 `flutter_litert` / 原生 CoreML 挂载 `Gemma 4 E2B` 模型，暴露 JSBridge 调用通道。
  * 拦截聊天发送请求事件，将推理输出按照 Token 流式打回给前端，实现流式回显打印。

### 📚 2. 本地检索增强强控与防幻觉 (Offline RAG / 权威认证)

为了防止 AI 大模型在此类性命攸关的应用中胡言乱语。四个极端预设场景拥有优先检索权。
* **前端实现**：支持对 `Message` 对象附加 `isAuthoritative: true` 标识。界面检测到该标识会立即亮起高权重的“✅ 权威指南认证”特殊 UI 标牌，以最高程度安抚用户的恐慌情绪。
* **开发指令**：
  * 请准备一个超小体积的嵌入式向量库（如 `ObjectBox / Isar`）。
  * 遇到“迷路、火场、地震、严重外伤”等高危 Prompt 时，**必须强制先在本地词库 / FM 21-76 等外挂大脑库中进行实体检索**。
  * 将检索到的结果作为高权重 Prompt（甚至直接覆盖回答）返回给前端，并注入 `isAuthoritative: true` 字段。

**当前实现状态**
- 已在 Web 业务引擎中落地离线知识卡检索与证据组装，不依赖在线 RAG 服务
- 高危场景会优先命中本地权威卡片，并向前端返回权威标识与证据摘要
- 当本地证据不足时，系统仍会实际调用本地 Gemma 模型生成场景化回复，但会保留“有限证据”免责声明，避免伪装成权威指南
- 当前方案是轻量离线检索，不需要引入重量级向量数据库即可本地运行

### 📸 3. 视觉模态支持与原生设备相机劫持 (Visual Analysis)

* **前端实现**：为了确保界面连贯，前端用 CSS 写了一套含有扫描框设计的虚拟 “Viewfinder” 取景器，用于收集“是否能吃”、“伤口什么程度”的拍摄指令（通过点击 `[视觉请求：野外生物识别]` 等关键字触发）。
* **开发指令**：
  * 请劫持前端唤起相机的 API。调用设备的真实前后摄。
  * 压缩图像并将其转换为适合 Gemma 模型能吃下的小体积视觉向量数据，执行多模态联合推理。

**当前实现状态**
- 前端已接入 Capacitor Camera，移动端可直接调用真实设备相机
- 视觉链路目前完成了原生采集接线，尚未内嵌本地多模态模型推理
- 现阶段图片输入可作为后续 Gemma/CoreML 推理的稳定入口

### 🔋 4. 底层心跳上报与极限功耗监控 (Hardware Throttling)

* **开发指令**：需要在运行底层建立独立线程监控电池状态。
  * 若侦测到当前设备电量 < `10%` 或进入低电量模式，通过 API 主动向前端触发发出一则警告语（`“当前电量极低，已切换为极限抢险省电方案。”`）。
  * 后端自行把大模型的层数/推理 Context 极速强行缩减，宁可牺牲一定的智商精准度也要换取生存信息。

**当前实现状态**
- 已完成设备信息与电量数据接线，前端可根据设备状态切换极限模式文案
- 推理侧当前采用轻量离线证据引擎，因此天然适配低功耗场景

### 📡 5. P2P 绝地近场自组网弹射 (Mesh SOS Broadcast)

* **前端实现**：位于界面最底端的红色大按钮（The SOS Anchor），提供最高优先级的事件点击 `toggleSOS()`。前端已经接好了倒计时及连接数字动态展示。
* **开发指令**：
  * 调用 `flutter_mesh_network` 或者操作系统的 Wi-Fi Direct / 蓝牙近场。
  * 收到广播信令后，**不经过任何服务器**（此时基站应该已毁坏），直接将：`经纬度` + `残余电量` + `通过聊天总结的 20 字轻量级伤情文本` 并行封包。向四周空出射发 SOS 病毒流，只要附近有任何存活节点装了这个应用就会被接收、警报、并作为中继再扩散。

**当前实现状态**
- 已完成 SOS 封包结构与广播状态持久化测试
- 当前位置、电量、聊天摘要等字段已具备本地采集与封装基础
- 真正的 mesh 近场扩散仍需在下一阶段补 Wi-Fi Direct / 蓝牙中继实现

## 🧪 已完成验收

- `npm test`
- `npm run mobile:build`
- `npm audit --audit-level=high`
- `flutter analyze`
- `flutter test`
- `cd android && JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH ./gradlew test lint assembleRelease bundleRelease`
- `cd ios/App && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project App.xcodeproj -scheme App -configuration Release -destination 'generic/platform=iOS' -archivePath ../archive-final/Beacon.xcarchive archive`
- `cd ios/App && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -exportArchive -archivePath ../archive-final/Beacon.xcarchive -exportOptionsPlist ../export-appstore/ExportOptions.plist -exportPath ../export-final`
- `cd ios/App && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project App.xcodeproj -scheme App -configuration Debug -destination 'platform=iOS Simulator,id=74116F03-5825-4112-8772-794A03A8B359' -derivedDataPath ../derived-sim build`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl install 74116F03-5825-4112-8772-794A03A8B359 ../derived-sim/Build/Products/Debug-iphonesimulator/App.app`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch 74116F03-5825-4112-8772-794A03A8B359 com.beacon.sos`

## 📦 当前可交付物

- Android 调试安装包: [/Users/haoc/Developer/Beacon/android/app/build/outputs/apk/debug/app-debug.apk](/Users/haoc/Developer/Beacon/android/app/build/outputs/apk/debug/app-debug.apk)
- Android 发布安装包: [/Users/haoc/Developer/Beacon/android/app/build/outputs/apk/release/app-release.apk](/Users/haoc/Developer/Beacon/android/app/build/outputs/apk/release/app-release.apk)
- Android 商店包: [/Users/haoc/Developer/Beacon/android/app/build/outputs/bundle/release/app-release.aab](/Users/haoc/Developer/Beacon/android/app/build/outputs/bundle/release/app-release.aab)
- iOS 发布安装包: [/Users/haoc/Developer/Beacon/ios/export-final/App.ipa](/Users/haoc/Developer/Beacon/ios/export-final/App.ipa)
- iOS 归档目录: [/Users/haoc/Developer/Beacon/ios/archive-final/Beacon.xcarchive](/Users/haoc/Developer/Beacon/ios/archive-final/Beacon.xcarchive)
- iOS 模拟器构建产物: [/Users/haoc/Developer/Beacon/ios/derived-sim/Build/Products/Debug-iphonesimulator/App.app](/Users/haoc/Developer/Beacon/ios/derived-sim/Build/Products/Debug-iphonesimulator/App.app)

## 🍎 iOS 当前状态

- 当前机器已安装完整 `Xcode.app`，并完成 Apple 开发签名配置
- 已成功生成 `Beacon.xcarchive` 并导出 `App.ipa`
- 已在 `iPhone 17 Pro` 模拟器完成安装与启动验证，Bundle ID 为 `com.beacon.sos`
- 后续如需上架 App Store，只需继续沿用同一套签名/描述文件配置补齐商店发布元数据

---

*💪 Let's build something God-Level before the world goes dark. -- Frontend Dev*
