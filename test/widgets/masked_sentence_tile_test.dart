import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'package:echo_loop/models/retell_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/saved_word_provider.dart';
import 'package:echo_loop/utils/saved_text_index.dart';
import 'package:echo_loop/widgets/common/masked_sentence_tile.dart';

import '../helpers/test_app.dart';

/// 构造测试用 Sentence
Sentence _sentence(String text, {int index = 0}) {
  return Sentence(
    index: index,
    text: text,
    startTime: Duration.zero,
    endTime: const Duration(seconds: 5),
  );
}

/// 包装 MaskedSentenceTile 用于测试
Widget _buildTile({
  required Sentence sentence,
  RetellDisplayMode displayMode = RetellDisplayMode.keywordsOnly,
  Set<int> keywordIndices = const {},
  bool isPlayingSentence = false,
}) {
  return createTestApp(
    MaskedSentenceTile(
      sentence: sentence,
      displayMode: displayMode,
      keywordIndices: keywordIndices,
      isPlayingSentence: isPlayingSentence,
    ),
  );
}

void main() {
  group('MaskedSentenceTile 蒙版连续显示', () {
    testWidgets('hideAll 模式：每个词独立渲染但视觉连续', (tester) async {
      await tester.pumpWidget(
        _buildTile(
          sentence: _sentence('I love you'),
          displayMode: RetellDisplayMode.hideAll,
        ),
      );
      await tester.pumpAndSettle();

      // 每个词仍独立渲染（保持布局稳定）
      expect(find.text('I'), findsOneWidget);
      expect(find.text('love'), findsOneWidget);
      expect(find.text('you'), findsOneWidget);

      // 连续遮盖词之间有桥接色块（通过 Stack + Positioned 溢出绘制）
      // 验证存在 Stack（clipBehavior: Clip.none）
      final stacks = tester.widgetList<Stack>(find.byType(Stack));
      // "I" 和 "love" 都有 isNextMasked=true，所以有 2 个 Stack
      expect(stacks.where((s) => s.clipBehavior == Clip.none).length, 2);
    });

    testWidgets('showAll 模式：每个词独立显示，无 Stack 溢出', (tester) async {
      await tester.pumpWidget(
        _buildTile(
          sentence: _sentence('I love you'),
          displayMode: RetellDisplayMode.showAll,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('I'), findsOneWidget);
      expect(find.text('love'), findsOneWidget);
      expect(find.text('you'), findsOneWidget);

      // showAll 模式无遮盖，不应有溢出 Stack
      final stacks = tester.widgetList<Stack>(find.byType(Stack));
      expect(stacks.where((s) => s.clipBehavior == Clip.none).length, 0);
    });

    testWidgets('keywordsOnly 模式：连续遮盖词桥接、交替词无桥接', (tester) async {
      // "I love you very much" → 关键词索引 {1}（"love"可见）
      // 遮盖: [0], [2], [3], [4]
      // 桥接: [2]→[3], [3]→[4]（2 个桥接）
      await tester.pumpWidget(
        _buildTile(
          sentence: _sentence('I love you very much'),
          displayMode: RetellDisplayMode.keywordsOnly,
          keywordIndices: {1},
        ),
      );
      await tester.pumpAndSettle();

      // 所有词独立存在
      expect(find.text('I'), findsOneWidget);
      expect(find.text('love'), findsOneWidget);
      expect(find.text('you'), findsOneWidget);
      expect(find.text('very'), findsOneWidget);
      expect(find.text('much'), findsOneWidget);

      // "you"→"very" 和 "very"→"much" 有桥接 Stack
      final stacks = tester.widgetList<Stack>(find.byType(Stack));
      expect(stacks.where((s) => s.clipBehavior == Clip.none).length, 2);
    });

    testWidgets('切换模式时 Wrap 子元素数量不变', (tester) async {
      // 先 hideAll
      await tester.pumpWidget(
        _buildTile(
          sentence: _sentence('A B C D E'),
          displayMode: RetellDisplayMode.hideAll,
        ),
      );
      await tester.pumpAndSettle();

      final wrapHideAll = tester.widget<Wrap>(find.byType(Wrap));
      final hideAllCount = wrapHideAll.children.length;

      // 切换到 showAll
      await tester.pumpWidget(
        _buildTile(
          sentence: _sentence('A B C D E'),
          displayMode: RetellDisplayMode.showAll,
        ),
      );
      await tester.pumpAndSettle();

      final wrapShowAll = tester.widget<Wrap>(find.byType(Wrap));
      final showAllCount = wrapShowAll.children.length;

      // 子元素数量应相同（5 个词 = 5 个子元素）
      expect(hideAllCount, showAllCount);
      expect(hideAllCount, 5);
    });
  });

  group('MaskedSentenceTile 双 hit area', () {
    /// 构造带双 callback 的 tile
    Widget buildInteractiveTile({
      required Sentence sentence,
      bool isPlayingSentence = false,
      bool isBookmarked = false,
      VoidCallback? onPlayFromTap,
      VoidCallback? onDetailTap,
      VoidCallback? onBookmarkTap,
    }) {
      return createTestApp(
        MaskedSentenceTile(
          sentence: sentence,
          displayMode: RetellDisplayMode.showAll,
          keywordIndices: const {},
          isPlayingSentence: isPlayingSentence,
          isBookmarked: isBookmarked,
          onPlayFromTap: onPlayFromTap,
          onDetailTap: onDetailTap,
          onBookmarkTap: onBookmarkTap,
        ),
      );
    }

    testWidgets('点击左侧讲解按钮触发 onDetailTap，不触发播放', (tester) async {
      var playFromCount = 0;
      var detailCount = 0;
      await tester.pumpWidget(
        buildInteractiveTile(
          sentence: _sentence('Hello world', index: 0),
          onPlayFromTap: () => playFromCount += 1,
          onDetailTap: () => detailCount += 1,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('$kMaskedSentenceExplanationHitAreaKeyPrefix-0'),
        ),
      );
      await tester.pump();

      expect(playFromCount, 0);
      expect(detailCount, 1);
    });

    testWidgets('点击文本区触发播放，不触发 onDetailTap', (tester) async {
      var playFromCount = 0;
      var detailCount = 0;
      await tester.pumpWidget(
        buildInteractiveTile(
          sentence: _sentence('Hello world', index: 0),
          onPlayFromTap: () => playFromCount += 1,
          onDetailTap: () => detailCount += 1,
        ),
      );
      await tester.pumpAndSettle();

      // 点击文本 "Hello"
      await tester.tap(find.text('Hello'));
      await tester.pump();

      expect(detailCount, 0);
      expect(playFromCount, 1);
    });

    testWidgets('点击右侧收藏区触发 onBookmarkTap，不触发其他回调', (tester) async {
      var playFromCount = 0;
      var detailCount = 0;
      var bookmarkCount = 0;
      await tester.pumpWidget(
        buildInteractiveTile(
          sentence: _sentence('Hello world', index: 0),
          onPlayFromTap: () => playFromCount += 1,
          onDetailTap: () => detailCount += 1,
          onBookmarkTap: () => bookmarkCount += 1,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('$kMaskedSentenceBookmarkHitAreaKeyPrefix-0'),
        ),
      );
      await tester.pump();

      expect(bookmarkCount, 1);
      expect(playFromCount, 0);
      expect(detailCount, 0);
    });

    testWidgets('当前句显示讲解图标，不显示编号或播放图标', (tester) async {
      await tester.pumpWidget(
        buildInteractiveTile(
          sentence: _sentence('Hello world', index: 4),
          isPlayingSentence: true,
          onPlayFromTap: () {},
          onDetailTap: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.text('5'), findsNothing);
    });

    testWidgets('非当前句也显示讲解图标，不显示编号或播放图标', (tester) async {
      await tester.pumpWidget(
        buildInteractiveTile(
          sentence: _sentence('Hello world', index: 4),
          isPlayingSentence: false,
          onPlayFromTap: () {},
          onDetailTap: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      expect(find.text('5'), findsNothing);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('左侧讲解按钮宽度保持 32dp', (tester) async {
      await tester.pumpWidget(
        buildInteractiveTile(
          sentence: _sentence('Hello world', index: 0),
          onPlayFromTap: () {},
        ),
      );
      await tester.pumpAndSettle();

      // 讲解按钮的祖先 SizedBox 应为 32dp。
      final sizedBoxes = tester.widgetList<SizedBox>(
        find.descendant(
          of: find.byKey(
            const ValueKey('$kMaskedSentenceExplanationHitAreaKeyPrefix-0'),
          ),
          matching: find.byType(SizedBox),
        ),
      );
      final hasWidth32 = sizedBoxes.any((s) => s.width == 32);
      expect(hasWidth32, true);
    });

    testWidgets('isBookmarked=true 时右侧渲染已收藏图标', (tester) async {
      await tester.pumpWidget(
        buildInteractiveTile(
          sentence: _sentence('Hello world', index: 0),
          isBookmarked: true,
          onPlayFromTap: () {},
          onDetailTap: () {},
          onBookmarkTap: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('callback 为 null 时不渲染 InkWell（仍可视）', (tester) async {
      await tester.pumpWidget(
        buildInteractiveTile(sentence: _sentence('Hello world', index: 0)),
      );
      await tester.pumpAndSettle();

      // 没有 callback，正文仍渲染，左侧讲解图标保持可见。
      expect(find.text('Hello'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      // 不应有 InkWell（两个交互区都 onTap=null）
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('MaskedSentenceTile 收藏词下划线', () {
    /// 构造带收藏索引覆盖的 tile
    Widget buildSavedTile({
      required Sentence sentence,
      required Set<String> savedWords,
      RetellDisplayMode displayMode = RetellDisplayMode.showAll,
      Set<int> keywordIndices = const {},
    }) {
      return createTestApp(
        MaskedSentenceTile(
          sentence: sentence,
          displayMode: displayMode,
          keywordIndices: keywordIndices,
          isPlayingSentence: false,
        ),
        overrides: [
          savedTextIndexProvider.overrideWithValue(
            SavedTextIndex.build(
              savedWords: savedWords,
              savedPhrases: const {},
            ),
          ),
        ],
      );
    }

    /// 取指定词的 Text widget 中带下划线的子段文本列表
    List<String> underlinedSubstrings(WidgetTester tester, String word) {
      final text = tester.widget<Text>(find.text(word));
      final span = text.textSpan;
      if (span is! TextSpan || span.children == null) return const [];
      return [
        for (final child in span.children!)
          if (child is TextSpan &&
              child.style?.decoration == TextDecoration.underline)
            child.text ?? '',
      ];
    }

    testWidgets('可见收藏词渲染点状下划线，标点不带下划线', (tester) async {
      await tester.pumpWidget(
        buildSavedTile(
          sentence: _sentence('I love you.'),
          savedWords: {'love'},
        ),
      );
      await tester.pumpAndSettle();

      expect(underlinedSubstrings(tester, 'love'), ['love']);
      // "you." 未收藏：仍是普通 Text（无 textSpan 子段）
      final youText = tester.widget<Text>(find.text('you.'));
      expect(youText.textSpan, isNull);
    });

    testWidgets('词组命中：跨词各自带下划线', (tester) async {
      await tester.pumpWidget(
        buildSavedTile(
          sentence: _sentence('please figure out now'),
          savedWords: {'figure out'},
        ),
      );
      await tester.pumpAndSettle();

      expect(underlinedSubstrings(tester, 'figure'), ['figure']);
      expect(underlinedSubstrings(tester, 'out'), ['out']);
      expect(tester.widget<Text>(find.text('please')).textSpan, isNull);
    });

    testWidgets('遮盖词不渲染下划线（hideAll 全遮盖）', (tester) async {
      await tester.pumpWidget(
        buildSavedTile(
          sentence: _sentence('I love you'),
          savedWords: {'love'},
          displayMode: RetellDisplayMode.hideAll,
        ),
      );
      await tester.pumpAndSettle();

      // 遮盖时走普通 Text（透明文字色），无下划线子段
      expect(tester.widget<Text>(find.text('love')).textSpan, isNull);
    });

    testWidgets('keywordsOnly：可见关键词带下划线，遮盖词不带', (tester) async {
      // "I love you" 关键词 {1}（love 可见），love/you 都已收藏
      await tester.pumpWidget(
        buildSavedTile(
          sentence: _sentence('I love you'),
          savedWords: {'love', 'you'},
          displayMode: RetellDisplayMode.keywordsOnly,
          keywordIndices: {1},
        ),
      );
      await tester.pumpAndSettle();

      expect(underlinedSubstrings(tester, 'love'), ['love']);
      expect(tester.widget<Text>(find.text('you')).textSpan, isNull);
    });
  });

  group('MaskedSentenceTile 学习内容字号', () {
    Future<void> pumpWithPrefs(
      WidgetTester tester,
      Map<String, Object> stored,
    ) async {
      SharedPreferences.setMockInitialValues(stored);
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        createTestApp(
          MaskedSentenceTile(
            sentence: _sentence('I love you'),
            displayMode: RetellDisplayMode.keywordsOnly,
            keywordIndices: const {1},
            isPlayingSentence: false,
          ),
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        ),
      );
      await tester.pumpAndSettle();
    }

    TextStyle? styleOf(WidgetTester tester, String word) =>
        tester.widget<Text>(find.text(word)).style;

    testWidgets('按用户字号渲染，可见词与遮盖词一致（布局不跳动）', (tester) async {
      await pumpWithPrefs(tester, {'reading_font_scale': 1.5});

      final base = Theme.of(
        tester.element(find.byType(MaskedSentenceTile)),
      ).textTheme.bodyMedium;
      final visible = styleOf(tester, 'love');
      expect(visible?.fontSize, (base?.fontSize ?? 14) * 1.5);
      // 遮盖词只改颜色，尺寸必须和可见词相同
      expect(styleOf(tester, 'you')?.fontSize, visible?.fontSize);
    });

    testWidgets('默认偏好保持主题正文样式', (tester) async {
      await pumpWithPrefs(tester, {});

      final base = Theme.of(
        tester.element(find.byType(MaskedSentenceTile)),
      ).textTheme.bodyMedium;
      expect(styleOf(tester, 'love')?.fontSize, base?.fontSize);
    });
  });
}
