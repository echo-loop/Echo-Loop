# Echo Loop 项目规划

> 最后更新：2026-04-03
> 当前焦点：录音+识别功能

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

### 复习流程（review0-review28）

1. 全文盲听 → 2. 跟读 → 3. 段落复述

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
