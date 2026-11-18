/// 译文流正常结束但没有任何译文时，列表应进入可重试的失败态，而不是骨架屏永久转圈。
///
/// 使用真实的 [sentenceTranslationProvider]，只替换 AI 服务与登录态，
/// 以覆盖「流结束 → 状态」这一段真实逻辑。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:echo_loop/database/daos/sentence_ai_cache_dao.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/models/sentence_ai_result.dart';
import 'package:echo_loop/providers/sentence_ai_prewarm.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/widgets/common/sentence_translation_text.dart';
import 'package:echo_loop/widgets/common/shimmer_placeholder.dart';

import '../../helpers/test_app.dart';

class _MockCacheDao extends Mock implements SentenceAiCacheDao {}

class _MockApiClient extends Mock implements SentenceAiApiClient {}

const _target = SentenceAiPrewarmTarget(text: 'Never get up early');

const _retryText = 'Translation failed. Tap to retry.';

Session _signedInSession() {
  final user = User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    email: 'user@example.com',
    createdAt: '2026-06-03T00:00:00.000Z',
  );
  return Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: user,
    refreshToken: 'refresh',
  );
}

void main() {
  late _MockCacheDao cacheDao;
  late _MockApiClient apiClient;
  late SentenceAiNotifier notifier;

  setUp(() {
    cacheDao = _MockCacheDao();
    apiClient = _MockApiClient();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(() => cacheDao.upsert(any(), any(), any())).thenAnswer((_) async {});
    notifier = SentenceAiNotifier(cacheDao: cacheDao, apiClient: apiClient);
  });

  Widget buildHost() {
    return createTestApp(
      const SentenceTranslationText(target: _target, textStyle: TextStyle()),
      overrides: [
        sentenceAiNotifierProvider.overrideWithValue(notifier),
        supabaseSessionProvider.overrideWithValue(
          AsyncData<Session?>(_signedInSession()),
        ),
      ],
    );
  }

  void stubTranslateFrames(
    Stream<SentenceTranslationStreamFrame> Function() frames,
  ) {
    when(
      () => apiClient.translateStream(
        any(),
        accessToken: any(named: 'accessToken'),
        previousText: any(named: 'previousText'),
        nextText: any(named: 'nextText'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) => frames());
  }

  testWidgets('流正常结束但没有任何译文时显示失败态，点击可重新请求', (tester) async {
    var requestCount = 0;
    stubTranslateFrames(() {
      requestCount += 1;
      if (requestCount == 1) return const Stream.empty();
      return Stream.value(
        const SentenceTranslationStreamFrame(
          translation: SentenceTranslation(translation: '从不早起'),
          isFinal: true,
        ),
      );
    });

    await tester.pumpWidget(buildHost());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ShimmerPlaceholder), findsNothing);
    expect(find.text(_retryText), findsOneWidget);

    await tester.tap(find.text(_retryText));
    await tester.pumpAndSettle();

    expect(requestCount, 2);
    expect(find.text('从不早起'), findsOneWidget);
  });

  testWidgets('最终帧译文为空时同样显示失败态，不一直骨架', (tester) async {
    stubTranslateFrames(
      () => Stream.value(
        const SentenceTranslationStreamFrame(
          translation: SentenceTranslation(translation: ''),
          isFinal: true,
        ),
      ),
    );

    await tester.pumpWidget(buildHost());
    // 骨架动画不会停止，不能用 pumpAndSettle；等待流结束后的状态即可。
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ShimmerPlaceholder), findsNothing);
    expect(find.text(_retryText), findsOneWidget);
  });
}
