# Fluency - 英语听说练习应用

Flutter 跨平台英语听说练习应用，支持 macOS / iOS / Android / Web。围绕真实音频材料，提供「首学→间隔复习→毕业检验」的完整学习闭环：盲听理解大意、逐句精听标注难点、跟读模仿发音、复述锻炼输出，配合 9 阶段间隔复习（R1-R28）巩固记忆，最终实现脱离字幕流利跟读与复述。

## 产品特色
- 把科学的英语听说学习方法流程化，碎片化，自动化。
- 有针对性的练习和复习，事半功倍，不做无用功。
- 智能自动切分意群，
- 多维度量化学习成果：学习时长，输入输出比，词汇量（唯一）

## 核心功能

### 学习流程
- **首学**：全文盲听 → 逐句精听+标注 → 难句跟读 → 段级复述
- **间隔复习**：9 阶段复习周期（R1-R28），从 1 天到 28 天逐步拉长间隔
- **毕业检验**：全文盲听 + 不看字幕跟读 + 总结复述，达标即毕业
- 进度记录到小阶段级别，支持断点续学

> 完整学习流程设计见 [METHOD.md](./METHOD.md)

### 合集管理
- 创建合集，组织音频材料
- 从本地导入音频文件（支持所有常见音频格式）
- 可选导入字幕文件（SRT/VTT 格式）
- 合集内音频管理（重命名、删除）

### 三种播放模式
- **全文播放**：连续播放整个音频
- **单句播放**：逐句播放并自动暂停，精听利器
- **收藏播放**：只播放收藏的句子，针对性复习

### 灵活的循环播放
- 可配置循环次数（1-10 次或无限）
- 可配置暂停间隔（0-10 秒）
- 支持单句循环、全文循环、收藏句子循环

### 智能收藏系统
- 点击星标即可收藏/取消收藏句子
- 收藏状态自动保存
- 收藏列表展示和快速跳转

### 完整的播放控制
- 播放/暂停/停止
- 上一句/下一句导航
- 进度条拖动定位
- 速度调节（0.5x - 2.0x）
- 点击句子直接跳转播放

### 字幕功能
- 实时高亮当前播放句子
- 自动滚动到当前句子
- 显示时间轴

### 其他
- 响应式设计（移动端底部导航，桌面端侧边导航）
- 浅色/深色/跟随系统主题
- 国际化：英文、简体中文

## 技术栈

| 类别 | 技术 |
|------|------|
| UI 框架 | Flutter + Material Design 3 |
| 状态管理 | Riverpod（代码生成模式） |
| 音频播放 | just_audio + audio_session |
| 国际化 | flutter_localizations + ARB 文件 |
| 字幕解析 | subtitle（SRT/VTT） |
| 文件选择 | file_picker |
| 数据持久化 | Drift (SQLite) + shared_preferences |
| 测试 | flutter_test + mocktail |
| 静态分析 | flutter_lints |

## 项目结构

```
lib/
├── l10n/              # 国际化翻译文件（ARB 格式）
├── models/            # 数据模型（AudioItem, Sentence, Collection 等）
├── providers/         # Riverpod 状态管理
│   ├── audio_engine/  # 音频引擎层（底层播放控制）
│   └── listening_practice/  # 听力练习层（业务逻辑）
│       ├── sentence_tracker.dart     # 句子定位（二分查找）
│       └── bookmark_manager.dart     # 书签管理
├── screens/           # 页面
├── services/          # 服务层（StorageService, SubtitleParser）
└── widgets/           # 可复用组件

integration_test/

test/
├── models/            # 模型单元测试
├── providers/         # Provider / 辅助类测试
├── services/          # 服务层测试
└── widget_test.dart   # Widget 冒烟测试
```

## 常用命令

```bash
# 运行, Debug 模式
flutter run -d macos          # macOS
flutter run -d chrome          # Web
flutter run -d ios             # iOS
flutter run -d android         # Android

# 质量检查
flutter analyze                # 静态分析
flutter test                   # 运行所有测试
flutter test integration_test -d macos # 运行集成测试
dart format .                  # 代码格式化

# 依赖管理
flutter pub get                # 安装依赖
flutter pub upgrade            # 升级依赖

# 代码生成（修改 Riverpod Provider 后）
dart run build_runner build

# 构建（开发环境，使用默认 API 地址）
flutter build macos            # macOS
flutter build apk              # Android APK
flutter build ios              # iOS

# 构建（指定 API 地址）
flutter build macos --dart-define=API_BASE_URL=https://dev.echo-loop.top   # dev 环境
flutter build ios --dart-define=API_BASE_URL=https://www.echo-loop.top     # 生产环境

# 真机运行（指定 API 地址）
flutter run --release -d <DEVICE_ID> --dart-define=API_BASE_URL=https://dev.echo-loop.top
```

## 平台支持

- macOS
- iOS
- Android
- Web

## 环境要求

- Flutter SDK 3.9.2+
- iOS 模拟器 / Android 模拟器 / 真机
- 桌面端：macOS / Windows / Linux 开发环境
