# CLAUDE.md - Claude Code 工作规范

## 1 核心原则

你是 Claude Code，在本仓库内协助完成开发任务。首要目标是按计划稳定推进，保持改动可验证。

1. **文件驱动** — 决策写进 PLAN.md / TASKS.md，不依赖聊天记忆
2. **单任务聚焦** — 一次只做一件事，做完再下一件
3. **测试先行** — 先写测试定义预期，再写实现代码，保证结果的正确性
4. **功能解耦** — 每个模块独立可测，不耦合无关逻辑；单文件 ≤500 行，单函数 ≤50 行
5. **逐步验证** — 每次改动立即可运行、可检查，不攒大变更
6. **注释完善** — 文件、函数、核心逻辑必须有中文文档注释，符合 Dart doc comment 规范
7. **文档同步** — 代码改完，立刻更新 TASKS.md（勾选任务、记录完成时间）和 PLAN.md（里程碑进度）
8. **最小改动** — 只改当前任务相关的文件和代码，不做额外重构
9. **类型安全** — 避免 dynamic、as 强转、!非空断言，优先使用类型安全写法
10. **诊断日志** - 打印出关键日志，方便排查、发现问题

---

## 2 Flutter 应用开发原则

### 2.1 核心原则
1. 优先保证结构清晰，不要过度设计。
2. 按职责拆分，不按页面外观拆分。
3. 保持单向数据流：UI 触发动作，controller 更新 state，UI 根据 state 渲染。
4. UI 和业务逻辑分离，widget 不承载复杂业务逻辑。
5. 优先简单、直接、稳定的方案。

### 2.2 分层职责
6. Screen/Page 负责页面组装、路由参数、读取 provider、分发回调。
7. Widget 负责展示和局部交互，尽量保持纯。
8. Provider/Notifier 负责状态和业务逻辑。
9. Repository 负责数据获取和持久化，不负责业务流程编排。
10. Model 表示业务数据，State 表示界面运行状态。Model 不依赖 State，State 可以包含 Model。

### 2.3 状态管理
11. Provider 按功能域拆分，不按组件个数拆分，也不按页面外观拆分。
12. 状态只在一个 widget 树内使用且不需要跨组件共享时，用局部 state；否则用 provider。
13. 一份真实状态只能有一个单一来源，避免多处维护同一状态。
14. 状态变更入口要集中，只能通过明确的方法修改状态。
15. 复杂流程提取为纯 Dart 类编排（可测试、可复用），Provider 负责连接编排层和 UI。

### 2.4 Widget 设计
16. 页面负责组装，组件负责展示。
17. 不要做万能组件，避免大量 if 和模式开关。参数超过 10 个说明职责太广，应该拆分。
18. build 方法只描述 UI，不做请求、不改状态、不启动副作用。
19. 子组件只读取自己关心的状态，避免整页无意义刷新。

### 2.5 可靠性
20. 异步操作必须防竞态：启动时记录标识（token/sessionId），回调时校验标识是否仍有效，过期则丢弃。
21. 谁创建谁销毁。资源的生命周期必须和它的所有者绑定，不能由外部隐式管理。
22. 副作用（网络请求、文件 IO、平台调用）通过接口或回调注入，不在业务逻辑类中直接调用。
23. 每个异步调用点都要考虑失败情况。沉默吞掉异常是 bug，应该明确处理或向上传播。
24. 错误、加载、空状态必须显式设计，不要只写成功态。

### 2.6 可维护性
25. 命名优先于技巧，名称必须直接表达职责。
26. 目录结构优先按 feature 组织，再在 feature 内部分层。
27. 先允许少量重复，确认模式稳定后再抽象。过早抽象比重复更有害。
28. 优先测试状态流转和业务逻辑，不要只测 UI 表面。

**文档版本**: v4.4
**更新时间**: 2026-06-27

---

## 3 启动流程（每个会话强制执行）

开始任何工作前，必须按顺序完成以下 4 步：

1. 读取 PLAN.md — 了解项目当前阶段和整体规划
2. 读取 TASKS.md — 了解待办任务列表和优先级
3. 输出要执行的任务 — 明确说明接下来做哪一个任务（一次只做一个）
4. 等待用户确认 — 用户同意后再开始修改代码

---

## 4 收尾流程（每次完成任务强制执行）

完成当前任务后，必须按顺序完成以下 7 步：

### 步骤 1: 检查测试完整性
确认以下测试是否已覆盖：
- **Unit Test**: 纯逻辑测试（模型、服务、辅助类），不涉及 UI
- **Widget Test**: 组件级 UI 测试
- **Integration Test**: 端到端（E2E）测试，验证完整用户流程

### 步骤 2: 删除死代码
检查是否存在未使用的代码（包括测试中的），有则删除。

### 步骤 3: 检查注释和文档
确保新增/修改的代码有清晰的中文注释。

### 步骤 4: 运行验证命令
```bash
flutter analyze
flutter test
flutter test integration_test -d macos
```

### 步骤 5: 更新 TASKS.md
```markdown
# 必须完成：
1. 勾选已完成任务（- [x]）
2. 在任务下添加完成记录：

  **完成时间**: 2026-01-31
```

### 步骤 6: 更新 PLAN.md（如有需要）
如果本次任务导致里程碑进度变化，必须更新 PLAN.md 中对应里程碑的状态。

### 步骤 7: 输出完成摘要
```markdown
**实现的任务**: [任务标题]
**修改的文件** (X 个):
- path/to/file.dart (+50 -10)
**对应的测试**:
- path/to/test_file.dart
**下一步建议**:
- 告诉用户如何验证结果
- 下一个任务是什么
```

---

## 5 TASKS.md 归档规则

满足以下任一条件时，必须执行归档：
1. **里程碑完成** — PLAN.md 中某个 Milestone 全部完成
2. **文件过大** — TASKS.md 超过 200 行
3. **任务过多** — 已完成任务超过 30 条
4. **手动触发** — 用户明确要求归档

归档步骤：
1. 创建归档文件：`docs/tasks-archive/milestone-X-completed.md`
2. 将已完成任务移入归档文件
3. 清理 TASKS.md，仅保留未完成任务
4. 在 TASKS.md 顶部添加归档链接
5. 更新 PLAN.md 里程碑状态

---

## 6 编码规范

### 6.1 Dart / Flutter 约定
- 使用 `flutter_lints` 静态分析，配置见 `analysis_options.yaml`
- 格式化：`dart format .`
- 国际化：`flutter_localizations` + ARB 文件（`lib/l10n/`），模板文件为 `app_en.arb`，当前支持 en / zh

### 6.2 测试约定
- 框架：`flutter_test` + `mocktail`
- 文件命名：`*_test.dart`，放在 `test/` 对应子目录下
- 每个新功能或 bug 修复必须包含对应测试

### 6.3 Riverpod 代码生成
- Provider 使用 `riverpod_generator` 代码生成，文件包含 `part 'xxx.g.dart';`
- 修改 Provider 后运行：`dart run build_runner build`

### 6.4 iOS 网络注意事项
- Flutter `dart:io` HttpClient 绕过 iOS 原生网络栈，**不会触发系统网络权限弹窗**
- 需要通过 Method Channel 调用 iOS 原生 `URLSession` 才能触发
- 当前方案：App 启动时通过 `top.echo-loop/network` Channel 发起原生请求（见 `AppDelegate.swift` + `main.dart`）

---

## 7 Troubleshooting（踩坑记录）

记录已修复的典型问题和设计约束，防止同类问题再次出现。

> 已压缩；完整长版见 `docs/reference/claude-2026-07-12-full.md`

### 7.1 iOS 语音识别：异步回调破坏新 session

- 旧 `cancel()` 回调会异步污染新 session。
- 规则：用 generation counter；错误分支不直接做资源清理。

### 7.2 flutter_tts：快速 stop→speak 导致 awaitSpeakCompletion 失效

- `stop()` 的晚到回调会完成新的 completer。
- 规则：不要依赖插件内部完成信号隔离；自己管理 in-flight 状态。

### 7.3 Android versionCode 必须全局单调递增，与 versionName 解耦

- Android 安装升级只看 `versionCode`。
- 规则：tag 用纯 SemVer；`versionCode` 用 commit count，不能回退。

### 7.4 离线 ASR：sherpa-onnx Silero VAD native 推理在部分机型 abort（**未解决**）

- 当前已确认问题集中在 Silero VAD native 推理。
- 规则：native 崩溃不能靠 try/catch；必须拿 `logcat` 和 `/data/tombstones` 定位。

### 7.5 清除缓存误删系统 URLCache 导致 disk I/O error

- 不能直接删 `Library/Caches` 根目录。
- 规则：只删 app 自建缓存目录，系统/框架缓存必须走对应 API 清理。

### 7.6 just_audio：整篇循环依赖 completed 事件做反应式计数不可靠

- `completed` 事件会重复或滞后，`playing` 在播完后仍可能是 true。
- 规则：有限循环用确定性的 `await playToEnd` 协程，不靠 completed 事件驱动。

### 7.7 锁屏：向系统上报 `completed` 导致整篇循环进度条偶发卡在结尾

- 系统媒体会话看到 `completed` 后会把进度条钉在结尾。
- 规则：锁屏状态不上报 `completed`；内部逻辑读原始播放器状态。

### 7.8 release 资源压缩删掉通知图标，锁屏/通知栏媒体控件整体消失（仅 release）

- 运行时字符串引用的 Android 资源会被 release 资源压缩误删。
- 规则：这类资源必须进 `res/raw/keep.xml` 白名单。

### 7.9 录音类任务抑制锁屏的三个坑（iOS MediaItem/position 通道 + Android「先 load 后 suppress」时序）

- 本问题已被 §7.12 的引擎拆分架构性取代。
- 规则：录音类任务若还走 suppress 思路，必须先 suppress 再 load，并同时堵住 mediaItem 与 playbackState 两条通道。

### 7.10 学习任务后台播放：静音保活音量必须 1.0；锁屏切句回调每任务绑一次

- iOS 后台静音保活与锁屏事件绑定都有时序要求。
- 规则：保活音量按既定值处理；锁屏切句回调在任务级单次绑定。

### 7.11 录音类任务仍显示锁屏：suppress(false) 在 idle 时重发 MediaItem 贴出无法清除的残留卡片

- idle 态重发 MediaItem 会残留无法清除的卡片。
- 规则：清卡片必须依赖正确的非 idle→idle 生命周期，不要在 idle 态补发 MediaItem。

### 7.12 媒体引擎 / 前台引擎分离：把「是否上锁屏」做成结构性属性而非运行时开关

- 这是当前锁屏/前台试听隔离的正式方案。
- 规则：前台试听与系统媒体会话物理分离，不再依赖 suppress 开关补救。

### 7.13 段落播放：position 追踪订阅早于 seek(0) 落定 → 高亮乱跳、断点被覆盖成首句

- 订阅建立早于回卷落定会污染当前位置。
- 规则：位置追踪必须晚于 seek 落定，避免用旧事件覆盖新状态。

### 7.14 盲听会话内中断用 stop（idle）反复拆/重建系统媒体会话 → 锁屏控件失效

- 会话内中断若用 stop，会反复拆媒体会话。
- 规则：会话内中断优先用 pause，不用 stop。

### 7.15 段落分段播放（clip）锁屏进度每切句归零：必须上报「绝对位置 + 全曲时长」

- clip 播放不能只报相对位置。
- 规则：锁屏进度统一报绝对位置与全曲时长。

### 7.16 停顿倒计时锁屏进度条仍前进、下一段又回退：必须上报 `speed=0` 冻结

- 倒计时时若仍报正常速度，系统会继续走进度。
- 规则：停顿阶段显式上报 `speed=0`。

### 7.17 合集内详情路由拍平在顶层 → 返回后自动多退一层（学习计划页 → 资源库）

- 顶层路由拍平会破坏返回栈。
- 规则：详情页路由层级要与入口栈保持一致。

### 7.18 统一 TTS：嵌入式发音组件不可在 provider build 期触碰平台/数据库（惰性化）

- build 期触发平台或数据库访问会污染页面初始化。
- 规则：发音能力惰性初始化，不在 provider build 期做副作用。

### 7.19 macOS flutter_tts：synthesizeToFile 不设 voice，英/美音合成产物完全相同

- macOS 平台插件历史上不正确设置 voice。
- 规则：遇到该链路继续优先走自家原生合成实现。

### 7.20 Echo Loop TTS（Kokoro / sherpa-onnx）接入要点（设计约束，详见 PLAN.md ADR-9）

- 本地 TTS 接入涉及模型下载、缓存、播放链路一致性。
- 规则：沿统一 TTS 架构接入，不额外分叉播放主干。

### 7.21 Kokoro 归档若用 macOS tar 打包，PAX 扩展头令 archive 解压抛 FormatException

- macOS tar 会带 PAX 扩展头，解包侧不一定兼容。
- 规则：模型归档方式按既定兼容格式生成。

### 7.22 TTS 音色试听/预热：音色经 config 显式传入 synthesize，统一 render 主干（设计约束）

- 试听和预热若绕过统一 render 主干，缓存和口音会串。
- 规则：音色通过 config 显式传入，统一走 render 主干。

### 7.23 平台 TTS 口音试听：engine.stop() 打断在途 synthesizeToFile 致复用方挂起

- `engine.stop()` 可能打断在途 `synthesizeToFile`，让 Future 永久挂起。
- 规则：先停播放器，再等 render；不要在有 in-flight synthesize 时盲目 stop engine。

### 7.24 macOS 平台 TTS 自实现 synthesizeToFile（原生通道）→ 三端合成行为一致

- macOS 已用原生通道补齐文件合成与缓存。
- 规则：macOS 平台合成能力以自家原生实现为准。

### 7.25 词典交互：非 modal 常驻面板 + 词组选区手柄（设计约束）

- 当前正式方案是 Stack 内嵌常驻面板 + 词级吸附手柄。
- 规则：新可点词场景统一复用 `SelectableSentenceText`；面板外点击关闭要带豁免命中区。

### 7.26 流式 AI 词典（NDJSON 部分对象快照）：设计约束与踩坑

- 流式词典已切到 NDJSON，并处理了取消、缓存和错误体边界。
- 规则：stream 响应不要被通用日志/序列化链路误消费。

### 7.27 流式 AI 词典：帧协议由「累计完整快照」改为「字段级增量」

- 现在协议核心是“按路径设叶子”，避免 O(n²) 重发。
- 规则：后续结构化流式对象继续优先用增量叶子协议，不回退到整对象快照。
