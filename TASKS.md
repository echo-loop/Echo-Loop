# Fluency 任务清单

> 最后更新：2026-03-09
> 当前焦点：录音+识别功能

## 历史归档
- [Milestone 2 - 学习流程引擎](./docs/tasks-archive/milestone-2-learning-engine.md)
- [Milestone 3 - 收藏与标注体系 + 体验优化](./docs/tasks-archive/milestone-3-completed.md)

---

## 临时修复
- [x] 精听标注文案分支修复：仅“看不懂”自动标记当次显示“已自动标记为难句，点此取消”，其余显示“已标记为难句，点此取消”。
  **完成时间**: 2026-03-09
- [x] 修复段落复述切段时 `stopPlayback` 与 `playRangeOnce` 竞态，避免 `just_audio` 抛出 `Loading interrupted`。
  **完成时间**: 2026-03-09

---

## 录音+识别功能
- [ ] 在跟读、段级复述中加入一个录音按钮，类似多邻国，点击之后开启录音，如果是第一次录音，需要请求权限。
- [ ] 利用平台能力实现语音识别的功能。
- [ ] 将录音和字幕对比，达到50%即可。如果识别错误就提醒错误，类似多邻国。
- [ ] 录音之后添加一个播放录音按钮，点击之后可以播放自己的录音，如果一句话录音多次，就覆盖上一次的。录音在学习阶段退出或完成的时候自动删除，不需要持久化。

## 已完成：本地词典功能

- [x] 集成本地词典数据库（dict.db），点击单词弹出音标、释义、柯林斯星级、考试标签
- [x] 支持收藏单词，收藏的时候要记录这个单词来源的音频和句子。如果用户删除的音频或字幕，不删除单词，但是把音频或句子来源设置为NULL

  **完成时间**: 2026-03-08

## 已完成：Favorites Tab 功能（MVP）

### 数据层
- [x] saved_words 表定义 + DB 迁移 v14→v15
- [x] SavedWordDao（watchAll / saveWord / removeWord / isWordSaved / watchIsWordSaved）
- [x] BookmarkDao 扩展 — watchAllWithAudioName() JOIN audio_items
- [x] SavedWordNotifier Provider（riverpod_generator 代码生成）
- [x] isWordSavedProvider（流式监听单词收藏状态）

### UI 层
- [x] WordDictionarySheet 添加收藏按钮（bookmark 图标 + 来源信息传递）
- [x] SentenceAnnotationCard 扩展（audioItemId + sentenceIndex 透传到词典弹窗）
- [x] Favorites Tab 句子视图（按音频分组 ExpansionTile + Dismissible 左滑删除）
- [x] Favorites Tab 单词视图（ExpansionTile 展开详情 + 词典释义 + 来源句子 + Dismissible）
- [x] SegmentedButton 切换句子/单词视图
- [x] 空状态引导

### 国际化
- [x] 新增 12 个 Favorites 相关 ARB key（en + zh）

### 测试
- [x] SavedWordDao 单元测试（8 个）
- [x] BookmarkDao.watchAllWithAudioName 单元测试（5 个）

  **完成时间**: 2026-03-08

## 已完成：收藏句子一键复习功能

- [x] i18n key（bookmarkReviewTitle / Start / Complete / Again / AudioSkipped / FromAudio / Progress，en + zh）
- [x] BookmarkSentence 数据类（Sentence + audioItemId + audioName）
- [x] BookmarkReviewProvider（跨音频复习、按音频分组乱序、跟读模式、取消收藏、再来一遍）
- [x] BookmarkReviewScreen UI（复用 ReviewDifficultPracticeScreen 布局 + 音频来源显示）
- [x] 路由注册（/bookmark-review，parentNavigatorKey: rootNavigatorKey）
- [x] Favorites 入口按钮（句子列表上方 FilledButton.tonal "开始复习 (N)"）
- [x] 单元测试（BookmarkSentence + State 行为 + 分组乱序逻辑，9 个）

  **完成时间**: 2026-03-08

## 优化收藏页
- [x] 句子收藏页面，需要在每个句子item 上显示收藏icon，用户可以点击取消收藏，不需要展开。

  **完成时间**: 2026-03-08
- [x] 句子收藏页面，每个音频item上（展开之前），都需要有一个按钮可以让用户练习这一篇中的收藏句。

  **完成时间**: 2026-03-08
- [x] 单词收藏页面，需要在每个单词item 上显示收藏icon，用户可以点击取消收藏，不需要展开。

  **完成时间**: 2026-03-08

## 已完成：难句补练 & 收藏复习页面添加设置
- [x] DifficultPracticeSettings 模型（盲听/跟读循环次数 + 句间停顿模式）
- [x] ReviewDifficultPracticeProvider / BookmarkReviewProvider 支持 settings + updateSettings
- [x] 设置底部弹窗（DifficultPracticeSettingsSheet，复用精听设置 UI 模式）
- [x] AppBar 添加设置按钮（难句补练 + 收藏复习两个页面）
- [x] 国际化（4 个新 key，停顿相关复用精听已有 key）
- [x] 单元测试（DifficultPracticeSettings 模型 11 个）

  **完成时间**: 2026-03-08

## 已完成：输入词数 & 输出词数统计

- [x] 词数计算工具函数（`lib/utils/word_counter.dart`，countWords + countWordsInSentences）
- [x] 词数存储服务（`StudyTimeService` 新增 addInputWords / addOutputWords / getTodayInputWords / getTodayOutputWords）
- [x] LearningSession 词数即时持久化（addInputWords / addOutputWords 直接写 SharedPreferences）
- [x] 精听播放器埋点（每遍播完 +inputWords）
- [x] 跟读播放器埋点（播完 +inputWords，停顿开始 +outputWords）
- [x] 复述播放器埋点（听完段落 +inputWords，复述完成 +outputWords）
- [x] 难句补练埋点（盲听 +inputWords，跟读 +inputWords +outputWords）
- [x] 盲听逐句追踪（position stream 监听，播过一句即计入，中途退出不丢数据）
- [x] StudyStats 扩展（todayInputWords / todayOutputWords 字段）
- [x] UI 展示（2 个新 Chip：输入/输出词数，格式化 < 1k / 1,234 / 12.3k）
- [x] 词数实时更新（addInputWords/addOutputWords 后自动刷新 studyStatsNotifierProvider）
- [x] 国际化（inputWordsShort / outputWordsShort，en + zh）
- [x] 测试覆盖（word_counter 13 个 + study_time_service 8 个新测试）

  **完成时间**: 2026-03-09

## 优化UI，使得用户看起来更舒服而不单调
- [x] AudioListTile 优化：左侧改为环形进度图标（未学习/进行中/已完成），副标题元数据用 `·` 分隔，桌面端加宽内边距
- [x] 弹窗合并：创建 4 个共享弹窗组件（StepCompleteDialog、FreePlayCompleteDialog、ConfirmDialog、TextInputDialog），迁移 9 个文件，删除约 650 行重复代码
- [ ] 支持自定义背景、背景音

  **完成时间**: 2026-03-09

## 词典功能优化
- [ ] 增加发音功能，调用平台自己的能力即可。

## 单词收藏列表页面增加flashcard功能
- [ ] 用户点击右上角的测验按钮，进入flashcard模式
- [ ] 正面显示单词，以及发音，背面显示释义，以及关联的例句
- [ ] 在正面用户点击查看答案翻转到背面，在背面点击 clip to flip，翻转回正面（有动画）
- [ ] 无论正面还是背面都在右上角显示取消收藏按钮，并显示浅色字体提醒用户掌握了就取消收藏
- [ ] 也支持自动下一个词，倒计时5秒，也支持手动点击上一个，下一个
- [ ] 在flashcard页面右上角提供一个设置按钮，支持让用户设置倒计时时间（固定时间，智能设定），设置顺序（字典序（正序、倒序），时间（正序、倒序），随机，智能（根据用户的掌握程度自动调度）。
- [ ] 记录用户每个单词（取消收藏的不记录）的练习次数，学习时间，是否查看背面，方便做智能倒计时和智能调度，目前只需要实现placeholder，采用简单算法。学习时间要做阶段，最长1分钟，防止用户挂机污染数据。

---

## 任务完成记录模板

<!--
完成任务后，按以下格式在任务下方添加记录：

  **完成时间**: 2026-XX-XX
-->
