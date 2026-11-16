/// 收藏句复习显示来源视频画面的 macOS 交互测试。
///
/// 用 ffmpeg 生成真实视频（底部白条模拟烧录字幕）与一段音频，走真实 media_kit
/// 播放链路，验证：
/// - 视频卡片在手机竖屏上下分栏、桌面宽屏左右分栏，翻面时画面不重建；
/// - 画面不提供字幕与全屏按钮；遮罩可开关，开关与拖动都写库；
/// - 「再听一遍」由媒体引擎播放这一句，画面随声音移动；
/// - 隐藏画面跨卡片保留；音频卡片保持单栏；设置关闭后立即回到纯音频；
/// - 退出复习释放视频。
///
/// 每个关键状态截图到临时目录（日志 BOOKMARK_VIDEO_SCREENSHOT=路径）。
///
/// 运行：flutter test integration_test/bookmark_review_video_test.dart -d macos
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/memory_scheduler/config/memory_profiles.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_namespaces.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_scheduler_commands.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_subject_ref.dart';
import 'package:echo_loop/features/memory_scheduler/providers/memory_scheduler_providers.dart';
import 'package:echo_loop/features/rating_prompt/data/rating_prompt_task_completion_store.dart';
import 'package:echo_loop/features/rating_prompt/rating_prompt_providers.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'package:echo_loop/features/remote_config/remote_config.dart';
import 'package:echo_loop/features/user_region/user_region_bootstrapper.dart';
import 'package:echo_loop/features/user_region/user_region_providers.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/dictionary/dictionary_registry.dart';
import 'package:echo_loop/providers/dictionary/lookup_controller.dart';
import 'package:echo_loop/providers/dictionary/visible_sources_provider.dart';
import 'package:echo_loop/providers/learning_session/bookmark_review_provider.dart';
import 'package:echo_loop/providers/media_engine/media_engine_provider.dart';
import 'package:echo_loop/providers/practice_media_split_provider.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/screens/bookmark_review_screen.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:echo_loop/services/media_session_router.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:echo_loop/utils/time_format.dart';
import 'package:echo_loop/widgets/common/media_visual_surface.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../test/helpers/mock_providers.dart';

const _captureKey = ValueKey('bookmark-video-capture');
const _stackedKey = ValueKey('practice-media-split-stacked');
const _sideBySideKey = ValueKey('practice-media-split-side-by-side');
const _surfaceKey = ValueKey('media-visual-surface');
const _collapsedKey = ValueKey('media-visual-collapsed-bar');
const _maskButtonKey = ValueKey('media-subtitle-mask-button');
const _maskKey = ValueKey('video-subtitle-mask');
const _videoId = 'review-video';
const _audioId = 'review-audio';

class _NoopSentenceAiApiClient extends SentenceAiApiClient {
  _NoopSentenceAiApiClient() : super.withDio(Dio());
}

class _EchoDictionarySource implements DictionarySource {
  @override
  String get id => 'local';

  @override
  IconData get icon => Icons.abc;

  @override
  bool get canBeDisabled => false;

  @override
  bool get requiresNetwork => false;

  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async => LocalDictResult(
    DictEntry(word: request.word, phonetic: 'x', translation: 'definition'),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory appDir;
  late db.AppDatabase database;

  /// 本用例关心的业务日志（复习视频编排、遮罩、分栏）。
  List<String> logs() => [
    for (final entry in AppLogger.instance.entries)
      if (const {
        'FavoriteSentenceReview',
        'VideoSubtitleMask',
        'PracticeMediaLayout',
      }.contains(entry.tag))
        '[${entry.tag}] ${entry.message}',
  ];

  setUpAll(() async {
    initTimeago();
    if (Platform.isMacOS) {
      await windowManager.ensureInitialized();
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setAlwaysOnTop(true);
    }
  });

  tearDownAll(() async {
    if (Platform.isMacOS) {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.hide();
    }
  });

  setUp(() async {
    appDir = await Directory.systemTemp.createTemp('bookmark-video-test-');
    appDataDirectoryOverride = appDir;
    database = db.AppDatabase(
      NativeDatabase.memory(setup: db.configureAppDatabaseConnection),
    );
    AppLogger.instance.clear();
  });

  tearDown(() async {
    await database.close();
    appDataDirectoryOverride = null;
    await appDir.delete(recursive: true);
  });

  Future<void> generateMedia(String name, {required bool video}) async {
    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=12',
      if (video) ...[
        '-f',
        'lavfi',
        '-i',
        // 底部白条模拟烧录字幕，用来目测遮罩是否盖住。
        'testsrc2=size=640x360:rate=25:duration=12,'
            'drawbox=x=60:y=290:w=520:h=44:color=white@0.95:t=fill',
        '-c:v',
        'mpeg4',
        '-q:v',
        '4',
      ],
      '-c:a',
      'aac',
      '${appDir.path}/$name',
    ]);
    expect(
      ReturnCode.isSuccess(await session.getReturnCode()),
      isTrue,
      reason: await session.getOutput(),
    );
  }

  /// 写入一段视频材料（两句收藏）和一段音频材料（一句收藏），按到期先后排序。
  Future<void> seed() async {
    await generateMedia('review.mp4', video: true);
    await generateMedia('review.m4a', video: false);
    final now = DateTime.now();
    for (final (id, name, path) in [
      (_videoId, 'Video Lesson', 'review.mp4'),
      (_audioId, 'Audio Lesson', 'review.m4a'),
    ]) {
      await database
          .into(database.audioItems)
          .insert(
            db.AudioItemsCompanion.insert(
              id: id,
              name: name,
              audioPath: Value(path),
              addedDate: now,
              updatedAt: now,
            ),
          );
    }
    final bookmarks = [
      (_videoId, 0, 'The first video sentence.', 1.0, 3.0, 3),
      (_videoId, 1, 'The second video sentence.', 5.0, 7.0, 2),
      (_audioId, 0, 'An audio only sentence.', 1.0, 3.0, 1),
    ];
    final scheduler = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(scheduler.dispose);
    for (final (audioId, index, text, start, end, minutesAgo) in bookmarks) {
      final subjectId = 'subject-$audioId-$index';
      await database
          .into(database.bookmarks)
          .insert(
            db.BookmarksCompanion.insert(
              memorySubjectId: Value(subjectId),
              audioItemId: audioId,
              sentenceIndex: index,
              sentenceText: text,
              startTime: start,
              endTime: end,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await scheduler
          .read(memorySchedulerProvider)
          .ensureSchedule(
            EnsureMemoryScheduleCommand(
              subject: MemorySubjectRef(
                namespace: kSavedSentenceNamespace,
                subjectId: subjectId,
              ),
              profile: kFsrsDefaultProfileRef,
              occurredAt: now.subtract(Duration(minutes: minutesAgo)),
            ),
          );
    }
  }

  testWidgets('视频卡片分栏、遮罩、隐藏画面、设置开关与退出释放', (tester) async {
    await tester.runAsync(seed);
    SharedPreferences.setMockInitialValues({
      // 按到期时间排序：视频第 1 句、视频第 2 句、音频句；不自动播放，由用例触发。
      'favorite_review_settings_v1': jsonEncode({
        'order': 'dueAt',
        'autoPlayFront': false,
        'autoPlayBack': false,
      }),
      // 关闭 AI 自动讲解，避免测试访问网络。
      'bookmark_review_settings_v1': jsonEncode({
        'autoShowAiExplanation': false,
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final dictionary = _EchoDictionarySource();
    final captures = Directory(
      '${Directory.systemTemp.path}/bookmark-video-review-$pid',
    );
    await captures.create(recursive: true);

    Future<void> settle([
      Duration duration = const Duration(milliseconds: 200),
    ]) async {
      final end = DateTime.now().add(duration);
      do {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      } while (DateTime.now().isBefore(end));
    }

    Future<void> waitFor(Finder finder, {String? reason}) async {
      for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
        await settle(const Duration(milliseconds: 100));
      }
      expect(finder, findsWidgets, reason: reason);
    }

    Future<void> capture(String name) async {
      await settle(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_captureKey),
      );
      final file = File('${captures.path}/$name.png');
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await file.writeAsBytes(data!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('BOOKMARK_VIDEO_SCREENSHOT=${file.path}');
    }

    Future<void> resize(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await settle(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    }

    addTearDown(tester.view.reset);
    await resize(const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: dedupeOverrides([
          appDatabaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
          // 旧 just_audio 引擎与本功能无关；复习 provider 销毁时会调用其 stop，
          // 真实实现会在销毁期间修改其它 provider 而触发 Riverpod 断言（既有问题）。
          audioEngineProvider.overrideWith(TestAudioEngine.new),
          mediaSessionRouterProvider.overrideWithValue(
            MediaSessionRouter(defaultHandler: BaseAudioHandler()),
          ),
          sentenceAiNotifierProvider.overrideWithValue(
            SentenceAiNotifier(
              cacheDao: createStubbedMockCacheDao(),
              apiClient: _NoopSentenceAiApiClient(),
            ),
          ),
          ...learningSettingsOverrides(),
          ...studyTimeOverrides(),
          analyticsOverride(),
          usageOverride(),
          dictionaryServiceOverride(),
          ratingPromptTaskCompletionStoreProvider.overrideWithValue(
            RatingPromptTaskCompletionStore(prefs),
          ),
          userRegionBootstrapProvider.overrideWith(
            (ref) async => const UserRegionBootstrapResult(
              isChinaUser: false,
              source: UserRegionDecisionSource.systemFallback,
              remoteConfig: RemoteConfig.defaults,
            ),
          ),
          dictionarySourcesProvider.overrideWithValue([dictionary]),
          dictionarySourcesByIdProvider.overrideWithValue({
            dictionary.id: dictionary,
          }),
          resolvedDefaultSourceIdProvider.overrideWithValue(dictionary.id),
          dictionaryLookupContextProvider.overrideWithValue(
            const DictionaryLookupContext(targetLanguage: 'zh-CN'),
          ),
        ]),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // 与收藏页入口一致：先初始化复习，再进入页面，由页面准备首张卡片。
          home: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    // 分栏比例偏好跨用例共享，先恢复默认。
    final split = container.read(practiceMediaSplitProvider.notifier);
    for (final axis in PracticeMediaSplitAxis.values) {
      await split.setVideoFraction(axis, null);
    }
    final review = container.read(bookmarkReviewProvider.notifier);
    final engine = container.read(mediaEngineProvider.notifier);
    BookmarkReviewState state() => container.read(bookmarkReviewProvider);

    await tester.runAsync(review.initialize);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const RepaintBoundary(
            key: _captureKey,
            child: BookmarkReviewScreen(),
          ),
        ),
      ),
    );
    await settle();
    await waitFor(find.byKey(_surfaceKey), reason: '视频卡片应显示画面');
    expect(state().currentCard?.audioItemId, _videoId);
    expect(state().videoPhase, BookmarkReviewVideoPhase.ready);
    expect(find.byKey(_stackedKey), findsOneWidget, reason: '手机竖屏应上下分栏');
    expect(engine.currentPosition.inMilliseconds, closeTo(1000, 300));
    await capture('01-phone-front');

    // 画面控件：无字幕、无全屏；遮罩可新建。
    await tester.tap(find.byKey(_surfaceKey));
    await settle();
    expect(
      find.byKey(const ValueKey('media-subtitle-track-button')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('media-fullscreen-button')), findsNothing);
    expect(find.byKey(_maskButtonKey), findsOneWidget);
    await tester.tap(find.byKey(_maskButtonKey));
    await settle(const Duration(milliseconds: 600));
    expect(find.byKey(_maskKey), findsOneWidget);
    final maskRow = await tester.runAsync(
      () => database.videoSubtitleMaskDao.getByAudioId(_videoId),
    );
    expect(maskRow?.enabled, isTrue, reason: '新建遮罩应写入数据库');
    await capture('02-phone-front-mask');

    // 遮罩可关闭（没有内嵌字幕的视频不应被一块关不掉的遮罩挡住），再重新打开。
    Future<bool?> maskEnabledInDatabase() async => (await tester.runAsync(
      () => database.videoSubtitleMaskDao.getByAudioId(_videoId),
    ))?.enabled;
    await tester.tap(find.byKey(_surfaceKey), warnIfMissed: false);
    await settle();
    await tester.tap(find.byKey(_maskButtonKey));
    await settle(const Duration(milliseconds: 600));
    expect(await maskEnabledInDatabase(), isFalse, reason: '关闭遮罩应写库');
    await tester.tap(find.byKey(_surfaceKey), warnIfMissed: false);
    await settle();
    await tester.tap(find.byKey(_maskButtonKey));
    await settle(const Duration(milliseconds: 600));
    expect(await maskEnabledInDatabase(), isTrue);

    // 拖动遮罩，位置写库。
    final before = maskRow!.rectTop;
    await tester.drag(find.byKey(_maskKey), const Offset(0, -30));
    await settle(const Duration(milliseconds: 600));
    final moved = await tester.runAsync(
      () => database.videoSubtitleMaskDao.getByAudioId(_videoId),
    );
    expect(moved!.rectTop, lessThan(before), reason: '拖动后遮罩位置应写库');

    // 翻面：画面不重建。
    final surfaceState = tester.state(find.byType(MediaVisualSurface));
    await tester.tap(find.byKey(const Key('bookmark-review-reveal-zone')));
    await waitFor(find.byKey(const Key('bookmark-review-answer')));
    await settle();
    expect(
      identical(tester.state(find.byType(MediaVisualSurface)), surfaceState),
      isTrue,
      reason: '翻面时视频画面不应重建',
    );
    await capture('03-phone-back');

    // 再听一遍：媒体引擎播放这一句并停在句尾附近。
    await tester.tap(
      find.byKey(const Key('bookmark-review-sentence-playback-toggle')),
    );
    await settle(const Duration(milliseconds: 600));
    expect(state().playbackState, BookmarkReviewPlaybackState.playing);
    for (
      var i = 0;
      i < 40 && state().playbackState != BookmarkReviewPlaybackState.idle;
      i++
    ) {
      await settle(const Duration(milliseconds: 100));
    }
    expect(state().playbackState, BookmarkReviewPlaybackState.idle);
    expect(engine.currentPosition.inMilliseconds, closeTo(3000, 400));
    expect(
      logs().any((l) => l.contains('play path=video result=completed')),
      isTrue,
    );

    // 宽屏：左右分栏。
    await resize(const Size(1280, 800));
    expect(find.byKey(_sideBySideKey), findsOneWidget, reason: '宽屏应左右分栏');
    await capture('04-desktop-back');

    // 隐藏画面后评分进入下一张（同一视频）：保持隐藏，只定位不重新加载。
    await tester.tap(find.byKey(_surfaceKey));
    await settle();
    await tester.tap(find.byKey(const ValueKey('media-hide-visual-button')));
    await settle();
    expect(find.byKey(_collapsedKey), findsOneWidget);
    await capture('05-desktop-hidden');
    await waitFor(find.byKey(const Key('flashcard-rating-good')));
    await tester.tap(find.byKey(const Key('flashcard-rating-good')));
    await settle(const Duration(milliseconds: 800));
    expect(state().currentCard?.sentence.index, 1);
    expect(find.byKey(_collapsedKey), findsOneWidget, reason: '隐藏画面应跨卡片保留');
    expect(engine.currentPosition.inMilliseconds, closeTo(5000, 300));
    expect(logs().where((l) => l.contains('video.sync action=open')).length, 1);
    expect(logs().any((l) => l.contains('video.sync action=reuse')), isTrue);
    await tester.tap(find.byKey(_collapsedKey));
    await settle();
    expect(find.byKey(_surfaceKey), findsOneWidget);
    await capture('06-desktop-front-card2');

    // 设置关闭：立即回到纯音频单栏；再打开恢复画面。
    await tester.tap(find.byKey(const Key('bookmark-review-settings')));
    await settle(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('bookmark-review-show-video')));
    await settle(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('bookmark-review-settings-close')));
    await settle(const Duration(milliseconds: 600));
    expect(find.byKey(_surfaceKey), findsNothing);
    expect(state().videoPhase, BookmarkReviewVideoPhase.none);
    await capture('07-desktop-video-off');
    await tester.tap(find.byKey(const Key('bookmark-review-settings')));
    await settle(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('bookmark-review-show-video')));
    await settle(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('bookmark-review-settings-close')));
    await waitFor(find.byKey(_surfaceKey), reason: '设置重新开启后应恢复画面');
    // 等设置弹窗关闭动画结束，避免点按落在遮罩层上。
    await settle(const Duration(milliseconds: 600));
    await capture('07b-desktop-video-on-again');

    // 音频卡片：单栏，无画面。
    await tester.tap(find.byKey(const Key('bookmark-review-reveal-zone')));
    await waitFor(find.byKey(const Key('flashcard-rating-good')));
    await settle(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('flashcard-rating-good')));
    await settle(const Duration(milliseconds: 800));
    expect(state().currentCard?.audioItemId, _audioId);
    expect(find.byKey(_surfaceKey), findsNothing);
    expect(find.byKey(_sideBySideKey), findsNothing);
    await capture('08-desktop-audio-card');

    // 退出：释放视频会话。
    await tester.runAsync(review.disposeSession);
    await settle();
    expect(container.read(mediaEngineProvider).currentMediaId, isNull);
    // ignore: avoid_print
    print('BOOKMARK_VIDEO_LOGS=\n${logs().join('\n')}');
  });
}
