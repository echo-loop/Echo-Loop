/// AppSelectableText 的文字缩放回归：正文必须跟随系统「更大字体」。
///
/// 正文是 RichText，默认 `TextScaler.noScaling`，不显式传入会在系统大字下
/// 保持 100%，与同屏的 Text 不一致。
library;

import 'package:echo_loop/widgets/selection/app_selectable_text.dart';
import 'package:echo_loop/widgets/selection/selection_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('系统文字缩放作用于正文，与 Text 一致', (tester) async {
    const text = 'Hello world';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: AppSelectableText(
              text: text,
              style: const TextStyle(fontSize: 20),
              wordRange: (_) => null,
              spanBuilder: (_) => [const TextSpan(text: text)],
              actionsBuilder: (_) => const <SelectionToolbarAction>[],
            ),
          ),
        ),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    expect(paragraph.textScaler.scale(10), 15);
  });
}
