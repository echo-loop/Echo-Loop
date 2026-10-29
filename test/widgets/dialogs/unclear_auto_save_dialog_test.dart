import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/widgets/dialogs/unclear_auto_save_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  /// 把弹窗挂到一个可点击的宿主按钮上，模拟精听页点击「听不太懂」。
  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showUnclearAutoSaveDialog(context),
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

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(UnclearAutoSaveDialog)),
      );

  testWidgets('展示说明文案、开关和确认按钮，开关默认跟随学习设置（开）', (tester) async {
    await pumpHost(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(UnclearAutoSaveDialog)),
    )!;
    expect(find.text(l10n.unclearAutoSaveDialogTitle), findsOneWidget);
    expect(find.text(l10n.unclearAutoSaveDialogMessage), findsOneWidget);
    expect(find.text(l10n.unclearAutoSaveDialogHint), findsOneWidget);
    expect(find.text(l10n.unclearAutoSaveSwitchOn), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });

  testWidgets('弹窗内切换开关即时写回学习设置', (tester) async {
    await pumpHost(tester);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(UnclearAutoSaveDialog)),
    )!;

    expect(
      containerOf(tester).read(learningSettingsProvider).autoSaveOnUnclear,
      isFalse,
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(find.text(l10n.unclearAutoSaveSwitchOff), findsOneWidget);
  });

  testWidgets('点击「知道了」关闭弹窗，且点击外部不会关闭', (tester) async {
    await pumpHost(tester);

    // 外部点击不关闭：弹窗必须由确认按钮结束，保证调用方一定能记录已提示。
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(UnclearAutoSaveDialog), findsOneWidget);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(UnclearAutoSaveDialog)),
    )!;
    await tester.tap(find.text(l10n.unclearAutoSaveDialogConfirm));
    await tester.pumpAndSettle();
    expect(find.byType(UnclearAutoSaveDialog), findsNothing);
  });
}
