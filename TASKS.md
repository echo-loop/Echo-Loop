# Echo Loop 任务清单

> 最后更新：2026-06-18（循环设置浮层定位与布局优化）
> 当前焦点：Android 结束录音闪退（离线 ASR / Silero VAD）——**仍未解决**

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
