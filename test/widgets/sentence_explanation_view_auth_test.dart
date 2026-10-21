import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:echo_loop/database/daos/audio_item_dao.dart';
import 'package:echo_loop/database/daos/sentence_ai_cache_dao.dart';
import 'package:echo_loop/database/daos/saved_sense_group_dao.dart';
import 'package:echo_loop/database/daos/saved_word_dao.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/remote_config/remote_config.dart';
import 'package:echo_loop/features/remote_config/remote_config_providers.dart';
import 'package:echo_loop/features/subscription/models/premium_feature.dart';
import 'package:echo_loop/features/subscription/models/ai_quota_rejection.dart';
import 'package:echo_loop/features/subscription/providers/subscription_availability.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/sense_group_result.dart';
import 'package:echo_loop/models/sense_group_range_playback.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/sentence_ai_result.dart';
import 'package:echo_loop/providers/audio_sentences_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/router/app_router.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/widgets/practice/sentence_annotation_card.dart';
import 'package:echo_loop/widgets/practice/sentence_explanation_view.dart';
import 'package:echo_loop/widgets/dictionary/dictionary_panel_host.dart';
import 'package:echo_loop/widgets/animated_bookmark_icon.dart';

import '../helpers/mock_providers.dart';

class _NoopSentenceAiApiClient extends SentenceAiApiClient {
  _NoopSentenceAiApiClient() : super.withDio(_UnusedDio());
}

class _QuotaSentenceAiNotifier extends SentenceAiNotifier {
  _QuotaSentenceAiNotifier({
    required super.cacheDao,
    required super.apiClient,
    this.reason = AiQuotaRejectionReason.exhausted,
  });

  final AiQuotaRejectionReason reason;

  final translationRespectLocalQuotaResetValues = <bool>[];
  final analysisRespectLocalQuotaResetValues = <bool>[];
  final senseGroupRespectLocalQuotaResetValues = <bool>[];

  @override
  Stream<SentenceTranslation> getTranslationStream(
    String text, {
    required String targetLanguage,
    String? previous,
    String? next,
    String? accessToken,
    CancelToken? cancelToken,
    bool respectLocalQuotaReset = false,
  }) async* {
    translationRespectLocalQuotaResetValues.add(respectLocalQuotaReset);
    throw AiFeatureQuotaExceededException(
      feature: PremiumFeature.aiTranslation,
      reason: reason,
    );
  }

  @override
  Stream<SentenceAnalysis> getAnalysisStream(
    String text, {
    required String targetLanguage,
    String? accessToken,
    CancelToken? cancelToken,
    bool respectLocalQuotaReset = false,
  }) async* {
    analysisRespectLocalQuotaResetValues.add(respectLocalQuotaReset);
    throw AiFeatureQuotaExceededException(
      feature: PremiumFeature.aiAnalysis,
      reason: reason,
    );
  }

  @override
  Stream<SenseGroupResult> getSenseGroupsStream(
    String text, {
    String? accessToken,
    CancelToken? cancelToken,
    bool respectLocalQuotaReset = false,
  }) async* {
    senseGroupRespectLocalQuotaResetValues.add(respectLocalQuotaReset);
    throw AiFeatureQuotaExceededException(
      feature: PremiumFeature.aiSenseGroup,
      reason: reason,
    );
  }
}

class _RecordingSentenceAiNotifier extends SentenceAiNotifier {
  _RecordingSentenceAiNotifier({
    required super.cacheDao,
    required super.apiClient,
    this.returnCachedResults = false,
  });

  final bool returnCachedResults;
  final translationRequests = <({String? previous, String? next})>[];
  var analysisRequests = 0;
  var senseGroupRequests = 0;

  @override
  SentenceTranslation? getCachedTranslation(
    String text, {
    String? previous,
    String? next,
    String? targetLanguage,
  }) => returnCachedResults
      ? const SentenceTranslation(translation: 'cached fixture translation')
      : null;

  @override
  SentenceAnalysis? getCachedAnalysis(String text, {String? targetLanguage}) =>
      returnCachedResults
      ? const SentenceAnalysis(
          grammar: [
            GrammarPoint(point: 'fixture grammar', note: 'fixture note'),
          ],
        )
      : null;

  @override
  Stream<SentenceTranslation> getTranslationStream(
    String text, {
    required String targetLanguage,
    String? previous,
    String? next,
    String? accessToken,
    CancelToken? cancelToken,
    bool respectLocalQuotaReset = false,
  }) async* {
    translationRequests.add((previous: previous, next: next));
    yield const SentenceTranslation(translation: 'cached-chain translation');
  }

  @override
  Stream<SentenceAnalysis> getAnalysisStream(
    String text, {
    required String targetLanguage,
    String? accessToken,
    CancelToken? cancelToken,
    bool respectLocalQuotaReset = false,
  }) async* {
    analysisRequests++;
    yield const SentenceAnalysis(
      grammar: [GrammarPoint(point: 'g', note: 'n')],
    );
  }

  @override
  Stream<SenseGroupResult> getSenseGroupsStream(
    String text, {
    String? accessToken,
    CancelToken? cancelToken,
    bool respectLocalQuotaReset = false,
  }) async* {
    senseGroupRequests++;
    yield const SenseGroupResult(
      medium: ['Hello world'],
      fine: ['Hello', 'world'],
    );
  }
}

class _TwoGroupSentenceAiNotifier extends _RecordingSentenceAiNotifier {
  _TwoGroupSentenceAiNotifier({
    required super.cacheDao,
    required super.apiClient,
  });

  @override
  Stream<SenseGroupResult> getSenseGroupsStream(
    String text, {
    String? accessToken,
    CancelToken? cancelToken,
    bool respectLocalQuotaReset = false,
  }) async* {
    yield const SenseGroupResult(
      medium: ['Hello', 'world'],
      fine: ['Hello', 'world'],
    );
  }
}

class _UnusedDio extends MockDio {}

class _MockCacheDao extends Mock implements SentenceAiCacheDao {}

class _MockSavedSenseGroupDao extends Mock implements SavedSenseGroupDao {}

class _MockSavedWordDao extends Mock implements SavedWordDao {}

class _MockAudioItemDao extends Mock implements AudioItemDao {}

class _NoopSenseGroupRangePlayback implements SenseGroupRangePlayback {
  @override
  Future<void> cancel() async {}

  @override
  Future<void> play(String audioItemId, Duration start, Duration end) async {}
}

/// 讲解页测试不验证真实音频播放，避免触碰未初始化的后台音频 handler。
class _NoopAudioEngine extends TestAudioEngine {
  @override
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId, {
    void Function()? onClipReady,
  }) async {
    onClipReady?.call();
  }
}

class MockDio extends Mock implements Dio {}

class _SentenceExplanationScrollHost extends StatefulWidget {
  const _SentenceExplanationScrollHost({super.key, required this.aiNotifier});

  final SentenceAiNotifier aiNotifier;

  @override
  State<_SentenceExplanationScrollHost> createState() =>
      _SentenceExplanationScrollHostState();
}

class _SentenceExplanationScrollHostState
    extends State<_SentenceExplanationScrollHost> {
  var _isActive = true;
  var _sentenceIndex = 0;

  void setActive(bool value) => setState(() => _isActive = value);

  void selectNextSentence() => setState(() => _sentenceIndex = 1);

  @override
  Widget build(BuildContext context) {
    return SentenceExplanationView(
      text: List<String>.filled(
        80,
        'A long sentence for scroll lifecycle.',
      ).join(' '),
      sentenceIndex: _sentenceIndex,
      aiNotifier: widget.aiNotifier,
      enableGuide: false,
      isActiveSentence: _isActive,
    );
  }
}

Session testSession() {
  return Session(
    accessToken: 'test-access-token',
    tokenType: 'bearer',
    user: const User(
      id: 'test-user',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-07-13T00:00:00.000Z',
    ),
  );
}

void main() {
  Future<void> pumpAuthTestApp(
    WidgetTester tester, {
    required SentenceAiCacheDao cacheDao,
    required SavedSenseGroupDao savedSenseGroupDao,
    SentenceAiNotifier? aiNotifier,
    bool signedIn = false,
    bool autoShowAiExplanation = true,
    bool autoShowAiAnalysis = true,
    bool autoShowAiTranslation = true,
    bool autoShowAiSenseGroups = false,
    bool? sentenceAutoShowAiExplanation,
    bool? sentenceAutoShowAiAnalysis,
    bool? sentenceAutoShowAiTranslation,
    bool? sentenceAutoShowAiSenseGroups,
    bool useProviderAiNotifier = false,
    bool wrapDictionaryPanelHost = false,
    Widget? content,
    SenseGroupRangePlayback? senseGroupRangePlayback,
    String? audioItemId,
    int? sentenceIndex,
    List<Override> extraOverrides = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      LearningSettingsKeys.autoShowAiExplanation,
      autoShowAiExplanation,
    );
    await prefs.setBool(
      LearningSettingsKeys.autoShowAiAnalysis,
      autoShowAiAnalysis,
    );
    await prefs.setBool(
      LearningSettingsKeys.autoShowAiTranslation,
      autoShowAiTranslation,
    );
    await prefs.setBool(
      LearningSettingsKeys.autoShowAiSenseGroups,
      autoShowAiSenseGroups,
    );
    final savedWordDao = _MockSavedWordDao();
    when(savedWordDao.watchAll).thenAnswer((_) => const Stream.empty());
    when(
      savedWordDao.watchSavedWordTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));
    when(() => savedWordDao.getByWord(any())).thenAnswer((_) async => null);
    when(() => savedWordDao.removeWord(any())).thenAnswer((_) async {});
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            final defaultContent = SentenceExplanationView(
              text: 'Hello world.',
              enableGuide: false,
              audioItemId: audioItemId,
              sentenceIndex: sentenceIndex,
              senseGroupRangePlayback: senseGroupRangePlayback,
              autoShowAiExplanation: sentenceAutoShowAiExplanation,
              autoShowAiAnalysis: sentenceAutoShowAiAnalysis,
              autoShowAiTranslation: sentenceAutoShowAiTranslation,
              autoShowAiSenseGroups: sentenceAutoShowAiSenseGroups,
              aiNotifier: useProviderAiNotifier
                  ? null
                  : aiNotifier ??
                        SentenceAiNotifier(
                          cacheDao: cacheDao,
                          apiClient: _NoopSentenceAiApiClient(),
                        ),
            );
            return Scaffold(
              body: wrapDictionaryPanelHost
                  ? DictionaryPanelHost(child: content ?? defaultContent)
                  : content ?? defaultContent,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const Scaffold(body: Text('Login page')),
        ),
        GoRoute(
          path: AppRoutes.paywall,
          builder: (context, state) =>
              const Scaffold(body: Text('Paywall page')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyticsOverride(),
          usageOverride(),
          ...learningSettingsOverrides(
            prefs: prefs,
            autoShowAiExplanation: autoShowAiExplanation,
            autoShowAiAnalysis: autoShowAiAnalysis,
            autoShowAiTranslation: autoShowAiTranslation,
            autoShowAiSenseGroups: autoShowAiSenseGroups,
          ),
          supabaseSessionProvider.overrideWith(
            (ref) => Stream<Session?>.value(signedIn ? testSession() : null),
          ),
          savedSenseGroupDaoProvider.overrideWithValue(savedSenseGroupDao),
          savedWordDaoProvider.overrideWithValue(savedWordDao),
          audioEngineProvider.overrideWith(() => _NoopAudioEngine()),
          subscriptionAvailabilityProvider.overrideWithValue(true),
          ...extraOverrides,
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('默认布局讲解工具栏与正文位于同一滚动区', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
    );

    final scrollView = find.descendant(
      of: find.byType(SentenceExplanationView),
      matching: find.byType(SingleChildScrollView),
    );
    expect(scrollView, findsOneWidget);
    expect(
      find.ancestor(of: find.text('Analysis'), matching: scrollView),
      findsOneWidget,
    );
  });

  testWidgets('重新进入句子讲解时同步滚动区回到工具栏顶部', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    final hostKey = GlobalKey<_SentenceExplanationScrollHostState>();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
      content: _SentenceExplanationScrollHost(
        key: hostKey,
        aiNotifier: SentenceAiNotifier(
          cacheDao: cacheDao,
          apiClient: _NoopSentenceAiApiClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(SentenceExplanationView),
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable, const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );

    hostKey.currentState!.setActive(false);
    await tester.pump();
    hostKey.currentState!.setActive(true);
    await tester.pump();
    await tester.pump();

    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, 0);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('analysis'))).dy,
      greaterThanOrEqualTo(tester.getTopLeft(scrollable).dy),
    );

    await tester.drag(scrollable, const Offset(0, -160));
    await tester.pumpAndSettle();
    hostKey.currentState!.selectNextSentence();
    await tester.pump();
    await tester.pump();
    expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
  });

  testWidgets('AI 工具栏上下使用统一的 6dp 紧凑留白', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
    );

    final toolbarTop = tester
        .getTopLeft(find.byKey(const ValueKey('analysis')))
        .dy;
    final toolbarBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('analysis')))
        .dy;
    final contentTop = tester
        .getTopLeft(find.byType(SentenceAnnotationCard))
        .dy;

    expect(toolbarTop, greaterThanOrEqualTo(0));
    expect(contentTop - toolbarBottom, closeTo(6, 0.1));
  });

  testWidgets('未显式注入 notifier 时 AI 工具栏仍使用 Provider 发起请求', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    final aiNotifier = _RecordingSentenceAiNotifier(
      cacheDao: cacheDao,
      apiClient: _NoopSentenceAiApiClient(),
    );
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
      signedIn: true,
      useProviderAiNotifier: true,
      autoShowAiAnalysis: false,
      extraOverrides: [
        sentenceAiNotifierProvider.overrideWithValue(aiNotifier),
      ],
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(aiNotifier.translationRequests, hasLength(1));
  });

  testWidgets('未登录请求新意群时展示可关闭的登录弹窗', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
    );

    await tester.tap(find.text('Sense Groups'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sign in to use AI features'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sign in to use AI features'), findsNothing);

    await tester.tap(find.text('Sense Groups'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Login page'), findsOneWidget);
  });

  testWidgets('未登录请求新翻译时展示登录弹窗', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
    );

    await tester.tap(find.text('Translation'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sign in to use AI features'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  for (final button in ['Translation', 'Analysis']) {
    testWidgets('$button 超出额度时先弹提醒，点击订阅后进入订阅页', (tester) async {
      final cacheDao = _MockCacheDao();
      final savedSenseGroupDao = _MockSavedSenseGroupDao();
      when(
        () => cacheDao.getByHash(any(), any()),
      ).thenAnswer((_) async => null);
      when(
        savedSenseGroupDao.watchSavedPhraseTexts,
      ).thenAnswer((_) => Stream<Set<String>>.value(const {}));

      final aiNotifier = _QuotaSentenceAiNotifier(
        cacheDao: cacheDao,
        apiClient: _NoopSentenceAiApiClient(),
      );
      await pumpAuthTestApp(
        tester,
        cacheDao: cacheDao,
        savedSenseGroupDao: savedSenseGroupDao,
        aiNotifier: aiNotifier,
      );

      final buttonKey = button == 'Translation' ? 'translation' : 'analysis';
      await tester.tap(find.byKey(ValueKey(buttonKey)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final respectLocalQuotaResetValues = button == 'Translation'
          ? aiNotifier.translationRespectLocalQuotaResetValues
          : aiNotifier.analysisRespectLocalQuotaResetValues;
      final quotaTitle = button == 'Translation'
          ? "This month's free AI translation quota is used up"
          : "This month's free AI sentence analysis quota is used up";
      expect(respectLocalQuotaResetValues, [false]);
      expect(find.text(quotaTitle), findsOneWidget);
      final dialogTitle = tester.widget<Text>(find.text(quotaTitle));
      final dialogTheme = Theme.of(tester.element(find.byType(AlertDialog)));
      expect(dialogTitle.style, dialogTheme.textTheme.titleLarge);
      expect(find.text('Got it'), findsOneWidget);
      expect(find.text('Upgrade Now'), findsOneWidget);
      expect(find.text('Paywall page'), findsNothing);

      await tester.tap(find.text('Upgrade Now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Paywall page'), findsOneWidget);
    });
  }

  testWidgets('后端 limit=0 时句子 AI 弹窗显示免费版不支持文案', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
      aiNotifier: _QuotaSentenceAiNotifier(
        cacheDao: cacheDao,
        apiClient: _NoopSentenceAiApiClient(),
        reason: AiQuotaRejectionReason.unsupportedForFreePlan,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('translation')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text("The free plan doesn't support AI translation"),
      findsOneWidget,
    );
    expect(
      find.text('Upgrade to unlock this feature and more AI features.'),
      findsOneWidget,
    );
  });

  testWidgets('手动点击超额弹窗关闭后，按钮可再次点击并再次弹窗', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
      aiNotifier: _QuotaSentenceAiNotifier(
        cacheDao: cacheDao,
        apiClient: _NoopSentenceAiApiClient(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('translation')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text("This month's free AI translation quota is used up"),
      findsOneWidget,
    );

    await tester.tap(find.text('Got it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text("This month's free AI translation quota is used up"),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('translation')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text("This month's free AI translation quota is used up"),
      findsOneWidget,
    );
  });

  testWidgets('手动点击意群超额时也强制弹窗并允许再次弹窗', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
      aiNotifier: _QuotaSentenceAiNotifier(
        cacheDao: cacheDao,
        apiClient: _NoopSentenceAiApiClient(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('senseGroup')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text("This month's free AI sentence chunking quota is used up"),
      findsOneWidget,
    );

    await tester.tap(find.text('Got it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text("This month's free AI sentence chunking quota is used up"),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('senseGroup')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text("This month's free AI sentence chunking quota is used up"),
      findsOneWidget,
    );
  });

  testWidgets('点击意群 AI 后立即关闭操作栏并打开词典面板', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
      signedIn: true,
      autoShowAiExplanation: false,
      aiNotifier: _RecordingSentenceAiNotifier(
        cacheDao: cacheDao,
        apiClient: _NoopSentenceAiApiClient(),
      ),
      wrapDictionaryPanelHost: true,
      senseGroupRangePlayback: _NoopSenseGroupRangePlayback(),
      extraOverrides: [dictionaryOverride()],
    );

    await tester.tap(find.byKey(const ValueKey('senseGroup')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hello world'));
    await tester.pump();
    expect(
      find.byKey(const Key('selection_toolbar_button_Analysis')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('selection_toolbar_button_Analysis')),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('selection_toolbar_button_Analysis')),
      findsNothing,
    );
    expect(find.byKey(const Key('dict_panel_surface')), findsOneWidget);
  });

  testWidgets('收藏意群后操作栏保持显示并随收藏真值切换为取消收藏', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    final audioItemDao = _MockAudioItemDao();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final savedTexts = StreamController<Set<String>>.broadcast();
    addTearDown(savedTexts.close);
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => savedTexts.stream);
    when(() => savedSenseGroupDao.getByPhraseText(any())).thenAnswer(
      (_) async => SavedSenseGroup(
        id: 1,
        phraseText: 'hello world',
        displayText: 'Hello world',
        practiceCount: 0,
        totalStudyMs: 0,
        viewedBack: false,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        syncStatus: 0,
      ),
    );
    when(
      () => savedSenseGroupDao.saveSenseGroup(
        phraseText: any(named: 'phraseText'),
        displayText: any(named: 'displayText'),
        audioItemId: any(named: 'audioItemId'),
        sentenceIndex: any(named: 'sentenceIndex'),
        sentenceText: any(named: 'sentenceText'),
        sentenceStartMs: any(named: 'sentenceStartMs'),
        sentenceEndMs: any(named: 'sentenceEndMs'),
        groupStartMs: any(named: 'groupStartMs'),
        groupEndMs: any(named: 'groupEndMs'),
      ),
    ).thenAnswer((_) async => savedTexts.add({'hello world'}));
    when(
      () => savedSenseGroupDao.removeSenseGroup('hello world'),
    ).thenAnswer((_) async => savedTexts.add(const {}));
    when(() => audioItemDao.getById('audio-1')).thenAnswer((_) async => null);
    when(
      () => audioItemDao.getTranscriptSrt('audio-1'),
    ).thenAnswer((_) async => null);

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
      signedIn: true,
      autoShowAiExplanation: false,
      aiNotifier: _RecordingSentenceAiNotifier(
        cacheDao: cacheDao,
        apiClient: _NoopSentenceAiApiClient(),
      ),
      wrapDictionaryPanelHost: true,
      senseGroupRangePlayback: _NoopSenseGroupRangePlayback(),
      audioItemId: 'audio-1',
      extraOverrides: [
        appDatabaseProvider.overrideWithValue(database),
        audioItemDaoProvider.overrideWithValue(audioItemDao),
        dictionaryOverride(),
        remoteFeatureEnabledProvider(
          RemoteFeature.aiChatAssistant,
        ).overrideWithValue(false),
      ],
    );
    savedTexts.add(const {});

    await tester.tap(find.byKey(const ValueKey('senseGroup')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hello world'));
    await tester.pump();

    final analysisButtonFinder = find.byKey(
      const Key('selection_toolbar_button_Analysis'),
    );
    await tester.tap(find.byKey(const Key('selection_toolbar_button_Save')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('selection_toolbar_button_Unsave')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('selection_toolbar_surface')),
      findsOneWidget,
    );

    await tester.tap(analysisButtonFinder);
    await tester.pump();

    final bookmark = tester.widget<AnimatedBookmarkIcon>(
      find.byKey(const Key('dict_panel_bookmark')),
    );
    expect(bookmark.isSaved, isTrue);

    expect(bookmark.onPressed, isNotNull);
    bookmark.onPressed!.call();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedBookmarkIcon>(
            find.byKey(const Key('dict_panel_bookmark')),
          )
          .isSaved,
      isFalse,
    );
  });

  testWidgets('意群操作栏显示时可一次点击直接切换到其它意群', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {'world'}));

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
      signedIn: true,
      autoShowAiExplanation: false,
      aiNotifier: _TwoGroupSentenceAiNotifier(
        cacheDao: cacheDao,
        apiClient: _NoopSentenceAiApiClient(),
      ),
      senseGroupRangePlayback: _NoopSenseGroupRangePlayback(),
      extraOverrides: [
        remoteFeatureEnabledProvider(
          RemoteFeature.aiChatAssistant,
        ).overrideWithValue(false),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('senseGroup')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hello'));
    await tester.pump();
    expect(
      find.byKey(const Key('selection_toolbar_button_Save')),
      findsOneWidget,
    );

    await tester.tap(find.text('world'));
    await tester.pump();

    expect(
      find.byKey(const Key('selection_toolbar_button_Unsave')),
      findsOneWidget,
    );
  });

  testWidgets('自动加载翻译和解析同时超额时只展示一个弹窗', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));

    final aiNotifier = _QuotaSentenceAiNotifier(
      cacheDao: cacheDao,
      apiClient: _NoopSentenceAiApiClient(),
    );
    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
      signedIn: true,
      aiNotifier: aiNotifier,
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text("This month's free AI sentence analysis quota is used up"),
      findsOneWidget,
    );
    expect(find.text('Got it'), findsOneWidget);
    expect(find.text('Upgrade Now'), findsOneWidget);
    expect(aiNotifier.translationRespectLocalQuotaResetValues, [true]);
    expect(aiNotifier.analysisRespectLocalQuotaResetValues, [true]);
  });

  testWidgets('默认自动显示解析和翻译，但不自动请求意群', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));
    final aiNotifier = _RecordingSentenceAiNotifier(
      cacheDao: cacheDao,
      apiClient: _NoopSentenceAiApiClient(),
    );

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
      signedIn: true,
      aiNotifier: aiNotifier,
    );
    await tester.pumpAndSettle();

    expect(aiNotifier.translationRequests, hasLength(1));
    expect(aiNotifier.analysisRequests, 1);
    expect(aiNotifier.senseGroupRequests, 0);
  });

  testWidgets('关闭 AI 讲解总开关时不自动请求任何 AI 内容', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));
    final aiNotifier = _RecordingSentenceAiNotifier(
      cacheDao: cacheDao,
      apiClient: _NoopSentenceAiApiClient(),
    );

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
      signedIn: true,
      autoShowAiExplanation: false,
      aiNotifier: aiNotifier,
    );
    await tester.pumpAndSettle();

    expect(aiNotifier.translationRequests, isEmpty);
    expect(aiNotifier.analysisRequests, 0);
    expect(aiNotifier.senseGroupRequests, 0);
  });

  testWidgets('显式 AI 自动展示设置优先于全局学习设置', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));
    final aiNotifier = _RecordingSentenceAiNotifier(
      cacheDao: cacheDao,
      apiClient: _NoopSentenceAiApiClient(),
      returnCachedResults: true,
    );

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
      signedIn: true,
      sentenceAutoShowAiExplanation: false,
      sentenceAutoShowAiAnalysis: true,
      sentenceAutoShowAiTranslation: true,
      sentenceAutoShowAiSenseGroups: true,
      aiNotifier: aiNotifier,
    );
    await tester.pumpAndSettle();

    expect(aiNotifier.translationRequests, isEmpty);
    expect(aiNotifier.analysisRequests, 0);
    expect(aiNotifier.senseGroupRequests, 0);
    expect(find.text('cached fixture translation'), findsNothing);
    expect(find.text('fixture grammar'), findsNothing);
  });

  testWidgets('只开启意群子开关时自动请求意群，不请求解析和翻译', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));
    final aiNotifier = _RecordingSentenceAiNotifier(
      cacheDao: cacheDao,
      apiClient: _NoopSentenceAiApiClient(),
    );

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
      signedIn: true,
      autoShowAiAnalysis: false,
      autoShowAiTranslation: false,
      autoShowAiSenseGroups: true,
      aiNotifier: aiNotifier,
    );
    await tester.pumpAndSettle();

    expect(aiNotifier.translationRequests, isEmpty);
    expect(aiNotifier.analysisRequests, 0);
    expect(aiNotifier.senseGroupRequests, 1);
  });

  testWidgets('关闭自动显示后仍可手动点击翻译', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));
    final aiNotifier = _RecordingSentenceAiNotifier(
      cacheDao: cacheDao,
      apiClient: _NoopSentenceAiApiClient(),
    );

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
      signedIn: true,
      autoShowAiExplanation: false,
      aiNotifier: aiNotifier,
    );

    await tester.tap(find.byKey(const ValueKey('translation')));
    await tester.pumpAndSettle();

    expect(aiNotifier.translationRequests, hasLength(1));
    expect(find.text('cached-chain translation'), findsOneWidget);
  });

  testWidgets('自动翻译等待前后句上下文就绪后再请求', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    final audioItemDao = _MockAudioItemDao();
    final aiNotifier = _RecordingSentenceAiNotifier(
      cacheDao: cacheDao,
      apiClient: _NoopSentenceAiApiClient(),
    );
    final sentencesCompleter = Completer<List<Sentence>>();

    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));
    when(() => audioItemDao.getById('audio-1')).thenAnswer((_) async => null);

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
      aiNotifier: aiNotifier,
      signedIn: true,
      audioItemId: 'audio-1',
      sentenceIndex: 1,
      extraOverrides: [
        audioItemDaoProvider.overrideWithValue(audioItemDao),
        audioSentencesProvider(
          'audio-1',
        ).overrideWith((_) => sentencesCompleter.future),
      ],
    );

    await tester.pump(const Duration(milliseconds: 50));
    expect(aiNotifier.translationRequests, isEmpty);

    sentencesCompleter.complete([
      Sentence(
        index: 0,
        text: 'Previous sentence.',
        startTime: Duration.zero,
        endTime: const Duration(seconds: 1),
      ),
      Sentence(
        index: 1,
        text: 'Hello world.',
        startTime: const Duration(seconds: 1),
        endTime: const Duration(seconds: 2),
      ),
      Sentence(
        index: 2,
        text: 'Next sentence.',
        startTime: const Duration(seconds: 2),
        endTime: const Duration(seconds: 3),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(aiNotifier.translationRequests, hasLength(1));
    expect(
      aiNotifier.translationRequests.single.previous,
      'Previous sentence.',
    );
    expect(aiNotifier.translationRequests.single.next, 'Next sentence.');
    expect(find.text('cached-chain translation'), findsOneWidget);
  });
}
