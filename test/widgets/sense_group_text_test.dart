import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/providers/saved_word_provider.dart';
import 'package:echo_loop/utils/saved_text_index.dart';
import 'package:echo_loop/widgets/practice/sense_group_text.dart';

import '../helpers/test_app.dart';
import '../helpers/mock_providers.dart';

/// 跟读匹配单词的高亮绿色（与组件内常量保持一致）
const _matchedColor = Color(0xFF2E9B51);

void main() {
  /// 收集所有 RichText 里被染成绿色的单词文本
  List<String> matchedWords(WidgetTester tester) {
    final result = <String>[];
    for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
      final span = richText.text;
      if (span is TextSpan) {
        span.visitChildren((child) {
          if (child is TextSpan &&
              child.style?.color == _matchedColor &&
              (child.text ?? '').trim().isNotEmpty) {
            result.add(child.text!.trim());
          }
          return true;
        });
      }
    }
    return result;
  }

  /// 单词段（命中目标词）
  SpeechTranscriptSegment word(String text, {required bool matched}) =>
      SpeechTranscriptSegment(text: text, isMatched: matched);

  group('SenseGroupText — 意群模式单词高亮', () {
    testWidgets('句尾数字时间格式的词也能显示播放高亮', (tester) async {
      final cases = [
        (chunk: 'when school finishes at 02:30,', wordIndex: 4, word: '02:30'),
        (chunk: 'and will go until 03:30.', wordIndex: 4, word: '03:30'),
      ];

      for (final testCase in cases) {
        await tester.pumpWidget(
          createTestApp(
            SenseGroupText(
              chunks: [testCase.chunk],
              timings: const [],
              onTapGroup: (_) {},
              activeWordIndex: testCase.wordIndex,
            ),
          ),
        );

        final highlightedSpans = <String>[];
        for (final richText in tester.widgetList<RichText>(
          find.byType(RichText),
        )) {
          richText.text.visitChildren((child) {
            if (child is TextSpan &&
                child.style?.backgroundColor != null &&
                (child.text ?? '').contains(testCase.word)) {
              highlightedSpans.add(child.text!.trim());
            }
            return true;
          });
        }

        expect(
          highlightedSpans.any((span) => span.startsWith(testCase.word)),
          isTrue,
          reason: '${testCase.word} should be highlighted as the active token',
        );
      }
    });

    testWidgets('匹配单词染绿，未匹配单词不染绿', (tester) async {
      // 原文 "Hello brave world" → 意群拆为 ["Hello brave", "world"]
      // 比对结果：Hello 匹配、brave 未匹配、world 匹配
      await tester.pumpWidget(
        createTestApp(
          SenseGroupText(
            chunks: const ['Hello brave', 'world'],
            timings: const [],
            onTapGroup: (_) {},
            highlightedSegments: [
              word('Hello', matched: true),
              const SpeechTranscriptSegment(text: ' ', isMatched: false),
              word('brave', matched: false),
              const SpeechTranscriptSegment(text: ' ', isMatched: false),
              word('world', matched: true),
            ],
          ),
        ),
      );

      final matched = matchedWords(tester);
      expect(matched, contains('Hello'));
      expect(matched, contains('world'));
      expect(matched, isNot(contains('brave')));
    });

    testWidgets('跨 badge 单词游标对齐（第二意群首词按整句状态上色）', (tester) async {
      // 原文 "one two three" → 意群 ["one two", "three"]
      // 仅 three 匹配；验证游标跨过第一意群两词后正确落到 three
      await tester.pumpWidget(
        createTestApp(
          SenseGroupText(
            chunks: const ['one two', 'three'],
            timings: const [],
            onTapGroup: (_) {},
            highlightedSegments: [
              word('one', matched: false),
              const SpeechTranscriptSegment(text: ' ', isMatched: false),
              word('two', matched: false),
              const SpeechTranscriptSegment(text: ' ', isMatched: false),
              word('three', matched: true),
            ],
          ),
        ),
      );

      expect(matchedWords(tester), equals(['three']));
    });

    testWidgets('粘连标点不染绿（与普通模式一致）', (tester) async {
      // "anymore," 中只有单词 anymore 染绿，逗号不染绿
      await tester.pumpWidget(
        createTestApp(
          SenseGroupText(
            chunks: const ['pay anymore,'],
            timings: const [],
            onTapGroup: (_) {},
            highlightedSegments: [
              word('pay', matched: false),
              const SpeechTranscriptSegment(text: ' ', isMatched: false),
              word('anymore', matched: true),
              const SpeechTranscriptSegment(text: ',', isMatched: false),
            ],
          ),
        ),
      );

      // 绿色片段是纯 "anymore"，不含逗号
      expect(matchedWords(tester), equals(['anymore']));
    });

    testWidgets('连字符词按两个单词计数，游标不错位', (tester) async {
      // "well-being world" → well/being 是两个单词，错算成一个会让 world 错位
      await tester.pumpWidget(
        createTestApp(
          SenseGroupText(
            chunks: const ['well-being world'],
            timings: const [],
            onTapGroup: (_) {},
            highlightedSegments: [
              word('well', matched: true),
              const SpeechTranscriptSegment(text: '-', isMatched: false),
              word('being', matched: false),
              const SpeechTranscriptSegment(text: ' ', isMatched: false),
              word('world', matched: true),
            ],
          ),
        ),
      );

      final matched = matchedWords(tester);
      expect(matched, contains('well'));
      expect(matched, contains('world'));
      expect(matched, isNot(contains('being')));
    });

    testWidgets('无高亮数据时回退为纯文本，不报错', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SenseGroupText(
            chunks: const ['Hello world'],
            timings: const [],
            onTapGroup: (_) {},
          ),
        ),
      );

      // 纯文本渲染：能找到原始文本，且无绿色高亮
      expect(find.text('Hello world'), findsOneWidget);
      expect(matchedWords(tester), isEmpty);
    });

    testWidgets('播放高亮时系统文字缩放与未播放时一致', (tester) async {
      // 系统「更大字体」下，播放期间 badge 必须仍跟随 MediaQuery 缩放；
      // RichText 默认 noScaling，会在播放起止时把字号缩回 100%。
      const systemScale = TextScaler.linear(1.5);

      Future<Set<double>> pumpScales({required int? activeWordIndex}) async {
        await tester.pumpWidget(
          createTestApp(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: systemScale),
                child: SenseGroupText(
                  chunks: const ['Hello world'],
                  timings: const [],
                  onTapGroup: (_) {},
                  activeWordIndex: activeWordIndex,
                ),
              ),
            ),
          ),
        );
        return {
          for (final paragraph in tester.renderObjectList<RenderParagraph>(
            find.byType(RichText),
          ))
            paragraph.textScaler.scale(10),
        };
      }

      final idleScales = await pumpScales(activeWordIndex: null);
      final playingScales = await pumpScales(activeWordIndex: 0);

      expect(idleScales, {15.0});
      expect(playingScales, idleScales);
    });
  });

  group('SenseGroupText — 收藏词下划线', () {
    /// 收集所有带下划线的子段文本（Text.rich 内部也由 RichText 渲染，
    /// 只扫 RichText 即可覆盖两条渲染路径且不重复计数）
    List<String> underlinedTexts(WidgetTester tester) {
      final result = <String>[];
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        rich.text.visitChildren((child) {
          if (child is TextSpan &&
              child.style?.decoration == TextDecoration.underline &&
              (child.text ?? '').trim().isNotEmpty) {
            result.add(child.text!.trim());
          }
          return true;
        });
      }
      return result;
    }

    Widget buildWithSaved(
      SenseGroupText child, {
      Set<String> savedWords = const {},
      Set<String> savedPhrases = const {},
    }) {
      return createTestApp(
        child,
        overrides: dedupeOverrides([
          savedTextIndexProvider.overrideWithValue(
            SavedTextIndex.build(
              savedWords: savedWords,
              savedPhrases: savedPhrases,
            ),
          ),
        ]),
      );
    }

    testWidgets('badge 内收藏词带下划线，其余不带；点击播放不受影响', (tester) async {
      var tapped = -1;
      await tester.pumpWidget(
        buildWithSaved(
          SenseGroupText(
            chunks: const ['How many people', 'is it for?'],
            timings: const [],
            onTapGroup: (i) => tapped = i,
          ),
          savedWords: {'people'},
        ),
      );

      expect(underlinedTexts(tester), equals(['people']));

      // 点击第二个 badge 仍触发播放回调
      await tester.tap(find.text('is it for?'));
      expect(tapped, 1);
    });

    testWidgets('badge 本体已收藏（整段自匹配）不重复下划线，内部收藏词照标', (tester) async {
      await tester.pumpWidget(
        buildWithSaved(
          SenseGroupText(
            chunks: const ['How many people'],
            timings: const [],
            onTapGroup: (_) {},
            savedGroupTexts: const {'how many people'},
          ),
          savedWords: {'many'},
          savedPhrases: {'how many people'},
        ),
      );

      // 整段自匹配被剔除，只有内部收藏词 many 带下划线
      expect(underlinedTexts(tester), equals(['many']));
    });

    testWidgets('跟读高亮与收藏下划线叠加：匹配词染绿且带下划线', (tester) async {
      await tester.pumpWidget(
        buildWithSaved(
          SenseGroupText(
            chunks: const ['Hello world'],
            timings: const [],
            onTapGroup: (_) {},
            highlightedSegments: [
              word('Hello', matched: true),
              const SpeechTranscriptSegment(text: ' ', isMatched: false),
              word('world', matched: false),
            ],
          ),
          savedWords: {'hello'},
        ),
      );

      // Hello 同时匹配（绿）且收藏（下划线）
      expect(matchedWords(tester), equals(['Hello']));
      expect(underlinedTexts(tester), equals(['Hello']));
    });
  });
}
