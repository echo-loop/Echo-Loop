# 段落复述视频链路实施计划

> **状态（2026-10-21）**：本文件记录的是视频链路建设时的历史方案。用户随后要求音频和视频复述统一到 MediaEngine；当前实现与维护应以统一链路为准：两种媒体都经 `MediaLearningStartup`、`LearningSession.enterRetellMode` 和 `MediaParagraphPlaybackDriver`。音频复述仍不发布系统媒体控制，也不启用后台保活。下文中“音频继续使用 ForegroundAudioEngine”及音视频分流入口等要求已被取代，不再作为实现规范。

## 目标

为首次学习、复习和自由练习中的段落复述/全文复述补齐视频链路。视频复述复用全文盲听已经建立的媒体启动、段落播放、视频呈现、全屏、CC、句子讲解和生命周期机制。

音频复述继续使用独立的 `ForegroundAudioEngine`；视频复述只使用 `MediaEngine`。除视频画面相关能力外，录音、ASR、评分、AI 评估、倒计时、手动模式、收藏、断点、完成与补做语义必须和音频链路一致。

## 接口与架构

### 段落播放契约

修改：

- `lib/providers/learning_session/paragraph_playback_driver.dart`
- `lib/providers/learning_session/retell_player_provider.dart`

实施：

- 新增 `ForegroundParagraphPlaybackDriver`，将现有 `ForegroundAudioEngine` 适配到已有 `ParagraphPlaybackDriver`。
- 复述状态机不再直接读取 `ForegroundAudioEngine`，统一通过 `ParagraphPlaybackDriver` 完成 session 创建、区间播放、位置监听、暂停/中断、速度和 seek。
- `ForegroundParagraphPlaybackDriver` 保持现有音频语义：中断区间时使用 `stopPlayback()`，不接入锁屏、通知栏或后台保活。
- `MediaParagraphPlaybackDriver` 原样复用，视频复述不创建新的播放抽象。
- `RetellPlayer.initialize(...)` 增加可选参数：

  ```dart
  ParagraphPlaybackDriver? playbackDriver
  ```

  不传时创建 `ForegroundParagraphPlaybackDriver`，保证所有既有音频调用方和行为不变；视频入口注入 `MediaParagraphPlaybackDriver`。
- 生命周期暂停、设置切换、切段、重播、句子跳转、静音跳过、断点高亮和销毁全部改为依赖当前 driver。
- 保留现有 sessionId、倒计时 runId 和迟到回调校验，不让旧音频/视频回调污染新段落。

### 学习会话入口

修改：

- `lib/providers/learning_session/learning_session_provider.dart`

保留现有音频接口：

```dart
Future<void> enterRetellMode(
  String audioItemId,
  List<List<Sentence>> paragraphs, {
  bool isFreePlay = false,
  LearningStage? catchUpStage,
  SubStageType? catchUpSubStage,
})
```

新增视频接口：

```dart
Future<MediaLoadResult> enterMediaRetellMode(
  AudioItem mediaItem,
  List<List<Sentence>> paragraphs, {
  bool isFreePlay = false,
  LearningStage? catchUpStage,
  SubStageType? catchUpSubStage,
})

Future<void> cancelMediaRetellEntry()
```

实施：

- 抽取私有复述会话初始化方法，共享断点解析、设置槽位、难度默认值、收藏、统计、catch-up 和 `RetellPlayer.initialize`，避免音视频各复制一套业务初始化。
- 音频入口保持原顺序：暂停原监听、清理媒体会话、加载到 `ForegroundAudioEngine`、注入前台音频 driver。
- 视频入口严格参考视频盲听/精听：
  - 暂停旧 `AudioEngine`，但不加载或改写音频链路。
  - 使用 `MediaEngine.loadMedia()` 按当前复述速度加载视频。
  - 默认关闭视频字幕轨。
  - 注入 `MediaParagraphPlaybackDriver`。
  - 将会话标记为 `LearningPlaybackChain.media`。
- 新增独立的 `_mediaRetellEntryGeneration`。加载、取消、重试、退出后检查 generation，迟到结果返回 cancelled 并释放其媒体会话。
- 视频加载失败释放 native media 链路，允许页面原位重试。
- 调整 `exitLearningMode()` 清理顺序：视频复述也必须停止复述 player、`fullReset` 录音控制器并释放 `MediaEngine`；媒体分支不得进入音频 `clearClip`/`stop` 路径。
- 视频复述和视频盲听、精听之间不共享活跃 player，只复用类型和生命周期协议。

## 页面与入口

修改：

- `lib/screens/learning_plan_screen.dart`
- `lib/router/app_router.dart`
- `lib/screens/retell_player_screen.dart`

实施：

- 在学习计划页抽取统一的复述打开 helper，由它根据 `AudioItem.isVideo` 分流：
  - 音频：等待 `enterRetellMode()` 完成后进入页面。
  - 视频：先进入页面，通过 `MediaLearningStartup` 延迟执行 `enterMediaRetellMode()`。
- 所有复述入口统一接入该 helper：
  - 首次学习段落复述。
  - 复习段落复述。
  - 复习全文复述。
  - 首次学习自由练习/补做。
  - 各复习阶段自由练习/补做。
- 视频入口使用 `audioSentencesProvider` 从数据库读取字幕，不调用 `_ensureAudioLoaded()`，避免视频进入原音频播放器。
- `MediaLearningStartup.loadKey` 区分材料、复述类型、planned/free-play 和阶段，避免旧加载任务复用错误会话。
- Retell 路由像 Blind Listen 路由一样解析 `state.extra`，向 `RetellPlayerScreen` 注入可选 `MediaLearningStartup`；路由路径不变。
- `RetellPlayerScreen` 复用：
  - `ManagedMediaVisualSurface`
  - `PracticeMediaPresentationHost`
  - `ParagraphPracticeScaffold.topContent`/`fullscreenBody`/`bodyWrapper`
  - `PracticeMediaPresentationSession`
  - `MediaSenseGroupRangePlayback`
- 音频页面不创建任何媒体呈现资源，布局与现有页面保持不变。
- 视频加载遮罩只覆盖 Scaffold body，保留 AppBar；ready 后才开始首段播放。
- 首次播放由“语音能力已就绪”和“媒体已加载”双门控，只允许启动一次；权限失败时取消媒体 startup 并退出。
- 视频普通模式下始终保留画面：播放时同步视频，录音、回放、倒计时和等待态停留在当前末帧。
- 视频播放结束进入 retelling 前自动退出全屏，退出完成后再触发自动录音，保证录音状态、按钮和实时反馈可见。
- 隐藏画面、CC、视频全屏和生命周期视频轨开关完全沿用共享宿主。
- 点击句子进入讲解时：
  - 先沿用复述现有逻辑停止自动流程和录音。
  - 视频入口注入当前 `PracticeMediaPresentationSession` 和 `MediaSenseGroupRangePlayback`。
  - 父页用等比例黑色画布占位，子页借用同一个视频纹理、CC 和全屏状态。
  - 返回后不自动恢复复述，仍按音频链路等待用户操作。
- 录音回放和 AI 评估只使用现有 `AudioPreviewController`，不得占用或重建 `MediaEngine`。

## 修改文件

生产代码：

- `lib/providers/learning_session/paragraph_playback_driver.dart`
- `lib/providers/learning_session/retell_player_provider.dart`
- `lib/providers/learning_session/learning_session_provider.dart`
- `lib/screens/learning_plan_screen.dart`
- `lib/screens/retell_player_screen.dart`
- `lib/router/app_router.dart`

测试与任务记录：

- `test/providers/learning_session/retell_player_provider_test.dart`
- `test/providers/learning_session/learning_session_provider_test.dart`
- `test/screens/retell_player_screen_test.dart`
- `test/screens/learning_plan_screen_test.dart`
- `test/router/app_router_test.dart`
- `test/helpers/shared/fake_notifiers.dart`
- `TASKS.md`

不新增数据库字段、不修改学习进度模型、不新增本地化文案。里程碑不变化，因此不修改 `PLAN.md`。

## 测试计划

- Provider 单测：同一复述状态机分别注入 fake foreground driver 和 fake media driver，验证区间、速度、位置高亮、暂停、重播、切段、断点、静音跳过及过期 session。
- 会话单测：视频成功、失败、取消、重试、迟到完成和退出清理；验证视频不加载前台音频、音频不加载 `MediaEngine`。
- Widget 测试：视频加载前不播放，加载后出现真实视频画布；加载遮罩不覆盖 AppBar；音频页面无视频画布。
- Widget 测试：播放结束时自动退出视频全屏，再进入录音；普通模式下录音、评估和倒计时 UI 与音频一致。
- Widget 测试：隐藏画面、CC、全屏、播放暂停和生命周期恢复。
- Widget 测试：视频句子讲解借用同一媒体会话，父页黑色占位，返回后恢复画面和收藏状态；音频句子讲解参数不变。
- 入口测试：首次学习、复习、全文复述、自由练习和补做均按 `isVideo` 正确分流，并保留 catch-up/stage 参数。
- 路由测试：collection 路由和独立材料路由都能传递 `MediaLearningStartup`。
- 回归现有复述 provider/widget 测试，重点覆盖录音自动停止、自动回放、手动接管、AI 评估和退出确认。

执行检查：

```sh
flutter analyze \
  lib/providers/learning_session/paragraph_playback_driver.dart \
  lib/providers/learning_session/retell_player_provider.dart \
  lib/providers/learning_session/learning_session_provider.dart \
  lib/screens/learning_plan_screen.dart \
  lib/screens/retell_player_screen.dart \
  lib/router/app_router.dart

flutter test test/providers/learning_session/retell_player_provider_test.dart
flutter test test/providers/learning_session/learning_session_provider_test.dart
flutter test test/screens/retell_player_screen_test.dart
flutter test test/screens/learning_plan_screen_test.dart
flutter test test/router/app_router_test.dart
flutter test test/screens/blind_listen_player_screen_test.dart
```

默认不运行 `scripts/check.sh`，因为改动虽跨页面与 provider，但仍限定在复述媒体链路；若相关定向测试暴露共享媒体边界回归，再升级运行完整检查。

## 验收 Checklist

- [ ] 视频材料的首次学习段落复述可以正常进入、加载并播放。
- [ ] 视频材料的复习段落复述和全文复述可以正常进入。
- [ ] 视频材料的自由练习及跳过后补做可以正常进入并正确记完成。
- [ ] 视频加载前不启动复述状态机，失败可重试，退出可取消。
- [ ] 视频播放严格遵循音频复述的段落、遍数、暂停、重播和推进规则。
- [ ] 视频播放结束自动退出全屏后才开始自动录音。
- [ ] 录音、ASR、评分、录音回放、AI 评估和段间倒计时与音频链路一致。
- [ ] 视频画面支持显示/隐藏、CC、全屏和生命周期恢复。
- [ ] 录音及等待阶段保留视频末帧，不创建第二个播放器。
- [ ] 句子讲解复用父级视频会话和区间播放，返回后不会出现双纹理。
- [ ] 视频断点保存、恢复、完成清空和 catch-up 语义与音频一致。
- [ ] 视频退出后 `MediaEngine`、录音控制器、订阅和全屏资源全部释放。
- [ ] 音频复述仍只使用 `ForegroundAudioEngine`，不创建 `MediaEngine`。
- [ ] 视频复述不加载或改写原音频播放链路。
- [ ] 现有音频复述及视频盲听测试全部通过。
- [ ] 相关文件 `flutter analyze` 无问题，定向测试全部通过。
- [ ] `TASKS.md` 勾选任务并记录实际完成时间和验证结果。
