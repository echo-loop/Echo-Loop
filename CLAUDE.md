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
