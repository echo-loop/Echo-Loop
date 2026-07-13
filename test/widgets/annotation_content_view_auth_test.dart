import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:echo_loop/database/daos/sentence_ai_cache_dao.dart';
import 'package:echo_loop/database/daos/saved_sense_group_dao.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/subscription/providers/subscription_availability.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/sense_group_result.dart';
import 'package:echo_loop/models/sentence_ai_result.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/router/app_router.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/widgets/practice/annotation_content_view.dart';

import '../helpers/mock_providers.dart';

class _NoopSentenceAiApiClient extends SentenceAiApiClient {
  _NoopSentenceAiApiClient() : super.withDio(_UnusedDio());
}

class _QuotaSentenceAiNotifier extends SentenceAiNotifier {
  _QuotaSentenceAiNotifier({required super.cacheDao, required super.apiClient});

  final translationRespectLocalQuotaResetValues = <bool>[];
  final analysisRespectLocalQuotaResetValues = <bool>[];

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
    throw const AiFeatureQuotaExceededException();
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
    throw const AiFeatureQuotaExceededException();
  }

  @override
  Stream<SenseGroupResult> getSenseGroupsStream(
    String text, {
    String? accessToken,
    CancelToken? cancelToken,
    bool respectLocalQuotaReset = false,
  }) async* {
    throw const AiFeatureQuotaExceededException();
  }
}

class _UnusedDio extends MockDio {}

class _MockCacheDao extends Mock implements SentenceAiCacheDao {}

class _MockSavedSenseGroupDao extends Mock implements SavedSenseGroupDao {}

class MockDio extends Mock implements Dio {}

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
    bool autoLoadSentenceAi = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: AnnotationContentView(
              text: 'Hello world.',
              enableGuide: false,
              autoLoadSentenceAi: autoLoadSentenceAi,
              aiNotifier:
                  aiNotifier ??
                  SentenceAiNotifier(
                    cacheDao: cacheDao,
                    apiClient: _NoopSentenceAiApiClient(),
                  ),
            ),
          ),
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
          ...learningSettingsOverrides(prefs: prefs),
          supabaseSessionProvider.overrideWith(
            (ref) => Stream<Session?>.value(signedIn ? testSession() : null),
          ),
          savedSenseGroupDaoProvider.overrideWithValue(savedSenseGroupDao),
          subscriptionAvailabilityProvider.overrideWithValue(true),
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

    await tester.tap(find.text('Groups'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sign in to use AI features'), findsOneWidget);
    expect(
      find.textContaining(
        'AI translation, analysis, and sense group splitting',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sign in to use AI features'), findsNothing);

    await tester.tap(find.text('Groups'));
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

    await tester.tap(find.text('Translate'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sign in to use AI features'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  for (final button in ['Translate', 'Analysis']) {
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

      final buttonKey = button == 'Translate' ? 'translation' : 'analysis';
      await tester.tap(find.byKey(ValueKey(buttonKey)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final respectLocalQuotaResetValues = button == 'Translate'
          ? aiNotifier.translationRespectLocalQuotaResetValues
          : aiNotifier.analysisRespectLocalQuotaResetValues;
      expect(respectLocalQuotaResetValues, [false]);
      expect(find.text('You\'ve reached your free limit'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
      expect(find.text('Upgrade Now'), findsOneWidget);
      expect(find.text('Paywall page'), findsNothing);

      await tester.tap(find.text('Upgrade Now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Paywall page'), findsOneWidget);
    });
  }

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

    expect(find.text('You\'ve reached your free limit'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('You\'ve reached your free limit'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('translation')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('You\'ve reached your free limit'), findsOneWidget);
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

    expect(find.text('You\'ve reached your free limit'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('You\'ve reached your free limit'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('senseGroup')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('You\'ve reached your free limit'), findsOneWidget);
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
      autoLoadSentenceAi: true,
      aiNotifier: aiNotifier,
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('You\'ve reached your free limit'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
    expect(find.text('Upgrade Now'), findsOneWidget);
    expect(aiNotifier.translationRespectLocalQuotaResetValues, [true]);
    expect(aiNotifier.analysisRespectLocalQuotaResetValues, [true]);
  });
}
