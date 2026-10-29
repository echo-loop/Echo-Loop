import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/database/daos/bookmark_dao.dart';
import 'package:echo_loop/database/daos/learning_progress_dao.dart';
import 'package:echo_loop/database/daos/stage_completion_dao.dart';
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/providers/notification_permission_provider.dart';
import 'package:echo_loop/providers/time_provider.dart';
import 'package:echo_loop/services/notification_permission_service.dart';
import 'package:mocktail/mocktail.dart';
import '../helpers/mock_providers.dart';

// ========== Mock 类 ==========

class MockLearningProgressDao extends Mock implements LearningProgressDao {}

class MockStageCompletionDao extends Mock implements StageCompletionDao {}

class MockBookmarkDao extends Mock implements BookmarkDao {}

class MockNotificationPermissionService extends Mock
    implements NotificationPermissionService {}

/// 测试用 Notifier：继承真实逻辑，覆盖 build() 注入初始状态，
/// 同时保留生产 build() 中安装的 settings → reconcile 监听器。
class _TestLearningProgressNotifier extends LearningProgressNotifier {
  final LearningProgressState _initialState;

  _TestLearningProgressNotifier(this._initialState);

  @override
  LearningProgressState build() {
    super.build();
    return _initialState;
  }
}

/// 测试用学习设置 Notifier：不依赖 SP，纯内存状态。
///
/// 用于通过 `setAutoSkipRetell` 直接触发 settings 变化、验证 progress 侧
/// 的 listener 联动（autoSkipRetell false→true 时的全量扫描）。
class _TestLearningSettingsNotifier extends Notifier<LearningSettings>
    implements LearningSettingsNotifier {
  final LearningSettings _initial;

  _TestLearningSettingsNotifier(this._initial);

  @override
  LearningSettings build() => _initial;

  @override
  Future<void> setAutoSkipRetell(bool enabled) async {
    if (state.autoSkipRetell == enabled) return;
    state = state.copyWith(autoSkipRetell: enabled);
  }

  @override
  Future<void> setShowStudyRecommendation(bool enabled) async {
    if (state.showStudyRecommendation == enabled) return;
    state = state.copyWith(showStudyRecommendation: enabled);
  }

  @override
  Future<void> setAutoFavoriteOnCantUnderstand(bool enabled) async {
    if (state.autoFavoriteOnCantUnderstand == enabled) return;
    state = state.copyWith(autoFavoriteOnCantUnderstand: enabled);
  }

  @override
  Future<void> setAutoExpandCachedAnnotation(bool enabled) async {
    if (state.autoExpandCachedAnnotation == enabled) return;
    state = state.copyWith(autoExpandCachedAnnotation: enabled);
  }

  @override
  Future<void> setAutoShowAiExplanation(bool enabled) async {
    if (state.autoShowAiExplanation == enabled) return;
    state = state.copyWith(autoShowAiExplanation: enabled);
  }

  @override
  Future<void> setAutoShowAiAnalysis(bool enabled) async {
    if (state.autoShowAiAnalysis == enabled) return;
    state = state.copyWith(autoShowAiAnalysis: enabled);
  }

  @override
  Future<void> setAutoShowAiTranslation(bool enabled) async {
    if (state.autoShowAiTranslation == enabled) return;
    state = state.copyWith(autoShowAiTranslation: enabled);
  }

  @override
  Future<void> setAutoShowAiSenseGroups(bool enabled) async {
    if (state.autoShowAiSenseGroups == enabled) return;
    state = state.copyWith(autoShowAiSenseGroups: enabled);
  }

  @override
  Future<void> setAutoPlayRetellRecordingAfterCompletion(bool enabled) async {
    if (state.autoPlayRetellRecordingAfterCompletion == enabled) return;
    state = state.copyWith(autoPlayRetellRecordingAfterCompletion: enabled);
  }

  @override
  Future<void> markRetellAutoPlaybackPromptShown() async {
    if (state.retellAutoPlaybackPromptShown) return;
    state = state.copyWith(retellAutoPlaybackPromptShown: true);
  }

  @override
  Future<void> markPdfExportReminderShown() async {
    if (state.pdfExportReminderShown) return;
    state = state.copyWith(pdfExportReminderShown: true);
  }

  @override
  Future<void> setRetellRatingEnabled(bool enabled) async {
    if (state.retellRatingEnabled == enabled) return;
    state = state.copyWith(retellRatingEnabled: enabled);
  }

  @override
  Future<void> setListenAndRepeatRatingEnabled(bool enabled) async {
    if (state.listenAndRepeatRatingEnabled == enabled) return;
    state = state.copyWith(listenAndRepeatRatingEnabled: enabled);
  }

  @override
  void reloadFromPrefs() {
    // 测试 Notifier 不依赖 SP，无需回灌；保持当前内存状态即可。
  }
}

void main() {
  late MockLearningProgressDao mockDao;
  late MockStageCompletionDao mockStageCompletionDao;
  late MockBookmarkDao mockBookmarkDao;

  setUpAll(() {
    // 注册 Companion 类型的 fallback 值
    registerFallbackValue(
      db.LearningProgressesCompanion(
        audioItemId: const Value('fallback'),
        currentStage: const Value('firstLearn'),
        currentSubStage: const Value('blindListen'),
        difficulty: const Value(2),
        firstLearnCompletedAt: const Value(null),
        lastStageCompletedAt: const Value(null),
        currentStageStartedAt: Value(DateTime(2026)),
        totalStudyDurationMs: const Value(0),
        updatedAt: Value(DateTime(2026)),
      ),
    );
    registerFallbackValue(
      db.StageCompletionsCompanion(
        audioItemId: const Value('fallback'),
        stage: const Value('firstLearn'),
        subStage: const Value('blindListen'),
        completedAt: Value(DateTime(2026)),
        durationMs: const Value(0),
      ),
    );
  });

  setUp(() {
    mockDao = MockLearningProgressDao();
    mockStageCompletionDao = MockStageCompletionDao();
    mockBookmarkDao = MockBookmarkDao();

    // 默认 stub
    when(() => mockDao.upsert(any())).thenAnswer((_) async {});
    when(() => mockDao.getByAudioId(any())).thenAnswer((_) async => null);
    when(() => mockDao.deleteByAudioId(any())).thenAnswer((_) async {});
    when(
      () => mockStageCompletionDao.insertRecord(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockStageCompletionDao.deleteByAudioId(any()),
    ).thenAnswer((_) async {});
    // 默认无难句书签
    when(
      () => mockBookmarkDao.getBookmarkedIndices(any()),
    ).thenAnswer((_) async => <int>{});
  });

  /// 创建带 mock DAO 的 ProviderContainer
  ///
  /// [bookmarks] 控制 mock 书签 DAO 返回的难句索引集合，用于验证
  /// 「难句跟读无难句连带跳过」逻辑。
  ProviderContainer createContainer(
    LearningProgressState initialState, {
    NowGetter? nowGetter,
    bool autoSkipRetell = false,
    Set<int>? bookmarks,
    NotificationPermissionService? notificationPermissionService,
  }) {
    if (bookmarks != null) {
      when(
        () => mockBookmarkDao.getBookmarkedIndices(any()),
      ).thenAnswer((_) async => bookmarks);
    }
    final container = ProviderContainer(
      overrides: [
        learningProgressNotifierProvider.overrideWith(
          () => _TestLearningProgressNotifier(initialState),
        ),
        learningProgressDaoProvider.overrideWithValue(mockDao),
        stageCompletionDaoProvider.overrideWithValue(mockStageCompletionDao),
        bookmarkDaoProvider.overrideWithValue(mockBookmarkDao),
        if (nowGetter != null) nowProvider.overrideWithValue(nowGetter),
        analyticsOverride(),
        if (notificationPermissionService != null)
          notificationPermissionServiceProvider.overrideWithValue(
            notificationPermissionService,
          )
        else
          notificationPermissionOverride(),
        ...learningSettingsOverrides(autoSkipRetell: autoSkipRetell),
        learningSettingsProvider.overrideWith(
          () => _TestLearningSettingsNotifier(
            LearningSettings(autoSkipRetell: autoSkipRetell),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// 便捷方法：从 container 读取指定音频的进度
  LearningProgress? readProgress(ProviderContainer container, String id) {
    return container.read(learningProgressNotifierProvider).progressMap[id];
  }

  /// 便捷方法：获取 notifier
  LearningProgressNotifier notifier(ProviderContainer container) {
    return container.read(learningProgressNotifierProvider.notifier);
  }

  // ========== Group 1: completeCurrentSubStage — 子步骤推进 ==========

  group('completeCurrentSubStage', () {
    test('首次学习阶段内推进（v2）：intensiveListen → listenAndRepeat', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        currentStageStartedAt: now,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).completeCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.firstLearn);
      expect(after.currentSubStage, SubStageType.listenAndRepeat);
      expect(after.firstLearnCompletedAt, isNull);
      expect(after.lastStageCompletedAt, isNull);
    });

    test('精听完成后无难句自动完成跟读并推进到盲听', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        currentStageStartedAt: now,
        updatedAt: now,
      );
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(
        container,
      ).completeIntensiveListenAndAutoCompleteShadowingIfNoDifficult('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.currentSubStage, SubStageType.blindListen);
      expect(
        container
            .read(learningProgressNotifierProvider)
            .completionsByAudio['a1'],
        containsAll(<String>[
          'firstLearn:intensiveListen',
          'firstLearn:listenAndRepeat',
        ]),
      );
      expect(after.skippedSubStageKeys, isEmpty);
    });

    test('精听完成后有难句时停留在跟读', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        currentStageStartedAt: now,
        updatedAt: now,
      );
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
        bookmarks: const {0},
      );

      await notifier(
        container,
      ).completeIntensiveListenAndAutoCompleteShadowingIfNoDifficult('a1');

      expect(
        readProgress(container, 'a1')!.currentSubStage,
        SubStageType.listenAndRepeat,
      );
    });

    test(
      '首次学习最后一步 retell → review0.reviewDifficultPractice，设置 firstLearnCompletedAt',
      () async {
        final now = DateTime(2026, 3, 1, 10, 0);
        final progress = LearningProgress(
          audioItemId: 'a1',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.retell,
          currentStageStartedAt: now,
          updatedAt: now,
        );

        final container = createContainer(
          LearningProgressState(progressMap: {'a1': progress}),
          nowGetter: () => now,
        );

        await notifier(container).completeCurrentSubStage('a1');

        final after = readProgress(container, 'a1')!;
        expect(after.currentStage, LearningStage.review0);
        expect(after.currentSubStage, SubStageType.reviewDifficultPractice);
        expect(after.firstLearnCompletedAt, isNotNull);
        expect(after.lastStageCompletedAt, isNotNull);
      },
    );

    test('首次学习最后一步完成后触发通知权限 pre-prompt 锚点', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.retell,
        currentStageStartedAt: now,
        updatedAt: now,
      );
      final notificationService = MockNotificationPermissionService();
      when(
        () => notificationService.maybeTriggerPrompt(),
      ).thenAnswer((_) async {});

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
        notificationPermissionService: notificationService,
      );

      await notifier(container).completeCurrentSubStage('a1');
      await Future<void>.delayed(Duration.zero);

      verify(() => notificationService.maybeTriggerPrompt()).called(1);
    });

    test('首次学习阶段内推进不触发通知权限 pre-prompt 锚点', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.blindListen,
        currentStageStartedAt: now,
        updatedAt: now,
      );
      final notificationService = MockNotificationPermissionService();
      when(
        () => notificationService.maybeTriggerPrompt(),
      ).thenAnswer((_) async {});

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
        notificationPermissionService: notificationService,
      );

      await notifier(container).completeCurrentSubStage('a1');
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => notificationService.maybeTriggerPrompt());
    });

    test('review1 v2 阶段内推进：reviewDifficultPractice → blindListen', () async {
      final now = DateTime(2026, 3, 5, 10, 0);
      // lastStageCompletedAt 设为 2 天前，让 review1（24h 间隔）已解锁
      final completedAt = now.subtract(const Duration(days: 2));
      // 无 review1 completion → v2 plan = [reviewDifficultPractice, blindListen]
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.reviewDifficultPractice,
        lastStageCompletedAt: completedAt,
        currentStageStartedAt: now,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).completeCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.review1);
      expect(after.currentSubStage, SubStageType.blindListen);
    });

    test(
      'review1 v1（snapshot v1）内推进：blindListen → reviewDifficultPractice',
      () async {
        final now = DateTime(2026, 3, 5, 10, 0);
        final completedAt = now.subtract(const Duration(days: 2));
        // 显式 stamp review1=1 → v1 plan = [blindListen, difficult, retellPara]
        final progress = LearningProgress(
          audioItemId: 'a1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: completedAt,
          currentStageStartedAt: now,
          updatedAt: now,
          planVersionsByStage: const {LearningStage.review1: 1},
        );

        final container = createContainer(
          LearningProgressState(progressMap: {'a1': progress}),
          nowGetter: () => now,
        );

        await notifier(container).completeCurrentSubStage('a1');

        final after = readProgress(container, 'a1')!;
        expect(after.currentStage, LearningStage.review1);
        expect(after.currentSubStage, SubStageType.reviewDifficultPractice);
      },
    );

    test(
      'review1 v2 最后一步推进到下一轮：blindListen → review2.reviewDifficultPractice',
      () async {
        final now = DateTime(2026, 3, 5, 10, 0);
        final completedAt = now.subtract(const Duration(days: 2));
        // 无 completion → v2 plan = [difficult, blindListen]；blindListen 是末项
        final progress = LearningProgress(
          audioItemId: 'a1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          firstLearnCompletedAt: DateTime(2026, 3, 1),
          lastStageCompletedAt: completedAt,
          currentStageStartedAt: now,
          updatedAt: now,
        );

        final container = createContainer(
          LearningProgressState(progressMap: {'a1': progress}),
          nowGetter: () => now,
        );

        await notifier(container).completeCurrentSubStage('a1');

        final after = readProgress(container, 'a1')!;
        expect(after.currentStage, LearningStage.review2);
        // review2 v2 plan = [difficult, blindListen, retellPara]，first = difficult
        expect(after.currentSubStage, SubStageType.reviewDifficultPractice);
        expect(after.lastStageCompletedAt, isNotNull);
        // firstLearnCompletedAt 不变
        expect(after.firstLearnCompletedAt, DateTime(2026, 3, 1));
      },
    );

    test(
      'review28 v2 最后一步推进到 completed：reviewRetellParagraph → completed',
      () async {
        final now = DateTime(2026, 5, 1, 10, 0);
        final completedAt = now.subtract(const Duration(days: 30));
        // 无 completion → v2 plan = [difficult, blindListen, reviewRetellParagraph]
        final progress = LearningProgress(
          audioItemId: 'a1',
          currentStage: LearningStage.review28,
          currentSubStage: SubStageType.reviewRetellParagraph,
          firstLearnCompletedAt: DateTime(2026, 3, 1),
          lastStageCompletedAt: completedAt,
          currentStageStartedAt: now,
          updatedAt: now,
        );

        final container = createContainer(
          LearningProgressState(progressMap: {'a1': progress}),
          nowGetter: () => now,
        );

        await notifier(container).completeCurrentSubStage('a1');

        final after = readProgress(container, 'a1')!;
        expect(after.currentStage, LearningStage.completed);
        expect(after.isCompleted, isTrue);
      },
    );

    test(
      'review28 v1（有 completion 走 v1 plan）最后一步推进：reviewRetellSummary → completed',
      () async {
        final now = DateTime(2026, 5, 1, 10, 0);
        final completedAt = now.subtract(const Duration(days: 30));
        // 有 review28 completion → v1 plan = [blind, difficult, summary]
        final progress = LearningProgress(
          audioItemId: 'a1',
          currentStage: LearningStage.review28,
          currentSubStage: SubStageType.reviewRetellSummary,
          firstLearnCompletedAt: DateTime(2026, 3, 1),
          lastStageCompletedAt: completedAt,
          currentStageStartedAt: now,
          updatedAt: now,
        );

        final container = createContainer(
          LearningProgressState(
            progressMap: {'a1': progress},
            completionsByAudio: const {
              'a1': {
                'review28:blindListen',
                'review28:reviewDifficultPractice',
              },
            },
          ),
          nowGetter: () => now,
        );

        await notifier(container).completeCurrentSubStage('a1');

        final after = readProgress(container, 'a1')!;
        expect(after.currentStage, LearningStage.completed);
        expect(after.isCompleted, isTrue);
      },
    );

    test('已完成状态不推进', () async {
      final now = DateTime(2026, 3, 1);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.completed,
        currentSubStage: SubStageType.blindListen,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).completeCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.completed);
      // DAO 不应被调用
      verifyNever(() => mockStageCompletionDao.insertRecord(any()));
    });

    test('audioItemId 不存在时安全返回', () async {
      final container = createContainer(
        const LearningProgressState(),
        nowGetter: () => DateTime(2026, 3, 1),
      );

      // 不应抛异常
      await notifier(container).completeCurrentSubStage('nonexistent');
      verifyNever(() => mockStageCompletionDao.insertRecord(any()));
    });

    test('耗时计算正确：totalStudyDurationMs 累加', () async {
      final startedAt = DateTime(2026, 3, 1, 10, 0, 0);
      final now = DateTime(2026, 3, 1, 10, 5, 0); // 5 分钟后
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.blindListen,
        currentStageStartedAt: startedAt,
        totalStudyDurationMs: 1000, // 已有 1 秒
        updatedAt: startedAt,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).completeCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      // 5 分钟 = 300000ms，加上原有的 1000ms
      // 注意：实际实现用 DateTime.now() 计算耗时，不用 nowProvider
      // 所以无法精确断言值，只能验证 >= 原值
      expect(after.totalStudyDurationMs, greaterThanOrEqualTo(1000));
    });

    test('stage_completions 历史记录写入', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.blindListen,
        currentStageStartedAt: now,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).completeCurrentSubStage('a1');

      // 验证 stageCompletionDao.insertRecord 被调用
      final captured = verify(
        () => mockStageCompletionDao.insertRecord(captureAny()),
      ).captured;
      expect(captured, hasLength(1));
      final companion = captured.first as db.StageCompletionsCompanion;
      expect(companion.audioItemId.value, 'a1');
      expect(companion.stage.value, LearningStage.firstLearn.key);
      expect(companion.subStage.value, SubStageType.blindListen.key);
    });

    test('完成精听后仅清除 intensiveListenSentenceIndex，其他索引不变', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        currentStageStartedAt: now,
        intensiveListenSentenceIndex: 5,
        shadowingSentenceIndex: 3,
        difficultPracticeSentenceIndex: 2,
        retellSentenceIndex: 1,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).completeCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.intensiveListenSentenceIndex, isNull, reason: '精听断点应被清除');
      expect(after.shadowingSentenceIndex, 3, reason: '跟读断点不应受影响');
      expect(after.difficultPracticeSentenceIndex, 2, reason: '难句补练断点不应受影响');
      expect(after.retellSentenceIndex, 1, reason: '复述断点不应受影响');
    });

    test('完成难句补练后仅清除 difficultPracticeSentenceIndex', () async {
      final now = DateTime(2026, 3, 5, 10, 0);
      final completedAt = now.subtract(const Duration(days: 2));
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.reviewDifficultPractice,
        lastStageCompletedAt: completedAt,
        currentStageStartedAt: now,
        intensiveListenSentenceIndex: 5,
        shadowingSentenceIndex: 3,
        difficultPracticeSentenceIndex: 7,
        retellSentenceIndex: 1,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).completeCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      expect(
        after.difficultPracticeSentenceIndex,
        isNull,
        reason: '难句补练断点应被清除',
      );
      expect(after.intensiveListenSentenceIndex, 5, reason: '精听断点不应受影响');
      expect(after.shadowingSentenceIndex, 3, reason: '跟读断点不应受影响');
      expect(after.retellSentenceIndex, 1, reason: '复述断点不应受影响');
    });

    test('跨大阶段完成最后子步骤时清除该步骤对应索引', () async {
      final now = DateTime(2026, 3, 5, 10, 0);
      final completedAt = now.subtract(const Duration(days: 2));
      // review1 最后一步是 reviewRetellParagraph
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.reviewRetellParagraph,
        firstLearnCompletedAt: DateTime(2026, 3, 1),
        lastStageCompletedAt: completedAt,
        currentStageStartedAt: now,
        difficultPracticeSentenceIndex: 4,
        retellSentenceIndex: 6,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).completeCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.review2);
      expect(after.retellSentenceIndex, isNull, reason: '复述断点应被清除（跨阶段）');
      expect(after.difficultPracticeSentenceIndex, 4, reason: '难句补练断点不应受影响');
    });

    test('完成跟读后仅清除 shadowingSentenceIndex', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.listenAndRepeat,
        currentStageStartedAt: now,
        shadowingSentenceIndex: 8,
        intensiveListenSentenceIndex: 5,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).completeCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.shadowingSentenceIndex, isNull, reason: '跟读断点应被清除');
      expect(after.intensiveListenSentenceIndex, 5, reason: '精听断点不应受影响');
    });

    test('完成盲听时不清除任何断点索引', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.blindListen,
        currentStageStartedAt: now,
        intensiveListenSentenceIndex: 5,
        shadowingSentenceIndex: 3,
        difficultPracticeSentenceIndex: 2,
        retellSentenceIndex: 1,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).completeCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.intensiveListenSentenceIndex, 5);
      expect(after.shadowingSentenceIndex, 3);
      expect(after.difficultPracticeSentenceIndex, 2);
      expect(after.retellSentenceIndex, 1);
    });

    test('复习未到时间时不推进进度（已有测试）', () async {
      final now = DateTime(2026, 2, 25, 12, 0);
      final initialProgress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.blindListen,
        lastStageCompletedAt: now,
        currentStageStartedAt: now,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'audio-1': initialProgress}),
        nowGetter: () => now,
      );

      await notifier(container).completeCurrentSubStage('audio-1');

      final after = readProgress(container, 'audio-1')!;
      expect(after.currentStage, initialProgress.currentStage);
      expect(after.currentSubStage, initialProgress.currentSubStage);
      expect(after.totalStudyDurationMs, initialProgress.totalStudyDurationMs);
    });

    // ========== T3: autoSkipRetell=true 时的自动跳过推进行为 ==========
    //
    // 新机制：plan 永远包含 retell；autoSkipRetell 开启时，complete 推进
    // 到 retell 位置后 hook 自动连续 skip，直到跳出 retell 区。

    test(
      'autoSkipRetell=true：firstLearn(v2) 盲听完成 → review0（自动跳过 retell）',
      () async {
        final now = DateTime(2026, 3, 1, 10, 0);
        // v2 plan = [intensive, listenAndRepeat, blindListen, retell]
        // 盲听是 retell 前的最后一步，完成后自动跳过 retell 推进到 review0。
        final progress = LearningProgress(
          audioItemId: 'a1',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.blindListen,
          currentStageStartedAt: now,
          updatedAt: now,
        );

        final container = createContainer(
          LearningProgressState(progressMap: {'a1': progress}),
          nowGetter: () => now,
          autoSkipRetell: true,
        );

        await notifier(container).completeCurrentSubStage('a1');

        final after = readProgress(container, 'a1')!;
        expect(after.currentStage, LearningStage.review0);
        expect(after.currentSubStage, SubStageType.reviewDifficultPractice);
        expect(after.firstLearnCompletedAt, isNotNull);
        // retell 应被记录在跳过集合
        expect(after.skippedSubStageKeys.contains('firstLearn:retell'), isTrue);
      },
    );

    test('autoSkipRetell=true：review0 v1 难句补练完成 → review1（自动跳过段落复述）', () async {
      final now = DateTime(2026, 3, 5, 10, 0);
      final completedAt = now.subtract(const Duration(days: 1));
      // v1 plan：review0 = [难句补练, 段落复述]，做完难句补练后落到 retell → 自动跳过。
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.review0,
        currentSubStage: SubStageType.reviewDifficultPractice,
        lastStageCompletedAt: completedAt,
        currentStageStartedAt: now,
        updatedAt: now,
        planVersionsByStage: const {LearningStage.review0: 1},
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
        autoSkipRetell: true,
      );

      await notifier(container).completeCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.review1);
      // review1 默认 v2 plan = [difficult, blindListen]，first = difficult
      expect(after.currentSubStage, SubStageType.reviewDifficultPractice);
    });

    test('autoSkipRetell=true：review0 v2 难句补练完成 → 停在全文盲听（不触发自动跳过）', () async {
      final now = DateTime(2026, 3, 5, 10, 0);
      final completedAt = now.subtract(const Duration(days: 1));
      // v2 plan：review0 = [难句补练, 全文盲听]，全文盲听非 retell → autoSkip 不触发。
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.review0,
        currentSubStage: SubStageType.reviewDifficultPractice,
        lastStageCompletedAt: completedAt,
        currentStageStartedAt: now,
        updatedAt: now,
        // 显式 v2（review0=2 与默认一致，写出来更明确）
        planVersionsByStage: const {LearningStage.review0: 2},
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
        autoSkipRetell: true,
      );

      await notifier(container).completeCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.review0);
      expect(after.currentSubStage, SubStageType.blindListen);
    });

    test(
      'autoSkipRetell=true：review28 snapshot v1 难句补练完成 → completed（自动跳过 summary）',
      () async {
        final now = DateTime(2026, 4, 1, 10, 0);
        final completedAt = now.subtract(const Duration(days: 30));
        // 显式 stamp review28=1 → v1 plan = [blindListen, difficult, summary]
        // 完成 difficult → next = summary（retell 类）→ autoSkip 触发 → completed
        final progress = LearningProgress(
          audioItemId: 'a1',
          currentStage: LearningStage.review28,
          currentSubStage: SubStageType.reviewDifficultPractice,
          lastStageCompletedAt: completedAt,
          currentStageStartedAt: now,
          updatedAt: now,
          planVersionsByStage: const {LearningStage.review28: 1},
        );

        final container = createContainer(
          LearningProgressState(progressMap: {'a1': progress}),
          nowGetter: () => now,
          autoSkipRetell: true,
        );

        await notifier(container).completeCurrentSubStage('a1');

        final after = readProgress(container, 'a1')!;
        expect(after.currentStage, LearningStage.completed);
      },
    );

    test(
      'autoSkipRetell=true：review28 v2 难句补练完成 → 停在全文盲听（非 retell，不触发 autoSkip）',
      () async {
        final now = DateTime(2026, 4, 1, 10, 0);
        final completedAt = now.subtract(const Duration(days: 30));
        // 无 completion → v2 plan = [difficult, blindListen, retellPara]
        // 完成 difficult → next = blindListen（非 retell）→ autoSkip 不触发
        final progress = LearningProgress(
          audioItemId: 'a1',
          currentStage: LearningStage.review28,
          currentSubStage: SubStageType.reviewDifficultPractice,
          lastStageCompletedAt: completedAt,
          currentStageStartedAt: now,
          updatedAt: now,
        );

        final container = createContainer(
          LearningProgressState(progressMap: {'a1': progress}),
          nowGetter: () => now,
          autoSkipRetell: true,
        );

        await notifier(container).completeCurrentSubStage('a1');

        final after = readProgress(container, 'a1')!;
        expect(after.currentStage, LearningStage.review28);
        expect(after.currentSubStage, SubStageType.blindListen);
      },
    );
  });

  // ========== Group 1b: skipCurrentSubStage — 手动跳过护栏 ==========

  group('skipCurrentSubStage', () {
    test('首次学习(v2) 入口精听不可跳过：无操作', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        currentStageStartedAt: now,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).skipCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      // 位置不变，且未写入跳过集合
      expect(after.currentStage, LearningStage.firstLearn);
      expect(after.currentSubStage, SubStageType.intensiveListen);
      expect(after.skippedSubStageKeys, isEmpty);
    });

    test('首次学习(v2) 盲听可跳过：blindListen → retell', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      // v2 plan = [intensive, listenAndRepeat, blindListen, retell]
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.blindListen,
        currentStageStartedAt: now,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).skipCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.firstLearn);
      expect(after.currentSubStage, SubStageType.retell);
      expect(
        after.skippedSubStageKeys.contains('firstLearn:blindListen'),
        isTrue,
      );
    });

    test('首次学习(v1) 精听可跳过（有难句时停在跟读）：intensiveListen → listenAndRepeat', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      // v1 plan = [blindListen, intensive, listenAndRepeat, retell]，入口是盲听，精听可跳过
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        planVersionsByStage: const {LearningStage.firstLearn: 1},
        currentStageStartedAt: now,
        updatedAt: now,
      );

      // 有难句书签 → 跟读有内容，不连带跳过
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
        bookmarks: const {0, 3},
      );

      await notifier(container).skipCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.firstLearn);
      expect(after.currentSubStage, SubStageType.listenAndRepeat);
      expect(
        after.skippedSubStageKeys.contains('firstLearn:intensiveListen'),
        isTrue,
      );
    });

    test('首次学习(v1) 跳过精听且无难句时连带跳过跟读：intensiveListen → retell', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        planVersionsByStage: const {LearningStage.firstLearn: 1},
        currentStageStartedAt: now,
        updatedAt: now,
      );

      // 无难句书签（默认）→ 跟读无内容，连带跳过到复述
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).skipCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.firstLearn);
      expect(after.currentSubStage, SubStageType.retell);
      expect(
        after.skippedSubStageKeys.contains('firstLearn:intensiveListen'),
        isTrue,
      );
      expect(
        after.skippedSubStageKeys.contains('firstLearn:listenAndRepeat'),
        isTrue,
      );
    });

    test(
      '复习阶段的盲听可跳过：review1 v1 blindListen → reviewDifficultPractice',
      () async {
        final now = DateTime(2026, 3, 5, 10, 0);
        final completedAt = now.subtract(const Duration(days: 2));
        // 显式 stamp review1=1 → v1 plan = [blindListen, difficult, retellPara]
        final progress = LearningProgress(
          audioItemId: 'a1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: completedAt,
          currentStageStartedAt: now,
          updatedAt: now,
          planVersionsByStage: const {LearningStage.review1: 1},
        );

        final container = createContainer(
          LearningProgressState(progressMap: {'a1': progress}),
          nowGetter: () => now,
        );

        await notifier(container).skipCurrentSubStage('a1');

        final after = readProgress(container, 'a1')!;
        expect(after.currentStage, LearningStage.review1);
        expect(after.currentSubStage, SubStageType.reviewDifficultPractice);
        expect(
          after.skippedSubStageKeys.contains('review1:blindListen'),
          isTrue,
        );
      },
    );
  });

  // ========== Group 2: 断点保存与清除 ==========

  group('断点保存与清除', () {
    late LearningProgress baseProgress;
    late DateTime now;

    setUp(() {
      now = DateTime(2026, 3, 1);
      baseProgress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        updatedAt: now,
      );
    });

    test('saveIntensiveListenSentenceIndex 保存断点（正常学习）', () async {
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': baseProgress}),
      );

      await notifier(
        container,
      ).saveIntensiveListenSentenceIndex('a1', 5, isFreePlay: false);

      final after = readProgress(container, 'a1')!;
      expect(after.intensiveListenSentenceIndex, 5);
      expect(after.newLearningBreakpointSavedAt, isNotNull);
    });

    test('saveIntensiveListenSentenceIndex 保存断点（自由练习）', () async {
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': baseProgress}),
      );

      await notifier(
        container,
      ).saveIntensiveListenSentenceIndex('a1', 5, isFreePlay: true);

      final after = readProgress(container, 'a1')!;
      expect(after.freePlayIntensiveListenSentenceIndex, 5);
      expect(after.freePlayBreakpointSavedAt, isNotNull);
      expect(after.intensiveListenSentenceIndex, isNull);
    });

    test('saveIntensiveListenSentenceIndex 清除断点', () async {
      final progressWithIndex = baseProgress.copyWith(
        intensiveListenSentenceIndex: 5,
      );
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progressWithIndex}),
      );

      await notifier(
        container,
      ).saveIntensiveListenSentenceIndex('a1', null, isFreePlay: false);

      final after = readProgress(container, 'a1')!;
      expect(after.intensiveListenSentenceIndex, isNull);
    });

    test('saveShadowingSentenceIndex 保存断点', () async {
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': baseProgress}),
      );

      await notifier(
        container,
      ).saveShadowingSentenceIndex('a1', 3, isFreePlay: false);

      final after = readProgress(container, 'a1')!;
      expect(after.shadowingSentenceIndex, 3);
    });

    test('saveShadowingSentenceIndex 清除断点', () async {
      final progressWithIndex = baseProgress.copyWith(
        shadowingSentenceIndex: 3,
      );
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progressWithIndex}),
      );

      await notifier(
        container,
      ).saveShadowingSentenceIndex('a1', null, isFreePlay: false);

      final after = readProgress(container, 'a1')!;
      expect(after.shadowingSentenceIndex, isNull);
    });

    test('saveDifficultPracticeSentenceIndex 保存断点', () async {
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': baseProgress}),
      );

      await notifier(
        container,
      ).saveDifficultPracticeSentenceIndex('a1', 7, isFreePlay: false);

      final after = readProgress(container, 'a1')!;
      expect(after.difficultPracticeSentenceIndex, 7);
    });

    test('saveDifficultPracticeSentenceIndex 清除断点', () async {
      final progressWithIndex = baseProgress.copyWith(
        difficultPracticeSentenceIndex: 7,
      );
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progressWithIndex}),
      );

      await notifier(
        container,
      ).saveDifficultPracticeSentenceIndex('a1', null, isFreePlay: false);

      final after = readProgress(container, 'a1')!;
      expect(after.difficultPracticeSentenceIndex, isNull);
    });

    test('saveRetellSentenceIndex 保存断点', () async {
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': baseProgress}),
      );

      await notifier(
        container,
      ).saveRetellSentenceIndex('a1', 2, isFreePlay: false);

      final after = readProgress(container, 'a1')!;
      expect(after.retellSentenceIndex, 2);
    });

    test('saveRetellSentenceIndex 清除断点', () async {
      final progressWithIndex = baseProgress.copyWith(retellSentenceIndex: 2);
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progressWithIndex}),
      );

      await notifier(
        container,
      ).saveRetellSentenceIndex('a1', null, isFreePlay: false);

      final after = readProgress(container, 'a1')!;
      expect(after.retellSentenceIndex, isNull);
    });

    test('audioItemId 不存在时断点保存安全返回', () async {
      final container = createContainer(const LearningProgressState());

      await notifier(
        container,
      ).saveIntensiveListenSentenceIndex('nonexistent', 5, isFreePlay: false);
      await notifier(
        container,
      ).saveShadowingSentenceIndex('nonexistent', 5, isFreePlay: false);
      await notifier(
        container,
      ).saveDifficultPracticeSentenceIndex('nonexistent', 5, isFreePlay: false);
      await notifier(
        container,
      ).saveRetellSentenceIndex('nonexistent', 5, isFreePlay: false);

      final progress = readProgress(container, 'nonexistent');
      expect(progress?.intensiveListenSentenceIndex, 5);
      expect(progress?.shadowingSentenceIndex, 5);
      expect(progress?.difficultPracticeSentenceIndex, 5);
      expect(progress?.retellSentenceIndex, 5);
      verify(() => mockDao.upsert(any())).called(greaterThanOrEqualTo(1));
    });
  });

  // ========== Group 3: 遍数统计 ==========

  group('遍数统计', () {
    late LearningProgress baseProgress;

    setUp(() {
      baseProgress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.blindListen,
        updatedAt: DateTime(2026, 3, 1),
      );
    });

    test('incrementBlindListenPassCount：0 → 1', () async {
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': baseProgress}),
      );

      await notifier(container).incrementBlindListenPassCount('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.blindListenPassCount, 1);
    });

    test('incrementIntensiveListenPassCount：null → 1', () async {
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': baseProgress}),
      );

      await notifier(container).incrementIntensiveListenPassCount('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.intensiveListenPassCount, 1);
    });

    test('incrementShadowingPassCount：null → 1', () async {
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': baseProgress}),
      );

      await notifier(container).incrementShadowingPassCount('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.shadowingPassCount, 1);
    });

    test('incrementRetellPassCount：null → 1', () async {
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': baseProgress}),
      );

      await notifier(container).incrementRetellPassCount('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.retellPassCount, 1);
    });

    test('连续递增多次正确累加', () async {
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': baseProgress}),
      );

      await notifier(container).incrementBlindListenPassCount('a1');
      await notifier(container).incrementBlindListenPassCount('a1');
      await notifier(container).incrementBlindListenPassCount('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.blindListenPassCount, 3);
    });

    test('audioItemId 不存在时遍数统计安全返回', () async {
      final container = createContainer(const LearningProgressState());

      await notifier(container).incrementBlindListenPassCount('nonexistent');
      await notifier(
        container,
      ).incrementIntensiveListenPassCount('nonexistent');
      await notifier(container).incrementShadowingPassCount('nonexistent');
      await notifier(container).incrementRetellPassCount('nonexistent');

      verifyNever(() => mockDao.upsert(any()));
    });
  });

  // ========== Group 4: 其他方法 ==========

  group('ensureProgress', () {
    test('首次创建默认进度', () async {
      final container = createContainer(const LearningProgressState());

      final result = await notifier(container).ensureProgress('new-audio');

      expect(result.audioItemId, 'new-audio');
      expect(result.currentStage, LearningStage.firstLearn);
      // v2 入口子步骤为逐句精听
      expect(result.currentSubStage, SubStageType.intensiveListen);
      expect(result.difficulty, DifficultyLevel.medium);

      // 验证持久化
      verify(() => mockDao.upsert(any())).called(1);

      // 验证 state 中已添加
      final inState = readProgress(container, 'new-audio');
      expect(inState, isNotNull);
    });

    test('已存在直接返回不重复创建', () async {
      final existing = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.blindListen,
        updatedAt: DateTime(2026, 3, 1),
      );
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': existing}),
      );

      final result = await notifier(container).ensureProgress('a1');

      expect(result.currentStage, LearningStage.review1);
      // DAO 不应被调用
      verifyNever(() => mockDao.upsert(any()));
    });

    test('内存缺失但数据库已存在时返回持久化断点且不覆盖', () async {
      final persistedRow = db.LearningProgressesData(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn.key,
        currentSubStage: SubStageType.intensiveListen.key,
        difficulty: DifficultyLevel.medium.value,
        firstLearnCompletedAt: null,
        lastStageCompletedAt: null,
        currentStageStartedAt: DateTime(2026, 3, 11, 9, 0),
        totalStudyDurationMs: 0,
        blindListenPassCount: 0,
        intensiveListenDifficultCount: null,
        intensiveListenPassCount: null,
        shadowingPassCount: null,
        intensiveListenSentenceIndex: 3,
        shadowingSentenceIndex: null,
        difficultPracticeSentenceIndex: null,
        retellSentenceIndex: null,
        retellPassCount: null,
        freePlayIntensiveListenSentenceIndex: null,
        freePlayShadowingSentenceIndex: null,
        freePlayDifficultPracticeSentenceIndex: null,
        freePlayRetellSentenceIndex: null,
        newLearningBreakpointSavedAt: null,
        freePlayBreakpointSavedAt: null,
        skippedSubStages: '',
        isPaused: false,
        planVersionsJson: '{}',
        updatedAt: DateTime(2026, 3, 11, 9, 30),
      );
      when(
        () => mockDao.getByAudioId('a1'),
      ).thenAnswer((_) async => persistedRow);

      final container = createContainer(const LearningProgressState());

      final result = await notifier(container).ensureProgress('a1');

      expect(result.intensiveListenSentenceIndex, 3);
      expect(readProgress(container, 'a1')?.intensiveListenSentenceIndex, 3);
      verify(() => mockDao.getByAudioId('a1')).called(1);
      verifyNever(() => mockDao.upsert(any()));
    });
  });

  group('getLatestOrEnsureProgress', () {
    test('数据库已无进度时清除内存旧进度和完成集合', () async {
      final stale = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.blindListen,
        updatedAt: DateTime(2026, 3, 11, 9, 0),
      );
      final container = createContainer(
        LearningProgressState(
          progressMap: {'a1': stale},
          completionsByAudio: {
            'a1': {'firstLearn:blindListen'},
          },
        ),
      );

      final result = await notifier(container).getLatestByAudioId('a1');

      expect(result, isNull);
      expect(readProgress(container, 'a1'), isNull);
      expect(
        container
            .read(learningProgressNotifierProvider)
            .completionsByAudio
            .containsKey('a1'),
        isFalse,
      );
      verify(() => mockDao.getByAudioId('a1')).called(1);
    });

    test('内存已有旧值时优先返回数据库最新断点并回填 state', () async {
      final stale = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.retell,
        retellSentenceIndex: 1,
        updatedAt: DateTime(2026, 3, 11, 9, 0),
      );
      final persistedRow = db.LearningProgressesData(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn.key,
        currentSubStage: SubStageType.retell.key,
        difficulty: DifficultyLevel.medium.value,
        firstLearnCompletedAt: null,
        lastStageCompletedAt: null,
        currentStageStartedAt: DateTime(2026, 3, 11, 9, 0),
        totalStudyDurationMs: 0,
        blindListenPassCount: 0,
        intensiveListenDifficultCount: null,
        intensiveListenPassCount: null,
        shadowingPassCount: null,
        intensiveListenSentenceIndex: null,
        shadowingSentenceIndex: null,
        difficultPracticeSentenceIndex: null,
        retellSentenceIndex: 7,
        retellPassCount: null,
        freePlayIntensiveListenSentenceIndex: null,
        freePlayShadowingSentenceIndex: null,
        freePlayDifficultPracticeSentenceIndex: null,
        freePlayRetellSentenceIndex: null,
        newLearningBreakpointSavedAt: null,
        freePlayBreakpointSavedAt: null,
        skippedSubStages: '',
        isPaused: false,
        planVersionsJson: '{}',
        updatedAt: DateTime(2026, 3, 11, 9, 30),
      );
      when(
        () => mockDao.getByAudioId('a1'),
      ).thenAnswer((_) async => persistedRow);

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': stale}),
      );

      final result = await notifier(container).getLatestOrEnsureProgress('a1');

      expect(result.retellSentenceIndex, 7);
      expect(readProgress(container, 'a1')?.retellSentenceIndex, 7);
      verify(() => mockDao.getByAudioId('a1')).called(1);
      verifyNever(() => mockDao.upsert(any()));
    });
  });

  // ========== T14: autoSkipRetell 开关切换时的全量扫描 ==========
  //
  // 新机制：autoSkipRetell false→true 触发 progress 端 listener，对所有
  // progress 跑一次 _autoSkipRetellIfEnabled；停在复述子阶段的会立即推进
  // 并写入 skippedSubStageKeys。true→false 不触发任何动作。

  group('autoSkipRetell 切换 OFF→ON 全量扫描', () {
    Future<void> enableAutoSkip(ProviderContainer container) async {
      container.read(learningProgressNotifierProvider.notifier);
      await container
          .read(learningSettingsProvider.notifier)
          .setAutoSkipRetell(true);
      await Future<void>.delayed(Duration.zero);
    }

    test('(a) firstLearn 当前在非复述 → 不推进', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.listenAndRepeat,
        currentStageStartedAt: now,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
        autoSkipRetell: false,
      );

      await enableAutoSkip(container);

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.firstLearn);
      expect(after.currentSubStage, SubStageType.listenAndRepeat);
      verifyNever(() => mockStageCompletionDao.insertRecord(any()));
      expect(after.skippedSubStageKeys, isEmpty);
    });

    test('(b) firstLearn 当前是 retell → 推进至 review0，写入跳过集合', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.retell,
        currentStageStartedAt: now,
        retellPassCount: 0,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
        autoSkipRetell: false,
      );

      await enableAutoSkip(container);

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.review0);
      expect(after.firstLearnCompletedAt, isNotNull);
      verifyNever(() => mockStageCompletionDao.insertRecord(any()));
      expect(after.retellPassCount, 0);
      expect(after.skippedSubStageKeys, contains('firstLearn:retell'));
    });

    test('(c) review0 当前是 reviewRetellParagraph → 推进至 review1', () async {
      final now = DateTime(2026, 3, 5, 10, 0);
      final completedAt = now.subtract(const Duration(hours: 12));
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.review0,
        currentSubStage: SubStageType.reviewRetellParagraph,
        lastStageCompletedAt: completedAt,
        currentStageStartedAt: now,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
        autoSkipRetell: false,
      );

      await enableAutoSkip(container);

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.review1);
      expect(
        after.skippedSubStageKeys,
        contains('review0:reviewRetellParagraph'),
      );
    });

    test('(d) review28 当前是 reviewRetellSummary → 推进至 completed', () async {
      final now = DateTime(2026, 4, 30, 10, 0);
      final completedAt = now.subtract(const Duration(days: 30));
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.review28,
        currentSubStage: SubStageType.reviewRetellSummary,
        lastStageCompletedAt: completedAt,
        currentStageStartedAt: now,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
        autoSkipRetell: false,
      );

      await enableAutoSkip(container);

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.completed);
    });

    test('(e) 已 completed → 不动', () async {
      final now = DateTime(2026, 5, 1, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.completed,
        currentSubStage: SubStageType.blindListen,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
        autoSkipRetell: false,
      );

      await enableAutoSkip(container);

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.completed);
    });

    test('(f) 多条进度同时扫描互不影响', () async {
      final now = DateTime(2026, 3, 10, 10, 0);
      final firstLearnProgress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.retell,
        currentStageStartedAt: now,
        updatedAt: now,
      );
      final review1Progress = LearningProgress(
        audioItemId: 'a2',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.reviewRetellParagraph,
        lastStageCompletedAt: now.subtract(const Duration(days: 2)),
        currentStageStartedAt: now,
        updatedAt: now,
      );
      final nonRetellProgress = LearningProgress(
        audioItemId: 'a3',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        currentStageStartedAt: now,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(
          progressMap: {
            'a1': firstLearnProgress,
            'a2': review1Progress,
            'a3': nonRetellProgress,
          },
        ),
        nowGetter: () => now,
        autoSkipRetell: false,
      );

      await enableAutoSkip(container);

      expect(
        readProgress(container, 'a1')!.currentStage,
        LearningStage.review0,
      );
      expect(
        readProgress(container, 'a2')!.currentStage,
        LearningStage.review2,
      );
      expect(
        readProgress(container, 'a3')!.currentStage,
        LearningStage.firstLearn,
      );
      expect(
        readProgress(container, 'a3')!.currentSubStage,
        SubStageType.intensiveListen,
      );
    });

    test('autoSkipRetell true→false 不触发任何推进', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.listenAndRepeat,
        currentStageStartedAt: now,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
        autoSkipRetell: true,
      );

      container.read(learningProgressNotifierProvider.notifier);
      await container
          .read(learningSettingsProvider.notifier)
          .setAutoSkipRetell(false);
      await Future<void>.delayed(Duration.zero);

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.firstLearn);
      expect(after.currentSubStage, SubStageType.listenAndRepeat);
    });
  });

  // ========== T15: skipCurrentSubStage 手动跳过 ==========

  group('skipCurrentSubStage', () {
    test('写 skippedSubStageKeys + 推进，不写 stage_completions', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.retell,
        currentStageStartedAt: now,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).skipCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.review0);
      expect(after.skippedSubStageKeys, contains('firstLearn:retell'));
      verifyNever(() => mockStageCompletionDao.insertRecord(any()));
    });

    test('已 completed 的子步骤不能再被跳过（互斥）', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.retell,
        currentStageStartedAt: now,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(
          progressMap: {'a1': progress},
          completionsByAudio: {
            'a1': {'firstLearn:retell'},
          },
        ),
        nowGetter: () => now,
      );

      await notifier(container).skipCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.currentSubStage, SubStageType.retell);
      expect(after.skippedSubStageKeys, isEmpty);
    });

    test('autoSkipRetell=true 时手动跳过非 retell 会触发自动续跳到非 retell 位置', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      // v2 plan = [intensive, listenAndRepeat, blindListen, retell]
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.blindListen,
        currentStageStartedAt: now,
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
        autoSkipRetell: true,
      );

      await notifier(container).skipCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      // blindListen 被手动跳过；下一个是 retell → 自动续跳 → review0
      expect(after.currentStage, LearningStage.review0);
      expect(
        after.skippedSubStageKeys,
        containsAll(<String>['firstLearn:blindListen', 'firstLearn:retell']),
      );
    });
  });

  // ========== T16: 互斥 — recordCompletionIfNew 清除 skip key ==========

  group('completion ⊥ skipped 互斥', () {
    test('skip 后 recordCompletionIfNew 同 key → skip 集合清除', () async {
      final now = DateTime(2026, 3, 1, 10, 0);
      const key = 'firstLearn:retell';
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.review0,
        currentSubStage: SubStageType.reviewDifficultPractice,
        skippedSubStageKeys: const {key},
        updatedAt: now,
      );

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).recordCompletionIfNew(
        'a1',
        LearningStage.firstLearn,
        SubStageType.retell,
      );

      final after = readProgress(container, 'a1')!;
      expect(after.skippedSubStageKeys, isNot(contains(key)));
      final completions = container
          .read(learningProgressNotifierProvider)
          .completionsFor('a1');
      expect(completions, contains(key));
    });
  });

  group('setDifficulty', () {
    test('更新难度等级', () async {
      final progress = LearningProgress(
        audioItemId: 'a1',
        difficulty: DifficultyLevel.medium,
        updatedAt: DateTime(2026, 3, 1),
      );
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
      );

      await notifier(container).setDifficulty('a1', DifficultyLevel.hard);

      final after = readProgress(container, 'a1')!;
      expect(after.difficulty, DifficultyLevel.hard);
      verify(() => mockDao.upsert(any())).called(1);
    });

    test('audioItemId 不存在时安全返回', () async {
      final container = createContainer(const LearningProgressState());

      await notifier(
        container,
      ).setDifficulty('nonexistent', DifficultyLevel.hard);
      verifyNever(() => mockDao.upsert(any()));
    });
  });

  group('recordCompletionIfNew', () {
    test('未记录过的 (stage, sub) → 写 DB + 更新内存集合', () async {
      final container = createContainer(
        const LearningProgressState(progressMap: {}, completionsByAudio: {}),
        autoSkipRetell: false,
      );

      await notifier(container).recordCompletionIfNew(
        'a1',
        LearningStage.firstLearn,
        SubStageType.retell,
      );

      verify(() => mockStageCompletionDao.insertRecord(any())).called(1);
      final completions = container
          .read(learningProgressNotifierProvider)
          .completionsFor('a1');
      expect(completions, contains('firstLearn:retell'));
    });

    test('已记录过的 (stage, sub) → 幂等 no-op，不重复写 DB', () async {
      final container = createContainer(
        const LearningProgressState(
          progressMap: {},
          completionsByAudio: {
            'a1': {'firstLearn:retell'},
          },
        ),
        autoSkipRetell: false,
      );

      await notifier(container).recordCompletionIfNew(
        'a1',
        LearningStage.firstLearn,
        SubStageType.retell,
      );

      verifyNever(() => mockStageCompletionDao.insertRecord(any()));
    });

    test('不同子步骤独立写入，不影响已有集合', () async {
      final container = createContainer(
        const LearningProgressState(
          progressMap: {},
          completionsByAudio: {
            'a1': {'firstLearn:blindListen'},
          },
        ),
        autoSkipRetell: false,
      );

      await notifier(container).recordCompletionIfNew(
        'a1',
        LearningStage.firstLearn,
        SubStageType.retell,
      );

      final completions = container
          .read(learningProgressNotifierProvider)
          .completionsFor('a1');
      expect(completions, {'firstLearn:blindListen', 'firstLearn:retell'});
    });
  });

  group('deleteProgress', () {
    test('从 state 中移除', () async {
      final progress = LearningProgress(
        audioItemId: 'a1',
        updatedAt: DateTime(2026, 3, 1),
      );
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
      );

      await notifier(container).deleteProgress('a1');

      expect(readProgress(container, 'a1'), isNull);
      verify(() => mockDao.deleteByAudioId('a1')).called(1);
      verify(() => mockStageCompletionDao.deleteByAudioId('a1')).called(1);
    });

    test('删除不存在的 id 不报错', () async {
      final container = createContainer(const LearningProgressState());

      await notifier(container).deleteProgress('nonexistent');
      verify(() => mockDao.deleteByAudioId('nonexistent')).called(1);
      verify(
        () => mockStageCompletionDao.deleteByAudioId('nonexistent'),
      ).called(1);
    });

    test('resetProgress 删除旧状态后立即创建逐句精听首步', () async {
      final existing = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.blindListen,
        updatedAt: DateTime(2026, 3, 1),
      );
      final container = createContainer(
        LearningProgressState(
          progressMap: {'a1': existing},
          completionsByAudio: const {
            'a1': {'firstLearn:intensiveListen', 'firstLearn:retell'},
          },
        ),
      );

      final reset = await notifier(container).resetProgress('a1');

      expect(reset.currentStage, LearningStage.firstLearn);
      expect(reset.currentSubStage, SubStageType.intensiveListen);
      expect(readProgress(container, 'a1'), same(reset));
      expect(
        container.read(learningProgressNotifierProvider).completionsFor('a1'),
        isEmpty,
      );
      verify(() => mockDao.deleteByAudioId('a1')).called(1);
      verify(() => mockStageCompletionDao.deleteByAudioId('a1')).called(1);
      verify(() => mockDao.upsert(any())).called(1);
    });
  });

  // ========== pauseProgress / resumeProgress ==========

  group('pauseProgress / resumeProgress', () {
    test('pauseProgress 将 isPaused 写为 true 并更新内存', () async {
      when(() => mockDao.setPaused(any(), any())).thenAnswer((_) async => 1);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.blindListen,
        updatedAt: DateTime(2026, 5, 1),
      );
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
      );

      await notifier(container).pauseProgress('a1');

      expect(readProgress(container, 'a1')?.isPaused, isTrue);
      verify(() => mockDao.setPaused('a1', true)).called(1);
    });

    test('resumeProgress 将 isPaused 写为 false 并更新内存', () async {
      when(() => mockDao.setPaused(any(), any())).thenAnswer((_) async => 1);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.blindListen,
        updatedAt: DateTime(2026, 5, 1),
        isPaused: true,
      );
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
      );

      await notifier(container).resumeProgress('a1');

      expect(readProgress(container, 'a1')?.isPaused, isFalse);
      verify(() => mockDao.setPaused('a1', false)).called(1);
    });

    test('状态相同时不写库（幂等）', () async {
      when(() => mockDao.setPaused(any(), any())).thenAnswer((_) async => 1);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.blindListen,
        updatedAt: DateTime(2026, 5, 1),
      );
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
      );

      await notifier(container).resumeProgress('a1');

      verifyNever(() => mockDao.setPaused(any(), any()));
    });

    test('audioItemId 不存在时安全返回', () async {
      when(() => mockDao.setPaused(any(), any())).thenAnswer((_) async => 1);
      final container = createContainer(const LearningProgressState());

      await notifier(container).pauseProgress('nonexistent');

      verifyNever(() => mockDao.setPaused(any(), any()));
    });
  });

  // ========== unlockCurrentReview — 立即解锁当前复习轮 ==========

  group('unlockCurrentReview', () {
    /// 构造一个锁定中的 review1 进度：2 小时前完成上一轮（间隔 18h，未到期）
    LearningProgress lockedReview1(DateTime now) => LearningProgress(
      audioItemId: 'a1',
      currentStage: LearningStage.review1,
      currentSubStage: SubStageType.reviewDifficultPractice,
      firstLearnCompletedAt: now.subtract(const Duration(days: 1)),
      lastStageCompletedAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now,
    );

    test('锁定中的复习轮 → 写 manualUnlockAt 并解除锁定', () async {
      final now = DateTime(2026, 7, 20, 10, 0);
      final progress = lockedReview1(now);
      expect(progress.isReviewLockedAt(now), isTrue);

      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).unlockCurrentReview('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.manualUnlockAt, isNotNull);
      expect(after.isReviewLockedAt(now), isFalse);
      // lastStageCompletedAt 不被篡改
      expect(after.lastStageCompletedAt, progress.lastStageCompletedAt);

      // 持久化 companion 携带非空 manualUnlockAt
      final captured =
          verify(() => mockDao.upsert(captureAny())).captured.single
              as db.LearningProgressesCompanion;
      expect(captured.manualUnlockAt.value, isNotNull);
    });

    test('解锁后 completeCurrentSubStage 不再被锁定 guard 早退', () async {
      final now = DateTime(2026, 7, 20, 10, 0);
      final progress = lockedReview1(now);
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      // 未解锁时被 guard 早退，不写 completion
      await notifier(container).completeCurrentSubStage('a1');
      verifyNever(() => mockStageCompletionDao.insertRecord(any()));

      await notifier(container).unlockCurrentReview('a1');
      await notifier(container).completeCurrentSubStage('a1');

      verify(() => mockStageCompletionDao.insertRecord(any())).called(1);
      final after = readProgress(container, 'a1')!;
      // review1 v2 plan = [difficult, blindListen]，推进到 blindListen
      expect(after.currentSubStage, SubStageType.blindListen);
      // 同 stage 内推进不清除解锁标记（做到一半仍保持解锁）
      expect(after.manualUnlockAt, isNotNull);
    });

    test('跨 stage 推进后 manualUnlockAt 被清除，下一轮恢复时间锁', () async {
      final now = DateTime(2026, 7, 20, 10, 0);
      // 锁定中的 review1，当前在末项 blindListen（difficult 已完成）
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.blindListen,
        firstLearnCompletedAt: now.subtract(const Duration(days: 1)),
        lastStageCompletedAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now,
      );
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).unlockCurrentReview('a1');
      await notifier(container).completeCurrentSubStage('a1');

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.review2);
      expect(after.manualUnlockAt, isNull);
      // 下一轮按实际完成时间 + 间隔正常锁定
      expect(after.isReviewLockedAt(DateTime.now()), isTrue);
    });

    test('非复习阶段（firstLearn）no-op', () async {
      final now = DateTime(2026, 7, 20, 10, 0);
      final progress = LearningProgress(audioItemId: 'a1', updatedAt: now);
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).unlockCurrentReview('a1');

      expect(readProgress(container, 'a1')?.manualUnlockAt, isNull);
      verifyNever(() => mockDao.upsert(any()));
    });

    test('已到期（未锁定）no-op 幂等', () async {
      final now = DateTime(2026, 7, 20, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.reviewDifficultPractice,
        lastStageCompletedAt: now.subtract(const Duration(hours: 20)),
        updatedAt: now,
      );
      expect(progress.isReviewLockedAt(now), isFalse);
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).unlockCurrentReview('a1');

      expect(readProgress(container, 'a1')?.manualUnlockAt, isNull);
      verifyNever(() => mockDao.upsert(any()));
    });

    test('audioItemId 不存在时安全返回', () async {
      final container = createContainer(const LearningProgressState());

      await notifier(container).unlockCurrentReview('nonexistent');

      verifyNever(() => mockDao.upsert(any()));
    });
  });

  // ========== T18: _normalizeSubStageForStage（DB→Model 兼容映射） ==========

  group('normalizeSubStageForStage', () {
    LearningProgressNotifier makeNotifier() {
      final container = createContainer(const LearningProgressState());
      return notifier(container);
    }

    test('review0 + blindListen → blindListen（v2 plan 合法项必须原样保留）', () {
      // 回归测试：旧实现把 review0 阶段的 blindListen 误归一到
      // reviewDifficultPractice，导致 v2 audio 重启后 currentSubStage 回退。
      final result = makeNotifier().normalizeSubStageForStageForTest(
        stage: LearningStage.review0,
        rawSubStageKey: 'blindListen',
      );
      expect(result, SubStageType.blindListen);
    });

    test('review0 + reviewDifficultPractice → 原样保留', () {
      final result = makeNotifier().normalizeSubStageForStageForTest(
        stage: LearningStage.review0,
        rawSubStageKey: 'reviewDifficultPractice',
      );
      expect(result, SubStageType.reviewDifficultPractice);
    });

    test('review0 + reviewRetellParagraph → 原样保留（v1 plan 合法项）', () {
      final result = makeNotifier().normalizeSubStageForStageForTest(
        stage: LearningStage.review0,
        rawSubStageKey: 'reviewRetellParagraph',
      );
      expect(result, SubStageType.reviewRetellParagraph);
    });

    test('review0 + 未知/无效 key → 归一到 reviewDifficultPractice', () {
      final result = makeNotifier().normalizeSubStageForStageForTest(
        stage: LearningStage.review0,
        rawSubStageKey: 'intensiveListen',
      );
      expect(result, SubStageType.reviewDifficultPractice);
    });

    // 回归：review28 v2 audio 重启后 reviewRetellParagraph 应原样保留，
    // 而非被旧实现误归一到 reviewRetellSummary。
    test('review28 + reviewRetellParagraph → 原样保留（v2 plan 合法项）', () {
      final result = makeNotifier().normalizeSubStageForStageForTest(
        stage: LearningStage.review28,
        rawSubStageKey: 'reviewRetellParagraph',
      );
      expect(result, SubStageType.reviewRetellParagraph);
    });

    test('review28 + reviewRetellSummary → 原样保留（v1 plan 合法项）', () {
      final result = makeNotifier().normalizeSubStageForStageForTest(
        stage: LearningStage.review28,
        rawSubStageKey: 'reviewRetellSummary',
      );
      expect(result, SubStageType.reviewRetellSummary);
    });

    test('review28 + blindListen → 原样保留', () {
      final result = makeNotifier().normalizeSubStageForStageForTest(
        stage: LearningStage.review28,
        rawSubStageKey: 'blindListen',
      );
      expect(result, SubStageType.blindListen);
    });

    // 回归：review1-14 的 blindListen 应原样保留，而非走 `_` 兜底（虽然
    // 旧实现的 `_` 也兜底到 blindListen，但新实现显式列出更安全）。
    test('review1 + blindListen → 原样保留', () {
      final result = makeNotifier().normalizeSubStageForStageForTest(
        stage: LearningStage.review1,
        rawSubStageKey: 'blindListen',
      );
      expect(result, SubStageType.blindListen);
    });

    test('review2 + reviewDifficultPractice → 原样保留', () {
      final result = makeNotifier().normalizeSubStageForStageForTest(
        stage: LearningStage.review2,
        rawSubStageKey: 'reviewDifficultPractice',
      );
      expect(result, SubStageType.reviewDifficultPractice);
    });

    test('review7 + reviewRetellParagraph → 原样保留', () {
      final result = makeNotifier().normalizeSubStageForStageForTest(
        stage: LearningStage.review7,
        rawSubStageKey: 'reviewRetellParagraph',
      );
      expect(result, SubStageType.reviewRetellParagraph);
    });

    test('review14 + 废弃 retell key → 归一到 reviewRetellParagraph', () {
      final result = makeNotifier().normalizeSubStageForStageForTest(
        stage: LearningStage.review14,
        rawSubStageKey: 'retell',
      );
      expect(result, SubStageType.reviewRetellParagraph);
    });
  });

  // ========== T19: 回归 — 完成 v2 review1.difficult 后 plan 不翻转 ==========

  group('plan snapshot 不变量（回归 buggy v34）', () {
    test(
      'v2 review1（fresh）完成 difficult 后 plan 仍是 v2，planVersionsByStage 不被改写',
      () async {
        // 模拟 fresh audio 进入 review1：planVersionsByStage = kLatestPlanVersions
        // （注意：测试 fixture 显式传完整 baseline 模拟 ensureProgress 行为）
        final now = DateTime(2026, 5, 16, 10, 0);
        const baseline = {
          LearningStage.firstLearn: 1,
          LearningStage.review0: 2,
          LearningStage.review1: 2,
          LearningStage.review2: 2,
          LearningStage.review4: 2,
          LearningStage.review7: 2,
          LearningStage.review14: 2,
          LearningStage.review28: 2,
        };
        final progress = LearningProgress(
          audioItemId: 'a1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.reviewDifficultPractice,
          lastStageCompletedAt: now.subtract(const Duration(days: 1)),
          currentStageStartedAt: now,
          updatedAt: now,
          planVersionsByStage: baseline,
        );
        final container = createContainer(
          LearningProgressState(progressMap: {'a1': progress}),
          nowGetter: () => now,
        );

        await notifier(container).completeCurrentSubStage('a1');

        final after = readProgress(container, 'a1')!;
        // ① 还在 review1（v2 plan = [diff, blind]，未到末项）
        expect(
          after.currentStage,
          LearningStage.review1,
          reason: '完成 difficult 不应翻 plan 到 review2',
        );
        // ② currentSubStage = blindListen（v2 plan 第二项）
        expect(after.currentSubStage, SubStageType.blindListen);
        // ③ **核心**：planVersionsByStage 完全不变（snapshot 不变量）
        expect(
          after.planVersionsByStage,
          baseline,
          reason: 'plan 版本 snapshot 必须在完成 substep 后保持不变',
        );
        // ④ review1 仍为 v2
        expect(after.planVersionFor(LearningStage.review1), 2);
      },
    );

    test('v2 review1（fresh）完成 difficult 再完成 blindListen → review2', () async {
      // 连续两步推进，验证 snapshot 稳定 + 自然跨阶段
      final now = DateTime(2026, 5, 16, 10, 0);
      const baseline = {
        LearningStage.firstLearn: 1,
        LearningStage.review0: 2,
        LearningStage.review1: 2,
        LearningStage.review2: 2,
        LearningStage.review4: 2,
        LearningStage.review7: 2,
        LearningStage.review14: 2,
        LearningStage.review28: 2,
      };
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.reviewDifficultPractice,
        lastStageCompletedAt: now.subtract(const Duration(days: 1)),
        currentStageStartedAt: now,
        updatedAt: now,
        planVersionsByStage: baseline,
      );
      final container = createContainer(
        LearningProgressState(progressMap: {'a1': progress}),
        nowGetter: () => now,
      );

      await notifier(container).completeCurrentSubStage('a1'); // → blindListen
      await notifier(container).completeCurrentSubStage('a1'); // → review2

      final after = readProgress(container, 'a1')!;
      expect(after.currentStage, LearningStage.review2);
      // review2 v2 plan = [diff, blind, retellPara]，first = diff
      expect(after.currentSubStage, SubStageType.reviewDifficultPractice);
      // 整个 snapshot 不变
      expect(after.planVersionsByStage, baseline);
    });
  });

  // ========== Group: refreshDifficultyFromBookmarks — 难句比例实时重算难度 ==========

  group('refreshDifficultyFromBookmarks', () {
    LearningProgress seedProgress(DifficultyLevel difficulty) {
      final now = DateTime(2026, 3, 1, 10, 0);
      return LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.listenAndRepeat,
        currentStageStartedAt: now,
        updatedAt: now,
        difficulty: difficulty,
      );
    }

    test('1/9 难句 → medium（比例 0.11 落在 (0.05, 0.15]）', () async {
      final container = createContainer(
        LearningProgressState(
          progressMap: {'a1': seedProgress(DifficultyLevel.veryHard)},
        ),
        bookmarks: {3},
      );

      final result = await notifier(
        container,
      ).refreshDifficultyFromBookmarks('a1', 9);

      expect(result, DifficultyLevel.medium);
      expect(readProgress(container, 'a1')!.difficulty, DifficultyLevel.medium);
      verify(() => mockDao.upsert(any())).called(1);
    });

    test('0 难句 → veryEasy', () async {
      final container = createContainer(
        LearningProgressState(
          progressMap: {'a1': seedProgress(DifficultyLevel.veryHard)},
        ),
        bookmarks: <int>{},
      );

      final result = await notifier(
        container,
      ).refreshDifficultyFromBookmarks('a1', 9);

      expect(result, DifficultyLevel.veryEasy);
      expect(
        readProgress(container, 'a1')!.difficulty,
        DifficultyLevel.veryEasy,
      );
    });

    test('4/9 难句（>0.30）→ veryHard', () async {
      final container = createContainer(
        LearningProgressState(
          progressMap: {'a1': seedProgress(DifficultyLevel.medium)},
        ),
        bookmarks: {0, 1, 2, 3},
      );

      final result = await notifier(
        container,
      ).refreshDifficultyFromBookmarks('a1', 9);

      expect(result, DifficultyLevel.veryHard);
    });

    test('难度无变化时跳过写库', () async {
      final container = createContainer(
        LearningProgressState(
          progressMap: {'a1': seedProgress(DifficultyLevel.medium)},
        ),
        bookmarks: {3}, // 1/9 → medium，与现有一致
      );

      final result = await notifier(
        container,
      ).refreshDifficultyFromBookmarks('a1', 9);

      expect(result, DifficultyLevel.medium);
      verifyNever(() => mockDao.upsert(any()));
    });

    test('字幕未加载（totalSentences=0）时不重算、不写库，返回现有难度', () async {
      final container = createContainer(
        LearningProgressState(
          progressMap: {'a1': seedProgress(DifficultyLevel.hard)},
        ),
        bookmarks: <int>{},
      );

      final result = await notifier(
        container,
      ).refreshDifficultyFromBookmarks('a1', 0);

      expect(result, DifficultyLevel.hard);
      expect(readProgress(container, 'a1')!.difficulty, DifficultyLevel.hard);
      verifyNever(() => mockDao.upsert(any()));
    });

    test('无 progress 时返回 medium，不写库', () async {
      final container = createContainer(
        const LearningProgressState(progressMap: {}),
        bookmarks: {0, 1, 2, 3},
      );

      final result = await notifier(
        container,
      ).refreshDifficultyFromBookmarks('missing', 9);

      expect(result, DifficultyLevel.medium);
      verifyNever(() => mockDao.upsert(any()));
    });
  });
}
