# Fluency 任务清单

> 最后更新：2026-03-13
> 当前焦点：录音+识别功能

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
- [x] 跟读页面加入录音按钮，点击后开始录音；首次录音时请求麦克风和语音识别权限。
- [x] 跟读页面利用平台能力实现 live ASR 语音识别（首期支持 iOS + macOS），停止后等待 final transcript 再判定。
- [x] 跟读页面将录音和字幕做 50% 词级 LCS 匹配；未检测到英语时给出识别错误提示。
- [x] 跟读页面录音后在原文下方显示转录结果卡，支持分数 badge、匹配高亮和播放自己的录音；同句重录覆盖旧录音；退出、完成或再来一遍时自动删除临时录音。
- [x] 跟读页面在“轮到用户说”阶段自动开始录音；5 秒未开口轻提醒，15 秒未开口回退为手动录音；用户开口后支持静音自动结束与 5 秒结果倒计时。
- [x] 录音启动延迟优化：AVAudioEngine 页面级常驻，warmup/shutdown 生命周期管理，startSession 从 524ms 降至 ~1ms。
- [ ] 段落复述页面复用同一模块接入录音识别能力。

  **跟读页面完成时间**: 2026-03-12
  **最近回归修复**: 2026-03-12（修复 macOS MethodChannel 注册缺失、跟读页录音结果区 overflow）
  **本次升级完成时间**: 2026-03-12（live ASR、final transcript 判定、统一 backend 接口、结果卡 UI）
  **最新 UI 调整**: 2026-03-12（原文命中词绿色高亮、转录下移到原文下方、小型播放图标、评级替代达标提示、录音回放音量增强）
  **自动录音升级完成时间**: 2026-03-13（跟读回合自动开始录音、speechStarted/silenceProgress 事件、静音自动结束、manual fallback、5 秒 review 倒计时与回放重置）
  **录音 UI 优化**: 2026-03-13（大圆形录音按钮+脉冲/波纹动画、manualFallback 重录 bug 修复、继续按钮 FilledButton.tonal 升级、倒计时圆环放大）
  **录音延迟优化**: 2026-03-13（AVAudioEngine 常驻 + warmup/shutdown 生命周期 + 双路径 startSession）
  **难句补练接入录音**: 2026-03-14（提取共享 UI 组件、回调注入解耦 TurnController、难句补练跟读模式接入自动录音，流程与跟读页完全一致）

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
- [x] 偷看功能改回点击显示（松开不再遮盖），现在是按住显示字幕，使用起来很麻烦

  **完成时间**: 2026-03-11
- [x] 修复学习断点保存/恢复回归：精听、跟读、段落复述统一断点语义，不区分自由练习；未完成时恢复上次位置，完成后清空断点，修复复述总是回到最后一段的问题。

  **完成时间**: 2026-03-12
- [x] 开发者选项中的 `unlock all review` 改为“时光机”，支持选择到分钟的调试时间并可恢复系统时间；开发者选项增加编译期开关，默认 dev 显示、release 隐藏。

  **完成时间**: 2026-03-11
- [x] 本地词典支持 asset 升级自动覆盖，避免 iOS/手机覆盖安装后继续使用旧版 `dict.db` 缓存。

  **完成时间**: 2026-03-12

- [ ] 计算每个任务的估计估计学习时长，显示在音频学习计划也以及学习tab页的任务item上。没有学习的显示估计时长，已经学习的显示真实的耗时。
- [x] 在学习页面的时候，要阻止息屏，现在还会息屏，息屏了之后，播放就停了。

  **完成时间**: 2026-03-11

- [x] 在单词收藏页面，展开单词之后，关联的例句要显示完整，现在只显示两行，多余的就省略了。

  **完成时间**: 2026-03-11

- [x] 难句补练完成之后的弹窗需要显示再来一遍

  **完成时间**: 2026-03-11

- [x] 逐句精听里，用户点“听不懂”进入字幕/查词/翻译/解析页后，点继续要在当前页直接带字幕重播，不再像新开一页；同时退出再进入时要恢复到上次句子断点。

  **完成时间**: 2026-03-11
  **跟进修复**: 2026-03-11，补齐详情页内重播时播放/暂停与上一句/下一句控制，并修复 `ensureProgress()` 覆盖数据库断点导致的精听进度无法恢复问题。
  **扩展修复**: 2026-03-11，将“开始播放一个学习单元就异步写断点”的方案推广到难句跟读、难句补练、段落复述，并统一为进入模式时先通过 `ensureProgress()` 读取最新持久化断点。

- [x] 学习 tab 新音频投放收敛：仅在当前任务数 <= 3 且现有在学音频都进入 `review1+` 时，才投放 1 篇新的未学习音频；新音频按最短时长优先。

  **完成时间**: 2026-03-12

- [ ] 学习 tab 页面点击学习或复习要直接打开学习页面，跳过学习计划页面
- [x] 顶部学习任务有点多余，下面也有一个，分析是否删除一个

  **完成时间**: 2026-03-11

- [x] 要显示每个音频的学习进度，类似资源库中的音频item

  **完成时间**: 2026-03-11

- [x] 段落复述中倒计时时点击上一句播放的是当前句子。点击下一句的时候播放的是后面第二句，跳过了一句（精听和跟读页面是正常的）

  **完成时间**: 2026-03-11
- [x] 段落复述页面，词可见性按钮是否可以放在段落下面（固定位置）放在上面不好点击。

  **完成时间**: 2026-03-11

- [x] 学习计划页面解锁label不能覆盖几天后label，否则会导致混淆，应该两个都显示，几天后这个label应该改成首次学习后几天，这样没有歧义。

  **完成时间**: 2026-03-11

- [x] 学完阶段绿色背景太浅了，看不清

  **完成时间**: 2026-03-11

## 优化今日任务策略
- [x] 现在是所有的没有学过的音频都会出现在学习tab 页，这样可能会导致很多，给用户造成压力。要采用“当目前所有任务都在复习中，并且任务数量 <= 3 的时候，才投放一篇新的（定义一个专门的函数来选择新音频，目前就随机选择一个即可）”。

  **完成时间**: 2026-03-12

## 统计用户词汇量
- [x] 需要创建一个表，专门记录用户已经学习过的唯一的单词（以及首次学习时间），并显示在学习tab 页，让用户知道自己已经听过多少个词汇了

  **完成时间**: 2026-03-12 11:29
  **补充更新**: 2026-03-12 14:59，词汇量 badge 支持底部弹窗分页查看（默认按添加时间倒序，支持时间/字母排序）

## 已完成：AI 单词深度解析功能

- [x] 后端 PostgreSQL `word_analyses` 表 + Drizzle schema
- [x] 后端 API 路由 `POST /api/v1/ai/word-analyze`（L3 unstable_cache + L4 PostgreSQL + LLM 生成）
- [x] Flutter 数据模型 `WordAnalysis`（4 个可选字段：contextMeaning / collocations / usage / wordFamily）
- [x] `SentenceAiApiClient` 扩展 `analyzeWord()` 方法
- [x] `WordAiNotifier` 三级缓存 Provider（L1 内存 → L2 SQLite → L3 API，含并发去重）
- [x] 国际化（5 个新 key，en + zh）
- [x] `WordDictionarySheet` UI 集成（AiContentSection 折叠/展开 + 结构化渲染）
- [x] 测试覆盖（模型 7 + API 客户端 7 + Provider 8 + Widget 6 = 28 个新测试）

  **完成时间**: 2026-03-13

---

## 已完成：输入时间 & 输出时间统计功能

- [x] StudyTimeService 扩展 — 新增 addInputTime / addOutputTime / getWeeklyInputTimes / getWeeklyOutputTimes 等 6 个方法
- [x] StudyStats 模型扩展 — 新增 todayInputSeconds / todayOutputSeconds / dailyInputSeconds / dailyOutputSeconds 4 个字段
- [x] 输入时间埋点（学习模式）— LearningSessionProvider 监听 AudioEngine playerState 追踪音频播放时间
- [x] 输入/输出时间埋点（收藏复习）— BookmarkReview 新增 _inputStopwatch + _outputStopwatch
- [x] 输入时间埋点（闪卡）— FlashcardNotifier 新增 _inputStopwatch（TTS + 例句播放计时）
- [x] 输出时间埋点 — 跟读 onPauseStarted/onPauseEnded、复述 _enterRetellingPhase/_onRetellCountdownFinished、难句补练跟读轮
- [x] UI — Chips 合并（"听: X分 · N词" / "说: X分 · N词"）+ 国际化 listenTimeWords / speakTimeWords
- [x] UI — 柱状图双色堆叠（底部 teal 输入 + 顶部 deepPurple 输出）
- [x] 测试覆盖（10 个新 StudyTimeService 测试，全部通过）

  **完成时间**: 2026-03-15

---

## 已完成：App 版本更新提醒机制

- [x] 后端 `version.json` 静态文件（`../fluency-frontend/apps/app/public/version.json`）
- [x] 版本比较工具（`lib/utils/version_compare.dart`，容错 semver 比较）
- [x] 数据模型（`lib/models/app_update_info.dart`，AppUpdateInfo + sealed AppUpdateState）
- [x] 网络服务（`lib/services/app_update_checker.dart`，独立 Dio + 5s 超时 + 静默失败）
- [x] 状态管理（`lib/providers/app_update_provider.dart`，keepAlive + 自然日节流 + 忽略逻辑）
- [x] UI 对话框（`lib/widgets/app_update_dialog.dart`，soft/force update + 复制链接逃生通道）
- [x] 国际化（10 个新 key，en + zh）
- [x] MainShell 集成（`ref.listenManual` 监听状态变化弹出对话框）
- [x] 设置页"检查更新"入口（手动检查绕过节流，SnackBar 反馈）
- [x] 测试覆盖（version_compare 20 + app_update_info 12 + app_update_checker 5 + provider 8 + widget 4 = 49 个新测试）

  **完成时间**: 2026-03-15

---

## 意群划分功能

## 增加自由练习功能
- [x] 用户点击一个音频之后，进入学习计划页面，在页面右上角增加“自由练习”按钮，点击之后进入自由练习页面，这个页面就类似最早期的播放器，按句子显示transcript，并且可以点击句子进行播放，可以查看收藏的句子列表，可以点击上一句，下一句，重复次数等。可以检查一下早期的播放器，应该有大部分代码都可以复用

  **完成时间**: 2026-03-12

---

## 任务完成记录模板

<!--
完成任务后，按以下格式在任务下方添加记录：

  **完成时间**: 2026-XX-XX
-->
