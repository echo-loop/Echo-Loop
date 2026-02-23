# Fluency 项目规划

> 最后更新：2026-02-23
> 当前阶段：Milestone 1 已完成 ✅，Drift 迁移已完成 ✅，资源库 Tab 改造已完成 ✅，Milestone 2 计划中

## 项目概述

Fluency 是一款 Flutter 跨平台英语听说练习应用，通过结构化的学习流程（首学→间隔复习→毕业检验）帮助用户系统性地提升英语听说能力。

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
│   ├── study_screen.dart            #   学习页（当前占位）
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
| `METHOD.md` | — | 学习方法论完整设计，Milestone 2 的需求文档 |

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
FluencyApp (main.dart)
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
| `learning_progresses` | 学习进度（阶段、小阶段、难度、首学完成时间、复习调度、学习时长） |
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
- 业务层可在不修改引擎的前提下扩展新的播放流程（如 Milestone 2 的首学/复习流程）
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
- 连续模式适合"全文盲听"场景（Milestone 2 首学第一步）
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

> 完整设计文档见 [METHOD.md](./METHOD.md)

### 核心理念

每篇音频经历 **8 个大阶段**的间隔复习周期：

```
首学(Day 0) → 首轮复习(当前) → R1(1天) → R2(2天) → R4(4天)
→ R7(7天) → R14(14天) → R28(28天) → 已完成
```

### 首学流程

1. **全文盲听** — 不看字幕完整听 1-2 遍，感受大意，选择难度
2. **逐句精听+标注** — 逐句盲听，听不懂显示字幕；标记难句、难意群和生词
3. **难句跟读** — 有字幕跟读难句，遍数根据难度调整（2-5 遍）
4. **段级复述** — 提供关键意群提示，用自己的话复述段落

### 复习流程（review0-review28）

1. 全文盲听 → 2. 跟读 → 3. 段级复述

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
- 首学流程（全文盲听、逐句精听、难句跟读、段级复述）
- 间隔复习调度（R1-R28 自动提醒）
- 学习进度记录（小阶段级别，支持断点续学）
- 难度评估（简单/中等/困难，影响遍数和间隔）

### 📋 Milestone 3: 收藏与标注体系

- 难句收藏（精听/复习中标记）
- 生词+意群高亮（附属于句子）
- 独立单词本（汇总所有标记的单词和意群）
- 收藏句子的复习与取消收藏逻辑

### 📋 Milestone 4: 体验优化与生产就绪

- 性能优化（大量音频、长列表）
- 错误处理与边界情况完善
- 多平台适配优化（macOS / iOS / Android / Web）
- 新材料推荐控制（每周 2-3 篇，超限提醒）
