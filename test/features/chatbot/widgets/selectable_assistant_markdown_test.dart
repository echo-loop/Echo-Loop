/// SelectableAssistantMarkdown 测试：自有选区内核 + 跨块后端 + 操作条（复制 / 问 AI）。
///
/// 2026-07-30 从官方 `SelectionArea` 迁到与句子正文同一套实现，测试语义随之改写：
/// 断言从「SelectionArea 已挂载」改为「选区状态与选中文本本身」——自有实现能在
/// headless 下算出真实选区，因此这里可以直接断言选中文本、跨块拼接与剪贴板内容。
library;

import 'package:echo_loop/features/chatbot/widgets/selectable_assistant_markdown.dart';
import 'package:echo_loop/widgets/selection/selectable_content.dart';
import 'package:echo_loop/widgets/selection/selection_toolbar_host.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'chatbot_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 强制 iOS 平台，覆盖移动端「长按选区即弹操作条」主路径。
  final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  final hapticCalls = <Object?>[];
  final clipboardTexts = <String>[];

  setUp(() {
    hapticCalls.clear();
    clipboardTexts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            hapticCalls.add(call.arguments);
          }
          if (call.method == 'Clipboard.setData') {
            clipboardTexts.add(
              (call.arguments as Map)['text'] as String? ?? '',
            );
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// 渲染 AI 回答，并挂上操作条所需的页面级宿主（真实结构由 `ChatView` 提供）。
  Future<void> pumpMarkdown(
    WidgetTester tester,
    Widget markdown, {
    Locale locale = const Locale('en'),
    ThemeMode themeMode = ThemeMode.light,
  }) => pumpChatWidget(
    tester,
    SelectionToolbarHost(
      child: Align(alignment: Alignment.topLeft, child: markdown),
    ),
    locale: locale,
    themeMode: themeMode,
  );

  SelectableContentState selectionState(WidgetTester tester) =>
      tester.state<SelectableContentState>(find.byType(SelectableContent));

  /// markdown 渲染出的全部段落（按文档顺序）。
  List<RenderParagraph> markdownParagraphs(WidgetTester tester) => find
      .descendant(of: find.byType(GptMarkdown), matching: find.byType(RichText))
      .evaluate()
      .map((element) => element.renderObject! as RenderParagraph)
      .toList();

  /// 取某个词的几何位置（全局坐标）；[align] 指定取词内哪一点。
  Offset wordPoint(WidgetTester tester, String word, {double align = 0.5}) {
    for (final paragraph in markdownParagraphs(tester)) {
      final text = paragraph.text.toPlainText();
      final start = text.indexOf(word);
      if (start < 0) continue;
      final rect = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: start + word.length),
          )
          .first
          .toRect();
      return paragraph.localToGlobal(
        Offset(rect.left + rect.width * align, rect.center.dy),
      );
    }
    fail('未在 markdown 中找到「$word」');
  }

  /// 长按建立选区（可选拖到另一点后松手）。
  Future<void> longPressSelect(
    WidgetTester tester, {
    required Offset from,
    Offset? to,
  }) async {
    final gesture = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    if (to != null) {
      await gesture.moveTo(to);
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  final toolbarSurface = find.byKey(
    const ValueKey('selection_toolbar_surface'),
  );

  testWidgets('不再使用官方 SelectionArea，改用自有选区内核包裹 markdown', (tester) async {
    await pumpMarkdown(
      tester,
      const SelectableAssistantMarkdown(data: 'hello world'),
    );
    expect(find.byType(SelectionArea), findsNothing);
    expect(find.byType(SelectableContent), findsOneWidget);
    expect(find.byType(GptMarkdown), findsOneWidget);
  }, variant: iOS);

  testWidgets('长按选中该词并弹出操作条：复制 + 问 AI', (tester) async {
    await pumpMarkdown(
      tester,
      SelectableAssistantMarkdown(data: 'hello world', onFollowUp: (_) {}),
    );
    await longPressSelect(tester, from: wordPoint(tester, 'hello'));

    expect(selectionState(tester).selectedText, 'hello');
    // en locale：Copy / Ask AI —— 与句子正文同一个操作条组件。
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Ask AI'), findsOneWidget);
    // 横向气泡：CupertinoTextSelectionToolbar（灰色圆角胶囊），非纵向 desktop 菜单。
    expect(find.byType(CupertinoTextSelectionToolbar), findsOneWidget);
    expect(toolbarSurface, findsOneWidget);
    // 手柄由平台画笔产出。
    expect(find.byKey(const Key('selection_handle_start')), findsOneWidget);
    expect(find.byKey(const Key('selection_handle_end')), findsOneWidget);
  }, variant: iOS);

  testWidgets('跨 markdown 块拖选：标题与正文按文档顺序拼接', (tester) async {
    // 标题是 `WidgetSpan` 占位符里的独立段落，与正文段落分属两个 RenderParagraph，
    // 因此这条覆盖的正是跨块字符空间与文档顺序。
    await pumpMarkdown(
      tester,
      const SelectableAssistantMarkdown(data: '# alpha one\n\nbeta two'),
    );
    expect(markdownParagraphs(tester).length, greaterThan(1));

    await longPressSelect(
      tester,
      from: wordPoint(tester, 'alpha'),
      to: wordPoint(tester, 'beta', align: 0.95),
    );

    final selected = selectionState(tester).selectedText;
    expect(selected, startsWith('alpha'));
    expect(selected, contains('one'));
    expect(selected, endsWith('beta'));
    expect(selected, contains('\n'));
  }, variant: iOS);

  testWidgets('单击取消选区（AI 回答不点词即查），双击选词', (tester) async {
    await pumpMarkdown(
      tester,
      const SelectableAssistantMarkdown(data: 'hello world'),
    );
    await longPressSelect(tester, from: wordPoint(tester, 'hello'));
    expect(selectionState(tester).hasActiveSelection, isTrue);

    // 双击判定按时间窗，单击测试前先让上一次点击过期。
    await tester.pump(kDoubleTapTimeout * 2);
    await tester.tapAt(wordPoint(tester, 'world'));
    await tester.pumpAndSettle();
    expect(selectionState(tester).hasActiveSelection, isFalse);
    expect(toolbarSurface, findsNothing);

    final target = wordPoint(tester, 'world');
    await tester.tapAt(target);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(target);
    await tester.pumpAndSettle();
    expect(selectionState(tester).selectedText, 'world');
    expect(toolbarSurface, findsOneWidget);
  }, variant: iOS);

  testWidgets('iOS 长按新选区统一触发选择轻反馈和平台长按反馈', (tester) async {
    await pumpMarkdown(
      tester,
      const SelectableAssistantMarkdown(data: 'hello world'),
    );

    await longPressSelect(tester, from: wordPoint(tester, 'hello'));
    expect(hapticCalls, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.heavyImpact',
    ]);

    hapticCalls.clear();
    await longPressSelect(tester, from: wordPoint(tester, 'world'));
    expect(hapticCalls, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.heavyImpact',
    ]);
  }, variant: iOS);

  testWidgets('Android 长按新选区统一触发选择轻反馈和平台长按反馈', (tester) async {
    await pumpMarkdown(
      tester,
      const SelectableAssistantMarkdown(data: 'hello world'),
    );

    await longPressSelect(tester, from: wordPoint(tester, 'hello'));
    expect(hapticCalls, ['HapticFeedbackType.selectionClick', null]);
  }, variant: android);

  testWidgets('Android AI Chat 选择手柄位于选区下方', (tester) async {
    await pumpMarkdown(
      tester,
      const SelectableAssistantMarkdown(data: 'hello world'),
    );
    await longPressSelect(tester, from: wordPoint(tester, 'hello'));

    final paragraph = markdownParagraphs(tester).first;
    final start = paragraph.text.toPlainText().indexOf('hello');
    final selectedBox = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + 5),
        )
        .first
        .toRect();
    final handleCenter = paragraph.localToGlobal(selectedBox.bottomCenter);
    final actualHandleCenter = tester
        .getRect(find.byKey(const Key('selection_handle_end')))
        .center;

    expect(actualHandleCenter.dy, greaterThan(handleCenter.dy));
  }, variant: android);

  testWidgets('长按拖选期间显示放大镜，松手后移除', (tester) async {
    await pumpMarkdown(
      tester,
      const SelectableAssistantMarkdown(data: 'hello world'),
    );

    final gesture = await tester.startGesture(wordPoint(tester, 'hello'));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.byType(CupertinoTextMagnifier), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoTextMagnifier), findsNothing);
  }, variant: iOS);

  testWidgets('无 onFollowUp 时只显示复制（不显示问 AI）', (tester) async {
    await pumpMarkdown(
      tester,
      const SelectableAssistantMarkdown(data: 'hello world'),
    );
    await longPressSelect(tester, from: wordPoint(tester, 'hello'));
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Ask AI'), findsNothing);
  }, variant: iOS);

  testWidgets('点复制：写入选中文本、收起操作条并结束选区', (tester) async {
    await pumpMarkdown(
      tester,
      const SelectableAssistantMarkdown(data: 'hello world'),
    );
    await longPressSelect(tester, from: wordPoint(tester, 'hello'));
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(clipboardTexts, ['hello']);
    expect(find.text('Copy'), findsNothing);
    expect(selectionState(tester).hasActiveSelection, isFalse);
    expect(tester.takeException(), isNull);
  }, variant: iOS);

  testWidgets('点问 AI：回调选中文本、收起操作条并结束选区', (tester) async {
    final followUps = <String>[];
    await pumpMarkdown(
      tester,
      SelectableAssistantMarkdown(
        data: 'hello world',
        onFollowUp: followUps.add,
      ),
    );
    await longPressSelect(tester, from: wordPoint(tester, 'hello'));
    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();

    expect(followUps, ['hello']);
    expect(find.text('Ask AI'), findsNothing);
    expect(selectionState(tester).hasActiveSelection, isFalse);
    expect(tester.takeException(), isNull);
  }, variant: iOS);

  testWidgets('AI 回答被整块移除（清空会话）时操作条一起消失', (tester) async {
    // 「新会话」会把消息从树上摘掉，此时不会走 didUpdateWidget，必须由内核在
    // dispose 里收掉自己挂在宿主上的操作条，否则气泡会孤零零留在空白页面上。
    await pumpMarkdown(
      tester,
      const SelectableAssistantMarkdown(data: 'hello world'),
    );
    await longPressSelect(tester, from: wordPoint(tester, 'hello'));
    expect(toolbarSurface, findsOneWidget);

    await pumpMarkdown(tester, const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(find.byType(SelectableContent), findsNothing);
    expect(toolbarSurface, findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: iOS);

  testWidgets('流式内容变化即结束选区（不按旧偏移盲目恢复）', (tester) async {
    await pumpMarkdown(
      tester,
      const SelectableAssistantMarkdown(data: 'hello world'),
    );
    await longPressSelect(tester, from: wordPoint(tester, 'hello'));
    expect(selectionState(tester).hasActiveSelection, isTrue);

    await pumpMarkdown(
      tester,
      const SelectableAssistantMarkdown(data: 'hello world and more'),
    );
    await tester.pumpAndSettle();
    expect(selectionState(tester).hasActiveSelection, isFalse);
    expect(toolbarSurface, findsNothing);
  }, variant: iOS);
}
