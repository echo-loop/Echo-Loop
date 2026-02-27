# Fluency 任务清单

> 最后更新：2026-02-26
> 当前焦点：Milestone 2 - 学习流程引擎

---

## P2: 用户体验优化
- [ ] 在进入一个学习阶段的时候，显示预估时长。比如难句跟读，假设共5个句子，每个句子跟读3遍，5秒，间隔固定5秒，预估时长是 3 * 5 * 5 * (3 * 5 - 1) * 5
- [ ] 难句跟读页面，精听页面，难句星标放在右侧。
- [ ] 学习页面左上角的返回按钮改成 X
- [ ] 在自由学习模式下，学完也弹窗，提醒用户完成或再学一遍，进入之前提醒用户这是自由学习模式。
- [ ] 学习过程中，如果息屏了，要后台播放。

## 音频标签功能

- [x] 数据库层 — 新建 `tags` 和 `audio_item_tags` 两张表 + schema v8→v9 迁移 + 反向查询索引
- [x] 标签 Model — `lib/models/tag.dart`（id, name, colorValue, createdDate, color getter, copyWith）
- [x] 标签 DAO — `lib/database/daos/tag_dao.dart`（CRUD + Junction 操作 + CASCADE）
- [x] Provider 注册 — `tagDaoProvider` 添加到 `lib/database/providers.dart`
- [x] 标签 Provider — `lib/providers/tag_provider.dart`（TagState + TagList notifier + audioToTagsMap 反向索引 + diff 模式更新）
- [x] 集成 — 音频删除时清理标签缓存（`removeAudioFromAllTags`）
- [x] 集成 — 启动时加载标签（`main_shell.dart` 中 `loadTags()`）
- [x] 预定义颜色板 — `lib/theme/tag_colors.dart`（10 个颜色）
- [x] UI — 管理标签 BottomSheet — `lib/widgets/edit_tag_membership_sheet.dart`（CheckboxListTile + 颜色圆点 + 创建标签对话框 + 颜色选择）
- [x] UI — 音频列表项集成 — `AudioListTile` 新增"管理标签"菜单项 + 彩色标签 chips + `AudioListView` 传入回调
- [x] 国际化 — 6 个新 key（manageTags / noTagsYet / createTag / tagName / enterTagName / selectColor）
- [x] 代码生成 — `build_runner build` + `flutter gen-l10n`
- [x] 测试 — Tag Model 测试(4) + Tag DAO 测试(10) + TagState 测试(4) + EditTagMembershipSheet Widget 测试(4) + smoke test 修复
- [x] UI — 标签删除功能 — 删除按钮 + 确认对话框 + 国际化(+2 key) + Widget 测试(+1)
- [x] UX — 标签/合集 Sheet 改为即时生效 — 去掉"完成"按钮和本地 `_selectedIds`，勾选/取消直接调 Provider，ConsumerStatefulWidget→ConsumerWidget，创建后自动关联

  **完成时间**: 2026-02-23

---

## 音频星标功能

- [x] 数据库表 `audio_items` 添加 `isStarred` 列 + schema v7→v8 迁移
- [x] AudioItem 模型添加 `isStarred` 字段（构造函数、toJson/fromJson、copyWith）
- [x] AudioLibraryProvider 添加 `toggleStar` 方法 + loadLibrary/upsert 映射
- [x] SP 迁移 Companion 补充 `isStarred`
- [x] 国际化添加 `starAudio` / `unstarAudio` 字符串
- [x] AudioListTile 添加星标 IconButton（AppTheme.bookmarkColor 颜色）
- [x] 测试：AudioItem 模型测试（+4）、AudioLibraryProvider 测试（+3）、AudioListTile Widget 测试（+4）

  **完成时间**: 2026-02-23

---

## 合集音频列表与全局音频列表复用

- [x] 统一 AudioListTile — 添加 collectionId 参数，合并 _CollectionAudioTile 差异逻辑（正在播放标记、文件检查、路由切换、条件菜单）
- [x] 统一 AudioListView — 添加 items/collectionId/emptyState 参数，支持外部数据源 + 统一排序
- [x] 提取 AudioSortButton — 从 library_screen.dart 的 _AudioSortButton 提取为公开组件
- [x] CollectionDetailScreen 改用 AudioListView + AudioSortButton，删除 _CollectionAudioTile
- [x] 验证通过（flutter analyze / flutter test / flutter build macos）

  **完成时间**: 2026-02-23

---

## 音频导入时提取并存储时长

- [x] 新建 `lib/utils/audio_duration.dart` 工具函数，使用 just_audio 临时实例提取时长
- [x] 修改 `AddAudioDialog._addAudio()` 在创建 AudioItem 前调用工具函数获取时长
- [x] 清理 `ListeningPractice.loadAudio()` 中多余的时长回写逻辑

  **完成时间**: 2026-02-22

---

## 音频字幕上传/替换功能

- [x] 为音频添加上传/替换字幕功能（菜单项 + 覆盖确认 + 公共工具方法）

  **完成时间**: 2026-02-22

---

## 上传字幕时记录句子数和单词数

- [x] 数据库表增加 sentenceCount / wordCount 两列 + schema v5→v6 迁移
- [x] AudioItem 模型增加两个字段（构造函数、toJson/fromJson、copyWith）
- [x] 新建 `lib/utils/transcript_stats.dart` 统计工具函数
- [x] AddAudioDialog 创建音频时统计字幕
- [x] transcript_picker 上传/替换字幕时统计
- [x] AudioLibraryProvider 映射 + upsert + 字幕清除时清零 + backfillTranscriptStats
- [x] 启动时补填旧音频缺失统计
- [x] 新增 `test/utils/transcript_stats_test.dart` + 更新 AudioItem 测试
- [x] 学习计划页面显示句子数/单词数/时长 + 无字幕警告横幅 + 禁用开始按钮
- [x] 更新 LearningPlanScreen 测试（3 个新测试 + 修复已有测试）

  **完成时间**: 2026-02-22

---

## 资源库（Library）Tab 改造

- [x] 任务 1：修复 deleteCollection 的 audioIdsMap Bug
- [x] 任务 2：新增独立音频路由
- [x] 任务 3：提取 AddAudioDialog
- [x] 任务 4：CollectionState 新增反向索引
- [x] 任务 5：新建 AudioListView + AudioListTile
- [x] 任务 6：新建合集归属编辑 BottomSheet
- [x] 任务 7：LibraryScreen 改造
- [x] 任务 8：新建 audioListSettingsProvider
- [x] 任务 9：i18n 更新
- [x] 任务 10：测试（已有测试更新 + 新增反向索引测试）

  **完成时间**: 2026-02-22

---

## 基础设施：迁移到 go_router

- [x] 添加 go_router 依赖，创建路由配置（AppRoutes + appRouterProvider）
- [x] 创建 MainShell 组件（StatefulShellRoute.indexedStack 保持 Tab 状态）
- [x] 创建 PackageInfo Provider（替代构造函数传参）
- [x] 改造 main.dart（MaterialApp.router + 删除 MainScreen）
- [x] 改造 SettingsScreen（用 provider 替代构造函数参数）
- [x] 改造 LearningPlanScreen（接收 ID 参数 + ConsumerStatefulWidget + 自行 loadAudio）
- [x] 迁移所有导航调用（collection_screen、collection_detail_screen、learning_plan_screen）
- [x] 更新测试基础设施（test_app.dart、test_notifiers.dart）
- [x] 更新受影响的测试（settings_screen、learning_plan_screen、widget_test）
- [x] 编写路由测试（app_router_test.dart，9 个测试）

  **完成时间**: 2026-02-21

---

## 实现单个音频学习流程引擎
- [x] 用户点击一个音频之后，展示一个学习计划表，有两个大阶段：首学、复习，每个大阶段下面是具体的学习步骤：首学：全文盲听-逐句精听-难句跟读-段级复述；复习：第一轮复习(6小时后), 第二轮复习 (1天后)，第三轮复习（3天后），第四轮复习（5天后），第五轮复习（8天后），第六轮复习（11天后），第七轮复习（2周后），第八轮复习（3周后），第九轮复习（4周后）。

  **完成时间**: 2026-02-21

- [x] 设计学习进度数据模型（阶段、小阶段、完成状态、难度）

  **完成时间**: 2026-02-21

- [x] 学习流程灵活性改进 — stage + subStage 均存字符串键，解耦存储与枚举顺序

  **完成时间**: 2026-02-21

- [x] 扩展学习进度数据模型 — +3 列（lastStageCompletedAt, currentStageStartedAt, totalStudyDurationMs）+ 新建 stage_completions 历史表 + StageCompletionDao + nextReviewAt/isReviewReady 计算属性 + completeCurrentSubStage 写入历史记录 + 复习卡片显示倒计时
  
  **完成时间**: 2026-02-21

- [x] 实现首学流程 — 全文盲听模式

  **完成时间**: 2026-02-21

- [x] 修复盲听播放器 3 个 Bug — 暂停恢复回跳、重播只播最后一句、返回不停止音频 + 移除 `|| true` 调试遗留 + 退出确认弹窗 + 进度条 seek 走 practice 层

  **完成时间**: 2026-02-22

- [x] 盲听播放器重构 — 新建 BlindListenPlayer Provider，绕过 ListeningPractice 复杂状态管理，修复进度条拖动抖动和拖到 0 播放从旧位置开始的 bug；LP 新增 suspendListeners/resumeListeners 方法

  **完成时间**: 2026-02-22

- [x] 已完成盲听步骤可点击单独练习 — `isFreePlay` 标志、跳过完成弹窗/遍数记录、`_StepCard` 支持 `onTap`、`_FirstStudySection` 改为 `ConsumerWidget`

  **完成时间**: 2026-02-22

- [x] 修复倒计时弹窗显示时机 — 根据目标遍数（暂硬编码 2）判断：未达目标显示倒计时后自动播放下一遍，达到目标弹完成对话框；移除 `_completedThisSession` 字段

  **完成时间**: 2026-02-22

- [x] 实现首学流程 — 逐句精听+标注模式

  **完成时间**: 2026-02-22

- [x] 精听设置 — 循环次数 + 停顿时间（IntensiveListenSettings 模型 + StorageService 持久化 + Provider 重构 + 设置面板 UI + 播放器集成 + 国际化）

  **完成时间**: 2026-02-22

- [x] 修复精听标注模式难句标记交互 — 去除 i18n 重复星标、新增 toggleDifficultSentence 方法、SentenceAnnotationCard 可点击切换难句状态

  **完成时间**: 2026-02-22

- [x] 精听设置改为即时生效 + 会话内临时生效 — 移除"完成"按钮改为即改即生效、updateSettings 不再持久化到 SP、清理 StorageService 精听设置代码、新增临时提示文案

  **完成时间**: 2026-02-22

- [x] 三项 UI 修复 — ① 移动端学习计划页面不显示句子数/单词数（watch notifier→watch state select）② 盲听遍间倒计时从全屏弹窗改为内联指示器 ③ 学习计划页盲听 substage 显示难度信息

- [x] 音频学习流程集成测试（20 个新测试） — 学习计划页 5 个（步骤展示/开始学习/无字幕禁用/进度回显/继续精听）、盲听播放器 6 个（UI/播控/倒计时/完成对话框/难度退出/退出确认）、精听播放器 7 个（UI/偷看/导航/标注进入退出/完成/断点保存）、跨页面闭环 2 个（盲听完成→进度更新/精听断点续学）

  **完成时间**: 2026-02-22

- [x] Substage 完成对话框双按钮选择 — 完成对话框改为双按钮（"继续：下一步" FilledButton + "返回计划" OutlinedButton + "再听一遍" TextButton）；末步骤显示"完成首学/复习"按钮；步骤进度显示（1/4）；BlindListenResult 改为 record type 包含 difficulty + continueToNext；盲听/精听播放器均支持直接跳转下一步

  **完成时间**: 2026-02-23

- [x] 实现首学流程 — 难句跟读模式

  **完成时间**: 2026-02-23

- [x] 跟读播放器两项改进 — 新建设置面板（循环次数+停顿模式，复用 IntensiveListenSettings）+ 移除录音按钮占位

  **完成时间**: 2026-02-23

- [x] 跟读停顿设置即时生效 Bug 修复 + 精听/跟读显示句子时长 — ① `_buildPauseCalculator()` 改为每次调用时读取最新 `state.settings`（闭包捕获旧值 bug）② 进度条右侧显示句子时长+起止时间戳（双层级视觉：时长 bodySmall + 时间戳 labelSmall@0.5α）③ 新增 `sentenceDuration` i18n key

  **完成时间**: 2026-02-23

- [x] 学习计划页 substage 卡片显示完成统计 — 精听显示难句数+循环次数、跟读显示难句数+循环次数（数据库+模型+Provider+播放器写入+UI+i18n）

  **完成时间**: 2026-02-23

- [x] 修复学习计划页 substage 卡片统计显示 6 个 Bug — ① 遍数字段语义纠正（RepeatCount→PassCount，改为总完成遍数）② 难句数改为从 bookmarks 表实时查询 ③ 所有退出路径（中途退出/自由练习/正常完成）都保存统计 ④ 跟读/精听 updateSettings 时 clamp currentPlayCount 防止越界显示

  **完成时间**: 2026-02-23

- [x] 修复未开始步骤不应显示难句统计 — 精听/跟读 subtitle 仅在 `isCompleted || isCurrent` 时显示，未开始步骤返回 null

  **完成时间**: 2026-02-24

- [x] 修复难句标记即时持久化 + 退出闪烁 — ① 难句标记点击后即时写入 DB（不再延迟到退出时批量保存）② initialize 预填历史书签（进入精听时从 sentence.isBookmarked 恢复难句状态）③ 正常模式新增星标标记行（可直接点击标记/取消难句）④ 退出时增量同步改为 diff 模式（新增+移除）⑤ 修复退出时星标闪烁（先 pop 再 disposePlayer）

  **完成时间**: 2026-02-24

- [x] 实现首学流程 — 段级复述模式

  **完成时间**: 2026-02-24

- [x] 修复复述播放器 5 个 Bug — ① 播放/暂停按钮不工作（pause 补 stopPlayback + _playCurrentParagraph 局部变量 guard + playRangeOnce/playClipOnce 移除过宽完成条件）② 切换显示模式句子布局跳动（每词独立渲染 _WordBlock 替代合并 _MaskedBlock）③ 学习计划页首学区域折叠支持（_FirstStudySection 新增 isExpanded/onToggle + AnimatedCrossFade）④ 自由练习完成显示错误文案（三分支判断 isFreePlay + 新增 retellCompleteFreePlay i18n key）⑤ 句子 Tile 交互优化（移除整体 GestureDetector + 添加展开按钮 + 可见单词点击回调 + 展开显示翻译/解析 placeholder）

  **完成时间**: 2026-02-24

- [x] 复述播放器 UI/UX 优化 — ① 关键词→可见词文案优化 + KeywordMethod 三选一（关闭/随机/AI）② 显示模式 SegmentedButton 主界面展示 ③ 底部控制栏统一风格（跟读同款圆形大按钮）④ 阶段指示器重构（listening 分行 + retelling 倒计时 120px 短进度条 + 100ms 平滑更新）⑤ 断点保存改用句子索引（分段无关）⑥ 完成对话框重构（步骤进度+统计+再来一遍/完成双操作）⑦ 句子编号改用全局索引

  **完成时间**: 2026-02-24
- [x] 盲听页面移除遍数显示 — 去掉 AppBar 右上角与中部状态区的遍数文案，仅保留倒计时提示

  **完成时间**: 2026-02-25
- [x] 复习阶段基础闭环（先占位）— ① 扩展复习子阶段模型（首轮=难句补练→段级复述；中间轮=全文盲听→难句补练→段级复述；末轮=全文盲听→难句补练→全文总结复述）② Study 页改为任务列表（复习优先）③ 新增 Review Hub 与复习子阶段 placeholder 页面并支持“标记完成并继续”④ 新增每日汇总提醒（默认 20:00）⑤ 通知点击回到学习任务列表

  **完成时间**: 2026-02-25
- [x] 学习计划页复习结构视觉统一 — “首轮复习~第七轮复习”提升为与“首学”同级；保留复习总标题；每轮复习展示自己的子阶段（默认展开）

  **完成时间**: 2026-02-25
- [x] 修复复习锁定防穿透 — 未到时间的复习任务不可提前开始（Study/学习计划/Review Hub/占位页统一禁用入口），并在 Provider 层增加兜底校验避免提前推进进度

  **完成时间**: 2026-02-25
- [x] 修复首轮复习解锁时机 — `review0` 从“立即可做”改为“6小时后解锁”，并同步学习计划页间隔文案与测试

  **完成时间**: 2026-02-25
- [x] 复习解锁时间判定统一为可注入时钟 — 新增 `nowProvider`，统一 Study/学习计划/Review Hub/复习占位页 与 Provider 层解锁判断；补齐 `< / == / > nextReviewAt` 边界测试，支持秒级自动验证无需等待真实时间

  **完成时间**: 2026-02-26
- [x] 复习逾期窗口策略落地与自动化测试补齐 — 逾期定义改为“超过可学习窗口才算逾期”（review0=解锁后6小时窗口，review1~review28=解锁后24小时窗口）；Study/学习计划/复习占位页统一逾期文案，任务排序改为逾期优先并按逾期时长降序；补齐模型/Provider/页面测试覆盖边界

  **完成时间**: 2026-02-26
- [x] 复习入口流程改为首学同款弹窗 — “继续学习”先显示复习任务提示弹窗，点击后直达当前复习子步骤；移除 Review Hub 页面与路由；复习步骤页返回统一回学习计划

  **完成时间**: 2026-02-26
- [ ] 实现复习调度引擎（R1-R28 间隔计算与提醒）
- [ ] 实现学习进度记录与断点续学


## 基础设施：SharedPreferences → Drift 迁移

- [x] 添加 drift, sqlite3_flutter_libs, drift_dev 依赖
- [x] 定义 5 张表（audio_items, collections, collection_audio_items, bookmarks, playback_states）+ 枚举 + 数据库 + 索引
- [x] 编写 4 个 DAO（AudioItemDao, CollectionDao, BookmarkDao, PlaybackStateDao）+ 29 个 DAO 测试
- [x] 编写 SP → Drift 一次性迁移服务 + 7 个迁移测试
- [x] 改造 main.dart（数据库初始化 + 迁移 + Provider override）
- [x] 改造 AudioLibrary Provider（数据源 → AudioItemDao）
- [x] 改造 Collection Provider + Collection 模型（junction 表 + audioIdsMap 缓存 + 移除 audioItemIds）
- [x] 改造 BookmarkManager（数据源 → BookmarkDao，增强版书签存 text/startTime/endTime）
- [x] 改造 PlaybackStateStorage（数据源 → PlaybackStateDao，精简为只存 position_ms）
- [x] 清理 StorageService（仅保留 PlaybackSettings 方法）

  **完成时间**: 2026-02-21

---

## 导航重构

- [x] 将四个 Tab 从 Library | Collections | Player | Account 改为 合集 | 学习 | 收藏 | 我的，默认是学习

  **完成时间**: 2026-02-20

## 优化 UI

- [x] 创建主题系统 `lib/theme/app_theme.dart`（颜色、组件主题、间距常量、语义色）
- [x] 接入主题系统到 main.dart，优化导航栏图标和样式
- [x] 优化播放器页面（控制面板、句子卡片、进度条、图标颜色统一）
- [x] 优化合集页面（卡片视觉、图标颜色、空状态 CTA）
- [x] 优化音频库页面（图标颜色、elevation 统一、空状态）
- [x] 优化设置页面和对话框（Card 分组、间距统一）
- [x] 优化占位页面 StudyScreen / FavoritesScreen 空状态
- [x] 更新测试适配 UI 变更，运行全部验证命令
- [x] 参考 Learna AI 风格视觉改造（蓝色主色调、浅灰背景、卡片去边框加微弱阴影、圆角增大）
- [x] 导航栏选中态蓝色 + 设置页面布局优化（分割线、单行 trailing 值）

  **完成时间**: 2026-02-21

## 优化合集 Tab

- [x] 图标颜色优化：folder/audiotrack 图标从 `onPrimaryContainer` 改为 `primary`（蓝色）
- [x] 音频菜单改为"重命名 + 删除"（原仅"从合集移除"）
- [x] 上传同名音频到同一合集时弹出错误提醒
- [x] 修复字幕标记显示错误：loadLibrary 增加字幕文件存在性验证；AudioItem.copyWith 支持显式 null transcriptPath
- [x] 去掉图标 CircleAvatar 背景色（backgroundColor 改为 transparent）
- [x] 修复合集音频数量不正确：删除音频时清理合集引用 + 启动时清理过期引用

  **完成时间**: 2026-02-21

---

## 任务完成记录模板

<!--
完成任务后，按以下格式在任务下方添加记录：

  **完成时间**: 2026-XX-XX
-->
