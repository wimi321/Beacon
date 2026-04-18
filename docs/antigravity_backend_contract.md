# Beacon 前后端对接契约

## 1. 初始化建议

前端启动后先完成以下步骤：

1. 初始化本地知识库实现，并灌入 `BootstrapModels.emergencySeedKnowledge()`。
2. 初始化 `LiteRtModelRuntime` 的真实适配器。
3. 使用 `BootstrapModels.gemma4E2b` 作为保底模型创建 `BeaconBackend`。
4. 只有在用户手动升级模型后，再调用 `modelManager.hotSwap()` 切到 E4B。

## 2. 急救分诊请求

调用入口：`BeaconBackend.triage()`

请求对象：`EmergencyRequest`

字段说明：

- `userText`: 用户描述，例如“手臂大出血，已经头晕”
- `imageBytes`: 可选，相机拍到的伤口或植物图片
- `locale`: 返回语言，默认 `zh-CN`
- `categoryHint`: 前端快捷按钮带过来的类别，例如 `snake bite`、`heavy bleeding`
- `powerMode`: `normal` 或 `doomsday`
- `includeRawPrompt`: 调试时可打开，生产环境建议关闭

## 3. 急救分诊响应

返回对象：`EmergencyResponse`

关键字段：

- `summary`: 一句话总结
- `steps`: 分步操作列表，按顺序展示给用户
- `knowledge`: 命中的本地知识条目，可用于显示“权威指南认证”
- `evidence`: 后端组装好的证据包，包含 authoritative/supporting/matchedCategories
- `disclaimer`: 固定安全提示
- `usedProfile`: 当前真正使用的推理配置
- `isKnowledgeBacked`: 是否命中本地知识
- `guidanceMode`: 当前统一为 `grounded`

前端展示建议：

- `isKnowledgeBacked == true` 时显示绿色认证盾牌
- 当 `isAuthoritative == false` 时，前端应展示“有限证据”级别提示，但回答内容仍来自真实本地模型而不是模板回退
- `steps[0..2]` 作为超高优先级步骤高亮
- `disclaimer` 始终固定在结果底部

## 4. SOS 广播

调用入口：`BeaconBackend.broadcastSos()`

传入：

- `senderId`: 本机节点 id
- `location`: GPS 坐标
- `brief`: 建议取自分诊结果摘要，例如“右腿开放性骨折，可交流，持续出血”

返回：`SosBroadcastResult`

关键字段：

- `packet`: 实际广播出去的数据包
- `deliveredToPeers`: 成功发出的邻居节点数

## 5. 模型管理

### 下载模型

调用：`modelManager.downloadModel(uri, outputPath, resumeFrom: bytes)`

前端可据此显示：

- 下载百分比
- 是否断点续传
- 当前目标模型路径

### 热切换模型

调用：`modelManager.hotSwap(descriptor)`

建议前端在切换时：

1. 禁止同时发起新的分诊请求
2. 显示“正在释放旧模型内存”
3. 切换完成后恢复入口

## 6. 省电模式

当前通过 `EmergencyRequest.powerMode` 控制。

策略：

- `normal`: E2B 走 balanced，E4B 走 expert
- `doomsday`: 强制走 `ModelProfile.e2bSaver`

也就是说，即使大模型已下载，在极限省电模式下也会自动降回低功耗推理配置。
