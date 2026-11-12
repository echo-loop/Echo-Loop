import 'package:echo_loop/features/subscription/models/premium_feature.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/sentence_ai_prewarm.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/providers/sentence_translation_provider.dart';
import 'package:echo_loop/widgets/common/sentence_translation_text.dart';
import 'package:echo_loop/widgets/common/shimmer_placeholder.dart';
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
    testWidgets('宿主不处理登录时，未登录不显示任何内容', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const SentenceTranslationText(
            target: _target,
            textStyle: TextStyle(),
          ),
          overrides: [
            sentenceTranslationProvider.overrideWith(
              (ref, target) =>
                  Stream.error(const AiFeatureAuthRequiredException()),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ShimmerPlaceholder), findsNothing);
      expect(find.byType(Text), findsNothing);
    });
  });

  group('bookmarkedSentenceTranslationBuilder', () {
    Sentence sentence(int index, String text) => Sentence(
      index: index,
      text: text,
      startTime: Duration.zero,
      endTime: const Duration(seconds: 1),
    );

    testWidgets('仅收藏句显示译文，并按句子全局索引定位', (tester) async {
      final requestedTargets = <SentenceAiPrewarmTarget>[];
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) {
              final builder = bookmarkedSentenceTranslationBuilder(
                theme: Theme.of(context),
                audioItemId: 'audio-1',
                bookmarkedSentenceIndices: const {5},
              );
              return Column(
                children: [
                  builder(sentence(4, 'Plain'), const TextStyle()) ??
                      const Text('no-translation'),
                  builder(sentence(5, 'Saved'), const TextStyle()) ??
                      const Text('no-translation'),
                ],
              );
            },
          ),
          overrides: [
            sentenceTranslationProvider.overrideWith((ref, target) {
              requestedTargets.add(target);
              return Stream.value('译文:${target.text}');
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('no-translation'), findsOneWidget);
      expect(find.text('译文:Saved'), findsOneWidget);
      expect(requestedTargets, const [
        SentenceAiPrewarmTarget(
          text: 'Saved',
          audioItemId: 'audio-1',
          sentenceIndex: 5,
        ),
      ]);
    });
  });
}
