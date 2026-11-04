# 踩坑记录（Troubleshooting）

记录已修复的典型问题和设计约束，防止同类问题再次出现。

本文件原为根目录 `CLAUDE.md` 第 7 节，已迁移至此。编号沿用原 §7 编号（如 §7.12），既有的引用仍可对应。

## 使用约定

- **查询**：按关键词搜索（如 `grep -n "锁屏" docs/troubleshooting.md`），或按下方索引定位。
- **记录**：修复典型问题或确立设计约束后，在文件末尾追加新条目，编号顺延。条目结构为：现象 / 根因 / 解法 / 规则 / 相关代码 / 修复时间，按需取舍。
- **未解决**的问题在标题中标注（**未解决**），解决后去掉标注并补充解法。
- **不写入 `CLAUDE.md`**：`CLAUDE.md` 只保留开发规范，踩坑记录统一放在本文件。

## 索引

- 7.1 iOS 语音识别：异步回调破坏新 session
- 7.2 flutter_tts：快速 stop→speak 导致 awaitSpeakCompletion 失效
- 7.3 Android versionCode 必须全局单调递增，与 versionName 解耦
- 7.4 离线 ASR：sherpa-onnx Silero VAD native 推理在部分机型 abort（**未解决**）
- 7.5 清除缓存误删系统 URLCache 导致 disk I/O error
- 7.6 just_audio：整篇循环依赖 completed 事件做反应式计数不可靠
- 7.7 锁屏：向系统上报 `completed` 导致整篇循环进度条偶发卡在结尾
- 7.8 release 资源压缩删掉通知图标，锁屏/通知栏媒体控件整体消失（仅 release）
- 7.9 录音类任务抑制锁屏的三个坑（iOS MediaItem/position 通道 + Android「先 load 后 suppress」时序）
- 7.10 学习任务后台播放：静音保活音量必须 1.0；锁屏切句回调每任务绑一次
- 7.11 录音类任务仍显示锁屏：suppress(false) 在 idle 时重发 MediaItem 贴出无法清除的残留卡片
- 7.12 媒体引擎 / 前台引擎分离：把「是否上锁屏」做成结构性属性而非运行时开关
- 7.13 段落播放：position 追踪订阅早于 seek(0) 落定 → 高亮乱跳、断点被覆盖成首句
- 7.14 盲听会话内中断用 stop（idle）反复拆/重建系统媒体会话 → 锁屏控件失效
- 7.15 段落分段播放（clip）锁屏进度每切句归零：必须上报「绝对位置 + 全曲时长」
- 7.16 停顿倒计时锁屏进度条仍前进、下一段又回退：必须上报 `speed=0` 冻结
- 7.17 合集内详情路由拍平在顶层 → 返回后自动多退一层（学习计划页 → 资源库）
- 7.18 统一 TTS：嵌入式发音组件不可在 provider build 期触碰平台/数据库（惰性化）
- 7.19 macOS flutter_tts：synthesizeToFile 不设 voice，英/美音合成产物完全相同
- 7.20 Echo Loop TTS（Kokoro / sherpa-onnx）接入要点（设计约束，详见 PLAN.md ADR-9）
- 7.21 Kokoro 归档若用 macOS tar 打包，PAX 扩展头令 archive 解压抛 FormatException
- 7.22 TTS 音色试听/预热：音色经 config 显式传入 synthesize，统一 render 主干（设计约束）
- 7.23 平台 TTS 口音试听：engine.stop() 打断在途 synthesizeToFile 致复用方挂起
- 7.24 macOS 平台 TTS 自实现 synthesizeToFile（原生通道）→ 三端合成行为一致
- 7.25 词典交互：非 modal 常驻面板 + 词组选区手柄（设计约束）
- 7.26 流式 AI 词典（NDJSON 部分对象快照）：设计约束与踩坑
- 7.27 流式 AI 词典：帧协议由「累计完整快照」改为「字段级增量」
- 7.28 选区能力三层化：自有 selection model + 平台手柄画笔（取代 SelectableText）
- 7.29 长期分支落地覆盖主干英文文案：`app_en.arb` 256 个 key 静默回退，且被后续测试"修复"坐实
- 7.30 跟读实时 VAD：固定 RMS 门槛把小声用户判成静音 → 说话中途被自动结束录音
- 7.31 复述重听本段：清理录音置 idle 触发自动录音，抢在原文播放前启动 → 原音被录进去
- 7.32 media_kit 区间播放：软停止越过句尾带出下一句；seek 未落定就起播
- 7.33 共享合集 / 播客未下载材料进入学习计划页：入口判断分散 → 进入逐句精听报 `file unavailable`
- 7.37 同一资源多入口下载：查找再登记导致重复任务，取消需绑定具体任务
- 7.38 Riverpod 3 暂停无监听 StreamProvider：启动会话永久挂起，登录后仍提示未登录
- 7.41 百度网盘批量导入：下载时才取 dlink，切后台后队列无法接力下一个文件

---

## 条目

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

### 7.26 流式 AI 词典（NDJSON 部分对象快照）：设计约束与踩坑

- **背景**：词典查词原为同步阻塞（`await` 完整 JSON → 一次性 shimmer→完整）。改为流式后端逐帧下发部分对象快照，首 token 延迟大幅下降、字段逐块渐显。拆成两个独立端点 `POST /api/v1/stream/lookup-word`（单词）与 `/lookup-phrase`（多词），各自持有 prompt+schema；**客户端按规范化后是否含空白路由**（`normalizeWord(word).contains(' ')`，规则同后端原 `resolveQueryType`）。旧 combined 同步端点 `/api/v2/ai/dictionary` 保留给老客户端。
- **传输 = NDJSON**（`\n` 分隔，`application/x-ndjson`）。选它而非 SSE：Flutter 无原生 EventSource，NDJSON 用 `utf8.decoder`+`LineSplitter` 两个标准 transformer 即可，无需容错半截 JSON。**注：帧载荷已由「每帧完整累计快照」改为「字段级增量事件」，见 §7.27（本节其余设计不变）。**
- **模型天然兼容部分帧**：`AiDictionaryEntry.fromJson` 已全防御性解析（缺字段回退空串/空列表，永不抛错），**无需 `fromPartialJson`**，每帧直接 `fromJson`。sealed 分派靠 `queryType`/`originalExpression`，故**服务端每帧注入 `queryType`**，客户端首帧即选对子类。视图各区块 `if (isNotEmpty)` 门控 → 部分帧自然逐块渐显。新增 `LookupStreaming` 态承载部分结果，完成转 `LookupLoaded`。
- **取消即止损（刻意反转旧「后台单请求语义」）**：旧 `AiDictionarySource` 忽略 CancelToken、跑完落缓存。流式路径**尊重取消**——controller 取消 token → Dio 关流 → 后端 `request.signal` abort → `streamObject` abort → 中断 LLM 省 token；**未完整读完不落缓存**（部分结果丢弃）。仅流正常读完才写 L1+L2。
- **缓存模拟流式的边界**：**服务端** L3/L4 命中按 key 顺序累计吐帧（首块 ~0.5s）；**客户端 L1/L2 本地命中直接整块即时返回**（0 延迟，不模拟）。
- **踩坑**：
  - **`Stream<Uint8List>.transform(utf8.decoder)` 运行时协变检查失败**（要求 `StreamTransformer<Uint8List,String>`，而 `utf8.decoder` 是 `<List<int>,String>`）。Dio 的 `ResponseBody.stream` 实为 `Stream<Uint8List>` → 必须先 `.cast<List<int>>()` 再 transform。见 `lib/services/ndjson_stream.dart`。
  - **前置错误体在 stream 模式下是未解析的 `ResponseBody`**：`_streamDictionary` 用 `validateStatus: (_) => true`（Dio 不在非 2xx 提前抛），手动读小 JSON 错误体取 `code`，映射为 `DictionaryPhraseTooLongException`/`DictionaryAuthRequiredException`/带状态码的 `DioException`（402 沿用 controller 现有分支）。
  - **流内错误无 HTTP 状态**（200 已发）：后端末帧发 `{"__error": ...}`，客户端识别 → `DictionaryStreamException` → controller 转 `LookupError`（可重试）。
  - **服务端 `streamObject` 错误不从流里抛**，而经 `onError` 回调 + `object` Promise reject。glue 靠 `await object` 的 reject 判失败；且**入库回调 `onComplete` 只在完整对象成功后 await 执行**（写在完整帧之后、`controller.close()` 之前，保证「完成才写、取消不写」）。
  - **`ApiLogInterceptor` 跳过 stream 响应体**（`responseType == ResponseType.stream` 时不 `_stringifyBody`，避免序列化/误触碰未消费的流）。
- **相关代码**：客户端 `lib/services/ndjson_stream.dart`、`sentence_ai_api_client.dart`（`lookupWordStream`/`lookupPhraseStream`/`_streamDictionary`）、`dictionary/ai_dictionary_source.dart`（`lookupStream`）、`providers/dictionary/lookup_controller.dart`（`LookupStreaming` + AI 流式分支）、`widgets/dictionary/ai_dict_result_view.dart`、`services/api_log_interceptor.dart`；后端 `packages/ai/lib/stream-structured.ts`、`apps/app/app/api/v1/stream/{_shared,lookup-word,lookup-phrase}`、`apps/app/app/api/v2/ai/dictionary/_shared.ts`。测试：`test/services/ndjson_stream_test.dart`、`sentence_ai_api_client_test.dart`、`dictionary/ai_dictionary_source_test.dart`、`providers/dictionary/lookup_controller_test.dart`、`widgets/dictionary/ai_dict_result_view_test.dart`；`packages/ai/__tests__/stream-structured.test.ts`、`apps/app/__tests__/stream-lookup-{word,phrase}-route.test.ts`。
- **待真机验证**：断连确实触发 Vercel `request.signal` abort（本机/CI 测不到）；gpt-5-mini 经 AI Gateway 的 `streamObject` 逐帧到达。
- **完成时间**：2026-07-08

### 7.27 流式 AI 词典：帧协议由「累计完整快照」改为「字段级增量」

- **背景/动机**：§7.26 的 NDJSON 每帧下发**当前累计的完整对象快照**，后一帧包含前一帧全部内容 → 总传输量 O(n²)。真机日志（查 `what's`）显示最终对象 ~1862B，却分 20 帧、每帧把已发内容整份重发。加 500ms 节流 + 相邻字节去重只能压掉「字段没变时的重复帧」，压不掉「每帧重发已完成字段」这个根本浪费。
- **新协议（NDJSON，每行一个 JSON object；只有一种数据操作：按路径设标量叶子）**：
  - 元信息（首行）`{"q":"single_word"|"multi_word"}` → 客户端播种 `acc={"queryType":q}`，sealed 分派尽早确定。
  - 叶子赋值 `{"p":["meanings",0,"definition"],"v":<scalar>}` → 每个**标量叶子（任意嵌套深度）**写完发一次，用路径寻址；数组由 int 路径段 + 客户端**自动扩容**隐式处理，无 append 操作。任何内容只发一次（O(n)）。
  - 结束 `{"done":true}` → isFinal 帧、落缓存；错误 `{"__error":"unavailable"}` → `DictionaryStreamException`。
  - 标量长文本**整段一次到位**（写完才发、不逐字流出）；数组/嵌套元素逐个渐显。空数组无叶子 → 不下发（`fromJson` 走默认空值，视图自然隐藏）。`thinking` 及其子路径永不下发。
- **后端**（`apps/app/app/api/v1/stream/_shared.ts`）：核心是递归 `emitStableLeaves(node,path,complete,emittedSet,out)`——`complete=false` 表示「在正在书写的尾部边缘」，一路 hold 到最深尾部叶子稳定；依据「AI SDK 部分解析器只有在对象/元素 JSON 闭合后才出现下一个键/元素」，故非末位子节点必已内部写完。真流式保留 500ms 批量节流、`emittedSet` 跨 flush 保证只发一次、末尾把整个 `full` 当完整补发剩余叶子 + `done`；缓存命中路径按 KEY_ORDER 重排顶层键后一次性发全部叶子、按叶子文本量控速。`onComplete` 入库仍存**含 thinking** 的完整 entry，不变。
- **客户端**（`lib/services/sentence_ai_api_client.dart`）：改造**收敛在 `_streamDictionaryFrames` 一处**——维护累积 `acc`，`{q}` 写 queryType、`{p,v}` 走 `_setPath`（按下一段类型自动建 List/Map、按需 null 扩容）、`{done}` 发 isFinal 帧；每个叶子事件后整体 `AiDictionaryEntry.fromJson(acc)` 再 yield 完整 `AiDictionaryStreamFrame`。**`AiDictionaryStreamFrame` 契约（entry+isFinal）不变** → `ai_dictionary_source.dart`（`last`=末帧完整 entry / `sawFinal` / 落缓存）、`lookup_controller.dart`、`ai_dict_result_view.dart`/`ai_multi_word_result_view.dart`、`dictionary_entry.dart` 模型**全部零改动**。`decodeNdjson` 也不变（仍逐行 yield Map）。
- **规则**：流式结构化对象要「增量下发、不重发」时，用**按路径设叶子**的单操作协议 + 客户端 `_setPath` 自动建容器拼装，别用「每帧完整快照」（O(n²)）；发射端靠「尾部边缘 hold、非末位必闭合」的递归规则判定叶子是否稳定，不依赖 per-schema 元信息（运行时结构判断即可）。
- **相关代码**：后端 `apps/app/app/api/v1/stream/_shared.ts`（`emitStableLeaves`/`buildNdjsonStreamResponse`/`buildRevealResponse`）；客户端 `lib/services/sentence_ai_api_client.dart`（`_streamDictionaryFrames`/`_setPath`）。测试：`apps/app/__tests__/stream-lookup-{word,phrase}-route.test.ts`（叶子拼装 `assemble` + `dropEmptyArrays`）、`test/services/sentence_ai_api_client_test.dart`（叶子增量 + 嵌套路径累积）。
- **完成时间**：2026-07-09
### 7.28 选区能力三层化：自有 selection model + 平台手柄画笔（取代 SelectableText）

- **根因**：Flutter 两个官方选区机制都在**前台失焦时清空选区**（`material/selectable_text.dart`
  `_handleFocusChanged`、`widgets/selectable_region.dart` `_handleFocusChanged`），
  且 `SelectableText.didUpdateWidget` 在 `textSpan` 变化时重建 controller 让选区归零
  （`_TextSpanEditingController._textSpan` 是 final）。而「选中文字 → 在页面内面板里
  查词/切源/收藏 → 选区必须还在」与该契约直接冲突，只能靠反向投影补救（2026-07-29
  一晚 7 个补丁的来源）。
- **规则**：选区需跨交互存活 / 需自定义词边界 / 需自定义操作条时，用**自有 selection
  model + 平台 `TextSelectionControls` 手柄画笔**（`SelectableRegion` 同款分层），
  **不要**用 `SelectableText` 或 `SelectionArea`。分三层：L1 会话（唯一真相源，只存
  字符区间 + 内容身份，不含焦点概念，`idle/selecting/active` 三态）、L2 呈现（平台
  手柄、tight 高亮、操作条、放大镜）、L3 `SelectionBackend`（命中/词边界/几何/取文本，
  单段与跨块的唯一差异点）。
- **词边界单一来源**：点词一律用业务自己的分词，**不能**用 `selectWord()`/ICU 边界——
  ICU 把 `co-op` 断成 `co`/`-`/`op`、`e.g.` 断成 `e`/`.`/`g`，会让高亮、查询与两个收藏
  入口各存不同的词。
- **操作条必须挂页面级宿主**：它会溢出内容的 render box，而**祖先按各自 box 剪裁命中
  测试**，挂在内容自己的 Stack 里溢出部分点不动（跳过自身剪裁的 `UnboundedHitStack`
  只解决自身那一层，够手柄用、不够操作条用）；挂根 Overlay 又会盖在页面内面板之上。
  正确层序：`正文 → 关面板屏障 → 操作条 → 面板`，遮挡与可点性全由层序解决，不做几何
  同步。锚点用全局坐标推送，由宿主换算（图层自身首次 build 时 `findRenderObject()`
  仍为 null，不能就地换算）。操作条挂在 Scrollable 外，故正文滚出视口时要主动收起
  （`rectsVisibleInViewport`）。
- **不用 `SelectionOverlay`**：它把手柄挂到「最近包含 context 的 Overlay」，手柄会跑到
  根 Overlay，遮挡与滚动跟随又得手算。手柄当普通 widget 放进内容 Stack 即可。
- **平台行为对齐**：长按拖选在 Android/Fuchsia/Linux/Windows 按**词**粒度、iOS/macOS 按
  字符（同框架 `selectWordsInRange` / `selectPositionAt`）；手柄拖拽所有平台都是字符级。
  手柄命中区以平台 `getHandleAnchor`/`getHandleSize` 推导后放大到 36dp（框架自身用 48dp）。
- **tight 高亮**：`Selectable` 协议内部硬编码 `boxHeightStyle: max`
  （`rendering/paragraph.dart`），所以**只要不走该协议**（单段与跨块 backend 都自己
  读段落几何）就能全程用 tight，两处观感一致。
- **桌面交互必须自己补齐**（`SelectableText` 白送的，自有实现一样都不会有）：mouse
  drag-select（限定 `PointerDeviceKind.mouse` 的 `PanGestureRecognizer`，且必须
  `DragStartBehavior.down`——默认的 `.start` 报的是「拖动被识别时」的位置，选区起点
  会偏移且触发识别的位移被并入 `onStart` 收不到 `onUpdate`）、**点击手抖兜底**（鼠标
  slop 只有 1 逻辑像素 `kPrecisePointerHitSlop`，抖 2px 就让 pan 赢 tap 输，pan 结束
  时未形成选区要按点击处理）、I-beam 光标、**双击选词 / Shift+点击扩选 / Shift+方向键
  扩选 / Cmd+C**（2026-07-30 补齐）。尚未做：三击选段 / Cmd+A / 拖动已选文本。
- **双击不能用 `DoubleTapGestureRecognizer`**：它会 hold 住手势竞技场，单击要等双击
  超时（约 300ms）才生效，点词查词整体变迟钝。自己在 tap 里按「时间窗 + slop」判定
  （`TapCadence`），单击零延迟。
- **键盘扩选没有光标态**：本实现只有选区，没有 caret，所以无选区时 Shift+方向键不做
  任何事；缩回固定端等于选区归零，按结束会话处理。上下行移动走**光标几何**
  （`caretRectAt` + `offsetAt`），不假设行结构，跨块也能跨到相邻块。Cmd/Ctrl+C **保留**
  选区（平台标准），与操作条里业务定义的「复制并结束会话」是两个动作。焦点只用于
  键盘事件路由，且**只有鼠标交互才 requestFocus**（触屏 requestFocus 会收起软键盘）。
- **长按落在词间空白**不能直接 return（会变成死手势）：把锚点定在该字符，拖出第一个
  字符再建立会话。
- **跨块 backend（AI 回答）不走 `SelectionContainer`/`Selectable`**：除了上面的 max
  高亮与失焦清选区，官方注册表在流式 markdown 帧末增删子节点时还会重入
  （`ConcurrentModificationError`，T16 修过）。改为直接读渲染树拼扁平字符空间。三个
  非直觉点：①**文档顺序必须按占位符递归**——`gpt_markdown` 把整段渲染成一个根
  `RichText`，块级元素（标题/列表/引用/表格）是 `WidgetSpan` 占位符，占位符里又是
  新的 `RichText`，即**子块嵌在父段落内部**，按「渲染树遇到的先后」排会错乱；正确做法
  是父段落文本被占位符切成多段、占位符处插入子块（`RenderParagraph` 的占位符子节点
  顺序 == span 中出现顺序，下标即对应）。②命中判定要用**段自身文本的矩形**，不能用
  段落 box——嵌套结构下父 box 覆盖子块，会命中外层。③相邻两段之间没有换行/空白时补
  一个换行（表格相邻单元格），该换行占扁平偏移但不属于任何段。
- **内容变化 / 卸载时通知宿主必须推迟一帧**：`didUpdateWidget`、`dispose` 里直接调
  `onHideToolbar` / `onSessionEnded` 会 setState 到**祖先**宿主，触发
  「markNeedsBuild called during build」；流式 AI 回答每帧都会走到这条路径。
- **内容被整块摘掉时也要收操作条**（`dispose`，不只是 `didUpdateWidget`）：聊天
  「新会话」清空消息会直接卸载 AI 回答，操作条否则孤零零留在空白页上。因此
  「收操作条」的回调必须**携带 owner**、不依赖 `currentState` / `context`（卸载后
  两者都失效），宿主 show/hide 也要加 `mounted` 守卫（延迟回调可能晚于宿主销毁）。
- **操作条挂载点抽象为 `SelectionToolbarMount` + `SelectionToolbarScope`**：查词页由
  `DictionaryPanelHost` 实现（层序 `正文 → 屏障 → 操作条 → 面板`），无面板的页面
  （聊天载体 `ChatView`）用通用 `SelectionToolbarHost`；内容组件只认接口，不关心自己
  被放进了哪种页面。
- **已知代价**（明确接受）：不提供系统选区的无障碍语义；句子文本本身仍可被读屏朗读。依赖的 API 全部公开（`RenderParagraph` 几何、
  `TextSelectionControls`、`TextMagnifier`、`DefaultSelectionStyle`），无私有状态依赖。
- **相关代码**：`lib/widgets/selection/`——内核 `selectable_content`（L1+L2 组装、手势
  语义）、`text_selection_session`（L1）、L2 `selection_presentation` /
  `selection_gesture_detector` / `selection_extend` / `selection_keyboard` /
  `platform_selection_handles` / `selection_highlight` / `selection_magnifier` /
  `selection_toolbar(_layer/_host)` / `selection_geometry` / `unbounded_hit_stack`、
  L3 `selection_backend` + `paragraph_selection_backend`（单段）+
  `multi_paragraph_selection_backend`（跨块）、组装件 `app_selectable_text`（单段）；
  `lib/widgets/practice/selectable_sentence_text.dart`（查词业务薄封装）、
  `lib/features/chatbot/widgets/selectable_assistant_markdown.dart`（AI 回答薄封装）、
  `lib/widgets/dictionary/dictionary_panel_host.dart`（操作条挂载 + `isPanelOpenOf`）。
  测试：`test/widgets/selection/`（`text_selection_session_test` /
  `selectable_content_desktop_test`）、`test/widgets/practice/selectable_sentence_text_test.dart`、
  `test/features/chatbot/widgets/selectable_assistant_markdown_test.dart`。
- **仍在用 `SelectableText` 的地方**（有意保留）：设置页/调试页/播客信息等纯只读文本，
  没有「选区跨面板交互存活」「自定义词边界」「自定义操作条」的需求，用系统实现更省。
- **完成时间**：2026-07-30（三层化 + 桌面补齐 + AI 回答迁移）

### 7.29 长期分支落地覆盖主干英文文案：`app_en.arb` 256 个 key 静默回退，且被后续测试"修复"坐实

- **根因**：`video` 分支从 07-21 fork 后持续开发到 08-05 才落地，中途多次 `rebase onto`
  main 同步；分支自身在 07-29 有一个提交整份重写了 `app_en.arb`（连带 codegen 全量生成的
  `app_localizations_en.dart`/`app_localizations.dart`），其源头早于主干 07-28 那次英文文案
  优化（`ece1a4da`）。因为 codegen 文件几乎每行都会变，line-based 三方合并/冲突判定在这种
  「整份重写」提交上基本失去意义，`ece1a4da` 改的 256 处英文文案被整批带回旧值，08-05 落地
  时无人逐行核对这么大的 diff。
- **二次坐实**：落地后全量 `flutter test` 因文案不匹配报出大量断言失败，后续有提交把这些
  断言"修"成匹配（已回退的、错误的）产出文案，而不是去查文案本身为什么变了——`TASKS.md`
  2026-08-06 那条"过期断言清理"记录就是这次坐实，之后测试全绿反而掩盖了问题。
- **规则**：i18n 模板文件（`app_en.arb`）+ 其 codegen 产物**不适合**长期分支持有自己的重写
  提交去 rebase 合并；长期分支应尽量高频同步 main（而不是攒到落地前才一次性 rebase），且
  涉及 codegen 全量生成文件的冲突，**必须**基于源文件（`.arb`）本身逐 key 核对，不能整份
  接受任一侧。当 `flutter test` 因文案不匹配大批失败时，先确认是文案本身出问题还是测试
  该更新，**不要**默认改测试断言让它变绿了事。
- **另发现**：`step_complete_dialog.dart` 用本地化后的字符串 `l10n.firstStudy` 做业务分支
  判断（决定"完成首轮"还是"完成复习"文案），这次因为 `firstStudy` 译文改成 `"First Round"`
  后恰好撞上某个 widget test 拿 `'First Round'` 当泛型占位符 stageName，暴露了"业务逻辑不
  应该拿翻译后的展示文本做判断依据"这个更根本的坏味道（`TASKS.md` 07-06 已记录，尚未改造，
  当前只改了测试的占位符避免碰撞）。
- **恢复方法**：三点对比法——取「回退前 (`ece1a4da^`)」「意图值 (`ece1a4da`)」「当前 HEAD」
  三份 arb 逐 key diff，`HEAD == ece1a4da^ 且 ece1a4da 改过` 即判定为被静默回退，按 `ece1a4da`
  的值恢复；同一方法可扩展到检测任意「长分支落地覆盖主干独立改动」的问题，不限于 l10n。
- **完成时间**：2026-08-06

### 7.30 跟读实时 VAD：固定 RMS 门槛把小声用户判成静音 → 说话中途被自动结束录音

- 根因：Android `AndroidSpeechPracticeHandler` 与 iOS/macOS `AppDelegate.swift` 都用固定门槛 0.015（**增益前** RMS；写入 WAV 时才 ×2.2，离线 ASR 日志里的 rms² 是增益后的值，换算时别搞混）。Android 离线 ASR 录音中无实时转写，自动停止只靠声学静音兜底，判错即截断。
- 规则：门槛按底噪自适应（`AdaptiveVadThreshold`，Kotlin + Swift 三端同源，改参数必须三端同步），**必须有上限（= 旧门槛）和下限**；底噪只统计判为静音的 buffer。排查时对比 `[RecordingDiag]` 的 `vadThreshold/vadNoiseFloor/vadVoicedBuffers` 与 `[ASREngine] VAD: x → y` 是否矛盾。
- 相关：跟读引擎的 `referenceDuration`/`maxDuration` 必须按播放倍速换算（`RepeatFlowConfig.playbackSpeed`），否则慢速播放时动态兜底降到 1s。

### 7.31 复述重听本段：清理录音置 idle 触发自动录音，抢在原文播放前启动 → 原音被录进去

- 根因：`clearRecording` 先同步置 idle 再 await 原生清理；期间跑过一帧时，idle 触发的自动录音在播放器仍为 retelling 时启动，随后才切 listening 放原文（评估中点击最易触发，主线程被评估占用）。
- 规则：所有「取消/清理录音后播放原文」的入口，清理期间都要先挡住自动录音（`_manualStoppedThisParagraph = true`），清理完、同步切到 listening 前再放开。回归测试见 `retell_player_screen_test.dart`「评估中点击主播放重听本段…」。

### 7.32 media_kit 区间播放：软停止越过句尾带出下一句；seek 未落定就起播

- 根因：句尾靠「位置事件/200ms 轮询发现 `position >= end` → 异步 pause」软停止。Android media_kit 用 `ao=opensles`，部分机型（华为 YAL-AL00 实测）输出缓冲深，`time-pos` 与实际出声有数百毫秒偏差：1.0.43 原包第一句（终点 2524ms）停在 2770ms，暂停后缓存位置又漂到 3100ms，正好覆盖下一句开头 "Would you"（2.74s 起）；末句则在 9045ms 提前收到 EOF。逐句精听在 1.0.42 已走 MediaEngine，回归点不是 1.0.43 的盲听驱动切换。
- 规则：区间终点用 mpv 原生 `end` 属性在解码层硬裁切（`MediaPlayerBackend.setPlaybackEnd`），终点后的音频不进输出缓冲；修复后同机停在 2523ms / 9524ms。`end` 是全局选项：**seek 前、区间结束/取消、任何非区间播放（play/seek/playToEnd/pause/stop/detach）都要撤销**，换文件时 backend.open 自行撤销，否则自由播放会停在旧终点或 seek 越过旧终点立即 EOF。
- 起播：seek 回执只代表命令被受理，要等位置流确认到达起点再 play（上限 500ms 兜底，不在命令队列里等）。精确 seek 可能落在目标前不到 1ms（2625 → 2624.9），起点判定要允许少量提前（50ms）。
- 排查日志：`[MediaEngine Range] start-gate`（outcome/waitedMs）、`[MediaKitBackend] set playback end`、`return: position=`。

### 7.33 共享合集 / 播客未下载材料进入学习计划页：入口判断分散 → 进入逐句精听报 `file unavailable`

- 根因：共享合集与播客单集入库时只有占位行（`audioPath=null`，字幕为空）。学习 Tab 的推荐卡 / 任务卡 / 最近完成直接 `push` 计划页，只有资源库列表点击会先下载；「更新字幕」只写字幕不下载音频，计划页因此出现「有字幕、无音频」，精听 `loadMedia` 报 `file unavailable`。推荐逻辑（`selectStudyRecommendation`）也从未过滤下载状态。
- 规则：**计划页是媒体就绪的唯一 owner**。入口只负责打开计划页，不做就绪判断，也不做下载。就绪状态由 `resolveMediaReadiness` 纯函数解析，列表行与计划页进度共用 `mediaDownloadSnapshotProvider`；未就绪时计划页只展示 `MediaPreparingView`，学习内容与 autoStart 在 `MediaReady` 之后才构建。
- 下载器约束：同一下载通道一次只跑一个任务，另一材料请求时解析为 `MediaWaiting`，通道空闲后由计划页自动重试；`MediaFailed` 不自动重试，只由占位页的重试按钮触发，避免失败后循环下载。播客 RSS 字幕不随音频自动下载，仅在用户于字幕管理中主动选择「下载播客字幕」时获取（首次选择时弹出一次性提醒）；未下载单集没有字幕。
- 排查日志：`[MediaEnsure]`（provision 结果 / 跳过原因）、`[CommunityDownload]`（start rejected / start / done / cancel）、`[PodcastTranscript]`（字幕附加）。

### 7.34 系统语言非中英文（如 `fr_CN`）→ 后台下载全部失败：非界面路径直接把系统 locale 喂给 `AppLocalizations`

- 根因：后台下载通知文案解析用 `appSettingsProvider.locale ?? PlatformDispatcher.instance.locale`，把原始系统语言直接传给 `AppLocalizations.delegate.load`。生成的 `lookupAppLocalizations` 只认 `en` / `zh`，其它语言抛 `FlutterError`，异常落在 `BackgroundFileDownloadService._initialize()` 内，插件整体初始化失败，任务从未入队（用户日志 25/25 失败，界面仍显示英文，故不易察觉）。
- 规则：**任何非 Widget 上下文取文案 / 语言标识，一律经 `resolveUiLocale`**（`settings_provider.dart`，与界面 `MaterialApp` 同一规则：显式设置优先，否则 `matchUiLocale`，只会是 `en` / `zh_CN`）。不要直接读 `PlatformDispatcher` 或原始 `Locale` 去查 `AppLocalizations`。通知文案属于非关键路径：解析失败须回退英文（`_guardNotificationLabels`、`ReviewReminderService._currentTexts`），不能让它拖垮下载或调度。
- 语言标识参与提醒快照去重（`locale|<tag>`），切换语言后即使提醒不变也会重新调度。
- 回归测试：`download_provider_test.dart`（fr_CN 回退）、`background_file_download_service_test.dart`（解析抛异常仍可入队）、`review_reminder_service_test.dart`「本地化文案」组、`paddle_billing_repository_test.dart`（checkout locale 注入）、`settings_provider_test.dart`「resolveUiLocale」组。
- 排查日志：`[BackgroundFileDownload] plugin initialization failed`，`cause=AppLocalizations.delegate failed to load unsupported locale "<locale>"`。

### 7.35 Release 工作流失败：Flutter SDK 对 Gradle / AGP / Kotlin 有最低版本门槛，升级 Flutter 后构建直接中止

- 根因：CI 的 Flutter 升到 3.47.9 后，`flutter-gradle-plugin` 校验项目的 Gradle ≥ 8.14、AGP ≥ 8.11.1、Kotlin ≥ 2.2.20，原配置（Gradle 8.12 / AGP 8.9.1 / Kotlin 2.1.0）全部不满足，`app/build.gradle.kts` 应用插件时即失败。三项门槛按顺序逐个暴露，需要一次性对齐。
- 规则：升级 `FLUTTER_VERSION` 时，先在本地 `./gradlew help` 验证 Android 配置阶段，再打 tag；不要只看 Flutter 版本号。
- 排查日志：`Your project's Gradle version (8.12.0) is lower than Flutter's minimum supported version`。

### 7.36 iOS 上传 altool 日志残留瞬时 500 的 ERROR 行 → 误判失败（上传实际已成功）

- 根因：App Store Connect 偶发 500 时 altool 内部重试并最终 `UPLOAD SUCCEEDED with no errors`，但日志里仍保留 `ERROR:` 行。工作流以「日志含 ERROR 即失败」判定，把已成功的上传标红。
- 规则：判定上传成功以 `UPLOAD SUCCEEDED with no errors` 为准，不以 ERROR 关键字为准；该构建号已入库，重跑同一 commit 会因构建号重复失败，需要新 commit 打新 tag。
- 同一次上传 Apple 还邮件提示 `ITMS-90683`：`file_picker` 等依赖引入相机 API，Info.plist 缺 `NSCameraUsageDescription` 即使应用不使用相机也会被拒，须补齐并同步 `en` / `zh-Hans` 的 InfoPlist.strings。

### 7.37 同一资源多入口下载：「查找再登记」必然重复建任务，取消也要绑定到具体任务

- 根因：资源下载按入口分别调用时，若先查「是否有活动任务」再异步提交，并发调用会各自新建任务，写同一临时文件。插件自带的 `transfers.getOrStart` 也是先查后 `await` 入队，同样不能当作互斥守卫；且它会返回已完成的旧 transfer，与「文件被删后可重新下载」冲突。
- 解法：`ResourceDownloadRegistry`（进程内单例，`BackgroundFileDownloadService` 默认共用）以资源 key 同步登记（check 与 insert 之间没有 `await`）。取消中的任务不可加入，新任务通过 `predecessor` 等待旧任务结束后再提交原生任务。
- 规则：
  - 取消回调必须绑定到具体任务（`cancelEntry(download)`），不能按 key 取消。否则旧调用方的 `CancelToken` 迟到触发时会误取消之后的新任务。
  - 登记表是唯一状态来源，Riverpod 只做镜像（`resourceDownloadsProvider`），不得持有第二份状态。
  - 进程级清理（`reset(group)`）只能在本进程没有 owner 的任务上执行，且每个 `FileDownloader` 只执行一次；多个 runner 共用同一个插件单例。
- 测试约定：
  - Riverpod 3 的 `container.listen` 回调是异步派发的。断言前需要 `await Future<void>.delayed(Duration.zero)`，否则会看到旧值。
  - 「取消后立即再提交」的断言，不能先 `await cancelResource(...)`，那会等旧任务结束，测不到取消中的分支。需要让测试替身的取消完成可手动控制。
  - 测试里提前 `await` 取消会触发结果报错，断言要在触发取消前挂上（`expectLater` 先于触发）。
- 相关代码：`lib/services/resource_download_registry.dart`、`lib/services/background_file_download_service.dart`（`downloadBatch` / `_execute` / `_subscribeProgress`）。
- 修复时间：2026-11-03。

### 7.38 Riverpod 3 暂停无监听 StreamProvider：启动会话永久挂起，登录后仍提示未登录

- 现象：1.0.46 冷启动后，已登录用户在播客订阅页点「+」仍弹「请先登录」；去登录、登录成功后再点仍弹窗，反复数次；进入设置等页面或返回上一页再进来后恢复正常。
- 根因：Riverpod 2 → 3（升级提交 `b880e422`，随 1.0.46 发布）起，没有任何监听者的 provider 会被暂停，StreamProvider 连带暂停底层订阅，事件只缓冲不投递。启动链路 `await ref.read(supabaseSessionProvider.future)` 发生在根级常驻监听安装之前，无 widget 监听时永久挂起，监听也装不上。会话长期停在 loading（`value == null`），`isAuthenticatedProvider` 为 `false`；登录成功的 `signedIn` 也被缓冲，直到某个页面 watch 会话才 flush。
- 解法：`startSupabaseSessionTracking`（`auth_providers.dart`）把顺序固化为「先 `container.listen` 常驻监听，再等待 `.future`」，`main.dart` 启动时改用它；订阅由 `_EchoLoopAppState` 持有到退出。测试注入点 `supabaseAuthClientProvider` 替换 Supabase 客户端。
- 规则：
  - 在 Riverpod 3 中，`ref.read(streamProvider.future)` 只有在 provider 已有活跃监听者时才会完成。需要「等首值」时，先挂常驻监听（`container.listen` / `listenManual`，由 widget 或应用级 State 持有），再等待。
  - 依赖 `provider.value` 做认证判断的代码，必须保证会话 provider 有常驻监听者，否则读到的是暂停前的旧值。仅在 provider 内部 `ref.listen` 不够：那个监听同样会随 provider 一起被暂停。
  - 排查「登录了却仍未登录」时，先看日志里 `identity_sync_pending` 是否长时间不结束、`auth_state_changed` 是否晚于登录页 pop。
- 测试约定：`auth_providers_test.dart` 中 `startSupabaseSessionTracking` 用例：先回放 `initialSession` 再启动接管，断言首值可在超时内到达；启动后无其它监听者时，登录 / 登出都能反映到 `isAuthenticatedProvider`。把顺序改回「先 await、后监听」会超时失败。
- 相关代码：`lib/features/auth/providers/auth_providers.dart`（`startSupabaseSessionTracking`、`supabaseAuthClientProvider`）、`lib/main.dart`（`_startThirdPartyDependentTasks`）。
- 修复时间：2026-11-03。

### 7.39 跟读页录音中点播放，麦克风未释放：暂停续播分支漏掉 cancelRecording

- 现象：跟读页先暂停原句（保存了续播位置），再点录音，录音中点播放键。播放正常从原位置续播，但系统状态栏麦克风指示仍亮，录音持续进行。
- 根因：`ListenAndRepeatController.resumeOrReplayCurrentSentence` 在存在续播位置时调用 `RepeatFlowEngine.resumeCurrentSentence`，该方法只做 pauseAudio / 倒计时取消 / 回放停止，没有调用 `callbacks.cancelRecording()`。无续播位置时走 `replayCurrentSentence` → `_atomicReset` → `_stopActiveResources`，录音会被正确释放，所以只有「先暂停再录音再播放」才会复现。
- 解法：`resumeCurrentSentence` 改为调用 `_stopActiveResources()`，与其它打断路径保持同一套释放顺序。
- 规则：引擎内任何「打断当前句」的入口都必须走 `_stopActiveResources()`，不得手写一份资源释放列表，否则新增资源（如录音）时会漏掉。共用此引擎的难句补练跟读同样受益。
- 测试约定：`repeat_flow_engine_test.dart` 中「录音中从暂停位置恢复播放会取消录音」。进入等待态时 `enterWaitingForUser` 本身也会触发一次 `cancelRecording`，断言前需先重置计数，只统计 resume 这一步。
- 相关代码：`lib/providers/repeat_flow/repeat_flow_engine.dart`（`resumeCurrentSentence`、`_stopActiveResources`）。
- 修复时间：2026-11-04。

### 7.40 难句跟读 / 难句补练进入时出现切屏动画：空列表下的首次对齐被当成相邻切句

- 现象：从学习计划进入难句跟读或难句补练，页面先横滑一段再停到断点句，而不是直接显示断点句。
- 根因：`PracticeSentencePager` 在句子列表为空（`itemCount=0`、`currentIndex=0`）时完成了一次同步，`_synced` 被置为 true。随后会话到位（`itemCount` 0→4，`currentIndex` 0→1），`_syncPageIfReady` 把它当成相邻切句，走 320ms `animateToPage`。加载遮罩只淡出 180ms，两者重叠就看到切屏。断点句与第 0 句相差大于 1 的任务（如逐句精听断点在第 4 句）走 `jumpToPage`，瞬间完成，所以看不出来。
- 解法：`didUpdateWidget` 检测到 `itemCount` 从 0 变为非 0 时，重置 `_synced` 并排一次对齐，使首次到位直接跳转。之后的相邻切句动画不变。
- 规则：分页组件的「已同步」状态只能在有效数据下建立；空列表时的页面位置不是业务索引的对齐结果。改动此类同步逻辑时，要同时覆盖「空列表到位后索引不变」与「到位后相邻切句」两种情况。
- 测试约定：`practice_sentence_pager_test.dart` 中三条用例分别覆盖首次到位直接对齐、已对齐后的相邻切句仍有动画、空列表到位（索引不变）后相邻切句仍有动画。
- 相关代码：`lib/widgets/practice/practice_sentence_pager.dart`（`didUpdateWidget`、`_syncPageIfReady`）。
- 修复时间：2026-11-04。

### 7.41 百度网盘批量导入：下载时才取 dlink，切后台后队列无法接力下一个文件

- 现象：批量导入时切到后台，当前文件下完后队列停住，回到前台才开始下一个。
- 根因：每个文件轮到下载时才调用 `filemetas` 取 dlink，并在 Dart 侧用并发 2 排队。App 挂起后没有人取下一个 dlink，也没有人提交下一个任务。
- 解法：入队时整批取一次 dlink（有效期约 8 小时，单次请求按 100 个分块），整批提交原生下载队列，同时下载数由原生 `holdingQueue`（`maxConcurrentDownloads = 2`）限制。取链接失败时整批标记失败，每个文件可单独重试。
- 规则：
  - 需要后台持续推进的请求，必须在前台一次性完成并交给原生队列，不能依赖 Dart 在每个任务开始时临时请求。
  - 批量接口中某个文件缺少 dlink 只跳过该文件，不抛异常拖垮整批。
  - 同批并发的任务不能在开始时快照资源库，库状态在注册时读取，否则先完成的兄弟任务不会被重复检测。
- 测试约定：`baidu_netdisk_import_tasks_provider_test.dart` 用可控的假取链接函数覆盖「取链接期间取消」「取链接失败整批失败并可重试」「整批只取一次链接」。
- 相关代码：`lib/features/baidu_netdisk/providers/baidu_netdisk_import_tasks_provider.dart`（`_submitBatch`）、`lib/features/baidu_netdisk/data/baidu_netdisk_api.dart`（`fetchDownloadLinks`）、`lib/features/baidu_netdisk/data/baidu_netdisk_import_service.dart`（`_linkFor`、`_fetchFreshLink`）。
- 修复时间：2026-11-04。
