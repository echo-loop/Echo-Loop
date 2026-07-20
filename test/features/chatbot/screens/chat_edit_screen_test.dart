/// ChatEditScreen 测试：预填 / 发送返回文本 / 关闭返回 null / 空文本禁用发送。
library;

import 'package:echo_loop/features/chatbot/screens/chat_edit_screen.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 推入编辑页；[onResult] 在编辑页 pop 后收到结果（发送=文本，关闭=null）。
  Future<void> openEditor(
    WidgetTester tester,
    String initialText,
    void Function(String? result) onResult,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final r = await Navigator.of(context).push<String>(
                    MaterialPageRoute<String>(
                      builder: (_) => ChatEditScreen(initialText: initialText),
                    ),
                  );
                  onResult(r);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('预填原文', (tester) async {
    await openEditor(tester, '原始问题', (_) {});
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '原始问题');
  });

  testWidgets('编辑后点发送返回新文本', (tester) async {
    String? result;
    var done = false;
    await openEditor(tester, '原始问题', (r) {
      result = r;
      done = true;
    });
    await tester.enterText(find.byType(TextField), '改后的问题');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatEditScreen), findsNothing);
    expect(done, isTrue);
    expect(result, '改后的问题');
  });

  testWidgets('点关闭返回 null（取消）', (tester) async {
    String? result = 'sentinel';
    var done = false;
    await openEditor(tester, '原始问题', (r) {
      result = r;
      done = true;
    });
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(ChatEditScreen), findsNothing);
    expect(done, isTrue);
    expect(result, isNull);
  });

  testWidgets('清空后发送按钮禁用', (tester) async {
    await openEditor(tester, '原始问题', (_) {});
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    final sendBtn = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.arrow_upward),
        matching: find.byType(IconButton),
      ),
    );
    expect(sendBtn.onPressed, isNull);
  });
}
