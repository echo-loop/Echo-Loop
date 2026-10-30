import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/retell_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/common/masked_sentence_tile.dart';
import 'package:echo_loop/widgets/common/paragraph_sentence_list_card.dart';

import '../../helpers/test_app.dart';

const _originalText = '  Hello, world!  ';

Sentence _sentence(int index) => Sentence(
  index: index,
  text: index == 0 ? _originalText : 'Another sentence.',
  startTime: Duration(seconds: index * 5),
  endTime: Duration(seconds: (index + 1) * 5),
);

Widget _host({
  RetellDisplayMode displayMode = RetellDisplayMode.showAll,
  Set<int> bookmarks = const {},
  int playingIndex = 0,
  List<Sentence>? sentences,
  Key? listKey,
  ValueChanged<Sentence>? onPlay,
  ValueChanged<Sentence>? onExplain,
  Future<void> Function(Sentence)? onBookmark,
}) => createTestApp(
  ParagraphSentenceListCard(
    key: listKey,
    sentences: sentences ?? [_sentence(0), _sentence(1)],
    displayMode: displayMode,
    keywordMap: const {
      0: {0},
    },
    playingSentenceIndex: playingIndex,
    bookmarkedSentenceIndices: bookmarks,
    onSentencePlayFrom: onPlay,
    onSentenceExplanationTap: onExplain,
    onSentenceBookmarkToggle: onBookmark,
  ),
  key: const ValueKey('sentence-menu-test-app'),
);

Finder _body(int index) =>
    find.byKey(ValueKey('$kMaskedSentenceBodyHitAreaKeyPrefix-$index'));

Finder _action(String name) => find.byKey(ValueKey('sentence-menu-$name'));

Future<void> _openMenu(WidgetTester tester, {int index = 0}) async {
  await tester.longPress(_body(index));
  await tester.pumpAndSettle();
  expect(_action('copy'), findsOneWidget);
}

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  for (final isSaved in [false, true]) {
    testWidgets('菜单图标与句子列表统一（已收藏：$isSaved）', (tester) async {
      await tester.pumpWidget(
        _host(
          bookmarks: isSaved ? const {0} : const {},
          onBookmark: (_) async {},
          onExplain: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      final bookmark = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(
            const ValueKey('$kMaskedSentenceBookmarkHitAreaKeyPrefix-0'),
          ),
          matching: find.byType(Icon),
        ),
      );
      final explanation = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(
            const ValueKey('$kMaskedSentenceExplanationHitAreaKeyPrefix-0'),
          ),
          matching: find.byType(Icon),
        ),
      );
      await _openMenu(tester);
      final menuBookmark = tester.widget<Icon>(
        find.descendant(
          of: _action('toggleBookmark'),
          matching: find.byType(Icon),
        ),
      );
      final menuExplanation = tester.widget<Icon>(
        find.descendant(of: _action('explain'), matching: find.byType(Icon)),
      );
      expect(menuBookmark.icon, bookmark.icon);
      if (isSaved) expect(menuBookmark.color, AppTheme.bookmarkColor);
      expect(menuExplanation.icon, explanation.icon);
      expect(menuExplanation.color, explanation.color);
      expect(menuExplanation.color, Colors.purple.shade400);
    });
  }

  testWidgets('长按只打开菜单，关闭菜单后普通点击仍播放原句', (tester) async {
    final played = <int>[];
    var explained = 0;
    var bookmarked = 0;
    await tester.pumpWidget(
      _host(
        onPlay: (s) => played.add(s.index),
        onExplain: (_) => explained += 1,
        onBookmark: (_) async {
          bookmarked += 1;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _openMenu(tester);
    expect(_action('toggleBookmark'), findsOneWidget);
    expect(_action('explain'), findsOneWidget);
    expect(played, isEmpty);
    expect(explained, 0);
    expect(bookmarked, 0);

    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    expect(_action('copy'), findsNothing);
    expect(bookmarked, 0);
    await tester.tap(_body(0));
    expect(played, [0]);
  });

  testWidgets('桌面右键打开同一菜单且不触发播放', (tester) async {
    var played = 0;
    await tester.pumpWidget(_host(onPlay: (_) => played += 1));
    await tester.pumpAndSettle();
    await tester.tap(
      _body(0),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(_action('copy'), findsOneWidget);
    expect(played, 0);
  });

  for (final mode in RetellDisplayMode.values) {
    testWidgets('$mode 复制完整原句，不复制遮盖内容或丢失空格', (tester) async {
      Object? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            if (call.arguments case final Map<Object?, Object?> arguments) {
              clipboardText = arguments['text'];
            }
          }
          return null;
        },
      );
      await tester.pumpWidget(_host(displayMode: mode));
      await tester.pumpAndSettle();
      await _openMenu(tester);
      await tester.tap(_action('copy'));
      await tester.pumpAndSettle();
      expect(clipboardText, _originalText);
      expect(find.text('Copied to clipboard'), findsOneWidget);
      expect(
        tester
            .widget<ParagraphSentenceListCard>(
              find.byType(ParagraphSentenceListCard),
            )
            .displayMode,
        mode,
      );
    });
  }

  testWidgets('收藏等待写入成功才提示，再次打开显示取消收藏', (tester) async {
    final write = Completer<void>();
    var calls = 0;
    Set<int> bookmarks = {};
    late StateSetter updateHost;
    await tester.pumpWidget(
      createTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return ParagraphSentenceListCard(
              sentences: [_sentence(0)],
              displayMode: RetellDisplayMode.showAll,
              keywordMap: const {},
              playingSentenceIndex: 0,
              bookmarkedSentenceIndices: bookmarks,
              onSentenceBookmarkToggle: (s) async {
                calls += 1;
                await write.future;
                updateHost(() {
                  bookmarks = bookmarks.isEmpty ? {s.index} : {};
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openMenu(tester);
    expect(find.text('Save sentence'), findsOneWidget);
    await tester.tap(_action('toggleBookmark'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Sentence saved'), findsNothing);
    // 写入期间再次长按不会建立第二次提交。
    await tester.longPress(_body(0));
    await tester.pumpAndSettle();
    expect(_action('copy'), findsNothing);
    write.complete();
    await tester.pumpAndSettle();
    expect(find.text('Sentence saved'), findsOneWidget);

    await _openMenu(tester);
    expect(find.text('Unsave sentence'), findsOneWidget);
    await tester.tap(_action('toggleBookmark'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(bookmarks, isEmpty);
    expect(find.text('Sentence unsaved'), findsOneWidget);
  });

  testWidgets('菜单打开期间已由其他入口收藏，不会反向取消', (tester) async {
    var calls = 0;
    Future<void> toggle(Sentence _) async {
      calls += 1;
    }

    await tester.pumpWidget(_host(onBookmark: toggle));
    await tester.pumpAndSettle();
    await _openMenu(tester);
    await tester.pumpWidget(_host(bookmarks: const {0}, onBookmark: toggle));
    await tester.pumpAndSettle();
    await tester.tap(_action('toggleBookmark'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Sentence saved'), findsOneWidget);
  });

  testWidgets('收藏提交后离开页面，异步完成不再显示反馈', (tester) async {
    final write = Completer<void>();
    await tester.pumpWidget(_host(onBookmark: (_) => write.future));
    await tester.pumpAndSettle();
    await _openMenu(tester);
    await tester.tap(_action('toggleBookmark'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    write.complete();
    await tester.pumpAndSettle();
    expect(find.text('Sentence saved'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('收藏失败反馈错误，不报告成功', (tester) async {
    await tester.pumpWidget(
      _host(onBookmark: (_) async => throw StateError('write failed')),
    );
    await tester.pumpAndSettle();
    await _openMenu(tester);
    await tester.tap(_action('toggleBookmark'));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't complete this action. Please try again."),
      findsOneWidget,
    );
    expect(find.text('Sentence saved'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('剪贴板失败反馈错误，不报告成功', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'clipboard-unavailable');
        }
        return null;
      },
    );
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await _openMenu(tester);
    await tester.tap(_action('copy'));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't complete this action. Please try again."),
      findsOneWidget,
    );
    expect(find.text('Copied to clipboard'), findsNothing);
  });

  testWidgets('播放切句与列表重建后 AI 讲解仍使用长按的原句', (tester) async {
    final explained = <Sentence>[];
    await tester.pumpWidget(_host(onExplain: explained.add));
    await tester.pumpAndSettle();
    await _openMenu(tester);
    await tester.pumpWidget(_host(playingIndex: 1, onExplain: explained.add));
    await tester.pumpAndSettle();
    await tester.tap(_action('explain'));
    await tester.pumpAndSettle();
    expect(explained.map((s) => s.index), [0]);
    expect(explained.single.text, _originalText);
    expect(_action('copy'), findsNothing);
  });

  testWidgets('收藏行被移除后仍由列表宿主反馈成功', (tester) async {
    var sentences = [_sentence(0), _sentence(1)];
    late StateSetter updateHost;
    await tester.pumpWidget(
      createTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return ParagraphSentenceListCard(
              sentences: sentences,
              displayMode: RetellDisplayMode.showAll,
              keywordMap: const {},
              playingSentenceIndex: 0,
              bookmarkedSentenceIndices: const {0, 1},
              onSentenceBookmarkToggle: (s) async {
                updateHost(() {
                  sentences = sentences
                      .where((item) => item.index != s.index)
                      .toList();
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openMenu(tester);
    await tester.tap(_action('toggleBookmark'));
    await tester.pumpAndSettle();
    expect(_body(0), findsNothing);
    expect(find.text('Sentence unsaved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('材料切换卸载原列表后丢弃过期菜单结果', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _host(listKey: const ValueKey('audio-a'), onExplain: (_) => calls += 1),
    );
    await tester.pumpAndSettle();
    await _openMenu(tester);
    await tester.pumpWidget(
      _host(listKey: const ValueKey('audio-b'), onExplain: (_) => calls += 1),
    );
    await tester.pumpAndSettle();
    if (_action('explain').evaluate().isNotEmpty) {
      await tester.tap(_action('explain'));
      await tester.pumpAndSettle();
    }
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
}
