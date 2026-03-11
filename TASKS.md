# Fluency 任务清单

> 最后更新：2026-03-10
> 当前焦点：Flashcard 单词卡片复习

## 历史归档
- [Milestone 2 - 学习流程引擎](./docs/tasks-archive/milestone-2-learning-engine.md)
- [Milestone 3 - 收藏与标注体系 + 体验优化](./docs/tasks-archive/milestone-3-completed.md)

---

## 已完成：iOS Universal Links（echo-loop.top）
- [x] iOS Runner 增加 Associated Domains capability（`echo-loop.top` + `www.echo-loop.top`）
- [x] 新增 `apple-app-site-association` 模板，覆盖当前 App 支持的主要路由
- [x] 补充部署与真机验证文档，便于后续 App Store 上架自查

  **完成时间**: 2026-03-09

---

## 已完成：iOS Bundle ID 调整
- [x] iOS Runner 主目标 Bundle ID 改为 `top.echo-loop`
- [x] iOS RunnerTests Bundle ID 同步改为 `top.echo-loop.RunnerTests`
- [x] Universal Links AASA `appIDs` 与 iOS 文档类型标识同步更新

  **完成时间**: 2026-03-10

---

## 已完成：iOS 上架前配置清单
- [x] iOS App 显示名改为 `Echo Loop`
- [x] 新增 App Store 上架清单文档，区分“已具备 / 待人工准备 / 真机检查”
- [x] 明确录音与语音识别权限文案留待相关功能接入后再补

  **完成时间**: 2026-03-10

---

## 已完成：iOS 发布步骤文档
- [x] 新增 iOS 发布操作文档，覆盖 archive、export、upload、build-status 查询
- [x] 记录 App Store Connect API Key 用法与每条命令的作用
- [x] 补充 Xcode 导出失败时的手工 IPA 封装兜底方案

  **完成时间**: 2026-03-10

---

## 已完成：iOS 一键发布脚本
- [x] 新增 `scripts/release_ios.sh`，一键执行 archive、export/兜底封包、upload
- [x] 支持 `--skip-upload`、`--wait` 和环境变量覆写
- [x] 补充脚本级测试与文档入口

  **完成时间**: 2026-03-10

---

## 已完成：iOS 字幕文档类型警告修复
- [x] 为 `SubRip Subtitle` 和 `WebVTT Subtitle` 补充 `LSHandlerRank`
- [x] 补充 `Info.plist` 元数据测试，避免 ITMS-90788 再次出现
- [x] 更新 iOS 发布文档中的 warning 说明

  **完成时间**: 2026-03-10

---

## 已完成：iOS 多语言桌面名称
- [x] iOS 桌面名称支持英文系统显示 `Echo Loop`
- [x] iOS 桌面名称支持简体中文系统显示 `Echo Loop`
- [x] 新增 `InfoPlist.strings` 本地化资源与对应测试

  **完成时间**: 2026-03-10

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

## 已完成：词典功能优化
- [x] 增加发音功能，调用平台自己的能力即可。

  **完成时间**: 2026-03-09

## 已完成：单词收藏列表页面增加 Flashcard 功能
- [x] 用户点击右上角的测验按钮，进入flashcard模式
- [x] 正面显示单词，以及发音，背面显示释义，以及关联的例句
- [x] 在正面用户点击查看答案翻转到背面，在背面点击 clip to flip，翻转回正面（有动画）
- [x] 无论正面还是背面都在右上角显示取消收藏按钮，并显示浅色字体提醒用户掌握了就取消收藏
- [x] 也支持自动下一个词，倒计时（默认8秒），支持手动点击上一个、下一个，支持左右滑动切换
- [x] 在flashcard页面右上角提供一个设置按钮，支持让用户设置倒计时时间（固定时间，智能设定，关闭），设置顺序（字典序正序/倒序，时间正序/倒序，随机，智能排序）
- [x] 记录用户每个单词的练习次数，学习时间（最长60秒截断），是否查看背面，实现智能倒计时和智能调度的简单算法
- [x] DB 迁移 v16→v17（saved_words 新增 4 列）
- [x] TtsService 单例 + WordDictionarySheet 发音按钮
- [x] FlashcardSettings 模型 + SharedPreferences 持久化
- [x] FlashcardTimer 倒计时 + FlashcardNotifier Provider
- [x] FlashcardCard 3D 翻转组件 + FlashcardScreen 页面 + 完成页面
- [x] FlashcardSettingsSheet 设置弹窗
- [x] 路由注册 /flashcard + Favorites 入口按钮
- [x] 国际化（25 个新 key，en + zh）
- [x] AppLifecycleListener 暂停/恢复倒计时
- [x] 词典懒加载（当前卡片 + 前后各 2 张）
- [x] 测试覆盖（FlashcardSettings 18 个 + FlashcardTimer 7 个 = 25 个新测试）

  **完成时间**: 2026-03-09

## 已完成：Flashcard 测试覆盖
- [x] 单元测试（FlashcardState / FlashcardWordItem / 倒计时算法 / 排序 / 智能分数 / 例句额外秒数，28 个）
- [x] 组件测试（FlashcardScreen 基本渲染 / 翻转交互 / 完成视图 / 暂停状态 / 中文本地化，9 个）
- [x] 集成测试（导航 + 卡片显示 / 翻转 / 前后切换 / 完成流程 / 暂停恢复 / 退出清理，10 个）
- [x] TestFlashcardNotifier 集成测试替身（test_notifiers.dart）

  **完成时间**: 2026-03-09

## 已完成：Flashcard UI 优化
- [x] 移除底部多余翻转按钮，点击卡片即翻转
- [x] 关联例句支持播放原声（复用 AudioEngine，带播放/停止状态切换）
- [x] 柯林斯星级 + 考试标签移至单词下方、释义上方（匹配词典弹窗布局）
- [x] 收藏按钮改为高亮样式（Icons.bookmark + primary color）
- [x] 设置按钮改为 Icons.tune（与其他学习页面一致）
- [x] 新增"自动播放例句"设置（默认开启），翻转到背面时 TTS 朗读完毕 + 600ms 间隔后自动播放例句原声
- [x] 倒计时改为环形进度（CircularProgressIndicator + 暂停/恢复按钮），进度连续平滑变化
- [x] 切换卡片/翻转时立即停止 TTS 和音频播放，避免声音重叠
- [x] 入口按钮文案改为"开始复习"并显示单词数量

  **完成时间**: 2026-03-09

## FIX bug
- [ ] 偷看功能改回点击显示（松开不再遮盖），现在是按住显示字幕，使用起来很麻烦
- [ ] 计算每个任务的估计估计学习时长，显示在音频学习计划也以及学习tab页的任务item上。没有学习的显示估计时长，已经学习的显示真实的耗时。
- [ ] 在学习页面的时候，要阻止息屏，现在还会息屏，息屏了之后，播放就停了。
- [ ] 在单词收藏页面，展开单词之后，关联的例句要显示完整，现在只显示两行，多余的就省略了。
- [ ] 难句补练完成之后的弹窗需要显示再来一遍
- [ ] 学习 tab 页面点击学习或复习要直接打开学习页面，跳过学习计划页面
- [ ] 顶部学习任务有点多余，下面也有一个，分析是否删除一个
- [ ] 要显示每个音频的学习进度，类似资源库中的音频item
- [ ] 段级复述中倒计时时点击上一句播放的是当前句子。点击下一句的时候播放的是后面第二句，跳过了一句（精听和跟读页面是正常的）
- [ ] 段级复述页面，词可见性按钮是否可以放在段落下面（固定位置）放在上面不好点击。
- [ ] 学习计划页面解锁label不能覆盖几天后label，否则会导致混淆，应该两个都显示，几天后这个label应该改成首学后几天，这样没有歧义。
- [ ] 学完阶段绿色背景太浅了，看不清

## 优化今日任务策略
- [ ] 用户第一次打开app 的时候，让用户选择每天的目标学习时长，同时支持在设置tab中让用户随时修改目标学习时长。
- [ ] 根据目标学习时长，自适应地调整今日任务。
  - [ ] 现在是所有的没有学过的音频都会出现在学习tab 页，这样可能会导致很多，给用户造成压力。要采用“至少间隔两天，并且任务不过载时，才投放一篇新的（定义一个专门的函数来选择新音频，目前就随机选择即可）”，。

## 统计用户词汇量
- [ ] 需要创建一个表，专门记录用户已经学习过的唯一的单词（以及首次学习时间），并显示在学习tab 页，让用户知道自己已经听过多少个词汇了

## 优化开发者选项
- [ ] 把开发者选项中的unlock all review，改成时光机，点击之后可以选择当前的日期和时间（精确到分钟即可），这样可以更方便的调试任务的调度和解锁功能
- [ ] 使用一个变量来控制是否显示开发者选项，release 包应该不包含，dev 包应该包含

## 意群划分功能

---

## 任务完成记录模板

<!--
完成任务后，按以下格式在任务下方添加记录：

  **完成时间**: 2026-XX-XX
-->
