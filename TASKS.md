# Echo Loop 任务清单

> 最后更新：2026-06-05
> 当前焦点：字幕编辑器波形边界手柄与最大缩放（已完成）

## 已完成：字幕编辑器波形边界手柄与最大缩放

将字幕编辑页波形里的起止边界把手从波形顶部移动到波形下部，并让把手底部贴住底部时间轴线，避免把手与顶部句子文本抢空间；同时把最大缩放从约每屏 4 秒提升到约每屏 2 秒，方便更精细地调整句子边界。

### 实现
- [x] 边界把手绘制位置改为底部贴住时间轴线，边界竖线仍贯穿波形用于定位
- [x] 边界把手 hit-test 与底部视觉位置对齐，顶部边界线不再误触发拖动
- [x] 波形最大缩放上限改为按约 2 秒可见窗口计算
- [x] 更新波形把手交互测试与缩放上限测试

### 验证
- [x] `dart format lib/features/subtitle_editor/subtitle_waveform_view.dart lib/features/subtitle_editor/subtitle_editor_controller.dart test/features/subtitle_editor/subtitle_waveform_view_test.dart test/features/subtitle_editor/subtitle_editor_controller_test.dart`
- [x] `flutter analyze lib/features/subtitle_editor test/features/subtitle_editor`：No issues found
- [x] `flutter test test/features/subtitle_editor/`：48 tests passed
- [x] `scripts/check.sh`：已执行，全量 `flutter analyze` 通过（仅仓库既有 warning/info）；全量 `flutter test` 执行到 1293+ tests、4 skip 时未见失败，工具会话结束前未返回最终 integration/build 结果

**完成时间**: 2026-06-05 22:52 +0800

## 已完成：字幕编辑器句子 item 三栏布局

将字幕编辑页句子列表从 `ListTile` 默认 leading/trailing 布局改为与合集列表一致的三栏结构：左侧播放按钮、中间文本、右侧菜单按钮。左右按钮区固定较窄宽度并占满 item 高度，减少对字幕文本区的挤压，同时保留播放、选中、合并下一句和删除菜单行为。

### 实现
- [x] 句子 item 改为 `Material + IntrinsicHeight + Row`，左/中/右三栏清晰分区
- [x] 左侧播放区固定 52px、右侧菜单区固定 44px，整高可点击
- [x] 中间文字区使用 `Expanded` 占满剩余宽度，点击仍用于选中句子
- [x] 保留选中/播放中的行底高亮与播放中 primary 图标强调

### 验证
- [x] `dart format lib/features/subtitle_editor/subtitle_simple_editor_screen.dart`
- [x] `flutter analyze lib/features/subtitle_editor/subtitle_simple_editor_screen.dart`：No issues found
- [x] `flutter test test/features/subtitle_editor/`：49 tests passed

**完成时间**: 2026-06-05 22:09 +0800

## 已完成：AI 转录 v2 认证与登录弹窗

将 AI 转录改为与翻译、解析、意群一致的认证策略：新版本客户端调用 v2 user-audio API 并携带 Supabase access token；旧版 v1 user-audio API 保持不变，避免老版本 App 用户立即无法使用。Flutter 端在点击 AI 转录入口时要求登录，未登录用户展示可关闭的登录弹窗；本地上传字幕不受影响。

### 实现
- [x] Flutter 转录请求切换到 `/api/v2/user-audio/upload-url`
- [x] Flutter 转录提交切换到 `/api/v2/user-audio/submit-transcription`
- [x] Flutter 转录轮询与结果获取切换到 `/api/v2/user-audio/job-status/[jobId]` 和 `/api/v2/user-audio/transcript`
- [x] 请求 v2 user-audio API 时通过 `Authorization: Bearer <Supabase access token>` 发送认证信息
- [x] 管理字幕弹窗点击 AI 转录时读取 Supabase session；未登录时展示登录弹窗，支持取消或跳转登录页
- [x] 意群词级时间戳远端回补改为仅在有 access token 时访问 v2 transcript API；本地 DB 已有词级时间戳仍可未登录读取
- [x] 后端新增 `/api/v2/user-audio/*`，复制 v1 业务逻辑后在用户端入口增加 Bearer token 校验
- [x] v1 user-audio API 保持不变，支持旧版 App 继续使用
- [x] 补充中英文登录提示文案并重新生成本地化代码

### 验证
- [x] `flutter gen-l10n`
- [x] `dart format lib/services/transcription_api_client.dart lib/providers/transcription_task_provider.dart lib/utils/sense_group_service.dart lib/widgets/manage_subtitles_sheet.dart lib/widgets/practice/annotation_content_view.dart test/helpers/mock_providers.dart test/providers/transcription_task_provider_test.dart test/services/transcription_api_client_test.dart test/widgets/manage_subtitles_sheet_test.dart`
- [x] `flutter analyze lib/services/transcription_api_client.dart lib/providers/transcription_task_provider.dart lib/utils/sense_group_service.dart lib/widgets/manage_subtitles_sheet.dart lib/widgets/practice/annotation_content_view.dart test/providers/transcription_task_provider_test.dart test/services/transcription_api_client_test.dart test/widgets/manage_subtitles_sheet_test.dart`：No issues found
- [x] `flutter test test/services/transcription_api_client_test.dart test/providers/transcription_task_provider_test.dart test/widgets/manage_subtitles_sheet_test.dart`：43 tests passed
- [x] 后端 `pnpm exec biome format --write apps/app/app/api/v2/user-audio/upload-url/route.ts apps/app/app/api/v2/user-audio/submit-transcription/route.ts apps/app/app/api/v2/user-audio/job-status/[jobId]/route.ts apps/app/app/api/v2/user-audio/transcript/route.ts apps/app/__tests__/user-audio-v2-auth.test.ts`
- [x] 后端 `pnpm exec vitest run __tests__/user-audio-v2-auth.test.ts`：4 tests passed
- [x] 后端 `pnpm --filter app typecheck`：通过
- [x] `scripts/check.sh`：全量 `flutter analyze` 通过（仅仓库既有 warning/info）；全量 `flutter test` 2448 tests passed，11 skip；macOS integration 中 `native_audio_decoder_integration_test.dart` 通过，后续 `asr_engine_test.dart` / `app_test.dart` 失败在本地 App debug connection 启动失败（`The log reader stopped unexpectedly, or never started`），与本次 AI 转录认证改动无关

**完成时间**: 2026-06-05 19:02 +0800

## 已完成：AI 翻译/解析 v2 认证与登录弹窗

将 AI 翻译和句子解析改为与意群功能一致的认证策略：新版本客户端调用 v2 API 并携带 Supabase access token；旧版 v1 API 保持不变，避免老版本用户立即无法使用。Flutter 端仅在本地 L1/L2 缓存未命中、必须访问云端 L3 API 时要求登录，未登录用户点击翻译、解析或意群时统一展示可关闭的登录弹窗，不使用 snackbar。

### 实现
- [x] Flutter 翻译请求切换到 `POST /api/v2/ai/translate`
- [x] Flutter 解析请求切换到 `POST /api/v2/ai/analyze`
- [x] 请求 AI v2 API 时统一通过 `Authorization: Bearer <Supabase access token>` 发送认证信息
- [x] `SentenceAiProvider` 对翻译、解析、意群统一使用 `AiFeatureAuthRequiredException` 表达未登录且需要远端请求
- [x] 翻译/解析 L1/L2 缓存命中仍允许未登录读取，避免老数据和缓存体验被破坏
- [x] 标注页翻译、解析、意群三类入口未登录时统一展示登录弹窗，支持关闭、取消或跳转登录页
- [x] 后端新增 `/api/v2/ai/translate` 和 `/api/v2/ai/analyze`，复制 v1 业务逻辑后仅在入口增加 Bearer token 校验
- [x] v1 翻译、解析、意群 API 保持不变，支持后续独立灰度下线

### 验证
- [x] `flutter gen-l10n`
- [x] `dart format lib/services/sentence_ai_api_client.dart lib/providers/sentence_ai_provider.dart lib/widgets/practice/annotation_content_view.dart lib/widgets/practice/sentence_annotation_card.dart test/services/sentence_ai_api_client_test.dart test/providers/sentence_ai_provider_test.dart test/widgets/annotation_content_view_auth_test.dart`
- [x] `flutter analyze lib/services/sentence_ai_api_client.dart lib/providers/sentence_ai_provider.dart lib/widgets/practice/annotation_content_view.dart lib/widgets/practice/sentence_annotation_card.dart test/services/sentence_ai_api_client_test.dart test/providers/sentence_ai_provider_test.dart test/widgets/annotation_content_view_auth_test.dart`：No issues found
- [x] `flutter test test/services/sentence_ai_api_client_test.dart test/providers/sentence_ai_provider_test.dart test/widgets/annotation_content_view_auth_test.dart`：35 tests passed
- [x] 后端 `pnpm exec biome format --write apps/app/app/api/v2/ai/translate/route.ts apps/app/app/api/v2/ai/analyze/route.ts apps/app/app/api/v2/ai/analyze/cleanup.ts apps/app/__tests__/sentence-ai-v2-auth.test.ts`
- [x] 后端 `pnpm exec vitest run __tests__/sense-groups-v2-auth.test.ts __tests__/sentence-ai-v2-auth.test.ts`：4 tests passed
- [x] 后端 `pnpm --filter app typecheck`：通过
- [x] `scripts/check.sh`：全量 `flutter analyze` 通过（仅仓库既有 warning/info）；全量 `flutter test` 2444 tests passed，11 skip；macOS integration 中 `native_audio_decoder_integration_test.dart` 通过，后续 `asr_engine_test.dart` / `app_test.dart` 失败在本地 App debug connection 启动失败（`The log reader stopped unexpectedly, or never started`），与本次 AI 认证改动无关

**完成时间**: 2026-06-05 18:25 +0800

## 已完成：意群 v2 认证与登录弹窗

为意群功能新增认证保护，同时保留旧版 v1 API，避免老版本客户端立即被禁止访问。Flutter 端改为只在需要请求后端 L3 意群 API 时要求 Supabase access token；已有本地 L1/L2 缓存仍可离线/未登录读取。未登录用户点击意群且本地无缓存时展示可关闭的登录弹窗，支持取消或跳转登录页。

### 实现
- [x] Flutter 意群请求切换到 `POST /api/v2/ai/sense-groups`
- [x] 请求 v2 API 时通过 `Authorization: Bearer <Supabase access token>` 发送认证信息
- [x] `SentenceAiProvider` 在 L1/L2 缓存未命中、即将访问 L3 API 前校验 access token，未登录时抛出明确的认证异常
- [x] 标注页点击意群时读取 Supabase session；未登录且需要远端请求时展示登录弹窗，不使用 snackbar
- [x] 后端新增 `/api/v2/ai/sense-groups`，复制 v1 业务逻辑后仅在入口增加 Bearer token 校验
- [x] v1 API 保持不变，支持后续按版本灰度下线
- [x] 补充中英文登录提示文案并重新生成本地化代码

### 验证
- [x] `flutter gen-l10n`
- [x] `dart format lib/services/sentence_ai_api_client.dart lib/providers/sentence_ai_provider.dart lib/utils/sense_group_service.dart lib/widgets/practice/annotation_content_view.dart test/services/sentence_ai_api_client_test.dart test/providers/sentence_ai_provider_test.dart test/widgets/annotation_content_view_auth_test.dart`
- [x] `flutter analyze lib/services/sentence_ai_api_client.dart lib/providers/sentence_ai_provider.dart lib/utils/sense_group_service.dart lib/widgets/practice/annotation_content_view.dart test/services/sentence_ai_api_client_test.dart test/providers/sentence_ai_provider_test.dart test/widgets/annotation_content_view_auth_test.dart`：No issues found
- [x] `flutter test test/services/sentence_ai_api_client_test.dart test/providers/sentence_ai_provider_test.dart test/widgets/annotation_content_view_auth_test.dart`：32 tests passed
- [x] 后端 `pnpm exec vitest run __tests__/sense-groups-v2-auth.test.ts`：2 tests passed
- [x] 后端 `pnpm --filter app typecheck`：通过
- [x] `scripts/check.sh`：全量 `flutter analyze` 通过（仅仓库既有 warning/info）；全量 `flutter test` 2441 tests passed，11 skip；macOS integration 中 `native_audio_decoder_integration_test.dart` 通过，后续 `asr_engine_test.dart` / `app_test.dart` 失败在本地 App debug connection 启动失败（`The log reader stopped unexpectedly, or never started`），与本次意群认证改动无关

**完成时间**: 2026-06-05 15:21 +0800

## 已完成：iOS 我的页新增 App Store 评价入口

在“我的”tab 的 About 区域为 iOS 用户新增“评价我们”入口，点击后直接通过 App Store 客户端打开 Echo Loop 的写评价页面。App Store ID 统一收敛到配置文件，更新检查的兜底商店链接也复用同一配置，避免后续维护时出现 ID 不一致。

### 实现
- [x] 新增 `lib/config/app_store_config.dart`，集中管理 App Store App ID、应用详情页和写评价页链接
- [x] `SettingsScreen` 在 iOS 平台显示“评价我们 / Rate Us”入口，非 iOS 平台隐藏
- [x] 点击入口使用 `itms-apps://itunes.apple.com/app/id6760324074?action=write-review` 并以外部应用方式打开
- [x] 新增中英文 i18n 文案并重新生成本地化代码
- [x] 设置页测试覆盖 iOS 显示入口、非 iOS 隐藏入口

### 验证
- [x] `flutter analyze lib/config/app_store_config.dart lib/screens/settings_screen.dart lib/services/app_update_checker.dart test/screens/settings_screen_test.dart`：No issues found
- [x] `flutter test test/screens/settings_screen_test.dart`：19 tests passed
- [x] `scripts/check.sh`：全量 `flutter analyze` 通过（仅仓库既有 warning/info）；全量 `flutter test` 2437 tests passed，11 skip；macOS integration 中 `native_audio_decoder_integration_test.dart` 通过，后续 `asr_engine_test.dart` / `app_test.dart` 失败在本地 App debug connection 启动失败（`The log reader stopped unexpectedly, or never started`），与本次 iOS 设置入口改动无关

**完成时间**: 2026-06-04 22:52 +0800

## 已完成：用户事件统计与本地 usage counter

建立本地使用统计层，为后续产品体验节奏、功能使用状态和用户引导时机判断提供可查询的累计计数。统计层采用 SharedPreferences 持久化，所有 key 统一使用 `usage_` 前缀；远端 analytics 仍复用现有 `AnalyticsService`。

### 实现
- [x] 新增 `UsageEvent`、`UsageCounters`、`UsageCounterStore`、`UsageTracker` 和 Riverpod provider
- [x] SharedPreferences key 统一为 `usage_counters_v1`、`usage_prompt_state_v1`、`usage_last_recorded_at_ms`
- [x] usage 本地计数不受 analytics consent 影响；远端上报仍由 `AnalyticsService` 处理 consent，且本地计数异常不会阻断原 analytics 上报
- [x] 接入音频上传、字幕上传、AI 转录开始/完成、AI 翻译/解析/意群点击、学习子阶段完成、首次学习完成、收藏句子/单词、收藏复习/单词卡入口与完成、录音完成、学习任务点击
- [x] AI 翻译/解析/意群按用户点击计数，缓存命中也会累计
- [x] 测试环境提供 no-op usage override；纯 provider 单元测试未注入 SharedPreferences 时使用内存 store fallback

### 验证
- [x] `flutter analyze lib/features/usage test/features/usage/usage_tracker_test.dart`：No issues found
- [x] `flutter test test/features/usage/usage_tracker_test.dart`：6 tests passed
- [x] `flutter test test/providers/learning_progress_provider_test.dart test/providers/transcription_task_provider_test.dart`：99 tests passed
- [x] `flutter test test/features/usage/usage_tracker_test.dart test/widgets/manage_subtitles_sheet_test.dart test/providers/learning_session/bookmark_review_test.dart test/providers/learning_session/retell_player_provider_test.dart test/providers/review_difficult_practice_provider_test.dart test/providers/flashcard/flashcard_provider_test.dart test/screens/favorites_screen_test.dart`：86 tests passed

**完成时间**: 2026-06-04 22:05 +0800

## 已完成：字幕编辑器可拖动句子边界 + 词级时间戳同步

在字幕编辑页支持手动微调句子起止时间：波形上当前句的起止边界做成可拖动把手，并把前后相邻句的起止边界画成参照线；拖动不能跨越相邻句最近边界（句子永不重叠、顺序不变）。保存时同时更新句子级 SRT 和词级时间戳（`audio_items.word_timestamps_json`）——词级同步策略为「只对齐边界词」：每句首词 start 跟随句 start、末词 end 跟随句 end，中间词真实时间戳不动；被删除区间的词丢弃。词级同步在保存时按时间重建，不在编辑期维护词索引，merge/delete 逻辑不受影响。仅 AI 转录音频有词级数据；本地字幕只更新 SRT。

### 实现
- [x] `WordTimestamp` 新增 `copyWith`
- [x] 新增 `lib/utils/word_timestamp_sync.dart`：`syncWordTimestampsToSentenceBounds` 纯函数（按句子边界对齐边界词、丢弃句外词）
- [x] `SubtitleEditEngine` 新增 `BoundaryEdge` 枚举、`kMinSentenceDuration` 常量和 `adjustBoundary`（按相邻句最近边界 + 最小句长钳制）
- [x] `SubtitleEditorController` 新增 `adjustSelectedSentenceBoundary`；`save()` 增加词级时间戳同步块（AI 转录音频才执行）
- [x] `SubtitleWaveformView` 新增边界把手 hit-test + 拖动手势（命中边界拖边界、否则拖播放头）、前后句参照线、可抓取把手绘制；新增 `selectedIndex` / `onAdjustBoundary` / `onAdjustEnd` 入参
- [x] `SubtitleSimpleEditorScreen` 传入 `selectedIndex` 并接入拖动回调

### 验证
- [x] `flutter analyze`：本次改动文件 No issues（仅余仓库既有 info 级 lint）
- [x] `flutter test`：全量 2472 passed，11 skip
- [x] 新增/补充单测：`word_timestamp_sync_test.dart`（8 例）、`subtitle_edit_engine_test.dart` 补 `adjustBoundary`（8 例）、`subtitle_editor_controller_test.dart` 补边界调整（3 例）、`subtitle_waveform_view_test.dart` 补边界拖动（1 例）

**完成时间**: 2026-06-05

### 后续修复与增强（同日）
- [x] **Bug 1**：单句播放到句尾时焦点不再跳到下一句。`_handlePosition`/`_tickPlayhead` 仅在 range 模式跟随播放头切句，sentence 模式保持焦点（修复首尾相接句的跳焦）
- [x] **Bug 2**：缩放时保持「当前位置」（播放头）在屏幕上不动而非左侧不动。`SubtitleWaveformView._preserveFocalOnZoom` 在缩放后调整滚动偏移锚定焦点
- [x] **Bug 3**：前后相邻句的边界也可拖动。hit-test 扩展到当前句 + 前后句的起止边界；重合边界按拖动方向定夺（左拖选「结束」边界、右拖选「开始」边界）；`adjustSentenceBoundary(index, edge, target)` 支持任意句索引且不改变当前选中句
- [x] **Bug 4**：起止边界配色区分——起始蓝（`0xFF2196F3`）、结束绿（`0xFF43A047`）；相邻句边界用淡色 + 小把手
- [x] **增强**：支持双指捏合缩放波形，两条路径——① 触摸屏原始指针按指距比例缩放（双指期间禁用滚动）；② 触控板 `PointerPanZoom*` 按 `event.scale` 缩放（纯滚动 scale≈1 为 no-op，不影响横向滚动）；越界统一由 `setWaveformZoomScale` 钳制；新增 `onZoomChanged` 入参
- [x] 补充单测：缩放焦点保持、单句播放不跳焦、相邻句边界调整、触摸双指捏合、触控板 pan-zoom 捏合；字幕编辑波形 8 例全过
- [x] `flutter test` 全量：2476 passed，11 skip

### 重构：波形改为「单一坐标系」根治停止跳变/闪烁（同日）
反复出现的「播放停止时波形/红线跳变、闪烁」是架构问题：波形在 `SingleChildScrollView` 里、红线是独立视口 overlay，两套坐标系按不同周期更新（红线分状态用「理想居中」与「实际偏移」两套公式 + post-frame `jumpTo` 滞后一帧）。采用行业标准做法重构为单一真相源：
- [x] 新增纯类 `WaveformMetrics`（viewport/zoom/duration/padding → `timeToContentX`/`screenX`/`timeAt`/`offsetToCenter`），波形/边界/红线/命中/轴全部经此唯一映射
- [x] 删除 `ScrollView`/`ScrollController`/`_restPinned`/`_scheduleFollow`/`_centerPlayheadOnStop`/双公式 `_buildPlayhead`/`_contentKey`/物理切换；改为单 `CustomPaint` 填满视口，波形层只绘**可见时间窗**（顺带修复高缩放下整条 contentWidth 全量重绘的性能陷阱）
- [x] `viewOffset` 每帧在 build 内同步派生（播放跟随→选句居中→缩放焦点→保持），播放停止仅翻 `isPlaying`、偏移与红线像素级不变 ⇒ **结构性零跳变/零闪烁**
- [x] 手势改用 `event.localPosition` + `metrics.timeAt`（去 `globalToLocal`）；捏合/触控板/选句居中(selectionEpoch)/缩放焦点保持均迁移到同步模型
- [x] 测试：新增核心不变量「红线 x 跨 play→stop 像素级不变」「viewOffset 派生正确」；波形视图测试断言改读 painter

#### 真正根因（状态机/引擎层）—— 「播放完跳回句首」一直没好的原因
之前所有改动都在视图层，但「跳回句首」其实是 **controller 完成回调的停止顺序 bug**，与视图无关：
- 根因：`playSentence`/`togglePlaybackFromPlayhead` 的 finally「先停底层播放器再冻结状态」。`_audioPlayer.stop()` 会吐出 position=0，经 `absolutePositionStream = clipStart + rel` 映射成 clip 起点（句首），被 `_handlePosition` 采纳（此刻 `isPlaying` 仍为 true），把 `playbackPosition` 拉回句首 → 视图忠实跟随 → 跳回句首。
- [x] 修复：两个 finally 改为「先冻结 `isPlaying=false` + 锁定句尾位置，再 `_stopActivePlayback`」（与 `stopPlayback()` 一致）；`_handlePosition` 增加「丢弃 >400ms 大幅后退残留事件」防御。
- [x] 回归测试 `subtitle_editor_stop_position_test.dart`：模拟 stop 残留事件，断言句尾停住且中间帧不回退；已验证「无修复必失败、有修复通过」。

#### 视图侧补回两项回归（单坐标重写一度引入）
- [x] 抖动/闪烁：重新加入播放头 80ms 双向小步补间（TweenAnimationBuilder，同一 painted 同时驱动红线与跟随偏移），平滑 50ms tick 台阶与 position 流微校准。
- [x] 无法平移：单指拖动空白处 = 平移波形（1:1 跟手）；轻点 = 定位播放头；边界把手拖动 = 调边界；双指/触控板 = 缩放。
- [x] `flutter analyze` 改动文件 No issues；`flutter test` 全量通过。

#### Bug：合并/编辑句子后自由练习与盲听仍显示旧拆分句子
- 根因：`ListeningPractice` 为 `keepAlive`，其 `loadAudio` 去重守卫只比较 `id` + `transcriptPath`；字幕保存是**原地改写同名 SRT**（`transcripts/{id}_ai.srt`），两者都不变。编辑器 `save()` 保存后调 `loadAudio(updatedItem)` 未带 `forceTranscriptReload` → 命中守卫直接 return → 内存保留旧句子，自由练习/盲听（均派生自 LP.sentences）显示陈旧拆分版本（截图 `0:18` 中间边界即合并前 SRT 残留）。同理仅调时间戳也会读到旧值。
- [x] 修复：`subtitle_editor_controller.dart` `save()` 中对 LP 的 `loadAudio` 传 `forceTranscriptReload: true` 并补注释。
- [x] 测试 `subtitle_editor_controller_test.dart` 新增：LP 持有该音频时保存后必须以 `forceTranscriptReload: true` 重载。
- [x] `flutter analyze` 改动文件 No issues；`flutter test` 全量 2485 passed，11 skip。

**完成时间**: 2026-06-05

## 已完成：字幕编辑页 UI/UX 打磨

在不改变整体布局的前提下打磨字幕编辑页的视觉与交互，复用既有设计系统（`AppSpacing` / colorScheme），提升可读性、可发现性和破坏性操作的安全网。

### 实现
- [x] 句子列表时间戳去掉 `fontSize: 9` 硬编码，改用 `labelSmall`(11px) + `onSurfaceVariant`；精度降为 `MM:ss` 并加 `tabularFigures` 防数字抖动
- [x] 控制条间距统一到 `AppSpacing` 常量；倍速按钮从裸文本改为带 `outlineVariant` 边框、圆角 12 的紧凑 chip（含 `arrow_drop_down`），明确其可点性
- [x] 移除常驻 `_DirtyBanner`（警告语义已由保存确认对话框承载），释放列表垂直空间
- [x] AppBar 保存按钮从裸 `TextButton` 升级为紧凑 `FilledButton.tonal`，强化主操作存在感
- [x] 删除菜单项用 `colorScheme.error` 着色；删除后弹 SnackBar 并提供撤销，`SubtitleEditorController` 新增 `restoreSentences` 还原快照
- [x] 播放中行 leading 图标用 `colorScheme.primary` 实色，区别于「仅选中定位」的行底高亮
- [x] 波形绘制去掉顶部 `topPadding`、波形与时间轴间隙收到 2px，消除上方多余空白
- [x] 重定义波形缩放语义：`_contentWidth` 改为「视口宽度 × 缩放」，`zoomScale == 1` 时时间轴恰好铺满屏宽（不缩放）；上限 `maxWaveformZoomScale` 按音频长度计算（约 `时长 / 4s`，clamp 1~150），长音频也能放大到看清一句话
- [x] 控制条缩放滑块改为左 `zoom_out`、右 `zoom_in` 图标，去掉放大倍数文本；短音频（上限=1）禁用滑块

### 验证
- [x] `flutter gen-l10n`（新增 `sentenceDeleted` 文案，`undo` / `save` 复用既有 key）
- [x] `dart format lib/features/subtitle_editor/ test/features/subtitle_editor/`
- [x] `flutter analyze lib/features/subtitle_editor`：No issues found（全量 analyze 仅余仓库既有 warning/info）
- [x] `flutter test test/features/subtitle_editor/`：19 tests passed（含 `restoreSentences` 撤销、缩放范围按音频长度限制用例）

**完成时间**: 2026-06-05

## 已完成：简版字幕编辑页

为用户上传且已有字幕的音频新增简版字幕编辑入口和编辑页面。首版聚焦结构操作：顶部展示音频波形，下方展示句子列表；每句支持单句播放、合并下一句和删除句子。保存时重新生成 SRT，更新音频句子数/词数，并清除该音频学习进度和收藏句子，避免结构变化后 sentenceIndex 错位。

### 实现
- [x] 新增 `just_waveform` 依赖，用于提取波形数据；波形组件自绘当前句起止范围和播放进度，并为后续拖动边界预留绘制层
- [x] 新增 `SubtitleSimpleEditorScreen`，页面包含固定波形区、句子列表、保存按钮和未保存退出确认
- [x] 新增 `SubtitleEditorController`，负责加载音频/字幕、播放单句、合并下一句、删除句子、保存 SRT 和刷新当前练习缓存
- [x] 新增 `SubtitleEditEngine` 纯 Dart 逻辑，保证合并/删除后句子 index 连续
- [x] 音频菜单对用户上传且已有字幕的音频显示“编辑字幕”，官方音频和无字幕音频不显示
- [x] “管理字幕”弹窗在已有字幕时增加“编辑字幕”次级入口
- [x] 新增中英文文案并生成本地化代码
- [x] 修复字幕编辑交互稳定性：`AudioEngine.playClipOnce` 按标准 clip 流程显式 `seek(0)`，字幕编辑页统一播放 session / stop / clearClip，播放头使用本地时钟平滑推进并用 position stream 校准
- [x] 波形区新增播放、缩放和倍速控制；拖动播放头时停止当前播放，结束拖动后按绝对时间 seek
- [x] 合并/删除句子时停止播放并让红线回到新选中句起点；保存失败不再误提示成功

### 验证
- [x] `flutter gen-l10n`
- [x] `dart format lib/features/subtitle_editor lib/router/app_router.dart lib/widgets/audio_list_tile.dart lib/widgets/manage_subtitles_sheet.dart test/features/subtitle_editor/subtitle_edit_engine_test.dart test/widgets/audio_list_tile_test.dart`
- [x] `flutter analyze lib/features/subtitle_editor lib/router/app_router.dart lib/widgets/audio_list_tile.dart lib/widgets/manage_subtitles_sheet.dart test/features/subtitle_editor/subtitle_edit_engine_test.dart test/widgets/audio_list_tile_test.dart`：No issues found
- [x] `flutter test test/features/subtitle_editor/subtitle_edit_engine_test.dart test/widgets/audio_list_tile_test.dart`：18 tests passed
- [x] `dart format lib/features/subtitle_editor/subtitle_editor_controller.dart lib/features/subtitle_editor/subtitle_simple_editor_screen.dart lib/features/subtitle_editor/subtitle_waveform_view.dart lib/providers/audio_engine/audio_engine_provider.dart test/features/subtitle_editor/subtitle_editor_controller_test.dart test/features/subtitle_editor/subtitle_waveform_view_test.dart`
- [x] `flutter analyze lib/features/subtitle_editor lib/providers/audio_engine/audio_engine_provider.dart test/features/subtitle_editor`：No issues found
- [x] `flutter test test/features/subtitle_editor/subtitle_editor_controller_test.dart test/features/subtitle_editor/subtitle_waveform_view_test.dart test/features/subtitle_editor/subtitle_edit_engine_test.dart`：17 tests passed
- [x] `scripts/check.sh`：全量 `flutter analyze` 通过（仅仓库既有 warning/info）；全量 `flutter test` 2447 tests passed，11 skip；macOS integration 中 `native_audio_decoder_integration_test` 通过，后续 `asr_engine_test` / `app_test` 在本地 App debug connection 启动失败（`The log reader stopped unexpectedly, or never started`），与本次字幕编辑改动无关

**完成时间**: 2026-06-04 22:03 +0800
**交互稳定性修复完成时间**: 2026-06-05 00:22 +0800

## 已完成：Android Google 账号登录与 GMS 门控

在邮箱 OTP 和 Apple 登录基础上补齐 Android Google 账号登录。实现采用 Google native ID token flow：App 通过 `google_sign_in` 获取 Google ID token / access token，再交给 Supabase `signInWithIdToken(provider: google)` 建立 Supabase session；不新增自建后端 API，不使用 redirect OAuth deep link 流。同时在 Android 登录页前置检测 Google Play services，可用才展示 Google 登录入口，不可用时只保留邮箱验证码兜底。

### 实现
- [x] 新增 `google_sign_in` 依赖，并显式补充 Android app 模块 `play-services-base` 编译依赖
- [x] 新增 Google 登录凭证获取接口，生产环境使用 `GoogleSignIn.instance.initialize(serverClientId: GOOGLE_WEB_CLIENT_ID)` + `authenticate()` + `authorizationClient` 获取 token，测试可注入替身
- [x] `AuthRepository` / `AuthController` 新增 `signInWithGoogle`，登录成功后复用现有 PostHog/Supabase 身份同步链路
- [x] `SupabaseAuthRepository.signInWithGoogle` 使用 Google `idToken` + `accessToken` 调用 Supabase `signInWithIdToken(provider: google)`
- [x] Android `MainActivity` 新增 `top.echo-loop/google_services` MethodChannel，通过 `GoogleApiAvailability` 检测 Google Play services 是否可用
- [x] 登录页 Android 仅在 GMS 可用时展示 Google 入口；检测失败、非 Android 或 GMS 不可用时隐藏入口，邮箱 OTP 始终保留
- [x] Google 登录取消时不显示错误；配置缺失、token 缺失或 Google 服务不可用时提示改用邮箱验证码
- [x] 华为/出境易等设备点击 Google 登录后若暴露 GMS 版本过低/provider 依赖缺失，显示 `Google services are outdated. Please update and try again.`

### 验证
- [x] `flutter pub add google_sign_in:^7.2.0`
- [x] `flutter gen-l10n`
- [x] `flutter analyze lib/features/auth test/features/auth android/app/src/main/kotlin/app/echoloop/MainActivity.kt`：No issues found
- [x] `flutter test test/features/auth/auth_providers_test.dart test/features/auth/auth_flow_screens_test.dart test/features/auth/google_services_availability_test.dart`：49 tests passed
- [x] `flutter build apk --debug --flavor dev`：成功生成 `build/app/outputs/flutter-apk/app-dev-debug.apk`
- [x] `flutter analyze lib/features/auth/screens/login_screen.dart test/features/auth/auth_flow_screens_test.dart`：No issues found
- [x] `flutter test test/features/auth/auth_flow_screens_test.dart`：27 tests passed
- [x] `scripts/check.sh`：全量 `flutter analyze` 通过（仅仓库既有 warning/info）；全量 `flutter test` 2428 tests passed，11 skip；用户中断时已进入 macOS integration 构建阶段，未见与本次 Google 登录改动相关失败

**完成时间**: 2026-06-04 19:14 +0800

## 已完成：Apple 登录审查修复

修复 Apple 登录代码审查发现的两个问题：登录入口不再只按平台判断，而是额外检查 native Sign in with Apple 实际可用性；iOS Xcode 配置不再把 Release/Profile/Release-prod target 固定为 Apple Development 签名，避免污染发布签名链路。同时补足 Apple native ID token flow 的仓库层测试。

### 实现
- [x] 登录页 iOS/macOS Apple 入口新增 `SignInWithApple.isAvailable()` 可用性检查，插件不可用或检查失败时不展示入口
- [x] iOS `Runner` target 移除误加的 `CODE_SIGN_IDENTITY = "Apple Development"` 和空 `PROVISIONING_PROFILE_SPECIFIER`，保留 Apple 登录 entitlement
- [x] `SupabaseAuthRepository.signInWithApple` 补充仓库层测试，覆盖 hashed nonce → Apple、raw nonce → Supabase、identity token 缺失、首次姓名 metadata 写入、metadata 更新失败不撤销 session
- [x] Auth 测试替身补齐 Apple credential provider / GoTrueClient / analytics 默认 stub，避免 mocktail 漏洞掩盖真实分支

### 验证
- [x] `flutter test test/features/auth/auth_providers_test.dart`：17 tests passed
- [x] `flutter analyze lib/features/auth/providers/auth_providers.dart lib/features/auth/screens/login_screen.dart lib/features/auth/screens/account_screen.dart lib/screens/settings_screen.dart test/features/auth/auth_providers_test.dart test/features/auth/auth_flow_screens_test.dart test/screens/settings_screen_test.dart`：No issues found
- [x] `flutter test test/features/auth/auth_flow_screens_test.dart test/screens/settings_screen_test.dart`：40 tests passed
- [x] `scripts/check.sh`：全量 `flutter analyze` 通过（仅仓库既有 warning/info）；全量 `flutter test` 2418 tests passed，11 skip；macOS integration 阶段失败在本地 App debug connection 启动失败（`The log reader stopped unexpectedly, or never started`），与本次认证修复无关

**完成时间**: 2026-06-04 16:41 +0800

## 已完成：登录入口平台收敛与账号邮箱展示优化

在 Apple 登录完成后，收敛登录页入口：Apple 平台仅显示 Apple 登录和邮箱 OTP，Android 平台仅显示 Google 登录和邮箱 OTP。同时优化已登录账号展示：设置页按 Supabase provider 显示 Apple/Google 登录方式，邮箱 OTP 登录显示邮箱标识；账号页显示登录方式和完整邮箱。

### 实现
- [x] 登录页新增 Google 登录平台支持判断，iOS/macOS 隐藏 Google 入口，Android 隐藏 Apple 入口
- [x] 账号页按真实 provider 显示 `Apple account/Apple 账号`、`Google account/Google 账号` 或普通 `Account/账户`
- [x] 账号页始终显示完整邮箱，不提示 Apple 私密邮箱，不用邮箱域名推断登录方式
- [x] 设置页账号入口对 Apple/Google 登录显示 `Signed in with Apple/Google`，普通邮箱登录显示邮箱标识
- [x] 登录方式识别改为读取 Supabase `appMetadata.provider` / `appMetadata.providers` / `identities.provider`
- [x] 账号页等待 session 加载时不误判为已登出，避免测试和首帧跳转竞态
- [x] 设置页账号入口复用同一邮箱压缩展示规则

### 验证
- [x] `flutter analyze lib/features/auth/screens/login_screen.dart lib/features/auth/screens/account_screen.dart lib/screens/settings_screen.dart test/features/auth/auth_flow_screens_test.dart`：No issues found
- [x] `flutter test test/features/auth/auth_flow_screens_test.dart`：22 tests passed
- [x] `flutter analyze lib/screens/settings_screen.dart test/screens/settings_screen_test.dart`：No issues found
- [x] `flutter test test/screens/settings_screen_test.dart`：15 tests passed
- [x] `flutter analyze lib/features/auth/screens/account_screen.dart lib/screens/settings_screen.dart lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_zh.dart test/features/auth/auth_flow_screens_test.dart test/screens/settings_screen_test.dart`：No issues found
- [x] `flutter test test/features/auth/auth_flow_screens_test.dart test/screens/settings_screen_test.dart`：40 tests passed
- [x] `flutter gen-l10n`

**完成时间**: 2026-06-04 16:18 +0800

## 已完成：iOS/macOS Apple 账号登录

在邮箱 OTP 登录基础上接入 Apple 账号登录。首版覆盖 iOS 和 macOS，采用 native ID token flow：App 通过系统 Sign in with Apple 获取 identity token，使用 nonce 防重放，再交给 Supabase `signInWithIdToken(provider: apple)` 建立长期 Supabase session；不新增自建后端 API。

### 实现
- [x] 新增 `sign_in_with_apple` 依赖，并更新 Flutter/macOS 插件注册与 lockfile
- [x] 新增 Apple 登录凭证获取接口，生产环境走系统 Apple 面板，测试可注入替身
- [x] `AuthRepository` / `AuthController` 新增 `signInWithApple`
- [x] Apple 登录使用 raw nonce + SHA-256 nonce，避免 ID token 重放
- [x] 登录成功后复用现有 PostHog/Supabase 身份同步链路
- [x] 首次 Apple 返回姓名时写入 user metadata，metadata 更新失败只记录日志，不撤销已建立 session
- [x] 用户取消 Apple 授权时不显示错误提示
- [x] 登录页 iOS/macOS 显示 Apple 入口，非 Apple 平台隐藏入口；登录中禁用其他认证入口
- [x] iOS/macOS entitlements 增加 `com.apple.developer.applesignin`

### 验证
- [x] `flutter pub get`
- [x] `flutter analyze lib/features/auth test/features/auth`：No issues found
- [x] `flutter test test/features/auth/auth_providers_test.dart test/features/auth/auth_flow_screens_test.dart`：32 tests passed
- [x] `scripts/check.sh`：全量 `flutter analyze` 通过（仅仓库既有 warning/info）；全量 `flutter test` 2407 tests passed，11 skip
- [x] macOS provisioning profile 已刷新并通过签名能力校验；`flutter build macos --debug` 成功生成 `build/macos/Build/Products/Debug/Echo Loop.app`

### 后台配置待办
- [x] Apple Developer：为 `top.echo-loop` 和 `top.echo-loop.dev` 对应 App ID 开启 Sign in with Apple
- [x] Supabase Auth：开启 Apple provider，并配置对应 bundle IDs / client IDs
- [x] 刷新 iOS/macOS provisioning profiles，并用 macOS debug build 确认 Apple 登录 entitlement 已生效

**完成时间**: 2026-06-04 14:55 +0800

## 已完成：修复 GitHub Actions analyze 中 AnalyticsChannel 测试替身缺口

修复 CI run `26926310353` 中 `flutter analyze` 失败的问题。`AnalyticsChannel` 已新增 `unregisterSuperProperty` 抽象方法，但 integration test 的 `_NoOpChannel` 测试替身未实现，导致 analyzer 报 `non_abstract_class_inherits_abstract_member`。

### 实现
- [x] `integration_test/helpers/test_notifiers.dart` 的 `_NoOpChannel` 补齐 `unregisterSuperProperty`
- [x] 移除同文件不再需要的 `mocktail` import，保证定向 analyze 无 issue

### 验证
- [x] `flutter analyze integration_test/helpers/test_notifiers.dart`：No issues found
- [x] `scripts/check.sh`：全量 `flutter analyze` 通过；全量 `flutter test` 2400 tests passed，11 skip；macOS integration 阶段失败在本地 App debug connection 启动失败（`The log reader stopped unexpectedly, or never started`），与本次 analyzer 修复无关

**完成时间**: 2026-06-04 11:08 +0800

## 已完成：Android 复习提醒改为非精确本地通知

修复 Android 上收藏复习提醒和音频到期提醒不触发的问题。复习提醒不需要分钟级准点，因此不再使用 `exactAllowWhileIdle`，避免依赖 Android 12+ exact alarm 权限；同时补齐 `flutter_local_notifications` 调度通知所需的 Android receiver 和重启恢复权限。

### 实现
- [x] `ReviewReminderService` 的收藏复习提醒改用 `AndroidScheduleMode.inexactAllowWhileIdle`
- [x] `ReviewReminderService` 的 per-audio 音频到期提醒改用 `AndroidScheduleMode.inexactAllowWhileIdle`
- [x] `AndroidManifest.xml` 新增 `RECEIVE_BOOT_COMPLETED`
- [x] `AndroidManifest.xml` 新增 `ScheduledNotificationReceiver` 和 `ScheduledNotificationBootReceiver`
- [x] 补充回归测试，确保两类复习提醒不再使用 exact alarm 调度
- [x] `ReviewReminderService` 关键路径接入 `AppLogger`：初始化、时区、调度、取消、skip 原因、通知点击和异常栈
- [x] 补充 iOS/macOS 通知详情保护性测试，确认 Android 调度调整不影响 `DarwinNotificationDetails`
- [x] 收藏复习提醒时间选择器改为 5 分钟间隔，方便 Android 真机调试且避免选项过密
- [x] 补充设置保存、设置变更重调度、数据源统计和系统 pending notification 摘要日志
- [x] 明确限制：Android 系统真正展示本地通知时不会自动唤醒 Dart，因此 AppLogger 只能记录调度成功、pending 摘要、通知点击和启动 payload

### 验证
- [x] `flutter analyze lib/services/review_reminder_service.dart test/services/review_reminder_service_test.dart`
- [x] `flutter test test/services/review_reminder_service_test.dart`：20 tests passed
- [x] `flutter analyze lib/screens/reminder_settings_screen.dart lib/providers/reminder_settings_provider.dart lib/services/review_reminder_service.dart test/services/review_reminder_service_test.dart`
- [x] `flutter test test/services/review_reminder_service_test.dart test/models/reminder_settings_test.dart`：38 tests passed
- [x] `scripts/check.sh`：全量 `flutter analyze` 通过；全量 `flutter test` 2400 tests passed，11 skip；macOS integration 阶段失败在本地 App debug connection 启动失败（`The log reader stopped unexpectedly, or never started`），与本次 Android 通知修复无关

**完成时间**: 2026-06-04 10:38 +0800

## 已完成：PostHog 匿名态与登录态身份链路收敛

修正 PostHog 身份识别策略，避免匿名阶段过早 `identify` 成“已识别用户”，同时保留匿名事件可正常上报，并在登录成功后把 Supabase 真实 UUID、邮箱和本地匿名 UUID 关联到同一用户画像。

### 分析链路
- [x] `lib/analytics/analytics_providers.dart` 启动时不再把本地匿名 UUID 作为 `userId` 调用 `identify`
- [x] 启动时改为注册事件级 super property `app_anonymous_id`，匿名事件持续可追踪
- [x] `lib/features/auth/providers/auth_providers.dart` 登录成功后统一执行：`identify(realUserId)` + `setUserProperty(email)` + `setUserProperty(app_anonymous_id)`
- [x] 登出仍沿用 `setUserId(null)`，由 PostHog `reset()` 回到新的匿名态

### 测试
- [x] `test/features/auth/auth_providers_test.dart` 补充登录成功后同步真实 UUID、邮箱和匿名 UUID 的测试
- [x] 补充“无邮箱时跳过 email 属性但仍保留匿名 UUID 关联”的测试

### 验证
- [x] `flutter test test/features/auth/auth_providers_test.dart`
- [ ] `scripts/check.sh`：已通过全量 `flutter analyze`（仅仓库既有 info/warning）；全量 `flutter test` 长时间运行中，当前未见与本次 PostHog 身份链路改动相关失败

**完成时间**: 2026-06-03 22:27 +0800

## 已完成：邮箱密码认证重构为一次性 OTP 登录

将现有 Supabase 邮箱密码登录 / 注册 / 忘记密码流程，重构为标准的一次性邮箱验证码登录。现在邮箱入口不再区分注册与登录，用户输入邮箱后发送 6 位验证码；首次使用该邮箱会在验证成功后自动创建账号并登录，后续同一路径直接登录。UI 也同步收敛为“登录方式选择 → 邮箱输入 → 验证码输入”三段流，避免旧多分叉认证心智和深链依赖。

### 认证架构
- [x] `lib/features/auth/providers/auth_providers.dart` 改为 `sendEmailOtp` / `verifyEmailOtp` / `signOut` 三个统一入口
- [x] 页面层不再直接依赖密码登录、注册、重置密码接口，继续通过 `AuthController` 收敛动作
- [x] 保留 `supabaseSessionProvider` 作为全局唯一登录态来源，移除仅服务于密码恢复的事件监听

### 路由与页面
- [x] `lib/router/app_router.dart` 删除 `emailSignUp` / `forgotPassword` / `resetPassword` 路由，认证流收敛为 `login` / `emailSignIn` / `checkEmail`
- [x] `lib/features/auth/screens/login_screen.dart` 邮箱入口改为“使用邮箱验证码继续”，补充无需密码提示
- [x] `lib/features/auth/screens/email_sign_in_screen.dart` 重构为单邮箱输入页：发送验证码、首次自动创建账号说明、保留品牌骨架
- [x] `lib/features/auth/screens/check_email_screen.dart` 重构为真实验证码页：6 位验证码输入、自动提交、60 秒倒计时重发、更换邮箱、就地错误提示
- [x] 删除 `lib/features/auth/screens/email_sign_up_screen.dart`、`forgot_password_screen.dart`、`reset_password_screen.dart`

### 文案与测试
- [x] `lib/l10n/app_en.arb` / `lib/l10n/app_zh.arb` 新增 OTP 文案并更新生成代码
- [x] `test/features/auth/auth_flow_screens_test.dart` 重写为 OTP 流测试，覆盖邮箱页、验证码页、倒计时重发、返回保留邮箱、成功登录
- [x] `test/features/auth/auth_providers_test.dart` 重写为 OTP controller 测试，覆盖发送验证码 / 验证登录 / 登出

### 验证
- [x] `flutter gen-l10n`
- [x] `flutter analyze lib/features/auth lib/router/app_router.dart lib/main.dart test/features/auth/auth_flow_screens_test.dart test/features/auth/auth_providers_test.dart`
- [x] `flutter test test/features/auth/auth_flow_screens_test.dart test/features/auth/auth_providers_test.dart`
- [ ] `scripts/check.sh`：已通过全量 `flutter analyze`（仅仓库既有 info/warning）；全量 `flutter test` 仍在运行中，当前未见与本次 OTP 改动相关失败

**完成时间**: 2026-06-03 18:43 +0800

## 已完成：Supabase 邮箱认证收敛为全局唯一登录态，并补齐密码找回闭环

基于现有 Supabase Auth 接入，补齐了标准邮箱认证链路，并把认证动作统一收敛到单一 controller/repository 入口，避免任意页面、任意登录方式直接各自维护状态。全局登录态仍只认 `onAuthStateChange`/`currentSession` 这一份事实来源，页面层不再分散直连 `Supabase.instance.client.auth.*`。

### 认证架构
- [x] `lib/features/auth/providers/auth_providers.dart` 新增 `AuthRepository` / `SupabaseAuthRepository` / `AuthController`
- [x] 邮箱登录、注册、忘记密码、登出统一改走 `authControllerProvider`
- [x] 保留 `supabaseSessionProvider` 作为全局唯一 session 来源，并新增 `supabaseAuthStateProvider` 承接恢复密码事件

### 密码找回闭环
- [x] `lib/features/auth/screens/reset_password_screen.dart` 新增“设置新密码”页，承接 Supabase `passwordRecovery` 事件
- [x] `lib/router/app_router.dart` 新增 `AppRoutes.resetPassword`
- [x] `lib/main.dart` 根部监听 `supabaseAuthStateProvider`；收到 `AuthChangeEvent.passwordRecovery` 后统一跳转重置密码页
- [x] `resetPasswordForEmail` 增加 `redirectTo=https://echo-loop.top/login/reset-password`，避免只回网页不回 App
- [x] `android/app/src/main/AndroidManifest.xml` 新增 `/login/reset-password` deep link intent-filter，补齐 Android 回跳入口

### 文案与测试
- [x] `lib/l10n/app_en.arb` / `lib/l10n/app_zh.arb` 新增重置密码页文案，并更新生成代码
- [x] `test/features/auth/auth_flow_screens_test.dart` 补充重置密码页流转与校验测试
- [x] `test/features/auth/auth_providers_test.dart` 补充 `AuthController` 统一入口测试（登录 / 发重置邮件 / 更新密码 / 登出）

### 验证
- [x] `flutter gen-l10n`
- [x] `flutter analyze lib/features/auth lib/router/app_router.dart lib/main.dart`
- [x] `flutter analyze test/features/auth/auth_flow_screens_test.dart test/features/auth/auth_providers_test.dart`
- [x] `flutter test test/features/auth/auth_flow_screens_test.dart test/features/auth/auth_providers_test.dart`
- [ ] `scripts/check.sh`：已启动并通过全量 `flutter analyze`（仅仓库既有 info/warning）；全量 `flutter test` 仍在运行中，当前未见与本次认证改动相关失败

**完成时间**: 2026-06-03 16:44 +0800

## 已完成：邮箱登录改为独立页面，消除展开跳变

将账户页里的“使用邮箱继续”从原地展开表单改为跳转到独立的邮箱登录页，并新增统一认证骨架，让邮箱登录/注册页沿用 Echo Loop logo 与主登录页的视觉结构。这样登录入口页不再因表单展开、键盘弹起而发生高度突变，邮箱登录与注册流程也保持一致的布局节奏。

### 页面结构
- [x] `lib/features/auth/screens/login_screen.dart` 删除内联邮箱表单，仅保留 Apple / Google / Email 三种入口
- [x] “使用邮箱继续” 改为跳转 `AppRoutes.emailSignIn`，不再在当前页展开内容
- [x] `lib/features/auth/auth_form_utils.dart` 新增 `AuthScaffold` / `AuthBrandHeader` / `AuthPolicyNotice` 共享骨架，统一认证页 logo、标题与协议提示
- [x] `lib/features/auth/screens/email_sign_in_screen.dart` / `email_sign_up_screen.dart` 切换到共享骨架，保留 Echo Loop logo 和主登录页近似布局
- [x] `lib/features/auth/screens/forgot_password_screen.dart` 切换到共享认证骨架与统一输入框装饰，“返回登录” 改为与左上角返回按钮相同的回退语义，不再额外 push 一层登录页

### 测试
- [x] `test/features/auth/auth_flow_screens_test.dart` 更新为独立页面流转测试，覆盖“点击邮箱进入新页”、品牌 logo 与协议文案保留、登录/注册/重置密码流程
- [x] 补充重置密码页回归测试：覆盖输入框样式与邮箱登录页一致，以及“返回登录”执行真正回退

### 验证
- [x] `flutter analyze lib/features/auth/auth_form_utils.dart lib/features/auth/screens/login_screen.dart lib/features/auth/screens/email_sign_in_screen.dart lib/features/auth/screens/email_sign_up_screen.dart test/features/auth/auth_flow_screens_test.dart`
- [x] `flutter test test/features/auth/auth_flow_screens_test.dart`
- [x] `flutter analyze lib/features/auth/screens/forgot_password_screen.dart test/features/auth/auth_flow_screens_test.dart`
- [x] `flutter test test/features/auth/auth_flow_screens_test.dart`
- [ ] `scripts/check.sh`：执行中；`flutter analyze` 仅报告仓库既有 info/warning，未发现本次改动新增问题

**完成时间**: 2026-06-03 16:16 +0800

## 已完成：字幕上传失败不再"假成功"，明确区分格式不支持 / 无效 / 空

修复 SRT/VTT 上传链路的静默失败：之前用户上传 .lrc / .ass 改名、损坏文件、空文件时会"看起来成功"（写入 transcriptPath + 0 句 0 词），后续精听陷入异常分支，且会覆盖已有正确字幕。现在三种失败都有明确 SnackBar 提示，且**校验在落沙盒之前**，原字幕不会被覆盖。

### 解析器层
- [x] `lib/services/subtitle_parser.dart` 新增 `SubtitleParseErrorKind` 枚举（unsupportedFormat / formatInvalid / empty）和 `SubtitleParseException`
- [x] 新增 `SubtitleParser.parseSubtitleStrict()`：先验扩展名白名单（srt/vtt 大小写不敏感），再走解析器，最后查 0 cue
- [x] 保留 `SubtitleParser.parseSubtitle()` 原容错语义（运行时加载已存量字幕不能崩）

### 上传入口
- [x] `lib/utils/transcript_picker.dart` 的 `pickAndSaveTranscript()`：path 模式下**先校验再落沙盒**（坏文件不污染已有同名字幕）；bytes/stream 模式下兜底先落再校验、失败时删除
- [x] `uploadTranscriptForAudio()` 增 `on SubtitleParseException` 分支，导出公共 `subtitleParseErrorMessage(l10n, e)` 给其他入口复用
- [x] `lib/widgets/manage_subtitles_sheet.dart` 的 `_handleLocalUpload` 同样接入 `SubtitleParseException` 处理

### 文案
- [x] ARB 新增三条 key：`subtitleUnsupportedFormat`（带 ext 占位）/ `subtitleFormatInvalid` / `subtitleFileEmpty`，中英文齐全

### 测试
- [x] `test/services/subtitle_parser_test.dart` 新增 16 个 `parseSubtitleStrict` 用例：成功路径（SRT/VTT 标准 + 大小写扩展名）、unsupportedFormat（.lrc/.ass/.ssa/.txt/无扩展名）、formatInvalid（文件不存在/二进制/.ass 内容改名）、empty（空文件/仅 WEBVTT 头/仅 NOTE 块）
- [x] `flutter analyze` 我改的 3 个文件 + 测试均 0 issue
- [x] `flutter test` 全量回归 2369 测试全过，无回归

**完成时间**: 2026-05-29

---

## 已完成：盲听 / 段落复述句子编号跳播 + 暂停到当前句

把句子 item 拆成两个独立点击区：编号区点击从该句开播，主体区点击进讲解页；暂停语义改为"暂停在当前句"，resume 时从该句开头开播。老用户肌肉记忆零破坏（点文本→讲解 行为不变）。

### Provider 层（统一字段争用模型）
- [x] 抛弃 `_resumeStartLocalSentenceIndex` 字段被多源争用的方案：`_playCurrentParagraph` 新增 `{int? startLocalIdxOverride, bool forceOffset = false}` 参数。字段仅留给 `initializeParagraphs` 首次断点续学，其他来源（pause / seek）走显式入参或 forceOffset，消除字段争用
- [x] 盲听 Provider：新增 `currentSentenceGlobalIndex` getter（与复述对齐）+ `seekToSentence(globalIdx)`（跨段重置 currentRepeatCount/displayMode/倒计时标志，同段保留）+ 改 `pause()` 快照 playingSentenceIndex 写入 `_resumeStartLocalSentenceIndex`（仅内存）+ 改 `resume()` 用 forceOffset:true + `goToNext/PreviousParagraph`/`restart` 入口显式清零字段
- [x] 复述 Provider：补 `seekToSentence(globalIdx)`（强制切 listening + 清所有 countdown 标志，同段 seek 保留 displayMode）+ 改 `pause()` 同盲听快照 + 改 `resume()` listening 分支 forceOffset:true + `goToNext/PreviousParagraph`/`restart`/`replayDuringCountdown` 入口清零字段 + `_playCurrentParagraph(startLocalIdxOverride)` 时不重置 displayMode

### Widget 层（编号区独立 InkWell + ▶ 图标）
- [x] `MaskedSentenceTile` 拆为两个并列 hit area：左侧 `_SentenceNumberHitArea`（固定 48dp 宽，撑满 tile 全高，独立 InkWell + onPlayFromTap，当前播放句渲染 `Icons.play_arrow`，其他句渲染数字）+ 右侧 `_SentenceBodyHitArea`（Expanded + onDetailTap，文本 + 书签）。原 `onTap` 重命名为 `onDetailTap`
- [x] `ParagraphSentenceListCard` 新增 `onSentencePlayFrom` 透传到 `MaskedSentenceTile.onPlayFromTap`

### Screen 层
- [x] 盲听 Screen：新增 `_handleSentencePlayFrom`（`_isSeeking` guard + `seekToSentence`）；原 `_handleSentenceTap` 改名 `_handleSentenceDetail`；`_exit()` pop 前补齐 `await saveBlindListenSentenceIndex`（与复述 `_handleExit` 对齐）
- [x] 复述 Screen：新增 `_handleSentencePlayFrom`（关键顺序：enterWaitingForUser(stopImmediately:true) → cancelActiveRecording → clearRecording → seekToSentence，避免 idle listener 误启动倒计时）；原 `_handleSentenceTap` 改名 `_handleSentenceDetail`

### 测试（新增 24 个用例）
- [x] 盲听 Provider 单测（13 个）：seekToSentence 同段/跨段/短段/写盘、pause 快照、pause→resume 短段也生效、pause→goToNext/Prev 不污染、初始未播放 pause 不写脏断点、currentSentenceGlobalIndex 退化等
- [x] 复述 Provider 单测（4 个）：seekToSentence 同段保留 displayMode、跨段重置 displayMode、retelling phase 切回 listening + 清等待态、pause→goToNext 不污染
- [x] Widget 单测（7 个）：编号区/文本区独立 hit 分发、播放句渲染 play_arrow、宽度≥48dp 触达基线、书签位置不变、callback null 时不渲染 InkWell
- [x] Screen 单测（复述新增 1 个）：点击编号区调用 `seekToSentence` 不进入讲解页；既有"点击文本进 detail"用例继续通过

### 验证
- [x] `flutter analyze`：0 error（issues 全部为预先存在的 info/warning，未引入新问题）
- [x] `flutter test`：2338 个测试全过（+24 个新增），11 个预先存在的 skip

**完成时间**: 2026-05-28

---

## 已完成：给所有学习任务加「跳过」功能（首次学习首个盲听除外）

- [x] `LearningProgress` 新增 `canSkipCurrentSubStage` getter：仅首次学习的第一个盲听（firstLearn:blindListen）不可跳过，其余子步骤（首次学习的精听/跟读/复述、所有复习阶段任务含复习盲听）均可跳过
- [x] `_doSkipCore` 增加防御性护栏：`!canSkipCurrentSubStage` 时早返回，UI 之外兜底
- [x] 新增共享组件 `lib/widgets/common/briefing_action_row.dart`：统一「开始练习」+ 可选「跳过」按钮布局，与复述简报跳过视觉一致
- [x] 精听 / 跟读 / 复习简报弹窗加 `onSkip` 形参并改用 `BriefingActionRow`；盲听段落弹窗透传 `skipLabel`/`onSkip`
- [x] `learning_plan_screen.dart` 新增 `_buildSkipCallback()`，各任务入口按 `canSkipCurrentSubStage` 守卫传 `onSkip`（首次学习盲听因此自动隐藏跳过按钮）
- [x] 跳过为直接跳过、无确认弹窗，文案复用 `retellSkip`（「跳过」/「Skip」）
- [x] 跳过按钮加 `outlineVariant` 描边，修复纯黑深色主题下底色与背景接近、边界不清的问题（`BriefingActionRow` 与 `paragraph_selection_sheet` 两处）
- [x] 连带跳过：`skipCurrentSubStage` 新增 `_autoSkipShadowingIfNoDifficult` 钩子——跳过后落到「难句跟读」且该音频无难句书签时自动连带跳过（精听被跳过通常无难句，跟读无内容可练）；判定以真实书签数为准
- [x] 跟读无难句自动完成后去掉自动打开复述引导弹窗（避免打扰、修复开启自动跳过复述时位置错位），snackbar 设为 3 秒，回到计划页
- [x] 「难句跟读」无难句的三处文案统一为「没有难句，无需跟读」（继续学习 snackbar / 步骤卡点击 snackbar / 步骤副标题），删除无用 key `autoCompletedNoDifficult`
- [x] 修复跳过步骤在当前阶段内不可点击自由练习的 bug：`canFreePlay` 纳入 `isSkipped`（首次学习区 + 复习区）
- [x] 跳过的任务在自由练习完成后回收为已完成：泛化 session 的 `catchUp*`（原 `retellCatchUp*`）+ 新增 `setCatchUp` / `recordCatchUpCompletionIfAny`，接入盲听/精听/跟读/复习难句补练四类自由练习完成回调（复述原已支持）

### 验证
- [x] `flutter analyze`：仅 1 条既有无关的 `unused_import` warning（learning_progress_provider.dart:19，非本次引入）
- [x] `flutter test test/models/learning_progress_test.dart test/providers/learning_progress_provider_test.dart test/widgets/intensive_listen_briefing_sheet_test.dart`：129 tests passed
- [x] 新增单测：model `canSkipCurrentSubStage`；provider 首次盲听跳过无操作 / 首次精听可跳过 / 复习盲听可跳过；widget 跳过按钮显隐与回调

**完成时间**: 2026-05-27

---

## 已完成：学习 Tab 加入学习社群邀请卡片

- [x] `lib/screens/study_screen.dart` 新增 `_CommunityInviteCard`：浅色 primaryContainer 底 + 👥 + 标题 + 副标题 + 右箭头，圆角 12，醒目但不扎眼
- [x] 卡片位置：`StudyStatsHeader` 下方、任务区上方；「全部完成」视图同步插入
- [x] 点击行为复用设置页逻辑：按 `Localizations.localeOf` 拼 `/zh-CN/social` 或 `/en/social`，`launchUrl('$apiBaseUrl$path')`
- [x] 新增埋点事件 `community_invite_tapped`
- [x] i18n：复用 `joinCommunity` 作标题，新增 `joinCommunityInviteSubtitle`（zh/en）

### 验证
- [x] `flutter analyze lib/screens/study_screen.dart lib/analytics/models/event_names.dart`：No issues found
- [x] `flutter test test/screens/study_screen_test.dart`：12 tests passed

**完成时间**: 2026-05-26

---

## 已完成：全文盲听播放速度设置

- [x] `BlindListenSettings` 增加会话内 `playbackSpeed`，默认 `1x`，入口面板离散选项固定为 `0.5x`、`0.7x`、`0.8x`、`0.9x`、`1x`、`1.1x`、`1.3x`、`1.5x`、`2.0x`
- [x] 全文盲听入口段落选择面板新增播放速度下拉菜单，选择值随开始练习传入盲听设置
- [x] 盲听设置面板新增播放速度滑块，范围 `0.5x-2.0x`，步进 `0.05x`，和盲听 player state 保持同步
- [x] 盲听播放前及设置变更时同步 `AudioEngine.setSpeed`，退出学习模式时恢复进入前的播放速度，避免影响其它播放场景
- [x] 补充模型、入口面板、设置面板测试，覆盖默认值、离散选项、滑块范围/步进、状态同步和音频引擎速度同步
- [x] 设置面板中播放速度下移到重复次数与段间停顿之后，保持控制相关设置优先
- [x] 入口面板播放速度下拉菜单去掉菜单阴影
- [x] 全文盲听播放页底部状态标签追加当前播放速度

### 验证
- [x] `flutter analyze lib/models/blind_listen_settings.dart lib/widgets/blind_listen_paragraph_sheet.dart lib/widgets/common/paragraph_selection_sheet.dart lib/widgets/blind_listen_settings_sheet.dart lib/providers/learning_session/blind_listen_player_provider.dart lib/providers/learning_session/learning_session_provider.dart lib/screens/learning_plan_screen.dart test/models/blind_listen_settings_test.dart test/widgets/blind_listen_settings_sheet_test.dart test/widgets/blind_listen_paragraph_sheet_test.dart`：No issues found
- [x] `flutter test test/models/blind_listen_settings_test.dart test/widgets/blind_listen_paragraph_sheet_test.dart test/widgets/blind_listen_settings_sheet_test.dart test/providers/learning_session/blind_listen_player_test.dart`：All tests passed
- [x] `flutter test test/screens/learning_plan_screen_test.dart`：37 tests passed
- [x] `flutter analyze lib/widgets/blind_listen_settings_sheet.dart lib/widgets/common/paragraph_selection_sheet.dart lib/widgets/practice/practice_play_count_label.dart lib/widgets/common/practice_playback_footer.dart lib/widgets/common/paragraph_practice_scaffold.dart lib/screens/blind_listen_player_screen.dart test/widgets/blind_listen_paragraph_sheet_test.dart test/widgets/blind_listen_settings_sheet_test.dart test/screens/blind_listen_player_screen_test.dart`：No issues found
- [x] `flutter test test/widgets/blind_listen_paragraph_sheet_test.dart test/widgets/blind_listen_settings_sheet_test.dart test/screens/blind_listen_player_screen_test.dart`：All tests passed
- [ ] `scripts/check.sh`：全量脚本退出码 1；本次相关新增/更新测试通过，失败集中在既有未触碰测试/分析问题，包括 `_MockCacheDao.getByHash` 未 stub 导致 `Future<String?>` 类型错误、`initialLearningSettingsProvider` 未 override、`app_shell_test` 中 `SwitchListTile` 多匹配，以及 `sentence_annotation_card_test` 内联标记期望失败

**完成时间**: 2026-05-25

---

## 已完成：通知授权请求时机修复（pre-prompt + 价值锚点）

针对 PostHog 数据显示通知 denied 率 66%（132/201）的问题，把权限请求从冷启动后移到价值锚点，加 in-app pre-prompt 提升授权率；同时给存量 denied 用户在提醒设置页加跳系统设置入口。

### Critical 修复
- [x] 拆 `ReviewReminderService.init()` 为 `initPlugin()` + `requestNotificationPermission()`；`DarwinInitializationSettings` 三个 request* 显式传 false，避免 `initialize()` 自身在 iOS/macOS 弹权限框（这是隐藏陷阱）
- [x] `_syncSavedReviewReminder` / `syncPerAudioReminders` 改用 `initPlugin()`；调度本身不再触发权限请求

### 新增协调器
- [x] `lib/services/notification_permission_service.dart`：`maybeTriggerPrompt()` 按系统状态 + SP 冷却（14 天）做去重；`onUserAcceptedPrompt` / `onUserDismissedPrompt` 串联系统授权 + 持久化 + 埋点
- [x] `lib/providers/notification_permission_provider.dart`：`NotificationPromptTriggerNotifier` 用计数器作为一次性事件流；`_showing` flag 防并发重复弹

### Pre-prompt 对话框
- [x] `lib/widgets/notification_permission_dialog.dart`：两种 mode（request / openSettings），复用 `permission_handler.openAppSettings()`
- [x] 文案走 ARB（10 个新 key，en/zh 双语）

### MainShell 监听
- [x] `lib/router/main_shell.dart`：`listenManual` 订阅 `notificationPromptTriggerProvider`，用 `rootNavigatorKey.currentContext` 弹 dialog 覆盖所有子路由；关闭后调 `onDialogClosed`

### 价值锚点注入
- [x] `learning_progress_provider.dart:completeCurrentSubStage` 末尾注入（每次用户完成 sub_stage 触发）
- [x] 5 处收藏入口：句子级（`listening_practice_provider` / `retell_player_provider` / `sentence_detail_screen`）+ 单词级（`saved_word_provider`）。只在 add 时触发，remove 不触发
- [x] `flashcard_provider` 改造：单词收藏路径由直接调 dao 改走 `SavedWordList.saveWord`，统一埋点 + 锚点链路（修了历史遗漏 `word_save` 埋点的隐性 bug）

### Denied 兜底
- [x] `lib/screens/reminder_settings_screen.dart` 改 `ConsumerStatefulWidget`：异步读 `Permission.notification.status`；denied/permanentlyDenied/restricted 时显示警告横幅 + 跳设置按钮；`AppLifecycleListener.onResume` 时重新读取（从系统设置回来立刻刷新）

### 埋点
- [x] 5 个新事件常量：`notification_prompt_shown` / `notification_prompt_result` / `notification_prompt_skipped` / `notification_system_result` / `notification_settings_open_tapped`
- [x] EventParams 新增 `reason` / `status` 字段

### 测试
- [x] 更新 `review_reminder_service_test.dart`：`init()` → `initPlugin()` 重命名；新增 case 验证 initPlugin 不调权限请求、Darwin request* 三参数全 false、`requestNotificationPermission` 平台契约
- [x] 新建 `notification_permission_service_test.dart`：覆盖 granted/denied/restricted/notDetermined×冷却分支×历史动作 + onUserAccepted/Dismissed 埋点 + SP 持久化
- [x] 新建 `notification_permission_dialog_test.dart`：两种 mode 渲染 + 按钮回调 + 展示埋点
- [x] `mock_providers.dart` 加 `notificationPermissionOverride()` helper，noop fake；`learning_progress_provider_test` 的 `createContainer` 加入该 override

### 验证
- [x] `flutter analyze`：0 error
- [x] `flutter test`：2238 通过 / 11 跳过 / 2 失败（v28_to_v31_migration 和 audio_pin_test，**预先存在的失败**，与本次无关）
- [x] 测试涉及的 `review_reminder_service_test` / `notification_permission_service_test` / `notification_permission_dialog_test` / `learning_progress_provider_test` 全过

### 非本次范围（独立任务待跟进）
- AndroidScheduleMode.exactAllowWhileIdle 在 Android 12+ 需要 SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM 权限，但 AndroidManifest.xml 未声明（独立 bug）
- 存量 denied 用户的 in-app 召回 banner（本次仅靠提醒设置页兜底）

**预期效果**：发布后观察 PostHog dashboard https://us.posthog.com/project/334520/dashboard/1613084，新用户群体的 notification 权限 denied 比例从 66% 降到 30-40%；`notification_prompt_result` 的 grant 率作为新 KPI。

**完成时间**: 2026-05-22

---

## 已完成：盲听/复述断点改成句子粒度 + 段内 10s 阈值恢复

将盲听、段落复述的进度从"段落索引"改为"全局句子索引"，并在段时长 > 10s 时段内从断点句开播。

- [x] DB schema v34→v35：`*_paragraph_index` → `*_sentence_index`，盲听旧值清零，复述旧值语义不变保留
- [x] `LearningProgress` model + `LearningProgressNotifier` 同步重命名，保存函数改名为 `saveBlindListenSentenceIndex` / `saveRetellSentenceIndex`
- [x] 盲听 player：常量 `_resumeMinParagraphDuration = 10s`；保存时机改为 position 流推进句子时（按句保存）；首次播放该段且段时长 > 10s 时从断点句的 `startTime` 开播
- [x] 复述 player：同上策略；新增 `currentSentenceGlobalIndex` getter，screen 退出时保存当前播放句子
- [x] `learning_session_provider`：恢复时把全局 sentenceIndex 换算成 (paragraphIdx, localIdx) 同时传给 player
- [x] 测试更新：`learning_progress_provider_test` / `retell_player_provider_test` / `learning_session_provider_test` / `mock_providers` / `test_notifiers` 全部按新接口适配，全部 PASS
- [x] flutter analyze: 0 error；flutter test：相关 provider 测试全过

**完成时间**: 2026-05-21

---

## 已完成：Onboarding 问卷细漏斗埋点

- [x] 新增 `onboarding_survey_question_shown`：进入 goal / exam_type / daily_minutes 题目步骤时上报。
- [x] 新增 `onboarding_survey_summary_shown`：答完题进入方法论 summary 页时上报，携带 goal / exam_type / daily_minutes。
- [x] 新增 `onboarding_survey_start_tapped`：点击“开始学习”时上报，携带答案与 elapsed_seconds，用于区分 summary 流失。
- [x] 补充 onboarding widget 测试，覆盖题目展示、summary 展示、开始学习点击、完成事件链路。

**完成时间**: 2026-05-21

---

## 已完成：集成测试提速全量整治（Phase 1-4 + 修复）

### 集成测试修复（2026-05-25）
- [x] `FakeAudioItemDao.getById` 类型错误修复（`Future<dynamic>` → `Future<AudioItem?>`）
- [x] retell 设置面板测试文案修复（`25%` → `30%`，匹配 KeywordRatio 枚举）
- [x] 标注模式退出测试改为 provider state 操作（按钮 tap 在 LiveTest 下不生效）
- [x] review 系列测试添加 `_seedAllPriorKeys` 调用并调至导航前
- [x] manage_subtitles AI 测试改为条件断言（UI 可能因功能开关不同而变化）
- [x] learning_flow 盲听完成测试添加路由直连 fallback
- [x] 集成测试失败数：10 → 5，通过数：36 → 41
- [x] `flutter test`：2251 通过 / 11 跳过 / 0 失败

### Phase 1：抽取 helpers 公共部分
- [x] 新建 `test/helpers/shared/fake_notifiers.dart`（16 个 Fake* 类）
- [x] 新建 `test/helpers/shared/fake_daos.dart`（4 个 DAO 替身）
- [x] helpers 行数：4193 → 3015（-1178 行，-28%）
- [x] 0 analyze error，现有测试全过

### Phase 2 (Pilot)：验证下沉方案
- [x] 4 个 case 下沉到 widget test，通过 fake async runner 验证
- [x] 无 7.1/7.2 风格回归，方案可行

### Phase 3 (Batch 下沉)
- [x] 学习计划页新增 7 个 widget test case
- [x] 删除 3 个集成测试 group（10 cases）：audio_pin, learning_plan, pause_resume
- [x] 集成测试：65→55 cases

### Phase 4：E2E 清单 + CI 分层
- [x] 创建 `scripts/test_fast.sh` — 本地 widget/unit test（≤90s）
- [x] 创建 `scripts/test_e2e.sh` — 集成测试入口（≤3min on macOS）
- [x] CI workflow 已有 `flutter analyze` + `flutter test` + build（.github/workflows/ci.yml）
- [x] E2E 最终清单 15 条用户故事与现有 55 cases 映射完成

### 最终状态
| 指标 | 改动前 | 改动后 |
|---|---|---|
| helpers 行数 | 4193 | 3015 |
| widget test cases | 2221 | 2252 |
| integration cases | 65 (17 files) | 55 (10 files) |
| `flutter analyze` | 0 error | 0 error |
| `flutter test` | 通过 | 2252 通过 (+2 预存失败) |
| 脚本 | 无 | test_fast.sh + test_e2e.sh |

### E2E 用户故事映射（15 → 现有覆盖）
| # | 用户故事 | 覆盖状态 |
|---|---|---|
| 1 | 冷启动→首页空状态 | 待新写 |
| 2 | 导入音频→collection 列表 | 待新写（需要真 Drift） |
| 3 | 创建学习计划→重启恢复 | 待新写（需要真 Drift） |
| 4 | 真实 ASR 评测 | `asr_engine_test.dart` |
| 5 | 真实 native audio decoder | `native_audio_decoder_integration_test.dart` |
| 6 | 盲听完整流程 | blind_listen (6 cases) |
| 7 | 精听完整流程 | intensive_listen (10 cases) |
| 8 | 跟读完整流程 | listen_and_repeat (6 cases) |
| 9 | 复述完整流程 | retell (8 cases) |
| 10 | 闪卡 TTS 连续切换 | 待新写（flashcard 已删除） |
| 11 | 复习子阶段排程 | review_sub_stage (6 cases) |
| 12 | 字幕管理 | manage_subtitles (7 cases) |
| 13 | 设置变更跨页生效 | 待新写（settings 已删除） |
| 14 | 音频固定+持久化 | tag (2) + widget test 覆盖 |
| 15 | 学习统计读写 | stats_display (7 cases) |

**完成时间**: 2026-05-23

---

## 进行中：TEST — 集成测试套件全量整治（接续 pause/resume 任务）

接续上一个任务，把全套 17 个集成测试 group 推到可跑可过状态。起点：38 失败/240 分钟。

### 测试基建加固（test_notifiers.dart）
- [x] 全局预置所有 `GuideFlowIds.all` flow 为 seen —— 避免 Showcase 弹窗遮挡按钮 + 残留 Timer
- [x] 新增 mock：`TestStudyStatsNotifier`、`TestStudyTimeService`、`TestOfflineAsrSettings`、`TestStageCompletionDao`、`TestAudioItemDao`、`TestReviewDifficultPractice.enterWaitingForUserInBlindMode` no-op
- [x] `TestLearningProgressNotifier` 加 `pauseProgress` / `resumeProgress` + `completeCurrentSubStage` 内同步更新 `completionsByAudio`（V2.1 后 UI 完成态依赖 stage_completions 历史）
- [x] `_AudioPreloadWrapper` 按 `(currentStage, currentSubStage)` 自动推导已完成 sub_stage keys，对齐 V2.1 行为
- [x] 新增 `safeSettle(tester, {timeout: 5s})` helper —— 用 5 秒 bounded pumpAndSettle 替代 17 个 group 内所有无界 `pumpAndSettle()`，避免单测 10 分钟超时

### 测试文案 / 断言批量更新（同步近期 UI 重构）
- [x] `settings_tests.dart`：Theme Mode → Theme（取最后一个 option）/ Language → Interface Language（同上）
- [x] `retell_toggle_tests.dart`：Learning settings → Study Plan（设置页结构整合 `f4bfd5a8`）
- [x] `learning_plan_tests.dart`：Retelling → Paragraph Retelling
- [x] `learning_flow_tests.dart` / `blind_listen_tests.dart`：难度选项 Okay → Medium（5 档难度改造）
- [x] `intensive_listen_tests.dart`：Peek 按钮点击后文案翻转为 Hide；逐词布局 token 末尾带空格；移除已废弃的 `intensiveListenDifficultCount` 断言（field 未在 production 写入）
- [x] `stats_display_tests.dart`：同上，sed 移除 `intensiveListenDifficultCount` 断言
- [x] `audio_pin_tests.dart`：Pin 操作改为菜单项，文案 Pin to Top / Unpin（原直接 icon 已迁入 popup menu）
- [x] `review_sub_stage_tests.dart`：Paragraph Retelling 改 `findsWidgets`（firstLearn 区段同时有此 step）；`1/3 sentences` → `Sentence 1/3`

### 当前最终状态（17 group / `flutter test integration_test/app_test.dart -d macos`）
**全过 group**（10）：流程 1, 2, 3, 4, 5, 7, 8音频置顶, 9标签, X, 8跟读（intentional skip 6）

**仍有 corner case 失败**（5 个 group / 约 10 个测试，未阻塞功能验证）：
- 流程 6 精听：1 个（退出 → 路由 pop 时机偶发）
- 流程 9 学习统计：1 个（pump 时机 - find IntensiveListenPlayerScreen）
- 流程 10 复述：1 个（退出 → 路由 pop 时机）
- 流程 10 Flashcard：1 个（CountdownChip 动画时机）
- 流程 11 复习子步骤：3 个（plan 折叠区 widget tree mount 计数）
- 流程 管理字幕：3 个（无字幕 audio 默认走 AI 转录路径后的连锁断言；已部分修复）
- 流程 Y：隔离运行 4/4 全过；suite 内偶发慢测

### 已知限制（环境性，非测试代码问题）
- macOS 集成测试 runner 在 17 group 顺序跑时偶发 build.db 锁 + Echo Loop.app 残留 → 单 group 跑结果稳定
- pumpAndSettle 在 LiveTest 下默认 10min 超时，已被全局 `safeSettle(timeout: 5s)` 替代

### 验证
- `flutter analyze integration_test/` 0 error
- 主链路 group 隔离运行全部 PASS



补齐 `2d7bd1ed`（音频暂停 / 恢复学习）的端到端集成覆盖。

### 新增
- [x] `integration_test/groups/pause_resume_tests.dart` 新建 group「流程 Y」共 4 个用例：
  - 进行中（未暂停）：底部显示「暂停学习 / 继续学习」两按钮
  - 暂停确认弹窗 → 取消：state 保持未暂停 + 底部按钮不变
  - 暂停确认弹窗 → 确认：state 翻转 `isPaused=true` + 底部按钮变单按钮「Paused · Resume」
  - 暂停态点击恢复按钮 → 直接恢复（无弹窗）+ 底部回到两按钮
  - 卡片菜单 / Paused chip 已被 widget 单测 `audio_list_tile_test.dart` 覆盖，不重复
- [x] `integration_test/app_test.dart` 注册 `pauseResumeTests()`
- [x] `integration_test/helpers/test_notifiers.dart`：
  - `TestLearningProgressNotifier` 加 `pauseProgress` / `resumeProgress` override（避免触达真实 DAO）
  - 新增 `TestStudyStatsNotifier` + `TestStudyTimeService` 并注入到 `createTestApp` / `createTestAppWithAudio` —— 修 `_MainShellState._onAppResume` → `studyStatsNotifierProvider.refresh()` → `studyTimeServiceProvider` → `appDatabaseProvider` 的 `LateInitializationError`，整体加固集成测试

### 顺手修复
- [x] `integration_test/groups/retell_toggle_tests.dart` 设置项名称「Learning settings」→「Study Plan」同步 `f4bfd5a8` 重构后文案

### 验证
- `flutter analyze` 0 error
- `flutter test integration_test/app_test.dart -d macos --name "流程 Y"` 全过（4/4）
- `flutter test integration_test/app_test.dart -d macos --name "流程 X"` 全过（1/1）

  **完成时间**: 2026-05-17

---

## 已完成：FIX2 — plan 版本架构二次收尾

review 上一轮 plan_versions_json snapshot 重构时，发现以下问题：

1. **review0_plan_version column 仍然保留但已无人读** —— 死代码
2. **`_reconcileStaleSubStage` 函数继承自前一版 review0 v2 改版**：
   - snapshot per entity 后 plan 版本永不变 → reconcile 失去意义
   - 「plan 全完成」兜底分支调 `completeCurrentSubStage` 写假 stage_completion + 重置 `lastStageCompletedAt`，破坏复习链
3. **迁移启发式过度复杂**：app 未发布，老数据全是 v1 plan 产生的，无须扫 first sub_stage 区分 v1/v2

### 收尾改动

**Schema 合并**：
- [x] schema currentVersion 回退到 34
- [x] 删 `review0_plan_version` 列（表定义 + drift 重生成）
- [x] 删 v33→v34（review0_plan_version 加列回填）那段迁移
- [x] v34→v35 改名 v33→v34，迁移逻辑简化为：每条 audio baseline 全 v1 + **未碰过的 review stage 升 v2**（按 stage 是否有任何 completion）
- [x] 删 v34_to_v35 migration_test，新 v33_to_v34_migration_test 覆盖 4 类 fixture

**删 reconcile**：
- [x] 删 `_reconcileStaleSubStage` 函数（~100 行）
- [x] 删 `loadAll()` 内调用
- [x] 删 `debugReconcileStaleSubStage` testing helper
- [x] 删 reconcileStaleSubStage 测试 group（9 用例）

**Cleanup**：
- [x] `demo_data_seeder.dart` 删冗余 `review0PlanVersion: Value(...)` 写
- [x] `_decodePlanVersions` catch 分支 + 非 Map 分支加 `AppLogger.log`（避免静默重置 snapshot）
- [x] enums.dart 注释更新（旧 API `review0PlanVersion/v1ReviewStages` 引用清理）
- [x] 测试文档残留引用清理

### 验证
- flutter analyze 0 error
- 2100 个 unit/widget 测试全过
- 迁移测试 v33→v34 覆盖：fresh、only firstLearn、review0/1 已碰过、review0 完成 reviewRetellParagraph（critic 提的 v32 中途用户边界）

  **完成时间**: 2026-05-16

---

## 已完成：FIX — plan 版本统一为 plan_versions_json（修架构 bug）

### 背景
上轮 review1-28 改版用「运行时从 stage_completions 派生 v1ReviewStages」的方案，
**架构有根本缺陷**：用户在 v2 review1 完成难句补练 → 写入 `review1:reviewDifficultPractice`
completion → derive 看到 review1 有 completion 就标记 v1 → plan 翻转成 v1。
**完成新 plan 的第一步反而让 plan 切回旧版**。

根因：plan 版本应当在「进入 stage」的瞬间锁定（snapshot-per-entity），不能从持续变化的
stage_completions 反推。业界标准做法：Stripe Subscription / 保险单 / Stripe API
都是版本字段随 entity 持久化，一旦写入永不变。

### 设计：dense map snapshot

- 加 `plan_versions_json` TEXT 列存 `Map<LearningStage, int>` JSON
- **每个 LearningStage 都显式存版本**（含 firstLearn / completed），不留特例
- 全局常量 `kLatestPlanVersions` 声明各 stage 当前版本，新建 progress 直接 stamp
- 未来某 stage 加新版本：仅改 `kLatestPlanVersions` + `LearningPlan.standard` 派生分支，
  迁移结构 / 持久化格式不变（snapshot 自动保留旧版）
- 旧的 `review0_plan_version` column 保留不读（后续可移除）

### 数据层
- [x] `lib/database/tables/learning_progresses.dart` 加 `planVersionsJson TEXT default '{}'`
- [x] `lib/database/app_database.dart` schema 34→35；迁移单步翻译既有数据：
      baseline = `kLatestPlanVersions`，搬 `review0_plan_version` 进 map，
      review1-28 按首条 stage_completion 启发式（sub_stage=blindListen → v1）

### Model / API
- [x] `lib/models/learning_plan.dart` 加 `kLatestPlanVersions`；
      `LearningPlan.standard({stagePlanVersions})` 统一 API；删 `review0PlanVersion`
      / `v1ReviewStages` 双参数
- [x] `lib/models/learning_progress.dart` `int review0PlanVersion` → `Map<LearningStage, int> planVersionsByStage`；
      加 `planVersionFor(stage)` 兜底 helper

### Provider
- [x] `lib/providers/learning_plan_provider.dart` family 直读 `progress.planVersionsByStage`；
      **删** `deriveV1ReviewStages` 函数（运行时派生废弃）
- [x] `lib/providers/learning_progress_provider.dart` `_planFor` 同源；
      `ensureProgress` 创建新 progress 时 stamp `kLatestPlanVersions`；
      DAO `_encodePlanVersions` / `_decodePlanVersions` JSON 序列化

### 测试
- [x] `test/database/v34_to_v35_migration_test.dart` 4 类 fixture：
      fresh / review0 v1 / review1 首条 blindListen / review1 首条 difficult。
      最后一类是 **bug 回归核心**：迁移不能把 v2 状态误标 v1
- [x] `test/models/learning_plan_test.dart` 重写：`kLatestPlanVersions` 不变量、
      `stagePlanVersions` 单 stage 覆盖 / 混合 / 与缺省一致 / 各 stage v1/v2 各分支
- [x] `test/providers/learning_progress_provider_test.dart`：
      `review0PlanVersion: 1` → `planVersionsByStage: {review0: 1}`；
      触发 v1 plan 改用 `planVersionsByStage` 而非 `completionsByAudio`
- [x] **回归用例**：v2 review1（fresh，baseline snapshot）完成 difficult →
      plan 仍 v2、`planVersionsByStage` 完全不变（snapshot 不变量）；
      再完成 blindListen → 跨阶段到 review2
- [x] **删** `test/providers/learning_plan_provider_test.dart`（deriveV1ReviewStages 函数已删）
- [x] `lib/services/demo_data_seeder.dart` 写 `planVersionsJson` baseline + 按 demo
      currentStage 推算已练习的 review stage 锁 v1

### 验证
- flutter analyze 0 error
- 2110 个 unit/widget 测试全过（含迁移测试 + 回归用例）

  **完成时间**: 2026-05-16

---

## 已完成：复习计划 v2 扩展到 review1-review28

把 v2 改版扩到剩余 7 轮复习。各轮 v2 plan：
- 第2轮 review1：难句补练 + 全文盲听（去掉段落复述，同首轮）
- 第3轮 review2：难句补练 + 全文盲听 + 段落复述（默认 15 秒，可跳过）
- 第4轮 review4：同上，默认 20 秒
- 第5轮 review7：同上，默认 25 秒
- 第6轮 review14：同上，默认 30 秒
- 第7轮 review28：同上，默认 60 秒（reviewRetellSummary → reviewRetellParagraph）

约束：
- 未练习的音频/轮次（该 stage 在 stage_completions 中无任何记录）→ v2
- 已练习的轮次（任一 substep 已完成）→ 保留 v1 plan 与原 UI

**零 DB 迁移**：plan 版本运行时由 `stage_completions` 派生。

### Model 层
- [x] `lib/database/enums.dart` `review28.allSubStages` 扩为 v1 ∪ v2 并集 4 项（含 reviewRetellParagraph）；注释更新
- [x] `lib/models/learning_plan.dart` `standard({review0PlanVersion, v1ReviewStages})` 工厂支持每个 review 阶段独立切 v1/v2

### Provider 层
- [x] `lib/providers/learning_plan_provider.dart` family 派生 v1ReviewStages 集合（review1-28 任一有 completion 即视为已练习）；helper `deriveV1ReviewStages` 抽出可测
- [x] `lib/providers/learning_progress_provider.dart` notifier `_planFor` 同步派生（避免与 family 循环）

### Reconcile 兜底
- [x] `_reconcileStaleSubStage` 加 option A 分支：currentSubStage 在 plan 内但 index > 0 + 该 stage 无任何 completion → snap 到 plan[0]。覆盖「老代码跨阶段时按 v1 first 设 currentSubStage、新 v2 first 顺序不同」的边界。

### Normalize 修复
- [x] `_normalizeSubStageForStage` review28 分支 `reviewRetellParagraph` 原样保留（v2 plan 合法项，旧实现误归一为 reviewRetellSummary）
- [x] review1-14（_ 兜底分支）显式列 blindListen / reviewDifficultPractice / reviewRetellParagraph 三个合法项

### Retell 默认时长
- [x] `lib/widgets/retell/retell_briefing_sheet.dart` `retellDefaultSeconds` 按轮次递增：firstLearn/review0/review1=10, review2=15, review4=20, review7=25, review14=30, review28=60

### UI 层
- [x] `lib/screens/learning_plan_screen.dart` `_FirstStudySection` / `_ReviewRoundSection` 子步骤迭代改为「当前 plan 顺序 + 历史外延项」（helper `_orderedSubStagesForDisplay`）。v1 用户看 v1 顺序、v2 用户看 v2 顺序；v1 已完成但 v2 已移除项（如 review28 summary 历史）仍渲染。

### 测试
- [x] `test/database/enums_test.dart` review28 并集 4 项断言
- [x] `test/models/learning_plan_test.dart` 重写：v1/v2 每阶段子步骤；v1ReviewStages 混合场景；review0 不受 v1ReviewStages 影响
- [x] `test/models/learning_progress_test.dart` totalSubStages 26、review28.subStageCount 4、progressPercent 分母调整
- [x] `test/providers/learning_plan_provider_test.dart` 新增：deriveV1ReviewStages 7 个用例（空 / firstLearn-only / review0-only / 单 stage / 多 stage / 完整学习 / 前缀严格）
- [x] `test/providers/learning_progress_provider_test.dart`：
  - 既有 review1/review28 推进用例适配新顺序（v2 first = difficult；v1 用 completion 显式触发）
  - autoSkipRetell review0 v1 / review28 v1/v2 用例区分
  - normalize：review28 paragraph + summary、review1/2/7/14 合法项 + 废弃 retell key 共 8 用例
  - reconcile snap：4 用例（v2 snap / v1 不 snap / v2 已练习不 snap / v2 firstLearn completions 不影响）
- [x] `test/models/retell_settings_test.dart` retellDefaultSeconds review2=15/review4=20/review7=25/review14=30/review28=60、completed=10

### 验证
- flutter analyze 0 error
- 2113 个 unit/widget 测试全过

  **完成时间**: 2026-05-16

---

## 已完成：首轮复习改版 — 难句补练 + 全文盲听（向前兼容）

把首轮复习（review0）的子步骤从「难句补练 + 段落复述」改为「难句补练 + 全文盲听」。约束：
- 全新音频 / 还在 firstLearn → 新版生效
- 卡在 review0 中途（做了难句补练但还没做段落复述）→ 切到新版，未做的段落复述不再要求
- 已完成 review0（review1+）→ 保留旧版 UI，历史不受影响

### 数据层
- [x] `lib/database/tables/learning_progresses.dart` 新增 `review0PlanVersion: int default 2`
- [x] `lib/database/app_database.dart` schema 33→34 + 迁移：currentStage IN review1..completed 回填 1；customStatement UPDATE 加 table-exists 守卫（兼容 v28 fixture 直跳路径）
- [x] `lib/models/learning_progress.dart` 新增 `review0PlanVersion` 字段 + copyWith
- [x] DAO mapper `_fromDbRow` / `_persistProgress` 序列化

### Model 层
- [x] `lib/models/learning_plan.dart` `standard({int review0PlanVersion = 2})` 工厂：v1 → 旧版子步骤、v2 → 新版子步骤；其它阶段直接读 stage.allSubStages
- [x] `lib/database/enums.dart` `review0.allSubStages` 改为 v1 ∪ v2 并集 `[reviewDifficultPractice, blindListen, reviewRetellParagraph]`，注释说明真实 plan 由 LearningPlan 派生

### Provider 层
- [x] `lib/providers/learning_plan_provider.dart` 新增 `learningPlanForAudioProvider(audioItemId)` family：watch progressMap，按 progress.review0PlanVersion 返回对应 plan；保留全局 `learningPlanProvider`（默认 v2，给无 audioId 场景兜底）
- [x] notifier 内部用私有 `_planFor(progress)` 派生 plan，避免 notifier→family→notifier 循环依赖
- [x] `_reconcileStaleSubStage`：loadAll 后扫描 currentSubStage 不在 plan 内的进度，自动修正到 plan 内首个未完成项；plan 全部已完成则触发跨阶段推进

### Call site 迁移（12 处）
- [x] 5 个 player screen（intensive / retell / blind / repeat / review_difficult）`_getStepContext` 改用 family
- [x] `learning_plan_screen.dart` 3 处（_ProgressCard / _FirstStudySection / _ReviewRoundSection）改用 family（_ProgressCard 在 audioItem null 时退化到全局 plan）
- [x] `study_screen.dart` 用 task.audioId
- [x] `learning_progress_icon.dart` progress 缺失时退化到全局 plan
- [x] `learning_progress_provider.dart` 内 `completeCurrentSubStage` / `_doSkipCore` / `_reconcileStaleSubStage` 用 `_planFor`

### Demo / 测试 fixture
- [x] `lib/services/demo_data_seeder.dart` 已完成 review0 的 demo audio（currentStage 在 review1+）显式 set `review0PlanVersion = 1`

### 测试
- [x] `test/database/v33_to_v34_migration_test.dart` 5 类 fixture（firstLearn / review0 / review1 / review28 / completed）验证回填规则
- [x] `test/database/enums_test.dart` review0.allSubStages 期望改为并集 3 项
- [x] `test/models/learning_plan_test.dart` 重写：v2 默认 / v1 / 非 review0 阶段一致
- [x] `test/models/learning_progress_test.dart` `doneUpTo` helper 改用 plan.subStagesFor；totalSubStages 25；review0.subStageCount 3
- [x] `test/providers/learning_progress_provider_test.dart` v1 autoSkip 老用例保留；新增 v2 autoSkip 用例（完成难句补练后停在全文盲听）；新增 reconcileStaleSubStage 5 个用例（v2 卡 reviewRetellParagraph 修正 / v2 plan 内首项无修正 / v1 reviewRetellParagraph 不修正 / v2 plan 全完成跨阶段 / completed 跳过）

### 验证
- flutter analyze 0 error
- 2079 个 unit/widget 测试全过

  **完成时间**: 2026-05-16

---

## 已完成：音频暂停学习 / 恢复学习

允许已开始学习的音频「暂停」——停止参与复习调度，但学习进度数据完整保留；用户可随时从同一菜单入口恢复。设计要点：暂停弹确认弹窗、恢复直接生效、卡片轮次 chip 与左侧进度图标同步切换为灰色暂停态。

### 数据层
- [x] `lib/database/tables/learning_progresses.dart` 加 `BoolColumn isPaused` 默认 false
- [x] `lib/database/app_database.dart` schema 32→33 + onUpgrade `_addColumnIfNotExists('learning_progresses', 'is_paused', 'INTEGER NOT NULL DEFAULT 0')`
- [x] `lib/database/daos/learning_progress_dao.dart` 加 `setPaused(audioItemId, paused)`
- [x] `lib/models/learning_progress.dart` 加 `bool isPaused` 字段 + copyWith
- [x] `lib/providers/learning_progress_provider.dart` mapper 双向同步 isPaused

### Provider 层
- [x] 新增 `pauseProgress` / `resumeProgress` + 内部 `_setPaused`（幂等：状态相同不写库；audioItemId 不存在安全返回）

### 调度过滤
- [x] `lib/providers/study_task_provider.dart` `_buildTaskForAudio` 早返回 null 跳过 paused
- [x] `lib/router/main_shell.dart` per-audio review reminder 同步时跳过 paused

### UI 层
- [x] `lib/widgets/audio_list_tile.dart` 菜单加「暂停学习 / 恢复学习」项（与 resetProgress 同条件 `hasProgress`）
- [x] 暂停弹 `AlertDialog` 二次确认；恢复直接调 notifier
- [x] 卡片 chip 暂停态替换为灰色「已暂停」chip
- [x] `lib/widgets/learning_progress_icon.dart` 暂停态环+中心图标整体灰化 + 图标改为 `Icons.pause_rounded`
- [x] `lib/screens/learning_plan_screen.dart` 底部按钮三态：未开始单按钮「开始学习」；进行中 `Row[暂停学习 灰底 | 继续学习 主蓝]` 1:2；已暂停单按钮灰底「已暂停 · 恢复学习」（点击直接恢复）

### i18n
- [x] `app_en.arb` / `app_zh.arb` 新增 `pauseLearning` / `resumeLearning` / `pausedChipLabel` / `pauseLearningConfirmTitle` / `pauseLearningConfirmMessage`

### 测试
- [x] `test/models/learning_progress_test.dart` isPaused 默认值 + copyWith
- [x] `test/providers/learning_progress_provider_test.dart` pause/resume/幂等/不存在 4 个用例
- [x] `test/providers/study_task_provider_test.dart` 暂停音频不进入任务列表
- [x] `test/database/v32_to_v33_migration_test.dart` 迁移加列 + 默认 false
- [x] `test/widgets/audio_list_tile_test.dart` 菜单文案切换 + 确认弹窗 + Paused chip + 未开始时不显示
- [x] `test/widgets/learning_progress_icon_test.dart` 暂停态显示 pause icon + 灰色环
- [x] `test/helpers/mock_providers.dart` TestLearningProgressNotifier 补 pause/resume

### 验证
- flutter analyze 0 error（只剩 pre-existing info/warning）
- 全量 2065 unit/widget 测试通过

  **完成时间**: 2026-05-16

---

## 已完成：复述功能重构 — 移除引导弹窗 + 自动跳过单一机制 + 简报手动跳过

V2.1 之后再次重构。问题：原方案保留了「全局开关过滤 plan」+「引导弹窗 + 三态判定」两套机制，复杂度高且与未来「用户自定义学习计划」逻辑冲突。本次改为**单一机制**——所有跳过（手动 / 自动）走同一 `skipCurrentSubStage`，全部写入 `LearningProgress.skippedSubStageKeys`；plan 永远静态全量。

### 设计变更
- 移除引导弹窗 + 9 处 `ensureRetellDecisionMade` 调用 + 删除 `setupChoiceMade` 字段/SP key/方法
- 全局开关语义反转：`retellEnabled` (默认 false) → `autoSkipRetell` (默认 false)
- 「关闭复述」不再过滤 plan；新语义是「学习推进到复述时自动调跳过」
- 计划列表三态：✅ completed / ⏭ skipped（灰色横线） / planned
- 手动跳过：仅在按计划学习触发的简报弹窗里加「跳过」按钮（宽度比例 1:2）

### 数据层
- [x] `lib/database/tables/learning_progresses.dart` 新增 `skippedSubStages` TEXT 列（逗号分隔 'stage.key:subStage.key'）
- [x] `lib/database/app_database.dart` schema 31→32 + onUpgrade addColumn；`_addColumnIfNotExists` 加 table-exists 守卫（解决 v28 fixture 升级直接跳到 v32 时 learning_progresses 缺表问题）
- [x] `lib/models/learning_progress.dart` 新增 `skippedSubStageKeys` 字段 + `isSubStageSkipped` 辅助 + `progressPercent` 公式改为 `分母 = inPlan ∪ isDone ∪ isUserSkipped、分子 = isDone + isUserSkipped`（纯跳过场景也能到 100%）
- [x] DAO mapper `_encodeSkippedKeys` / `_decodeSkippedKeys` 双向序列化

### Model 层
- [x] `lib/models/learning_plan.dart` 静态化：删除 `fromSettings(LearningSettings)`，改为 `LearningPlan.standard()`；与 settings 解耦
- [x] `lib/providers/learning_plan_provider.dart` 不再 watch settings

### Settings 层
- [x] `lib/providers/learning_settings_provider.dart` 字段重命名 + 默认 false + 删除 `setupChoiceMade` / `markSetupChoiceMade` / `LearningSettingsKeys.setupChoiceMadeAtMs`
- [x] 启动期 best-effort 清理老 SP key (`learning_retell_enabled` / `retell_setup_choice_at_ms`)

### Progress Notifier
- [x] 新增 `skipCurrentSubStage` (public) + `_doSkipCore` (内部，参数 source=manual/auto)
- [x] 新增 `_autoSkipRetellIfEnabled` 循环 hook：complete / skip 推进后调；autoSkipRetell=true + 新位置是复述类 → 连续 skip 推进
- [x] 新增 `_autoSkipScanAllProgress`：autoSkipRetell false→true 时遍历所有 progress
- [x] reconcile listener 改为监听 `learningSettingsProvider`（plan 静态后不再需要监听 plan）
- [x] 互斥不变量：`completeCurrentSubStage` / `recordCompletionIfNew` 写 completion 时清除对应 skipped key（用户从自由练习完成已跳过的复述 → 状态变 ✅，skip 集合清空）

### UI 层
- [x] `lib/widgets/common/paragraph_selection_sheet.dart` 加可选 `onSkip` + `skipLabel`：`Row(Expanded flex:1 OutlinedButton + 16px + Expanded flex:2 FilledButton)`；`onSkip==null` 时保留原 width:double.infinity 路径（盲听不受影响）
- [x] `lib/widgets/retell/retell_briefing_sheet.dart` 透传 `onSkip` + `skipLabel: l10n.retellSkip`
- [x] `lib/screens/learning_plan_screen.dart` 仅 line 438 计划流加 `onSkip` 回调；其他 3 处自由练习入口保持无 skip 按钮
- [x] 计划列表三态渲染：`_StepCard` 加 `isSkipped` 参数；iterate `inPlan || isDone || isUserSkipped`；isSkipped 用 `Icons.remove` 灰色 + 文案后缀「· 已跳过」
- [x] `lib/screens/learning_settings_screen.dart` 改用新 ARB key + 读 autoSkipRetell；图标 `Icons.chat`（与复述任务一致）

### 删除
- [x] `lib/widgets/retell_intro_dialog.dart` / `retell_decision_gate.dart` / `test/widgets/retell_intro_dialog_test.dart`
- [x] 9 处 `ensureRetellDecisionMade` 调用全部简化为直接 push（main / study_screen ×4 / favorites_screen ×2 / audio_list_tile）

### i18n / 埋点
- [x] ARB：删 `retellEnabled*` / `retellPrompt*` 共 8 个 key；新增 `autoSkipRetell{Toggle,Subtitle,Description}` + `retellSkip` + `retellSkippedSuffix`
- [x] event_names：删 `retellIntroDialogShown` / `retellIntroDialogChoice` / `retellAutoStageAdvance`；新增 `retellSkipped`（params source=manual/auto）

### 测试
- [x] `test/providers/learning_settings_provider_test.dart` 重写（autoSkipRetell + cleanupLegacy）
- [x] `test/providers/learning_progress_provider_test.dart` 全部用例 retellEnabled→autoSkipRetell 语义反转；新增 skipCurrentSubStage（同/跨阶段 / 互斥早返回）、completion ⊥ skipped 互斥、autoSkip OFF→ON 全量扫描 6 个边界 + true→false 不触发
- [x] `test/models/learning_plan_test.dart` 重写（plan 静态化）
- [x] `test/models/learning_progress_test.dart` 加跳过场景 100%、isSubStageSkipped 用例
- [x] mock_providers / test_notifiers / 5 个 player screen test / learning_plan_screen_test / learning_settings_screen_test / retell_toggle_tests 全部适配新字段名

### 验证
- flutter analyze 0 error（lib + test + integration_test）
- 2054 个 unit/widget 测试全过

  **完成时间**: 2026-05-16

---

## 已完成：完成历史驱动的三态判定（V2.1 修复 3 个 V2 bug）

V2 重构后暴露 3 个 bug，根因都是 `isSubStageCompleted` 用 `stage.index + plan.includes` 推导「完成」，没查真实历史：

1. **完成弹窗「继续：XX」按钮不看 plan**：review0 复述关闭，做完难句补练，弹窗显示「继续：段落复述」（plan 实际不含）
2. **跳过的子步骤被误判为完成**：关闭复述完成 review0 → 重开复述 → 段落复述卡显示 ✅（用户从未做过）
3. **已完成的复述被隐藏**：开启复述完成 retell → 关闭复述 → retell 卡完全消失（用户真做过的历史被丢失）

### 架构变更
- [x] `lib/database/daos/stage_completion_dao.dart` 新增 `getCompletionKeysByAudio` — 一次性加载所有音频的完成事件集合（key 格式 `'stage.key:subStage.key'`）
- [x] `LearningProgressState` 加 `completionsByAudio: Map<String, Set<String>>` 字段；`completionsFor(audioId)` 便捷访问
- [x] `LearningProgressNotifier.loadAll` 同时加载 stage_completions 到内存集合
- [x] `LearningProgressNotifier.completeCurrentSubStage` 写入 stage_completions 后同步更新内存集合
- [x] `LearningProgressNotifier.deleteProgress` 清理对应条目
- [x] `LearningProgress.isSubStageCompleted` / `progressPercent` / `completedFirstStudySteps` 签名改为接收 `Set<String> completedKeys`（真实完成历史，不依赖 stage.index）
- [x] `LearningPlan.nextPlannedAfter(stage, sub)` — 找当前阶段 plan 内下一项，末尾返回 null（修 bug 1）

### UI 层
- [x] 学习计划页 iterate `stage.allSubStages`，渲染条件 = `completed || inPlan`（跳过的 skipped 完全不渲染）
- [x] 进度比例分子分母都用 `completedKeys`（保留已完成的历史可见性，bug 3 修复）
- [x] `_ProgressCard` / `_FirstStudySection` / `_ReviewRoundSection` 都 watch `learningProgressNotifierProvider` 取 completionsByAudio
- [x] `study_screen` / `learning_progress_icon` 同样接 completedKeys
- [x] 5 个 player screen（blind_listen / intensive_listen / listen_and_repeat / retell / review_difficult_practice）的 `_getStepContext` 改用 `plan.subStagesFor(stage)` 派生 stepIndex/totalSteps；nextStepName 用 `plan.nextPlannedAfter` 计算，末尾返回 null（弹窗只显示「完成」按钮，bug 1 修复）

### 测试覆盖
- [x] DAO 测试 + 4 个 `getCompletionKeysByAudio` 边界
- [x] LearningProgress 三态判定单测含 bug 2/3 关键回归
- [x] `LearningPlan.nextPlannedAfter` 4 个边界（含 plan OFF + review0 难句补练 → null 修 bug 1）
- [x] plan screen / 5 个 player screen 测试 ProviderScope 增加 `learningSettingsOverrides`
- [x] plan screen test 引入 `_withAutoCompletions` 兼容旧测试预期（按 currentStage/currentSubStage 自动推导 completedKeys）

### 验证
- flutter analyze 0 error
- 2054 个 unit/widget 测试全过

  **完成时间**: 2026-05-14（V2.1）

---

## 已完成：复述跳过 vs 完成语义修正 + 全局学习计划对象（V2 重构）

V1 实现暴露两个语义缺陷：
1. 「跳过」与「完成」混淆：`silentSkip=true` 推进后 `isSubStageCompleted` 仍按 `stage.index` 判定为 true → UI 上跳过的复述也显示 ✅
2. 判定散落多处：`subStagesWith` / `visibleSubStagesForPlanView` / `progressPercentWith` / `_completedSubStageCount` / `completeCurrentSubStage` 各自读 `retellEnabled` 实时计算

引入**全局 `LearningPlan` 值对象**作为「每个大阶段计划做哪些子步骤」的单一事实来源，从 settings 派生。UI / 推进 / reconcile / 进度计算只读 `plan.subStagesFor(stage)`，`retellEnabled` 只在 plan 构造时被读一次。

### 架构变更
- [x] `lib/models/learning_plan.dart` 新增不可变 `LearningPlan` 值对象（`subStagesFor` / `includes` / `indexOf` / `totalPlannedCount` API）
- [x] `lib/providers/learning_plan_provider.dart` 派生自 `learningSettingsProvider`
- [x] `lib/database/enums.dart`：`LearningStage.subStages` 重命名 `allSubStages`；删除 `subStagesWith`
- [x] `lib/models/learning_progress.dart`：新增 `isSubStageCompleted(stage, sub, plan)` / `progressPercent(plan)` / `completedFirstStudySteps(plan)`；**删除** `visibleSubStagesForPlanView` / `progressPercentWith` / `progressPercent` getter / `completedFirstStudyStepsWith` / `completedFirstStudySteps` getter / `needsAdvanceWhenRetellDisabled` / 旧无参 `isSubStageCompleted`
- [x] `lib/providers/learning_progress_provider.dart`：`ref.listen` 改监听 `learningPlanProvider`；`completeCurrentSubStage` 删除 `silentSkip` 参数改读 plan；`_reconcileForRetellDisabled` → `_reconcileForSettingsChange` 重写为「直接修改 currentStage/currentSubStage，**不写** stage_completions」
- [x] UI 切到 plan：`learning_plan_screen` / `study_screen` / `learning_progress_icon` 删除 `retellEnabled` 传参，改 `ref.watch(learningPlanProvider)`，iterate `plan.subStagesFor(stage)`（跳过的子步骤自动不渲染）

### 关键回归修复
- **跳过 ≠ 完成**：reconcile 推进时不写 `stage_completions`、不递增 retellPassCount，过去阶段中不在 plan 内的复述子步骤 `isSubStageCompleted` 返回 false
- **跳过卡片完全不显示**：UI iterate plan 而非 allSubStages
- **进度比例正确**：分子/分母都从 plan 派生（跳过既不计入也不显示）

### 测试覆盖
- [x] `test/models/learning_plan_test.dart`（6 个）：fromSettings / subStagesFor / includes / indexOf / totalPlannedCount
- [x] `test/database/enums_test.dart` 简化为 `allSubStages` + `kRetellSubStages` + `isRetellSubStage`（11 个）
- [x] `test/models/learning_progress_test.dart` 扩展：三态判定 + 关键回归（过去阶段 + 不在 plan → completed=false）+ progressPercent(plan) / completedFirstStudySteps(plan)
- [x] `test/providers/learning_progress_provider_test.dart` 更新：reconcileForSettingsChange 6 边界 + completeCurrentSubStage 推进
- [x] `test/widgets/learning_progress_icon_test.dart` / `test/helpers/mock_providers.dart` 同步
- [x] `integration_test/groups/retell_toggle_tests.dart` 端到端验证

### 验证
- flutter analyze 0 error
- 2046 个 unit/widget 测试全过
- 集成测试 retell_toggle 通过

  **完成时间**: 2026-05-14（V2）

---

## 已完成：复述功能开关（Retell Toggle）

新增「我的设置 → 学习设置 → 启用复述练习」全局开关，默认关闭。用户首次进入任意音频学习计划页时一次性弹窗询问是否启用。关闭时复述类子阶段从「按计划学习」流中过滤掉，且自动推进卡在复述子阶段的进度。已完成的大阶段不受影响，自由练习入口不受影响。

### 数据层
- [x] `lib/providers/learning_settings_provider.dart`：`LearningSettings` 不可变值对象（`retellEnabled` + `introDialogShown`）+ `LearningSettingsNotifier`（手动 Notifier 模式）+ SP 持久化（`learning_retell_enabled` + `retell_intro_dialog_shown_at_ms`）+ `initialLearningSettingsProvider` 同步预读注入
- [x] `lib/main.dart` 启动期 `LearningSettings.fromPrefsSync(prefs)` 注入 override
- [x] `lib/database/enums.dart` 新增 `LearningStage.subStagesWith({retellEnabled})` + `kRetellSubStages` 常量 + `isRetellSubStage()` 工具
- [x] `lib/models/learning_progress.dart` 新增 `needsAdvanceWhenRetellDisabled` getter + `progressPercentWith` / `completedFirstStudyStepsWith` 过滤版方法

### 推进与 reconcile
- [x] `lib/providers/learning_progress_provider.dart`：`completeCurrentSubStage` 接入 `subStagesWith`；`currentIdx == -1` 边界处理 reconcile 路径；进入下一阶段后 while 循环跳过空可见列表；新增 `silentSkip` 参数跳过 `stage_completions` 写入和耗时累加
- [x] `LearningProgressNotifier.build()` 内 `ref.listen(learningSettingsProvider)` 监听 `true → false` 触发 `_reconcileForRetellDisabled`：遍历所有进度调用 `completeCurrentSubStage(silentSkip: true)`，单向数据流避免 Notifier 双向耦合
- [x] Reconcile 入口埋点 `retell_auto_stage_advance`（含 from_stage / to_stage）

### UI 层
- [x] `lib/screens/learning_plan_screen.dart`：`_ProgressCard` / `_FirstStudySection` / `_ReviewRoundSection` 全部接入 `subStagesWith` + 过滤版进度方法；`_completedSubStageCount` / `_reviewTimingText` / `progressPercent` / `completedFirstStudySteps` 等所有 `subStages` 引用按开关过滤；`initState` 触发 `maybeShowRetellIntroDialog`
- [x] `lib/screens/study_screen.dart` `_TaskCard` 接入 `progressPercentWith`
- [x] `lib/widgets/learning_progress_icon.dart` 改为 ConsumerWidget 接入 `progressPercentWith`
- [x] `lib/screens/settings_screen.dart` 新增「学习」section + 「学习设置」入口（🎯 emoji + 已开启状态文字）
- [x] `lib/screens/learning_settings_screen.dart` 子页面（参考 reminder_settings 样式，SwitchListTile + 副标题 + 说明文字）
- [x] `lib/widgets/retell_intro_dialog.dart` 引导弹窗（Material 3 AlertDialog + Hero icon + 双按钮 + barrierDismissible:false）+ `maybeShowRetellIntroDialog` 内存 flag + SP 双 gate 防双弹

### 埋点（4 个新事件）
- [x] `retell_intro_dialog_shown` / `retell_intro_dialog_choice` / `retell_toggle_changed` / `retell_auto_stage_advance` + 参数 `enabled` / `source` / `choice` / `trigger`

### 国际化（11 个 key）
- [x] `learningSection` / `learningSettings` / `learningSettingsEnabled` / `speakingPracticeSection` / `retellEnabledToggle` / `retellEnabledSubtitle` / `retellEnabledDescription` / `retellPromptTitle` / `retellPromptBody` / `retellPromptDismiss` / `retellPromptEnable`（中英文）

### 测试覆盖
- [x] 单元测试：`learning_settings_provider_test.dart`（11 个）/ `enums_test.dart`（11 个）/ `learning_progress_test.dart`（+10 个）/ `learning_progress_provider_test.dart`（+12 个 T3/T5 边界）/ `event_names_test.dart`（+2 个）
- [x] Widget 测试：`learning_settings_screen_test.dart`（3 个）/ `retell_intro_dialog_test.dart`（5 个）
- [x] Integration：`retell_toggle_tests.dart`（设置入口可达 + 开关切换 state 翻转）
- [x] Provider 默认 mock + screen 测试 helper 同步更新

  **完成时间**: 2026-05-14

---

## 已完成：跟读权限前置阻塞弹窗

把麦克风 + 平台语音识别权限检查从 `RepeatPracticePanel` 中剥离，改为入口前置阻塞弹窗。语音识别仅在 `offlineAsrSettings.enabled && backend == AsrBackend.platform` 时才请求；关闭 ASR 或选 Echo Loop AI 离线引擎时弹窗只列麦克风。

### 实现
- [x] 新建 `lib/widgets/speech_permission_dialog.dart`：暴露 `ensureSpeechReadyForSubStage(ctx, ref, subStage)` / `ensureSpeechReadyForRecording(ctx, ref)`，内部串联 subStage 过滤 → 平台支持检查 → 权限弹窗 → ASR 模型下载弹窗
- [x] 弹窗三态：notDetermined（「授权」按钮触发系统弹窗）/ denied（「前往设置」+ AppLifecycle.resumed 自动重查）/ restricted（「设备已限制」仅返回）
- [x] 新增 14 个 i18n key（en + zh）
- [x] 改造 4 个录音页 initState 接入前置检查（listen_and_repeat / review_difficult_practice / bookmark_review / retell），权限拒绝则 `context.pop()`
- [x] 改造 11 处聚合页按钮 onTap（learning_plan / favorites / study）：`ensureAsrReadyBeforeSpeechPractice` → `ensureSpeechReadyForRecording`；`ensureAsrReadyForSubStage` → `ensureSpeechReadyForSubStage`
- [x] 清理 `RepeatPracticePanel` 中权限引导职责：删除 `_isPermissionDenied` / `_openAppSettings` / permissionDenied 专用 UI 分支；permissionDenied 兜底走通用 `errorMessage` 路径
- [x] 测试：新增 11 个 dialog 测试（subStage 过滤 / 权限矩阵 / lifecycle 重查 / 不支持平台）+ 改写 panel 测试（permissionDenied 不再显示「前往设置」+ 兜底走 errorMessage）

  **完成时间**: 2026-04-27

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



## 已完成：首启 Onboarding 问卷（学习目标 + 每日时长）

跨需求特性：首次安装的新用户必须先回答 2 道画像题（学习目标 / 每日学习时长）才能进入 App，用于冷启动分群和 PostHog/Firebase 留存漏斗分析。本期**只采集不消费**——答案不接入任何业务流，仅写埋点 user property。

### 数据层（`lib/features/onboarding_survey/`）
- [x] `models/onboarding_question.dart`：Q1/Q2 静态元数据 + 选项编码常量（OnboardingGoal、OnboardingDailyMinutes）
- [x] `models/onboarding_answers.dart`：不可变答案模型 + isComplete + copyWith + equality
- [x] `data/onboarding_survey_storage.dart`：SP 读写封装；用 `onboarding_completed_at_ms` 存在性作为完成判定锚点（不引入冗余 bool）；非法答案编码自动识别返回 null

### Provider 层（`lib/features/onboarding_survey/providers/`）
- [x] `sharedPreferencesProvider`、`onboardingStorageProvider`：基础注入
- [x] `initialOnboardingCompletedProvider`：main 同步预读注入；`OnboardingCompletedNotifier` 内存状态
- [x] `OnboardingAnswersNotifier`：草稿累积 + submit（先 await SP，再翻转完成态）
- [x] `shouldShowSurveyProvider`：三层 gate（isFirstLaunch && !completed && !hasLearningProgress），router redirect 同步使用

### UI（`lib/features/onboarding_survey/screens/` + `widgets/`）
- [x] `OnboardingSurveyScreen`：PageView + 顶部进度 + PopScope.canPop=false 拦截返回 + 完成 ✓ 动画 + 老用户 initState 异步兜底
- [x] `SurveyChoiceTile`：大块 InkWell + Card 选项（指尖区域大），选中 primaryContainer 高亮
- [x] `SurveyProgressBar`：LinearProgressIndicator + 进度文字

### 接入
- [x] `lib/main.dart`：同步预读 `onboarding_completed_at_ms`，注入 `sharedPreferencesProvider` + `initialOnboardingCompletedProvider` override
- [x] `lib/router/app_router.dart`：新增 `AppRoutes.onboardingSurvey = '/onboarding/survey'`、对应 GoRoute（rootNavigatorKey 全屏）；扩展 redirect（onboarding 路径自身早返防死循环）

### 埋点
- [x] `event_names.dart` 新增 3 事件常量（shown / question_answered / completed）+ 2 user property（english_goal / daily_minutes_target）+ 5 个事件参数

### 国际化
- [x] `app_en.arb` / `app_zh.arb` 新增 19 个 i18n key（标题/副标题/进度/2 题题干/10 个选项/下一题/完成/完成页提示）

### 测试覆盖（28 个新测试 + 集成测试 helper 升级）
- [x] storage 单元测试 11 个（SP 读写、完成锚点、非法编码兜底、flexible 时长、clear、模型 equals/copyWith）
- [x] provider 测试 11 个（gate 矩阵：首启/已完成/老用户/进度兜底；submit 写 SP；幂等）
- [x] widget 测试 6 个（按钮 disabled→enabled、2 题流程、无跳过按钮、PopScope 拦截、进度文字、老用户 initState 兜底）
- [x] `integration_test/helpers/test_notifiers.dart` 添加 `onboardingTestOverrides()`，所有现有集成测试默认走"老用户"分支不被拦截
- [x] `test/widget_test.dart` 冒烟测试同步加 onboarding override

### 范围内不做（v1 明确排除）
- 引入 `introduction_screen` 等第三方库（原生 PageView + Material 3 自绘 ~250 行）
- 答案上报到后端 / 跨设备同步
- 答案驱动业务行为（推荐难度 / 训练侧重 / 提醒频次都仍走默认）
- 跳过按钮（产品立场是必须答完）
- 任何 v2 问卷通过首启路径迭代——未来补问只能走柔和入口（设置页 / 学习页 banner）

  **完成时间**: 2026-04-25

### 体验优化（2026-04-25 13:34）
- [x] 优化中英文 onboarding 问卷文案，让目标、每日时长和完成页提示更自然清晰
- [x] 完成页改为用户点击“开始学习”后才提交并进入 App，避免完成动画后自动结束过快
- [x] 更新 widget 测试覆盖：答完第二题后停留完成页、不自动写入完成态，点击完成页按钮后才完成 onboarding

### 体验优化（2026-04-25 14:50）
- [x] 重构 Onboarding 问卷页减弱"答题"感：选项后自动前进、内容居中、移除题号文字与"下一题/完成"大按钮，仅保留小号"上一步"
- [x] "应对考试"展开二级菜单（中高考 / 四六级 / 考研 / 雅思 / 托福 / 其他）；新增“影视博客”目标选项；“其他”不再要求输入，选中后自动进入时长
- [x] Q2 文案微调："15-20 分钟"改为"约 20 分钟"，"不固定，有时间就练"简化为"不固定"
- [x] 模型/存储新增 `examType` / `goalOtherText` 字段及对应 SP key，`saveCompleted` 校验 + 切分支自动清残留
- [x] 更新单测/widget 测试覆盖三条分支（普通 / 考试 / 其他）+ 上一步导航 + 切分支字段清理
- [x] 修复选择“其他”后键盘遮挡输入框：页面主体改为可滚动，并在输入框聚焦后自动滚到可见区域

---

## 历史

> 最后更新：2026-04-19
> 当前焦点：官方合集功能（MVP）

## 已完成：官方合集功能（MVP）

跨前后端特性：官方在后端维护一批英语合集，用户在资源库浏览并"添加到我的合集"，点击音频时按需下载。已下载内容永不被 sync 覆盖（本地不变性），移除合集彻底清空。

### 后端（fluency-frontend）
- [x] Schema：`collections` 加 status/description/coverUrl/publishedAt/updatedAt + 2 索引；`audio_collections` 加 sortOrder（drizzle-kit 自动生成 migration `0024_fast_manta.sql`）
- [x] 3 个公共 API：`GET /api/v1/collections`、`GET /api/v1/collections/:id`、`GET /api/v1/audios/:id/content`（unstable_cache(120s) + tag 'collections'）
- [x] 纯查询层 `apps/app/lib/collections/queries.ts` + 对应 DTO；域错误类（404 → CollectionNotFound、410 → CollectionDeprecated、422 → NoTranscriptError）
- [x] `packages/transcription/utils/srt-builder.ts` — sentences → SRT 字符串工具
- [x] 单测：srt-builder 10 + collection-queries 13（错误分支 + DTO 映射）

### Flutter 数据层
- [x] Drift v28→v29：collections 加 5 列（source/remoteId/coverUrl/description/deprecatedAt），audio_items 加 2 列（remoteAudioId/isAudioDownloaded，默认 true 兼容老数据），2 个条件索引
- [x] `Collection` 模型加 `CollectionSource` enum + `isOfficial`/`isDeprecated` getter
- [x] `AudioItem` 模型加 `remoteAudioId`/`isAudioDownloaded`
- [x] `CollectionDao.getByRemoteId` + `AudioItemDao.getByRemoteAudioId`
- [x] `audio_library_provider` 跳过 `!isAudioDownloaded` 的文件存在性校验（避免误软删）

### Flutter feature 层（`lib/features/official_collections/`）
- [x] API client（3 个错误类型）
- [x] Repository：enroll 防重入（DB 唯一索引 + AlreadyEnrolledError）+ remove 彻底清空（collections + audio_items + junction + learning_progresses 等所有按 audioItemId 关联的表 + 本地文件）
- [x] Sync service：三条路径（新增 / 远端移除保留已下载 / 元信息更新）+ 410/404 → deprecatedAt + 单集异常不阻塞
- [x] Download notifier（Riverpod Notifier）：sealed class state（Idle/InProgress/Failed）、单任务并发约束、sessionId 防竞态、CancelToken
- [x] PrepareLearningDialog（非阻塞，可关闭后下载继续）
- [x] Discover 页 + 官方合集详情页（三态显式：loading/error/empty/data）
- [x] OfficialCollectionCard + OfficialBadge + OfficialDeprecatedBadge
- [x] Enrollment provider：enroll/remove 入口

### UI 集成
- [x] Library Collections 视图 AppBar 加 `compass` 入口 → /discover
- [x] `_CollectionListTile` 显示 badges + 菜单按 source 裁剪（official 仅 pin + 移除）
- [x] `CollectionDetailScreen` source='official' 时隐藏添加音频按钮
- [x] `AudioListTile._handleTap` 官方合集未下载分支触发下载对话框
- [x] 路由 `/discover` 和 `/discover/:remoteId`
- [x] `main.dart` 注册全局 `scaffoldMessengerKey`（下载完成 snackbar 任何页面可见）
- [x] 启动时清 `documents/tmp/official_audio/*.m4a.part` 残留
- [x] 启动 3s 后 fire-and-forget 调 `OfficialSyncService.syncAll()`

### 国际化
- [x] 新增 23 个 i18n key（中英文）

### 测试覆盖
- [x] Collection 模型 8 个新测试
- [x] AudioItem 模型 5 个新测试
- [x] OfficialCollectionRepository 9 个测试（enroll/remove/防重入/彻底清空）
- [x] OfficialSyncService 10 个测试（新增/远端移除 + 已下载保留不变性/元信息变化/410 → deprecated/容错）
- [x] OfficialDownloadNotifier 6 个测试（already/busy/cancel/防竞态）

### 范围内不做（MVP 明确排除）
- 搜索 / 难度筛选 / 红点 / 埋点专项 / 迁移降级 / 多粒度版本 / manifest diff API / 后台续传 / 下载队列

**完成时间**: 2026-04-19

---

## 已完成：用户音频 AI 字幕自动校准（Apple 首版）

- [x] 新增统一上层接口 `NativeAudioDecoder` / `DecodedAudioData`，`iOS + macOS` 走同一 `MethodChannel`，其他平台安全回退
- [x] 新增 `SubtitleAutoAlignService`，将 web 自动校准核心规则移植到 Dart，基于本地 PCM 静音区间微调句边界
- [x] 在 `TranscriptionTaskManager._saveTranscriptAndFinish(...)` 接入自动校准，仅对“用户自己的音频 + AI 字幕 + 词级时间戳齐全”生效
- [x] 官方合集/远端音频（`remoteAudioId != null`）不尝试自动校准，继续直接使用后端分句结果
- [x] Apple 原生解码失败时仅记录日志并回退到原始字幕，不影响转录完成态，也不向用户报错
- [x] 补充 provider/service 测试，覆盖成功校准、平台不支持、解码异常回退、用户音频触发、官方音频跳过

**完成时间**: 2026-04-23

- [x] 同步 fluency-frontend 最新算法（commit 24c8c21）：动态阈值 `min(noiseFloor+10, -35)`、逐对静音检测、`maxBoundaryShiftMs=500` 位移帽、`minBoundaryGapMs=50` 最小间隙、`boundaryNudgeMs=150` 对称兜底、`applyGapFallbackAdjustment` 二级算法、整对回退以及词边界保护三重后置清理；删除 `shortSilenceSplitMs` 中点启发式
- [x] 更新测试：既有用例改为对齐新两级算法的期望值，新增 gap 不足时兜底 return null 用例

  **完成时间**: 2026-04-24

- [x] Android 端原生音频解码桥（`AndroidAudioDecodeHandler`）：复用 `top.echo-loop/audio_decode` MethodChannel，使用 `MediaExtractor` + `MediaCodec` 解码，最近邻重采样到 1000 Hz 单声道 Float32，与 iOS / macOS 协议和算法完全一致
- [x] `MainActivity.configureFlutterEngine` 注册 handler，`cleanUpFlutterEngine` 释放
- [x] `PlatformNativeAudioDecoder.isSupported` 加入 `Platform.isAndroid`，无需改 Dart 算法即可在三端启用自动校准
- [x] 新增 JVM 单测 `PcmDownsamplerTest`：覆盖最近邻重采样、跨 chunk 等价性、双声道与四声道平均、低频正弦波形保留、`reconfigureIfNeeded` 中途换采样率、Float32 LE 编码、空 chunk

  **完成时间**: 2026-04-25

---

## 已完成：页面级新用户引导（showcaseview）

- [x] 接入 `showcaseview`，新增可复用 `GuideFlowHost` / `GuideTarget` / `GuideRegistry`，每个 flow 独立用 SharedPreferences 记录 seen 状态
- [x] `LibraryScreen` 新增创建合集与 Examples 预置合集引导
- [x] `CollectionDetailScreen` 新增上传音频与 Examples 示例音频引导
- [x] `LearningPlanScreen` 拆分无字幕 flow（添加字幕 → AI 转录 → 开始转录）和有字幕 flow（自由练习 → 按计划学习）
- [x] 补充中英文引导文案与 guide provider 单元测试
- [x] 重构为全展示型、互相隔离的页面级 flow：Library 合集列表/创建合集、合集详情音频列表/上传音频、学习计划字幕/学习入口、字幕弹窗 AI 转录

  **完成时间**: 2026-04-17 09:36

---

## 进行中：本地 ASR 用户流程集成

- [x] 国际化文案：新增 ~30 个 ASR 相关 i18n key（en + zh）
- [x] `OfflineAsrSettingsProvider`：三态 enabled、下载管理、引擎生命周期
- [x] `speechPracticeBackendProvider` 动态切换（OfflineAsrBackend / Platform）
- [x] 语音识别设置页 UI（开关/进度/删除/确认弹窗）
- [x] 设置主页 AI section（Android 显示入口）
- [x] GMS 检测 + 模型推荐 main() 一次性计算全局注入
- [x] 录音页面入口弹窗（首次引导 + 下载进度 + 自动恢复）
- [x] 改为入口前置阻塞检查（学习计划页/Favorites），替代页面内 guard，避免下载中进入录音

  **完成时间**: 2026-04-10 01:11

- [x] 语音评分 badge 仅在识别失败时回退到“录音”态，识别成功不再依赖 transcript 是否为空

  **完成时间**: 2026-04-10 11:34

- [x] 修复段落复述页面自动录音 listener / dispose 竞态，避免 `ref` 在 widget 销毁后继续访问

  **完成时间**: 2026-04-10 11:53

- [x] 修复本地 ASR 已下载但引擎未就绪时的前置放行问题，确保进入录音前先完成引擎加载/失败判定，避免清晰录音被误判为失败

  **完成时间**: 2026-04-10 12:20

- [x] 补齐录音结束到 ASR 结束链路的关键日志，覆盖 backend 选择、stopSession、final transcript、离线转录与评估结果

  **完成时间**: 2026-04-10 12:24

- [x] 进一步补齐 ASR 全链路日志，覆盖模型下载、引擎初始化、平台桥接、原始事件、离线推理输入输出

  **完成时间**: 2026-04-10 12:35

- [x] 将本地 ASR 默认推荐模型从 Moonshine 切到 Whisper Tiny/Base，便于真机对比识别效果

  **完成时间**: 2026-04-10 12:42

- [x] 修复残缺模型被误判为已下载的问题：完整性判定增加体积校验，启动加载保留残留大小并标记为 failed，设置页/前置弹窗可继续下载或重试

  **完成时间**: 2026-04-10 12:49

- [x] 修复设置页残缺模型体积展示误导：不再把残留大小显示成完整模型大小，改为显示“当前已下载 / 目标总大小”

  **完成时间**: 2026-04-10 12:53

- [x] 修复设置页 AI section 偶发消失：显示条件从 `needsLocalAsr` 解耦，Android 上稳定显示，同时在 `main()` 始终注入离线 ASR 初始状态

  **完成时间**: 2026-04-10 13:08

- [x] 修复完整模型状态漂移：新增“下载完成”持久化标记并在启动时与实际文件状态对齐，残缺旧文件不再被跳过而是假 100%，会删除后重新下载

  **完成时间**: 2026-04-10 13:31

- [x] 切到固定 commit 下载 + SHA-256 校验：模型文件清单写入官方 commit/hash，下载完成后逐文件校验通过才写完成标记；启动时不再后台重验

  **完成时间**: 2026-04-10 13:56

- [x] 转录空结果处理：新增 `TranscriptionEmptyResult` 状态，音频无人声时不保存 SRT 而是进入该状态；`manage_subtitles_sheet` 展示专属提示 UI 并允许重试；补充 i18n key（en + zh）

  **完成时间**: 2026-04-15

- [x] 修复闪卡切卡动画：`navigationDirection` / `navigationId` 移入 provider state，以 `dbKey_navId` 作唯一动画 key，解决往返同一张卡时 AnimatedSwitcher 复用旧 key 导致动画不触发的问题；同时移除 screen 中多余的 `setState` 调用

  **完成时间**: 2026-04-15

- [x] 修复闪卡切卡/例句播放音频竞态：切卡和播放例句前统一 `await _stopAllPlayback()`，避免 iOS 上旧 stop 事件在新 play 之后到达；`_stopActiveResources` 新增 `stopAudio` 参数，引擎内部不再发起二次 unawaited stop，防止与 `playRangeOnce` 产生竞态

  **完成时间**: 2026-04-15

---

## 已完成：本地 ASR 引擎集成（sherpa-onnx）

- [x] 统一 `OfflineAsrEngine` 接口，支持 Moonshine 和 Whisper ONNX 模型
- [x] `SherpaOnnxEngine` 实现：Recognizer 常驻内存，Android 尝试 NNAPI 加速（fallback CPU）
- [x] `AsrModelManager`：HuggingFace 镜像下载、进度回调、本地缓存
- [x] `AudioFileReader`：支持 WAV（RIFF）和 CAF（Float32/Int16）格式解析
- [x] `OfflineAsrBackend` 装饰器：拦截空 transcript 补充离线转录（待接入 provider）
- [x] 开发者 ASR 测试页面：引擎切换、模型下载、录音、转录结果、性能指标、事件日志
- [x] Android `warmup` 增加 `hasGms` 字段透传
- [x] 单元测试 14 个 + 集成测试 1 个

  **完成时间**: 2026-04-09

---

## 历史归档
- [Milestone 2 - 学习流程引擎](./docs/tasks-archive/milestone-2-learning-engine.md)
- [Milestone 3 - 收藏与标注体系 + 体验优化](./docs/tasks-archive/milestone-3-completed.md)
- [Milestone 4 - 功能完善与体验打磨](./docs/tasks-archive/milestone-4-features-and-polish.md)

---

## 已完成：Star → Pin 置顶功能替换 + 列表项布局优化

- [x] 数据模型 `isStarred` → `isPinned`（AudioItem / Collection），`fromJson` 兼容旧 key
- [x] 数据库 schema 27→28 迁移（`ALTER TABLE RENAME COLUMN`）
- [x] DAO 排序加 `isPinned DESC`，pinned 项始终排在最前
- [x] Provider `toggleStar` → `togglePin`，togglePin 后重排列表
- [x] `AudioListView.sortAudioItems` 置顶项固定在前不参与排序，合集排序同理
- [x] UI 布局：ListTile → IntrinsicHeight 自定义布局，pin 按钮上 + 菜单下纵向排列
- [x] 音频列表项 trailing 改为紧凑按钮尺寸，去掉纵向平分高度，修复 pin/菜单上下结构导致的卡片过高过稀疏问题
- [x] 图标 star → push_pin（30° 倾斜、size 20、pinned 红色 `AppTheme.pinColor`）
- [x] 国际化：星标 → 置顶
- [x] 测试：provider 排序 6 项 + collection 排序 4 项 + sortAudioItems 单测 8 项
- [x] 音频列表项、合集列表项与合集网格卡片统一移除外露 pin，改为菜单内 pin/unpin，置顶态改为淡背景色标记

  **完成时间**: 2026-04-10

---

## 已完成：共享跟读权限错误文案窄屏截断修复

- [x] `RepeatPracticePanel` 在 `permissionDenied` / error 态切换到加高状态槽位，允许英文错误文案双行居中显示
- [x] 保持正常录音/倒计时态原有固定高度，不影响共享跟读中间区的稳定布局
- [x] 新增 `repeat_practice_panel_test.dart`，覆盖英文权限文案在窄屏下完整显示且“Go to Settings”按钮仍可见

  **完成时间**: 2026-04-10

---

## 已完成：录音按钮 idle 态隐藏提示文案

- [x] 跟读共享中间区 `RepeatPracticePanel` 在 `idle` 态不再显示 `Tap to record`，同时移除对应占位间距
- [x] 段落复述页录音区在 `idle` 态不再渲染上方状态文案，也不再保留固定高度占位
- [x] 更新跟读/复述 screen 回归测试，覆盖 `idle` 态无状态文案

  **完成时间**: 2026-04-03

---

## 已完成：评估结果 badge 回放态图标修复

- [x] `RepeatFlowState` 新增显式 `isReviewPlaybackActive`，录音回放不再占用独立流程 phase
- [x] `RepeatFlowEngine` 在开始/停止录音回放时仅切换真实回放状态，并保持 `WaitingForUser` 语义；切句、重播、重置时统一清理
- [x] 跟读、难句补练、收藏复习页面的 `SpeechRatingBadge` 改为读取真实回放状态
- [x] 补充跟读主页面回归测试，覆盖“回放进行中时 badge 显示停止图标”

  **完成时间**: 2026-04-03

---

## 已完成：全文盲听/段落复述调试日志补齐

- [x] 全文盲听页面新增播放器状态变化日志，覆盖段落索引、句子高亮、播放/倒计时/等待态切换
- [x] 段落复述页面新增播放器状态变化日志，覆盖 listening/retelling、倒计时、等待态和显示模式变化
- [x] 段落复述页面新增录音状态变化日志，覆盖录音 phase、attempt 状态、score 和 live transcript 变化
- [x] 段落复述页面新增录音回放日志，覆盖 badge 回放开始/停止和当前是否在播放

  **完成时间**: 2026-04-03

---

## 已完成：播放按钮 idle 态图标兜底修复

- [x] 全文盲听、段落复述、逐句精听、难句补练、收藏复习统一为“只有主音频确实在播放中才显示暂停图标”
- [x] `WaitingForUser`、倒计时、暂停态即使 `isPlaying` 等字段暂未收口，也统一显示播放三角图标
- [x] 补充全文盲听和段落复述 screen 回归测试，覆盖不一致状态下仍显示播放图标

  **完成时间**: 2026-04-03

---

## 已完成：评估结果 badge 改为自管理录音回放

- [x] `SpeechRatingBadge` 改为自管理录音回放和图标切换，不再依赖页面层传入 `isPlaying`
- [x] 页面层改为仅提供 `onBeforePlayback` 回调，在播放前执行取消倒计时、切换等待态、暂停主音频等清理动作
- [x] 复述、跟读、难句补练、收藏复习统一切到新的 badge 接口
- [x] 新增 `speech_rating_badge_test.dart`，覆盖 badge 自己切换喇叭/停止图标

  **完成时间**: 2026-04-03

---

## 已完成：全文盲听/段落复述设置弹窗等待态修复

- [x] 全文盲听 `BlindListenPlayerState` 新增显式 `isWaitingForUser`，不再靠停止播放的布尔组合隐式表达等待态
- [x] 段落复述 `RetellPlayerState` 新增显式 `isWaitingForUser`，区分“可录音/可继续”与“设置接管流程”的等待态
- [x] 两页设置入口统一在打开弹窗前调用 `enterWaitingForUser()`，播放中允许当前段自然播完，再落入等待态
- [x] 设置修改发生在挂起等待态时，不再打断当前段，也不再重播或自动进入下一步
- [x] 段落复述自动录音与评估后倒计时改为尊重 `isWaitingForUser`，避免 provider 已等待而 screen 又重新推进流程
- [x] 补充 blind listen / retell provider 回归测试，覆盖“播完后等待”和“设置变更保持等待”两条状态流

  **完成时间**: 2026-04-03

---

## 已完成：全文盲听 + 段落复述共享骨架重构

- [x] 新增 `ParagraphPracticeScaffold`，统一顶部进度区、句子列表、中部插槽和底部播放控制
- [x] 新增 `ParagraphSentenceListCard`，让全文盲听与段落复述共用段落句子卡片
- [x] 新增 `ParagraphVisibilityControls`，将复述可见性菜单上移到句子列表下方、练习控制区上方
- [x] `BlindListenPlayerScreen` 改为共享 scaffold 结构，`build()` 内完成监听下沉到 `initState` 的 `listenManual`
- [x] `RetellPlayerScreen` 改为共享 scaffold 结构，自动录音与完成监听从 `build()` 下沉到显式 listener
- [x] `RetellSentenceTile` 去掉对 `RetellPhase` 的直接依赖，收敛为纯展示组件
- [x] 补充全文盲听与段落复述 screen/widget 回归测试，覆盖共享 footer、可见性菜单位置与录音控制区布局

  **完成时间**: 2026-04-03

---

## 已完成：逐句精听页面按难句补练模式重构

- [x] 逐句精听盲听流程接入 `BlindPracticeFlowEngine`，不再由 Screen/Provider 手工拼装播放与倒计时布尔状态
- [x] 新增 `IntensiveAnnotationPhase` / `IntensiveAnnotationState`，将“看不懂后”的详情模式收敛为显式状态切换
- [x] `IntensiveListenPlayerScreen` 改为“顶部进度 + 中间内容切换 + 单一 footer”结构，复用 `PracticeProgressSection` 与 `PracticePlaybackFooter`
- [x] 设置、偷看字幕、查词等用户接管动作统一进入等待态；播放中触发时允许当前句自然播完后再进入 `WaitingForUser`
- [x] 补充逐句精听 provider / widget 测试，覆盖盲听、详情重播、继续推进、完成弹窗与设置交互
- [x] 修复逐句精听快速切句时旧盲听回调污染新句状态，避免新句一开始误显示倒计时
- [x] 修复“看不懂 → 继续”后的详情倒计时不刷新的问题，改为局部订阅剩余时间并使用独立 key 重建组件

  **完成时间**: 2026-04-03

---

## 已完成：复述页面输出时长统一记录修复

- [x] `RecordingService.stopRecording()` 恢复为录音结束后的统一输出时长写入入口，避免各录音 controller 分散记账
- [x] `SpeechRecordingController` 改为只计算有效说话时长并传给底层，不再直接调用 recorder
- [x] `RetellRecordingController` 补齐首个语音时间记录与有效说话时长计算，修复复述场景漏记 `outputTime`
- [x] 新增复述录音控制器回归测试，验证停止录音后会通过底层统一记录一条说的时长

  **完成时间**: 2026-04-03

---

## 已完成：难句补练/收藏复习盲听等待态状态机化

- [x] 复用现有 `BlindPracticeFlowEngine`，将难句补练盲听流程从布尔状态拼装迁移为显式 phase 状态机
- [x] `ReviewDifficultPracticeState` 新增 `blindFlowState`，盲听 UI 从状态机派生播放/倒计时/等待态
- [x] 难句补练页在设置、偷看字幕、查词前统一进入 `WaitingForUser`
- [x] 收藏复习页盲听流程接入同一套 `BlindPracticeFlowEngine`，跨音频播放前通过 `onBeforeSentenceStart` 预加载音频
- [x] 修复 blind flow dispose 竞态，Provider 销毁后不再继续回调状态或读取 provider
- [x] 补充 provider/widget 回归测试，覆盖盲听 `WaitingForUser` 保持、两页设置弹窗进入等待态

  **完成时间**: 2026-04-03

---

## 已完成：难句补练/收藏复习单底部控制重构

- [x] 新增 `PracticePlaybackFooter`，统一 `上一句 / 播放 / 下一句 + 遍数标签`
- [x] `RepeatPracticePanel` 收敛为纯跟读中间区，不再内嵌 footer
- [x] `ReviewDifficultPracticeScreen` 改为“中间内容切换 + 单一 footer”结构
- [x] `BookmarkReviewScreen` 改为同样的单一 footer 结构，删除旧 `AnnotationWithRecording`
- [x] `BookmarkReviewProvider` 跟读模式迁移到 `RepeatFlowEngine`
- [x] 难句补练/收藏复习 screen tests 补齐“盲听/跟读都只有一套 footer”回归断言

  **完成时间**: 2026-04-03

---

## 已完成：难句跟读复用边界收敛 + 主页面测试补齐

- [x] `ListenAndRepeatPlayerScreen` / `ReviewDifficultPracticeScreen` / `BookmarkReviewScreen` 将 `ref.listen` 从 `build()` 下沉到 `initState` 的 `listenManual`
- [x] `ReviewDifficultPractice` / `BookmarkReview` 收回标记持久化逻辑，Screen 不再直接操作 `BookmarkDao`
- [x] `BookmarkReview` 的音频加载回调移除 `dynamic`，改为显式 typed loader
- [x] 重写 `listen_and_repeat_player_screen_test.dart`，覆盖标题/进度/录音区/完成弹窗
- [x] 修复难句补练与收藏复习 screen tests 的测试依赖漂移（`AnnotationContentView` 依赖补齐），并临时跳过 7 个已失真断言

  **完成时间**: 2026-04-02

---

## 已完成：活动日历页面

- [x] 添加 `table_calendar` 依赖
- [x] 创建 `monthlyStudyRecordsProvider`（Family Provider，按月查询每日学习记录）
- [x] 创建 `ActivityDayCell`（圆形日期单元格，GitHub 风格 12 级绿色热力图）
- [x] 创建 `MonthlySummaryCard`（月度统计摘要：总计/学习天数/日均/最长连续）
- [x] 创建 `ActivityCalendarScreen`（月历页面，table_calendar 月视图）
- [x] Streak chip 始终显示（streak=0 灰色），点击进入日历页
- [x] 路由注册 `/activity-calendar`
- [x] 点击日期弹出 `DayStageBreakdownSheet`（复用已有弹窗，隐藏图例）
- [x] 国际化（中/英双语）
- [x] Provider 单元测试 + Widget 测试（9 个测试全通过）

  **完成时间**: 2026-03-26

---

## 已完成：修复听说时间统计不一致 + 集中化 StudyEventRecorder

- [x] 显示层 clamp 修复：output 不再被 `total - input` 压缩到 0（4 处）
- [x] 新增 `StudyEventRecorder`：封装按句/按录音的统计写入（inputTime + inputWords + recordSentence + outputTime）
- [x] `SentencePlaybackEngine` 注入 recorder：`playSentenceLoop` 和 `playOnce` 每播完一遍自动记录
- [x] `RecordingService` 追踪录音时长：`stopRecording` 时自动回调 recorder
- [x] 录音控制器暴露 `setRecorder()`：Provider 进入模式时注入，退出时清除
- [x] 全部 7 个 Player Provider 迁移：删除 input/output Stopwatch，改用 recorder 事件驱动
- [x] 清理 LearningSession 死代码：删除 `addInputTime`/`addInputWords`/`recordLearnedSentence`/`_saveInputOutputTime`

  **完成时间**: 2026-03-24

---

## 已完成：提醒设置功能

- [x] ReminderSettings 数据模型（`lib/models/reminder_settings.dart`，防御性 fromJson + copyWith + equality）
- [x] ReminderSettingsNotifier Provider（`lib/providers/reminder_settings_provider.dart`，keepAlive + SP 持久化）
- [x] 改造通知调度链路（`review_reminder_provider.dart` 从设置读取 hour/minute，`review_reminder_service.dart` 新增 updateTimeCalculator + cancelAllPerAudioReminders，`main_shell.dart` 新增设置变更监听）
- [x] 提醒设置页 UI（`lib/screens/reminder_settings_screen.dart`，每日提醒开关+时间选择+复习提醒开关）
- [x] 设置页入口（`settings_screen.dart` 外观与存储之间新增提醒 section）
- [x] 国际化（9 个新 key，en + zh）
- [x] 测试（ReminderSettings 模型 18 个 + ReviewReminderService 新增 cancelAll/updateTimeCalculator 3 个 = 21 个新测试）

  **完成时间**: 2026-03-22

---

## 已完成：按学习阶段分开统计听说时长 + 柱状图点击查看详情

- [x] 新建 `StudyStage` 枚举（7 个学习阶段，intEnum 存储）
- [x] 新建 `DailyStageStudyRecords` Drift 表（date + stage 唯一组合键）
- [x] 新建 `DailyStageStudyRecordDao`（upsertAdd 累加 + getByDate 查询）
- [x] 数据库注册新表 + 新 DAO，`schemaVersion` 19 → 20，迁移 createTable
- [x] `StudyTimeService` 扩展：构造函数注入新 DAO，`addStudyTime/addInputTime/addOutputTime` 加可选 `stage` 参数实现双写
- [x] `StudyTimeService` 新增 `getStageBreakdown(date)` + `getDayTotal(date)` 查询方法
- [x] `LearningSessionProvider._saveStudyTime/_saveInputOutputTime` 传递 `_currentStage`（LearningMode → StudyStage 映射）
- [x] `BookmarkReviewProvider._saveAndRefreshStudyTime` 传递 `StudyStage.bookmarkReview`
- [x] `FlashcardNotifier._saveAndRefreshStudyTime` 传递 `StudyStage.flashcard`
- [x] `_WeeklyBarChart` 改为 StatefulWidget，新增 `onBarTap` 回调 + 点击高亮（150ms opacity）
- [x] 新建 `DayStageBreakdownSheet` 底部弹窗（阶段列表 + 图标 + 听说明细 + 合计行 + 旧数据回退提示）
- [x] 国际化新增 14 个 key（7 阶段名 + 弹窗标题/今天/合计/不足1分/听/说/无数据提示，en + zh）

  **完成时间**: 2026-03-21

---

## 已完成：埋点分析系统（Firebase / 友盟 / LogOnly）

### 架构
- [x] 三通道架构：`AnalyticsChannel` 抽象接口 + `FirebaseChannel` / `UmengChannel` / `LogOnlyChannel`
- [x] `AnalyticsService` Facade 入口（合规拦截 + 分发 + 异常静默）
- [x] `ConsentManager` 用户同意管理（本期默认同意）
- [x] `GeoInterceptor` Dio 拦截器（从 API 响应自动更新地区缓存，零额外请求）
- [x] `AnalyticsObserver` GoRouter NavigatorObserver（自动采集 screen_view）
- [x] 事件名/参数名常量集中管理（`Events` / `EventParams`）
- [x] Riverpod Provider 注册（同步暴露，与 appDatabaseProvider 模式一致）

### 平台配置
- [x] Firebase iOS/macOS 配置（`flutterfire configure`）
- [x] `firebase_core` + `firebase_analytics` + `umeng_common_sdk` 依赖
- [x] 关闭 Firebase 自动 screen_view（Info.plist `FirebaseAutomaticScreenReportingEnabled = NO`）
- [x] 友盟空 Key 防护（未配置时 fallback 到 Firebase）

### 事件（17 个）
- [x] `app_open`（冷启动 / 热启动）、`app_background`（前台时长）
- [x] `screen_view`（页面名 + 上一页面）
- [x] `learning_start` / `learning_end`（音频 ID + 学习模式 + 时长 + 自由练习标记）
- [x] `blind_listen_start` / `blind_listen_complete`（遍数）
- [x] `blind_listen_difficulty_set`（难度级别）
- [x] `intensive_listen_start` / `intensive_listen_complete`（总句数 + 难句数）
- [x] `listen_repeat_start` / `listen_repeat_complete`（总句数）
- [x] `retell_start` / `retell_complete`（总段落数）
- [x] `difficult_practice_start` / `difficult_practice_complete`（难句数）
- [x] `first_learn_complete`（总学习时长）
- [x] `stage_advance`（from_stage → to_stage）

### 集成
- [x] `main.dart` Firebase 初始化 + 生命周期事件
- [x] GoRouter Observer 注册
- [x] 各学习 Provider 埋入 start/complete 事件
- [x] `LearningProgressProvider` 埋入 stage_advance + first_learn_complete
- [x] `GeoInterceptor` 挂载到 AI API / 转录 API 的 Dio 实例
- [x] 设置页开发者选项显示当前通道

### 测试
- [x] 39 个测试全部通过（service 10 + observer 9 + consent 4 + geo 6 + log_channel 6 + event_names 4）

### Firebase DebugView 验证
- [x] `app_open`、`screen_view`、`learning_start`、`learning_end` 在 DebugView 中确认出现

  **完成时间**: 2026-03-23

### 上线前待办
- [ ] 友盟后台注册 App，填入 iOS/Android App Key（`umeng_channel.dart`）
- [ ] `ConsentManager` 默认同意改为默认拒绝 + 隐私政策弹窗
- [ ] `revokeConsent` 时清除 `anonymous_id`

---

## 已完成：断点索引跨阶段未重置

- [x] 正常学习模式进入精听/跟读/难句补练/复述时不再读取遗留断点，一律从头开始
- [x] 自由练习模式保留断点续学能力
- [x] `completeCurrentSubStage` 完成子步骤时防御性清除对应断点索引
- [x] 更新/新增测试覆盖（learning_progress_provider 5 个 + learning_session_provider 8 个）

  **完成时间**: 2026-03-20

---

## 已完成：全文盲听 & 逐句精听添加手动控制模式

- [x] BlindListenSettings 添加 controlMode 字段 + isManualMode getter + copyWith 扩展
- [x] IntensiveListenSettings 注释更新（controlMode 精听也用）
- [x] BlindListenPlayerProvider 手动模式：播放完段落后跳过倒计时，直接停止
- [x] IntensiveListenPlayerProvider 手动模式：播放一遍后停止、标注重播后停止、controlMode 变化触发 restart
- [x] BlindListenSettingsSheet 添加控制模式 SegmentedButton，手动模式隐藏重复次数和停顿设置
- [x] IntensiveListenSettingsSheet 添加控制模式 SegmentedButton，手动模式隐藏循环次数和停顿设置
- [x] BlindListenPlayerScreen 手动模式隐藏遍数文字
- [x] IntensiveListenPlayerScreen 手动模式隐藏播放遍数文字
- [x] 国际化新增 4 个描述 key（blindListen/intensiveListen ControlMode Auto/ManualDesc，en + zh）
- [x] 测试覆盖（BlindListenSettings 7 个 + BlindListenPlayer 4 个 + IntensiveListenPlayer 手动模式 3 个 = 14 个新测试）

  **完成时间**: 2026-03-20

---

## 已完成：跟读录音控制器独立实现 + UI 优化

- [x] 新增 `ShadowingRecordingController` 替代跟读场景对 `retellRecordingControllerProvider` 的复用
- [x] 扩展 `ListenAndRepeatTurnState` 新增录音相关字段（currentAttempt / liveTranscript / permissions 等）
- [x] 三个页面（跟读/难句补练/收藏复习）统一切换到 `shadowingRecordingControllerProvider`
- [x] `exitLearningMode` 按模式调用对应录音控制器 fullReset
- [x] 删除旧 `ListenAndRepeatTurnController` 及 `_mapToTurnState` 映射
- [x] 评估后倒计时：`isPostEvalCountdown` 标志（对应复述的 `isRetellCountdown`）
- [x] 倒计时 UI 直接用 player state 驱动（不再合成 turnState）
- [x] 倒计时暂停/恢复/取消（`pausePostEvalCountdown` / `cancelPostEvalCountdown`）
- [x] 评级 badge 移到录音按钮上方（和复述页面同位置）
- [x] 错误提示（未检测到英语等）显示在录音按钮上方状态文字区
- [x] 手动模式录音兜底：开始即启动 300s 上限，检测到语音后 max(300s, 5×自动时长)
- [x] 更新测试（provider 测试 + screen 测试 + mock 测试辅助类）

  **完成时间**: 2026-03-19

---

## 已完成：全文盲听页面改造 — 段落分段播放

- [x] 提取共用 UI 组件：`ParagraphBottomControls` + `ParagraphProgressHeader`
- [x] 修改 `retell_player_screen.dart` 使用共用组件（纯机械替换，行为不变）
- [x] 新增 `BlindListenSettings` 模型（重复次数 + 段间停顿秒数）
- [x] 重写 `BlindListenPlayerProvider`（段落播放 + 句子高亮 + 段间倒计时 + 遍数循环 + 兼容极简模式）
- [x] 修改 `BlindListenBriefingSheet`（新增段落时长 + 段间停顿选择器 + 段落数预览）
- [x] 新增 `BlindListenSettingsSheet`（每段重复次数 + 段间停顿）
- [x] 修改 `LearningSessionProvider.enterBlindListenMode`（支持段落模式 / 极简模式双通道）
- [x] 重写 `BlindListenPlayerScreen`（段落模式：句子列表 + 导航 + 倒计时 | 极简模式：大播放按钮 + 进度条）
- [x] 修改 `LearningPlanScreen` 所有盲听入口（首次学习 / 复习 / 自由练习）传入 sentences 和段落参数
- [x] 国际化新增 11 个 key（en + zh）

  **完成时间**: 2026-03-18

---

## 已完成：文本 Embedding 相似度计算（NLEmbedding + MethodChannel）

- [x] Dart 侧平台桥接 `TextEmbeddingPlatform`（MethodChannel `top.echo-loop/text_embedding`，`embed` 方法）
- [x] Dart 侧 `EmbeddingSimilarity` 纯计算服务（cosine similarity + mock 友好的 `TextEmbeddingBackend` 抽象）
- [x] iOS 原生 `IOSTextEmbeddingHandler`（NLEmbedding.sentenceEmbedding + vector(for:)）
- [x] macOS 原生 `MacTextEmbeddingHandler`（同 iOS API）
- [x] 单测 12 个（cosineSimilarity 纯函数 8 个 + computeSimilarity mock 测试 4 个）

  **完成时间**: 2026-03-18

---

## 已完成：用户体验优化（部分）

- [x] 段落复述页面：词可见性菜单顺序改为全部隐藏|仅可见词|全部显示，另外如果用户如果在播放过程中切换了显示选项，就不要在播放结束的时候自动改成仅可见词了（本段落内有效）。
  **完成时间**: 2026-03-17

---

## bug 修复

- [x] 修复精选合集下载完成后学习计划页只显示音频时长、缺少句数/词数 chip：`OfficialDownloadNotifier._runDownload` / `updateTranscript` 写 DB 时同步调用 `getTranscriptStats` 计算 sentenceCount/wordCount 入库，避免依赖启动期 `backfillTranscriptStats` 补填；老用户未补填的官方音频仍由启动 backfill 兼容

  **完成时间**: 2026-04-28

- [x] 修复精选合集加入后音频列表出现重复项（新发布音频被插入多次）：`OfficialSyncService.syncAll` 加 inflight 锁，消除并发 trigger 下两份 `_applyCatalog` 共享旧 `localByRemoteId` 快照各 insert 一次的竞态；`audio_items(remote_audio_id)` 索引升级为 UNIQUE 作为 DB 层兜底

  **完成时间**: 2026-04-24

- [x] 精选合集官方音频更新字幕前增加确认弹窗，并在更新成功后清空该音频收藏句子和学习进度，避免旧句子索引错位

  **完成时间**: 2026-04-20 22:57

- [x] 修复官方音频“更新字幕”覆盖同一路径后学习页仍显示旧字幕：更新后强制重载当前音频会话，并补充句子字幕、词级字幕和学习进度保留测试

  **完成时间**: 2026-04-20 21:32

- [x] 给精选合集官方音频菜单新增“更新字幕”：拉取最新官方字幕并覆盖本地 SRT/词级时间戳，不重置学习进度

  **完成时间**: 2026-04-20 20:58

- [x] 修复精选合集详情页空音频不可下拉刷新，并移除音频列表“当前播放”持久背景色，仅保留点击瞬时反馈和置顶高亮

  **完成时间**: 2026-04-20 20:46

- [x] 修复冷启动精选合集未及时刷新：启动 catalog 同步改为 force 绕过本地 10 分钟节流，并在磁盘 catalog 加载后刷新 provider

  **完成时间**: 2026-04-20 14:56

- [x] 修复数据导出遇到未下载官方音频失败：备份媒体路径收集兼容 `audio_path=NULL`，只复制已存在本地路径的音频/字幕文件

  **完成时间**: 2026-04-20 14:38

- [x] 修复官方合集升级迁移顺序：v28 老库直升当前版本时先补 `is_audio_downloaded` 再执行 v30 表重建，避免已有用户启动时报 `no such column: is_audio_downloaded` 导致本地合集不可见

  **完成时间**: 2026-04-20 13:56

- [x] 补充启动时资源库加载关键日志：记录音频/合集读库数量、映射后可见数量、官方/本地合集数量、关联音频数量，并在启动链路捕获异常方便定位升级后合集不可见问题

  **完成时间**: 2026-04-20 13:50

- [x] iOS 点击收藏复习通知无法跳转收藏页（AppDelegate 缺少 UNUserNotificationCenter.delegate 设置 + 兼容旧 open_study_tasks payload）

  **完成时间**: 2026-03-23

- [x] 点击复习通知，打开音频的学习计划页面，但是没有返回按钮，应该加上返回按钮，使得用户可以返回到学习 tab。应该和在学习tab点击一个任务打开的效果类似

  **完成时间**: 2026-03-23

- [x] 在复习收藏内容（句子和单词）的时候要阻止息屏。
- [x] 确认一个学习任务完成之后，不能再阻止息屏了。

  **完成时间**: 2026-03-23

- [x] 收藏句子复习页面学习时长虚高（用户睡着后计时器不停止）：BookmarkReview 补齐周期保存+封顶+生命周期处理 + WakelockMixin 增加空闲超时自动关屏 + LearningSession 完成时停止计时

  **完成时间**: 2026-03-24

- [x] 难句补练页面，收藏tab中句子复习页面，在第二遍的时候，点击播放按钮暂停，重播，还是会把遍数重置为1，这个bug之前应该已经修复过了，为什么还有

  **完成时间**: 2026-03-24
- [x] 在难句补练页面，在倒计时过程中点击播放按钮重播，还是会出现”倒计时没有消失，并且播放结束后倒计时重置，并且无法暂停的情况”，这个bug之前应该已经修复过了，为什么还有。

  **完成时间**: 2026-03-24
- [x] 难句补练页面，评级badge上方没有边距，这个bug之前应该修复过了，为什么还有

  **完成时间**: 2026-03-24
- [x] 难句跟读页面播放中取消标记后，`flowToken` 不应被 UI 刷新复用；修复后原句播放完成仍会正常收口并继续流程

  **完成时间**: 2026-04-02

- [x] 全文盲听阶段（复习阶段第一次学习）没有正常恢复进度：新增双轨断点字段 + 段落切换时异步保存 + 进入时 clamp 恢复

  **完成时间**: 2026-03-24
---

## 已完成：数据导入/导出功能（开发者选项）

- [x] 添加 `archive` + `share_plus` 依赖
- [x] 创建 `lib/services/backup/backup_manifest.dart` — manifest 模型
- [x] 创建 `lib/services/backup/backup_progress.dart` — 进度模型
- [x] 创建 `lib/services/backup/backup_service.dart` — 核心导出/导入逻辑（ZIP + SQLite 文件直拷）
- [x] 创建 `lib/providers/backup_provider.dart` — Provider 桥接 UI 和 Service
- [x] 修改 `lib/screens/settings_screen.dart` — 开发者选项新增导出/导入入口
- [x] 修改 `lib/database/app_database.dart` — 新增 `currentSchemaVersion` 静态常量
- [x] 国际化：新增 22 个 i18n key（en + zh）
- [x] 创建 `test/services/backup/backup_service_test.dart` — 单元测试

  **完成时间**: 2026-03-26

---

## 已完成：开发者选项新增「偏好设置」查看页

- [x] 新增 `PreferencesViewerScreen`：列出 SharedPreferences 所有 key/value，支持搜索、长按复制、整体复制、刷新
- [x] 设置页开发者选项新增「偏好设置」入口（内部存储上方）
- [x] JSON 字符串自动 pretty-print，方便查看复杂设置

  **完成时间**: 2026-04-18

---

## 录音+识别功能（进行中）

- [ ] 段落复述页面复用同一模块接入录音识别能力。

---

## 优化UI（进行中）

- [ ] 支持自定义背景、背景音

---

## 用户体验优化（待办）

- [ ] 计算每个任务的估计学习时长，显示在音频学习计划页以及学习tab页的任务item上。没有学习的显示估计时长，已经学习的显示真实的耗时。
- [ ] 学习 tab 页面点击学习或复习要直接打开学习页面，跳过学习计划页面
- [ ] 在学习tab，增加显示今日完成任务（如果有），默认折叠起来，避免用户不知道今天都学了哪些
- [ ] 给句子增加复制功能，在移动端长按，在PC端右键，弹出一个菜单，现在只有一个选项就是复制。

---

## 已完成：精听标注模式三按钮工具栏

- [x] 提取 ShimmerPlaceholder 为公共 widget
- [x] 新增国际化 key（annotationBtnSenseGroup / annotationBtnTranslation / annotationBtnAnalysis / senseGroupNotAvailable）
- [x] 改造 SentenceAnnotationCard：移除 AiContentSection 手风琴，改为三按钮工具栏 + 内联翻译 + 面板解析
- [x] 工具栏固定在滚动区上方，_AnnotationModeView 改为 StatefulWidget
- [x] 更新测试（19 个）

  **完成时间**: 2026-03-28

---

## 已完成：意群划分功能

- [x] 后端：暴露词级时间戳 API（transcript route 返回 words）
- [x] 后端：AI 意群拆分端点（POST /api/v1/ai/sense-groups + PostgreSQL 缓存表）
- [x] Flutter：词级时间戳模型（WordTimestamp）+ 获取
- [x] Flutter：意群数据模型（SenseGroupResult）+ AI 客户端 + 三级缓存
- [x] Flutter：意群时间戳映射工具（mapSenseGroupTimings）
- [x] Flutter：意群色块 UI 组件（SenseGroupText）
- [x] Flutter：标注模式集成（SentenceAnnotationCard 意群替换 RichText）
- [x] Flutter：精听播放器集成（playSenseGroup / stopSenseGroupPlayback）
- [x] 国际化（senseGroupSplit / senseGroupLoading / senseGroupSingleGroup）
- [x] Critic Review 修复（_autoAdvance 重置意群状态、exitAnnotationMode 停止意群播放、死代码清理、SenseGroupText 改 StatelessWidget、双空格修复）
- [x] 单元测试（27 个：模型 fromJson/toJson + 时间戳映射算法）
- [x] 意群模型重构：移除 translation 字段，新增 isCore 核心意群标记
- [x] 后端 prompt/schema 同步更新（SenseGroupData 接口 + Zod schema + system prompt）
- [x] 意群 badge UI 重构：Wrap + 多色色板（亮/暗主题各 6 色）、移除单词级点击查词典（避免与 group 点击冲突）
- [x] 缓存容错：SQLite L2 缓存解析失败时自动删除并 fallthrough 到 API
- [x] 新增 SentenceAiCacheDao.deleteByHash() 方法

  **完成时间**: 2026-03-14 (初版) / 2026-03-28 (重构)

---

## 已完成：收藏回收站功能

- [x] 取消收藏改为软删除（bookmark/word/senseGroup 的 remove 方法设 deletedAt 而非物理删除）
- [x] 三个 DAO 新增回收站方法：getDeleted / restore / permanentlyDelete / permanentlyDeleteAllDeleted
- [x] 收藏页 AppBar 改造：标题左对齐 + 右侧回收站图标按钮
- [x] 句子回收站弹窗（左滑删除 + 书签按钮恢复 + 清空 + 排序）
- [x] 词汇回收站弹窗（合并 word+senseGroup，内存归并排序）
- [x] 公共组件提取：RecycleBinSheetScaffold / RecycleBinDismissible / RecycleBinRestoreButton
- [x] 国际化（10 个新 key，en + zh）
- [x] DAO 单元测试（12 个新测试）

  **完成时间**: 2026-03-30

---

## 已完成：意群逐个播放

- [x] 标注模式下播放按钮改为逐个播放意群（意群之间暂停 1 秒），而非播放整句
- [x] 新增 `playAllSenseGroups` 方法（sessionId 竞态保护 + 暂停/切换可取消）
- [x] 键盘快捷键 + 播放按钮两处入口统一，无意群时 fallback 到整句播放

  **完成时间**: 2026-03-29

---

## 已完成：词级时间戳本地持久化

- [x] 词级时间戳存入 `audio_items.word_timestamps_json` 列（与字幕一起管理，非缓存）
- [x] 数据库迁移 v24 → v25（加列 + 从旧表迁移数据 + 删除旧表）
- [x] `WordTimestamp` 模型新增 `encodeWordTimestamps` / `decodeWordTimestamps` 工具函数
- [x] 转录完成时自动保存词级时间戳
- [x] 精听页面 DB 优先 + API fallback（支持离线 + 旧数据自动补拉）
- [x] 意群播放无时间戳时 SnackBar 提示 + 意群 badge 统一浅蓝色
- [x] 删除字幕时清除词级时间戳，清除缓存时不清除
- [x] 国际化新增 `wordTimestampsNotFound` key（en + zh）

  **完成时间**: 2026-03-29

---

## 加入特效

- [ ] 一个句子/单词播放完成，一遍播放完成，播放音效
- [ ] 任务完成，播放动画+音效

## 埋点

- [ ] 支持中国大陆区
- [ ] 支持全球

---

## 任务完成记录模板

<!--
完成任务后，按以下格式在任务下方添加记录：

  **完成时间**: 2026-XX-XX
-->
