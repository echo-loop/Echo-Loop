# Echo Loop 项目规划

> 最后更新：2026-07-02
> 当前焦点：录音+识别功能

---

## 已完成：学习材料导出 PDF

**完成时间**: 2026-07-02

把一篇学习材料（音频+字幕）导出为可打印的 PDF：左栏文章句子、右栏词汇笔记（收藏词/意群 + 音标 + 斜体词性 + 释义 bullet；全文无词条时不分栏），翻译弱化为句下灰字，AI 解析集中在文末「附录 · 句子解析」（正文句末尾注标记 [n] 与附录条目内部链接互跳）。学术论文风格（首版彩色底色块样式被用户否决后重设计）：无底色块、收藏句句末书签图标、收藏词橙色细下划线 + 词后上标词条标号（全文档统一编号且**全局标记**——同一收藏词在任何句子出现都标同号；与右栏同号互跳，`vocab-{n}` 锚点）、附录字段标签灰底 badge + `` `引用片段` `` 灰底高亮、首页标题居中 + ECHO LOOP 品牌、次页 running header。样式规则固定（自动样式），只导出已有缓存不发 AI 请求（AI 词典严格优先于本地，含 lemma→表面词形兜底查缓存），入口在资源库/合集音频条目菜单。

- **技术选型**：Dart `pdf` 包（^3.12.0）端上生成 + 既有 `Share.shareXFiles` 分享流；不引入 printing。字体必须内置 TrueType（系统 CJK 字体是 CFF/TTC，pdf 包解析不了），NotoSans Regular/Bold/Italic + NotoSansSC 共 ~12.3MB，生成时自动子集化
- **分层**：`study_pdf_loader.dart`（数据聚合，DAO 注入可测）→ `study_pdf_data.dart`（纯模型，跨 isolate）→ `study_pdf_builder.dart`（compute isolate 渲染）→ `study_pdf_export_service.dart`（门面）→ `export_pdf_runner.dart`（UI 编排）
- **关键约束**：MultiPage 只有顶层兄弟块之间可断页（句子行/附录字段必须拍平；翻译并入句子行左栏 Column，独立块会被右栏高度推出空隙）；`maxPages` 默认 20 需显式调大；收藏词/句按「索引+文本双重校验」归句防字幕重解析错位；收藏下划线区间复用 App 的 `SavedTextIndex`/`savedCharRanges` 纯逻辑保证语义一致
- **pdf 包渲染坑**（详见 TASKS.md 第四轮）：RichText 各 span 是独立断行单元（标号须与词合并为原子 WidgetSpan）；RichText 按 span 跟踪 fill color 而 `_WidgetSpan.paint` 不保存图形状态，内部改色会染色后续正文（用 `_PaintIsolate` 借 SingleChildWidget.paintChild 的 q/Q 包裹所有内嵌 WidgetSpan 子树）；WidgetSpan 底边落在行基线，内部文字须按 `-(内边距+字号×descent)` 下移对齐；`TextDecoration.underline` 画在 baseline 下 descent/2 处（写死不可调）会切过 descender——收藏词下划线改为逐词 Container 底边框自绘（画在字形框之下）
- 测试：loader 18 + builder 8 + DAO 2 + widget 2；样例 PDF 渲染目检通过

---

## 已完成：词典交互重设计——非 modal 常驻面板 + 词组选区手柄

**完成时间**: 2026-07-02

响应用户反馈（不支持词组查询、modal 弹窗连续查词体验差），按业界标准（每日英语听力/LingQ/Kindle）重设计词典交互，设计约束见 CLAUDE.md §7.25：

- **非 modal 面板**：`DictionaryPanelHost`（Stack 内嵌、页面局部 state）+ `DictionaryPanel`（原 `word_dictionary_sheet` 迁移，resize/下拉关闭保留）。面板显示期间正文可继续点词/选词组，点新词原地切换；关闭方式：X/下拉/返回键（经 `closeIfOpen()` guard 先关面板）/点句子外区域（带词区域豁免的屏障，吸收点击不触发下层操作）
- **词组选择**：`SelectableSentenceText`（统一两套旧点词实现）——点词即查并出词级吸附选区手柄，拖动扩选、松手查词组；长按复制整句保留。查词管线：`normalizeWord` 折叠内部空白、词组默认 AI 源、AI 缓存零迁移、V1 不带句子上下文
- 6 个宿主页接入（player / sentence_detail / 精听 / 跟读 / 收藏复习 / 难句补练），`showWordDictionarySheet` modal 路径删除

---

## 已完成：多词典源查词（可插拔框架）

**完成时间**: 2026-06-27

查词弹窗从「单一本地词典」升级为「可切换的多词典源」可插拔框架。本期落地本地 / AI / Cambridge 三个真实源；加新源（如 Oxford）只需实现 `DictionarySource` + 在注册表加一行，不改现有源 / 弹窗 controller / 设置。

### 架构
- sealed `DictionaryLookupResult`（Local/Ai/WebDict）+ 各源独立渲染器（编译期穷尽 switch 兜底新增源）
- `DictionarySource` 接口（id/icon/canBeDisabled/requiresNetwork/lookup）+ 静态注册表 + 派生「可见源 / 生效默认源」
- `DictionaryLookupController`（family by word；选中源 + 各源态缓存 + 每源序列号/CancelToken 防竞态）
- `DictionarySettingsNotifier`（SharedPreferences；默认源 + 禁用集；禁用当前默认源自动回退）

### 数据源
- 本地：复用 `DictionaryService`（离线，不可禁用）
- AI：后端 `POST /api/v2/ai/dictionary`（Bearer 登录态）→ 结构化 `DictionaryEntry`（音标/词义/搭配/词族/词源/提示）；三级缓存；依赖延迟解析
- 网页源（共 8 个）：`flutter_inappwebview` 显示词条网页（单实例保活 + 5min「源+词」复用 + CSS 收敛；不支持平台降级外部打开）；均可禁用。由配置表 `kWebDictConfigs` 驱动的通用 `WebDictionarySource`/`WebDictResult`/`WebDictionaryView`——加一个网页词典只需加一行配置：
  - Cambridge（中英对照）/ Oxford / Longman / Merriam-Webster / Collins / Vocabulary.com / 有道 / 欧陆
  - 默认全部启用；Macmillan 未纳入（官网已永久关停）

### UI
- 弹窗右上角下拉切换器（图标+名称，仅列已启用源，标记默认）+ AnimatedSwitcher 平滑过渡；TTS/收藏跨源恒定
- 「我的」Tab → 词典设置（默认词典单选 + 源开关，本地/AI 锁定）
- AI 结果视图美化（2026-06-27）：对齐后端新 entry 格式（`learnerTips` 改字符串数组、`wordFamily` 加 `meaning`）；多义项序号 + 细分隔、近/反义词 chips、例句圆角淡底块、搭配 `type` 标签、词族 `meaning`、学习提示项目符号、补充分节柔和卡片，整体专业简洁

### 测试覆盖
- 模型/设置/可见列表/三源/controller 单测 + 各视图/切换器/设置页/弹窗多源切换 widget 测；`flutter analyze` 0（新代码）、`flutter test` 全过

---

## 已完成：AI 翻译 & AI 解析功能

**完成时间**: 2026-03-06

在精听标注模式中集成 AI 翻译和 AI 解析功能，替换原有静态占位区域：

### 后端
- PostgreSQL 缓存表（sentence_translations / sentence_analyses）
- 两个独立 API（POST /api/v1/ai/translate, POST /api/v1/ai/analyze）
- 共享工具（text-normalize, generate-with-retry + 模型 fallback 链）

### Flutter
- 四级缓存：L1 内存 Map → L2 SQLite → L3 Next.js → L4 PostgreSQL
- 可折叠 AiContentSection 组件（shimmer 骨架屏、错误重试）
- 精听页面集成（lazy load，用户点击展开才请求）

### 测试覆盖
- 58 个新测试，总计 717 个测试全部通过

---

## 已完成：AI 单词深度解析功能

**完成时间**: 2026-03-13

在词典弹窗中集成 AI 单词深度解析，帮助学习者理解单词在语境中的含义：

### 后端
- PostgreSQL `word_analyses` 表 + Drizzle schema
- API 路由 `POST /api/v1/ai/word-analyze`（L3 unstable_cache + L4 PostgreSQL + LLM 生成）
- 自适应 4 字段分析：语境释义、常见搭配、用法要点、词族扩展

### Flutter
- `WordAnalysis` 数据模型（4 个可选字段，AI 自适应返回 null）
- `WordAiNotifier` 三级缓存（L1 内存 → L2 SQLite → L3 API，并发去重）
- `WordDictionarySheet` UI 集成（AiContentSection 折叠/展开 + 结构化渲染）
- 词典有结果和未收录词均支持 AI 解析

### 测试覆盖
- 28 个新测试（模型 7 + API 客户端 7 + Provider 8 + Widget 6）

---

## 进行中：录音+识别功能

**最新进展**: 2026-03-13

- 已完成跟读页面的 live ASR、final transcript 判定、LCS 文本匹配、录音回放与临时文件清理
- 录音识别能力已升级为可复用的统一 backend/session 接口 + Apple 原生 live ASR 桥接（iOS + macOS）
- 跟读页结果区已重构为原文下方的教练式反馈卡，原文命中词直接高亮、转录弱化显示、评级替代达标提示，并支持播放自己的录音
- 已修复 macOS `speech_practice` 通道注册缺失，以及跟读页录音结果区在窄屏下的布局溢出
- 已增强 iOS/macOS 临时录音文件写入增益，改善”播放我的录音”回放音量偏小的问题
- 已完成跟读回合自动录音：进入”轮到用户说”时自动开始录音，5 秒未开口轻提醒，15 秒未开口回退手动录音，用户开口后支持静音自动结束
- 已完成跟读结果回合自动推进：结果页默认 5 秒倒计时，播放自己的录音时会重置倒计时并在播放结束后重新开始计时
- 已完成跟读录音 UI 优化：大圆形录音按钮（脉冲+波纹动画）、manualFallback 重录 bug 修复、继续按钮升级为 FilledButton.tonal + 箭头图标、倒计时圆环放大至 40px 内嵌秒数
- 已完成录音启动延迟优化：AVAudioEngine 页面级常驻，warmup/shutdown 生命周期管理，startSession 从 524ms 降至 ~1ms
- 已完成难句补练页面接入自动录音：提取共享 UI 组件（SpeechPracticeTurnPanel / SpeechPracticeResultCard），回调注入解耦 TurnController，难句补练跟读模式自动录音流程与跟读页完全一致（遍间+句间停顿均触发录音）
- 已完成难句跟读复用边界收敛：3 个页面将 `build()` 内监听下沉到 `initState`，难句/收藏标记持久化回收至 provider，`BookmarkReview` 去掉 `dynamic` 音频加载入口，并补齐跟读主页面 Widget 测试
- 已完成难句补练/收藏复习单底部控制重构：`RepeatPracticePanel` 收敛为跟读中间区，三页共享 `PracticePlaybackFooter`，`BookmarkReview` annotation mode 切换到 `RepeatFlowEngine`
- 已完成难句补练/收藏复习盲听等待态状态机化：两页 blind mode 接入 `BlindPracticeFlowEngine`，设置/偷看字幕/查词统一进入 `WaitingForUser`，并修复 dispose 异步竞态
- 已完成逐句精听页面按难句补练模式重构：blind mode 接入 `BlindPracticeFlowEngine`，新增 `IntensiveAnnotationState` 管理“看不懂后”的详情流程，页面收敛为“顶部进度 + 中间内容切换 + 单一 footer”
- 已完成全文盲听 + 段落复述共享骨架重构：两页统一到 `ParagraphPracticeScaffold`，共享段落句子卡片、顶部进度区和底部播放控制，复述可见性菜单上移为独立内容控制区
- 已完成全文盲听/段落复述等待态补齐：两页新增显式 `isWaitingForUser` 语义，设置弹窗打开前统一接管流程，播放中支持当前段自然播完后再进入等待
- 已完成本地 ASR 入口交互重构：改为在学习计划页/Favorites 入口前做阻塞式检查与下载弹窗，未完成下载前不进入录音页

---

## 已完成：管理字幕功能（AI 转录）

**完成时间**: 2026-03-05

实现了"管理字幕"底部弹窗功能，支持本地上传、AI 转录和删除字幕三种操作：

### Phase 1（客户端 UI）
- 数据模型扩展：TranscriptSource 枚举 + AudioItem 新字段 + DB 迁移 v12→v13
- ManageSubtitlesSheet 底部弹窗（本地上传/AI 转录/删除字幕）
- 菜单入口从"上传字幕"改为"管理字幕"
- 国际化（25 个新 key）

### Phase 2（AI 转录完整流程）
- SHA256 音频指纹计算（Isolate + crypto 包）
- 后端 user_audios + user_audio_transcripts 表 + 5 个 HTTP API Routes
- Dio HTTP 客户端 + 转录状态 Provider（keepAlive，后台运行）
- SRT 格式转换 + AudioListTile 进度指示
- 两级缓存：音频 SHA256 去重 + 字幕语言去重

### Phase 3（UI 优化 + iOS 适配）
- 管理字幕弹窗 UI 重构（卡片式选项、删除按钮移至标题栏、移除状态标签）
- 转录错误提示简化（短码 + i18n 本地化）
- 全局 API 配置提取（`lib/config/api_config.dart`）
- iOS 网络权限：通过 Method Channel 调用原生 URLSession 触发系统弹窗
- iOS ATS 例外配置（NSAllowsArbitraryLoads + NSLocalNetworkUsageDescription）

### 测试覆盖
- 65+ 个测试全部通过（模型 31 + Widget 10 + SRT 8 + SHA256 5 + API 11）

---

## 已完成：Bug 修复（3 个）

### Bug 1：跟读自由练习模式最后一句无停顿直接退出

**根因**：

1. **Provider 层**（`listen_and_repeat_player_provider.dart` 第 336-340 行）：
   `_autoAdvance()` 检测到最后一句后立即设置 `isCompleted = true` 并 return，完全跳过了句末停顿逻辑。

2. **Screen 层**（`listen_and_repeat_player_screen.dart` 第 204-211 行）：
   `_handleCompleted()` 在 `isFreePlay` 模式下直接 `context.pop()` 退出页面，没有弹窗。

**修复步骤**：

1. **Provider — `_autoAdvance()` 最后一句也走停顿流程**
   - 文件：`lib/providers/learning_session/listen_and_repeat_player_provider.dart`
   - 移除最后一句的提前 return，改为统一调用 `_engine.autoAdvance()`
   - 在 `onAdvance` 回调中判断：最后一句则标记 `isCompleted = true`，否则推进到下一句

2. **Provider — 新增 `resetToStart()` 方法**
   - 文件同上
   - `_engine.invalidateSession()` → 重置 state 到第一句 → `startPlaying()`

3. **Screen — `_handleCompleted()` 自由练习弹出对话框**
   - 文件：`lib/screens/listen_and_repeat_player_screen.dart`
   - `isFreePlay` 分支改为弹出 `_FreePlayCompleteDialog`
   - 返回 `true` = 完成退出 → `context.pop()`，`null` = 再来一遍 → `resetToStart()`
   - 无论哪种选择都递增遍数

4. **Screen — 新增 `_FreePlayCompleteDialog` 组件**
   - 复用 `_RetellCompleteDialog` 模式：标题行 + 统计内容 + "再来一遍"(TextButton) + "完成练习"(FilledButton)

---

### Bug 2：精听自由练习模式最后一句无停顿直接退出

**根因**：与 Bug 1 完全相同的模式。

1. **Provider 层**（`intensive_listen_player_provider.dart` 第 463-468 行）
2. **Screen 层**（`intensive_listen_player_screen.dart` 第 343-353 行）

**修复步骤**：

1. **Provider — `_autoAdvance()` 最后一句也走停顿流程**
   - 文件：`lib/providers/learning_session/intensive_listen_player_provider.dart`
   - 精听使用内联 `_startCountdown` + `Future.delayed` 机制
   - 移除最后一句的提前 return，统一执行停顿后判断：最后一句 → `isCompleted = true`，否则推进

2. **Provider — 新增 `resetToStart()` 方法**

3. **Screen — `_handleCompleted()` 自由练习弹出对话框**
   - 文件：`lib/screens/intensive_listen_player_screen.dart`
   - 同 Bug 1 模式，弹出 `_FreePlayCompleteDialog`

4. **Screen — 新增 `_FreePlayCompleteDialog` 组件**

---

### Bug 3：段落复述字幕显示选项只在播放完后才能点击

**根因**：`retell_player_screen.dart` 第 296-298 行

```dart
onSelectionChanged: state.phase == RetellPhase.retelling
    ? (selected) => player.setDisplayMode(selected.first)
    : null,
```

`SegmentedButton` 被 `RetellPhase.retelling` 门控，`listening` 阶段不可点击。

**修复步骤**：

1. **一行修改**：移除 phase 条件，始终允许切换
   ```dart
   onSelectionChanged: (selected) => player.setDisplayMode(selected.first),
   ```

---

### 国际化新增 Key

| Key | 中文 | 英文 |
|-----|------|------|
| `shadowingCompleteTitle` | 跟读完成 | Shadowing Complete |
| `shadowingCompleteMessage` | 共 {count} 句跟读完成 | {count} sentences shadowed |
| `intensiveListenCompleteTitle` | 精听完成 | Intensive Listening Complete |
| `intensiveListenCompleteMessage` | 共 {count} 句精听完成 | {count} sentences listened |
| `practiceAgain` | 再来一遍 | Practice Again |
| `practiceComplete` | 完成练习 | Practice Complete |

> 注：`practiceAgain` 和 `practiceComplete` 作为通用 key，跟读/精听共用。也可复用现有 `retellPracticeAgain` 和 `retellCompleteFreePlay`，如确认文案一致则不新增。

---

### 代码生成

```bash
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
```

---

### 影响范围

| 文件 | 改动类型 |
|------|----------|
| `lib/providers/learning_session/listen_and_repeat_player_provider.dart` | 改 `_autoAdvance` + 新增 `resetToStart` |
| `lib/screens/listen_and_repeat_player_screen.dart` | 改 `_handleCompleted` + 新增 `_FreePlayCompleteDialog` |
| `lib/providers/learning_session/intensive_listen_player_provider.dart` | 改 `_autoAdvance` + 新增 `resetToStart` |
| `lib/screens/intensive_listen_player_screen.dart` | 改 `_handleCompleted` + 新增 `_FreePlayCompleteDialog` |
| `lib/screens/retell_player_screen.dart` | 一行改动（移除 phase 条件） |
| `lib/l10n/app_zh.arb` | 新增 i18n key |
| `lib/l10n/app_en.arb` | 新增 i18n key |

---

### 验证步骤

1. `flutter analyze` — 无错误
2. `flutter test` — 现有测试通过
3. 手动验证：
   - 跟读自由练习 → 最后一句播完 → 有跟读停顿 → 弹窗"完成/再来一遍"
   - 精听自由练习 → 最后一句播完 → 有停顿 → 弹窗"完成/再来一遍"
   - 段落复述 → 播放阶段即可切换字幕显示模式
   - 正常模式（非自由练习）不受影响

---

## 项目概述

Echo Loop 是一款 Flutter 跨平台英语听说练习应用，通过结构化的学习流程（首次学习→间隔复习→毕业检验）帮助用户系统性地提升英语听说能力。

---

## 目录结构与关键文件索引

```
lib/
├── main.dart                        # 应用入口，配置主题/国际化
├── router/                          # go_router 路由配置
│   ├── app_router.dart              #   GoRouter 配置 + 类型安全路由常量
│   └── main_shell.dart              #   Tab 导航外壳（StatefulShellRoute）
├── l10n/                            # 国际化
│   ├── app_en.arb                   # 英文模板（新增 key 在此添加）
│   └── app_zh.arb                   # 中文翻译
├── models/                          # 纯数据模型（不含业务逻辑）
│   ├── audio_item.dart              #   音频文件元数据（相对路径）
│   ├── collection.dart              #   合集（包含多个 AudioItem）
│   ├── tag.dart                     #   标签（名称 + 颜色）
│   ├── sentence.dart                #   字幕句子（时间轴 + 书签状态）
│   ├── playback_settings.dart       #   播放设置（循环、速度、间隔等）
│   ├── intensive_listen_settings.dart #  精听设置（循环次数、停顿模式）
│   ├── audio_engine_state.dart      #   音频引擎状态快照
│   ├── listening_practice_state.dart#   学习会话完整状态
│   └── learning_progress.dart       #   学习进度（阶段、进度计算）
├── database/                        # Drift (SQLite) 数据库层
│   ├── app_database.dart            #   数据库定义 + 连接 + 索引
│   ├── enums.dart                   #   SyncStatus / LearningStage / SubStageType / DifficultyLevel 枚举
│   ├── providers.dart               #   数据库 + DAO 的 Riverpod Provider
│   ├── tables/                      #   8 张表定义
│   │   ├── audio_items.dart
│   │   ├── collections.dart
│   │   ├── collection_audio_items.dart
│   │   ├── bookmarks.dart
│   │   ├── playback_states.dart
│   │   ├── learning_progresses.dart
│   │   ├── stage_completions.dart
│   │   ├── tags.dart
│   │   └── audio_item_tags.dart
│   ├── daos/                        #   7 个 DAO
│   │   ├── audio_item_dao.dart
│   │   ├── collection_dao.dart
│   │   ├── bookmark_dao.dart
│   │   ├── playback_state_dao.dart
│   │   ├── learning_progress_dao.dart
│   │   ├── stage_completion_dao.dart
│   │   └── tag_dao.dart
│   └── migration/
│       └── sp_to_drift_migration.dart  # SP → Drift 一次性迁移
├── services/                        # 基础服务（无状态/单例）
│   ├── storage_service.dart         #   SharedPreferences（仅 PlaybackSettings）
│   └── subtitle_parser.dart         #   SRT/VTT 字幕解析
├── providers/                       # Riverpod 状态管理（代码生成）
│   ├── audio_library_provider.dart  #   音频库管理（导入/删除/路径迁移）
│   ├── collection_provider.dart     #   合集 CRUD + 排序 + 反向索引
│   ├── tag_provider.dart            #   标签 CRUD + 反向索引 + diff 更新
│   ├── audio_list_settings_provider.dart # 音频列表排序设置
│   ├── settings_provider.dart       #   全局设置（主题/语言）
│   ├── audio_engine/
│   │   └── audio_engine_provider.dart  # 底层音频控制（封装 just_audio）
│   ├── learning_progress_provider.dart  # 学习进度管理（加载/推进/难度设置）
│   ├── learning_session/
│   │   ├── learning_session_provider.dart  # 学习会话层（盲听模式/设置保存恢复）
│   │   └── blind_listen_player_provider.dart # 盲听专用轻量播放器（直接操作 AudioEngine）
│   └── listening_practice/
│       ├── listening_practice_provider.dart  # 核心业务：播放模式/句子导航/书签
│       ├── sentence_tracker.dart     #   二分查找定位当前句子
│       ├── bookmark_manager.dart     #   书签持久化 + 去重逻辑
│       └── playback_state_storage.dart #  播放状态断点恢复
├── screens/                         # 页面级 UI 组件
│   ├── collection_screen.dart       #   合集列表页
│   ├── collection_detail_screen.dart#   合集详情页
│   ├── study_screen.dart            #   学习页（任务列表：复习优先）
│   ├── favorites_screen.dart        #   收藏页（当前占位）
│   ├── learning_plan_screen.dart     #   学习计划表页
│   ├── blind_listen_player_screen.dart #  盲听播放器（极简界面）
│   ├── player_screen.dart           #   播放器页（核心交互）
│   └── settings_screen.dart         #   设置页
├── widgets/                         # 可复用 UI 组件
│   ├── playback_controls.dart       #   播放控制面板
│   ├── sentence_list_view.dart      #   句子列表（滚动 + 高亮）
│   ├── settings_dialog.dart         #   播放设置弹窗
│   ├── blind_listen_briefing_sheet.dart #  盲听简报底部弹窗
│   ├── blind_listen_complete_dialog.dart # 盲听完成/难度选择对话框
│   └── player_hotkey_scope.dart     #   桌面端键盘快捷键
└── theme/
    └── app_theme.dart               # 主题系统（Material 3，蓝色主色调）

test/                                # 单元测试 + Widget 测试
├── helpers/                         #   测试辅助（mock_providers, test_app）
├── database/                        #   DAO 测试 + 迁移测试
├── models/                          #   6 个模型测试
├── providers/                       #   Provider 测试（含 listening_practice/）
├── screens/                         #   4 个页面 Widget 测试
├── services/                        #   SubtitleParser 测试
└── widgets/                         #   3 个组件测试

integration_test/                    # 端到端集成测试（25 个测试）
├── app_test.dart                    #   入口（7 个 group）
├── groups/                          #   按功能分组
│   ├── navigation_tests.dart        #     导航（2 个测试）
│   ├── settings_tests.dart          #     设置（2 个测试）
│   ├── collection_tests.dart        #     合集（1 个测试）
│   ├── learning_plan_tests.dart     #     学习计划页（5 个测试）
│   ├── blind_listen_tests.dart      #     盲听播放器（6 个测试）
│   ├── intensive_listen_tests.dart  #     精听播放器（7 个测试）
│   └── learning_flow_tests.dart     #     跨页面学习闭环（2 个测试）
└── helpers/                         #   测试用 Notifier + 数据工厂
```

### 关键文件速查

| 文件 | 行数 | 说明 |
|------|------|------|
| `listening_practice_provider.dart` | ~780 | **最核心文件**：双播放模式、句子导航、书签、状态恢复 |
| `audio_engine_provider.dart` | ~160 | 底层音频引擎，封装 just_audio |
| `player_screen.dart` | — | 播放器 UI，用户交互最集中的页面 |
| `app_theme.dart` | ~236 | 全局主题定义，修改视觉从这里开始 |
| `app_database.dart` | — | Drift 数据库定义（7 表 + 6 DAO + 索引） |
| `storage_service.dart` | — | SharedPreferences（仅 PlaybackSettings） |

---

## 架构设计

### 3 层播放器架构

```
┌──────────────────────────────────────────────┐
│      LearningSession（学习会话层）             │
│  学习模式 · 盲听遍数 · 完成判定 · 设置保存恢复  │
├──────────────┬───────────────────────────────┤
│ BlindListen  │  ListeningPractice（播放业务层）│
│ Player       │  句子追踪·书签·循环·播放模式    │
│ （盲听专用）  │  （普通播放/精听模式）          │
├──────────────┴───────────────────────────────┤
│           AudioEngine（底层）                  │
│  封装 just_audio · 播放/暂停/seek/速度控制     │
└──────────────────────────────────────────────┘
```

- **AudioEngine**（底层）：封装 just_audio，提供播放、暂停、seek、速度控制等原子操作，不包含业务逻辑
- **ListeningPractice**（业务层）：基于 AudioEngine，实现句子追踪（二分查找定位当前句子）、书签管理、循环播放、播放模式切换等业务功能
  - 播放编排为**单一事件驱动模型**：gapless 连播由位置流推进 `currentFullIndex`；单句循环/收藏逐句播放由「clip 完成事件」触发纯函数 `decideNext`（`playback_reducer.dart`）决策下一步（重播/进句/回卷/停止）。循环语义由**两组独立可同时开启**的开关描述——整篇循环（`loopWhole`+总遍数+间隔）与单句循环（`loopSentence`+次数+间隔），各自携带间隔由 reducer 经 `pauseBefore` 下发；取代旧 `PlaybackRepeatMode{off,all,one}` 互斥三态。讲解页等共享引擎的旁路驱动靠 `isActiveSession` session 守卫隔离，返回时 `restorePosition()` 显式对齐当前句。

### 状态管理

使用 Riverpod + 代码生成模式（`riverpod_generator`）。Provider 文件包含 `part 'xxx.g.dart';`，修改后需运行 `dart run build_runner build`。

### 依赖关系图

```
EchoLoopApp (main.dart)
├── AppTheme (theme)
├── AppSettings Provider (主题/语言) → SharedPreferences
├── AudioLibrary Provider → AudioItemDao ──┐
├── CollectionList Provider → CollectionDao ├──→ AppDatabase (Drift/SQLite)
└── Screens                                 │
    └── PlayerScreen → ListeningPractice    │
                        ├── AudioEngine → just_audio
                        ├── SentenceTracker (二分查找)
                        ├── BookmarkManager → BookmarkDao ──┤
                        ├── PlaybackStateStorage → PlaybackStateDao ┘
                        └── StorageService → SharedPreferences (仅 PlaybackSettings)
```

### 数据持久化

业务数据使用 Drift (SQLite)，纯设置使用 SharedPreferences：

**Drift (SQLite) — 9 张表**：

| 表 | 说明 |
|----|------|
| `audio_items` | 音频元数据（含 sync 字段） |
| `collections` | 合集（含 sync 字段） |
| `collection_audio_items` | Junction 表（多对多关联） |
| `bookmarks` | 增强版书签（存 text/startTime/endTime） |
| `playback_states` | 播放断点（仅 position_ms + playlistMode） |
| `learning_progresses` | 学习进度（阶段、小阶段、难度、首次学习完成时间、复习调度、学习时长） |
| `stage_completions` | 步骤完成历史（按步骤记录完成时间和耗时） |
| `tags` | 标签（名称、颜色、sync 字段） |
| `audio_item_tags` | 标签-音频关联表（多对多 Junction） |

**SharedPreferences — 纯设置项**：

| Key | 内容 |
|-----|------|
| `playback_settings` | 播放设置（速度、循环等） |
| `theme_mode` | UI 主题 |
| `locale` | 语言 |
| `drift_migration_v1_complete` | 迁移完成标记 |

### 国际化

- Flutter 内置 `flutter_localizations` + ARB 文件
- 翻译文件位置：`lib/l10n/`
- 模板文件：`app_en.arb`，当前支持 en / zh
- 配置文件：`l10n.yaml`

---

## 关键架构决策记录 (ADR)

### ADR-1: 相对路径存储

**决策**：AudioItem 的音频/字幕路径存储为相对于 documents 目录的相对路径，而非绝对路径。

**原因**：绝对路径在不同设备、沙盒环境变化时会失效。相对路径保证数据可移植性。

**影响**：AudioLibraryProvider 包含自动迁移逻辑，将旧版绝对路径转换为相对路径。

### ADR-2: 两层播放器分离

**决策**：将音频播放分为 AudioEngine（底层原子操作）和 ListeningPractice（业务层流程控制）两层。

**原因**：
- 底层引擎可独立测试，不依赖业务逻辑
- 业务层可在不修改引擎的前提下扩展新的播放流程（如 Milestone 2 的首次学习/复习流程）
- 避免单一 Provider 过于庞大

**影响**：新增播放流程只需在业务层添加，不需要修改 AudioEngine。

### ADR-3: Session ID 隔离机制

**决策**：每次 play() 调用分配唯一 sessionId，后台任务在写入状态前必须校验 sessionId 是否仍然有效。

**原因**：用户可能在句子循环播放过程中快速切换到其他句子，如果不校验 session，旧的异步回调会覆盖新状态，导致 UI 跳回旧句子。

**影响**：所有异步播放逻辑必须持有 sessionId 并在每次状态更新前检查 `isActiveSession(id)`。

### ADR-4: 书签去重归一化

**决策**：切换书签时，对句子文本进行归一化（小写 + 去尾部标点），相同文本的所有句子同时添加/移除书签。

**原因**：同一句话可能在字幕中重复出现（如复述、回顾），用户意图是标记"这句话"而非"这个位置"。

**影响**：BookmarkManager 中的 `_normalizeForBookmarkComparison()` 负责归一化逻辑。

### ADR-5: 双播放模式动态切换

**决策**：支持两种播放模式——连续模式（全文自动播放）和字幕驱动模式（逐句控制 + 循环），根据用户设置动态切换。

**原因**：
- 连续模式适合"全文盲听"场景（Milestone 2 首次学习第一步）
- 字幕驱动模式适合"逐句精听"和"难句跟读"场景
- 两种模式共享同一套句子导航和书签系统

**切换条件**：`autoPlayNextSentenceEnabled=true` 且 `loopEnabled=false` 时为连续模式，否则为字幕驱动模式。

### ADR-6: Drift (SQLite) 作为业务数据持久化方案

**决策**：业务数据（音频、合集、书签、播放状态）使用 Drift (SQLite)，纯设置/偏好保留在 SharedPreferences。

**原因**：
- Milestone 2 学习流程需要复杂查询（进度、间隔复习调度），关系型数据库更适合
- Junction 表管理多对多关系比 JSON 数组更可靠
- 增强版书签存储 text/startTime/endTime，防止字幕重新解析后索引错位
- 所有主要表预留 sync 字段（updatedAt/deletedAt/syncStatus），为未来服务器同步做准备

**迁移**：SP → Drift 一次性迁移在首次启动时自动执行，单事务保证原子性。旧 SP 数据不删除，迁移标记 `drift_migration_v1_complete` 防止重复执行。

### ADR-7: 媒体引擎与前台引擎分离（媒体会话绑定结构化，取代运行时 suppress）

**决策**：把底层播放拆成两套**不共享 player** 的引擎：

- **媒体引擎** = 现有 `AudioEngine` → `echoLoopAudioHandler._player`，接入 `audio_service`，带锁屏/后台/静音保活/逻辑播放态。服务于 **Free Player / 逐句精听 / 全文盲听**（以及学习自动推进）——这些任务确实需要后台 + 锁屏。
- **前台引擎** = 新增 `ForegroundAudioEngine`，自持一个**裸 `ja.AudioPlayer`，从不注册到 `audio_service`**。服务于 **难句跟读 / 段落复述 / 难句补练 / 收藏句复习 / 收藏词复习(闪卡)**——它们只在前台播放原句/原段，物理上碰不到 `MPNowPlayingInfoCenter`/前台通知。（用户 2026-06-27 明确：收藏句复习、收藏词复习都不要后台/锁屏。）

**原因**：§7.7–7.11 全部 bug 同源——"是否上锁屏"现在是一个运行时开关 `setMediaSessionSuppressed`，它要和系统两条独立通道（playbackState + MediaItem）以及跨 session 的事件时序打地鼓。把"是否绑定媒体会话"变成 **player 的物理属性**（用哪个引擎）而非 flag，从源头消除整类竞态：前台引擎不接 `audio_service`，不可能弹卡片，suppress 整套逻辑（§7.9/§7.11 的时序对齐）连根删除，§7.7 简化。

**结构**（按 2026-06-27 决定）：**前台引擎独立写一份**，不抽共享 ClipPlayer 实现，逐方法照抄 `AudioEngine` 播放子集、仅把 `_handler.xxx` 换成裸 `_player.xxx`（符合 CLAUDE.md「先重复后抽象」）。**不需要 `PlaybackEngine` 接口**——探查确认不存在"被媒体任务与前台任务按同一引擎类型共用"的编排代码：`SentencePlaybackEngine` 仅被补练 + 收藏句复习构造（均前台）、`StudyTaskControllerMixin` 仅被 listen_and_repeat（前台）`with`、`RepeatFlowEngine` 经回调注入不持引擎字段。故 `SentencePlaybackEngine.getEngine` 与 mixin 的引擎引用直接改成 `ForegroundAudioEngine` 即可，调用点改 `foregroundAudioEngineProvider`。

**任务切换**：学习计划里 `盲听(媒体引擎) → 跟读(前台引擎)` 背靠背时，进前台任务要把**媒体引擎 `stop()`**（产生 `非idle→idle` 跳变 → audio_service 调 `stopService` 清掉锁屏卡片），取代旧的"suppress 共享 player"。这是个明确的状态转换，比 suppress 干净。

**行为保证**：前台引擎逐方法照抄 AudioEngine 播放子集，配合现有行为测试平移（override 改 `foregroundAudioEngineProvider`、断言不变），保证 难句跟读/段落复述等的**播放/录音功能行为与 commit 578f8829 一致**；锁屏卡片不再出现是有意改进。

**风险**：iOS `AVAudioSession` 进程级共享，两个 `just_audio` player + 录音器对 category（playAndRecord）的争用本机/CI 测不到，**必须真机验证**（同 §7.10 后台行为）。

**影响**：删 `AudioEngine.setMediaSessionSuppressed` 及 handler 中 `_mediaSessionSuppressed` 相关分支；5 个前台任务改注入前台引擎、删 suppress/bind/保活/mixin、进任务改 stop 媒体引擎。

### ADR-8: 统一 TTS 架构（可插拔引擎 + 合成→文件→缓存→播放管线）

**决策**：把硬编码单例 `TtsService`（flutter_tts，固定 en-US/语速 0.45）重构为分层、可插拔的统一 TTS 架构。所有发音走同一条管线：`文本+参数 → cacheKey → 查缓存 → 命中直接播 / 未命中合成产文件并入库 → 播放文件`。

**分层**：
- **引擎抽象** `TtsEngine`（`lib/services/tts/tts_engine.dart`）：`initialize`/`applyConfig`/`synthesize`(产文件)/`speakLive`(实时兜底)/`stop`/`dispose`。本期实现 `PlatformTtsEngine`（flutter_tts，`synthesizeToFile` 产 wav/caf + §7.2 防竞态的 speakLive 兜底）；`KokoroTtsEngine` 占位（未来本地 82M 模型，接入只加一个实现 + 工厂分支，上层零改动）。
- **缓存层** `TtsCacheStore` + Drift `tts_cache` 表（v43）：cacheKey=`sha256(textHash|engine|voice|speed|format)`，文件落 `getApplicationCacheDirectory()/tts_cache/`，过期/容量由 DB `expiresAt`/`lastAccessedAt`(LRU) 驱动（默认 10 天 / ~200MB），不靠目录或文件名。`isPinned` 列为未来长文永久缓存预留。
- **播放层** `TtsPlayer`：独立裸 `just_audio` player，**不接 `audio_service`**（一次性短发音不上锁屏，规避 §7.7–7.13 锁屏竞态），session 守卫 + 确定性 await 完成（§7.6）。
- **协调层** `TtsCoordinator`（纯 Dart 可测）：串管线 + generation 防竞态 + 引擎**惰性**创建（仅渲染发音按钮不触碰平台 TTS/数据库，首次 speak 才建引擎、连库）。
- **门面** `ttsControllerProvider`：全应用唯一发音入口，监听 `ttsSettingsProvider`（引擎/口音，SharedPreferences）热重配；`speakingKey` 驱动发音按钮激活态。

**为什么平台 TTS 也走「合成→文件」而非实时 speak**（用户 2026-06-28 拍板）：单词/例句短文本合成延迟可忽略；**前瞻需求**——未来给大段用户输入文本生成音频必须产文件+缓存复用。统一管线让平台 TTS 与 Kokoro 同路，缓存层现在就被真实使用和验证。平台 TTS 保留 `speakLive` 作 `synthesizeToFile` 失败（iOS 历史不稳）时的降级兜底。

**口音**：美/英全局生效，`en-US`/`en-GB` 经 `setLanguage`（三平台最稳，不依赖 voice name）。Echo Loop 引擎本期 UI 置灰（设置层选中回退 platform 防御）。

**消费点**：闪卡单词、收藏单词、词典单词发音迁到统一入口（删 `tts_service.dart`）；**新增**词典 AI 例句（词义/搭配/词族）点击发声。统一发音按钮 `SpeakButton`（连续点打断重播、错误静默复位）。

**风险**：iOS `synthesizeToFile` 历史不稳 → speakLive 兜底 + 校验文件 size>0；iOS `AVAudioSession` 进程级共享，TTS 文件经 just_audio 播放与录音/学习引擎争用本机/CI 测不到，**闪卡录音+TTS、学习中点词发音需真机验证**（同 §7.12）。详见 CLAUDE.md §7.14。

### ADR-9: Echo Loop TTS = sherpa-onnx 跑 Kokoro-82M（落地 ADR-8 的 Kokoro 占位）

**决策**：把 ADR-8 预留的 `KokoroTtsEngine` 占位实现为可用引擎——复用已集成的 `sherpa_onnx` FFI（与 Whisper ASR 同一套原生引擎，零新增原生依赖）跑 **Kokoro-en-v0_19 int8** 本地神经网络合成。接入只新增引擎实现 + 工厂分支 + 下载状态机，ADR-8 的协调器/缓存/播放器零改动。

**为什么用 sherpa 打包的 Kokoro 而非裸 onnx**：`sherpa_onnx` 的 `OfflineTts` 只能加载 sherpa 官方格式的 Kokoro（自带 `espeak-ng-data` 做 G2P）；thewh1teagle/kokoro-onnx 的裸 onnx 用另一套音素化（misaki/phonemizer），塞不进 sherpa FFI。故模型取自 k2-fsa/sherpa-onnx TTS 发布、量化 int8、重托管到 `cdn.echo-loop.top`（App 只从自家 CDN 下载，与 Whisper 一致）。

**模型分发**：单 `tar.gz`（98 MB，因含 `espeak-ng-data` 目录树，区别于 Whisper 的逐文件清单）。`KokoroModelManager` 下载归档 → 校验整包 SHA-256 → `archive` 的 `extractFileToDisk` 流式解包 → 递归校验关键文件。下载失败按"整包重下"恢复（重试按钮），与 ASR 粒度一致。

**音色/口音**：Kokoro 的美/英音 = 不同 speaker（`af_/am_`=美音、`bf_/bm_`=英音）。11 个发音人写进 `kokoro_voices.dart`（id→sid）。设置层加 `kokoroVoiceUs`/`kokoroVoiceUk`，美/英各记一个所选音色；`toSpeechConfig` 在 echoLoop 下带 `voiceName`（=音色 id），引擎解析为 `generate(sid:)`，缓存键天然按 engine+voiceId 分桶。

**原生推理**：放常驻 worker isolate（镜像 `sherpa_onnx_engine.dart`），`OfflineTts.generate`+`writeWave` 在 worker 内执行回传 wav 路径，主线程无 jank。固定 `provider='cpu'`（可靠、规避 §7.4 NNAPI 崩溃路径；TTS 不用 VAD）。"原生合成"抽象为可注入 `KokoroNativeSynthesizer`，引擎逻辑（sid 解析/文件命名/降级）可纯单测。

**生效门控**：选 Echo Loop 但模型未就绪时 `effectiveTtsEngine` 降级平台 TTS（发音不中断），就绪后控制器自动切回 echoLoop。`KokoroTtsEngine.speakLive` 返回 false（不抛），合成失败时共享管线优雅静默。

**附带收益**：macOS 上 Kokoro 走 `generate` 能正确区分英/美音（集成测试验证美/英音音频不同），对照平台 TTS 在 macOS 的 `synthesizeToFile` 口音失效（§7.15）。

**风险**：iOS `AVAudioSession` 进程级共享，TTS worker 推理 + just_audio 播放 + 录音器争用本机/CI 测不到，需真机验证；sherpa native abort 不可 catch（§7.4），CPU provider 已规避已知路径。详见 CLAUDE.md §7.16。

### ADR-10: 本地（离线）音频转录生成字幕（复用离线 Whisper 引擎，作云端转录的对偶）

**决策**：把评分用的离线 sherpa-onnx Whisper 引擎复用于"文件转字幕"，作为云端 `TranscriptionTaskManager`（Deepgram）的离线平行选项。云端与本地是两个平行的后台 task manager，**共用同一下游 sink**（`saveTranscriptContent` + SRT + 词级时间戳入库），差异只在文本来源——正确的解耦点。

**词级时间戳仍按字符长度合成**（`generateSyntheticWordTimestampsFromSrt`，与"本地上传 SRT"路径完全一致）。引擎新增 `transcribeSegments`（保留 `transcribe()` 评分路径不动）。

**whisper 分段策略（2026-07-05 定稿：转录路径彻底去 VAD + whisper 自驱滑窗 + 原生 segment 时间戳）**：旧实现每个 VAD 段单独送 whisper（`minSilenceDuration=0.25s` 切 <1s 碎片，whisper 易幻觉/漏词）。中途试过「VAD 拼 ≤30s chunk」，但发现 VAD 作内容闸门本身有害——`minSpeechDuration=0.5s` 丢短词、削词头尾、对非人声误删。最终方案彻底不在转录用 VAD：
- ① **whisper 自驱滑窗**（`_slidingWindowTranscribe`，openai/whisper 长音频标准做法）：把音频切成 ≤30s **连续窗口**逐个解码，窗口在「上一个完整 whisper segment 的结束时刻」推进——**不裁剪、不丢弃任何音频，切点落在自然停顿、不在词中间硬切**。whisper 30s 硬上限是唯一还需要切窗的理由。
- ② 窗口读取：可 seek 的 `Pcm16WavStreamReader.readWindow(start,count)` 按 seek 位置只读当前窗口，峰值内存与总时长解耦；非标准 WAV 回退全量读后同样滑窗。
- ②b **静音跳过**（`_skipLeadingSilence`/`firstAudibleFrameIndex`）：每窗前跳过「持续 ≥0.8s 且均方 <阈值(≈-40dBFS)」的静音（考试音频大段答题静音转录无意义，且 whisper 会在长静音上幻觉）。用**能量(RMS)检测、非人声检测**——保守阈值只删真静音、保留一切有声内容（含音乐/音效）；漏跳只是把静音喂给 whisper（无害），绝不误跳有声。
- ③ cue 边界与时间取 **whisper 原生 segment 时间戳**（`enableSegmentTimestamps`；segment 自带 start/duration/text），线性映射回原始音频（窗口连续、无丢静音，`绝对时间 = 窗口起点 + 段相对时间`）。
- **附带**：转录路径不再触及 Silero VAD → §7.4 的 native 崩溃对转录彻底消失。VAD 仅评分路径（`_handleTranscribe`）保留。

**为什么是 segment 而非 token 时间戳**：sherpa-onnx 的 whisper **token 时间戳（DTW）需要重导带 `cross_attention_weights` 输出的模型**（官方发布的模型都没带，实测 `result.timestamps` 恒空）；而 **segment 时间戳靠 logit filter 保留 whisper 原生时间戳 token，现有 int8 模型即可**（sherpa-onnx PR #2945，已在 1.12.24+，我们用 1.12.36）。**坑**：segment 字段不在公开 `getResult()` 里（被丢弃），只在原生 result JSON（`segment_timestamps`/`segment_durations`/`segment_texts`）；需实现层 import `package:sherpa_onnx/src/sherpa_onnx_bindings.dart` 调 `getOfflineStreamResultAsJson` 取 raw JSON 自解析（`parseWhisperSegments`，纯逻辑可测；`// ignore: implementation_imports`，已 pin `^1.12.36`）。
**回退**：某窗未产出 segment（全静音/极端情况）时，按句末标点切句（`splitTextIntoSentences`）+ 字符长度在该窗时间跨度上比例分配估时（近似，与 `generateSyntheticWordTimestampsFromSrt` 同源）。下游 `mergeShortAsrSegments`（合并过短句到 4-7s）/SRT 零改动。
**踩坑教训**：① 曾误用 VAD 段边界当 cue 边界——`minSilenceDuration=0.8s` 下整段连续对话被 VAD 当成 1 个 ~30s 段，33s 音频只出 1 条巨型字幕（文本对但粒度全丢）；cue 粒度必须来自 whisper。② 曾据一次 `ts=0` 草率断定「sherpa 不支持时间戳」——真因是模型导出缺 attention 权重 + Dart 绑定丢弃 segment 字段，非 API 不支持。③ 最终认识到 VAD 检测的是"人声"、且会删内容，用它当 whisper 的内容闸门有害；whisper 自己有 segment 时间戳 + 30s 内部处理，转录只需"切 ≤30s 窗、喂连续音频"，VAD 冗余且有害，遂彻底移除（切窗改由 whisper segment 边界自驱）。

**解码 seam**：库音频多为 m4a/mp3，`audio_file_reader` 只认 WAV/CAF，故 ffmpeg（已打包）先转 16kHz 单声道 PCM WAV（`AudioTranscodeService.transcodeToPcmWav16k`），无原生通道改动。原生 `audio_decode` 通道返回 1kHz（仅供静音检测），不可用于 ASR。

**专用引擎实例（不复用共享评分引擎）**：转录档位可与评分档位不同，复用共享单例会因切换模型 dispose/reload 扰乱评分。故 `LocalTranscriptionTaskManager` 自建 `OfflineAsrEngine`（注入工厂）按所选档位构建 config，用后即 dispose（"谁创建谁销毁"）。后台 keepAlive + 进度 + 可取消（业界标准；native 阻塞段无法中途中断，取消在阶段边界生效）。

**档位与后端解耦**：转录**完全无视评分 `backend` 开关**（Apple Speech 评分用户无需切后端即可转录）。档位偏好独立持久化（`localTranscriptionModelProvider`，默认回退评分 selectedModel/推荐档位，互不回写）。门控 `ensureAsrModelReadyForTranscription` 按指定档位检查/下载，绝不改评分设置。`TranscriptSource.device` 区分"设备本地转录"与 local/ai（词级时间戳合成语义与 local 同侧）。

**风险/验证**：`enableSegmentTimestamps` 已真机（macOS）确认生效——33s 音频出 `whisperSegments=13`、13 条句级 cue、时轴贴合。**待验证**：① 更长音频（>30s 语音、触发多窗滑动）窗口推进正确、无漏词/重复、时轴连续；② int8 tiny WER 偏高时换 small.en 档位（模型本身弱，非管线问题）；③ 长音频与练习评分并发争用 CPU（不同场景，可接受）。

---

## 学习流程设计

### 核心理念

每篇音频经历 **8 个大阶段**的间隔复习周期：

```
首次学习(Day 0) → 首轮复习(当前) → R1(1天) → R2(2天) → R4(4天)
→ R7(7天) → R14(14天) → R28(28天) → 已完成
```

### 首次学习流程

1. **全文盲听** — 不看字幕完整听 1-2 遍，感受大意，选择难度
2. **逐句精听+标注** — 逐句盲听，听不懂显示字幕；标记难句、难意群和生词
3. **难句跟读** — 有字幕跟读难句，遍数根据难度调整（2-5 遍）
4. **段落复述** — 提供关键意群提示，用自己的话复述段落

### 复习流程

各轮次子步骤略有差异（详见 `LearningStage.allSubStages` + `LearningPlan.standard`）：

- **review0 首轮复习**（默认新版 v2）：难句补练 → 全文盲听。
  - v1（迁移前已完成 review0 的旧音频）：难句补练 → 段落复述。
- **review1 / review2 / review4 / review7 / review14**：全文盲听 → 难句补练 → 段落复述。
- **review28 末轮**：全文盲听 → 难句补练 → 全文复述。

### 收藏体系

- **难句子**为主要收藏单位，生词+意群高亮附属于句子
- 独立「单词+意群」本汇总查阅
- R1 及之后听懂的句子可取消收藏

---

## 里程碑

### ✅ Milestone 1: 基础播放器（已完成）

音频导入、三种播放模式（全文/单句/收藏）、循环播放、收藏、字幕显示与同步。

### 📋 Milestone 2: 学习流程引擎

实现 METHOD.md 中的阶段系统，包括：
- 首次学习流程（全文盲听、逐句精听、难句跟读、段落复述）
- 间隔复习调度（R1-R28 自动提醒）
- 学习进度记录（小阶段级别，支持断点续学）
- 难度评估（简单/中等/困难，影响遍数和间隔）

### ✅ Milestone 3: 收藏与标注体系（已完成）

**完成时间**: 2026-03-09

- ✅ Favorites Tab MVP：句子视图（按音频分组）+ 单词视图（展开详情）
- ✅ saved_words 数据表 + DAO + Provider
- ✅ WordDictionarySheet 收藏按钮（记录来源音频/句子）
- ✅ BookmarkDao 跨音频查询（watchAllWithAudioName）
- ✅ 收藏句子一键复习（跨音频乱序复习、盲听→跟读、取消收藏）
- ✅ 难句补练 & 收藏复习设置
- ✅ Milestone 3 测试覆盖补充（65 个新测试）
- 生词+意群高亮（附属于句子）— 延期到 P1 迭代

### 📋 Milestone 4: 体验优化与生产就绪

- 性能优化（大量音频、长列表）
- 错误处理与边界情况完善
- 多平台适配优化（macOS / iOS / Android / Web）
- 新材料推荐控制（每周 2-3 篇，超限提醒）
