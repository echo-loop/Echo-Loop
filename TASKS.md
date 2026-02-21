# Fluency 任务清单

> 最后更新：2026-02-21
> 当前焦点：Milestone 2 - 学习流程引擎

---

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
**Commit**: 0bcc0f1
**变更点**:
- 新建 16 个文件（表定义、DAO、数据库、迁移服务、Provider、枚举、测试）
- 修改 12 个文件（main.dart、4 个 Provider、模型、屏幕、测试）
- 全量测试 197 通过，集成测试 5 通过，macOS 构建成功

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
**Commit**: 11a5eb0

## 优化合集 Tab

- [x] 图标颜色优化：folder/audiotrack 图标从 `onPrimaryContainer` 改为 `primary`（蓝色）
- [x] 音频菜单改为"重命名 + 删除"（原仅"从合集移除"）
- [x] 上传同名音频到同一合集时弹出错误提醒
- [x] 修复字幕标记显示错误：loadLibrary 增加字幕文件存在性验证；AudioItem.copyWith 支持显式 null transcriptPath
- [x] 去掉图标 CircleAvatar 背景色（backgroundColor 改为 transparent）
- [x] 修复合集音频数量不正确：删除音频时清理合集引用 + 启动时清理过期引用

**完成时间**: 2026-02-21
**Commit**: 2ea7b5a

## Milestone 2: 学习流程引擎

- [ ] 设计学习进度数据模型（阶段、小阶段、完成状态、难度）
- [ ] 实现首学流程 — 全文盲听模式
- [ ] 实现首学流程 — 逐句精听+标注模式
- [ ] 实现首学流程 — 难句跟读模式
- [ ] 实现首学流程 — 段级复述模式
- [ ] 实现复习调度引擎（R1-R28 间隔计算与提醒）
- [ ] 实现学习进度记录与断点续学
- [ ] 实现难度评估（简单/中等/困难）及其对遍数、间隔的影响

## Milestone 3: 收藏与标注体系

- [ ] 实现难句收藏（精听/复习中标记）
- [ ] 实现生词+意群高亮（附属于句子）
- [ ] 实现独立单词本（汇总所有标记的单词和意群）
- [ ] 实现收藏句子的复习与取消收藏逻辑

## Milestone 4: 体验优化与生产就绪

- [ ] 性能优化（大量音频、长列表场景）
- [ ] 错误处理与边界情况完善
- [ ] 多平台适配优化
- [ ] 新材料推荐控制（每周 2-3 篇，超限提醒）

---

## 任务完成记录模板

<!--
完成任务后，按以下格式在任务下方添加记录：

**完成时间**: 2026-XX-XX
**变更点**:
- 修改了 X 文件，实现 Y 功能
- 添加了 Z 测试，覆盖 A 场景
-->
