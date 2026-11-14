import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/models/favorites_export/favorites_export_options.dart';
import 'package:echo_loop/widgets/favorites/favorites_export_dialog.dart';

import '../../helpers/test_app.dart';

/// 在测试应用中打开弹窗，并记录确认 / 取消的结果
Future<void> _openDialog(
  WidgetTester tester, {
  required int sentenceCount,
  required int wordCount,
  required void Function(FavoritesExportOptions?) onResult,
}) async {
  await tester.pumpWidget(
    createTestApp(
      Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              onResult(
                await showFavoritesExportDialog(
                  context,
                  sentenceCount: sentenceCount,
                  wordCount: wordCount,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('词汇数量为 0 时词汇选项禁用且不勾选，确认仅导出句子', (tester) async {
    FavoritesExportOptions? result;
    await _openDialog(
      tester,
      sentenceCount: 2,
      wordCount: 0,
      onResult: (value) => result = value,
    );

    final tiles = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(tiles[0].value, isTrue);
    expect(tiles[0].onChanged, isNotNull);
    expect(tiles[1].value, isFalse);
    expect(tiles[1].onChanged, isNull);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(result?.includeSentences, isTrue);
    expect(result?.includeWords, isFalse);
  });

  testWidgets('点击取消返回 null', (tester) async {
    var called = false;
    FavoritesExportOptions? result = const FavoritesExportOptions();
    await _openDialog(
      tester,
      sentenceCount: 1,
      wordCount: 1,
      onResult: (value) {
        called = true;
        result = value;
      },
    );

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(result, isNull);
  });

  testWidgets('取消勾选全部内容后确认按钮禁用', (tester) async {
    await _openDialog(tester, sentenceCount: 1, wordCount: 1, onResult: (_) {});

    final checkboxes = find.byType(CheckboxListTile);
    await tester.tap(checkboxes.at(0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );

    await tester.tap(checkboxes.at(1));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
