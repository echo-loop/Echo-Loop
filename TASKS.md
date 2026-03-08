# Fluency 任务清单

> 最后更新：2026-03-06
> 当前焦点：AI 翻译 & AI 解析功能

## 历史归档
- [Milestone 2 - 学习流程引擎](./docs/tasks-archive/milestone-2-learning-engine.md)

---

## 已完成：管理字幕功能

### Phase 1：底部弹窗 + 本地上传 + 删除字幕

- [x] #1 数据模型扩展（TranscriptSource 枚举 + AudioItem 新字段 + DB 迁移 v12→v13）
- [x] #2 管理字幕底部弹窗 UI 骨架（ManageSubtitlesSheet）
- [x] #3 菜单入口替换 + 本地上传集成
- [x] #4 删除字幕功能
- [x] #5 国际化（25 个新 key）

  **完成时间**: 2026-03-05

### Phase 2：AI 转录完整流程

- [x] #6 SHA256 计算工具（`lib/utils/audio_fingerprint.dart`，Isolate + crypto 包）
- [x] #7 后端：user_audios + user_audio_transcripts 表 + 5 个 HTTP API Routes
- [x] #8 转录 API 客户端（`lib/services/transcription_api_client.dart`，Dio）
- [x] #9 SRT 格式转换工具（`lib/utils/srt_generator.dart`）
- [x] #10 转录状态 Provider（`lib/providers/transcription_task_provider.dart`，keepAlive）
- [x] #11 AI 转录 UI 集成（进度显示、语言禁用逻辑、覆盖确认）
- [x] #12 AudioListTile 后台转录进度指示

  **完成时间**: 2026-03-05

### 测试覆盖

- [x] AudioItem 模型测试（31 个，含新字段 copyWith + 序列化）
- [x] ManageSubtitlesSheet Widget 测试（10 个）
- [x] SRT 格式转换测试（8 个）
- [x] SHA256 计算工具测试（5 个）
- [x] 转录 API 客户端测试（11 个）
- [x] TranscriptionTaskManager 单元测试（15 个）
- [x] 管理字幕集成测试（7 个 E2E 场景）

  **完成时间**: 2026-03-05

### UI 优化与错误处理

- [x] #13 管理字幕弹窗 UI 优化（卡片式选项、删除按钮移至标题栏）
- [x] #14 简化转录错误提示（短码 + i18n 本地化）
- [x] #15 移除字幕来源状态标签（避免歧义）
- [x] #16 提取全局 API 配置（`lib/config/api_config.dart`）
- [x] #17 iOS 原生网络权限触发（Method Channel + URLSession）
- [x] #18 iOS ATS 例外配置（NSAllowsArbitraryLoads）

  **完成时间**: 2026-03-05

### 验证结果

- flutter analyze: 通过（info，无错误）
- flutter test: 全部通过
- flutter test integration_test -d macos: 全部通过（61 个）
- flutter build macos: 通过

---

## 已完成：AI 翻译 & AI 解析功能

### 后端（Next.js）

- [x] 新增 `sentence_translations` 和 `sentence_analyses` PostgreSQL 表 + DB 迁移
- [x] 共享工具：`text-normalize.ts`（归一化 + SHA256 hash）
- [x] 共享工具：`generate-with-retry.ts`（AI 生成 + Zod 校验 + 模型 fallback）
- [x] `POST /api/v1/ai/translate` API Route（DB 缓存 → LLM 生成）
- [x] `POST /api/v1/ai/analyze` API Route（DB 缓存 → LLM 生成）

### Flutter 数据层

- [x] 数据模型：`SentenceTranslation` + `SentenceAnalysis`（`lib/models/sentence_ai_result.dart`）
- [x] 归一化工具：`normalizeForCache()` + `hashText()`（`lib/utils/text_normalize.dart`）
- [x] SQLite 缓存表：`SentenceAiCache` + `SentenceAiCacheDao`（DB v13→v14）
- [x] API 客户端：`SentenceAiApiClient`（`lib/services/sentence_ai_api_client.dart`，60s timeout）
- [x] 状态管理：`SentenceAiNotifier`（L1 内存 → L2 SQLite → L3 API 三级缓存 + 防重复请求）

### Flutter UI 层

- [x] `AiContentSection` 可折叠组件（4 态：收起/加载中/已加载/错误，shimmer 骨架屏）
- [x] `SentenceAnnotationCard` 改造（替换静态 placeholder 为 AiContentSection）
- [x] 精听页面集成（`_AnnotationModeView` 接入 SentenceAiNotifier）
- [x] 国际化（新增 aiTranslation/aiAnalysis/aiLoadFailed/aiRetry，移除旧 placeholder key）

### 测试覆盖（58 个新测试）

- [x] 数据模型序列化测试
- [x] 归一化 + hash 函数测试
- [x] SentenceAiCacheDao 测试（6 个）
- [x] SentenceAiApiClient 测试（8 个）
- [x] SentenceAiNotifier Provider 测试（9 个）
- [x] AiContentSection Widget 测试（13 个）
- [x] SentenceAnnotationCard Widget 测试

### 验证结果

- flutter analyze: 通过（36 info，无错误/警告）
- flutter test: 全部通过（717 个）
- flutter build macos: 通过（73.8MB）

  **完成时间**: 2026-03-06

---

## 待完成：学习进度记录与断点续学
- [x] 实现学习进度记录与断点续学

## 用户体验优化
- [x] 优化段级复述页面的复述时间的计算逻辑，改成 2秒+三倍段落长度
- [x] 修改逐句精听的偷看功能，按住按钮才显示字幕，松开就隐藏，并且只对当前正在播放的句子生效，播放下个句子的时候自动reset到隐藏状态

  **完成时间**: 2026-03-05

  **完成时间**: 2026-03-05
- [x] 在段级复述页面，把连续的隐藏的文字的蒙版连续显示

  **完成时间**: 2026-03-05
- [x] 在倒计时阶段（逐句精听、跟读、复述、难句补练等），播放按钮的行为改成再播放一遍（播放时取消已有倒计时，播放完成后重新倒计时），另外显示两个控制倒计时的按钮：暂停计时，和快进（10倍速度，不是立即结束计时），注意还没有播放的时候以及播放的时候不显示倒计时，播放完成后才显示

  **完成时间**: 2026-03-05
- [x] 优化 4 个播放器页面的倒计时控制 UI：将倒计时进度环移至独立 CountdownChip、移除快进按钮、统一布局样式（轻量导航按钮、56px 播放按钮、ActionChip 偷看字幕）、固定高度防止布局跳动

  **完成时间**: 2026-03-06
- [x] 难句补练"听不懂"改为跟读模式（播放+留白×3遍自动推进，替换标注卡片+单次重播）

  **完成时间**: 2026-03-06
- [x] 难句补练跟读模式复用 SentenceAnnotationCard（可点击查词 + 翻译/分析占位卡片）

  **完成时间**: 2026-03-06
- [x] 跟读/难句补练页面添加跟读提示（播放中"先听，听完后跟读" / 留白期"请跟读这个句子"）

  **完成时间**: 2026-03-06
- [x] 在进入一个学习阶段的时候，显示预估时长

  **完成时间**: 2026-03-06
- [x] 难句跟读页面，精听页面，难句星标放在右侧

  **完成时间**: 2026-03-06
- [x] 学习页面左上角的返回按钮改成 X，并且不用支持滑动返回效果

  **完成时间**: 2026-03-06
- [x] 在自由学习模式下，学完也弹窗，提醒用户完成或再学一遍

  **完成时间**: 2026-03-06
- [x] 学习过程中，如果息屏了，要后台播放（已支持：iOS UIBackgroundModes:audio + audio_session playback 模式）

  **完成时间**: 2026-03-06
- [x] 统计用户每日的学习时长

  **完成时间**: 2026-03-06
- [x] 在所有界面支持快捷键控制播放、暂停、上一句、下一句

  **完成时间**: 2026-03-06
- [x] 对于段级复述，首学和首轮复习的默认选项应该是逐句，第一轮，第二轮都是10秒，第三轮第四轮都是20秒，第5轮，第6轮都是30秒

  **完成时间**: 2026-03-07

## 学习 tab 页
- [x] 文章item 上显示正确的当前的学习阶段如首学-精听，第2轮复习-段级复述，未开始等。

  **完成时间**: 2026-03-08
- [x] 在上方显示一些统计信息，包括今日学习时长，本周学习时长，本月学习时长，输入词数（听了多少词），输出词数（跟读了多少词），最好显示一个过去7天的柱状图，高度表示学习时长。

  **完成时间**: 2026-03-08
- [x] 学习 Tab 重设计：Hero Card 一键继续学习、统计 Chips（连续天数/今日/本周时长）、7天柱状图、任务卡片增强（子阶段+进度条+按钮细化）、待解锁折叠、已完成折叠、空状态优化（无任务跳转Library/全部完成鼓励）、国际化迁移

  **完成时间**: 2026-03-08

## 录音+识别功能
- [ ] 在跟读、段级复述中加入一个录音按钮，类似多邻国，点击之后开启录音，如果是第一次录音，需要请求权限。
- [ ] 利用平台能力实现语音识别的功能。
- [ ] 将录音和字幕对比，达到50%即可。如果识别错误就提醒错误，类似多邻国。
- [ ] 录音之后添加一个播放录音按钮，点击之后可以播放自己的录音，如果一句话录音多次，就覆盖上一次的。录音在学习阶段退出或完成的时候自动删除，不需要持久化。

## 已完成：本地词典功能

- [x] 集成本地词典数据库（dict.db），点击单词弹出音标、释义、柯林斯星级、考试标签
- [ ] 支持收藏单词，收藏的时候要记录这个单词来源的音频和句子。如果用户删除的音频或字幕，不删除单词，但是把音频或句子来源设置为NULL

  **完成时间**: 2026-03-05

## 优化UI，使得用户看起来更舒服而不单调
- 支持自定义背景、背景音

---

## 任务完成记录模板

<!--
完成任务后，按以下格式在任务下方添加记录：

  **完成时间**: 2026-XX-XX
-->
