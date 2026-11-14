import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:echo_loop/models/favorites_export/favorites_export_data.dart';
import 'package:echo_loop/models/favorites_export/favorites_export_options.dart';
import 'package:echo_loop/screens/favorites_export_preview_screen.dart';
import 'package:echo_loop/services/favorites_export/favorites_export_service.dart';
import 'package:echo_loop/services/favorites_export/favorites_pdf_builder.dart';

import '../helpers/test_app.dart';

class _MockFavoritesExportService extends Mock
    implements FavoritesExportService {}

void main() {
  late _MockFavoritesExportService service;

  const request = FavoritesExportRequest(
    options: FavoritesExportOptions(),
    format: FavoritesExportFormat.pdf,
  );

  setUpAll(() {
    registerFallbackValue(const FavoritesExportOptions());
    registerFallbackValue(FavoritesExportFormat.pdf);
    registerFallbackValue(
      (FavoritesExportDocument _) => const FavoritesExportLabels(
        title: '',
        sentencesSection: '',
        wordsSection: '',
        unknownSource: '',
        metaSentences: '',
        metaWords: '',
      ),
    );
  });

  setUp(() {
    service = _MockFavoritesExportService();
  });

  Future<void> pumpScreen(WidgetTester tester) {
    return tester.pumpWidget(
      createTestApp(
        FavoritesExportPreviewScreen(
          request: request,
          service: service,
          previewBuilder: (_, bytes) => Text('preview:${bytes.length}'),
        ),
      ),
    );
  }

  testWidgets('生成成功后展示预览', (tester) async {
    when(
      () => service.export(
        options: any(named: 'options'),
        format: any(named: 'format'),
        targetLanguage: any(named: 'targetLanguage'),
        buildLabels: any(named: 'buildLabels'),
      ),
    ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('preview:3'), findsOneWidget);
    verify(
      () => service.export(
        options: request.options,
        format: FavoritesExportFormat.pdf,
        targetLanguage: any(named: 'targetLanguage'),
        buildLabels: any(named: 'buildLabels'),
      ),
    ).called(1);
  });

  testWidgets('生成失败显示错误态，点击重试重新生成', (tester) async {
    var calls = 0;
    when(
      () => service.export(
        options: any(named: 'options'),
        format: any(named: 'format'),
        targetLanguage: any(named: 'targetLanguage'),
        buildLabels: any(named: 'buildLabels'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw StateError('boom');
      return Uint8List.fromList([9]);
    });

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('boom'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('preview:1'), findsOneWidget);
  });
}
