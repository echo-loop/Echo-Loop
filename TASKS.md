# Fluency 任务清单

> 最后更新：2026-04-27
> 当前焦点：跟读权限前置阻塞弹窗

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
