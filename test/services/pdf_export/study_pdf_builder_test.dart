import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/models/pdf_export/study_pdf_data.dart';
import 'package:echo_loop/services/pdf_export/common/pdf_assets.dart';
import 'package:echo_loop/services/pdf_export/study_pdf_builder.dart';

/// 统计 PDF 字节里的页对象数量（附录另起一页的断言用）
int _pageCount(Uint8List bytes) =>
    RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)).length;

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
      appIconPng: await File('assets/icon/app-icon-96.png').readAsBytes(),
    );
  });

  StudyPdfBuildRequest buildRequest(StudyPdfDocument document) {
    return StudyPdfBuildRequest(
      document: document,
      assets: assets,
      exportDate: '2026-07-02',
      labels: StudyPdfLabels(
        metaDuration: '时长 ${formatStudyPdfDuration(document.durationSeconds)}',
        metaSentences: '${document.sentenceCount} 句',
        metaWords: '${document.wordCount} 词',
        appendixTitle: '附录 · 句子解析',
        grammar: '语法',
        vocabulary: '重点词汇',
        listening: '听力提示',
      ),
    );
  }

  test('中英混排 + 收藏句/收藏词下划线 + 全类型笔记生成有效 PDF', () async {
    final doc = StudyPdfDocument(
      title: '测试材料 Test Material',
      paragraphs: [
        [
          const StudyPdfSentence(
            index: 0,
            text: 'Hello world, this is a bookmarked sentence.',
            isBookmarked: true,
            // "world" 与 "bookmarked" 命中收藏下划线
            savedRanges: [(6, 11), (24, 34)],
            translation: '你好世界，这是一个收藏句。',
            grammar: '主系表结构，bookmarked 为过去分词作定语。',
            vocabulary: 'bookmark 收藏；sentence 句子。',
            listening: 'this is 存在连读现象。',
            vocabNotes: [
              StudyPdfVocabNote(
                term: 'bookmark',
                phonetic: 'ˈbʊkmɑːrk',
                glosses: [
                  StudyPdfGloss(pos: 'n.', text: '书签；收藏'),
                  StudyPdfGloss(pos: 'v.', text: '收藏'),
                ],
              ),
            ],
          ),
          const StudyPdfSentence(index: 1, text: 'A plain sentence.'),
        ],
      ],
    );

    final bytes = await buildStudyPdfBytes(buildRequest(doc));

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('有解析时附录另起一页，无解析时单页无附录', () async {
    const plain = StudyPdfSentence(index: 0, text: 'A plain sentence.');
    const analyzed = StudyPdfSentence(
      index: 0,
      text: 'A sentence with analysis.',
      grammar: '主语 + 介词短语。',
    );

    final without = await buildStudyPdfBytes(
      buildRequest(
        StudyPdfDocument(
          title: 'No Appendix',
          paragraphs: [
            [plain],
          ],
        ),
      ),
    );
    final with_ = await buildStudyPdfBytes(
      buildRequest(
        StudyPdfDocument(
          title: 'With Appendix',
          paragraphs: [
            [analyzed],
          ],
        ),
      ),
    );

    expect(_pageCount(without), 1);
    expect(_pageCount(with_), 2);
  });

  test('尾注/词条锚点与内部链接写入 PDF（note-n / sent-n / vocab-n）', () async {
    final doc = StudyPdfDocument(
      title: 'Anchors',
      paragraphs: [
        [
          const StudyPdfSentence(
            index: 3,
            text: 'A sentence with a message inside.',
            grammar: '语法解析，引用 `a message` 片段。',
            savedRanges: [(18, 25)],
            vocabNotes: [
              StudyPdfVocabNote(
                number: 1,
                term: 'message',
                glosses: [StudyPdfGloss(pos: 'n.', text: '消息')],
                ranges: [(18, 25)],
              ),
            ],
            vocabMarkers: [(25, 1)],
          ),
        ],
      ],
    );

    final bytes = await buildStudyPdfBytes(buildRequest(doc));
    final raw = String.fromCharCodes(bytes);
    // 命名目的地（锚点）与链接注解共用名字：出现 ≥2 次说明两端都写入
    expect('note-1'.allMatches(raw).length, greaterThanOrEqualTo(2));
    expect('sent-3'.allMatches(raw).length, greaterThanOrEqualTo(2));
    expect('vocab-1'.allMatches(raw).length, greaterThanOrEqualTo(2));
  });

  test('全文无词汇旁注时不分栏（正常生成，无 vocab 锚点）', () async {
    final doc = StudyPdfDocument(
      title: 'Single Column',
      paragraphs: [
        [
          const StudyPdfSentence(
            index: 0,
            text: 'A plain sentence without any vocabulary notes.',
            translation: '一个没有词汇笔记的句子。',
          ),
        ],
      ],
    );

    final bytes = await buildStudyPdfBytes(buildRequest(doc));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(String.fromCharCodes(bytes).contains('vocab-'), false);
  });

  test('500 句长文不抛异常（maxPages 生效）', () async {
    final sentences = List.generate(
      500,
      (i) => StudyPdfSentence(
        index: i,
        text:
            'Sentence number $i with some reasonably long content '
            'to fill the page and force pagination across many pages.',
        translation: i.isEven ? '第 $i 句的中文翻译内容。' : null,
        vocabNotes: i % 5 == 0
            ? [
                StudyPdfVocabNote(
                  term: 'word$i',
                  glosses: [StudyPdfGloss(text: '释义 $i')],
                ),
              ]
            : const [],
      ),
    );
    // 每 20 句一段
    final paragraphs = <List<StudyPdfSentence>>[];
    for (var i = 0; i < sentences.length; i += 20) {
      paragraphs.add(
        sentences.sublist(
          i,
          i + 20 > sentences.length ? sentences.length : i + 20,
        ),
      );
    }

    final bytes = await buildStudyPdfBytes(
      buildRequest(StudyPdfDocument(title: 'Long Doc', paragraphs: paragraphs)),
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('控制字符被清洗，超长字段被截断不抛异常', () async {
    final doc = StudyPdfDocument(
      title: 'Edge Cases',
      paragraphs: [
        [
          StudyPdfSentence(
            index: 0,
            text: 'Field\u001Fseparator\u0000embedded.',
            grammar: 'x' * 20000,
          ),
        ],
      ],
    );

    final bytes = await buildStudyPdfBytes(buildRequest(doc));
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('无应用图标（appIconPng 为 null）时优雅降级只渲染品牌文字', () async {
    final doc = StudyPdfDocument(
      title: 'No Icon',
      paragraphs: [
        [const StudyPdfSentence(index: 0, text: 'A sentence.')],
      ],
    );
    final bytes = await buildStudyPdfBytes(
      StudyPdfBuildRequest(
        document: doc,
        assets: PdfAssets(
          latinRegular: assets.latinRegular,
          latinBold: assets.latinBold,
          latinItalic: assets.latinItalic,
          cjkRegular: assets.cjkRegular,
        ),
        exportDate: '2026-07-02',
        labels: const StudyPdfLabels(
          metaDuration: '时长 00:00',
          metaSentences: '1 句',
          metaWords: '2 词',
          appendixTitle: '附录 · 句子解析',
          grammar: '语法',
          vocabulary: '重点词汇',
          listening: '听力提示',
        ),
      ),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('收藏区间越界（截断/脏数据）不抛异常', () async {
    final doc = StudyPdfDocument(
      title: 'Range Edge',
      paragraphs: [
        [
          const StudyPdfSentence(
            index: 0,
            text: 'Short text.',
            savedRanges: [(6, 999)],
          ),
        ],
      ],
    );

    final bytes = await buildStudyPdfBytes(buildRequest(doc));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
