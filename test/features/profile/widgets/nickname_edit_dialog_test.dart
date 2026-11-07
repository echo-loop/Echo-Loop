import 'package:echo_loop/features/profile/widgets/nickname_edit_dialog.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpDialog(
  WidgetTester tester, {
  required String? initialNickname,
  required Future<void> Function(String nickname) onSave,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => NicknameEditDialog(
                initialNickname: initialNickname,
                onSave: onSave,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

FilledButton _saveButton(WidgetTester tester) {
  return tester.widget<FilledButton>(find.byType(FilledButton));
}

void main() {
  testWidgets('未修改时保存按钮禁用', (tester) async {
    await _pumpDialog(tester, initialNickname: 'Ann', onSave: (_) async {});

    expect(_saveButton(tester).onPressed, isNull);
  });

  testWidgets('超过 30 个字符时显示错误并禁用保存', (tester) async {
    await _pumpDialog(tester, initialNickname: 'Ann', onSave: (_) async {});

    await tester.enterText(find.byType(TextField), 'a' * 31);
    await tester.pump();

    expect(find.text('Nickname can be up to 30 characters'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);
  });

  testWidgets('保存时提交去除首尾空白后的昵称并关闭对话框', (tester) async {
    String? savedNickname;
    await _pumpDialog(
      tester,
      initialNickname: 'Ann',
      onSave: (nickname) async => savedNickname = nickname,
    );

    await tester.enterText(find.byType(TextField), '  Anna  ');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(savedNickname, 'Anna');
    expect(find.byType(NicknameEditDialog), findsNothing);
  });

  testWidgets('保存失败时保持对话框打开并提示错误', (tester) async {
    await _pumpDialog(
      tester,
      initialNickname: 'Ann',
      onSave: (_) async => throw Exception('network down'),
    );

    await tester.enterText(find.byType(TextField), 'Anna');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(NicknameEditDialog), findsOneWidget);
    expect(
      find.text("Couldn't save your profile. Please try again."),
      findsOneWidget,
    );
  });
}
