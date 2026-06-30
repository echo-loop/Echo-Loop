# Echo Loop 任务清单

> 最后更新：2026-06-30（修复 TTS 音色重播播放态）
> 当前焦点：Android 结束录音闪退（离线 ASR / Silero VAD）——**仍未解决**

## 已完成：修复 TTS 音色连续重播时小喇叭提前消失

语音设置页点击某个音色试听时，第一次点击会显示小喇叭；同一音色再次点击重播时，小喇叭会在新播放仍进行中提前消失。根因是播放态只用 `speakingKey` 判断归属，同一 key 连续发起两次播放时，第一次请求完成后会误清第二次请求的 UI 状态。

- [x] `tts_controller_provider.dart`：新增 `_speakingToken` 发音 UI 代际；`speak` / `previewVoice` / `previewPiperVoice` / `previewAccent` / `stop` 均递增或校验 token，旧请求完成时不能清掉新请求的小喇叭。
- [x] 测试：`tts_controller_preview_test.dart` 补同一 `speakingKey` 连续发音回归，确认旧请求完成时第二次播放态仍保留；同时为该测试文件补 fake TTS cache DAO 与 fake cache path，避免依赖真实数据库。
- [x] 验证：`flutter analyze lib/providers/tts/tts_controller_provider.dart test/providers/tts/tts_controller_preview_test.dart` 0 问题；`flutter test test/providers/tts/tts_controller_preview_test.dart` 16 passed。

  **完成时间**: 2026-06-30

## 已完成：修复 Echo Loop/Balanced TTS 回退系统语音与缓存串音

iOS 上选中 Echo Loop Speech（Balanced/Piper 或 Advanced/Kokoro）后，部分发音仍播出 Apple 系统语音。根因有两层：① 控制器在本地模型未就绪时会把有效引擎降级为平台 TTS；② 协调器的 `speakWith`/`prewarm` 虽传入目标引擎与配置，但实际 `_ensureEngine` 仍按全局 desired 引擎建/复用，可能用平台引擎产物写入 Echo Loop/Piper 的 cache key。

- [x] `tts_controller_provider.dart`：`effectiveTtsEngine` 改为始终尊重用户选择；选中 Echo Loop/Balanced 但模型未下载、下载中或失败时只后台触发下载，不再回退系统语音。配置保留本地引擎 `voiceName/modelTag`，确保后续合成进入正确缓存桶。
- [x] `tts_coordinator.dart`：`_ensureEngine` 改为接收本次目标 `kind/config`；`speakWith`、`prewarm`、`prewarmCurrent` 与普通 `speak` 均用本次真实目标引擎合成，避免 cache key 与实际合成引擎不一致。补齐 in-flight 构建后目标引擎不一致时的重新检查。
- [x] 测试：更新门控测试覆盖 Echo Loop/Piper 未就绪不回退平台；新增协调器回归，覆盖当前为平台引擎时显式 Echo Loop/Piper 试听/预热会切到目标本地引擎并按目标引擎入库。
- [x] 验证：`flutter analyze` 改动文件 0 问题；`flutter test test/providers/tts/tts_controller_gating_test.dart test/services/tts/tts_coordinator_test.dart` 33 passed。
- [x] 注：本次按用户选择不做旧 TTS 缓存自动失效；已污染缓存可能仍需用户手动清缓存或等待过期。

  **完成时间**: 2026-06-30

## 已完成：统一 Free Player / 全文盲听停顿期上一键语义

精听句间停顿已改为「上一句先重播当前句」后，继续收敛同源体验：Free Player 在句间 / 整篇循环间隔、全文盲听在段间停顿期间，左按钮也应把刚结束的当前播放单元从头重播，而不是直接跳到前一个单元。

- [x] `listening_practice_provider.dart`：新增私有 `_isInPlaybackInterval` 标记，仅包住 `_delayInterval`；`previousSentence()` 在停顿期改为 `replayCurrentSentence()`。同时 dispose 时递增播放代际，并让 `_delayInterval` 持有 engine 引用，避免延迟 finally 在 provider 销毁后再 `ref.read`。
- [x] `blind_listen_player_provider.dart`：`goToPreviousParagraph()` 在 `isPauseCountdown` 期间重播当前段段首；非停顿期保留原上一段语义。
- [x] 测试：Free Player 覆盖整篇循环间隔中上一句重播末句；全文盲听覆盖段间停顿期上一段重播当前段。相关 provider 测试共 76 passed。
- [x] 验证：`flutter analyze` 改动文件 0 问题；未跑 `scripts/check.sh`：本次为两个 provider 的局部交互语义修复，按仓库规范仅跑相关检查。

  **完成时间**: 2026-06-30

## 已完成：修复精听句间停顿期锁屏上一句跳转异常

逐句精听在 `BlindWaitingInterval`（句间停顿）期间，锁屏/屏内「上一句」原本无条件走 `currentSentenceIndex - 1`：第一句停顿期被 clamp 成当前句后 no-op，第二句停顿期会跳回第一句开头（用户感觉像往前跳两句/跳到 0 点）。句间停顿应视为刚播完的当前句等待态，左按钮先回到当前句开头重播。

- [x] `intensive_listen_player_provider.dart`：`goToPrevious()` 在 `BlindWaitingInterval` 期间改为 `_blindEngine.replayCurrentSentence()`；其他阶段保留原本上一句跳转语义。锁屏控制已绑定同一方法，无需改 `BackgroundAudioHandler`。
- [x] 测试：`intensive_listen_player_test.dart` 新增两例回归，覆盖第一句停顿期不再 no-op、第二句停顿期不再跳回第一句；同步修正测试 fake engine，使同一句重播使用独立完成点。
- [x] 验证：`flutter analyze` 改动文件 0 问题；`flutter test test/providers/intensive_listen_player_test.dart` 44 passed。未跑 `scripts/check.sh`：本次为单 provider 小范围 bug 修复，按仓库规范仅跑相关检查。

  **完成时间**: 2026-06-30

## 已完成：Free Player 倒计时期间冻结锁屏进度条（§7.16 同源）

Free Player（`ListeningPractice`）句间循环/整篇循环之间的停顿期间，锁屏进度条仍前进（越过句尾/篇尾）、下一遍起播又回退——与精听/盲听 §7.16 修复前同源。Free Player 走同一媒体引擎但从未调过 `setProgressFrozen`。

- [x] `listening_practice_provider.dart`：所有停顿延迟唯一收敛到 `_delayInterval(interval)`（整篇/无字幕整篇/单句重播/跳句/gapless 交接 5 处调用点全经此）。单点包裹——延迟前 `_engine.setProgressFrozen(true)`、`finally` 中 `setProgressFrozen(false)`；`interval==0` 不触碰，`finally` 保证延迟异常/会话作废也不残留冻结态。
- [x] 测试：`free_player_playback_flow_test.dart`「整篇循环间隔」用例补断言——停顿期 `engine.progressFrozen==true`、起播下一遍后 `==false`。
- [x] CLAUDE.md §7.16 补充「Free Player 同源接入」。
- [x] 验证：`flutter analyze` 改动文件 0 问题；`flutter test` 全套 3229 passed / 11 skipped。**待真机验证**（iOS 后台外推本机/CI 测不到）：Free Player 设间隔>0+循环，锁屏停顿期进度条停住、起播恢复、图标仍显「播放中」。

  **完成时间**: 2026-06-29

## 已完成：修复盲听后台播放锁屏控制两处缺陷（控件不显示 + 上/下一句无反应）

2b20c840 给盲听/精听接入锁屏控制后出现两个 bug（iOS+Android 都有）：① 锁屏控件有时不显示（冷启动正常、用一段时间后消失）；② 盲听锁屏「上一句/下一句」按钮可见但点了无反应。单一根因：锁屏会话销毁由 `processingState` 跳 `idle` 驱动（audio_service `非idle→idle` → `stopService` 拆 `MPRemoteCommandCenter`/前台通知）。**精听**每次中断走 `engine.pause()`（非 idle，不拆会话）；**盲听**每次暂停/切段/seek/改设置都走 `engine.stopPlayback()`（idle→stopService），于是每中断一次就拆/重建系统媒体会话——命令 target 被移除致 prev/next 死按钮，反复拆建致卡片时序性消失。

- [x] `blind_listen_player_provider.dart`：4 处会话内中断 `engine.stopPlayback()` → `engine.pauseKeepSession()`（`pause()` / `enterWaitingForUser()` / `updateSettings()` 模式切换 / `_cancelAll()`，后者被 seek/切段/重听共用）。session 已由各调用点 `newSession()` 失效，故用不再 bump 的 `pauseKeepSession`，行为等价、只去掉 idle 广播。真正退出仍由 `exitLearningMode → practice.stop()`（idle）清卡片。
- [x] 测试：盲听 fake 引擎经 `FakeAudioEngine.pauseKeepSession`（已存在、no-op）兜底，无需改测试；`blind_listen_player_test`(50) + `background_audio_handler_test` 全通过。
- [x] CLAUDE.md 新增 §7.14（盲听会话内中断必须 pause 不能 stop，与精听对齐）。
- [x] **统一上一句/下一句导航**：盲听左右按钮（锁屏 + 屏内控制栏 + 键盘热键）从「上一段/下一段」改为「上一句/下一句」，与逐句精听语义统一。`blind_listen_player_provider.dart` 新增 `goToNextSentence`/`goToPreviousSentence`（基于 `_currentSentenceLocation` 跨段步进，复用 `seekToSentence`）+ `canGoToPreviousSentence`/`isAtLastSentence` 判定按钮可用态/完成态；屏幕 3 处调用点改用之；段间自动推进（`_onPauseCountdownFinished`）仍走段级 `goToNextParagraph`，进度条段级拖动 `seekToParagraph` 不变。`FakeBlindListenPlayer` 加对应 override（无真实段落时按段索引近似）；新增 4 例导航单测。
- [x] **修复锁屏进度切句归零**（§7.15）：盲听每段用 `setClip` 播放，just_audio 在 clip 下 `position` 相对 clip 起点、`duration` 为 clip 长度，handler 直接广播致锁屏进度每切句归零。`background_audio_handler.dart` 记 `_clipStart`/`_clipActive`/`_fullDuration`，`_broadcastState` 上报 `_clipStart + position`（绝对位置），duration 监听 clip 期间保留全曲时长；无 clip 时 `_clipStart=0`，Free Player 整曲不变。新增 3 例 handler 测试（clip 绝对位置 / 切段不归零 / clearClip 回退）。
- [x] 验证：`flutter analyze` 0 error（改动文件无问题）；`services/` + `audio_engine/` + `listening_practice/` + `learning_session/` + `screens/` 全通过（1068 passed / 11 skipped）。**待真机验证**（锁屏/后台本机测不到）：iOS/Android 锁屏点上一句/下一句逐句切换且进度不归零、多次中断 + 长时使用后卡片仍在、录音任务卡片仍消失、退出回 Free Player 正常。

  **完成时间**: 2026-06-29

## 已完成：收藏词汇页 TTS 预热（单词 + 意群后台预生成）

把词典弹窗的预热机制扩到「收藏 → 词汇」页：进入即后台预热全部收藏单词 + 意群发音，列表 `SpeakButton` 与「开始复习」闪卡发音命中缓存秒播。单词 = `SavedWord.word`，意群 = `SavedSenseGroup.displayText`，二者都走统一 `ttsController.speak` → 当前配置，cacheKey 与 `prewarmCurrent` 一致。句子 tab 走原音频、无 TTS，不在范围。

- [x] **控制器泛化**（`tts_controller_provider.dart`）：`prewarmDictionaryTexts`→`prewarmTexts`、`cancelDictionaryPrewarm`→`cancelTextsPrewarm`、`_dictPrewarmToken`→`_textsPrewarmToken`（一处复用词典/收藏两页；逻辑不变，注释说明共享 token 语义）。同步词典弹窗调用点与测试改名。
- [x] **收藏页接线**（`favorites_screen.dart` `_WordsViewState`）：build 内 `_schedulePrewarm(words, phrases)` 收集 `word.word` + `phrase.displayText`，签名去重（仅文本集变化才重启批次）+ postFrame 触发 `prewarmTexts`；新增 `dispose` 调 `cancelTextsPrewarm`；build 缓存 notifier 供 dispose（§7.18）。
- [x] **仅词汇 tab 激活才预热**：`_WordsView` 加 `isActive`（= 词汇 tab 选中）。IndexedStack 同时构建两个 tab，不门控则停在句子 tab 也会为词汇起 Kokoro 引擎合成、白占 CPU（句子走原音频、无 TTS）。`_schedulePrewarm` 非激活直接 return；`didUpdateWidget` 在切离词汇 tab 时 `cancelTextsPrewarm` + 重置签名（重新进入可再触发，已缓存命中即跳过）。「开始复习」是 `context.push`、收藏页不 dispose，故进闪卡不取消预热（缓存命中/在途复用秒播）。
- [x] **测试**：`favorites_prewarm_test`（5 例：停句子 tab 不预热 / 切到词汇 tab 预热单词+意群 / 切离词汇 tab 取消 / 重发相同列表不重启 / 离开页取消）+ `tts_controller_dict_prewarm_test` 改名回归（4 例，DAO 改手写 fake 修 mocktail `getByKey` 偶发 sync-null + 临时目录 tearDown 清理）；改动文件 `flutter analyze` 0 问题，TTS+收藏+词典套件 97 例通过。

## 已完成：词典弹窗 TTS 预热（单词 + 例句后台预生成）

把语音合成设置页的「后台预生成 + 点击命中缓存秒播」机制（§7.22/§7.23）扩到词典弹窗。Kokoro 首次合成有可感知延迟（RTF≈3，例句逐条数秒），查词结果到达后按显示顺序后台预合成「单词 + 全部例句」入缓存，用户点击单词/例句发音即命中秒播。

**核心约束**：预热须用与点击发音 `speak()` 完全相同的当前配置，否则 cacheKey 不符、点击命不中（§7.22 回归点）。故预热不自建配置，复用协调器记录的 `_desiredKind`/`_desiredConfig`。

- [x] **协调器原语**（`tts_coordinator.dart`）：新增 `prewarmCurrent(text)`——用当前配置以 background 优先 `_render`、只合成不播；未配置 no-op。沿用既有 cache-first + `_inFlightRender` 去重 + 优先级调度（背景让位用户发音）。
- [x] **控制器批量预热**（`tts_controller_provider.dart`）：新增 `prewarmDictionaryTexts(texts)`（独立 `_dictPrewarmToken`、逐条 await `prewarmCurrent`、失败静默）+ `cancelDictionaryPrewarm()`（弹窗关闭即停在途批次）。token 与试听预热互不干扰。
- [x] **可发音文本提取**（`models/dictionary/dict_speakable_texts.dart`，新）：纯函数 `dictionarySpeakableTexts(result)` 按弹窗显示顺序收齐 headword + 各义项/搭配/词族例句；空串剔除、保序去重；本地/网页源仅 headword。
- [x] **弹窗接线**（`word_dictionary_sheet.dart`）：build 内 `ref.listen` 在选中源变为新 `LookupLoaded` 时触发预热；缓存 notifier 供 dispose 调 `cancelDictionaryPrewarm`（§7.18 不可在 dispose 用 ref）。
- [x] **测试**：`dict_speakable_texts_test`（5 例：AI 按序提取 / 本地 / 网页 / 空串剔除 / 去重）+ coordinator `prewarmCurrent`（3 例：未配置 no-op / 当前配置合成入库不播 / 命中缓存跳过）+ controller `dict_prewarm`（4 例：按序合成 / 空串跳过 / 中途取消停剩余 / token 独立）；`flutter analyze` 改动文件 0 问题，全 TTS+词典套件 125 例通过。

> 注：`integration_test/kokoro_tts_test.dart` 的 `_CountingEngine.synthesize` 已补 §7.22 的 `config` 形参，invalid_override error 已修。

## 已完成：修复语音合成设置页「后台预热」从不生效，点击时才合成

进设置页本应后台为各音色/口音预合成示范句入库（点击秒播），实际从无命中、每次点击都即时合成。日志确诊：worker 在 36s 空窗全程空闲、首次点击全为缓存未命中 → 后台预热一次都没跑。根因：预热触发点（一次性 postFrame + build 内 `ref.listen`）对「模型下载完成后 ready 翻转」捕捉不可靠，prewarm 在 `!ready` 提前返回后再不重跑；而点击因 `previewVoice` 硬编码 echoLoop、绕过 ready 门控仍能合成，故两者并存。cacheKey 检测本身正确（试听/预热同键）。

- [x] **触发可靠化**（`tts_settings_screen.dart`）：就绪翻转 / 变体切换的监听从 build 内 `ref.listen` 迁到 `initState` 的 `ref.listenManual`（注册即生效、不受 build 时序影响），订阅在 dispose 关闭；保留进页一次性 postFrame kick。
- [x] **预热幂等 + 可观测**（`tts_controller_provider.dart`）：加批次签名 `_prewarmSignature`（`engine|variant`），同签名在跑则不重启（防多触发点竞相 bump token 互掐）；全程 `AppLogger` 打点（开始/逐项/跳过分支/完成/取消）便于真机一眼判定。
- [x] **cacheKey 结构性对齐**：抽出单一来源 `ttsVoicePreviewConfig(voice, variant)`，`previewVoice` 与 `prewarmVoicePreviews` 共用，杜绝两路 config 漂移导致预热产物点击命不中。
- [x] **测试**：controller 新增「同签名并发重入只跑一批（幂等）」+「ttsVoicePreviewConfig 逐字段确定 / 变体分桶 modelTag」共 3 例；全 TTS 套件（providers + services + screens）通过；改动文件 `flutter analyze` 0 问题。
- [x] **补漏：引擎切换不对称**（`tts_settings_screen.dart` `_onEngineChanged`）：切到 Echo Loop 此前只 `ensureDownloaded`、不触发音色预热——模型已下载时 ready 不翻转、变体不变、postFrame 已跑过，导致「Apple→Echo Loop 切换后不预热」（日志里看似有预热实为后续切变体触发）。改为切到 echoLoop 也调 `prewarmVoicePreviews()`（与平台分支 `prewarmAccentPreviews` 对称；未就绪则 ready 门控提前返回，由 listenManual 补触发）。
- [ ] **真机验证待办**：进 Echo Loop 设置页不点击，确认日志逐项 `预热[i/N]→合成`（无播放）跑完全部音色；随后点击应 `缓存命中→播放` 秒播。

  **完成时间**: 2026-06-30

## 已完成：macOS 平台 TTS 自实现 synthesizeToFile（原生通道）→ 三端合成行为一致

flutter_tts 4.2.5 的 macOS `synthesizeToFile` 漏设 voice（§7.19），导致 macOS 平台 TTS 此前「放弃合成 → 降级 speakLive、永不入缓存」。新增自家原生合成通道，使 macOS 也能像 iOS/Android 一样合成 caf 入缓存且口音正确。详见 CLAUDE.md §7.24。

- [x] **原生 handler** `macos/Runner/MacosTtsSynthHandler.swift`：通道 `top.echo-loop/tts_synth`，`AVSpeechSynthesizer.write` 合成前正确设 `utterance.voice`，PCM buffer 写 caf 到绝对路径；末尾空 buffer 判完成、先关文件再主线程回报。
- [x] **注册 + 登记**：`MainFlutterWindow.swift` 实例化持有；`Runner.xcodeproj/project.pbxproj` 补 4 处（镜像 NotificationPermissionHandler 条目，新唯一 ID）。
- [x] **Dart 引擎** `platform_tts_engine.dart`：macOS（`_useNativeMacosSynth`）走原生通道，iOS/Android 仍用 flutter_tts；注入式 `NativeMacosSynthResolver`/`NativeMacosSynthesize` 可纯单测；删除 §7.19 遗留的 `accentAwareSynth`/`useDocumentsWorkaround`/Documents 中转。
- [x] **验证**：`flutter build macos --debug` 通过（Swift 编译 + pbxproj 有效）；engine 测试（原生成功/失败/空产出）+ coordinator + 全 TTS 套件通过；`flutter analyze` 0 问题。

  **完成时间**: 2026-06-30

## 已完成：平台 TTS 口音可试听 + 进入页面后台预热

把 Kokoro 音色的「试听 + 预热」机制对齐到平台 TTS 口音：选中平台 TTS 时进页即后台预热美/英两个口音示范句，点击「美音/英音」行即用该口音朗读（同时提交选中，已选项再点也重播），多数情况秒播。

- [x] **控制器**（`tts_controller_provider.dart`）：加 `ttsAccentPreviewKey` + `previewAccent`（speakWith 指定口音）+ `prewarmAccentPreviews`（平台引擎门控、与音色预热共用 `_prewarmToken` 取消）。
- [x] **平台引擎修正**（`platform_tts_engine.dart`）：`synthesize` 显式应用传入 `config`（setLanguage 按本次口音），使产物与缓存键一致——根除「试听非当前口音产错口音却以目标口音入缓存」。
- [x] **设置页**（`tts_settings_screen.dart`）：口音 RadioGroup 改为两行 `_AccentPreviewRow`（点击=选中+试听，试听中显 volume_up）；进页 / 切回平台 TTS 触发 `prewarmAccentPreviews`。
- [x] **修复点击口音无声（挂起）**（CLAUDE.md §7.23）：`_renderAndPlay` 旧版「先 engine.stop 再 render」会让 `_tts.stop()` 打断在途 `synthesizeToFile`（复用方挂起）。改为「player.stop（即时切旧音频）→ 先 render（复用在途合成、不打断）→ 仅 `_inFlightRender.isEmpty` 时才 engine.stop」。加协调器回归测试 1 例。
- [x] **测试**：controller（previewAccent 置/复位 speakingKey、prewarmAccentPreviews 平台触发/Echo Loop 提前返回）+ platform_engine（传 config 按口音 setLanguage）+ coordinator（复用在途合成不打断、完成后照常播放）+ screen（点口音行 setAccent、口音行播放图标）共 7 例；`flutter analyze` 改动文件 0 问题，`flutter test` 全过。

  **完成时间**: 2026-06-30

## 已完成：语音合成音色试听 + 进入页面后台预热（试点）

针对 Kokoro 首次合成有可感知延迟，落地业界标准「预生成 + 缓存命中即播」：音色弹层每行点击即用该音色朗读固定示范句（再点重播，且同时提交选中），弹层不关闭便于连续试听；进设置页（Echo Loop 且模型就绪）即后台异步为全部 11 个音色预合成入库，点击秒播。

- [x] **统一渲染主干**（`tts_coordinator.dart`）：抽出 `_render`（请求→缓存文件，cache-first 幂等，不碰播放器/代际）与 `_renderAndPlay`（抢占+渲染+播放+speakLive 降级）两条主干；`speak` 重构为委托 `_renderAndPlay`，新增 `speakWith`（指定音色试听）/ `prewarm`（预热不播）复用主干，无平行重复逻辑。
- [x] **音色经配置显式传入**：`TtsEngine.synthesize` 加 `TtsSpeechConfig? config`，Kokoro 用 `config ?? _config` 在入口同步解析 sid，根除「applyConfig 与 synthesize 间隙被并发改写」竞态；平台引擎音色仍由 applyConfig 设定，脆弱路径零回归。
- [x] **控制器入口**（`tts_controller_provider.dart`）：`kTtsPreviewText` 示范句 + `ttsVoicePreviewKey` + `previewVoice`（设 speakingKey + speakWith）+ `prewarmVoicePreviews`（echoLoop+ready 门控、token 取消、遍历 11 音色）+ `cancelVoicePreviewPrewarm`。
- [x] **弹层 UI**（`tts_settings_screen.dart`）：音色行抽为 `_VoicePreviewRow`（ConsumerWidget，自管理选中态/播放态），点击=选中+试听+**不关闭**，试听中显 volume_up 图标；进页 postFrame + ready/variant 变化触发预热，dispose 取消（缓存 notifier 避开 dispose 用 ref）。
- [x] **在途去重**：协调器按 cacheKey 记 `_inFlightRender`，同 key 并发渲染（预热某音色时恰好点该音色）复用同一 Future，不重复入 worker 队列/不重复合成；完成自动移除。
- [x] **测试**：coordinator（speakWith 配置路由 / 抢占不播 / prewarm 入库不播 / 命中去重 / 同 key 在途仅合成一次）+ controller（previewVoice speakingKey 流转 / prewarm 门控 / 取消）+ widget（播放图标据 speakingKey 显隐）；既有 synthesize 桩补 `config` 具名参。
- [x] **验证**：`flutter analyze` 改动文件 0 问题；`flutter test` 全通过（**3344 passed / 11 skipped / 0 failed**）。macOS 集成测试因 posthog_flutter Pods 隐私清单构建报错（x86_64，与本次改动无关）未跑。

  **完成时间**: 2026-06-30

## 已完成：Kokoro 双模型变体（fp32 高质量 / int8 轻量）可切换

实测 int8 在 Apple/ARM 上经 onnxruntime CPU 推理比 fp32 慢约 3×（RTF 2.6→0.7），故新增 fp32（未量化，默认+推荐，~300MB）与 int8（低内存设备，~100MB）两个变体，可切换、各自独立下载/删除。两个归档均托管自家 CDN（gzip，避开 §7.21 的 bz2 慢解码）。

- [x] **变体模型**：`KokoroModelVariant` 枚举 + `KokoroModelSpec` 注册表（各自 id/归档/SHA/模型文件名）；manager 按 `Provider.family` 绑定单变体，方法签名不变。
- [x] **多变体状态机** `kokoro_model_provider.dart`：`KokoroModelsState`（按变体状态 Map）+ 每变体独立下载/取消/重试/删除 + 每变体 SP 标记；`kokoroReadyProvider`=当前选中变体是否就绪。
- [x] **设置 + 引擎**：`TtsSettings.kokoroVariant` 持久化；切变体时 `invalidateEngine` 用新模型重建引擎；`modelTag` 入缓存键使 fp32/int8 产物不串音。
- [x] **设置页**：Echo Loop 卡内两变体单选切换（高质量带「推荐」徽标 / 轻量），各自进度/重试/删除，使用中的不可删；音色收成 disclosure 弹层；切回平台后收成存储清理入口。
- [x] **诊断 + 线程**：协调器/worker 打各步耗时（ensureEngine/lookup/generate/writeWave）；`numThreads` 按平台（桌面 6 / 移动 4，按核心收敛）。
- [x] **验证**：`flutter analyze` 0 error；TTS 测试全过（含两变体独立下载/删除、切换、modelTag 分桶）。
- [ ] **待办**：iOS 真机验 fp32 速度后再正式发版（fp32 ~300MB，确认移动端可接受）。

  **完成时间**: 2026-06-29

## 已完成：Echo Loop TTS（Kokoro 本地语音合成，sherpa-onnx 纯 CPU）

把 ADR-8 预留的 `KokoroTtsEngine` 占位落地为可用引擎：复用已集成的 `sherpa_onnx` FFI 跑 Kokoro-82M int8 本地神经网络合成，模型像 Whisper 一样从 CDN 按需下载（含失败/重试/取消/删除/恢复），支持 11 个发音人音色选择 + 美/英音，全平台（含 macOS，顺带解决 §7.19 平台 TTS 口音失效）。详见 PLAN.md ADR-9。

- [x] **音色目录** `kokoro_voices.dart`：11 发音人 + sid 映射（美音 af/am 0–6、英音 bf/bm 7–10），口音/性别由 id 前缀推导，`voicesForAccent`/`defaultVoice`/`sidForVoiceId` helper。
- [x] **模型管理器** `kokoro_model_manager.dart`：单 `tar.gz` 下载（dio + 进度 + CancelToken）→ 校验整包 SHA-256 → `extractFileToDisk` 流式解包 → 递归校验关键文件（model.int8.onnx/voices.bin/tokens.txt/espeak-ng-data）；复用 `AsrModelDownloadStatus/Progress`。
- [x] **引擎 + 合成器** `kokoro_tts_engine.dart` + `kokoro_synthesizer.dart`：替换 stub；原生推理走常驻 worker isolate（`OfflineTts.generate`+`writeWave`，`provider='cpu'`），注入式 `KokoroNativeSynthesizer` 使引擎逻辑可纯单测；`synthesize` 产 wav、`speakLive` 返回 false（不抛）。
- [x] **设置扩展** `TtsSettings`：加 `kokoroVoiceUs`/`kokoroVoiceUk` + `activeKokoroVoice` + `setKokoroVoice`；`toSpeechConfig` 在 echoLoop 带 voiceName；`setEngine` 去回退；SP 持久化 + 非法回退。
- [x] **下载状态机** `kokoro_model_provider.dart`：`KokoroModelState/Notifier`（ensureDownloaded/retry/cancel/delete）+ `initialKokoroModelStateProvider`（main 注入）+ `loadInitialKokoroModelState` + `kokoroReadyProvider`。
- [x] **工厂 + 生效门控** `tts_controller_provider.dart`：`kokoroModelManagerProvider` + 工厂构造真实引擎；控制器监听 settings + kokoroReady，`effectiveTtsEngine` 在模型未就绪时降级平台 TTS（发音不中断），就绪自动切回。
- [x] **设置页** `tts_settings_screen.dart`：Echo Loop 可选 + 选中触发下载、模型状态卡片（下载中进度+取消 / 失败错误+重试 / 就绪+删除）、按口音过滤的音色单选；l10n（en/zh）。
- [x] **未就绪后台自愈**：控制器 `_reconfigure` 在选中 Echo Loop 且模型未就绪时 fire-and-forget 触发下载（含 App 启动恢复/失败后），期间平台 TTS 兜底，就绪自动切回；使用处永不弹窗/阻塞。
- [x] **模型删除（回收空间）**：选中 Echo Loop（启用中）只显状态、不提供删除（不删正在用的语音）；切回平台 TTS 后若模型仍在本地，模型卡片显常驻「删除模型」入口（二次确认后删，引擎已是平台、后台自愈不触发重下）。
- [x] **main.dart**：启动期 `loadInitialKokoroModelState` 注入初始状态。
- [x] **测试**：voices / model_manager（自造 tar.gz + MockHttpClientAdapter）/ engine（fake synth）/ settings_provider / model_provider（fake manager）/ controller gating / settings_screen（test notifier）共 50+ 例；macOS 集成测试 `integration_test/kokoro_tts_test.dart`（真下模型 + 真合成，验证美/英音音频不同）。
- [x] **验证**：`flutter analyze` 0 error；`flutter test` 全通过（**3315 passed / 11 skipped / 0 failed**）；`flutter test integration_test/kokoro_tts_test.dart -d macos` 通过。

  **完成时间**: 2026-06-29

## 已完成：统一 TTS 架构（可插拔引擎 + 合成→文件→缓存→播放）+ 语音合成设置页（详见 PLAN.md ADR-8）

把硬编码单例 `TtsService`（flutter_tts，固定 en-US/语速 0.45、无设置、无缓存）重构为分层、可插拔的统一 TTS 架构：所有发音走 `文本+参数 → cacheKey → 查缓存 → 命中直接播 / 未命中合成产文件并入库 → 播放文件`。底层引擎可替换（本期平台 TTS，预留 Kokoro），口音美/英全局生效，新增「语音合成」设置子页与词典例句发声。

- [x] **数据库层**：Drift `tts_cache` 表 + `TtsCacheDao`（getByKey touch / upsert / expiredEntries / unpinnedByLruAsc / totalSize / deleteAllUnpinned），schema v42→v43 迁移 + 索引；`ttsCacheDaoProvider`。
- [x] **引擎抽象**：`TtsEngine` 接口 + `TtsSpeechConfig`/`TtsSynthesisResult` + 枚举 `TtsEngineKind`/`TtsAccent`；`PlatformTtsEngine`（synthesizeToFile wav/caf + §7.2 防竞态 speakLive 兜底）；`KokoroTtsEngine` 占位（未来本地 82M，不实例化）。
- [x] **缓存仓库** `TtsCacheStore`：cacheKey=sha256、文件落 `getApplicationCacheDirectory()/tts_cache/`、过期/LRU 清理（默认 10 天 / ~200MB，DB 驱动）、DAO 惰性解析（渲染发音按钮不连库）。
- [x] **播放器** `TtsPlayer`：独立 just_audio、不接 audio_service、session 守卫 + 确定性 await 完成。
- [x] **协调器** `TtsCoordinator`（纯 Dart）：管线编排 + generation 防竞态 + 引擎惰性创建。
- [x] **设置 + 门面**：`ttsSettingsProvider`（引擎/口音，手动 Notifier + initial override，main.dart 注入）；`ttsControllerProvider` 唯一发音入口（监听设置热重配，speakingKey 驱动按钮激活态）；启动后延迟清理缓存（main.dart，不拖首屏）。
- [x] **设置页**：`tts_settings_screen.dart`（引擎 RadioGroup，Echo Loop 置灰+「即将推出」；口音美/英 RadioGroup）+ 设置页入口（trailing 显当前口音）+ l10n（en/zh）。
- [x] **消费点迁移**：闪卡(333/668/922)、收藏单词(1400)、词典单词(460) 迁到统一入口；`SpeakButton` 统一发音按钮（打断重播 + 激活态 + 错误静默）；词典 AI 例句（词义/搭配/词族）`_ExampleView` 改 Consumer，点击文本或喇叭发声；删旧 `tts_service.dart`。
- [x] **测试**：DAO / cache_store / platform_engine / coordinator / settings_provider / settings_screen / speak_button 共 60 例；受影响宿主测试（ai_dict_result_view 加 ProviderScope）修复。
- [x] **验证**：`flutter analyze` 0 error（新增文件 0 问题）；`flutter test` 全通过（**3266 passed / 11 skipped / 0 failed**）。
- [x] **修复：macOS 英/美音无区别**（见 CLAUDE.md §7.19）。macOS flutter_tts `synthesizeToFile` 不设 utterance.voice，产物永远默认音色。`PlatformTtsEngine.synthesize` 在 macOS 直接返回 null → 降级 `speakLive`（口音生效）；iOS/Android 不变。新增 `AccentAwareSynthResolver`（默认 `!Platform.isMacOS`）+ 测试 1 例。
  **完成时间**: 2026-06-29

  **完成时间**: 2026-06-28

## 已完成：词典弹窗整个 header 区域可拖拽调整高度 + 下滑关闭

AI/网页源查词弹窗支持上拉/下拉调整高度，但此前只有顶部 36×4 的指示条能触发拖拽（`_buildDragHandle` 的 `GestureDetector` 只包住指示条，命中区仅约 16px 高），header 里数据源选择行、标题行、行间留白都拖不动，体验上"只能点上方中间很小一块"；且把 header 全包成 resize 后，原本在 header 空白处的「下滑关闭」被吞掉、缩到下限就卡住。

- [x] `word_dictionary_sheet.dart`：竖向拖拽手势从"只包指示条"上提到新增的 `_buildHeader`——指示条 + 数据源行 + 标题行整块用 `GestureDetector(opaque, onVerticalDragStart/Update/End)` 包裹（仅 `isResizable` 时）；`_buildDragHandle` 简化为纯视觉指示条；`Key('dict_drag_handle')` 迁到外层 header。内容区仍在 header 之外，WebView/滚动不受影响。
- [x] 手势共存：外层只注册 `VerticalDragGestureRecognizer`，与 header 内按钮/长按经手势竞技场天然区分（纯点击→按钮赢，有竖向位移→拖拽赢）。
- [x] 下滑关闭（标准底部弹窗手感）：拖拽期间用「逻辑高度」`_dragLogicalHeight`（可低于下限，记录手指真实位置；渲染高度仍夹在下限上避免溢出）；松手时逻辑高度低于下限超过 `_kDismissOverdrag`(80px) 即 `Navigator.maybePop` 关闭。从手指真实位置计算，单步/多步拖拽结果一致，不会因一次大 move 误判。
- [x] 测试：`word_dictionary_sheet_resize_test.dart` 抽 `buildOverrides`/`app`/`pumpModal` 公共 helper，新增「标题行非指示条区域上拉放大」「下拉到底再继续下拉关闭弹窗」「下拉到下限但未超阈值仅缩小不关闭」，共 6 例全通过；`flutter analyze` 改动文件 0 问题。

  **完成时间**: 2026-06-28

## 已完成：修复段落复述/全文盲听打开段落时句子高亮乱跳、断点被覆盖成首句

打开一段时偶发：选中句乱跳后回到第一句起播（应从断点恢复处起播）。根因：`_playCurrentParagraph` 在 `playRangeOnce` 的 `seek(0)` 落定**之前**就订阅了 `absolutePositionStream`，setClip/seek 过渡期发出的陈旧 position（重载后为 0、或沿用 stop 后残留）被 `_findSentenceIndex` 误映射成错误句号 → 改高亮 + 经 `_persistCurrentSentenceIndexAsync` 把断点覆盖成首句（0 落在本段首句之前→index 0）+ 可能误触发静音跳过 seek。竞态代码自 578f8829 未变，0bfdbf76（§7.12 引擎拆分）切到 keepAlive 前台引擎后从潜在转为高频复现。

- [x] 两个引擎 `playRangeOnce` 增加 `onClipReady` 回调（`foreground_audio_engine_provider.dart` / `audio_engine_provider.dart`），在 `seek(0)` 落定、`play()` 之前回调；调用方此刻才订阅位置流，从源头消除陈旧窗口。
- [x] `retell_player_provider.dart` / `blind_listen_player_provider.dart`：订阅时机移入 `onClipReady`；监听器开头加越界丢弃（position 落在 `[首句.start, 末句.end]` 外直接 return，不改高亮/不写断点/不触发静音跳过）作兜底。
- [x] 测试：两个 provider 各加 1 例位置流驱动回归（越界陈旧 position 不改高亮/不污染断点、段内 position 正常更新）；所有 `playRangeOnce` override 的测试同步加 `onClipReady` 形参。
- [x] 验证：`flutter analyze` 0 error；相关测试套件全通过。

  **完成时间**: 2026-06-27

## 已完成：媒体引擎 / 前台引擎分离（详见 PLAN.md ADR-7）

把底层播放拆成两套不共享 player 的引擎，把"是否上锁屏"从运行时 `setMediaSessionSuppressed` 开关改成"用哪个引擎"的物理属性，从源头根除 §7.7–7.11 的 suppress 类锁屏竞态。**前台引擎独立写一份**（逐方法照抄 AudioEngine 播放子集，仅把 `_handler.xxx` 换裸 `_player.xxx`）；**无需 `PlaybackEngine` 接口**（无跨边界共用的编排代码）。媒体引擎 = 精听/盲听/Free Player；前台引擎 = 跟读/复述/补练/收藏句复习/收藏词复习。行为与 commit 578f8829 一致由现有行为测试平移守护。

- [x] **步骤 0**：订正 TASKS.md + PLAN.md ADR-7（ForegroundAudioEngine、无接口、5 个前台任务）。
- [x] **步骤 1（前台引擎）**：新增 `lib/providers/audio_engine/foreground_audio_engine_provider.dart`——`@Riverpod(keepAlive: true) class ForegroundAudioEngine`，自持裸 `ja.AudioPlayer()`，**不接 `audio_service`**，逐方法照抄 `AudioEngine` 播放子集。单测 `test/providers/audio_engine/foreground_audio_engine_provider_test.dart`（6 例：session 守卫/loop/clearClip 状态/playClipOnce 过期跳过）。
- [x] **步骤 2（改类型）**：`sentence_playback_engine.dart` 的 `getEngine` → `ForegroundAudioEngine Function()`；`study_task_controller_mixin.dart` 内部引擎引用改 `foregroundAudioEngineProvider`。
- [x] **步骤 3（迁移 5 个前台任务）**：`listen_and_repeat_controller` / `retell_player_provider` / `review_difficult_practice_provider` / `bookmark_review_provider` / `flashcard_provider` 引擎调用点改前台引擎；删 `setMediaSessionSuppressed`；去 `StudyBackgroundPlaybackMixin` + bind/setSessionActive/unbind（补练/收藏句复习/收藏词复习）。
- [x] **步骤 4（进任务清媒体卡片）**：`enterRetellMode`/`enterReviewDifficultPracticeMode`/`listen_and_repeat.initialize`/`bookmark_review.initialize`/`flashcard.initialize` 各调一次媒体引擎 `stop()`；`learning_session_provider._ensureAudioLoaded` 加 `foreground:` 参数，前台模式加载到前台引擎。
- [x] **步骤 5（删 suppress 死代码）**：删 `AudioEngine.setMediaSessionSuppressed` + handler `_mediaSessionSuppressed` 字段及 `_broadcastState`/`loadFile`/duration 监听里的抑制分支（含 LOCKDBG debugPrint）。保留 keepAlive/logicalPlaying/`_mapProcessingState`(§7.7)/锁屏回调。CLAUDE.md：§7.9/§7.11 标「已被引擎拆分架构性取代」+ 新增 §7.12。
- [x] **步骤 6（测试平移）**：`fake_notifiers.dart` 删 FakeAudioEngine 的 suppress 覆写 + 新增 `FakeForegroundAudioEngine`；`mock_providers`/`test_app` 增 `TestForegroundAudioEngine` 并在共享 harness 同时 override 前台引擎；retell/L&R/bookmark/review_difficult/sentence_playback/retell_settings_sheet 测试 override 改 `foregroundAudioEngineProvider`（断言不变）；`background_audio_handler_test` 删 §7.9/§7.11 suppress 用例组。
- [x] **步骤 7（验证）**：`flutter analyze` 0 error（仅历史无关 warning）；`flutter test` 全通过（**3124 passed / 11 skipped / 0 failed**）。`flutter test integration_test -d macos`：macOS app **构建成功**，但本机 debug 连接无法建立（"log reader stopped"，3 个 integration 文件含无关的 asr 测试全部如此 → 环境性 launch 限制，非本次改动）。

  **完成时间**: 2026-06-27

> **真机 iOS 验收（硬门槛，本机/CI 测不到，待用户回归）**：① 5 个前台任务（跟读/复述/补练/收藏句复习/收藏词复习）锁屏/通知栏**无** now-playing 卡片；② 学习计划内 盲听→精听→跟读→复述 背靠背切换，媒体卡片随媒体任务正确出现、进前台任务后消失；③ 与 578f8829 功能逐项对照（跟读播原句→录音→回放→推进、复述播段→倒计时→推进、暂停续播、速度、断点恢复）；④ 录音播放（playAndRecord）与媒体引擎播放交替时 `AVAudioSession` category 不打架；⑤ 退回精听/盲听/Free Player 锁屏卡片正常恢复。

## 已完成：再修难句跟读/段落复述锁屏残留（suppress(false) idle 重发，§7.11）

上一轮（下方条目）gate 住了进任务的 `mediaItem.add`，但 `setMediaSessionSuppressed(false)` 仍**无条件**重发 MediaItem。录音任务退出时主 player 已停成 **idle**，此时重发经 native `setMediaItem` 贴出一张卡片，但此后 player 长期 idle、再无 `非idle→idle` 跳变 → 卡片无法被 `stopService` 清除；下一个录音任务（计划里「跟读→复述」背靠背）`suppress(true)` 广播 idle 时 `previousState` 已是 idle，不触发 stopService → 卡片继续显示。

- [x] `lib/services/background_audio_handler.dart`：`setMediaSessionSuppressed(false)` 重发 MediaItem 仅在主 player **非 idle** 时进行（idle 跳过；native 保留 mediaItem，下次真正播放的 `playing:true` 广播自动回填）。
- [x] 规则：每次 `mediaItem.add`（建卡片）必须配对一个将来必然到来的 `非idle→idle` 跳变才可清除。CLAUDE.md 新增 §7.11。
- [x] 测试：`background_audio_handler_test.dart` 改 1 + 增 2（idle 不重发 / 非 idle 重发 / 录音→录音背靠背无残留），共 29 例通过。
- [x] 验证：`flutter analyze` 改动文件 0 问题；`flutter test` 全通过（3128）。真机 iOS 端到端验收（计划走「跟读→复述」两任务锁屏均无卡片、退出回精听/盲听/Free Player 卡片正常恢复）待用户回归。

  **完成时间**: 2026-06-27

## 已完成：修复难句跟读/段落复述锁屏 now-playing 卡片仍泄漏（suppress 不彻底）

强交互录音任务（难句跟读 L&R、段落复述 Retell）进任务时调 `setMediaSessionSuppressed(true)`，但锁屏 now-playing 卡片仍显示。根因：iOS 锁屏卡片由**两条独立通道**驱动——playbackState（`_broadcastState`）与 MediaItem（`mediaItem.add`→native `setMediaItem`→`MPNowPlayingInfoCenter`）。原 suppress 只挡了 playbackState；`mediaItem.add` 未受约束，进任务加载音频时 native `setMediaItem` 把卡片填回（iOS 清卡片唯一入口是 `stopService`，且 audio_service 仅在 `非idle→idle` 跳变那一次调它，`setMediaItem` 从不清卡片）。

- [x] `lib/services/background_audio_handler.dart`：抑制态下 gate 两处 `mediaItem.add`（`loadFile` + 构造函数 duration 监听）；`setMediaSessionSuppressed(false)` 退任务时重发当前 MediaItem，使被 `stopService` 置 nil 的 native `nowPlayingInfo` 为后续任务恢复。
- [x] 一处修复同时覆盖难句跟读 + 段落复述 + 未来任何 suppressed 任务；无新文件、无架构改动。
- [x] 测试：`background_audio_handler_test.dart` 补 3 例（suppress 后 loadFile 不推 mediaItem / suppress(false) 正常设 / suppress(false) 重发 mediaItem）。
- [x] 验证：`flutter analyze` 改动文件 0 问题；`flutter test` 全通过。真机 iOS 端到端验收（进难句跟读/段落复述锁屏无卡片、退出回精听/盲听卡片恢复、Free Player 不受影响）待用户回归。

  **完成时间**: 2026-06-27

## 已完成：学习/复习任务通用化后台播放 + 锁屏控制

把 Free Player 的「三层后台播放 + 锁屏控制」机制通用化给盲听（分段/不分段）、逐句精听、难句补练、收藏句复习、收藏词复习（闪卡，仅音频部分）。修复盲听原有缺陷：① 音频/段落播完后锁屏播放按钮无反应；② resume/播完后图标卡在暂停；③ 分段后台只播第一段。跟读/复述等录音强交互阶段明确不接入后台。后台停顿采用**静音保活**（仅 iOS，停顿期间循环静音轨保持音频会话活跃，Dart 倒计时照常推进；Android 靠既有前台服务）。

- [x] 底座 `lib/services/background_audio_handler.dart`：`setLogicalPlaying(bool?)`（逻辑播放态覆盖，默认 null=读裸 player，停顿期间锁屏仍显示播放中）+ `startKeepAlive/stopKeepAlive`（私有静音播放器循环 `assets/audio/silence_2s.m4a`，仅 iOS）。`_broadcastState` 改读 `_logicalPlaying ?? _player.playing`。
- [x] 透传 `lib/providers/audio_engine/audio_engine_provider.dart`：`setLogicalPlaying/startKeepAlive/stopKeepAlive`。
- [x] 共享接入层 `lib/providers/learning_session/study_background_playback_mixin.dart`：`bindLockScreen/setSessionActive/unbindLockScreen`，各任务 controller `with` 接入。
- [x] 盲听 `blind_listen_player_provider.dart`：接入 + **删除** `_handleAppLifecycleChange` 进后台暂停倒计时（分段停滞根因）；停顿期间 `setSessionActive(true)` 保活。
- [x] 精听/难句补练/收藏句复习：`_onBlindFlowStateChanged` 按 `BlindPlayingPrompt||BlindWaitingInterval` 维护逻辑播放态 + 保活；跟读（录音）阶段 `unbindLockScreen` 排除后台（D1）。
- [x] 闪卡 `flashcard_provider.dart`：仅音频段（短语/例句）接入锁屏 + 切卡；单词 TTS 不纳入媒体会话；`onAppBackgrounded` 不再中断流程。
- [x] Free Player 非回归（硬约束）：`ListeningPractice` 不迁移；新增 `reattachLockScreen()` 自愈，`PlayerScreen.initState` 每次进入夺回锁屏并清除任务残留的逻辑播放态/保活——`setLogicalPlaying` 默认 null + 保活 opt-in 保证默认零行为变更。
- [x] 测试：handler 逻辑播放态覆盖/保活（F1）、盲听锁屏接入生命周期（bind/pause/dispose）、Free Player `reattachLockScreen` 自愈（G6）；`FakeAudioEngine` 增记录式 no-op 覆写。
- [x] 验证：`flutter analyze` 改动文件 0 问题；`flutter test` 全通过（3117）。真机 iOS 端到端验收（E1/E2/E3、跨音频标题、录音阶段不进后台、中断同步）待用户回归。

  **完成时间**: 2026-06-26

> 最后更新：2026-06-27（网页词典源扩展：抽象通用网页源 + 新增 7 个词典）
> 当前焦点：Android 结束录音闪退（离线 ASR / Silero VAD）——**仍未解决**

## 已完成：新增 7 个网页词典源（Oxford/Longman/Merriam-Webster/Collins/Vocabulary.com/有道/欧陆）

参照 Cambridge 网页源，再加 7 个同类网页词典。因这些源与 Cambridge 本质相同（仅 URL 模板与品牌展示不同），把 Cambridge 这一已验证模式**抽象为配置驱动的通用网页源**，Cambridge 降级为配置之一——新增源只需往 `kWebDictConfigs` 加一行。Macmillan 未纳入（官网 2023-06-30 已永久关停）。7 个新源默认全部启用，中文品牌用中文名（有道/欧陆）。

- [x] 抽象通用件：`WebDictResult`（替代 `CambridgeWebResult`，带 `sourceId`）、`WebDictionarySource`+`WebDictConfig`+`kWebDictConfigs`（`lib/services/dictionary/web_dictionary_source.dart`）、`WebDictionaryView`（`lib/widgets/dictionary/web_dictionary_view.dart`，由 cambridge_web_view 泛化）。
- [x] 接线：`dictionary_result_view`（web 源统一走 `WebDictionaryView`）、`dict_source_presentation`（颜色/名称取自配置）、`dictionary_registry`（`webDictionarySources` 展开拼入）。删除 cambridge 三个旧专用件。
- [x] 切源不闪旧页（**标准做法**）：`WebDictionaryView` 用 `initialUrlRequest` 加载、`ValueKey('web_$sourceId')` 让 Flutter 在切源时重建为全新 native view（杜绝旧页像素残留），加载遮罩盖到 `onLoadStop` 揭示。**放弃**单实例保活 + `loadUrl` 切换 + 进度阈值/延时启发式那套 workaround（删 `web_dictionary_keepalive_provider`）。移动端 UA + `preferredContentMode.MOBILE` 走移动布局。
- [x] 测试：`web_dictionary_source_test`（遍历配置校验 id/URL 编码/sourceId）；`lookup_controller_test` 改用 `WebDictResult`。`flutter analyze` 我方文件 0、dictionary 全部 84 测试通过。

  **完成时间**: 2026-06-27

## 已完成：修复 AI 词典弹窗出现时闪烁一下

复查过的单词（L2 SQLite 缓存命中）再次查词时，弹窗弹出途中会「闪烁一下」。根因：内容区套了 `AnimatedSize`/`AnimatedSwitcher`，缓存结果在弹窗滑入动画途中（约几十 ms）到达，触发高度增长动画 + 内容切换，与滑入运动叠加。L1 内存命中（首帧前解析完）和 L3 网络（滑入早已结束）都不受影响，故只在复查单词时显现。改为：滑入动画期间内容区直接渲染（不套过渡，被滑入运动掩盖即时定型），监听弹窗路由动画，滑入结束后才启用 `AnimatedSize`/`AnimatedSwitcher` 供切换数据源平滑过渡。

- [x] `lib/widgets/intensive_listen/word_dictionary_sheet.dart`：新增 `_entered` 标志 + `didChangeDependencies` 监听 `ModalRoute.animation`，滑入完成置位刷新；`_buildContent` 据此决定是否套过渡。
- [x] 测试：`word_dictionary_sheet_test` 新增「滑入期间内容区不套 AnimatedSwitcher，滑入结束后启用」用例。`flutter analyze` 0、相关测试全过。

  **完成时间**: 2026-06-27

## 已完成：修复默认 AI 词典冷启动后首个单词误显 local 词典

默认源设为 AI 时，冷启动/热更新后点第一个单词显示的是 local，点其它单词才正常。根因：`DictionarySettingsNotifier` 采用「假异步」——`build()` 同步返回缺省 `local`，真实值由 `_load()` 后台 `await SharedPreferences.getInstance()` 异步读入；首查在加载完成前同步锁定了缺省 local。改为同步从 main() 已预热注入的 `sharedPreferencesProvider` 读取，首次 build 即拿到真实设置，竞态从根上消除（`resolvedDefaultSourceId`/`lookup_controller`/UI 零改动）。

- [x] `lib/providers/dictionary/dictionary_settings_provider.dart`：`build()` 改为同步 `ref.watch(sharedPreferencesProvider)` 读取并解析；删除 `_load()`；`_persist` 改用同步 provider 取实例。
- [x] 测试：`dictionary_settings_provider_test` 新增「冷启动同步读取持久化默认源」用例 + 各 dictionary/settings 测试补 `sharedPreferencesProvider` override（settings_screen 的 study section 同步读词典设置，需注入 SP）。`flutter analyze` 0、相关测试全过。

  **完成时间**: 2026-06-27

## 已完成：清理死掉的 WordAi 解析 + AI 缓存表正名 + 修复 AI 词典 L1 缓存清不掉

围绕 AI 缓存的三件清理：删除已被 AI 词典取代、无任何 UI 调用的 WordAi 单词解析；澄清缓存表实为通用 AI 结果缓存；补齐清缓存对 AI 词典内存缓存的清理。

- [x] **删死代码**：`word_analysis` type 已无任何调用点（`getWordAnalysis`/`analyzeWord` 仅剩 `clearMemoryCache`/`invalidate` 接线）。删除 `lib/providers/word_ai_provider.dart`、`lib/models/word_analysis.dart`、`SentenceAiApiClient.analyzeWord`、`/api/v1/ai/word-analyze` 调用及对应测试（`word_ai_provider_test`/`word_analysis_test`/api client 的 analyzeWord group）；移除 `database/providers.dart`、`settings_screen.dart` 里的 import 与 `wordAiNotifierProvider` 接线。
- [x] **缓存表正名**：`sentence_ai_cache` 实为按 `(textHash, type)` 索引的**通用 AI 结果缓存**（住着 translation/analysis/ai_dictionary）。更新表/DAO/`type` 列/`_cacheType` 注释如实表达（表名为历史遗留，不改名以免迁移）。
- [x] **修复 AI 词典 L1 缓存清不掉**（原 bug）：清缓存只清了 SQLite + 句子 AI 的 L1，`AiDictionarySource._memCache` 从没被清→清缓存后重查仍命中旧结果。新增 `AiDictionarySource.clearMemoryCache()`，接入 `settings_screen` 清缓存第 2 步与 `switchAppDatabase`（切库 invalidate keepAlive 源以丢弃旧库结果）。
- [x] 测试：`ai_dictionary_source_test` 新增「clearMemoryCache 后重查回到 L2/L3（API 调 2 次）」；改动文件 `flutter analyze` 0、相关测试全过。

  **完成时间**: 2026-06-27

## 已完成：AI 词典改为后台单请求（关弹窗不中断、重查复用、不重复发请求）

原行为：加载中关闭词典弹窗 → controller autoDispose → 取消在途 CancelToken → AI 请求被中断且未落缓存 → 重查同词从零再发请求（烧 token、慢）。改为标准的「后台单请求」语义：请求生命周期与弹窗解耦，跑完落缓存，全程只有一个请求。

- [x] AI 源 `lib/services/dictionary/ai_dictionary_source.dart`：`lookup` 刻意忽略调用方 `cancelToken`，`_fetch` 去掉该参数、不转发给 API——请求一经发起即跑到底并落 L1+L2 缓存。`_pending` 在途去重 + 缓存共同保证同词只有一个请求（与 widget 生命周期解耦）。
- [x] controller `lib/providers/dictionary/lookup_controller.dart`：新增 `_disposed` 守卫（`_dropResult = _disposed || _isStale`），AI 后台请求在 dispose 后回调到达时丢弃，避免对已销毁 Notifier 写 state 抛错。onDispose 仍取消 token（网页源据此中断抓取，AI 忽略后台续跑）。
- [x] 接口注释 `dictionary_source.dart`：注明源可忽略 `cancelToken`（AI 后台单请求语义）。
- [x] 测试：`ai_dictionary_source_test`（忽略 cancelToken 不转发 API、并发同词只调一次 API）、`lookup_controller_test`（controller 销毁后在途请求完成不写已销毁状态不抛错）；改动文件 `flutter analyze` 0、相关测试全过。

  **完成时间**: 2026-06-27

## 已完成：修复 Cambridge 网页词典加载（缓存失败/卡转圈/误判失败/强刷）+ 切换器 UX

网页词典（Cambridge WebView）一系列加载问题修复 + 切换器交互优化。

- [x] **缓存失败结果致空白页**：`markLoaded` 原在 `onWebViewCreated` 发起加载时**乐观调用**，失败的加载被记入复用缓存→重开命中复用窗口跳过加载→显示空白。改为仅成功才 `markLoaded`；新增 `markFailed(word)` 清该词复用记录（只清匹配词），失败/超时即清。
- [x] **加载超时**：新增 20s 超时计时器，超时未完成转失败态可重试；进度达标即取消。
- [x] **重试不强刷**：重试走 `_startLoad(forceReload: true)` 绕过 HTTP 缓存（iOS/macOS 用 `RELOAD_IGNORING_LOCAL_CACHE_DATA`，Android 先 `clearAllCache`），避免重试又命中失败缓存。
- [x] **卡在"加载中"**：`onLoadStop` 原先 `await` 美化注入在清 `_loading` 之前，注入抛错则卡转圈。改为先结束 loading 再 try-catch 包裹注入。
- [x] **内容已显示却变失败**：Cambridge 页（AI Assistant 长连接）迟迟不触发 `onLoadStop`，`_loading` 一直 true→20s 后超时误判失败。改以 `onProgressChanged` 进度 ≥70% 为主信号（`_markShown`）；`onReceivedError` 仅在加载中、主框架、非 CANCELLED 才算失败。
- [x] **加载条太抢眼**：`LinearProgressIndicator` 改 2px 高 + 透明底 + 主色 35% 透明度。
- [x] **切换器 UX**（`source_switcher.dart`）：下拉 chip 选中态加主色边框/字（与 AI 按钮对称，标明当前选中）；选中 AI 时点 chip 直接切到默认源（不先展开菜单），切到下拉源后才展开菜单换源。
- [x] 测试：`cambridge_webview_provider_test`（复用窗口/换词/超窗/失败清缓存/markFailed 不误清）、`source_switcher_test` 新增「选中 AI 时点 chip 直接切源」；`flutter analyze` 0、相关测试全过。

  **完成时间**: 2026-06-27

## 已完成：AI 词典对齐后端新 entry 格式 + 美化展示

后端 `/api/v2/ai/dictionary` 的 entry 格式调整（`learnerTips` 由单字符串改为字符串数组、`wordFamily` 项新增 `meaning`），App 侧对齐模型并整体美化 AI 词典结果视图，使其专业、简洁、美观。仅动 AI 源相关代码，本地/Cambridge 源、弹窗组装器、切换器、TTS/收藏不变。

- [x] 模型对齐 `lib/models/dictionary/dictionary_entry.dart`：`DictionaryEntry.learnerTips` 改 `List<String>`（`fromJson` 复用 `_strList`）、`WordFamilyItem` 新增 `meaning`（`_str`）；`toJson`/`isEmpty` 随之兼容。
- [x] 美化渲染层 `lib/widgets/dictionary/ai_dict_result_view.dart`（整体重写）：多义项序号徽章 + 义项间细分隔；释义字重提升；近/反义词由逗号文本改为圆角 chips（近义主色淡底、反义中性淡底）；例句改圆角主色淡底块 + 左主色 accent，中英文层级分明；常见搭配补显此前被丢弃的 `type` 小标签；词族补显新增 `meaning`；学习提示由单段改为项目符号列表；补充分节（搭配/词族/词源/提示）包入柔和卡片 + 图标徽章标题。状态分支与「空字段隐藏」原则不变。
- [x] 空条目兜底 `lib/services/dictionary/ai_dictionary_source.dart`：`learnerTips: const []`。
- [x] 测试：`dictionary_entry_test`（learnerTips 数组 / wordFamily meaning / 类型不符回退空列表 / 往返）、`ai_dict_result_view_test`（近义 chip / 多义序号 / 搭配 type / 词族 meaning / 提示逐条）；`ai_dictionary_source_test`、`word_dictionary_sheet_switch_test` 同步签名。
- [x] 验证：改动文件 `flutter analyze` 0 问题；相关测试全过。

  **完成时间**: 2026-06-27

## 已完成：多词典源查词（可插拔框架：本地 / AI / Cambridge）

查词底部弹窗从「单一本地词典」升级为「可切换的多词典源」。右上角下拉切换数据源，「我的」Tab 新增「词典设置」（设默认词典 + 启用/禁用可选源）。核心是可插拔框架：日后加 Oxford 等只需新增一个 source 实现 + 注册一行，不改现有 source / 弹窗 controller / 设置。

- [x] 领域模型：`DictionaryLookupResult`(sealed: Local/Ai/CambridgeWeb) + `DictionaryEntry`(镜像后端 v2 `/api/v2/ai/dictionary`) + `DictionarySettings` + `DictionarySource`/`Request` 接口。
- [x] 三个 source：本地（包装 `DictionaryService`）、AI（v2 接口 + 三级缓存 + Bearer 鉴权 + targetLanguage，依赖延迟解析避免枚举即初始化 DB）、Cambridge（构造中英对照网页 URL）。
- [x] 注册表 + 派生可见列表：`dictionary_registry`、`visibleDictionarySources`、`resolvedDefaultSourceId`（默认源被禁用时回退 local）。
- [x] 设置 provider：`DictionarySettingsNotifier`（SharedPreferences；只允许可禁用源进禁用集、禁用当前默认源自动回退）。
- [x] 查词 controller：`DictionaryLookupController`（family by word，选中源 + 各源态缓存 + 每源序列号/CancelToken 防竞态）。
- [x] 渲染层：本地/AI(结构化)/Cambridge(InAppWebView 保活+5min复用) 三视图 + 右上角下拉切换器 + sealed-result 穷尽分发；AI 复用词性蓝标签。
- [x] 弹窗整合：`word_dictionary_sheet` 瘦身为组装器（切换器 + controller + AnimatedSwitcher），`showWordDictionarySheet` 签名不变，保留 TTS/收藏。
- [x] 词典设置页 + 「我的」Tab 入口（默认词典单选 + 源开关/锁定）。
- [x] i18n：en/zh 新增词典源名/设置页/Cambridge/AI 空态·登录等文案。
- [x] 新增依赖 `flutter_inappwebview`（含 macOS）。
- [x] 测试：模型/设置/可见列表/三源/controller 单测 + 各视图/切换器/设置页/弹窗切换 widget 测；`flutter analyze` 0（新代码）、`flutter test` 全过。
- [x] UI 微调：AI 源提到下拉菜单外，成独立「✨ AI」快捷按钮（紫色，紧贴切换器左侧、与其等高、整体靠右）；选中 AI 时清空菜单内勾选；两 chip 视觉权重统一（同中性底，AI 仅以紫色字/选中淡紫底区分）；弹窗最高限 2/3 屏。

  **完成时间**: 2026-06-27

## 已完成：全部学习子阶段设置持久化改用「按槽位 typed 偏好」

把逐句精听的标准持久化推广到所有学习子阶段 + 收藏句/收藏词复习,并保持「每个复习轮次的设置各自独立」。设置的真正单位是**槽位**=子阶段×复习轮次(盲听/复述跨首学+各复习轮、难句补练跨各复习轮),故按槽位 key 存、轮次独立。

- [x] 通用底座 `lib/models/slot_prefs.dart`（`SlotPrefs<P>` 槽位→可空偏好表）+ `lib/providers/slot_prefs_notifier.dart`（`SlotPrefsNotifier<P>` 基类:按槽位读写 + 启动期注入 + 写 SP）。
- [x] 各 Settings 模型对应的可空偏好 + Provider:`IntensiveListenPrefs`（精听+跟读共用,槽位区分）、`BlindListenPrefs`、`RetellPrefs`（含 keywordRatio/targetSeconds 动态默认）、`DifficultPracticePrefs`（难句补练+收藏句复习共用）。`resolve(槽位, 智能默认)` 出生效设置。
- [x] 各 player/controller/session：`initialize`/`enter*Mode` 收完整 settings（屏幕 resolve 出）、`updateSettings` 写穿偏好；删除 `_applyOverride`/有损 `pauseMultiplier` 通道。
- [x] 屏幕各入口（按计划 + 自由练习 + 复习各轮）：预填 `prefs.resolve`、记于开始练习（精听/跟读为改完即记）；自由练习与按计划共用同一轮次槽位。
- [x] 清退 `stage_settings_overrides` 存储：删 Provider + `StageSettingsOverrides`/`settingsJsonDiff`/`toOverride`/`overrideToBriefingPauseChoice`；`stage_settings_overrides.dart` 仅保留通用的 `StageSettingsSlots`/`stageSlotKey`/`BriefingPauseChoice`。
- [x] 收藏词复习（闪卡）：已有独立单 store 持久化（`flashcard_settings`），核验正常,本次不动。
- [x] 测试：各子阶段 prefs 模型/Provider 单测 + 桥接/流程测试;`flutter analyze` 0、`flutter test` 全过。

  **完成时间**: 2026-06-26

## 已完成：逐句精听设置持久化改用标准「单 store + 可空覆盖」

逐句精听设固定停顿后关弹窗重开/进播放器仍显示「自动」。根因是旧 `stage_settings_overrides` 方案踩坑：两处真相源（会话 settings + 稀疏覆盖表，靠 `BriefingPauseChoice↔Map↔fromJson` 翻译）、停顿经 `legacyPauseMultiplier` 折成 `-1.0` 的有损通道（固定值只能靠覆盖表读回）、自由练习入口三处接线全断。改为业界标准的偏好持久化：**单一 typed、全字段可空的 `IntensiveListenPrefs`**（null=用默认，含动态智能速度默认），入口弹窗 / 🔧 面板 / 播放器初始化都读写这一份，无第二份拷贝、无翻译、无有损通道。两个入口（按计划 / 自由练习）共用同一逻辑，行为一致。本次仅 intensive；跟读/复述/盲听/复习暂仍用旧覆盖表。

- [x] `lib/models/intensive_listen_prefs.dart`：全字段可空模型 + `resolve(smartSpeed)` 叠加默认 + 稀疏 `toJson`/防御性 `fromJson`/`fromPrefsSync`。
- [x] `lib/providers/intensive_listen_prefs_provider.dart`：手写 Notifier + 启动期 override 注入；细粒度 setter 为唯一写路径（只把改动字段从 null 变非空，不冻结智能默认）。
- [x] `lib/main.dart`：`fromPrefsSync` 预读 + ProviderScope 注入。
- [x] `learning_plan_screen.dart`：两入口 `_startIntensiveListen` / `_startFreePlayIntensiveListen` 改读 prefs.resolve 预填 + `intensivePrefsRecorder` 改完即记；删除已无人用的 `_briefingPauseRecorder`。
- [x] 播放器：`enterIntensiveListenMode`/`initialize` 改收完整 `IntensiveListenSettings`（删 `pauseMultiplier`/`settingsSlot`/`_applyOverride`）；`updateSettings` 写穿到 prefs（🔧 面板从「临时」改「持久」，更新文案）。
- [x] 测试：`intensive_listen_prefs_test`（13）、`intensive_listen_prefs_provider_test`（5）、`intensive_listen_pause_flow_test`（4，两入口端到端锁 bug）；更新 fake_notifiers / settings_sheet 断言。
- [x] 验证：`flutter analyze` 0 问题；`flutter test` 全通过。

  **完成时间**: 2026-06-26

## 已完成：修复刚完成大阶段不实时显示「完成于XX」

学习计划页中刚完成的大阶段会立即显示 ✅，但右侧「完成于XX」相对完成时间需重启 App 才出现。根因：`reviewStageCompletionTimesProvider` 是 `FutureProvider`，结果永久缓存，`stage_completions` 写入后不失效。改为基于 drift `.watch()` 的 `StreamProvider`，表变更自动发射，无需手动 invalidate（对齐同文件 `audioBookmarkCountProvider` 既有模式）。天然覆盖首次学习完成、跳过后补做、重置删除等所有写入场景。

- [x] `lib/database/daos/stage_completion_dao.dart`：新增 `watchStageCompletedAtByAudioId`（流式），抽出共用查询 `_stageCompletedAtQuery` 与折叠函数 `_foldStageCompletedAt`，Future 版复用。
- [x] `lib/screens/learning_plan_screen.dart`：`reviewStageCompletionTimesProvider` 由 `FutureProvider.family` 改为 `StreamProvider.family`；消费端零改动（`.valueOrNull` 对 Stream/Future 一致）。
- [x] 测试：`stage_completion_dao_test.dart` 新增 `watchStageCompletedAtByAudioId` 用例（插入后流自动发射、同 stage 取最后完成时间）。
- [x] 验证：改动文件 `flutter analyze` 0 问题；`flutter test test/database/daos/stage_completion_dao_test.dart` 全通过（14）。

  **完成时间**: 2026-06-25

## 已完成：学习子阶段设置跨音频持久化

6 个听说子阶段（盲听/精听/跟读/复述/难句补练/收藏句复习）的设置此前仅会话级，退出即丢。现按「子阶段 × 复习轮次」跨音频记住用户**手动改动过**的全部设置（含播放器内 🔧 面板的 controlMode/repeatCount/pauseMode 等，以及入口弹窗的速度/停顿/复述可见词比例/目标时长）。入口弹窗预填记忆值，与进入页面后的设置等效。仅记手动改动、不冻结按难度/轮次递进的智能默认；分轮独立；自由练习不记；闪卡沿用既有持久化。

- [x] `lib/models/stage_settings_overrides.dart`：稀疏字段覆盖存储模型（slot=`子阶段:轮次`）、`stageSlotKey`/`settingsJsonDiff`/`briefingPauseToOverride`/`overrideToBriefingPause` 等纯函数。复用各 Settings 模型现成 `toJson/fromJson`，不写镜像类。
- [x] `lib/providers/stage_settings_overrides_provider.dart`：手写 Notifier + 启动期 override 注入（对齐 learning_settings_provider）；`overridesFor`/`recordOverride`。
- [x] `lib/main.dart`：`fromPrefsSync` 预读 + ProviderScope 注入。
- [x] 6 个 provider（含 `ListenAndRepeatSettings` / `BookmarkReview` / 共用 `DifficultPracticeSettings` 的公共 helper）：`initialize` 增 `settingsSlot` 并 seed（override-wins）、`updateSettings` 开头 diff 记录。session 的 `enter*Mode` 透传 `LearningStage? stage`，自由练习传 null（不记）。
- [x] 入口弹窗：3 个专用 sheet（精听/跟读/难句）+ 共用 `paragraph_selection_sheet`（盲听/复述）新增 `defaultPauseMultiplier` 并自校验；`learning_plan_screen` 各在途站点预填 + record-before-enter。
- [x] 测试：`stage_settings_overrides_test`（21）、`stage_settings_overrides_provider_test`（6）、`listen_and_repeat_settings_memory_test`（4，端到端 seed/record/分轮独立/不冻结）。
- [x] 验证：`flutter analyze` 改动文件 0 问题；`flutter test` 全通过（3066）。

  **完成时间**: 2026-06-25

## 已完成：锁屏整篇循环进度条偶发卡在结尾

整篇循环时锁屏 Now Playing 进度条偶发卡在上一遍结束位置（满格、暂停图标），但音频已在播下一遍。根因：`_broadcastState()` 把 just_audio 自然播完的 `completed` 状态原样上报给系统，iOS 据此把曲目当作已播完、进度条钉在结尾，后续回卷 `seek(0)` 在「已结束」态下被忽略（偶发，取决于 completed→ready 转换时序）。详见 CLAUDE.md §7.7。

- [x] `lib/services/background_audio_handler.dart`：`_mapProcessingState` 把 `ja.ProcessingState.completed` 映射为 `AudioProcessingState.ready`——循环播放器对系统从不真正「结束」，系统永不收到 completed 标志，回卷/续播的 position 更新在 ready 态下被正常接受。app 内部 completed 判定均读原始 player 状态，零副作用。
- [x] 测试：`background_audio_handler_test.dart` 新增 2 例（completed→ready 映射、其余状态原样映射）。
- [x] 验证：`flutter analyze` 改动文件 0 问题；`background_audio_handler_test` 全通过（14）。

  **完成时间**: 2026-06-25

## 已完成：Free Player 结束态进入后首次点击误从结尾起播

进入 player 时 `_restorePlaybackState` 会把引擎 seek 到上次存档位置；若上次正好播到结尾，存档位置就在音频末尾，此时 just_audio 的 `processingState` 仍是 `ready`（非 `completed`，且 `_awaitingReplayFromStart` 为 false）。「续播 vs 从头」的启发式（`processingState != completed && position > 0`）据此误判为「续播」：无字幕从结尾起播立即结束（需点两次才从头播），有字幕则从最后一句起播而非音频开头。

- [x] `lib/providers/audio_engine/audio_engine_provider.dart`：新增 `totalDuration` getter（暴露已解析总时长）。
- [x] `lib/providers/listening_practice/listening_practice_provider.dart`：新增 `_isAtAudioEnd()`（位置接近总时长即视作已播完）。无字幕 `_startNoTranscriptPlayback` 的续播判定加 `!_isAtAudioEnd()`；有字幕 `play()` 把「已播完重播」分支条件改为 `_awaitingReplayFromStart || _isAtAudioEnd()`，结尾态统一走 `_restartFromPlayableBeginning` 从列表开头重播。
- [x] 测试：`free_player_playback_flow_test.dart` 新增 3 例（无字幕结尾态首点 seek(0)、无字幕中段续播不 seek(0)、有字幕结尾态首点从第 1 句重播）。
- [x] 验证：`flutter analyze` 0 问题；`flutter test` 全通过（3032）。

  **完成时间**: 2026-06-25

## 已完成：Free Player 无字幕场景修复

无字幕音频（`transcriptSource == null` → `sentences` 为空）在 Free Player 有多处问题：① 播完后播放按钮卡在「暂停」图标（根因：无字幕 `play()` 从不 `newSession()`，`_playbackSessionId` 停在 `-1`，`_onPlayerStateChanged` 永远 early-return，逻辑播放态没有路径置回 false）；② 播完后点击无法从头重播（just_audio 对 `completed` 播放器 `play()` 不回头，且未设 `_awaitingReplayFromStart`）；③ 显示无意义的「上一句/下一句」（App 内 + 锁屏）；④ 显示无法使用的模式切换/字幕显示/单句循环；⑤ 整篇循环开启后不循环。

- [x] `lib/providers/listening_practice/listening_practice_provider.dart`：新增 `_startNoTranscriptPlayback`/`_playNoTranscriptDriven`（确定性 await-完成循环 + 认领 session + honor `loopWhole`）、`seekRelative`（相对 seek 钳制）、`_applyLockScreenHandlers`（按 `hasSentences` 注册切句 vs 后退/前进回调）。
- [x] `lib/providers/audio_engine/audio_engine_provider.dart`、`lib/services/background_audio_handler.dart`：新增 `setSeekHandlers` + 锁屏 rewind/fastForward 控件（与切句互斥）。
- [x] `lib/widgets/playback_controls.dart`：无字幕只显示 速度 + 后退/前进10秒 + 整篇循环；隐藏模式切换/字幕显示。
- [x] `lib/widgets/settings_dialog.dart`：`LoopSettingsPopup` 无字幕时隐藏单句循环。
- [x] `lib/screens/player_screen.dart`：状态栏无字幕时隐藏模式标签。
- [x] 顺带修复（有字幕）：播放中点上一句/下一句会把整篇循环遍数重置为第一遍。`_startWholeDriven` 拆分 `resetWholeLoops`/`resetSentenceRepeats`，`_startCurrent` 增 `resetWholeLoops` 参数，`_moveToIndex`（prev/next）传 `false`——切句视为「同一遍内换句」，保留整篇遍数、只重置单句遍数。
- [x] 测试：provider 无字幕场景（起播/播完/重播/整篇循环/seekRelative）+ 有字幕切句保留整篇遍数；`playback_controls_test`、`settings_dialog_test`、`background_audio_handler_test` 新增/更新。

  **完成时间**: 2026-06-25

## 已完成：学习计划页当前阶段 item 可点击

学习计划页时间线上，已完成/已跳过/过去阶段的子步骤卡可点击进入自由练习，但**当前进行中的子步骤卡**（`isCurrent`）此前不可点击，用户只能靠底部「开始学习」按钮启动。现改为：当前步骤卡可直接点击，效果与点击底部「开始学习」完全一致（复用同一 `_handleStartLearning` 回调，同样受「有字幕 && 复习未锁定」门控）。

- [x] `lib/screens/learning_plan_screen.dart`：`_FirstStudySection` / `_ReviewRoundSection` 各新增 `onStartCurrentStage` 回调字段；父级以与底部按钮一致的 `hasTranscript && !isLockedReview ? () => _handleStartLearning(...) : null` 注入；两区块 item 构造在 `isCurrent` 时把 `onTap` 指向该回调。
- [x] 测试：`learning_plan_screen_test.dart` 新增 2 例（点击当前精听卡弹出简报、无字幕时点击当前卡无反应）。
- [x] 验证：`flutter analyze lib/screens/learning_plan_screen.dart test/screens/learning_plan_screen_test.dart` 0 问题；`flutter test test/screens/learning_plan_screen_test.dart` 全通过（49）。

  **完成时间**: 2026-06-25

## 已完成：复习轮次增量间隔修正 + 学习计划页完成时间展示

学习计划的复习解锁原先沿用“上一轮完成后再等”的滚动基准，但误把累计里程碑（1d/2d/4d/28d）直接当作相邻两轮的等待时长，导致后续轮次整体偏长；同时学习计划页未来轮次展示固定 `After X days` 文案，在滚动基准下容易误导。现改为：继续保留“上一轮完成后解锁下一轮”的简单策略，但把各轮等待时长修正为增量值；未来未解锁轮次不再显示固定时间，已完成轮次则显示相对完成时间（如 `2天前` / `2h ago`）。

- [x] `lib/database/enums.dart`：将 `LearningStage.intervalHours` 改为“距上一轮完成后的等待时长”，各轮增量修正为 `6h / 18h / 24h / 48h / 72h / 168h / 336h`。
- [x] `lib/database/daos/stage_completion_dao.dart`：新增按音频聚合 `stage -> 最终 completedAt` 的查询，供学习计划页标题行读取大阶段完成时间。
- [x] `lib/screens/learning_plan_screen.dart`：新增 `reviewStageCompletionTimesProvider`；已完成复习轮次标题行显示相对完成时间，当前轮次继续显示真实倒计时/待复习/逾期，未来轮次隐藏固定 `After X days` 标签。
- [x] 测试：更新 `learning_progress_test.dart` 的增量间隔断言；为 `stage_completion_dao_test.dart` 补聚合查询用例；更新 `learning_plan_screen_test.dart` 覆盖“未来轮次隐藏固定时间”“已完成轮次显示相对完成时间”。
- [x] 验证：`flutter analyze lib/database/enums.dart lib/database/daos/stage_completion_dao.dart lib/screens/learning_plan_screen.dart test/models/learning_progress_test.dart test/database/daos/stage_completion_dao_test.dart test/screens/learning_plan_screen_test.dart` 通过；`flutter test test/models/learning_progress_test.dart`、`flutter test test/database/daos/stage_completion_dao_test.dart`、`flutter test test/screens/learning_plan_screen_test.dart` 全通过。

  **完成时间**: 2026-06-25 13:16:43 +0800

## 已完成：学习页冷启动预加载 + 骨架兜底

默认落地 `Study` tab 时，启动链路原本在首帧后才异步加载音频列表和学习进度，`StudyScreen` 又把“尚未加载”的空列表直接渲染成空态，导致冷启动先闪 `No study tasks yet`，随后才切到真实任务页。现改为：启动阶段优先并发预热学习页首屏必需数据，同时 `Study` 页自身补 loading skeleton 兜底，保证慢机/竞态下也不会再误闪空态。

- [x] `lib/router/main_shell.dart`：将 `audioLibrary.loadLibrary()` 与 `learningProgress.loadAll()` 前移为默认学习页首屏关键预加载，并发等待完成后再继续合集/标签/backfill 等非首屏关键任务；补统一 retry helper，保持失败 snackbar 行为。
- [x] `lib/screens/study_screen.dart`：新增 `audioLibrary.isLoading || learningProgress.isLoading` gate；加载中显示学习页骨架，不再直接渲染 `No study tasks yet`；骨架仅使用私有 `_StudyLoadingSkeleton` / `_SkeletonBlock` 组件，不改任务排序与空态语义。
- [x] 测试：`study_screen_test.dart` 新增音频列表加载中 / 学习进度加载中骨架用例，并把原有用例显式区分 `isLoading=false`；`app_shell_test.dart` / `widget_test.dart` 更新为断言默认进入学习页而非写死首帧空态。
- [x] 验证：`flutter analyze lib/router/main_shell.dart lib/screens/study_screen.dart test/screens/study_screen_test.dart test/screens/app_shell_test.dart test/widget_test.dart` 通过；`flutter test test/screens/study_screen_test.dart test/screens/app_shell_test.dart test/widget_test.dart` 全通过（22）。

  **完成时间**: 2026-06-25 11:50:00 +0800

## 已完成：精听前「听前预热」卡

v2 计划把逐句精听提到首步后，用户对长音频内容零认知就直接精听会蒙。在「首次学习」**上方**插入一张独立醒目的「听前预热」卡片（「推荐先做」徽章 + 耳机图标 + 描述「先听一遍全文，抓住大意，不用听懂每一句」+「先听全文」主按钮），引导用户先用现有随心听播放器整篇泛听熟悉内容。仅 `!isStarted && hasTranscript` 时显示，开始学习后自动消失（按音频维度一次性，无新增持久化）；按钮与右上角胶囊同一目的地。不新增学习步骤、不改进度模型、不强制。

- [x] `lib/screens/learning_plan_screen.dart`：抽 `_openFreePlay`（AppBar 胶囊 + 预热卡 + start 兜底分支共用，消除三处重复）；新增 `_WarmUpCard`（横向单行紧凑卡：暖橙奶油底 + 耳机图标圆底 + 内联「推荐先做」徽章 + 右侧 chevron，整卡可点），在 `_ProgressCard`/无字幕横幅与 `_FirstStudySection` 之间条件插入。
- [x] l10n：`app_zh.arb` / `app_en.arb` 新增 `warmUpCardTitle`(听前预热) / `warmUpCardSubtitle` / `warmUpCardBadge`(推荐先做)。
- [x] 测试：`learning_plan_screen_test.dart` 新增 4 例（未开始+有字幕显示标题与徽章 / 点击进播放器 / 已开始消失 / 无字幕不显示），全部通过。
- [x] 验证：改动文件 `flutter analyze` 0 问题；`flutter test test/screens/learning_plan_screen_test.dart` 全通过（46）。

  **完成时间**: 2026-06-25
  **备注**: 经两轮反馈定稿——初版「首次学习」内嵌虚线小卡 → 上方独立大卡 → 暖橙调横向紧凑卡（更矮、按钮收敛为整卡可点）。

## 已完成：AI 转录「自动合并短句」开关（App 侧）

用户反馈 AI 转录字幕句子太长（后端 `mergeShortSentences` 无条件合并到 4-7s）。新增转录弹窗开关「自动合并短句」，默认开启、记住上次选择；关闭后后端返回 provider 原生未合并分句（句子更短）。App 侧只透传开关；分句质量改造在后端（见 fluency-frontend TASKS.md）。

- [x] `lib/providers/settings_provider.dart`：新增 `aiTranscriptionAutoMergeEnabled`（默认 true）+ key `ai_transcription_auto_merge_enabled` + setter，复用现有 SharedPreferences 模式。
- [x] `lib/widgets/manage_subtitles_sheet.dart`：语言选择下方、仅 AI 模式显示 `SwitchListTile`（初值取设置、onChanged 写回记住）；`startTranscription` 透传 `autoMergeShortSentences`。
- [x] `lib/services/transcription_api_client.dart`：`submitTranscription` body、`getTranscript` query 增 `mergeSentences`（默认 true）。
- [x] `lib/providers/transcription_task_provider.dart`：`startTranscription` 增 `autoMergeShortSentences`，透传给 submit / getTranscript / `_pollJobStatus`。
- [x] l10n：`app_en.arb` / `app_zh.arb` 新增 `autoMergeShortSentences` / `autoMergeShortSentencesHint`。
- [x] 测试：`transcription_api_client_test.dart`（body/query 带 mergeSentences true/false）、`settings_provider_test.dart`（默认/持久化/加载）、`manage_subtitles_sheet_test.dart`（开关显隐/默认开/可切换）；测试 helper 同步新签名。
- [x] 验证：`flutter analyze`（改动文件 0 问题）；`flutter test` 全量通过（2986）。

  **完成时间**: 2026-06-24

## 已完成：锁屏播放控件定制（封面图 / 合集名 / 上一句下一句）

iOS 锁屏 Now Playing 组件的布局不可改，只定制可控的内容与命令。本次三项：①锁屏封面图显示 app 图标；②标题下方（artist 行）由硬编码 `Echo Loop` 改为所属合集名（取第一个，与顶栏副标题同源）；③上一首/下一首改接 Free Player 的上一句/下一句（复用 `nextSentence`/`previousSentence`）。切句控制随 Free Player controller 接管引擎而出现、挂起/释放而消失，避免学习模式等场景误触。

- [x] `lib/services/background_audio_handler.dart`：新增 `prepareArtwork()`（app 图标 asset 拷为本地文件并缓存 file:// URI，`loadFile` 设 `artUri`）；`loadFile` 加 `subtitle` 参数 → `MediaItem.artist`；新增 `setSkipHandlers` + `skipToNext`/`skipToPrevious` override；`setMediaControls` 在可切句时拼成「上一句/播放暂停/下一句」，`systemActions` 增加 skip。`initEchoLoopAudioHandler` 启动时调 `prepareArtwork`。
- [x] `lib/providers/audio_engine/audio_engine_provider.dart`：`loadAudio` 加可选 `subtitle` 透传；新增 `setSkipHandlers` 转发给 handler。
- [x] `lib/providers/listening_practice/listening_practice_provider.dart`：新增 `_resolveCollectionName`（按 `collectionListProvider` 反查首个合集名）并传入 `loadAudio`；`_setupListeners` 注册切句回调、`suspendListeners`/`_disposeListeners` 清空（dispose 用缓存引擎引用，避免销毁阶段 `ref.read`）。
- [x] 测试：新增 `test/services/background_audio_handler_test.dart`（skip 回调触发/no-op、控制列表与 systemActions 随注册变化）；`fake_notifiers.dart` / `loop_reset_on_load_test.dart` 同步新签名。
- [x] 验证：改动文件 `flutter analyze` 0 问题；`flutter test`（含 listening_practice / audio_engine / handler）通过。锁屏视觉效果（封面图/合集名/切句按钮）需真机或模拟器人工确认。

  **完成时间**: 2026-06-24

### 追加：播完后保留锁屏控件 + 锁屏播放/暂停经业务逻辑

原行为：整篇/列表自然播完（不循环）时 controller 调 `_engine.stop()` → `super.stop()` → iOS 清空 Now Playing → **锁屏控件直接消失**。改为播完保留媒体会话、停在暂停态，符合 Apple Music/Podcasts 习惯，用户可在锁屏直接重播。同时把锁屏播放/暂停按钮接入 controller 业务逻辑（此前直接打到底层 player，绕过「播完从头重播 / 保留遍数续播」）。

- [x] `background_audio_handler.dart`：新增 `playPlayer`/`pausePlayer`（直接驱动播放器）与 `setTransportHandlers`；`play`/`pause` override 改为「有回调走回调，否则回退 playPlayer/pausePlayer」，避免 controller→engine→handler→controller 回环。
- [x] `audio_engine_provider.dart`：内部协程（playClipOnce/playToEnd/playRangeOnce）与 `play`/`pause`/`pauseKeepSession` 一律改用 `playPlayer`/`pausePlayer`；新增 `setTransportHandlers` 转发。
- [x] `listening_practice_provider.dart`：natural-end 的两处 `_engine.stop()` 改为 `pauseKeepSession()`（保留会话）；`_setupListeners` 注册 `setTransportHandlers(onPlay: play, onPause: pause)`，suspend/dispose 清空；`_onPlayerStateChanged` 增加 completed 守卫——completed 时 just_audio 的 `playing` 仍为 true，保留会话后该事件会到达监听，不排除会把逻辑播放态误翻回 true（图标错显）。
- [x] 测试：`background_audio_handler_test.dart` 增 play/pause 路由组；`free_player_playback_flow_test.dart` 6 处 natural-end 断言由 `stopCount==1` 改为 `pauseKeepSessionCount==1 && stopCount==0`；`fake_notifiers.dart` 增 `setTransportHandlers` no-op。
- [x] 验证：改动文件 `flutter analyze` 0 问题；全量 `flutter test` 通过。锁屏「播完控件保留 + 锁屏重播」需真机/模拟器人工确认。

  **完成时间**: 2026-06-24

## 已完成：Free Player iOS 后台播放标准化迁移

将 Free Player 的共享播放底座升级为 `just_audio + audio_service + audio_session` 标准架构，先只覆盖 Free Player，解决 iOS 锁屏/后台继续播放，同时保留现有单句循环、整篇循环、收藏跳播、恢复断点等已验证行为不回退。本次不做复杂锁屏自定义控制，但已把系统媒体会话、状态广播和未来扩展边界收敛到统一 `AudioHandler`。

- [x] `pubspec.yaml` / `pubspec.lock`：新增 `audio_service` 依赖；插件接入后同步更新锁文件与 macOS 插件注册文件 `macos/Flutter/GeneratedPluginRegistrant.swift`。
- [x] `lib/services/background_audio_handler.dart`：新增全局 `EchoLoopAudioHandler`，内部托管唯一 `AudioPlayer`，统一承接系统媒体会话、后台播放状态广播、基础播放命令与 `audio_session` 中断配置。
- [x] `lib/main.dart`：启动阶段改为初始化全局后台播放 handler，不再在 `main()` 里分散配置 `AudioSession`。
- [x] `lib/providers/audio_engine/audio_engine_provider.dart`：从“直接持有 `AudioPlayer`”重构为 `AudioHandler` facade；保留 Free Player 现有高层接口，避免打破循环/seek/clip 语义。
- [x] `lib/providers/listening_practice/listening_practice_provider.dart`：新增底层 `playerStateStream` 监听，把锁屏/系统媒体会话导致的被动暂停/恢复回写到 `isPlaying`，修复“实际停了但按钮仍显示暂停”。
- [x] `lib/screens/player_screen.dart`：移除 `deactivate()` 的误停播逻辑，改为仅在页面真正 `dispose` 时暂停并保存进度，避免 iOS 锁屏/后台切换误触发暂停。
- [x] `android/app/src/main/AndroidManifest.xml` / `android/app/src/main/kotlin/app/echoloop/MainActivity.kt`：补齐 `audio_service` 所需的前台媒体播放权限、service / receiver 声明，并让 `MainActivity` 继承 `AudioServiceActivity`。
- [x] 测试：`free_player_playback_flow_test.dart` 新增“外部暂停/恢复回写逻辑播放态”回归；`player_screen_test.dart` 全量通过，确认页面生命周期改动未破坏既有 UI 行为。

  **完成时间**: 2026-06-23 19:53:37 +0800

## 已完成：修复 Free Player 恢复后进度条停在 0:00

Free Player 恢复播放断点时，provider 已经按持久化绝对时间 `seek` 到正确位置，句子高亮也会恢复到对应句；但底部进度条首帧只依赖 `absolutePositionStream`，如果 `seek` 后还没有新的位置流事件，UI 会暂时显示 `0:00`。现改为：进度条无拖动预览时直接读取 `AudioEngine.absoluteCurrentPosition` 作为首帧真相源，避免“当前句已恢复到末句，但进度条仍在起点”的错位。

- [x] `player_screen.dart`：`_buildProgressBar()` 的首帧位置来源从“stream 快照兜底 `Duration.zero`”调整为“优先 `_seekPreviewPosition`，否则读取 `absoluteCurrentPosition`”；保留 `StreamBuilder` 负责响应后续位置变化。
- [x] `player_screen_test.dart`：新增恢复断点回归，覆盖“getter 已在恢复位置、positionStream 尚未发事件”场景，直接断言 `ProgressBar.progress` 使用恢复后的绝对时间。
- [x] 验证：`flutter analyze lib/screens/player_screen.dart test/screens/player_screen_test.dart` 通过；`flutter test test/screens/player_screen_test.dart` 23 passed。

  **完成时间**: 2026-06-23 19:07:53 +0800

## 已完成：资源库排序方式持久化

资源库页面的排序方式此前仅存于 Riverpod 内存 state，App 重启后回到默认「最近创建」，用户需反复手动选择。改为持久化到 SharedPreferences，下次进入自动恢复。复用 `settings_provider.dart` 范式（常量 key + 异步 `_load` + setter 中 `await prefs.setString`），enum 以 `.name` 字符串存储、解析失败回退默认。覆盖资源库页两个排序入口：合集排序（`CollectionSortType`）与音频列表排序（`AudioSortType`，同时用于合集详情页非官方合集）。此改动不触发 riverpod 代码生成，无 `.g.dart` 变更。

- [x] `collection_provider.dart`：新增 `_collectionSortTypeKey`、纯函数 `collectionSortTypeFromName`（null/非法回退 dateDesc）；`build()` 挂 fire-and-forget `_loadSortType()`（try/catch 保护，prefs 失败不影响合集加载）；`setSortType` 改 `Future<void>` 并写入 prefs。
- [x] `audio_list_settings_provider.dart`：同上模式（保持 `@riverpod` 不改 keepAlive，autoDispose 重建后会从 prefs 重新读回）。全局菜单仅 4 项不含 `custom`，custom 永不进入持久化。
- [x] UI 层（`CollectionSortButton`/`AudioSortButton`）无需改动，onSelected fire-and-forget。
- [x] `fake_notifiers.dart`：`FakeCollectionList.setSortType` 签名同步改 `Future<void>`。
- [x] 测试：两个 provider 各新增解析纯函数（合法/null/非法回退）+ `setSortType` 持久化写入用例；全量 `flutter test` 2969 通过，`flutter analyze` 改动文件 0 问题。

  **完成时间**: 2026-06-23

## 已完成：版本号升级到 1.0.19

按“版本 +1”要求，将 Flutter 应用版本从 `1.0.18` 升级到 `1.0.19`。当前仓库的 Android `versionName` 跟随 Flutter `versionName`，本次只需更新 `pubspec.yaml` 即可同步到标准 Flutter 构建链路；不额外改动业务代码或平台逻辑。

- [x] `pubspec.yaml`：版本号从 `1.0.18` 升级到 `1.0.19`。
- [x] 验证：检查 Android `build.gradle.kts` 仍使用 `flutter.versionName`，版本升级会随 Flutter 构建配置自动生效。

  **完成时间**: 2026-06-23 12:56:44 +0800

## 已完成：Free Player 精听单句模式切句改为 iPhone 相册式跟手滑动

此前 Free Player「单句模式（= 精听模式）」切句用 `AnimatedSwitcher` + `FadeTransition`，淡入淡出期间新旧文字在同一 Stack 内叠加 → 文字相互遮挡，且不跟手。改为业界标准的 `PageView.builder` + `PageController` 横向分页：内容跟手左右滑动、松手吸附，类似 iPhone 相册照片切换。

- [x] `player_screen.dart`：`_buildSingleSentenceView` 用 PageView 重构，删除 `AnimatedSwitcher`/`_SingleSentenceAnimatedPage`/`_handleSingleSentenceSwipe` 及方向追踪字段；header + 难句标记行固定在 PageView 之上。
- [x] 双向同步：provider→PageView 用 post-frame `animateToPage`（首次 `jumpToPage`）跟随自动推进/选句；PageView→provider 用 `onPageChanged` → `select{Full,Bookmarked}Sentence(autoPlay: isPlaying)`；两端按当前 truth 比较 guard，屏蔽 `animateToPage` 落点回声，避免回环。
- [x] 全文 / 收藏两 tab 各持一个 `PageController` + 独立 key + 显式传 `PlaylistMode`：规避 TabBarView 切换动画期间两 body 同存导致单 controller 多挂、及离屏 tab 用全局 playlistMode 错配列表。
- [x] 端点吸附天然替代手动边界 guard；`AnnotationContentView` 预建仅本地 SQLite 无网络，PageView.builder ±1 预建安全。
- [x] 测试：`player_screen_test.dart` 改写两条 swipe 用例为 PageView 翻页 + 选句记录，新增「保持播放态 autoPlay:true」「首页右滑端点吸附不触发」「外部推进自动跟随不回环」3 条，单文件 21 通过。
- [x] 修正：点击解析/翻译/意群工具栏按钮触发「当前句自然播完后暂停」（`onToolbarButtonTapped` → `pauseAfterCurrentSentence()`），避免打断当前朗读；意群试听播放前仍立即暂停（`onStopMainPlayer` → `pause()`）。句级循环在 clip 边界停在本句、整篇 gapless 在跨句边界回退停留在刚播完的句子（`_pauseGaplessHoldingSentence`），使解析面板停留在用户点击的句子上。
- [x] 修复：PageView 预建相邻页导致 showcaseview 新手引导崩溃（`ShowcaseController.register` 落在已 unmount 的 State）。`AnnotationContentView` 新增 `enableGuide`（默认 true），离屏页置 false → 四个 GuideStep 为 null（`_wrapGuide` 不包 Showcase）、flows 为空；`player_screen` 仅对 `position == targetPosition` 的当前页启用引导。
- [x] 修正：句级循环（单句循环/收藏）暂停续播保留已完成遍数——`play()` 改为 flag 驱动（`_sentenceLoopResumePending`）的句级 resumable 分支 + `_resumeSentenceDriven`（不清零 `_sentenceRepeatsDone`/`_wholeLoopsDone`），立即暂停与延迟暂停统一置位、换句/seek/stop 清零。此前句级路径恒走 `_startCurrent` 清零，暂停后从第一遍重来。`free_player_playback_flow_test.dart` 新增续播保留遍数、延迟暂停（句级/gapless）、未播放退化立即暂停共 4 条回归。
- [x] 修正：整篇循环播放中开启单句循环不再重置整篇遍数——两套循环状态互不影响。根因：`_maybeHandoffFromGapless` 从 gapless 交接到句级时调 `_startCurrent` 无条件清零 `_wholeLoopsDone`。抽出 `_launchSentenceDriven({resetWholeLoops, resetSentenceRepeats})` 公共入口，交接路径只重置当前句单句遍数、保留整篇遍数；`_startCurrent`(true,true) / `_resumeSentenceDriven`(false,false) 复用同一入口。`free_player_playback_flow_test.dart` 新增「整篇循环中开单句循环不重置整篇遍数」回归。

  **完成时间**: 2026-06-23

## 已完成：修复 Free Player 整篇循环次数不准 + 播放/暂停图标错乱

整篇连续播放（gapless）此前依赖 just_audio 的 `ProcessingState.completed` 事件做反应式循环计数与重启，触发三个连带 bug：① 重复设 3 遍只播 2 遍就停（重复/滞后 completed 事件多计数）；② 播完后播放/暂停按钮仍显示「暂停」图标（按钮直接读 just_audio 的 `playing`，而它在自然播完后仍为 true）；③ 播完后点两下按钮却从最后一句开始（图标错误导致首击触发 pause，清掉了「从头重播」标志）。改为与单句循环一致的确定性 await-完成循环模型，并把图标改由 controller 的逻辑播放态驱动，从根上消除整类竞态。

- [x] `audio_engine_provider.dart`：新增 `playToEnd(sessionId)` 原语（await 自然播完，免疫重复 completed 事件）；新增 `processingState` getter（解耦续播判定、可测）。
- [x] `listening_practice_provider.dart`：新增 `_playWholeDriven` 确定性整篇循环协程 + `_startWholeDriven` 起播入口；删除反应式 `_onPlayerStateChanged`/`_advanceWholeCompletion`/`_handlingWholeCompletion` 及 playerState 订阅；暂停续播、模型交接、seek 续播均改走确定性循环。
- [x] `listening_practice_state.dart` + UI：新增 `isPlaying` 逻辑播放态作为图标唯一真相源；`playback_controls.dart`、`player_screen.dart` 热键改读逻辑态。
- [x] 测试：`free_player_playback_flow_test.dart` 扩展 fake engine（`playToEnd` + `emitCompleted` 贴近 just_audio）并新增 5 个用例（整篇 3 遍恰好停、重复 completed 不多计数、间隔停顿、播完图标恢复+单击从头、暂停续播保留遍数）；`playback_controls_test.dart`、共享 fake 同步更新。全量 `flutter test` 2951 通过。

  **完成时间**: 2026-06-23

## 已完成：Free Player 禁止 tab swipe，逐句精听支持左右滑动切句

此前 Free Player 的 `全文 / 收藏` 使用 `TabBarView` 默认横向切页，和产品想要的“横向手势优先用于学习态切句”语义冲突；逐句精听则只有底部上下句按钮，没有对应的左右滑动切句入口。现统一调整为：Free Player 只允许点击 tab 切换，逐句精听支持左右 swipe 切换句子。

- [x] `player_screen.dart`：`TabBarView` 显式禁用横向 swipe，仅保留点击 `TabBar` 切换。
- [x] `intensive_listen_player_screen.dart`：在主体内容区新增横向手势，左滑下一句、右滑上一句，并补边界防越界处理。
- [x] 测试：`player_screen_test.dart` 增加“横向滑动不会切 tab”回归；`intensive_listen_player_screen_test.dart` 增加左右滑动切句与首句防越界回归。

  **完成时间**: 2026-06-22 22:09:26 +0800

## 已完成：学习版通知提示收敛到逐句精听完成

此前“开启通知提醒”的学习版 pre-prompt 同时挂在逐句精听、跟读、盲听、难句补练、复述多个完成页上；任务顺序调整后，用户可能在错误的任务完成点看到提示。现收敛为只在逐句精听完成后直接弹出，其它任务完成页不再主动弹学习版通知提示。

- [x] `intensive_listen_player_screen.dart`：保留逐句精听完成后的学习版通知提示，并补充注释说明当前触发语义。
- [x] `blind_listen_player_screen.dart` / `listen_and_repeat_player_screen.dart` / `review_difficult_practice_screen.dart` / `retell_player_screen.dart`：移除完成页里的学习版通知提示调用与对应 import。
- [x] 测试：补充 5 个页面回归，覆盖“逐句精听完成后仍会检查并弹提示”“盲听/跟读/难句补练/复述完成后不再检查学习版通知提示”。

  **完成时间**: 2026-06-22 21:24:29 +0800

## 已完成：任务引导页与设置弹窗设置项横向对齐统一

逐句精听、跟读、复习、盲听、复述等任务引导页与设置弹窗此前各自手写 `Row + Text + Dropdown/Text`，导致标签列宽、右侧值区宽度和左右边距视觉上不一致。现统一抽出公共设置项横向布局骨架，只修对齐，不改业务逻辑和控件语义。

- [x] `setting_labeled_row.dart`：新增公共“左标签 + 右侧固定宽度值区”布局组件，统一设置项横向对齐约束。
- [x] `intensive_listen_briefing_sheet.dart` / `listen_and_repeat_briefing_sheet.dart` / `review_briefing_sheet.dart` / `paragraph_selection_sheet.dart`：入口引导弹窗里的下拉设置行统一切到公共骨架，并补测试 key。
- [x] `intensive_listen_settings_sheet.dart` / `listen_and_repeat_settings_sheet.dart` / `blind_listen_settings_sheet.dart` / `retell_settings_sheet.dart`：播放速度标题行统一切到公共骨架，收敛标签列和值区对齐。
- [x] 测试：新增 briefing/settings 相关 widget 回归，覆盖标签列左边界一致、右侧值区宽度一致，防止后续布局回退。

  **完成时间**: 2026-06-22 19:39:05 +0800

## 已完成：统一播放速度档位到 0.1 步进

此前 Free Player、各学习模式入口和设置面板仍混用 `0.75 / 0.85 / 0.95 / 1.25 / 1.75` 等旧档位，默认值映射与显示格式也不一致。现统一为 `0.4-1.5` 按 `0.1` 递增，另保留 `2.0`；所有速度文案统一显示一位小数，默认值映射中的旧档位同步上调到最近的 `0.1` 档。

- [x] `playback_speed.dart` + `playback_settings.dart`：新增统一速度档位、格式化和归一化工具；Free Player 速度档位与旧值兼容读取统一走同一套逻辑。
- [x] `intensive_listen_settings.dart` / `difficult_practice_settings.dart` / `blind_listen_settings.dart` / `retell_settings.dart` / `playback_speed_default.dart`：练习入口离散档位和默认速度映射统一到新规则，旧 `0.75 / 0.85 / 0.95` 默认值分别改为 `0.8 / 0.9 / 1.0`。
- [x] `playback_controls.dart`、各 briefing sheet、各 settings sheet、各练习页状态标签：速度显示统一为 `1.0x` / `2.0x`，并将设置面板滑块从 `0.05x` 连续步进改为统一离散档位。
- [x] 测试：更新模型、provider、briefing、settings、screen 相关回归，覆盖新档位列表、默认值映射、旧值归一化和 `1.0x / 2.0x` 文案。

  **完成时间**: 2026-06-22 18:19:35 +0800

## 已完成：所有练习页循环次数支持无限 ∞

此前只有 Free Player 的循环模型支持 `0 = ∞`，学习模式各页仍把重复次数写死为有限值，导致逐句精听、跟读、难句补练、收藏复习、盲听、复述都无法设置无限重复。现统一把所有重复次数语义扩展为 `0 = ∞`，并补齐设置 UI、流程引擎和遍数文案。

- [x] `intensive_listen_settings.dart` / `difficult_practice_settings.dart` / `blind_listen_settings.dart` / `retell_settings.dart`：重复次数统一支持 `0 = ∞`，并补齐对应防御性解析。
- [x] `intensive_listen_settings_sheet.dart` / `listen_and_repeat_settings_sheet.dart` / `difficult_practice_settings_sheet.dart` / `blind_listen_settings_sheet.dart` / `retell_settings_sheet.dart`：重复次数下拉统一补上 `∞` 选项。
- [x] `sentence_playback_engine.dart` / `blind_listen_player_provider.dart` / `retell_player_provider.dart` / `blind_practice_flow_state.dart` / `repeat_flow_state.dart`：流程状态与推进逻辑兼容无限重复，不再错误判定“最后一遍”。
- [x] `practice_play_count_label.dart` 及相关页面：自动模式遍数文案统一支持 `第 n/∞ 遍` / `Round n/∞`。
- [x] 测试：更新模型、设置面板、跟读 controller、盲听 provider、复述 provider 相关回归，覆盖 `0 = ∞` 解析、UI 展示和无限重复不自动完成。

  **完成时间**: 2026-06-22 15:33:09 +0800

## 已完成：Free Player 整数倍速文案精确显示

速度菜单和底部速度按钮此前会把整数倍速统一显示成 `1x` / `2x`，与产品预期不一致。现将整数倍速统一保留一位小数，确保默认档位和菜单选项显示为 `1.0x`、`2.0x`。

- [x] `playback_controls.dart`：速度文案格式化改为整数倍速统一保留一位小数，显示为 `1.0x`、`2.0x`。
- [x] `playback_controls_test.dart`：更新默认速度按钮和速度菜单断言，覆盖 `1.0x`、`2.0x` 文案。

  **完成时间**: 2026-06-22 11:15:24 +0800

## 已完成：弹出菜单样式收敛（更宽更轻 + 危险区分隔）

音频 item / 合集 / 排序类弹出菜单此前统一成了白底描边卡片，但内容比例仍偏重：菜单整体狭长、边框存在感过强、图标和文字都太黑太粗，末尾删除项也缺少独立危险区。现将统一菜单骨架收敛为更克制的悬浮卡片和更紧凑的条目节奏，并在删除/退订前加入分隔，减少“长白条清单感”。

- [x] `app_popup_menu.dart`：新增统一 `appPopupMenuItem()`，把菜单项高度收紧到 44；菜单行加最小宽度、固定图标列、较轻图标色和较低字重，稳定左右节奏。
- [x] `app_theme.dart`：`popupMenuTheme` 改为更大圆角、更弱描边、更轻阴影，减少外框抢眼感，主要靠阴影和圆角建立层级。
- [x] `audio_list_tile.dart` / `collection_screen.dart`：切到统一菜单项封装，并在删除 / 退订 / 移除前插入 `PopupMenuDivider`，把末尾危险操作单独分区。
- [x] `audio_list_view.dart` / `recycle_bin_sheet_base.dart` / `learned_word_forms_sheet.dart`：排序类菜单同步切到更紧凑的统一条目高度，保持菜单系统一致。
- [x] 测试：`audio_list_tile_test.dart` / `collection_screen_test.dart` 增加危险区分隔断言，验证菜单结构未回退。

  **完成时间**: 2026-06-22 10:54:15 +0800

## 已完成：Free Player 播放速度选项补齐

Free Player 原先只有 7 个离散倍速档位，和参考播放器不一致，细粒度慢速训练选择不够。现将速度菜单补齐为 12 档，并统一显示格式，整数档位不再显示多余的小数位。

- [x] `playback_controls.dart`：播放速度菜单从 `0.5 / 0.75 / 1 / 1.25 / 1.5 / 1.75 / 2` 调整为 `0.5 / 0.7 / 0.75 / 0.8 / 0.85 / 0.9 / 0.95 / 1 / 1.1 / 1.3 / 1.5 / 2`；新增统一速度文案格式化，显示为 `1x` / `2x` 而非 `1.0x` / `2.0x`。
- [x] `playback_controls_test.dart`：更新默认按钮文案断言，并补齐完整速度菜单选项覆盖。
- [x] 验证：`flutter analyze lib/widgets/playback_controls.dart test/widgets/playback_controls_test.dart` 通过；`flutter test test/widgets/playback_controls_test.dart` 16 passed。

  **完成时间**: 2026-06-22 10:49:16 +0800

## 已完成：Free Player 进度条 seek 抖动修复（收藏 tab / 全文 tab）

收藏 tab 在播放中点击进度条时，旧流程会先 `clearClip()` 再重启句子驱动播放，导致进度条短暂回到音频 0 点；全文 tab 在 seek 过程中也会偶发先跳到前后错误位置再归位。现改为：收藏 tab 播放中直接切到目标句并重新起播，同时在进度条 UI 增加短暂的 seek 预览，屏蔽底层引擎中间态带来的圆点抖动。

- [x] `listening_practice_provider.dart`：`seekAbsolute()` 增加播放中句子驱动分支，跳过 `clearClip()` / 中间 seek，直接 `_startCurrent()` 重起目标句。
- [x] `player_screen.dart`：进度条 `onSeek` 增加短暂的目标位置预览，seek 完成前优先显示用户点击位置，避免全文 tab 圆点偶发前后跳动。
- [x] `free_player_playback_flow_test.dart`：新增回归测试，覆盖收藏 tab 播放中点击进度条不再先清空 clip。
- [x] 验证：`flutter analyze lib/screens/player_screen.dart lib/providers/listening_practice/listening_practice_provider.dart test/providers/listening_practice/free_player_playback_flow_test.dart test/screens/player_screen_test.dart` 通过；`flutter test test/providers/listening_practice/free_player_playback_flow_test.dart test/screens/player_screen_test.dart` 32 passed。

  **完成时间**: 2026-06-22 08:55:41 +0800

## 已完成：学习计划页 Free Player 入口显眼度优化

学习计划页右上角的「自由练习」原本只是普通 `TextButton.icon`，在标题区视觉权重偏低，用户容易忽略。现改为更克制但更醒目的紧凑工具入口：提高底色对比、边框存在感和浮起感，在不明显挤压标题的前提下提高可发现性。

- [x] `learning_plan_screen.dart`：将 AppBar 右上角入口替换为自定义 `_FreePlayAppBarButton`；使用更强的主色容器底、轻描边、轻量耳机图标和加粗文案强化视觉层级，并保持移动端紧凑宽度。
- [x] `learning_plan_screen_test.dart`：新增回归测试，覆盖入口渲染与点击后进入 Player 路由。
- [x] 验证：`flutter analyze lib/screens/learning_plan_screen.dart test/screens/learning_plan_screen_test.dart` 通过；`flutter test test/screens/learning_plan_screen_test.dart` 42 passed。

  **完成时间**: 2026-06-22

## 已完成：Free Player 睡眠定时器入口改为低干扰倒计时

自由播放器右上角睡眠定时器此前激活后仍只显示图标，真正的剩余时间放在浮层里大字号展示，信息层级过重且抢占浮层注意力。现改为：激活后 AppBar 入口直接显示一个低存在感倒计时胶囊，浮层只保留标题、关闭操作和预设列表，当前档位稳定打勾，不再靠剩余时间近似推断。

- [x] `sleep_timer_state.dart`：新增 `presetMinutes` 运行态字段，显式保存当前预设档位，避免 UI 用剩余时间反推选中项。
- [x] `sleep_timer_provider.dart`：`start()` 写入预设分钟数，tick 期间仅刷新 `remaining` 并保留当前档位，到点/取消时统一清空。
- [x] `sleep_timer.dart`：未激活保持弱化 `timer_outlined`；激活改为小号 `mm:ss` 轻量胶囊（弱底色 + 细描边 + tabular figures）；浮层删除大号倒计时区块，仅保留“关闭定时”和预设项。
- [x] 测试：更新 provider / widget 回归，覆盖激活态胶囊显示、浮层去掉大号剩余时间、运行一段时间后当前档位仍正确打勾。

  **完成时间**: 2026-06-22

## 已完成：共享句子列表收藏图标视觉收敛

右侧收藏按钮已改成更接近原句子 item 的轻量标记：已收藏保持小号 amber 书签，未收藏态进一步弱化，减少对句子正文的注意力抢占。

- [x] `masked_sentence_tile.dart`：收藏图标缩到 14px，保持与原句子 item 一致的轻量标记风格；未收藏态使用更弱化的 `onSurfaceVariant` 半透明色。
- [x] 验证：`flutter analyze lib/widgets/common/masked_sentence_tile.dart lib/widgets/common/paragraph_sentence_list_card.dart test/widgets/masked_sentence_tile_test.dart test/screens/player_screen_test.dart test/screens/blind_listen_player_screen_test.dart test/screens/retell_player_screen_test.dart` 通过；`flutter test test/widgets/masked_sentence_tile_test.dart` 通过（12 passed）。

  **完成时间**: 2026-06-22

## 已完成：共享句子列表改为三段式收藏交互

共享句子列表组件 `ParagraphSentenceListCard` / `MaskedSentenceTile` 之前只有两段式交互：左侧编号区负责播放，右侧整块主体区进入讲解页，收藏/取消收藏只能进讲解页后再做。现改为三段式共享布局，供 Free Player、全文盲听、段落复述共用：左侧编号区继续从该句播放，中间文本区保留进入讲解页，右侧新增独立收藏按钮，支持直接收藏/取消收藏。

- [x] `masked_sentence_tile.dart`：布局改为左播 / 中间文本 / 右侧收藏三段式；新增右侧收藏点击区、测试 key、tooltip / semantics，正文区不再混入只读书签图标。
- [x] `paragraph_sentence_list_card.dart`：新增句子级 `onSentenceBookmarkToggle` 回调并透传给共享 tile，保持自动跟随、初次定位、guide step 逻辑不变。
- [x] `player_screen.dart`：全文 Tab 和收藏 Tab 接入列表右侧收藏切换；中间文本进讲解页行为保持不变。
- [x] `blind_listen_player_provider.dart` / `blind_listen_player_screen.dart`：补齐盲听 provider 的 `toggleBookmark` 能力，并把列表右侧按钮接到 provider。
- [x] `retell_player_screen.dart`：接入复述列表右侧收藏切换。
- [x] 测试：更新 `masked_sentence_tile_test.dart`，新增 Player / 盲听 / 复述页面对右侧收藏按钮的回归测试。
- [x] 验证：`flutter analyze` 相关文件通过；`flutter test test/widgets/masked_sentence_tile_test.dart test/screens/player_screen_test.dart test/screens/blind_listen_player_screen_test.dart test/screens/retell_player_screen_test.dart` 全部通过（58 passed）。

  **完成时间**: 2026-06-21

## 已完成：Free Player 收藏 Tab 默认单句循环

Free Player 的收藏句通常不是连续上下文，若按普通连续播放直接跳到下一条，听感会比较硬。现将收藏 tab 的默认循环语义统一为：默认开启单句循环，重复 1 次，间隔 1 秒；用“逐句停顿”替代“连续硬切”。全文 tab 保持原默认不变。

- [x] `playback_settings.dart`：新增收藏 tab 默认循环常量/辅助函数，统一表达“单句循环开 + 1 次 + 1 秒”。
- [x] `listening_practice_state.dart` / `storage_service.dart`：收藏 tab 默认设置、旧单份 schema 升级、双设置读取统一收敛到新的收藏默认循环语义。
- [x] `listening_practice_provider.dart`：加载新音频时，全文 tab 仍重置为“不循环”，收藏 tab 恢复默认单句循环，确保难句跳播不连续硬切。
- [x] 测试：更新 model / storage / provider / widget 回归，覆盖收藏默认设置、旧 schema 迁移、切到收藏 tab 生效、加载新音频后恢复默认循环。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`flutter test` 目标测试 86 passed。

  **完成时间**: 2026-06-21

## 已完成：Free Player 播放结束后重播语义统一

Free Player 在非循环模式下播到末尾后，之前会停在结尾，但用户再次点击主播放按钮时会从**最后一句**重新开始，全文 Tab 和收藏 Tab 都不符合播放器常见语义。现统一为：两个 Tab 都在播放结束后保留结尾态；用户再次点击主播放按钮时，从**当前 Tab 对应播放列表的开头**重新开始。整篇循环开启时保持自动回卷不变。

- [x] `listening_practice_provider.dart`：新增“当前播放列表已自然播完、等待从列表开头重播”的 provider 内部状态；全文 gapless 和收藏/单句 clip 两条自然结束路径统一置位；主播放按钮在该状态下改为从当前列表第 1 句启动，而不是从最后一句启动；手动 seek / 切句 / 切 Tab / 对齐当前位置等操作会清除结束态。
- [x] `free_player_playback_flow_test.dart`：新增“全文非循环播完后再播从第 1 句开始”“收藏非循环播完后再播从收藏列表第 1 句开始”两个回归场景。
- [x] 验证：`flutter analyze lib/providers/listening_practice/listening_practice_provider.dart test/providers/listening_practice/free_player_playback_flow_test.dart` 通过；`flutter test test/providers/listening_practice/free_player_playback_flow_test.dart` 12 passed。

  **完成时间**: 2026-06-21

## 已完成：Free Player 全文 / 收藏 Tab 设置解耦

Free Player 之前只有一份全局 `PlaybackSettings`，导致全文 Tab 和收藏 Tab 共用倍速、字幕显隐、单句模式和循环设置；这与两种模式的训练语义不一致：全文是连续播放，收藏是难句跳播，用户在一边调出的设置会污染另一边。现改为按 Tab 维护两套完全独立的设置，并兼容旧版单份持久化数据自动迁移。

- [x] `listening_practice_state.dart`：新增 `fullSettings` / `bookmarkSettings` 两份状态，保留 `settings` 作为“当前激活 Tab 生效设置”的派生入口，兼容既有调用方。
- [x] `storage_service.dart`：`playback_settings` 持久化升级为双配置结构；兼容旧 schema，首次读取旧单份设置时复制为全文 / 收藏两份初始值。
- [x] `listening_practice_provider.dart`：`loadSettings` / `updateSettings` / `setPlaylistMode` / `loadAudio` 改为读写两份设置；切 Tab 时立即应用目标 Tab 的倍速并停止上一个 Tab 播放，不自动续播；加载新音频时分别重置两边的循环开关。
- [x] `player_screen.dart`：全文列表/收藏列表/单句视图按各自 Tab 的设置渲染，不再错误读取当前激活 Tab 的显示状态。
- [x] 测试：新增 state / storage / provider / widget 回归，覆盖“双设置独立持久化”“旧 schema 迁移”“切 Tab 应用目标设置”“收藏设置不串改全文”。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`flutter test` 目标测试 56 passed。

  **完成时间**: 2026-06-21

## 已完成：修复 Free Player 单句循环开关误改播放状态

单句循环开关此前会在播放中直接触发 `gapless ↔ clip` 驱动模型切换，导致当前句突然回到开头；在暂停态切换时，也可能因为复用同一条重启路径而意外恢复播放。修复目标是把“切换设置”和“切换当前播放任务模型”解耦：开关切换本身不改变播放/暂停态，不立刻跳句首；若播放中打开单句循环，则当前句先自然播完，再从**当前句句首**进入循环。整篇循环行为保持不变。

- [x] `listening_practice_provider.dart`：拆分“当前实际播放模型”与“设置期望模型”，新增延迟交接标记；播放中开启单句循环时，当前句继续自然播放，播完后从当前句句首切到 clip；播放中关闭单句循环时，当前 clip 播完后切回 gapless；暂停态切换仅更新设置，不触发 `play/seek/newSession`。
- [x] `free_player_playback_flow_test.dart`：新增 3 个回归场景，覆盖“播放中开启不跳句首”“暂停开启不自动播”“播放中关闭后当前 clip 播完再回 gapless”。
- [x] 验证：`flutter analyze lib/providers/listening_practice/listening_practice_provider.dart test/providers/listening_practice/free_player_playback_flow_test.dart` 通过；`flutter test test/providers/listening_practice/free_player_playback_flow_test.dart` 10 passed；`flutter test test/providers/listening_practice/session_guard_test.dart` 6 passed（有既存测试日志告警，但不影响通过）。

  **完成时间**: 2026-06-21

## 已完成：Free Player 播放架构重构（分模式播放，修复单句/整篇循环）

Free Player 的单句循环和整篇循环在全 gapless + positionStream 边界监听模型下容易受采样 overshoot、末句完成事件、收藏非连续句和静音间隙影响，无法稳定复现 v1.0.17 的循环行为。本次改为按播放目标选择模型：普通全文播放继续 gapless，保留整段进度条任意 seek；单句循环和收藏跳播回到句级 clip 驱动，由 clip completed 明确推进，避免用 positionStream 猜句尾。

- [x] `listening_practice_provider.dart`：删除 `_watchBoundaries`/`_watchEndTime`/边界监听推进路径，新增播放任务 generation、句级 clip 播放协程和 gapless 整篇完成处理；单句循环/收藏模式忽略 positionStream 高亮推进，避免双推进。
- [x] `audio_engine_provider.dart`：恢复共享句级播放基元 `playClipWithLoops`，新增 `absoluteCurrentPosition`，确保 clip 模式保存断点时写入绝对时间而非 clip 相对位置。
- [x] `playback_state_storage.dart`：保存接口改为接收绝对 `Duration`，消除对 `AudioPlayer.position` 的 clip 相对时间依赖。
- [x] `free_player_playback_flow_test.dart`：新增复杂字幕场景（不等长句、句间静音、边界相邻、非连续收藏、尾句贴近音频尾部），覆盖普通 gapless、有限/无限单句循环、收藏跳播、seek 后重置计数、手动切句、双循环同开。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`flutter test test/providers/listening_practice` 全 66 passed；`player_screen_test` / `playback_controls_test` / `settings_dialog_test` / `loop_reset_on_load_test` 相关组合全 passed。

  **完成时间**: 2026-06-18

## 已完成：修复 CI widget test 失败（句子列表点击与字幕弹窗语言选择）

GitHub Actions `test` job 失败于 3 个 widget test：Free Player 句子列表两个点击测试点到了不可命中的文本/Tile 中心区域；管理字幕弹窗测试假设默认语言为 auto，但当前默认语言是 en，导致找不到可点击的 `Start Transcription` 按钮。

- [x] `masked_sentence_tile.dart`：给句子编号点击区和主体点击区增加 `@visibleForTesting` key 前缀，测试可精准点击真实交互热区，不依赖内部文本布局。
- [x] `player_screen_test.dart`：等待初次定位淡入完成后，改用点击区 key 分别测试“编号区播放”和“主体区进讲解页”。
- [x] `manage_subtitles_sheet_test.dart`：测试中显式从 English 切换到 Auto Detect，再断言 AI(en) 已转录场景下可重新发起 auto 转录。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`player_screen_test.dart` 15 passed；`manage_subtitles_sheet_test.dart` 12 passed。

  **完成时间**: 2026-06-18

## 已完成：Free Player 句子列表初次定位「直接显示在中间」（去除多余滚动）

Free Player 句子列表在「首次进入」和「收藏 Tab 切回全文 Tab」时，当前句会从顶部滚到中部——不符合业界标准（初次定位应直接显示在中间，不发生滚动）。根因：`ParagraphSentenceListCard` 的初次定位与播放跟随共用「jumpTo 顶部 → scrollTo 居中」路径，无论动画快慢，用户都会看到目标句从顶部移动到中部。

业界标准做法（避免踩坑）：在「列表不可见」时完成滚动定位，居中后再淡入，用户全程看不到滚动。关键约束：必须保持底层 `anchor=0`——`ScrollablePositionedList` 的 `initialAlignment=0.5` 会把 anchor 永久设为 0.5、破坏既有「anchor=0 + ClampingScrollPhysics 硬停」的到头/尾防回弹设计（实测 `不越界` 回归测试失败）。

- [x] `widgets/common/paragraph_sentence_list_card.dart`：`initState` 用 `initialScrollIndex` 首帧把当前句渲染在顶部（anchor 仍为 0）；新增 `_centerInitialFocus`（jumpTo→scrollTo 两阶段瞬时居中，保持 anchor 0）；`build` 外层包 `AnimatedOpacity`（`_initialFocusDone` 前 opacity=0 隐藏、完成后 120ms 淡入）；`_focusPlayingSentence` 恢复原状仅负责播放中逐句跟随；新增 `@visibleForTesting kParagraphListInitialFocusKey`。
- [x] `paragraph_sentence_list_card_test.dart`：新增「居中完成前隐藏、完成后淡入且已居中」回归测试；现有「末句贴底/首句贴顶/中部居中/不越界防回弹」4 测试不变。
- [x] 验证：`flutter analyze` 改动文件 No issues；`flutter test paragraph_sentence_list_card_test.dart`：10 passed；`test/screens test/widgets` 仅 2 个 pre-existing 失败（`player_screen_test` 交互用例，baseline 同样失败，与本改动无关）。

  **完成时间**: 2026-06-18

## 已完成：更换内置 Examples 为 6 条 CEFR 示例音频

内置 Examples 从单条 `English in a Minute - On the Ball` 替换为 A1/A2/B1/B2/C1/C2 六条 CEFR 示例音频。安装器改为版本化幂等安装：全新空库安装 6 条新示例；已安装旧 bundled example 的用户启动后自动删除旧记录、旧音频文件和旧音频关联数据并迁移到 6 条新示例；已有用户库但没有旧 example 的环境不自动插入示例，避免污染既有库。示例继续保持无字幕策略，引导用户通过 AI 转录生成字幕；重复安装不会覆盖新示例已生成的字幕。

- [x] `bundled_example_installer.dart`：新增 v2 manifest（6 条固定 ID）和 `bundled_example_installed_version`；支持旧 `bundled-example-audio-0001` 迁移清理；显式清理旧音频的 collection/bookmark/progress/stage/playback/tag 关联与 saved word/sense group 冗余上下文；复制新 assets 并写入 `Examples` 合集。
- [x] `bundled_example_installer_test.dart`：覆盖空库安装、最新版跳过、版本标记丢失幂等（保留已生成字幕）、旧示例迁移（含关联表/上下文清理）、非空用户库不自动插入五个分支。
- [x] `native_audio_decoder_integration_test.dart`：demo asset 改为新的 `CEFR A1 - Book a table.m4a`，更新时长断言。
- [x] 验证：`flutter analyze lib/services/bundled_example_installer.dart test/services/bundled_example_installer_test.dart integration_test/native_audio_decoder_integration_test.dart`：No issues found；`flutter test test/services/bundled_example_installer_test.dart`：5 passed。

  **完成时间**: 2026-06-18

## 已完成：Free Player 睡眠定时器（定时停止）

自由播放器缺少听力/播客播放器的标准「定时停止」功能。在 AppBar 右上角新增 timer 图标按钮，点击在按钮下方弹出气泡浮层（复用「循环设置」浮层的视觉与交互骨架，箭头朝上）选择预设时长（5/10/15/30/45/60 分钟），到点自动**暂停**（可续播）。定时为**一次性**：不持久化、独立 provider、autoDispose 绑定页面生命周期，离开页面即取消、到点后清空、重进无激活态。墙钟倒计时（`clock.now()` + `Timer.periodic`，便于 fake_async 测试），防竞态用 generation token 作废旧计时。范围裁剪：不做「听完本条/当前句」自然结束选项、不做音量淡出、不做自定义分钟输入。

- [x] `models/sleep_timer_state.dart`：不可变运行态 `SleepTimerState{remaining}` + 预设档常量 `sleepTimerPresets`。
- [x] `providers/listening_practice/sleep_timer_provider.dart`：`@riverpod`(autoDispose) `SleepTimer`，`start/cancel/_tick`，到点 `ref.read(listeningPracticeProvider.notifier).pause()`；`ref.onDispose` 取消 ticker。
- [x] `widgets/sleep_timer.dart`：`SleepTimerButton`（AppBar，OverlayPortal 定位按钮下方）+ `_SleepTimerPopup`（未激活列 6 档；激活显剩余时间 + 关闭定时 + 当前档打勾）+ `_CaretUpPainter`（朝上箭头）。
- [x] `screens/player_screen.dart`：AppBar `actions: [SleepTimerButton()]`。
- [x] l10n：`app_en.arb`/`app_zh.arb` 新增 sleepTimer/sleepTimerMinutes/sleepTimerRemaining/sleepTimerOff/sleepTimerA11yActive。
- [x] 依赖：`pubspec.yaml` 直接引入 `clock`（墙钟可测）。
- [x] 测试：`sleep_timer_provider_test`（fake_async：剩余递减、到点暂停一次、重设替换、取消不触发、dispose 取消）5 例；`sleep_timer_test`（widget：6 档渲染、点选启动收起转激活、激活态剩余/关闭/打勾、点关闭恢复）3 例。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`flutter test` 全套 2874 例通过。
- [x] UI 打磨：图标加右边距；浮层收窄（240→144）；新增居中标题头 + 浅色分割线；选项字体收小（bodyLarge→bodyMedium）、行高/图标收紧；行内容统一居中、hover 高亮铺满整行。

  **完成时间**: 2026-06-18

## 已完成：Free Player 进度条重构（gapless + 边界监听，业界标准任意 seek）

Free Player 进度条两个 bug——①位置与句子有时不匹配、②只能按句子寻址不能任意位置——根因都在 **clip 播放形态**：单句循环/收藏 tab 下用 `just_audio.setClip` 把播放限制在当前句区间，导致整段进度条只在小区间内移动、拖动吸附句首重起播。彻底重构为**永不 setClip 的 gapless 播放 + positionStream 边界监听**：进度条始终是整段连续时间轴、可任意位置 seek；单句循环/收藏跳播/整篇循环改由「越过当前监听句尾」检测驱动（接受 ~200ms 标准 overshoot）。

- [x] `audio_engine_provider.dart`：新增 `pauseKeepSession()`（暂停但不递增 sessionId），供边界处理/任意 seek 续播同一 session。`setClip`/`playClipOnce`/`playRangeOnce` 保持不动（学习模式仍用）。
- [x] `sentence_tracker.dart`：`findSentenceIndexByPosition` 间隙归属由「下一句」改为「上一句」（尾部静音），修高亮在静音段提前跳。
- [x] `playback_reducer.dart`：`decideNext` 删除 `isClipMode`，语义改为「越过当前句尾后该做什么」；新增 public `shouldLoopWhole`（供 gapless 整段自然播完判定）。
- [x] `listening_practice_provider.dart`：删 `_isClipMode`/`_playPosition`/`_advanceAfterCompletion`/`_advancing`；`_isClipMode`→`_watchBoundaries`；新增 `_watchPos`/`_watchEndTime`/`_boundaryGen`/`_handlingBoundary` 与 `_maybeCrossBoundary`/`_advance`/`_resumeAt`/`_setWatch`/`_alignEngineToCurrent`；`_onPositionChanged` 拆「越界检测 + 高亮」；`seekAbsolute` 重写为任意 seek 从落点续播（收藏模式吸附最近收藏句）。
- [x] 测试：`playback_reducer_test` 删 isClipMode 用例、补 `shouldLoopWhole`；`sentence_tracker_test` 间隙归属改上一句 + 补 endTime 边界；`session_guard_test` 单句循环改 gapless 断言、新增「越过句尾位置流重播」「任意拖动从落点续播」；`fake_notifiers` 补 `pauseKeepSession`。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`flutter test` 全套 2866 例通过。

  **完成时间**: 2026-06-18

## 已完成：修复学习首页「待解锁」任务卡片误显"学习中"

待解锁任务（`reviewUpcoming`）本轮尚未解锁，按设计只应显示解锁倒计时，但 v2 计划的音频会误显"学习中"。根因：`study_screen.dart` 的 `_statusText` 用 `task.subStage != task.stage.allSubStages.first` 判定"学习中"，而 `allSubStages`（v1∪v2 展示并集）复习阶段首元素是盲听，v2 计划首步却是难句补练，导致刚进入新复习轮的待解锁任务被误判。改为基于真实完成历史（`stage_completions`），与 `learning_plan_screen` 的判定口径统一，且不依赖计划版本。

- [x] `study_task_provider.dart`：`StudyTask` 新增 `hasRoundProgress` 字段，`_buildTaskForAudio` 由 `completionsByAudio` 计算当前 stage 是否有 ≥1 完成记录（key 前缀带冒号，避免 `review1` 误匹配 `review14`）。
- [x] `study_screen.dart`：`_statusText` 改用 `task.hasRoundProgress` 判定"学习中"，弃用 `allSubStages.first` 比较。
- [x] 测试：`study_task_provider_test` 新增 `hasRoundProgress` group（待解锁无记录=false、有记录=true、跨阶段不误命中）；`study_screen_test` 新增待解锁卡片显示倒计时而非"学习中"用例。
- [x] 验证：`flutter analyze` 改动文件 0 issue；目标测试全绿。

  **完成时间**: 2026-06-18

## 已完成：Free Player 单句模式改为精听模式（复用 AnnotationContentView）

自由播放器的「单句模式」原本只是一张简单卡片（句子大字 + 序号 + 时间 + 收藏图标，隐藏字幕仅模糊句子文本），语义上其实就是「精听模式」。改为与「逐句精听」复用同一套解析 UI（`AnnotationContentView`：解析/翻译/意群工具栏 + 句子 + 翻译 + 解析 + 难句标记行）。与逐句精听唯一不同：自由播放器有「隐藏字幕」开关，隐藏时遮蔽**整个解析内容区**（含工具栏、句子、翻译、解析）且禁用点击。

- [x] `player_screen.dart`：重写 `_buildSingleSentenceView`，弃用旧卡片，改为「序号+时间 + `BookmarkToggleRow` 难句标记行 + `AnnotationContentView`（被遮罩 Stack 包裹）」，接入方式参照 `sentence_detail_screen.dart`；`onStopMainPlayer` 接 `controller.pause()` 让意群试听前停主播放；隐藏字幕遮罩复用原模糊视觉（`ImageFilter.blur(5,5)` + `onSurface` 0.05）外加 `IgnorePointer` 实现禁用。删除随之失效的整卡右键/长按上下文菜单（`_showContextMenu` + `text_context_menu` import）。
- [x] 测试：`player_screen_test` 新增「单句模式（精听）」group——验证渲染 `AnnotationContentView` + `BookmarkToggleRow`、隐藏字幕叠加遮罩/显示字幕无遮罩、点击标记行切换收藏。复用 `intensive_listen_player_screen_test` 的 AI/DAO/学习设置 override 套路避免真实网络/DB。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`player_screen_test` 全 15 例绿；`flutter test` 全套 2860 例通过。

  **完成时间**: 2026-06-18

## 已完成：Free Player Tab 激活态视觉优化

自由播放器顶部「全文 / 收藏」两个 tab 原激活态只靠蓝色文字 + 底部下划线，对比弱、用户不易察觉哪个 tab 激活。改为业界通用、与 Material 3 一致的 SegmentedButton 风格浅色药丸激活态。

- [x] `app_theme.dart`（`tabBarTheme`）：激活态改用 `indicator` 浅色药丸（`secondaryContainer` + 圆角 10）+ `indicatorSize: tab` 铺满；`dividerColor: transparent` 去掉底部下划线；`labelColor: onSecondaryContainer`、`unselectedLabelColor: onSurfaceVariant`；`splashBorderRadius` 与药丸圆角对齐。
- [x] `player_screen.dart`（`TabBar`）：新增 `indicatorPadding`（垂直 8 / 水平 4）让药丸四周留白、不顶满。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`player_screen_test` 全绿（纯样式属性调整，无需改测试）。

  **完成时间**: 2026-06-18

## 已完成：播放控制栏视觉优化

自由播放器底部控制栏的 UI 打磨，按用户多轮反馈逐项调整：

- [x] `player_screen.dart`：移动端底部状态栏也显示（原仅桌面端），居中于播放按钮下方且保留播放按钮原有下边距；状态栏顺序调整为「模式 · 倍速 · 整篇循环 · 单句循环」；整体弱化为低对比灰（`onSurface` 0.45），避免与控制按钮抢注意力。
- [x] `playback_controls.dart`：切换按钮激活态改用 MD3 tonal 风格（`primaryContainer` 浅色调底 + 主色图标），替代原蓝/灰图标（对比太弱、又不与主播放按钮抢焦点）；移动端切换按钮间距 4 → 12；倍速文字弱化（灰、w600）。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`playback_controls_test` / `player_screen_test` 全绿。

  **完成时间**: 2026-06-18

## 已完成：循环开关改为不全局持久化（随加载新音频重置）

自由播放器底部四个按钮原本全部全局持久化（SharedPreferences）。按业界惯例区分「偏好」与「意图」：播放速度 / 字幕显隐 / 单句视图属偏好，保持全局持久化；**循环开关是「现在想刷这条」的临时意图，不应被全局记忆**。改为：循环开关纯内存、不落任何盘，加载新音频时一律重置为关；循环参数（次数/间隔）仍作为全局偏好保留。已与用户确认采用「不持久化 / 永远忘记」方案，不改数据库 schema。

- [x] `playback_settings.dart`：`toJson` 移除 `loopWhole`/`loopSentence` 两个开关键（参数键照常写）；`fromJson` 新 schema 判据改按循环参数键识别（避免误入 legacy 迁移），开关一律还原为 `false`，仅恢复参数/速度/视图/字幕；旧字段（`repeatMode`/`loopEnabled`/`loopAudioEnabled`）的开关迁移逻辑去除，只保留旧 `loopCount`/`pauseInterval`→单句参数的迁移。
- [x] `listening_practice_provider.dart`：`loadAudio` 真正加载新音频路径上 `state.copyWith(settings: settings.copyWith(loopWhole:false, loopSentence:false))`，仅改内存、不持久化；同音频早返回则保持不变。
- [x] 测试：重写 `playback_settings_test` 往返/旧字段/范围校验三组断言（开关不往返、参数保留）；新增 `loop_reset_on_load_test`（内存 DB + 测试引擎，验证加载新音频重置开关、同音频早返回不重置）。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`playback_settings_test` / `listening_practice/` / `settings_dialog_test` / `playback_controls_test` 全绿。

  **完成时间**: 2026-06-18

## 已完成：循环设置浮层定位修复 + 布局优化

原浮层用 `CompositedTransformFollower` 右对齐到循环按钮（宽 300），向左溢出甚至超出屏幕左边缘。按用户参考样式改为**按钮正上方居中弹出、底部带向下箭头指向按钮**的气泡，并经 ui-ux agent 优化布局。

- [x] `playback_controls.dart`（`_LoopButton`）：弃用 `LayerLink`/`CompositedTransform*`，改为按钮加 `GlobalKey`，在 `overlayChildBuilder` 内读按钮相对 Overlay 的位置，用 `Positioned`（left/bottom/width）将浮层居中于按钮并**水平夹紧到屏幕内**（左右各留 16px），`caretX` = 按钮中心相对浮层左缘的偏移；`bottom` 锚定使浮层展开时向上生长、箭头始终贴按钮。
- [x] `settings_dialog.dart`（`LoopSettingsPopup`）：删除「循环设置」标题；宽度 300→280，新增 `width`/`caretX` 参数；卡片底部用 `_CaretPainter`（CustomPaint 等腰三角，宽 16 高 8）画向下箭头；区块间分隔改 1px `outlineVariant` Divider；主开关行图标/标题随开关变色（开 primary / 关 onSurfaceVariant）且整行 `InkWell` 可点；`_LabeledSliderRow` label 宽 84→64、单行省略、值列宽 40→44；间隔值用紧凑单位 `Ns`（label 去「（秒）」），无障碍朗读保留完整「N 秒」。
- [x] l10n：`intervalTime` 由「间隔时间（秒）」→「间隔」、「Interval (seconds)」→「Interval」。
- [x] 测试：更新 `settings_dialog_test`/`playback_controls_test`/`player_screen_test` 改用「Whole-text loop」判定浮层开启（标题已删），断言间隔 label「Interval」与值「3s」。`flutter analyze` 改动文件 0 issue；三套测试全绿。

  **完成时间**: 2026-06-18

## 已完成：循环设置弹窗（整篇 / 单句双循环独立可同时开启）

自由播放器原循环交互繁琐：循环图标是三态切换（关闭→整段→单句，**互斥**），重复次数/间隔藏在右上角 `Icons.tune` 弹窗且仅作用于单句循环。改为：点击循环图标直接弹出循环设置面板，「整篇循环」「单句循环」两个**独立、可同时开启**的开关，各带「重复次数」「间隔时长」滑块。右上角 tune 按钮删除。已与用户确认语义：整篇循环「重复次数 N」= 整篇**总共播放 N 遍**（∞=无限）。

- [x] `playback_settings.dart`：用六个新字段（`loopWhole`/`wholeLoopCount`/`wholeInterval` + `loopSentence`/`sentenceLoopCount`/`sentenceInterval`）**替换**单一 `repeatMode`/`loopCount`/`pauseInterval`；范围校验（次数 0=∞ 或 1-10，间隔 0-10s）；`fromJson` 兼容旧 schema 迁移（`one`→单句、`all`→整篇∞、`off`→双关，旧 `loopEnabled`/`loopAudioEnabled` 亦兼容）；删除已无消费方的 `PlaybackRepeatMode` 枚举与其 export。
- [x] `playback_reducer.dart`：`decideNext` 重写为接收 `isClipMode` + 双循环参数，覆盖 gapless（整篇完成）/clip（单句完成）两种事件语义；`ReplayCurrent`/`GoToPosition` 增加 `pauseBefore` 字段，让 reducer 直接给出该用单句还是整篇间隔（单一真相源）。
- [x] `listening_practice_provider.dart`：`_repeatsDone`→`_sentenceRepeatsDone` 并新增 `_wholeLoopsDone`（clip 模式仅在真正整篇回卷时 +1，避免 off-by-one）；`_isClipMode` 改为 `bookmarks || loopSentence`；`_advanceAfterCompletion` 走新 reducer；`_delayInterval(Duration)` 接收 reducer 决策的间隔；所有起播/seek 重置点同步归零两个计数。
- [x] UI：`playback_controls.dart` 循环图标改为点击弹出**悬浮浮层**（`_LoopButton` 用 `OverlayPortal` + `CompositedTransformFollower` 锚定到按钮上方、右对齐，透明遮罩点击外部关闭；任一循环开则高亮，仅单句开用 repeat_one）；`settings_dialog.dart` 重写为浮层 `LoopSettingsPopup`（两组自定义紧凑开关行 + `AnimatedSize` 展开「标签 + 滑条 + 值」**单行**滑块：重复次数 1-10/∞、间隔 0-10s，即时生效）；`player_screen.dart` 删除 tune 按钮与 `_showSettingsDialog`，状态徽标改为按 `loopWhole`/`loopSentence` 各自展示；l10n 新增 `wholeTextLoop`/`singleSentenceLoop`（复用 `loopSettings`/`repeatCount`/`intervalTime`/`times`/`seconds`）。
- [x] 测试：重写 `playback_reducer_test`（gapless/clip/两者同开全程 trace/边界，断言 `pauseBefore`）、`playback_settings_test`（六字段往返、范围截断、旧 schema 迁移）、`settings_dialog_test`（双开关展开滑块、∞ 文案、切换触发 updateSettings）、`playback_controls_test`（图标随循环态、点击开弹窗）、`player_screen_test`（移除 tune、循环按钮开弹窗）、`session_guard_test`（迁移到新字段）。

  **完成时间**: 2026-06-17

## 已完成：自由播放器（free player）播放架构重构

free player 的循环/跳句 bug（单句循环莫名跳第一句、讲解页试听返回后跳句）根源是架构问题：`ListeningPractice` 用**两套执行模型**（响应式 `_playContinuous` + 命令式 `while/for` 长协程 `_playSubtitleDriven`）驱动同一个共享 `AudioEngine`，由 `loopEnabled×loopCount×autoPlayNext×loopAudio` 四开关矩阵 + 被多处递增的 `sessionId` 协调，事件竞态导致索引乱跳。本次彻底重写为**单一事件驱动模型**，不打补丁。

- [x] 新增纯函数 `playback_reducer.dart`（`PlaybackRepeatMode{off,all,one}` + `decideNext`），把「一句播完后做什么」从协程剥离为可单测的无副作用决策；枚举名避开 Flutter material 的 `RepeatMode` 冲突。
- [x] `playback_settings.dart`：用单一 `repeatMode` **替换** `loopEnabled`/`loopAudioEnabled`/`loopAudio`；`fromJson` 一次性迁移旧字段；删除废弃字段及其 toJson/copyWith/校验。
- [x] 重写 `listening_practice_provider.dart`：删除 `_playContinuous`/`_playSubtitleDriven`/`_shouldUseContinuousMode`/`_audioLoopCount` 与 `play()` 的 `isResume` 启发式；改为「位置流推进高亮（gapless）+ 完成事件归约器 `_advanceAfterCompletion` 调 `decideNext`」；新增 `restorePosition()` 供讲解页返回显式对齐当前句；保留共享引擎必需的 `isActiveSession` 守卫并加注释。删除引擎中仅 LP 使用的死代码 `playClipWithLoops`。
- [x] UI：`playback_controls.dart` 单句开关改为三态循环按钮（关闭→整段循环→单句循环）；`settings_dialog.dart` 删除「音频循环」整块与「句子重复」开关，合并为单句循环参数（重复次数/间隔）；`player_screen.dart` 讲解页返回调用 `restorePosition()`，InfoBar 按 `repeatMode` 展示；清理孤立 l10n 键。
- [x] 交互简化（用户反馈）：删除费解的「自动播放下一句」开关，把「单句循环是无限重复还是重复 N 次后前进」折叠进**重复次数**——`loopCount=0` 即「∞」无限重复当前句，有限次数则重复够后自动进下一句。`autoPlayNextSentenceEnabled` 字段一并删除。
- [x] 测试：新增 `playback_reducer_test.dart`（13 用例覆盖 decideNext 全分支）；重写 `session_guard_test.dart`（单句循环不跳第一句、讲解页返回 `restorePosition` 对齐当前句、gapless 位置推进、外来 session 隔离）；更新 `playback_settings_test`/`settings_dialog_test`/`playback_controls_test`/`player_screen_test`。`flutter analyze` lib 0 issue；全量 2841 单元/组件测试通过。（macOS integration_test 因环境「Unable to start the app on the device」启动失败，与本改动无关。）

  **完成时间**: 2026-06-17

## 已完成：修复自由播放器看完句子讲解返回后主播放按钮跳回第一句

free player 点句子进讲解页 → 试听单句 → 返回 → 点主播放按钮，结果从第一句重播。根因：讲解页与 free player 共享同一个 `AudioEngine`，讲解页旁路驱动它（`playRangeOnce`，`newSession()` 顶掉 LP 的 session、改写 clip/position），污染了「外部播放器」状态。两处泄漏：①LP 的位置/状态监听器不校验 session，`_updateCurrentSentence` 把 `currentFullIndex` 改成被试听的句子；②`play()` 的 `isResume` 仅看引擎当前 position，会从讲解页留下的（被污染）位置续播。盲听播放器本就有 `isActiveSession` 守卫且 resume 永远按断点句重新 seek（`blind_listen_player_provider.dart`），free player 缺失——本次按同款思路补齐。

- [x] `audio_engine_provider.dart`：新增 `currentSessionId` getter。
- [x] `listening_practice_provider.dart`：新增 `_playbackSessionId` 字段，`_playContinuous`/`_playSubtitleDriven` 的 `newSession()` 后记录、`pause()` 后记录引擎当前 session（使「普通暂停→续播」仍归 LP 所有）；`_updateCurrentSentence`/`_handlePlaybackCompleted` 加 `isActiveSession(_playbackSessionId)` 守卫；`play()` 的 `isResume` 增加 `isActiveSession(_playbackSessionId)` 前置——被外来 session 驱动过就不续播引擎位置，改按 `currentFullIndex` 重新定位。
- [x] 测试：新增 `test/providers/listening_practice/session_guard_test.dart`（外来 session 位置事件不改 `currentFullIndex`、外来 session 后 `play()` 按 `currentFullIndex` 重新 seek、LP 自身 session 正常推进高亮）。`flutter analyze` 改动文件 0 issue；provider + player_screen 共 609 测试全绿。

  **完成时间**: 2026-06-17

## 已完成：自由练习全能播放器复用盲听句子列表组件

自由练习「全能播放器」(`PlayerScreen`) 原用自有 `SentenceListView`（整条点击=播放、右侧书签切换按钮、显示时间范围）。改为复用全文盲听的共享组件 `ParagraphSentenceListCard`/`MaskedSentenceTile`，统一交互：点击左侧编号区从该句继续播放、点击句子主体进讲解页、内置「尊重用户手动滚动」的自动跟随。约束：仅共享句子列表组件，不共享 provider/controller，不给共享组件加新职责。

- [x] `player_screen.dart`：`_buildFullTextTab`/`_buildBookmarkedTab` 用 `ParagraphSentenceListCard` 替换 `SentenceListView`。全文 tab `playingSentenceIndex=currentFullIndex`（列表位置==index）；收藏 tab 把 `currentBookmarkIndex` 换算成收藏子集本地位置。`displayMode` 由 `settings.showTranscript` 映射 showAll/hideAll。`autoFocusEnabled=autoScrollEnabled`。
- [x] `player_screen.dart`：新增 `_handleSentenceDetail`（仿盲听、本页持有不共享）——`_isNavigatingToDetail` 防重入 → `pause()` → `context.push(AppRoutes.sentenceDetail, extra: SentenceDetailArgs(...))` → 返回后 `syncBookmarks()` 刷新收藏标记与「收藏(n)」计数。移除原 `onUserScroll→setAutoScroll(false)` 桥接（共享组件自管理）。删除 `_buildSingleSentenceView` 中遗留未用的 `l10n`。
- [x] 删除死代码 `lib/widgets/sentence_list_view.dart` 及 `test/widgets/sentence_list_view_test.dart`（仅 PlayerScreen 引用）。
- [x] 行为变化：列表内不再有内联书签切换（收藏改到讲解页完成）、不再显示时间范围、不再支持长按文本选择菜单（单句模式视图仍保留自带菜单）。
- [x] 测试：`test/helpers/test_app.dart` 加 `/sentence-detail` stub 路由；重写 `player_screen_test.dart` 列表渲染断言（改查共享组件类型）、`play_arrow` 断言限定在 `PlaybackControls` 内（当前播放句编号区也渲染 ▶）；新增「点击编号区从该句播放」「点击主体进讲解页」两个交互用例。`flutter analyze` 改动文件 0 issue。

  **完成时间**: 2026-06-17

## 已完成：修复未开始音频仍显示旧版首次学习流程（盲听优先）

v33→v34 迁移把所有存量 audio 的 firstLearn 一律锁 v1。v2（盲听后置）上线后，一个**在旧版打开过学习计划页、被建了进度行但从未真正开始学习**的音频被永久锁在 v1 顺序（全文盲听排第一）。新增一次性迁移直接清空这类进度行——删除后无进度行 → plan 回退 `kLatestPlanVersions`（firstLearn=2）→ 显示新版流程；重新打开时 `ensureProgress` 建全新 v2 进度。

- [x] `app_database.dart`：`currentSchemaVersion` 41→42；新增 `_clearUnstartedV1FirstLearnProgress()`——删除 `current_stage='firstLearn' AND current_sub_stage='blindListen' AND plan firstLearn==1` 的进度行。**安全点**：v2 第 3 步同样是 firstLearn:blindListen，必须校验 json `firstLearn==1` 只删 v1，绝不误删进行中的 v2。迁移块置于 `onUpgrade` 末尾（依赖 v34 块创建的 plan_versions_json 列，迁移块按源码顺序执行）。
- [x] 测试：新增 `test/database/v42_migration_test.dart`（5 类 fixture：v1 盲听首步删 / 盲听过几遍仍删 / v1 已前进到精听保留 / v1 已进入 review 保留 / v2 第 3 步保留）；更新 `v33_to_v34_migration_test`（链式迁移到 head 后 audio-fresh 被 v42 清理，review 版本判定改用 audio-only-firstlearn）。全量 2836 测试通过，`flutter analyze` 改动文件 0 issue。

  **完成时间**: 2026-06-17

## 已完成：难度实时化 —— 按当前难句书签数重算，驱动各入口默认速度

原难度在精听完成时一次性按难句比例判定并冻结落库，后续步骤/复习只读这个冻结值。导致用户练熟后取消难句收藏（如 9 句只剩 1 句难句）时，难句跟读等入口仍按历史 veryHard 显示 0.75x。改为「每次进入练习入口时按当前难句书签数实时重算难度并静默回写」：难句比例下降 → 难度降低 → 默认播放速度随之回升，不再被历史难度绑定。

- [x] `learning_progress_provider.dart`：新增 `refreshDifficultyFromBookmarks(audioItemId, totalSentences)`——查 bookmarkDao 当前难句数 → `difficultyFromDifficultRatio` 重算 → 静默落库（不发埋点，区别于用户显式 `setDifficulty`）；难度无变化跳过写库；`totalSentences<=0`（字幕未加载）不重算，避免误清成 veryEasy；无 progress 返回 medium。
- [x] `learning_plan_screen.dart`：各练习入口在弹引导前调用 `refreshDifficultyFromBookmarks`，用返回的实时难度算 `defaultPlaybackSpeedFor` / `KeywordRatio` / 跟读 `playCount`。覆盖：难句跟读、段落复述、复习盲听、复习难句补练、复习段落复述，及对应自由练习路径。
- [x] `learning_plan_screen.dart`：首学全文盲听（第三步）`_startBlindListen` 原本未传 `defaultPlaybackSpeed`（恒 1x），补为按 firstLearn 阶段的实时难度速度，与难句跟读/复述一致。
- [x] `fake_notifiers.dart`：`FakeLearningProgressNotifier` 覆盖 `refreshDifficultyFromBookmarks` 为纯内存返回现有难度（测试不接 bookmarkDao）。
- [x] 测试：`learning_progress_provider_test` 新增 `refreshDifficultyFromBookmarks` group（1/9→medium、0→veryEasy、4/9→veryHard、无变化跳过写库、totalSentences=0 不重算、无 progress 返回 medium）；修正 `blind_listen_briefing_sheet_test` 过期文案断言。全量测试通过，`flutter analyze` 0 error。

  **完成时间**: 2026-06-17

---

## 已完成：学习流程调整 —— 盲听后置 + 取消手动选难度 + 难度自动判定

依据 DAU 下降分析报告：盲听作为首次学习第一步让新用户困惑、延后 aha 时刻。首次学习流程由
`盲听→精听→跟读→复述` 调整为 `逐句精听→难句跟读→盲听(可跳过)→段落复述`，并取消手动难度选择、
难句跟读统一默认 3 遍、精听完成弹窗增加间隔复习引导。仅对新建音频生效（计划版本 firstLearn v2）。

- [x] `learning_plan.dart`：`kLatestPlanVersions[firstLearn]=2`；`LearningPlan.standard` firstLearn 按版本分支，v2=`[intensive, listenAndRepeat, blind, retell]`，v1 保留旧顺序。
- [x] `enums.dart`：`LearningStage.allSubStages` firstLearn 改为 v2 规范顺序。
- [x] `learning_progress.dart`：新增 `firstLearnEntrySubStage`（按 plan 版本派生）；`isStarted` / `canSkipCurrentSubStage` 改为按入口子步骤判定（v1 盲听不可跳过、v2 精听不可跳过盲听可跳过）。
- [x] `learning_progress_provider.dart`：`ensureProgress` 新建进度入口子步骤改为 v2 的逐句精听。
- [x] `step_complete_dialog.dart`：删除 5 档难度选择器（含 `StepCompleteResult.difficulty`、`showDifficultySelector`）。
- [x] `blind_listen_player_screen.dart`：盲听完成不再弹难度选择 / 写难度。
- [x] 新增 `utils/difficulty_from_ratio.dart`：精听后按「难句比例=收藏难句/总句数」自动判定难度（0/≤5%/≤15%/≤30%/>30% → veryEasy/easy/medium/hard/veryHard）。
- [x] `intensive_listen_player_screen.dart`：精听完成时自动 `setDifficulty`。难度仍驱动 `defaultPlaybackSpeedFor(难度×阶段)` 默认速度（整表不变）。
- [x] `sentence_playback_engine.dart`：`targetPlayCountForDifficulty` 各档统一返回 3（保留接口便于以后差异化）。
- [x] l10n：`intensiveListenCompleteMessage` 改为「你已精听全部 X 个句子，收藏了 Y 个难句。坚持间隔复习，就能彻底掌握这些难句。」（中英）。
- [x] 测试：新增 `difficulty_from_ratio_test`；更新 plan/progress/enums/dialog/provider/screen/engine/fake_notifiers 及 integration 测试（v2 顺序、入口跳过规则、难度自动判定、新文案）。全量 2818 单元/widget 测试通过，`flutter analyze` 0 error。

  **完成时间**: 2026-06-17

---

## 已完成：修复「清除缓存」误删系统 URLCache 致 disk I/O error

清缓存把整个 `Library/Caches` 一级条目全删，连带删掉 `URLSession.shared`(NSURLCache) 正在打开的 `<bundleId>/Cache.db`，导致后续网络请求反复报 `disk I/O error`（与磁盘空间无关）。改为只清 app 自己的产物。

- [x] `temp_cleanup_service.cleanupAllTempFiles`：`Library/Caches` 不再全量删；新增前缀白名单 `audio_export_`/`echoloop_export_`/`echoloop_import_` + `_cleanupDirectory` 的 `nameFilter` 参数，只删 app 自建导出/导入临时目录，系统/框架缓存（`Cache.db*`、`<bundleId>/`、`app_network_images`）一律跳过；日志补 `skipped=`。tmp/ 仍全量清。
- [x] `settings_screen._clearNetworkImageCache`：网络图片缓存改走 `AppNetworkImageCache.instance.emptyCache()`（flutter_cache_manager API），释放字节累加进提示。
- [x] 测试：`temp_cleanup_service_test` 重写 `cleanupAllTempFiles` group（tmp/ 全清、Library/Caches 只删导出导入目录、保护 URLCache/框架缓存）。services 全量 445 测试通过，`flutter analyze` 改动文件 0 issue。
- [x] CLAUDE.md §7.5 记录踩坑与规则。

  **完成时间**: 2026-06-17

---

## 已完成：清空缓存补齐孤儿音频/字幕/waveform 文件清理

设置页「清除缓存」此前只清 AI 缓存表 + 内存 + 系统临时目录 + 词典，从不触碰 app 数据目录下按内容/ID 落盘的产物，导致孤儿音频、孤儿字幕、waveform 文件永久堆积。

- [x] **源头泄漏修复**：删除音频时 `_deleteAudioFilesIfUnreferenced`（`audio_library_provider.dart`）此前只删 audioPath/transcriptPath，从不删 `waveforms/{id}.wave` → 每删一个音频漏一个波形文件。现按 id 一并删除（波形按 id 独占无共享，无需引用检查）。
- [x] 新增 `AudioItemDao.getAllReferencedRelPaths()`：取**所有行（含软删）**的 audioPath/transcriptPath 相对路径集合，作为孤儿清扫白名单（软删行硬删前仍持有文件，不能误删）。
- [x] 新增 `lib/services/orphan_file_cleanup_service.dart`：`cleanupOrphanMediaFiles()` 递归扫 `audios/`（覆盖 imported/official 子目录 + 旧版直接存于根、可读文件名的遗留音频）和 `transcripts/`，删除 DB 无引用的孤儿文件；`cleanupAllWaveforms()` 全量清 `waveforms/`（纯缓存，可重建）。
- [x] `settings_screen._clearAiCache` 接入两个清理函数，freedBytes 累加进释放提示，沿用现有文案与埋点。
- [x] 测试：`orphan_file_cleanup_service_test.dart`（孤儿删除/引用保留/空集全删/不碰 waveforms/全量清波形）；`dao_test` 补 `getAllReferencedRelPaths`（含软删行、忽略空路径）；`audio_library_provider_test` 补「删音频一并删 waveform」。

  **完成时间**: 2026-06-17

---

## 已完成：练习播放页进度条改为可拖动（按句吸附跳转）

学习计划五个播放页（盲听 / 精听 / 跟读 / 复述 / 难句补练）的顶部进度条由只读 `LinearProgressIndicator` 改为按句分档的可拖动滑块，松手吸附到目标句并从该句开始播放。**收藏复习不做**。

- [x] 共享组件 `PracticeProgressSection` 新增可选 `onSeek(int targetIndex)`（0-based）；非 null 且 `total>1` 时渲染私有 `_SeekableProgressBar`（拖动跟手、`onChangeEnd` 才提交、`SliderTheme` 收紧尺寸），否则保持只读进度条。向后兼容。
- [x] `ParagraphPracticeScaffold` 新增 `onSeekToIndex` 透传（盲听 / 复述经它渲染）。
- [x] 跳转能力：盲听 / 复述复用现成 `seekToSentence`；精听、`RepeatFlowEngine`（跟读）、难句补练新增公开 `goToSentence(int)`（防御式 clamp + 同句 no-op，next/prev 复用）；`ListenAndRepeatController` 转发。
- [x] 五个播放页接线 `onSeek`。
- [x] 测试：新建 `practice_progress_section_test.dart`（只读/滑块切换、拖动回调取值）；精听 / 跟读 / 难句补练 provider 各补 `goToSentence`（合法跳转 / 越界 clamp / 同句 no-op）单测。`flutter analyze` 0 error，相关 117 测试全过。

  **完成时间**: 2026-06-16

---

## 已完成：延后转码 —— 导入保留原始音频，AI 转录后再转码

提升 AI 转录质量：旧流程导入即转码为 64k 单声道 m4a，转录上传低质 m4a。改为导入**不转码**（保留原始、导入更快）、转录上传**原始文件**（质量更高）、转录成功后在流程内**顺带**把原始转码为 m4a 并替换 `audioPath`、删除原始。

- [x] `AudioTranscodeService`：抽出底层 `transcodeToFile(source, output)→bool`（不删源、失败删半成品），删除旧 `transcodeToM4a`/`_uniqueOutputPath`/`_replaceSourceWithOutput` 死代码。
- [x] `AudioFinalizationService.finalize()`：导入不再转码，按原始指纹保留原格式落盘（`sha==originalSha`）；新增 `transcodeExisting()`（转录后转码，`try/finally` 清理临时 m4a，不删源由调用方删）。
- [x] `transcription_task_provider`：`_saveTranscriptAndFinish` 内 best-effort 转码——仅对未转码用户导入（`remoteAudioId==null && audioSha256==originalAudioSha256`）触发；成功更新 `audioPath`/`audioSha256` 并删原始，**失败静默**（仍保存字幕、保留原始，不阻塞学习）。新增 `transcriptionFinalizationServiceProvider`。
- [x] 边界：① 转码失败/异常清理临时文件；② "是否已转码"复用现有两 sha 相等判据，删字幕不动 sha → 重转录天然跳过/重试，无需新字段或迁移。
- [x] 测试：finalization 单测（导入不转码 / transcodeExisting 成功·失败·去重·无残留）；import_service 单测改为断言保留原始；provider 单测新增「成功触发转码并删原始」「失败静默仍完成」；transcode 集成测试改用 `transcodeToFile`。

  **完成时间**: 2026-06-16

---

## 已修复：字幕丢失 + 冷重启音频显示未下载（同一根因）

- [x] **根因**：`AudioItemDao.batchInsert` 用 `InsertMode.insertOrReplace`，在 SQLite 是整行 **DELETE+INSERT**。由 commit `3768a131` 把 `_upsertItem` 改走批量 `insertOrReplace` 引入。两个后果：
  1. `_audioItemToCompanion` 不携带 `transcript_srt` / `word_timestamps_json`，整行替换把这两列抹成 NULL → 「句数词数还在但字幕没了」（编辑字幕/自由练习/盲听都拿不到字幕）。
  2. DELETE 行触发所有子表 `ON DELETE CASCADE`（`collection_audio_items` / `bookmarks` / `playback_states` / `learning_progresses`）→ 音频被静默移出合集、丢书签与学习进度。冷启动若有旧绝对路径音频触发 `hasMigratedItems`，会对全部音频回写一遍，整片合集 junction 被删空 → 官方/podcast 音频在详情页"消失"并回落到下载态 → 显示「下载按钮」。
  - 任何走 `_upsertItem` 的回写都会触发：`updateAudioItem` / `togglePin` / `checkAudioContent`（下载完成后立即调用）/ `backfill*` / 路径迁移。
  - **修复**：`batchInsert` 改为逐条 `insert(..., onConflict: DoUpdate((_) => entry))`（INSERT … ON CONFLICT DO UPDATE），已存在行只更新 companion 携带的列、不删行 → 大字段保留、不触发级联。
  - **测试**：`test/database/dao_test.dart` 新增 2 个回归用例（保留 transcript_srt/word_timestamps 大字段；不级联删除合集 junction/书签），旧实现下精确 fail、修复后通过。
  - **注意**：已被旧版本抹掉 `transcript_srt` 的存量数据无法从统计反推；有遗留 `transcriptPath` 文件的可由启动 `backfillTranscriptSrt` 恢复，否则需重新下载/转录。被级联删空的合集 junction 由下次官方 sync 重建。

  **完成时间**: 2026-06-15

---

## 待办：Android 离线 ASR 结束录音仍闪退

- [ ] 崩在 sherpa-onnx 的 Silero VAD native 推理（`_extractSpeechWithVad`）；cpu provider、AudioRecord 串行、自适应跳过 VAD 三种尝试均未解决（skip-VAD 真机连续崩多次已撤销）。诊断设施已保留，待真机 **logcat + `/data/tombstones`** 确诊信号/栈后再定方案。详见 CLAUDE.md §7.4。

---

## 进行中：启动埋点附带 4 类授权状态

PostHog 自动事件 `Application Opened` 不带任何系统授权属性，无法做"授权状态 vs 留存"分析。本期把麦克风 / 语音识别 / 通知 / 网络 4 类授权状态作为 PostHog **super properties + person properties + 自定义事件 `app_permission_snapshot`** 上报；不修改任何现有权限弹窗时机。

### 任务拆分（一次一项）
- [x] **任务 1：埋点常量 + PermissionSnapshot helper + 单测**
  - `event_names.dart`：新增 `Events.appPermissionSnapshot` + 4 个 EventParams（mic/speech/notification/network）
  - `lib/analytics/permission_snapshot.dart`：不可变值对象 + `toEventParams()` + 静态 `capture(prefs, {probe})`
  - `PermissionProbe` 抽象 + `DefaultPermissionProbe` 实现（mic/speech 走 `SpeechPracticePlatform`，notification 走 `flutter_local_notifications`；网络读 SP `network_data_task_succeeded`，仅 iOS 有意义，其他平台 `not_applicable`）
  - 网络状态映射：iOS 上 SP 缺失 → `notDetermined`，true → `granted`，**不引入假 denied 推断**
  - `test/analytics/permission_snapshot_test.dart`：11 个测试覆盖 toEventParams 映射 / 网络状态平台分支 / probe 容错 / 状态常量
  
  **完成时间**: 2026-04-26
- [x] **任务 2：iOS 网络 channel 改造 + main.dart 写 SP**
  - `ios/Runner/AppDelegate.swift:1144-1170` channel handler 返回 `{ok, reason}` + `hasResponded` Once 守护 + 5s 超时（避免 method channel 多次 result 踩坑，参考 CLAUDE.md §7.2）
  - 把原 `_triggerNetworkPermission` 抽到 `lib/services/network_permission_trigger.dart` 的 `NetworkPermissionTrigger.trigger(prefs, url)`，便于单测；成功时写 SP `network_data_task_succeeded = true`，**失败/超时/异常不写 SP**（防止飞行模式 / 弱网 / 服务端故障被误判为 denied）
  - `lib/main.dart` 删除内联 `_triggerNetworkPermission`，启动调用改为 `NetworkPermissionTrigger.trigger(prefs, apiBaseUrl)`，并清理掉不再用的 `package:flutter/services.dart` import
  - `test/services/network_permission_trigger_test.dart`：7 个测试覆盖 ok=true/false/null/缺字段/抛错/幂等/失败不回退
  
  **完成时间**: 2026-04-26
- [x] **任务 3：AnalyticsChannel.registerSuperProperties + PostHog 实现 + 其他 channel no-op + AnalyticsService 转发**
  - `analytics_channel.dart` 接口新增 `registerSuperProperties(Map<String, Object>)` + 中文文档注释（解释与 setUserProperty 的区别）
  - `posthog_channel.dart` 实现：循环调用 `Posthog().register(key, value)`（5.x SDK 一次接受一个 key/value）
  - `firebase_channel.dart` / `umeng_channel.dart` no-op 实现 + 注释说明为何
  - `log_only_channel.dart` 实现：把 `key=value` 列表打到 `AppLogger`
  - `analytics_service.dart` 加 `registerSuperProperties` 方法：consent gate + try/catch 兜底（埋点不影响主业务）
  - 更新所有现有 mock channel 实现新方法（`MockChannel` / `_RecordingChannel`）
  - 新增 4 个测试：转发 / consent 拦截 / 异常静默吞 / LogOnly 日志格式
  
  **完成时间**: 2026-04-26
- [x] **任务 4：main.dart 启动序列接入 + Onboarding 末页权限预告 label**
  - `lib/analytics/permission_snapshot.dart` 新增 `PermissionSnapshotReporting` extension on `AnalyticsService`，把"super properties + 4 个 person property + `app_permission_snapshot` 事件"三路写入封装在一个方法里
  - `lib/main.dart` 在 `initAnalytics` 之后 `await PermissionSnapshot.capture(prefs)` → `await analyticsService.reportPermissionSnapshot(snapshot)`，用 try/catch 包裹避免影响启动
  - Onboarding 方法论页（summary）"开始学习"按钮上方加权限预告：小号提示 + 两个 `Wrap` chip（`notifications_outlined` / `wifi_outlined` + 短 label "系统通知" / "网络权限"），独立 Padding 区不滚动总能见，仅展示无交互
  - 网络权限保持启动即触发（保留原行为）：埋点上报依赖网络通畅，推迟到 Onboarding 完成会丢事件；系统弹窗具体呈现时机由 OS 决定
  - ARB 新增 3 个 key（zh + en）
  - 测试：`permission_snapshot_test.dart` 加 2 个测试覆盖 extension（三路写入 / consent 拦截）；`onboarding_survey_screen_test.dart` 加权限 label 渲染断言
  
  **完成时间**: 2026-04-26
- [ ] 任务 5：手动验证（PostHog Live Events / Persons / Insights）

### 范围内不做
- 自定义教育弹窗 / 调整任何现有权限弹窗时机 / 跳系统设置引导 / AppLifecycleState.resumed 监听 / Android 13+ 通知权限 UI 验证

---

## 录音+识别功能（进行中）

- [x] **修复 iOS `prod` flavor release 构建配置**

  **完成时间**: 2026-06-15 18:38 +0800

  补齐 `prod` flavor 的 iOS 构建链路，避免 `flutter run --release --flavor prod` 在 Flutter 26 / Xcode 26 下丢失 `TARGET_BUILD_DIR`：
  - `ios/Podfile` 增加 `Debug-prod` / `Release-prod` 到 CocoaPods 配置映射
  - 新增 `ios/Flutter/Debug-prod.xcconfig` 与 `ios/Flutter/Release-prod.xcconfig`
  - `ios/Runner.xcodeproj/project.pbxproj` 将 `Debug-prod` / `Release-prod` 绑定到对应 flavor xcconfig
  - 重新执行 `pod install` 同步 Pods flavor 配置
  - 验证 `xcodebuild -workspace Runner.xcworkspace -scheme prod -configuration Release-prod -showBuildSettings` 可正常输出 `TARGET_BUILD_DIR`

- [x] **段落复述评级开关**
  
  **完成时间**: 2026-06-15 16:04 +0800
  
  学习设置页新增「计算并显示复述评级」开关，默认开启。关闭后段落复述只保留录音和自动回听，不再启用识别、转录、匹配或评分，胶囊降级为「录音」胶囊（不显示评级）；段间停顿按无评分策略计算。
  - [x] `LearningSettings` 新增 `retellRatingEnabled`，使用 `learning_retell_rating_enabled` 持久化，默认 true
  - [x] 段落复述录音关闭评级时跳过 ASR/transcript/matcher/embedding，只保存录音 attempt
  - [x] 关闭评级时胶囊降级为「录音」胶囊（`unavailable + filePath`），仍挂载并复用 badge controller
  - [x] 补充学习设置、复述录音 controller、复述页面回归测试
  - [x] 2026-06-15 16:08 +0800：调整学习设置页复述评级开关文案为「复述时关闭评级」，描述改为关闭后只保留录音回听且不再显示评分
  - [x] 2026-06-15：修复关闭评级时自动回听不显示停止图标的 bug——删除绕过 badge 的 `_playAttemptRecordingDirectly` 直连路径，开启/关闭统一走 `_ratingBadgeController.play()`，使「录音」胶囊在自动回听时正确显示停止图标且可点停止；修正被该 bug 固化的测试断言；补全 `_TestLearningSettingsNotifier.setRetellRatingEnabled` 缺失实现
  - [x] `flutter analyze lib/providers/learning_settings_provider.dart lib/providers/retell_recording_controller_provider.dart lib/screens/learning_settings_screen.dart lib/screens/retell_player_screen.dart lib/widgets/common/repeat_practice_panel.dart lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_zh.dart test/providers/learning_settings_provider_test.dart test/providers/retell_recording_controller_test.dart test/screens/learning_settings_screen_test.dart test/screens/retell_player_screen_test.dart`：No issues found
  - [x] `flutter test test/providers/learning_settings_provider_test.dart test/screens/learning_settings_screen_test.dart test/providers/retell_recording_controller_test.dart test/screens/retell_player_screen_test.dart`：39 passed
  - [ ] `scripts/check.sh`：未跑；本次为学习设置与段落复述局部行为改动，按规范仅运行直接相关检查

- [ ] 段落复述页面复用同一模块接入录音识别能力。

---

## 优化UI（进行中）

- [x] **全能播放器句子列表交互优化**

  **完成时间**: 2026-06-17

  删除 AppBar 手动 focus 按钮，改为播放句自动跟随、用户滚动后短暂停留再自动恢复；缩小播放器标题字号并单行省略；句子 item 改为左侧单句播放、中间进入句子讲解、右侧整高收藏区域，字幕文字与时间样式参考字幕编辑器。补充单句播放 provider 入口，确保点击左侧只播放当前句，播完暂停。

- [ ] 支持自定义背景、背景音

---

## 用户体验优化（待办）

- [ ] 计算每个任务的估计学习时长，显示在音频学习计划页以及学习tab页的任务item上。没有学习的显示估计时长，已经学习的显示真实的耗时。
- [ ] 学习 tab 页面点击学习或复习要直接打开学习页面，跳过学习计划页面
- [ ] 在学习tab，增加显示今日完成任务（如果有），默认折叠起来，避免用户不知道今天都学了哪些
- [ ] 给句子增加复制功能，在移动端长按，在PC端右键，弹出一个菜单，现在只有一个选项就是复制。

---

## 加入特效

- [ ] 一个句子/单词播放完成，一遍播放完成，播放音效
- [ ] 任务完成，播放动画+音效

---

## 埋点

- [ ] 支持中国大陆区
- [ ] 支持全球

---

## 历史归档
- [Milestone 2 - 学习流程引擎](./docs/tasks-archive/milestone-2-learning-engine.md)
- [Milestone 3 - 收藏与标注体系 + 体验优化](./docs/tasks-archive/milestone-3-completed.md)
- [Milestone 4 - 功能完善与体验打磨](./docs/tasks-archive/milestone-4-features-and-polish.md)
- [Milestone 5 - 登录认证 / Podcast / 离线 ASR / 字幕编辑器](./docs/tasks-archive/milestone-5-completed.md)

---

## 任务完成记录模板

<!--
完成任务后，按以下格式在任务下方添加记录：

  **完成时间**: 2026-XX-XX
-->
