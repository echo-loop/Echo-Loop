import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/features/media_trim/media_trim_clip.dart';
import 'package:echo_loop/features/media_trim/widgets/media_trim_dialogs.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openDialog(
    WidgetTester tester,
    Future<void> Function(BuildContext context) show,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => show(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  MediaTrimBoundaries free(Duration total) =>
      MediaTrimBoundaries(total: total, sentences: const []);

  testWidgets('自动分段只提供比材料短的段长', (tester) async {
    await openDialog(
      tester,
      (context) => showMediaTrimAutoSplitDialog(
        context,
        boundaries: free(const Duration(minutes: 4)),
        existingClipCount: 0,
      ),
    );
    for (final minutes in [1, 2, 3]) {
      expect(find.byKey(ValueKey('trim-split-$minutes')), findsOneWidget);
    }
    for (final minutes in [5, 10]) {
      expect(find.byKey(ValueKey('trim-split-$minutes')), findsNothing);
    }
  });

  testWidgets('材料不超过最短段长时说明原因，不能应用', (tester) async {
    await openDialog(
      tester,
      (context) => showMediaTrimAutoSplitDialog(
        context,
        boundaries: free(const Duration(seconds: 60)),
        existingClipCount: 2,
      ),
    );
    expect(find.byKey(const ValueKey('trim-split-too-short')), findsOneWidget);
    final apply = tester.widget<FilledButton>(
      find.byKey(const ValueKey('trim-split-apply')),
    );
    expect(apply.onPressed, isNull);
  });

  for (final isManaged in [true, false]) {
    testWidgets('保存弹窗：来自播客 / 共享合集时提示只能存到本地合集 ($isManaged)', (tester) async {
      await openDialog(
        tester,
        (context) => showMediaTrimSaveDialog(
          context,
          clipCount: 2,
          collections: const <db.Collection>[],
          preferredCollectionId: null,
          defaultCollectionName: 'Source · 片段',
          isFromManagedCollection: isManaged,
        ),
      );
      expect(
        find.byKey(const ValueKey('trim-save-local-only')),
        isManaged ? findsOneWidget : findsNothing,
      );
    });
  }
}
