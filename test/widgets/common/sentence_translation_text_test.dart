import 'package:echo_loop/features/subscription/models/premium_feature.dart';
import 'package:echo_loop/providers/sentence_ai_prewarm.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/providers/sentence_translation_provider.dart';
import 'package:echo_loop/widgets/common/sentence_translation_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

const _target = SentenceAiPrewarmTarget(
  text: 'Hello world',
  audioItemId: 'audio-1',
  sentenceIndex: 0,
);

Widget _buildText(
  Stream<String> Function() translationStream, {
  VoidCallback? onSignInRequired,
}) {
  return createTestApp(
    SentenceTranslationText(
      target: _target,
      textStyle: const TextStyle(),
      onSignInRequired: onSignInRequired ?? () {},
    ),
    overrides: [
      sentenceTranslationProvider.overrideWith(
        (ref, target) => translationStream(),
      ),
    ],
  );
}

void main() {
  group('SentenceTranslationText', () {
    testWidgets('译文就绪后显示译文', (tester) async {
      await tester.pumpWidget(_buildText(() => Stream.value('你好世界')));
      await tester.pumpAndSettle();

      expect(find.text('你好世界'), findsOneWidget);
    });

    testWidgets('额度用尽时就地提示订阅，不回退英文也不通知登录', (tester) async {
      var signInRequests = 0;
      await tester.pumpWidget(
        _buildText(
          () => Stream.error(
            const AiFeatureQuotaExceededException(
              feature: PremiumFeature.aiTranslation,
            ),
          ),
          onSignInRequired: () => signInRequests += 1,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('AI translation quota used up. Tap to subscribe.'),
        findsOneWidget,
      );
      expect(find.text('Hello world'), findsNothing);
      expect(signInRequests, 0);
    });

    testWidgets('未登录时通知宿主', (tester) async {
      var signInRequests = 0;
      await tester.pumpWidget(
        _buildText(
          () => Stream.error(const AiFeatureAuthRequiredException()),
          onSignInRequired: () => signInRequests += 1,
        ),
      );
      // 未登录时保持骨架占位（动画不停），不能用 pumpAndSettle。
      await tester.pump();
      await tester.pump();

      expect(signInRequests, 1);
    });

    testWidgets('普通失败时点击重试会重新请求', (tester) async {
      var requestCount = 0;
      await tester.pumpWidget(
        _buildText(() {
          requestCount += 1;
          return requestCount == 1
              ? Stream.error(Exception('network'))
              : Stream.value('你好世界');
        }),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Translation failed. Tap to retry.'));
      await tester.pumpAndSettle();

      expect(requestCount, 2);
      expect(find.text('你好世界'), findsOneWidget);
    });
  });
}
