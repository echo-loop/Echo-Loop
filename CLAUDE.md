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

**文档版本**: v4.3
**更新时间**: 2026-04-02

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

### 7.1 iOS 语音识别：异步回调破坏新 session

- **现象**：录音播放不正确、卡在"分析中"~5 秒、评级却显示很棒
- **根因**：`SFSpeechRecognitionTask.cancel()` 的回调是**异步**的（排入主队列下一轮事件循环）。若新 session 已启动，旧回调读到新 session 状态并破坏它（`isRecording = false` + 取消新识别任务）
- **解法**：generation counter 模式 — 每次新 session 递增计数器，闭包捕获当前值，回调中校验不匹配则丢弃
- **规则**：识别回调的 error 分支**不做资源清理**，资源清理统一由 stop/cancel/shutdown 发起
- **相关代码**：`ios/Runner/AppDelegate.swift` → `IOSSpeechPracticeHandler`
- **修复时间**：2026-03-27

### 7.2 flutter_tts：快速 stop→speak 导致 awaitSpeakCompletion 失效

- **现象**：闪卡快速切换单词时，TTS 在 3-9ms 内"完成"（实际还在朗读），倒计时和 TTS 声音同时出现
- **根因**：`_tts.stop()` 触发平台两个响应：① method channel result（解除 await）② cancel handler（异步到达）。cancel handler 在新 `speak()` 的 Completer 创建后才到达，错误地完成了新的 Completer。平台层报错 `Message responses can be sent only once`
- **解法**：不依赖 `awaitSpeakCompletion`，改用自管理 Completer + `setStartHandler` 标志。start handler 到达前的 completion/cancel 回调视为 stale 直接忽略。method channel FIFO 保证顺序：旧 cancel → 新 start → 新 completion
- **规则**：TTS 的 stop 和 speak 之间不能依赖 flutter_tts 内部的完成信号隔离，必须自行管理
- **相关代码**：`lib/services/tts_service.dart`
- **修复时间**：2026-04-06

### 7.3 Android versionCode 必须全局单调递增，与 versionName 解耦

- **现象**：已装 1.0.10+4 的设备无法安装 1.0.11+1/+2，系统提示「已存在更高版本」
- **根因**：Android 升降级**只看 versionCode（整数）**，不看 versionName。Flutter `pubspec.yaml` 的 `+N` 直接映射到 Android versionCode。minor 升级时把 buildNumber 重置回 1，导致 versionCode 倒退（4 → 1）
- **解法**：
  - Git tag 改用纯 SemVer 格式 `v1.0.11`（**不带 `+N`**）
  - versionCode 由 CI 用 `git rev-list --count <tag>` 自动生成，全局单调递增
  - App 内"关于"页只显示 versionName，buildNumber 不暴露给用户
  - 同 versionName 内需重新构建时：加空 commit (`git commit --allow-empty`) → commit count +1
- **规则**：所有平台（Android/iOS/macOS）的发布脚本和 CI workflow 都按"tag = 纯 SemVer，versionCode = commit count"约定走。打 tag 前必须先升级 `pubspec.yaml` 的 version 字段（workflow 会强制校验一致）
- **相关代码**：`scripts/lib/build_number.sh`、`scripts/release_*.sh`、`.github/workflows/release.yml`、`lib/screens/settings_screen.dart`
- **修复时间**：2026-05-20

### 7.4 离线 ASR：sherpa-onnx Silero VAD native 推理在部分机型 abort（**未解决**）

- **现象**：OnePlus Ace 6T / Android 16 (ColorOS) 跟读/复述点"结束录音"后闪退
- **排查过程（重要方法论）**：拿不到 logcat/tombstone，靠**落盘日志 + 崩溃面包屑**定位。先按"最可能是 NNAPI"把 `_platformProvider()` 由 `nnapi` 改 `cpu`（兜底，保留）；但真机日志显示 `provider=cpu` 后**仍崩**，且 worker 日志里 `VAD input` 打出、紧随的 `VAD: segments` 未打出——锁定崩在 `_extractSpeechWithVad`，即 **Silero VAD 的 native 推理**，与 NNAPI/whisper 无关
- **真因**：sherpa-onnx 的 Silero VAD 在该机型 native abort（进程被杀）。在 sherpa-onnx native 层，本地无法复现、改不动
- **失败的修复尝试（均未解决）**：
  - ① AudioRecord 并发串行（commit `bbbf1c37`）——误判，真因不在录音
  - ② NNAPI → cpu provider（commit `0174ee80`）——误判，cpu 后仍崩
  - ③ 自适应跳过 VAD（崩一次后置位 `offline_asr_skip_vad`、整段直送 whisper）——真机**连续崩多次**，标记未触发自愈或绕开 VAD 后 whisper decode 同样崩，已**撤销**
- **现状**：崩溃**未解决**。保留诊断设施（落盘日志 / `_workerLog` / 崩溃面包屑 / `asr_inference_crash_suspected` 上报）与两个独立合理的防御改动（cpu provider、AudioRecord 串行）继续排查；确诊需真机 **logcat + `/data/tombstones`**
- **规则**：
  - native SIGABRT/SIGSEGV/被杀**不可 catch**——"兜底不崩"只能靠避开崩溃路径（跳过该 native 调用），不能靠包 try-catch；但避开 VAD 后本例仍崩，说明绕开单点不一定够
  - 面包屑只能证明"进程在某 native 段被终止"，**证明不了信号类型**（SIGABRT/SIGSEGV/OOM-SIGKILL 都会残留 marker），也证明不了"绕开该段就不崩"；要确诊信号/栈仍需 logcat + `/data/tombstones`
  - 排查 native 崩溃必须**落盘日志 + 调用前同步 flush**：内存日志（`AppLogger` 环形缓冲）崩溃即丢；Worker isolate 的日志写各自 isolate 单例、到不了主 isolate 日志页，需在 isolate 内自行写文件（`_workerLog`）
- **相关代码**：`lib/services/asr/sherpa_onnx_engine.dart`（崩溃面包屑 / `_workerLog` / cpu provider）、`lib/providers/offline_asr_settings_provider.dart`（`_reportPreviousAsrCrashIfAny`）、`lib/services/app_logger.dart`、`lib/utils/app_data_dir.dart`
- **更新时间**：2026-06-10（暂记，待真机定位）

### 7.5 清除缓存误删系统 URLCache 导致 disk I/O error

- **现象**：点「清除缓存」后日志反复 `error-message=disk I/O error`，`DB=.../Library/Caches/<bundleId>/Cache.db`，`BEGIN IMMEDIATE TRANSACTION` 失败、`cannot commit - no transaction is active`。每次 app resume 触发原生网络请求就报一次（与磁盘空间无关）
- **根因**：`cleanupAllTempFiles` 把 `getTemporaryDirectory()`（= iOS/macOS 的 `Library/Caches`）**整个根目录**一级条目逐个 `delete(recursive:true)`。`Library/Caches` 是系统/框架共享目录，其中 `<bundleId>/Cache.db`(+`-wal`/`-shm`) 是 `URLSession.shared`(NSURLCache) 正在打开的 SQLite 缓存库。文件被 unlink 后 URLSession 再写缓存即 SQLITE_IOERR(error-code=10)
- **解法**：清缓存只清 app 自己的产物——
  - `Library/Caches` 只删 app 自建导出/导入临时目录（前缀白名单 `audio_export_` / `echoloop_export_` / `echoloop_import_`），系统/框架缓存一律跳过
  - 网络图片缓存走 `flutter_cache_manager` 的 `AppNetworkImageCache.instance.emptyCache()`（API 同时清文件+json 索引）
  - 沙盒 `tmp/`（NSTemporaryDirectory）仍可全量清（私有、语义可丢）
- **规则**：**禁止用文件系统直接删 `Library/Caches` 根目录**。网络缓存清理必须走对应库/系统的 API（如 `URLCache.shared.removeAllCachedResponses()`、`flutter_cache_manager.emptyCache()`），不能 unlink 它正在打开的文件
- **相关代码**：`lib/services/temp_cleanup_service.dart`（前缀白名单 + `nameFilter`）、`lib/screens/settings_screen.dart`（`_clearNetworkImageCache`）
- **修复时间**：2026-06-17

### 7.6 just_audio：整篇循环依赖 completed 事件做反应式计数不可靠

- **现象**：Free Player 整篇循环重复设 3 遍只播 2 遍就停；播完后播放/暂停按钮仍显示「暂停」图标；播完后点两下按钮却从最后一句开始播
- **根因**：整篇连续播放（gapless）此前监听 `playerStateStream` 的 `ProcessingState.completed` 做「计数 +1 后 seek 回开头重播」。just_audio 有两个与该设计冲突的语义——
  - **`AudioPlayer.playing` 在自然播完（completed）后仍为 `true`**：播放/暂停按钮直接读 `engine.isPlaying`(=`_audioPlayer.playing`)，播完瞬间就误显「暂停」
  - **`completed` 事件可能重复/滞后到达**：重启后到达的陈旧 completed 会让计数多 +1，`shouldLoopWhole` 提前返回 false → 提前停止。`_handlingWholeCompletion` 闸门只挡得住「处理中重入」，挡不住「重启后到达的滞后事件」
  - 连带 bug③：图标错显「暂停」→ 首击触发 `pause()`（清掉 `_awaitingReplayFromStart`）→ 次击 `play()` 不再从头重播，而从当前（末）句起播
- **解法**：放弃反应式 completed 计数，改为与单句循环一致的**确定性 await-完成循环**——
  - 新增引擎原语 `AudioEngine.playToEnd(sid)`：`play()` 后 `await playerStateStream.firstWhere(completed || 失效)`，每个自然结束只解析一次 await，对重复/滞后 completed 天然免疫
  - `_playWholeDriven` 协程里循环 `await playToEnd` → 遍数 +1 → `shouldLoopWhole` 判停/回卷；暂停续播、模型交接、seek 续播都重新拉起该协程
  - 图标改由 controller 持有的**逻辑播放态** `ListeningPracticeState.isPlaying`（在起播/暂停/停止/自然播完入口显式维护）驱动，**不读** just_audio 的 `playing`
- **规则**：
  - **「播 N 遍后停」「播完该停」这类有限循环不要监听 `completed` 事件反应式推进**，要用 `await playToEnd/playClipOnce` 的确定性协程循环计数（同 §7.1/§7.2「不依赖音频库回调隔离 session」）
  - **播放/暂停按钮图标的真相源是 controller 的逻辑播放意图，不是音频库的瞬时 `playing` 标志**（completed 后 `playing` 仍为 true）
- **相关代码**：`lib/providers/audio_engine/audio_engine_provider.dart`（`playToEnd` / `processingState`）、`lib/providers/listening_practice/listening_practice_provider.dart`（`_playWholeDriven` / `_startWholeDriven` / `_setLogicalPlaying`）、`lib/models/listening_practice_state.dart`（`isPlaying`）、`lib/widgets/playback_controls.dart`
- **修复时间**：2026-06-23
