/// PlayerScreen 测试
///
/// 测试播放器页面的渲染和交互。
/// 注意：PlayerScreen 在 macOS 上包含 _HotkeyTipsCarousel（Timer.periodic），
/// 每个测试结束前需替换 widget tree 触发 dispose 取消 timer。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:echo_loop/screens/player_screen.dart';
import 'package:echo_loop/widgets/common/paragraph_sentence_list_card.dart';
import 'package:echo_loop/widgets/common/masked_sentence_tile.dart';
import 'package:echo_loop/widgets/common/bookmark_toggle_row.dart';
import 'package:echo_loop/widgets/playback_controls.dart';
import 'package:echo_loop/widgets/practice/annotation_content_view.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/playback_settings.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/database/app_database.dart' show AudioItem, Bookmark;
import 'package:echo_loop/database/daos/audio_item_dao.dart';
import 'package:echo_loop/database/daos/bookmark_dao.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

class _MockApiClient extends Mock implements SentenceAiApiClient {}

/// 测试用 BookmarkDao（AnnotationContentView 词典/收藏依赖）
class _TestBookmarkDao implements BookmarkDao {
  @override
  Future<List<Bookmark>> getByAudioId(String audioItemId) async => const [];

  @override
  Stream<List<Bookmark>> watchByAudioId(String audioItemId) =>
      Stream<List<Bookmark>>.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// 测试用 AudioItemDao（词级时间戳加载返回空）
class _TestAudioItemDao implements AudioItemDao {
  @override
  Future<AudioItem?> getById(String id) async => null;

  @override
  Future<void> updateWordTimestamps(String audioItemId, String? json) async {}

  // AnnotationContentView 经 audioSentencesProvider 读字幕做翻译上下文；
  // 单句模式测试无需真实字幕，返回 null（前后句为空）。
  @override
  Future<String?> getTranscriptSrt(String audioItemId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _RecordingListeningPractice extends TestListeningPractice {
  _RecordingListeningPractice(super.initialState);

  /// 记录 PageView 翻页触发的选句调用（含全局下标与是否起播）。
  final List<({int index, bool autoPlay})> selectFullCalls = [];
  final List<({int index, bool autoPlay})> selectBookmarkCalls = [];

  @override
  Future<void> selectFullSentence(int index, {bool autoPlay = true}) async {
    selectFullCalls.add((index: index, autoPlay: autoPlay));
    await super.selectFullSentence(index, autoPlay: autoPlay);
  }

  @override
  Future<void> selectBookmarkedSentence(
    int index, {
    bool autoPlay = true,
  }) async {
    selectBookmarkCalls.add((index: index, autoPlay: autoPlay));
    await super.selectBookmarkedSentence(index, autoPlay: autoPlay);
  }

  /// 模拟播放中外部推进当前句（gapless 自动翻页路径），不经 PageView。
  void emitFullIndex(int index) {
    state = state.copyWith(currentFullIndex: index);
  }
}

/// 测试恢复断点首帧：getter 已在恢复位置，但 positionStream 还未发事件。
class _RestorePositionAudioEngine extends TestAudioEngine {
  _RestorePositionAudioEngine({
    required this.restoredPosition,
    super.initialState,
  });

  final Duration restoredPosition;

  @override
  Duration get absoluteCurrentPosition => restoredPosition;

  @override
  Stream<Duration> get absolutePositionStream => const Stream.empty();
}

/// 单句模式（精听）所需 overrides：在音频 overrides 基础上补齐
/// [AnnotationContentView] 的 AI / DAO / 学习设置依赖。
List<Override> _singleSentenceOverrides({
  required ListeningPracticeState practiceState,
  AudioEngineState? engineState,
}) {
  return [
    ..._audioOverrides(practiceState: practiceState, engineState: engineState),
    ...learningSettingsOverrides(),
    bookmarkDaoProvider.overrideWithValue(_TestBookmarkDao()),
    audioItemDaoProvider.overrideWithValue(_TestAudioItemDao()),
    sentenceAiNotifierProvider.overrideWithValue(
      SentenceAiNotifier(
        cacheDao: createStubbedMockCacheDao(),
        apiClient: _MockApiClient(),
      ),
    ),
  ];
}

/// 有音频状态的通用 provider overrides
List<Override> _audioOverrides({
  ListeningPracticeState? practiceState,
  AudioEngineState? engineState,
}) {
  return [
    appSettingsProvider.overrideWith(() => TestAppSettings()),
    audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
    collectionListProvider.overrideWith(() => TestCollectionList()),
    listeningPracticeProvider.overrideWith(
      () => TestListeningPractice(
        practiceState ?? const ListeningPracticeState(),
      ),
    ),
    audioEngineProvider.overrideWith(
      () => TestAudioEngine(
        initialState:
            engineState ??
            const AudioEngineState(totalDuration: Duration(seconds: 120)),
      ),
    ),
  ];
}

/// 单句模式（精听）swipe 测试 overrides：注入指定的 [player]（录制选句调用），
/// 并补齐 [AnnotationContentView] 的 AI / DAO / 学习设置依赖。
List<Override> _recordingOverrides(_RecordingListeningPractice player) => [
  appSettingsProvider.overrideWith(() => TestAppSettings()),
  audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
  collectionListProvider.overrideWith(() => TestCollectionList()),
  listeningPracticeProvider.overrideWith(() => player),
  audioEngineProvider.overrideWith(
    () => TestAudioEngine(
      initialState: const AudioEngineState(
        totalDuration: Duration(seconds: 120),
      ),
    ),
  ),
  ...learningSettingsOverrides(),
  bookmarkDaoProvider.overrideWithValue(_TestBookmarkDao()),
  audioItemDaoProvider.overrideWithValue(_TestAudioItemDao()),
  sentenceAiNotifierProvider.overrideWithValue(
    SentenceAiNotifier(
      cacheDao: createStubbedMockCacheDao(),
      apiClient: _MockApiClient(),
    ),
  ),
];

List<Override> _restoreProgressOverrides({
  required ListeningPracticeState practiceState,
  required Duration restoredPosition,
}) => [
  appSettingsProvider.overrideWith(() => TestAppSettings()),
  audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
  collectionListProvider.overrideWith(() => TestCollectionList()),
  listeningPracticeProvider.overrideWith(
    () => TestListeningPractice(practiceState),
  ),
  audioEngineProvider.overrideWith(
    () => _RestorePositionAudioEngine(
      restoredPosition: restoredPosition,
      initialState: const AudioEngineState(
        totalDuration: Duration(seconds: 120),
      ),
    ),
  ),
];

/// 替换 widget tree 触发 dispose，再 pump 一帧让 deactivate 中的
/// Future(...) 和 _HotkeyTipsCarousel 的 periodic Timer 全部完成/取消
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // 额外 pump 让 deactivate 中 Future 微任务执行完毕
  await tester.pump();
  await tester.pump();
}

void main() {
  group('PlayerScreen', () {
    group('渲染', () {
      testWidgets('无音频时显示空状态', (tester) async {
        await tester.pumpWidget(createTestScreen(const PlayerScreen()));
        await tester.pump();

        expect(find.text('No audio loaded'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('无音频时 AppBar 显示 Player 标题', (tester) async {
        await tester.pumpWidget(createTestScreen(const PlayerScreen()));
        await tester.pump();

        expect(find.text('Player'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('有音频时显示音频名称作为标题', (tester) async {
        final item = createTestAudioItem(name: 'My Lesson');
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('My Lesson'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('有音频和句子时显示 TabBar', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pump();

        // TabBar 应显示"全文"和"书签"标签
        expect(find.byType(TabBar), findsOneWidget);
        expect(find.textContaining('Full Text'), findsOneWidget);
        expect(find.textContaining('Bookmarked'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('句子列表复用盲听共享组件渲染', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pump();

        // 列表改用共享组件 ParagraphSentenceListCard + MaskedSentenceTile
        expect(find.byType(ParagraphSentenceListCard), findsOneWidget);
        expect(find.byType(MaskedSentenceTile), findsNWidgets(3));
        await _disposeTree(tester);
      });

      testWidgets('显示 PlaybackControls', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pump();

        // 播放控制栏应存在（play_arrow 限定在 PlaybackControls 内，
        // 因为当前播放句的编号区也会渲染 play_arrow）
        expect(
          find.descendant(
            of: find.byType(PlaybackControls),
            matching: find.byIcon(Icons.play_arrow),
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.skip_previous), findsOneWidget);
        expect(find.byIcon(Icons.skip_next), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('移动端状态 label 不再占用完整底部安全区', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = const FakeViewPadding(bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(bottom: 34);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);

        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            locale: const Locale('zh'),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pump();

        final statusRowBottom = tester
            .getRect(find.byKey(kPlayerInfoBarStatusRowKey))
            .bottom;
        final screenBottom =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;

        // 底部状态行保留约 16px 压缩安全区，避免贴住 Home indicator，
        // 同时不使用 34px 全量安全区把播放器控制面板顶高。
        expect(screenBottom - statusRowBottom, closeTo(16, 0.1));
        await _disposeTree(tester);
      });

      testWidgets('恢复断点后进度条首帧显示当前绝对位置，不回到 0:00', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 6);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _restoreProgressOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 5,
              ),
              restoredPosition: const Duration(seconds: 45),
            ),
          ),
        );
        await tester.pump();

        final progressBar = tester.widget<ProgressBar>(
          find.byType(ProgressBar),
        );
        expect(progressBar.progress, const Duration(seconds: 45));
        expect(progressBar.total, const Duration(seconds: 120));
        await _disposeTree(tester);
      });

      testWidgets('AppBar 不再显示设置按钮（已移除）', (tester) async {
        await tester.pumpWidget(createTestScreen(const PlayerScreen()));
        await tester.pump();

        expect(find.byIcon(Icons.tune), findsNothing);
        await _disposeTree(tester);
      });

      testWidgets('有音频但无字幕时显示无字幕提示', (tester) async {
        final item = createTestAudioItem();

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: const [], // 无句子
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('No Subtitle'), findsOneWidget);
        expect(find.byIcon(Icons.subtitles_off_outlined), findsOneWidget);
        await _disposeTree(tester);
      });
    });

    group('交互', () {
      testWidgets('点击循环按钮打开循环设置弹窗', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pump();

        // 默认两循环都关：控制栏循环图标为 repeat（无徽标干扰）
        await tester.tap(find.byIcon(Icons.repeat));
        await tester.pumpAndSettle();

        // 应弹出循环设置弹窗（含两组循环开关，无标题）
        expect(find.text('Loop Settings'), findsNothing);
        expect(find.text('Whole-text loop'), findsOneWidget);
        expect(find.text('Single-sentence loop'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('切换全文/书签 Tab', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pump();

        // 点击书签标签
        await tester.tap(find.textContaining('Bookmarked'));
        // Tab 切换动画 300ms + 内容构建，分多次 pump 确保完成
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        // 应显示无书签提示
        expect(find.text('No bookmarked sentences'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('横向滑动不会切换全文/书签 Tab', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No bookmarked sentences'), findsNothing);

        await tester.drag(find.byType(TabBarView), const Offset(-400, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        expect(find.text('No bookmarked sentences'), findsNothing);
        expect(find.byType(ParagraphSentenceListCard), findsOneWidget);

        await tester.tap(find.textContaining('Bookmarked'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        expect(find.text('No bookmarked sentences'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('点击句子编号区从该句开始播放', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 初始：第 1 句播放（编号区显示 ▶），第 2 句编号区显示 '2'
        expect(find.text('2'), findsOneWidget);
        expect(find.text('1'), findsNothing);

        // 点击第 2 句编号区 → selectFullSentence(1) → currentFullIndex=1
        await tester.tap(
          find.byKey(
            const ValueKey('$kMaskedSentenceNumberHitAreaKeyPrefix-1'),
          ),
        );
        await tester.pump();

        // 第 2 句变为播放（▶），第 1 句编号区恢复显示 '1'
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsNothing);
        await _disposeTree(tester);
      });

      testWidgets('点击句子主体先切换焦点再进入讲解页', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);
        final player = _RecordingListeningPractice(
          ListeningPracticeState(
            currentAudioItem: item,
            sentences: sentences,
            currentFullIndex: 0,
          ),
        );

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _recordingOverrides(player),
          ),
        );
        await tester.pumpAndSettle();

        // 点击非当前句主体区，避开左侧编号播放热区。
        await tester.tap(
          find.byKey(const ValueKey('$kMaskedSentenceBodyHitAreaKeyPrefix-2')),
        );
        await tester.pumpAndSettle();

        // 正文点击只切换焦点，不自动播放；返回时列表会跟随新焦点。
        expect(player.selectFullCalls, [(index: 2, autoPlay: false)]);
        expect(player.state.currentFullIndex, 2);
        // 导航到讲解页 stub。
        expect(find.text('Sentence Detail'), findsOneWidget);
        await _disposeTree(tester);
      });
    });

    group('单句模式（精听）', () {
      testWidgets('复用精听解析组件 AnnotationContentView + 难句标记行', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _singleSentenceOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
                settings: const PlaybackSettings(singleSentenceMode: true),
              ),
            ),
          ),
        );
        await tester.pump();

        // 不再是旧的列表卡片，而是精听解析视图 + 难句标记行
        expect(find.byType(AnnotationContentView), findsOneWidget);
        expect(find.byType(BookmarkToggleRow), findsOneWidget);
        expect(find.byType(ParagraphSentenceListCard), findsNothing);
        await _disposeTree(tester);
      });

      testWidgets('隐藏字幕时叠加遮罩，显示字幕时无遮罩', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        // showTranscript = false → 遮罩存在
        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _singleSentenceOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
                settings: const PlaybackSettings(
                  singleSentenceMode: true,
                  showTranscript: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // 遮罩存在：模糊层 + IgnorePointer 禁用下层交互
        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(find.byType(IgnorePointer), findsWidgets);
        await _disposeTree(tester);

        // showTranscript = true → 无遮罩
        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _singleSentenceOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
                settings: const PlaybackSettings(singleSentenceMode: true),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(BackdropFilter), findsNothing);
        await _disposeTree(tester);
      });

      testWidgets('点击难句标记行切换收藏状态', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _singleSentenceOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
                settings: const PlaybackSettings(singleSentenceMode: true),
              ),
            ),
          ),
        );
        await tester.pump();

        // 初始未标记
        expect(find.text('Tap to mark as difficult'), findsOneWidget);

        await tester.tap(find.byType(BookmarkToggleRow));
        await tester.pump();

        // 切换后显示已标记文案
        expect(find.text('Tap to mark as difficult'), findsNothing);
        expect(find.text('Marked difficult, tap to undo'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('全文 tab 单句模式左滑切到下一句（PageView 翻页）', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);
        final player = _RecordingListeningPractice(
          ListeningPracticeState(
            currentAudioItem: item,
            sentences: sentences,
            currentFullIndex: 0,
            settings: const PlaybackSettings(singleSentenceMode: true),
          ),
        );

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _recordingOverrides(player),
          ),
        );
        await tester.pumpAndSettle();

        await tester.fling(
          find.byKey(kPlayerSingleSentenceSwipeAreaKey),
          const Offset(-500, 0),
          1000,
        );
        await tester.pumpAndSettle();

        // 暂停态翻页：selectFullSentence(1, autoPlay:false)。
        expect(player.selectFullCalls, [(index: 1, autoPlay: false)]);
        expect(player.state.currentFullIndex, 1);
        await _disposeTree(tester);
      });

      testWidgets('播放中翻页保持播放态（autoPlay:true）', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);
        final player = _RecordingListeningPractice(
          ListeningPracticeState(
            currentAudioItem: item,
            sentences: sentences,
            currentFullIndex: 0,
            isPlaying: true,
            settings: const PlaybackSettings(singleSentenceMode: true),
          ),
        );

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _recordingOverrides(player),
          ),
        );
        await tester.pumpAndSettle();

        await tester.fling(
          find.byKey(kPlayerSingleSentenceSwipeAreaKey),
          const Offset(-500, 0),
          1000,
        );
        await tester.pumpAndSettle();

        expect(player.selectFullCalls, [(index: 1, autoPlay: true)]);
        await _disposeTree(tester);
      });

      testWidgets('首页右滑被端点吸附拦截，不触发选句', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);
        final player = _RecordingListeningPractice(
          ListeningPracticeState(
            currentAudioItem: item,
            sentences: sentences,
            currentFullIndex: 0,
            settings: const PlaybackSettings(singleSentenceMode: true),
          ),
        );

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _recordingOverrides(player),
          ),
        );
        await tester.pumpAndSettle();

        // 首页向右滑（回上一句）应被 PageView 端点吸附拦截。
        await tester.fling(
          find.byKey(kPlayerSingleSentenceSwipeAreaKey),
          const Offset(500, 0),
          1000,
        );
        await tester.pumpAndSettle();

        expect(player.selectFullCalls, isEmpty);
        expect(player.state.currentFullIndex, 0);
        await _disposeTree(tester);
      });

      testWidgets('外部推进当前句时 PageView 自动跟随，不回环触发选句', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);
        final player = _RecordingListeningPractice(
          ListeningPracticeState(
            currentAudioItem: item,
            sentences: sentences,
            currentFullIndex: 0,
            isPlaying: true,
            settings: const PlaybackSettings(singleSentenceMode: true),
          ),
        );

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _recordingOverrides(player),
          ),
        );
        await tester.pumpAndSettle();

        // 模拟 gapless 播放外部推进到第 2 句。
        player.emitFullIndex(1);
        await tester.pumpAndSettle();

        // PageView 跟随到 pos 1（animateToPage 落点回声被 guard 拦截，无新选句调用）。
        expect(player.state.currentFullIndex, 1);
        expect(player.selectFullCalls, isEmpty);
        await _disposeTree(tester);
      });

      testWidgets('整篇循环回卷（末句→首句）跨多页对齐不触发选句', (tester) async {
        // 回归 §7.6 之后的精听整篇循环 bug：回卷时 currentFullIndex 从末句跳回 0，
        // animateToPage 跨多页途经的中间页 onPageChanged 不得被当作用户滑动反向
        // selectFullSentence（否则会重启整篇循环、清零已播遍数 → 徽标回到 1/N）。
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 8);
        final player = _RecordingListeningPractice(
          ListeningPracticeState(
            currentAudioItem: item,
            sentences: sentences,
            currentFullIndex: 7,
            isPlaying: true,
            settings: const PlaybackSettings(singleSentenceMode: true),
          ),
        );

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _recordingOverrides(player),
          ),
        );
        await tester.pumpAndSettle();

        // 模拟整篇循环回卷：当前句从末句（7）跳回首句（0）。
        player.emitFullIndex(0);
        await tester.pumpAndSettle();

        // PageView 跨 7→0 多页对齐，途经中间页均不触发选句。
        expect(player.state.currentFullIndex, 0);
        expect(player.selectFullCalls, isEmpty);
        await _disposeTree(tester);
      });

      testWidgets('收藏 tab 单句模式左右滑动切换收藏句（PageView 翻页）', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);
        final player = _RecordingListeningPractice(
          ListeningPracticeState(
            currentAudioItem: item,
            sentences: sentences,
            bookmarkedIndices: const {0, 2},
            currentFullIndex: 0,
            currentBookmarkIndex: 0,
            playlistMode: PlaylistMode.full,
            fullSettings: const PlaybackSettings(singleSentenceMode: true),
            bookmarkSettings: const PlaybackSettings(singleSentenceMode: true),
          ),
        );

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _recordingOverrides(player),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.textContaining('Bookmarked'));
        // 等待 TabBarView 切换动画结束，否则滑动区仍在横向位移中，
        // fling 命中点会落到正在滑出的全文页上而非收藏页滑动区。
        await tester.pumpAndSettle();

        // 收藏子集 {0,2}：pos0→pos1 对应全局下标 2。
        await tester.fling(
          find.byKey(kPlayerBookmarkSingleSentenceSwipeAreaKey),
          const Offset(-500, 0),
          1000,
        );
        await tester.pumpAndSettle();

        expect(player.selectBookmarkCalls.last, (index: 2, autoPlay: false));
        expect(player.state.currentBookmarkIndex, 2);

        await tester.fling(
          find.byKey(kPlayerBookmarkSingleSentenceSwipeAreaKey),
          const Offset(500, 0),
          1000,
        );
        await tester.pumpAndSettle();

        expect(player.selectBookmarkCalls.last, (index: 0, autoPlay: false));
        expect(player.state.currentBookmarkIndex, 0);
        await _disposeTree(tester);
      });
    });
  });
}
