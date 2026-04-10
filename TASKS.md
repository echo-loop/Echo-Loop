# Fluency 任务清单

> 最后更新：2026-04-03
> 当前焦点：录音+识别功能

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
