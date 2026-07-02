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
- **补充（2026-06-25）：恢复进入时存档位置停在结尾被误判为「续播」**
  - **现象**：上次播到结尾的音频再次进入 player，无字幕需点两次播放才从头播（首次从结尾起播立即结束）；有字幕首次点击从最后一句起播而非音频开头
  - **根因**：`_restorePlaybackState` 把引擎 `seek` 到存档位置（=结尾）。此时 `processingState` 是 `ready`（**非 `completed`**——completed 只在本 session 内真正播到尾才触发），且 `_awaitingReplayFromStart` 为 false。「续播 vs 从头」启发式 `processingState != completed && position > 0` 据此误判为续播
  - **解法**：新增 `AudioEngine.totalDuration` getter 与 `_isAtAudioEnd()`（`currentPosition` 接近总时长即视作已播完）。无字幕 `_startNoTranscriptPlayback` 续播判定加 `!_isAtAudioEnd()`；有字幕 `play()` 的「已播完重播」分支条件改为 `_awaitingReplayFromStart || _isAtAudioEnd()`，结尾态统一走 `_restartFromPlayableBeginning`
  - **规则**：`completed` 事件只反映「本 session 播到尾」，**不能**用来识别「恢复进入时存档位置就在结尾」——后者必须用 `位置 ≈ 总时长` 判断。读实时 `currentPosition` 而非依赖标志位，天然兼容「拖动进度条到中间后再播」

### 7.7 锁屏：向系统上报 `completed` 导致整篇循环进度条偶发卡在结尾

- **现象**：整篇循环时，锁屏 Now Playing 进度条偶发卡在「上一遍结束位置」（满格、暂停图标=系统认为在播），但音频已开始播下一遍。大部分正常，无固定触发条件
- **根因**：锁屏进度完全由 `audio_service` 的 `playbackState` 驱动（无自定义 `MPNowPlayingInfoCenter`）。`_broadcastState()` 在每个 just_audio `playbackEvent` 上把 `_player.position/playing/processingState` 原样广播。一遍自然播完时 just_audio 进入 `completed` 且 `playing` 仍为 true（见 §7.6），广播出 `position≈end + playing=true + processingState=completed`。`completed`（已结束）标志让 iOS 把曲目当作播完、进度条钉在结尾；随后 `_playWholeDriven` 回卷 `seek(0)` 时 just_audio 仍停在 `completed`（要等下一遍 `play()` 才转 ready），系统在「已结束」态下忽略 position=0 更新，进度条继续卡结尾。能否纠正取决于 completed→ready 转换与 stale 终结事件的到达时序——故偶发（同 §7.1/§7.2/§7.6：不可依赖音频库事件顺序跨 session/循环边界）
- **解法**：`_mapProcessingState` 把 `ja.ProcessingState.completed` 映射为 `AudioProcessingState.ready`。本 app 是循环播放器，对系统从不真正「结束」——系统永远看不到 completed 标志，回卷 seek/下一遍 position 更新都在 ready 态下被正常接受
- **规则**：锁屏/系统媒体会话**不上报 `completed`**。app 内部所有 `completed` 判定（循环计数、`_isAtAudioEnd`、续播 vs 从头）都读**原始 `_handler.player.processingState`**，不读 audio_service 广播态，故该映射对内部逻辑零副作用
- **相关代码**：`lib/services/background_audio_handler.dart`（`_mapProcessingState`）
- **修复时间**：2026-06-25

### 7.8 release 资源压缩删掉通知图标，锁屏/通知栏媒体控件整体消失（仅 release）

- **现象**：`flutter run`（debug）锁屏/通知栏媒体控件正常；GitHub CI 编出的 release 包播放时**不显示媒体通知**，取而代之是系统通用前台服务占位通知「"Echo Loop"正在运行 / 点按即可了解详情或停止应用」。影响所有播放场景（不止 Free Player），small icon 是全局媒体通知图标
- **排查方法论（重要）**：症状先验证机制——读 audio_service Android 源码确认媒体通知只在 `playing` false→true 经 `enterPlayingState()` → `startForeground(buildNotification())` 创建；系统占位通知 = `startForegroundService()` 调了但紧接的 `startForeground(媒体通知)` 没成功（抛异常）。**纯静态分析定位不到**（Dart 侧推演不出），最终靠 `unzip -p APK resources.arsc | strings | grep 资源名` 对比 debug/release 包资源表锁定：release 的 arsc 里**没有 `ic_stat_logo` 资源名**（对照 `audio_service_*`、`ic_launcher` 都在）。验证用的是 CDN/CI 实际产物，不是本地旧包（旧包早于改动会误判）
- **根因**：`androidNotificationIcon: 'drawable/ic_stat_logo'` 这个 small icon **只在 Dart 里以字符串运行时引用**（audio_service 内部 `getResources().getIdentifier()` 动态查找），无任何代码/XML 静态引用。release 的 R8 资源压缩器（`shrinkResources`，本项目 release 默认开启，资源还被混淆成 `res/XX.png`）据此判定「未使用」并从 APK 删除 → 运行时 `getIdentifier` 返回 **0** → `setSmallIcon(0)` → `startForeground` 抛 "Bad notification: Couldn't create icon" → 媒体通知建不起来。debug 不压缩资源故无此问题
- **解法**：新建 `android/app/src/main/res/raw/keep.xml`，用 `tools:keep="@drawable/ic_stat_logo"` 把图标加入资源压缩白名单，使其在 release 包保留、`getIdentifier` 可解析
- **规则**：**任何只通过运行时字符串名（`getIdentifier`/插件配置）引用、无静态引用的 Android 资源，都必须在 `res/raw/keep.xml` 里 `tools:keep`**，否则 release 资源压缩会删掉它。这类问题 debug 永远不复现，必须用 release 包 + 查 `resources.arsc` 资源表验证
- **相关代码**：`android/app/src/main/res/raw/keep.xml`、`lib/services/background_audio_handler.dart`（`androidNotificationIcon`）、`android/app/build.gradle.kts`（release R8）
- **修复时间**：2026-06-25

### 7.9 录音类任务抑制锁屏的三个坑（iOS MediaItem/position 通道 + Android「先 load 后 suppress」时序）

> **已被 §7.12 引擎拆分架构性取代（2026-06-27）**：`setMediaSessionSuppressed` 整套已删除，录音/复习类任务改用不接 `audio_service` 的前台引擎，物理上不弹卡片。本节保留为历史教训：运行时 suppress 开关对抗系统两条通道+事件时序极脆弱。

- **现象**：难句跟读 / 段落复述等录音强交互任务进任务时已调 `setMediaSessionSuppressed(true)`，但锁屏/通知栏 now-playing 卡片仍显示。三处根因独立，需逐一修；难句跟读修完前两处即好，段落复述还需第三处
- **排查方法论**：读 audio_service iOS 源码（`AudioServicePlugin.m`）确认锁屏卡片由**两条独立通道**驱动——① playbackState（`setState`→`updateControls`/`updateNowPlayingInfo`）；② MediaItem（`setMediaItem`→`updateNowPlayingInfo`→`MPNowPlayingInfoCenter.nowPlayingInfo=…`）。iOS 清卡片的**唯一**入口是 native `stopService`（把 `nowPlayingInfo` 置 nil），而 Dart 侧（`audio_service.dart` `_observePlaybackState`）**只在 `processingState` 发生 `非idle→idle` 跳变那一次**才调 `stopService`；`setMediaItem` 本身**从不清卡片，只会重新填充**
- **根因（两处，需同时修）**：
  - **① MediaItem 通道未抑制**：`background_audio_handler.dart` 两处 `mediaItem.add`（`loadFile` 设标题/封面、构造函数 duration 监听回填）未受抑制约束。进录音任务时音频经共享 handler 加载 → native `setMediaItem` 把卡片填回锁屏；即使 playbackState 是 idle（按钮被禁用），卡片本体照样可见。**先修这处，难句跟读（播完一句即等录音、position 不持续变）即好**
  - **② 抑制广播透传实时 position（iOS）**：`_broadcastState` 抑制分支原样发 `updatePosition: _player.position`。iOS `setState`（`AudioServicePlugin.m`）在「playing/speed/position 任一变化」时调 `updateNowPlayingInfo` → 用插件**本地仍存的**标题/封面把 `nowPlayingInfo` 写回系统（`stopService` 只清系统侧、不清本地字典）→ **连续播放（段落复述整段连播）时卡片随 position 反复复活**
  - **③「先 load 后 suppress」时序（Android 尤其明显）**：`enterRetellMode` 原本先 `_ensureAudioLoaded`（loadFile 此时 suppress 还是 false → 走非抑制广播：ready/playing:false/position 0/controls[play,stop] + setMediaItem 设标题）再 `initialize` 才 suppress。Android `AudioService.java` 的 `setState` 仅在 `notificationCreated && processingState!=idle && notificationChanged` 时 `updateNotification()` 贴通知 → loadFile 那次非抑制广播把通知贴出。后续 suppress 的 idle 广播在多数路径能靠 `非idle→idle` 跳变触发 `stop()`→`cancel`，但此时序下通知已贴出且不稳定移除。**难句跟读没这问题，因为它 `initialize` 开头第一行就 suppress、早于任何 load**
- **解法**：抑制态下把会触发系统重绘的来源**全部挡住**，且**抑制必须早于音频加载**——
  - gate 两处 `mediaItem.add`（`if (!_mediaSessionSuppressed)`）
  - 抑制广播发**恒定** `updatePosition: Duration.zero` / `bufferedPosition: Duration.zero` / `speed: 1.0`（不透传实时值），让系统认为「无变化」不再 `updateNowPlayingInfo`
  - **`enterRetellMode` 把 `setMediaSessionSuppressed(true)` 提到 `_ensureAudioLoaded` 之前**，与难句跟读「先 suppress 再 load」对齐；provider `initialize` 内的 suppress 保留为幂等兜底
  - `setMediaSessionSuppressed(false)` 退任务时重发当前 MediaItem，把被 `stopService` 置 nil 的 native `nowPlayingInfo` 为后续任务恢复（下一次 `playing:true` 广播会重新激活 commandCenter）
- **规则**：
  - **「隐藏锁屏」要堵死所有会写系统媒体会话的通道**——iOS：`setMediaItem`（mediaItem.add）+ `setState` 的 position/playing/speed 变化；Android：`setState` 在非 idle 时的 `updateNotification`。缺一不可
  - **录音类任务必须「先 suppress 再 load 音频」**，否则 loadFile 会以非抑制态把卡片/通知贴出；事后再抑制不一定能干净移除（尤其 Android）
  - app 共用单个全局 handler/player，「播音不上锁屏」做不到「不碰媒体会话」，只能靠主动抑制；抑制对 app 内部零副作用（内部读原始 `_player` 状态，不读广播态，同 §7.7）
- **相关代码**：`lib/services/background_audio_handler.dart`（`setMediaSessionSuppressed` / `_broadcastState` 抑制分支 / `loadFile` / 构造函数 duration 监听）、`lib/providers/learning_session/learning_session_provider.dart`（`enterRetellMode` 先 suppress 再 load）、`lib/providers/listen_and_repeat/listen_and_repeat_controller.dart`（`initialize` 开头即 suppress）；参照 `audio_service-0.18.18` 的 `AudioServicePlugin.m`（iOS）/ `AudioService.java`（Android setState→updateNotification/stop）/ `audio_service.dart`（`_observePlaybackState` idle 跳变才 stopService）
- **修复时间**：2026-06-27

### 7.10 学习任务后台播放：静音保活音量必须 1.0；锁屏切句回调每任务绑一次

- **现象**：Free Player / 逐句精听 / 全文盲听 锁屏后暂停（不再自动推进到下一句/下一段）；锁屏「上一句/下一句」有时不起作用。3228c91f 时正常
- **根因（两处独立）**：
  - **① iOS 静音保活 `setVolume(0)` 无效**：句间/段间停顿由 `CountdownController` 的 Dart `Timer` 计时。iOS 锁屏后 app 被挂起则 `Timer` 冻结 → 停顿结束不推进 → 表现为「锁屏后暂停」。为此引入「停顿期循环播静音轨保活」让 app 不挂起，但 `startKeepAlive` 把保活轨设成 `setVolume(0)` —— **iOS 把「零输出」视作「未在播放」仍会挂起 app**，保活失效。Android 不受影响（靠前台服务 + 广播 `playing:true` 保活，定时器照跑）
  - **② 锁屏切句回调「按活跃 phase 条件 bind」留空窗**：精听/盲听原本在 `_onBlindFlowStateChanged` 里「仅活跃 phase 调 `bindLockScreen`」，非活跃瞬间回调槽状态不稳定 → 锁屏切句偶发失灵
- **解法**：
  - **保活音量 `0 → 1.0`**：静音内容本身无声、用户听不到，但「会话持续渲染音频」才能让 iOS 不挂起、Dart 倒计时在后台照常推进，实现「整个会话锁屏后自动跑完」。保活生命周期由 `setSessionActive(active)` 维护：自动推进（播放中或停顿倒计时）期间 `active=true` 跑保活，暂停/完成 `active=false` 停保活（省电）
  - **锁屏回调每任务绑一次**：`bindLockScreen` 移到 `initialize`/`initializeParagraphs` 调一次（回调是稳定的 notifier 方法），整段任务期间切句始终可用；`_onBlindFlowStateChanged` 只留 `setSessionActive(active)` 管保活+图标
- **录音类任务（跟读/复述/补练）**：进任务 `setMediaSessionSuppressed(true)` 隐藏锁屏（§7.9），且**不**绑锁屏、**不**起保活 → 不进后台、不上锁屏。补练（`review_difficult_practice`）此前在盲听子流程里会 `bindLockScreen`+`setSessionActive`，§7.10 一并去掉（音量改 1.0 后它会让补练意外后台保活）
- **规则**：
  - **iOS 后台保活的静音轨音量必须 > 0**（用静音内容、非零音量），`setVolume(0)` 不阻止挂起
  - 「整个会话后台自动跑完」靠：iOS = 持续渲染的保活轨让 app 不挂起；Android = 前台服务 + 广播 `playing:true`。停顿仍由 Dart `Timer` 计时，保活只保证它在后台照跑
  - 锁屏控制回调按**任务生命周期**绑定（进任务绑、离任务清），不按播放 phase 频繁切换
  - 保活双 player 与 §7.1/7.2/7.6 的「双 player 跑内容/事件竞态」不同：它是被动的会话持有者，不接入媒体会话、锁屏只反映主 player
  - **iOS 后台挂起行为本机/CI 测不到，必须真机验证**「停顿跨锁屏能否自动推进到下一句」
- **相关代码**：`lib/services/background_audio_handler.dart`（`startKeepAlive` 音量 1.0）、`lib/providers/learning_session/study_background_playback_mixin.dart`（`setSessionActive`/`bindLockScreen`/`unbindLockScreen`）、`intensive_listen_player_provider.dart` / `blind_listen_player_provider.dart`（bind 移到 initialize）、`review_difficult_practice_provider.dart`（盲听子流程去 bind/保活）
- **修复时间**：2026-06-27

### 7.11 录音类任务仍显示锁屏：suppress(false) 在 idle 时重发 MediaItem 贴出无法清除的残留卡片

> **已被 §7.12 引擎拆分架构性取代（2026-06-27）**：suppress 已删除，本节保留为历史教训。

- **现象**：难句跟读 / 段落复述虽已先 suppress 再 load（§7.9），锁屏 now-playing 卡片仍显示。学习计划里「跟读 → 复述」背靠背时尤为明显
- **根因**：iOS 清卡片唯一入口是 audio_service 在 `processingState` **非idle→idle 跳变那一次**调 `stopService`（`audio_service.dart:1132`，置 `nowPlayingInfo=nil`）。而 `setMediaSessionSuppressed(false)` **无条件**重发 MediaItem——录音任务退出（`disposeSession`/`disposePlayer`）时主 player 已被 `stopSession()` 停成 **idle**，此时 `mediaItem.add` 经 native `setMediaItem` 立刻贴出卡片（`AudioServicePlugin.m:222` 必定 `updateNowPlayingInfo`），但此后 player 长期停在 idle，**再无 非idle→idle 跳变**，卡片无法被清除。下一个录音任务 `suppress(true)` 广播 idle 时 `previousState` 已是 idle → 不触发 stopService → 卡片继续显示
- **解法**：`suppress(false)` 仅当主 player **非 idle**（音频仍已加载/活跃、将来停止会产生可清除跳变）时才重发 MediaItem；idle 时跳过——native 仍保留 mediaItem 静态值（`stopService` 不清它，`AudioServicePlugin.m:230-241`），下一次真正播放的 `playing:true` 广播会经 `setState`→`updateNowPlayingInfo` 自动回填卡片
- **规则**：**每一次 `mediaItem.add`（创建卡片）都必须配对一个将来必然到来的 非idle→idle 跳变**，否则卡片无法清除。退抑制重发卡片要 gate 在「player 非 idle」，不能无条件重发
- **相关代码**：`lib/services/background_audio_handler.dart`（`setMediaSessionSuppressed` 非 idle gate）；测试 `test/services/background_audio_handler_test.dart`（idle 不重发 / 非 idle 重发 / 录音→录音背靠背无残留）
- **修复时间**：2026-06-27

### 7.12 媒体引擎 / 前台引擎分离：把「是否上锁屏」做成结构性属性而非运行时开关

- **背景**：§7.7–7.11 全部锁屏 bug 同源——所有播放场景共用同一个接入 `audio_service` 的 `AudioPlayer`，靠运行时开关 `setMediaSessionSuppressed` 决定录音类任务是否隐藏锁屏。这个开关要同时对抗系统两条独立通道（playbackState + MediaItem）和跨 session/循环边界的事件时序，地鼓打不完
- **解法（ADR-7）**：拆成两套**不共享 player** 的引擎，把「是否绑定系统媒体会话」变成**用哪个引擎**的物理属性：
  - **媒体引擎** `AudioEngine` → `echoLoopAudioHandler._player`，接 `audio_service`（锁屏/后台/静音保活/逻辑播放态）。用户：逐句精听、全文盲听、Free Player
  - **前台引擎** `ForegroundAudioEngine`，自持裸 `ja.AudioPlayer`，**从不注册到 `audio_service`**，物理上碰不到 `MPNowPlayingInfoCenter`/前台通知。用户：难句跟读、段落复述、难句补练、收藏句复习、收藏词复习
  - 前台引擎逐方法照抄媒体引擎的播放子集（session 守卫 / setClip→seek(0)→play / await-完成），仅把 `_handler.xxx` 换成裸 `_player.xxx`，保证录音类任务播放/录音功能行为不变
  - 进前台任务时调一次**媒体引擎 `stop()`**（`非idle→idle` 跳变 → audio_service `stopService` 清锁屏卡片），取代旧 suppress
  - `setMediaSessionSuppressed` 及 handler 的 `_mediaSessionSuppressed` 整套删除
- **规则**：
  - **「某类任务要不要上锁屏」应由「用哪个引擎」表达，不要用运行时 flag 抑制共享 player** —— 后者必然要追着系统多通道+事件时序打补丁（§7.9/7.11 的反复）
  - 录音"采集"（`RecordingService`/`SpeechRecordingController`）与"回放用户录音"（`AudioPlaybackService`，独立 player）本就独立于引擎，不受本次影响
  - 无需 `PlaybackEngine` 接口：不存在「被媒体任务和前台任务按同一引擎类型共用」的编排代码（`SentencePlaybackEngine`/`StudyTaskControllerMixin` 的消费者全在前台侧），直接改类型/改调用点
- **相关代码**：`lib/providers/audio_engine/foreground_audio_engine_provider.dart`（新）、`sentence_playback_engine.dart`/`study_task_controller_mixin.dart`（改类型）、`learning_session_provider.dart`（`_ensureAudioLoaded(foreground:)` + 进任务 stop 媒体引擎）、5 个前台任务 provider（改引擎 + 去 suppress/bind/保活/mixin）、`audio_engine_provider.dart` + `background_audio_handler.dart`（删 suppress）
- **风险（待真机验证）**：iOS `AVAudioSession` 进程级共享，两个 player + 录音器对 category（playAndRecord）的争用本机/CI 测不到
- **修复时间**：2026-06-27

### 7.13 段落播放：position 追踪订阅早于 seek(0) 落定 → 高亮乱跳、断点被覆盖成首句

- **现象**：段落复述 / 全文盲听打开一段时偶发——当前选中（高亮）句突然乱跳，最终回到第一句起播（预期应从断点恢复处起播，已播完才从首句起播）
- **根因**：段落级 `_playCurrentParagraph` 先**同步**订阅 `absolutePositionStream`（`_startPositionTracking`），之后才 `await playRangeOnce`。而 `playRangeOnce` 内部按序做 `copyWith(clipStart=start)` → `setClip` → `seek(0)` → `play`，`absolutePositionStream = positionStream.map((rel) => clipStart + rel)`。在「订阅完成」到「seek(0) 落定」这段窗口里，位置流发出陈旧 position（旧 clipStart+旧 rel、或新 start+旧 rel），被 `_findSentenceIndex` 反查成错误句号 → ① 反复改写 `playingSentenceIndex`（乱跳）② 每次改写都 `_persistCurrentSentenceIndexAsync()` 写盘，陈旧 0 落在本段首句之前被 clamp 成 index 0 → **把断点覆盖成首句**（下次打开真从首句起播）③ 若开静音跳过，陈旧 position 经 `_maybeSkipSilence` 触发 `seekToAbsolute` 把音频 seek 走。竞态码自 578f8829 未变，§7.12 引擎拆分把复述切到 keepAlive 前台引擎（跨任务留旧 position + `_ensureAudioLoaded` 对同一音频跳过重载）后从潜在转为高频复现
- **解法**（同 §7.6「确定性 await，不依赖音频库回调时序」）：
  - 两个引擎 `playRangeOnce` 加 `onClipReady` 回调，在 `seek(0)` 落定、`play()` 之前回调一次；调用方此刻才 `_startPositionTracking`——位置流此后发出的是 seek 后的新位置（rel≈0 → 绝对位置≈start），从源头消除陈旧窗口
  - 监听器开头加越界丢弃兜底：position 落在 `[首句.start, 末句.end]` 外直接 return，绝不改高亮 / 写断点 / 触发静音跳过（防 seek 后仍残留一次旧 emission）
- **规则**：**段落/区间播放的 position 追踪必须等 `seek(0)` 落定后才订阅**（用 `onClipReady` 回调时机，不在 `playRangeOnce` 之前订阅）；监听器对越界 position 一律丢弃，不可让其改高亮或写断点
- **相关代码**：`lib/providers/audio_engine/foreground_audio_engine_provider.dart` / `audio_engine_provider.dart`（`playRangeOnce` 的 `onClipReady`）、`lib/providers/learning_session/retell_player_provider.dart` / `blind_listen_player_provider.dart`（`_playCurrentParagraph` 订阅后移 + `_startPositionTracking` 越界丢弃）
- **修复时间**：2026-06-27

### 7.14 盲听会话内中断用 stop（idle）反复拆/重建系统媒体会话 → 锁屏控件失效

- **现象**（iOS + Android 都有）：① 盲听锁屏「上一句/下一句」按钮可见但点击**无反应**；② 锁屏媒体控件有时不显示——冷启动后正常，用一段时间后就不再出现。精听无此问题
- **根因（单一根因，两处表现）**：锁屏卡片/控件的销毁由 **`processingState` 跳到 `idle`** 驱动——audio_service 监听到 `非idle→idle` 跳变即调 `stopService`（`audio_service.dart:1132`）→ iOS 把 `MPRemoteCommandCenter` 置 nil、移除全部命令 target、清 `nowPlayingInfo`（`AudioServicePlugin.m:230`）；Android 撤前台服务通知。`EchoLoopAudioHandler.stop()` 内 `_player.stop()`→idle→`_broadcastState()` 广播 idle，`AudioEngine.stopPlayback()/stop()` 都走它。**关键不对称**：精听每次中断走 `engine.pause()`→`pausePlayer()`（**非 idle**，不拆会话）；盲听每次暂停/切段/seek/改设置都走 `engine.stopPlayback()`（**idle→stopService**），于是每中断一次就把整个系统媒体会话拆掉再重建——拆掉后命令 target 被移除 → prev/next 死按钮（Bug②）；反复拆建、恢复依赖随后非 idle 广播精确落地、时序不稳 → 卡片偶发不再出现（Bug①，冷启动尚未拆除故正常）
- **解法**：盲听「会话内中断」与精听对齐——`engine.stopPlayback()` 改 `engine.pauseKeepSession()`（=`pausePlayer`，非 idle、不拆会话；session 已由调用点 `newSession()` 自行失效，故用不再 bump 的 `pauseKeepSession`）。共 4 处：`pause()` / `enterWaitingForUser()` / `updateSettings()` 模式切换 / `_cancelAll()`（被 seek/切段/重听共用）。**真正退出**（exitLearningMode → `practice.stop()` → idle）仍负责清卡片，不受影响
- **规则**：**接 audio_service 的媒体引擎，会话内的暂停/切句/seek 一律用 pause（非 idle），不能用 stop（idle）**——stop 只留给「真正退出该播放会话」。否则每次中断都触发 stopService 拆/重建系统媒体会话，锁屏控件失灵。录音类前台引擎不接 audio_service，不受此约束
- **相关代码**：`lib/providers/learning_session/blind_listen_player_provider.dart`（4 处 `stopPlayback`→`pauseKeepSession`）；对照 `intensive_listen_player_provider.dart`+`blind_practice_flow_engine.dart`（`callbacks.pauseAudio`→`engine.pause`）；`audio_engine_provider.dart`（`pauseKeepSession`/`stopPlayback`/`stop`）
- **修复时间**：2026-06-29
- **真机验证**：iOS/Android 锁屏点上一句下一句应正确切段；多次暂停/切段 + 长时使用后卡片仍显示；录音任务卡片仍消失、退出回 Free Player 正常

### 7.15 段落分段播放（clip）锁屏进度每切句归零：必须上报「绝对位置 + 全曲时长」

- **现象**：全文盲听点上一句/下一句，锁屏 now-playing 进度条总被清零
- **根因**：盲听每段用 `playRangeOnce` → `setClip(start,end)` 播放。just_audio 在 clip 下 `player.position` 是**相对 clip 起点**（切句重设 clip + `seek(0)` → 归零）、`player.duration` 是**clip 长度**。handler 此前直接广播 `updatePosition: _player.position` + duration 监听用 `player.duration` 覆盖 `mediaItem.duration` → 锁屏拿到「clip 相对位置 / clip 长度」，每切一段就归零
- **解法**：handler 记 `_clipStart`/`_clipActive`/`_fullDuration`——`setClip` 写入 clip 起点与激活态，`loadFile` 解析并复位全曲时长；`_broadcastState` 上报 `updatePosition = _clipStart + _player.position`（+ bufferedPosition 同理）；duration 监听在 clip 期间不让 clip 长度覆盖 `mediaItem.duration`，保持全曲时长。无 clip 时 `_clipStart=zero`，Free Player 整曲行为不变
- **规则**：**接 audio_service 的 clip 分段播放，锁屏进度必须上报「全曲绝对位置 + 全曲时长」，不能直接用 just_audio 的 clip 相对 position / clip 长度 duration**（否则切片即归零）。app 内进度走 `engine.absolutePositionStream`（已是 clipStart+rel），与本次锁屏修复同源不同通道
- **注意**：锁屏「拖动进度条」(`changePlaybackPositionCommand` → `handler.seek`) 仍是 clip 相对语义，与现上报的绝对位置不一致——盲听/精听未用此交互，属既有遗留，未在本次处理
- **相关代码**：`lib/services/background_audio_handler.dart`（`_clipStart`/`_clipActive`/`_fullDuration`、`setClip`/`loadFile`/`_durationSub`/`_broadcastState`）；测试 `test/services/background_audio_handler_test.dart`（clip 绝对位置 / 切段不归零 / clearClip 回退）
- **修复时间**：2026-06-29

### 7.16 停顿倒计时锁屏进度条仍前进、下一段又回退：必须上报 `speed=0` 冻结

- **现象**：全文盲听段落播完进入段间停顿倒计时期间，锁屏 now-playing 进度条仍持续往前走（越过段尾），下一段起播又回退
- **根因**：停顿期靠 `setSessionActive(true)` 保持 `_logicalPlaying=true`（锁屏图标显示「播放中」+ 静音保活让 Dart 倒计时后台推进）。`_broadcastState` 据此广播 `playing:true` + `speed:_player.speed`(>0)。iOS `MPNowPlayingInfoPropertyPlaybackRate = playing ? speed : 0`，rate>0 时系统按**墙钟时间外推** `elapsedPlaybackTime`（`AudioServicePlugin.m:288`），进度条自行前进；下一段 `setClip` 复位 `updatePosition` → 回退。问题本质是 iOS 端外推，主 player 实际已停在段尾
- **解法**：停顿期广播 `speed:0.0`（新增 `_progressFrozen` 开关），iOS rate=0 即不再外推，进度停在当前 `updatePosition`（段尾）；`playing` 仍读 `_effectivePlaying`(=true) 保持图标「播放中」——因 iOS 播放/暂停图标由 `center.playbackState`(读 `playing`，`AudioServicePlugin.m:294`) 驱动，与 rate 解耦。段落连续，下一段从段头(≈上段段尾)起播，无回退。`setProgressFrozen` 经 engine→mixin 暴露，provider 在 `_startPauseCountdown` 置 true、`_playCurrentParagraph`(实际起播) 置 false；`unbindLockScreen`/`loadFile` 复位 false 防泄漏到 Free Player
- **规则**：**「图标显示播放中但音频实际不前进」的场景（停顿倒计时）必须广播 `speed=0` 冻结锁屏进度**——iOS 进度外推只认 playbackRate，不能靠 `playing:false`（会误把图标切成暂停、且停保活）。图标真相源是 `playing`，进度外推真相源是 `speed`，二者要分别控制
- **相关代码**：`lib/services/background_audio_handler.dart`（`_progressFrozen`/`setProgressFrozen`/`_broadcastState` speed 分支）、`lib/providers/audio_engine/audio_engine_provider.dart` + `study_background_playback_mixin.dart`（passthrough + unbind 复位）、`lib/providers/learning_session/blind_listen_player_provider.dart`（`_startPauseCountdown` 冻结 / `_playCurrentParagraph` 解冻）；测试 `test/services/background_audio_handler_test.dart`（冻结 speed=0 / 图标不变 / 段尾位置不归零）
- **注意**：逐句精听（`intensive_listen_player_provider`）句间倒计时同属此类，本次未改；句子短、漂移小，如有反馈再按同法接 `setProgressFrozen`
- **修复时间**：2026-06-29
- **补充（2026-06-29）：Free Player 同源接入**
  - **现象**：Free Player（`ListeningPractice`）句间循环/整篇循环之间的停顿期间，锁屏进度条同样仍前进、下一遍起播又回退——与精听/盲听修复前同源。Free Player 走同一媒体引擎但从未调过 `setProgressFrozen`
  - **解法**：Free Player 所有停顿延迟唯一收敛到 `_delayInterval(interval)`（整篇/无字幕整篇/单句重播/跳句/gapless 交接 5 处调用点全经此）。在此单点包裹：延迟前 `_engine.setProgressFrozen(true)`、`finally` 中 `setProgressFrozen(false)`。`interval==0` 不触碰，`finally` 保证延迟异常/会话作废也不残留冻结态
  - **相关代码**：`lib/providers/listening_practice/listening_practice_provider.dart`（`_delayInterval`）；测试 `test/providers/listening_practice/free_player_playback_flow_test.dart`（「整篇循环间隔」用例断言停顿期 `progressFrozen==true`、起播后 `==false`）

### 7.17 合集内详情路由拍平在顶层 → 返回后自动多退一层（学习计划页 → 资源库）

- **现象**（Android 16 / Honor MagicOS）：随心听播放器点返回，先短暂停在学习计划页，随即**自动**又退到资源库列表页（合集 tab 根）。期望停在学习计划页
- **根因**：`app_router.dart` 把合集内音频详情页（学习计划 / 各播放器）声明成 **`StatefulShellRoute` 的顶层兄弟路由**（带 `parentNavigatorKey: rootNavigatorKey`），但路径 `/collections/:c/:a/plan` 与 branch-0 的 `/collections` 前缀重叠。正常入栈 `[Shell(branch-0=合集详情), plan, player]` 里，「合集详情」这一层是 imperative push、**只存在于页面栈、不编码进 URI**。go_router 17 在 `restoreRouteInformation` 后把当前 URI 回报框架；框架以 **null state** 回灌时（Android 生命周期/前台播放服务窗口焦点抖动触发），parser 走「合成 go → `findMatch(uri)` 从零重建栈」，而 `/collections/:c/:a/plan` 只匹配到顶层 plan 路由，shell 分支被重置回初始 location（资源库根），合集详情丢失。随后那一次返回 pop 掉 plan 就落到资源库根
- **解法**：把 7 条 `/collections/:c/:a/*`（plan/player/blind-listen/intensive-listen/listen-and-repeat/retell/review-difficult-practice）下沉为 branch-0 里 `:collectionId` 的**相对路径子路由**（`:audioId/plan` 等），**保留各自 `parentNavigatorKey: rootNavigatorKey`** 继续全屏无 tab bar。这样 URI 经由 shell 匹配、合集详情是匹配链里的真实祖先，重解析/恢复能重建出 `/collections/c1`，分支不再塌回根。`AppRoutes.*` 生成的字符串一字不变 → 调用点零改动。`/audio/:audioId/*` 系列不与任何分支前缀重叠，保持顶层不动
- **规则**：**`StatefulShellRoute` 全屏子页（带 rootNavigatorKey）若路径与某分支前缀重叠，必须嵌套在该分支子树内、用相对路径**，不能拍平成顶层兄弟路由——否则 null-state 重解析会按 URI 重建而丢失 imperative push 的中间层，把分支重置回初始 location。「是否上 tab bar」由 `parentNavigatorKey` 表达，「属于哪个分支」由路由树嵌套表达，二者解耦
- **相关代码**：`lib/router/app_router.dart`（branch-0 `:collectionId` 的 `routes:` 子路由）；测试 `test/router/app_router_test.dart`（嵌套结构重解析后 pop 回合集详情 / 顶层平级结构复现分支塌回根）
- **修复时间**：2026-06-29

### 7.18 统一 TTS：嵌入式发音组件不可在 provider build 期触碰平台/数据库（惰性化）

- **背景**：统一 TTS 架构（详见 PLAN.md ADR-8）。发音按钮 `SpeakButton` 是 `ConsumerWidget`，`watch(ttsControllerProvider)`；词典例句 `_ExampleView` 改 `ConsumerWidget` 内嵌它。结果：**任何宿主页面渲染发音按钮就会触发 `ttsControllerProvider.build`**。
- **现象**：初版 `ttsControllerProvider.build` 里 ① `initialTtsSettingsProvider` 未 override 时 `throw`（仿 learning_settings）② `ref.read(ttsCacheDaoProvider)` 立即连库 ③ `configure()` 立即 `engine.initialize()`（flutter_tts method channel）④ `Future.delayed` 起清理定时器。导致**多个现有 widget 测试**（词典弹窗 resize、ai_dict_result_view 等只想渲染 UI）抛 `No ProviderScope found`/`UnimplementedError`/`MissingPluginException`/pending-timer，header 拖拽布局也被异常打乱（resize 测试 24 例炸）。
- **根因**：发音是**辅助功能**，但其 provider 把"重副作用（DB/平台/定时器/必需 override）"放在 build 期同步执行，使"渲染一个喇叭图标"硬依赖整条 TTS+DB+平台栈就绪。
- **解法**（让"渲染发音按钮"零副作用，副作用全部惰性到"真正发音"时）：
  - `initialTtsSettingsProvider` 返回 `const TtsSettings()` 默认值（**不 throw**）——发音功能缺 override 时优雅降级，不崩宿主页（与 learning_settings 的"强制 override"取舍不同：那是核心流程，TTS 是辅助）
  - `TtsCacheStore` 的 DAO 改**惰性解析** `TtsCacheDao Function()`，只在 lookup/store/cleanup 真正读写时才 `ref.read(ttsCacheDaoProvider)`
  - `TtsCoordinator` 引擎**惰性创建**：`configure()` 只记录目标 kind/config（引擎已存在才热更新），首次 `speak()` 才 `_ensureEngine()` 建引擎 + `initialize`（flutter_tts 调用）+ 连库
  - 缓存清理定时器从 provider build **移到 main.dart**（`Future.delayed` 用 `database.ttsCacheDao` 直接构造，独立于 provider，widget 测试不触发 pending-timer）
  - 宿主测试该补 `ProviderScope` 的补（`ai_dict_result_view_test` 等视图现在消费 Riverpod）
- **规则**：
  - **被广泛内嵌的 Consumer 组件，其 provider 的 `build` 不得做 DB/平台通道/定时器/必需 override 等重副作用**——否则该组件的每个宿主页（含其 widget 测试）都被迫提供完整依赖栈。把副作用惰性到首次真实交互
  - 辅助功能的 initial-settings provider 倾向"默认值降级"而非"未 override 即 throw"；强制 throw 只留给核心流程（router redirect / 启动同步路径）
  - flutter_tts 在 widget 测试里调 method channel 会 `MissingPluginException`；引擎惰性化后，不点发音的测试根本不会实例化引擎，天然规避
- **相关代码**：`lib/providers/tts/tts_controller_provider.dart`（惰性 dao + 无定时器）、`tts_settings_provider.dart`（initial 默认值）、`lib/services/tts/tts_coordinator.dart`（`_ensureEngine` 惰性）、`tts_cache_store.dart`（`resolveDao`）、`lib/main.dart`（延迟 cleanup）
- **修复时间**：2026-06-28

### 7.19 macOS flutter_tts：synthesizeToFile 不设 voice，英/美音合成产物完全相同

> **已被 §7.24 取代（2026-06-30）**：不再「macOS 放弃合成 → 降级 speakLive 不缓存」，改为自家原生通道 `MacosTtsSynthHandler` 合成（正确设 voice → macOS 也缓存且口音正确）。本节保留为根因记录。

- **现象**：macOS 上切换英音(en-GB)/美音(en-US)，发音听起来没区别；iOS/Android 正常
- **根因**：统一 TTS 管线走「合成到文件→缓存→播放文件」（`synthesize`→`synthesizeToFile`）。对比 `flutter_tts-4.2.5` 两端插件源码——iOS `SwiftFlutterTtsPlugin.swift` 的 `synthesizeToFile` 合成前正确设 `utterance.voice = self.voice ?? AVSpeechSynthesisVoice(language: self.language)`；**macOS `FlutterTtsPlugin.swift` 的 `synthesizeToFile`（line 148-195）从不给 utterance 设 voice**（连 `self.voice` 都不读，只有 `speak` 设了），产物永远是系统默认音色 → 不管 `setLanguage('en-GB')` 还是 `'en-US'` 都同一个嗓音。cacheKey 因 voiceId 不同会建两条缓存，但音频内容相同。en-GB 音色其实已装（`say -v '?'` 可见 Daniel/Eddy(UK)），不是缺音色
- **关键约束**：macOS `synthesizeToFile` 连 `self.voice` 也不读，所以即便 `setVoice` 指定具体音色也无效——这条路在 macOS 上无解；唯有 `speak()`（实时朗读）会用 `AVSpeechSynthesisVoice(language:)`，口音才生效
- **解法**：`PlatformTtsEngine.synthesize` 在 macOS（`_accentAwareSynth()=false`）直接返回 null → 协调器降级 `speakLive`（走 `speak`，按 `setLanguage` 选 en-GB/en-US 音色）。代价：macOS 不缓存音频（非性能敏感平台，可接受）；iOS/Android 的 synthesizeToFile 正确设 voice，照常走缓存合成路径
- **规则**：依赖 flutter_tts `synthesizeToFile` 反映音色/口音前，须确认目标平台插件确实给 utterance 设了 voice——macOS 端漏设，是与 §7.5 isFullPath 同类的 macOS 平台遗漏。判断「平台是否支持口音合成」用注入式 `AccentAwareSynthResolver`（默认 `!Platform.isMacOS`），不在业务逻辑里硬判平台
- **相关代码**：`lib/services/tts/platform_tts_engine.dart`（`_accentAwareSynth` + `synthesize` 提前返回 null）；参照 `flutter_tts-4.2.5/macos/Classes/FlutterTtsPlugin.swift:148`（无 voice）vs `ios/Classes/SwiftFlutterTtsPlugin.swift:173`（有 voice）
- **修复时间**：2026-06-29

### 7.20 Echo Loop TTS（Kokoro / sherpa-onnx）接入要点（设计约束，详见 PLAN.md ADR-9）

- **模型必须取自 sherpa 官方打包，不能用裸 Kokoro onnx**：`sherpa_onnx` 的 `OfflineTts` 只能加载 sherpa 格式的 Kokoro（自带 `espeak-ng-data` 做 G2P）。thewh1teagle/kokoro-onnx 仓库的裸 onnx 用另一套音素化（misaki/phonemizer），**塞不进 sherpa FFI**。模型源 = k2-fsa/sherpa-onnx 的 TTS 发布，量化 int8 后重托管到 `cdn.echo-loop.top/model/tts/`，App 只从自家 CDN 下载（与 Whisper 一致）
- **`extractFileToDisk` 按扩展名识别格式**：`archive` 包的 `extractFileToDisk(inputPath, outputPath)` 用文件扩展名（最多 2 段，如 `.tar.gz`）判断解压方式。下载的临时归档**文件名必须以 `.tar.gz` 结尾**（本项目用 `_dl_<id>.tar.gz`），否则抛 `No file extension detected`。流式解包（`InputFileStream`）省内存，勿用 `readAsBytes` 全量读 98MB
- **`OfflineTts` 的 FFI 指针只能在创建它的 isolate 内用**：`generate`/`writeWave`/`free` 必须与 `OfflineTts(...)` 同 isolate。故 worker isolate 内建引擎、循环处理合成请求、回传 wav 路径（`GeneratedAudio.samples` 是 Dart `Float32List`，跨 isolate 可传，但本项目直接在 worker 内 `writeWave` 写盘更简单）。镜像 `sherpa_onnx_engine.dart` 的 `_AsrWorker` 结构
- **固定 `provider='cpu'`**：满足"一直 CPU、可靠"，规避 §7.4 的 NNAPI 崩溃路径；TTS 不用 VAD，不涉 §7.4 的 Silero VAD 崩溃
- **解包目录布局不写死**：归档解包后关键文件可能在根或子目录，用"递归定位 `model.int8.onnx`/`voices.bin`/`tokens.txt`/`espeak-ng-data`"判断就绪与解析路径（`KokoroModelManager._resolvePaths`），不假设层级
- **`speakLive` 返回 false 而非抛异常**：Kokoro 始终产文件，无实时兜底。合成失败时返回 null（synthesize）/ false（speakLive），让 ADR-8 共享协调器优雅静默，不在共享管线里抛
- **相关代码**：`lib/services/tts/kokoro_model_manager.dart`、`kokoro_synthesizer.dart`、`kokoro_tts_engine.dart`、`kokoro_voices.dart`、`lib/providers/tts/kokoro_model_provider.dart`、`tts_controller_provider.dart`（`effectiveTtsEngine` 门控）；集成测试 `integration_test/kokoro_tts_test.dart`
- **修复时间**：2026-06-29

### 7.21 Kokoro 归档若用 macOS tar 打包，PAX 扩展头令 archive 解压抛 FormatException

- **现象**：设置页选 Echo Loop TTS 触发下载，进度走完后报 `FormatException: Missing extension byte (at offset 98)`，点「重试」无效
- **排查方法论**：错误文案是 provider 兜底 `catch` 的 `'$e'`（非 `DioException`），先排除网络。逐段验证下载链路——`curl -I` CDN 返回 200 + 完整 ~98MB；`shasum` 与 `kokoroArchiveSha256` 一致 → 下载/SHA 全对，问题在解包。用项目 `archive` 包跑 `extractFileToDisk` 拿到栈:`TarDecoder.decodeStream:58` 的 `utf8.decode`
- **根因**：归档在 **macOS 用 `tar`/`bsdtar` 重新打包**，混入 AppleDouble(`._*`) 与 **PAX 扩展属性头**（`com.apple.*` xattr，值为二进制；本例 792 条）。`archive` 包 `tar_decoder.dart:58` 对 PAX `x`/`g` 头做**无 try/catch 的 `utf8.decode`**，碰非 UTF-8 字节即抛 `FormatException`，从 `extractFileToDisk` 冒泡到 provider。CDN/下载/SHA 全部正常
- **不能用 bz2 绕过**：sherpa-onnx 原始 `kokoro-int8-en-v0_19.tar.bz2`（Linux CI 打包）虽干净无 PAX，但 `archive` 包的 **bzip2 是纯 Dart 解码（无原生）**，解 ~100MB 移动端过慢（本机原生 `bunzip2` 都 >2min）；gzip 走 `dart:io` 原生 zlib，快
- **解法**：用 **gzip 重打且禁 macOS 元数据**——`COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata -czf kokoro-en-v0_19-int8.tar.gz model.int8.onnx voices.bin tokens.txt LICENSE espeak-ng-data`；重传 CDN 覆盖 `model/tts/kokoro-en-v0_19-int8.tar.gz`；更新 `kokoroArchiveSha256` 常量。客户端解包逻辑/`.tar.gz` 后缀不变
- **规则**：托管给客户端 `archive` 包解压的 tar.gz **不得含 macOS xattr/AppleDouble**（必在 Linux 打或加 `--no-xattrs --no-mac-metadata` + `COPYFILE_DISABLE=1`）；**不用 bz2**（纯 Dart 慢）。换归档必须同步改 SHA 常量，且**先传 CDN 再改常量/发版**，否则旧包对不上新 SHA
- **相关代码**：`lib/services/tts/kokoro_model_manager.dart`（`kokoroArchiveSha256`）；参照 `archive-4.0.7/lib/src/codecs/tar_decoder.dart:58`（PAX `utf8.decode` 无防护）
- **修复时间**：2026-06-29

### 7.22 TTS 音色试听/预热：音色经 config 显式传入 synthesize，统一 render 主干（设计约束）

- **背景**：Kokoro 首次合成有可感知延迟（CPU 推理 RTF≈3）。语音合成设置页落地业界标准「预生成 + 缓存命中即播」——进页面后台为全部 11 个音色预合成示范句入库，音色弹层点击即播（命中预热缓存秒播）。
- **核心约束（防竞态）**：试听/预热要用**与当前选中不同**的音色合成，但全 App 共用单个 Kokoro 引擎 + 单 worker isolate（顺序 FIFO）。**音色必须经 `TtsEngine.synthesize(..., config:)` 显式传入**，在方法入口**同步**解析 sid（`KokoroTtsEngine` 用 `config ?? _config`）——**不可**靠 `applyConfig` 改引擎环境态再合成：`applyConfig`(async) 与 `synthesize` 之间有 await 间隙，并发的另一次试听/预热会改写 `_config`，导致音频被写到错误 sid（同 §7.1/7.2/7.6 「不依赖跨边界的可变态」）。平台引擎无具名音色，音色仍由 `applyConfig` 的 setLanguage/setVoice 设定，`config` 不消费（脆弱的 §7.19 macOS 路径零回归）。
- **统一主干（避免打补丁）**：协调器只有一条渲染主干 `_render`（请求→缓存文件，cache-first 幂等，不碰播放器/代际）+ 一条播放主干 `_renderAndPlay`（抢占→渲染→播放→speakLive 降级）。`speak`/`speakWith`（试听）/`prewarm`（预热不播）全部委托主干，不新增与 `speak` 平行的重复逻辑。预热 fire-and-forget、命中缓存即跳过、按 `_prewarmToken` 取消在途旧批次。
- **在途去重（`_inFlightRender`）**：`_render` 按 cacheKey 记「合成在途」Future——缓存未命中时若同 key 已在合成（如预热某音色时用户恰好点该音色），**复用同一 Future**，不重复入 worker 队列、不重复跑 native generate，第二方等同一份产物。完成（含失败）后 `finally` 移除。检查+登记是同步段（无 await 间隙），故并发不会双登记。这是「点正在生成的 item」不再二次合成的关键。
- **缓存天然分桶**：缓存键含 `voiceId + modelTag(fp32/int8) + engine + speed + textHash`，故预热与试听用同句+同音色+同变体命中同一条目，无需新增缓存维度；切变体（modelTag 变）→ 新键 → 重新预热。
- **测试注意**：`TtsEngine.synthesize` 加 `config` 后，mocktail 桩须补 `config: any(named: 'config')`（协调器恒传 config，非 null 实参不匹配缺省桩会返回 null 致崩）；`deriveKey` 桩须含 `modelTag: any(named: 'modelTag')`（非 null modelTag）。`ConsumerState.dispose` 内**不可用 ref**，取消预热须用 build 时缓存的 notifier 引用。
- **相关代码**：`lib/services/tts/tts_coordinator.dart`（`_render`/`_renderAndPlay`/`speakWith`/`prewarm`）、`tts_engine.dart`/`kokoro_tts_engine.dart`/`platform_tts_engine.dart`（`synthesize` 的 `config`）、`lib/providers/tts/tts_controller_provider.dart`（`previewVoice`/`prewarmVoicePreviews`/`kTtsPreviewText`/`ttsVoicePreviewKey`）、`lib/screens/tts_settings_screen.dart`（`_VoicePreviewRow` + 进页预热）
- **完成时间**：2026-06-30

### 7.23 平台 TTS 口音试听：engine.stop() 打断在途 synthesizeToFile 致复用方挂起

- **现象**：把 §7.22 的「试听+预热」扩到平台 TTS 口音（点美音/英音即朗读，进页预热两口音）后，点击「美音」无声。日志只到 `[TtsCoordinator] 合成在途复用 key=… voice=en-US` 后**戛然而止**（无「播放」、无「降级 speakLive」、无异常）——典型「awaited Future 永不 resolve」。
- **根因**：进页预热把 en-US 合成登记为 `_inFlightRender` 在途 Future。用户点美音 → `previewAccent`→`speakWith`→`_renderAndPlay`。旧 `_renderAndPlay` 顺序是「`++gen` → `player.stop()` → **`engine.stop()`** → `_render`」。`engine.stop()`→平台引擎 `_tts.stop()` 在 `_render` 复用在途 Future **之前**就打断了那次正在跑的 `synthesizeToFile`——而 flutter_tts 的 `synthesizeToFile`(配 `awaitSynthCompletion(true)`)被 stop 打断后**完成回调可能永不到达**，其 Future 永久挂起 → 复用它的 `speakWith` 一起挂起。Kokoro 不复现：合成在 worker isolate 跑，`engine.stop()` 不影响它（同 §7.22 单 worker 串行，但 stop 动的是主 isolate 引擎态）。
- **解法**（同 §7.6/7.18「不依赖音频库回调时序，确定性 await」）：`_renderAndPlay` 改为「`++gen` → `player.stop()`（只动播放器、不碰合成，可安全前置即时切断旧音频）→ **先 `_render`**（复用在途合成、**不打断**它）→ 仅当 `_inFlightRender.isEmpty` 时才 `engine.stop()` → 播放」。两点缺一不可：① 渲染先于 stop，本次依赖的在途合成不被杀；② `engine.stop()` 用 `_inFlightRender.isEmpty` 门控，避免误杀**其他**在途合成（如另一口音的预热）使其 Future 挂起、后续点该口音复用时再次卡死。抢占仍由 generation 守卫 +（降级分支）`speakLive` 自带的 stop 保证。
- **平台引擎 config 修正**：平台 `synthesize` 旧版「不消费 config」、靠 `applyConfig` 环境态。试听非当前口音时产物口音错误却以目标口音 key 入缓存。改为 `config != null` 时入口 `applyConfig(config)`（按本次口音 `setLanguage`），使产物与缓存键一致。
- **规则**：
  - **平台引擎 `engine.stop()`（=`_tts.stop()`）绝不可在一段 `synthesizeToFile` 在途时调用**——会让其 Future 永久挂起。任何「抢占/打断」逻辑要么在合成完成后再 stop，要么用 `_inFlightRender.isEmpty` 门控跳过。
  - 切断旧**播放**用 `player.stop()`（安全、即时）；切断旧**实时朗读**靠 `speakLive` 自带的 `await stop()`；二者都不该为抢占而盲目 `engine.stop()`。
- **相关代码**：`lib/services/tts/tts_coordinator.dart`（`_renderAndPlay` 重排 + `_inFlightRender.isEmpty` 门控）、`platform_tts_engine.dart`（`synthesize` 应用传入 config）、`lib/providers/tts/tts_controller_provider.dart`（`previewAccent`/`prewarmAccentPreviews`/`ttsAccentPreviewKey`）、`lib/screens/tts_settings_screen.dart`（`_AccentPreviewRow`）
- **修复时间**：2026-06-30

### 7.24 macOS 平台 TTS 自实现 synthesizeToFile（原生通道）→ 三端合成行为一致

- **背景**：§7.19 因 flutter_tts 4.2.5 的 macOS `synthesizeToFile` 漏设 voice，让 macOS「放弃合成 → 降级 speakLive」。代价是 **macOS 平台 TTS 永不入 `tts_cache`**（speakLive 不产文件），用户观察到「Apple 语音播完没缓存、tts_cache 里 engine 全是 echoLoop」。iOS/Android 的 synthesizeToFile 正确设 voice、照常缓存——三端行为不一致。
- **解法（自实现 synthesizeToFile，仅补 macOS）**：新增原生 handler `macos/Runner/MacosTtsSynthHandler.swift`（通道 `top.echo-loop/tts_synth`，方法 `synthesizeToFile`），用 `AVSpeechSynthesizer.write` 自行合成，合成前**正确设 `utterance.voice = AVSpeechSynthesisVoice(language:)`**（flutter_tts 漏的就是这步），按 PCM buffer 写 caf 到调用方给的**绝对路径**。`PlatformTtsEngine` 在 macOS（`_useNativeMacosSynth()=true`）走该通道，iOS/Android 仍用 flutter_tts（本就正常，零改动）。结果：三端都「合成入缓存 + 口音正确」。
- **要点 / 坑**：
  - **末尾空 buffer = 合成结束**：`synth.write` 的 buffer 回调最后会以 `frameLength==0` 触发，据此判定完成（对齐 flutter_tts 自身实现）；完成时先 `output=nil` 关闭 `AVAudioFile`（flush 落盘）**再**回报结果，确保 Dart 读取时文件已写完。
  - **`FlutterResult` 必须主线程调用**：write 回调在后台队列，完成回报用 `DispatchQueue.main.async`。
  - **macOS 10.15+**：`AVSpeechSynthesizer.write` 需 10.15+，低版本返回 FlutterError（协调器降级 speakLive）。
  - **新 Swift 文件要登记 pbxproj**：macOS Runner 用 Xcode 工程，新增 `.swift` 必须在 `Runner.xcodeproj/project.pbxproj` 补 4 处（PBXBuildFile / PBXFileReference / Runner group children / Sources build phase），否则不参与编译。镜像 `NotificationPermissionHandler.swift` 的条目即可（注意分配新的唯一 ID）。`MainFlutterWindow.swift` 里 `awakeFromNib` 实例化并强引用持有 handler（同其他 Mac*Handler）。
  - **失败优雅降级**：原生返回 false / 产出为空 → `synthesize` 返回 null → 协调器降级 speakLive（macOS speak 仍按 `setLanguage` 选英/美音，口音不丢）。
  - **音色注入式可测**：`PlatformTtsEngine` 把「是否走原生」与「原生合成函数」做成注入参数（`NativeMacosSynthResolver`/`NativeMacosSynthesize`），单测无需真机/真通道；§7.19 遗留的 `accentAwareSynth`/`useDocumentsWorkaround`/`documentsDirResolver` 及 Documents 中转修法一并删除（macOS 不再经 flutter_tts 合成，Documents 中转无意义）。
- **相关代码**：`macos/Runner/MacosTtsSynthHandler.swift`（新）、`macos/Runner/MainFlutterWindow.swift`（注册）、`macos/Runner.xcodeproj/project.pbxproj`（登记）、`lib/services/tts/platform_tts_engine.dart`（`_useNativeMacosSynth`/`_nativeMacosSynth`/`_synthesizeViaNativeMacos`）；测试 `test/services/tts/platform_tts_engine_test.dart`（原生成功/失败/空产出）
- **修复时间**：2026-06-30

### 7.25 词典交互：非 modal 常驻面板 + 词组选区手柄（设计约束）

- **背景**：旧词典是 `showModalBottomSheet`（遮蔽、抢焦点，查下一个词必须先关弹窗），且只支持点单个单词。按业界标准（每日英语听力/LingQ/Kindle：高频查词一致用非 modal 面板 + 选区扩展）重设计。
- **架构**：
  - **面板宿主** `DictionaryPanelHost`：包在各宿主页 Scaffold body 外的 **Stack 内嵌常驻面板**（非 showBottomSheet——有 LocalHistoryEntry/返回键纠缠；非 OverlayEntry——命令式生命周期易泄漏）。面板状态是**页面局部 state**（谁创建谁销毁，页面 pop 即销毁，autoDispose 查词 controller 随之释放）。面板开着时正文可继续点词，`show()` 原地切换内容不重开。
  - **词组选择 = 选区手柄**：`SelectableSentenceText`（统一了标注卡 RichText+recognizer 与盲听 Wrap+GestureDetector 两套旧实现）。点词即查并出现左右手柄（词级吸附），拖动扩选、松手查词组。手柄用 `ImmediateMultiDragGestureRecognizer` 按下即赢得竞技场（Flutter 系统选择手柄同款），不与滚动/PageView/长按冲突 → **「长按复制整句」保留不动**。
  - **几何**：RichText + `RenderParagraph.getPositionForOffset`（命中）/`getBoxesForSelection`（手柄定位，post-frame 计算）。选区清理经宿主 `activeOwnerOf`（InheritedWidget 依赖面）：面板关闭或别处点词即自动清。
- **规则**：
  - **返回键**：已有 PopScope 的宿主在 `_handleExit` **首行**加 `closeIfOpen()` guard，**禁止**宿主内再注册第二个 PopScope（同路由多 PopScope 触发顺序无保证）；无 PopScope 的页面用宿主 `handleBackButton: true`。
  - **点面板外关闭 = 带词区域豁免的屏障**（2026-07-02 用户真机反馈后由「不做点空白关闭」改为此方案）：面板开着时正文上盖透明屏障（Stack 中位于正文之上、面板之下），点句子里的词/拖手柄经**豁免区域**放行（连续查词/扩选不受影响），点其它区域先关面板并**吸收该次点击**（不触发下层操作，如盲听偷看切换）。豁免判定由 `SelectableSentenceText` 挂载时向宿主 `registerTapThroughHitTest(全局坐标命中谓词)` 注册、卸载时注销；谓词 = 文本 bounds ∪ 两个手柄命中区（与 `_buildHandle` 共用 `_handleHitRect` 公式），**必须精确、不得外扩粗矩形**——初版用「组件 bounds 上下外扩 36dp」的 Rect getter，句子紧邻的下层交互被误放行（盲听点句子上方一条带子触发隐藏字幕、标注卡解析按钮被误点，2026-07-02 二次真机反馈修正）；屏障用自定义 `RenderProxyBox.hitTest`（豁免命中返回 false 穿透）+ `Listener.onPointerDown` 关面板（非手势竞技场，即时且无歧义吸收）。**不要**用 translucent Listener——事件会同时到达下层，正好触发用户不想要的主屏操作。
  - **手柄悬垂越界命中**：手柄/竖线悬在文本 bounds 外（末行下方、行首左侧），普通 Stack 的 `hitTest` 在 `size.contains` 处提前剪裁导致悬垂部分不可拖——组件用 `_UnboundedHitStack`（重写 `hitTest` 跳过自身 size 剪裁、直接测子节点）。手柄视觉=iOS 系统选择手柄同款：选区边界竖线（行高）+ 圆点（与竖线端点相切；起始手柄圆点在竖线上端、结束手柄在下端），直径较系统略大（12dp）便于点按，命中区 36dp 以圆点为中心（2026-07-02 真机反馈由 Android 水滴改为 iOS 圆点）。
  - **面板默认高度 3/5 屏**（2026-07-02 真机反馈两轮调整：2/3 偏高、1/2 偏低，3/5 折中）：可拉伸源（AI/网页）默认与本地源限高统一 3/5，上拉可放大到 95%。
  - **会话粘滞源**：`DictionarySessionSource`（keepAlive）记录用户面板会话内手动选中的源；查词 controller（autoDispose family，切词即重建）初始源优先级 = 粘滞源 > 词组 AI 偏好 > 全局默认。面板 dispose 时清除（**须推迟到微任务**——dispose 处于树 finalize 流程，同步改 provider 触发 Riverpod 断言），下次打开恢复默认。
  - **词组查询管线**：`normalizeWord` 已折叠内部空白；controller 对含空格 key 默认选 AI 源；AI 缓存 key（`normalizeForCache`）天然兼容词组。**V1 不带句子上下文**——带则缓存 key/family key 必须复合 sentenceHash，命中率崩塌且后端要改协议（`DictionaryLookupRequest.sentence` 已预留）。
  - 新增可点词渲染场景一律复用 `SelectableSentenceText`，不要再造分词/recognizer。
- **相关代码**：`lib/widgets/dictionary/dictionary_panel_host.dart`、`dictionary_panel.dart`、`lib/widgets/practice/selectable_sentence_text.dart`、`sentence_word_selection.dart`、`lib/providers/dictionary/lookup_controller.dart`（`_resolveInitialSourceId`）、`lib/utils/text_normalize.dart`；测试 `test/widgets/dictionary/dictionary_panel_test.dart` 等
- **完成时间**：2026-07-02
