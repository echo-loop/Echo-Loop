import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/models/favorites_export/favorites_export_data.dart';
import 'package:echo_loop/services/favorites_export/favorites_pdf_builder.dart';
import 'package:echo_loop/services/pdf_export/common/pdf_assets.dart';

/// 统计 PDF 字节里的页对象数量
int _pageCount(Uint8List bytes) =>
    RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)).length;

const _labels = FavoritesExportLabels(
  title: '收藏导出',
  sentencesSection: '句子',
  wordsSection: '词汇',
  unknownSource: '未知来源',
  metaSentences: '2 句',
  metaWords: '1 词',
);

void main() {
  late PdfAssets assets;

  setUpAll(() async {
    // VM 测试直接从工程 assets 读字体（无需 rootBundle）
    assets = PdfAssets(
      latinRegular: await File('assets/fonts/pdf/NotoSans-Regular.ttf')
          .readAsBytes(),
      latinBold: await File('assets/fonts/pdf/NotoSans-Bold.ttf').readAsBytes(),
      latinItalic: await File('assets/fonts/pdf/NotoSans-Italic.ttf')
          .readAsBytes(),
      cjkRegular: await File('assets/fonts/pdf/NotoSansSC-Regular.ttf')
          .readAsBytes(),
    );
  });

  FavoritesPdfBuildRequest request(FavoritesExportDocument document) {
    return FavoritesPdfBuildRequest(
      document: document,
      assets: assets,
      exportDate: '2026-11-14',
      labels: _labels,
    );
  }

  test('输出合法 PDF 字节，句子与词汇分区都可为空', () async {
    final bytes = await buildFavoritesPdfBytes(
      request(const FavoritesExportDocument()),
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('同时包含句子与词汇（含未知来源与无译文）正常生成', () async {
    final bytes = await buildFavoritesPdfBytes(
      request(
        const FavoritesExportDocument(
          sentenceGroups: [
            FavoriteSentenceGroup(
              sourceName: 'Alpha',
              sourceMedia: FavoriteSourceMedia.video,
              sentences: [
                FavoriteSentence(
                  text: 'This is a test.',
                  translation: '这是一个测试。',
                ),
                FavoriteSentence(text: 'Goodbye now.'),
              ],
            ),
            FavoriteSentenceGroup(
              sourceName: null,
              sentences: [FavoriteSentence(text: 'Orphan sentence.')],
            ),
          ],
          vocabulary: [
            FavoriteVocabularyEntry(
              term: 'Look up',
              isPhrase: true,
              definition: '查阅',
              example: FavoriteExample(
                text: 'Look it up.',
                translation: '查一下。',
              ),
              sourceSentence: 'Look it up tonight.',
              sourceName: 'Beta',
              sourceMedia: FavoriteSourceMedia.audio,
            ),
            FavoriteVocabularyEntry(term: 'apple', isPhrase: false),
          ],
        ),
      ),
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(_pageCount(bytes), greaterThanOrEqualTo(1));
  });

  test('大量条目自动分页，控制字符与超长字段不抛异常', () async {
    final longText = 'word\u0001 ' * 1200;
    final bytes = await buildFavoritesPdfBytes(
      request(
        FavoritesExportDocument(
          sentenceGroups: [
            FavoriteSentenceGroup(
              sourceName: 'Long',
              sentences: [
                for (var i = 0; i < 300; i++)
                  FavoriteSentence(text: 'Sentence $i with some words.'),
              ],
            ),
          ],
          vocabulary: [
            FavoriteVocabularyEntry(
              term: longText,
              isPhrase: false,
              definition: longText,
            ),
          ],
        ),
      ),
    );

    expect(_pageCount(bytes), greaterThan(3));
  });
}
