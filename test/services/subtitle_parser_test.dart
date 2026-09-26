import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/services/subtitle_parser.dart';
import 'package:path/path.dart' as p;

void main() {
  group('SubtitleParser.formatDuration', () {
    test('小于 1 小时格式 M:SS', () {
      expect(
        SubtitleParser.formatDuration(const Duration(minutes: 5, seconds: 30)),
        '5:30',
      );
    });

    test('分钟数不补零', () {
      expect(
        SubtitleParser.formatDuration(const Duration(minutes: 1, seconds: 5)),
        '1:05',
      );
    });

    test('秒数补零', () {
      expect(
        SubtitleParser.formatDuration(const Duration(minutes: 3, seconds: 2)),
        '3:02',
      );
    });

    test('超过 1 小时格式 H:MM:SS', () {
      expect(
        SubtitleParser.formatDuration(
          const Duration(hours: 1, minutes: 5, seconds: 30),
        ),
        '1:05:30',
      );
    });

    test('多小时', () {
      expect(
        SubtitleParser.formatDuration(
          const Duration(hours: 2, minutes: 30, seconds: 0),
        ),
        '2:30:00',
      );
    });

    test('零值', () {
      expect(SubtitleParser.formatDuration(Duration.zero), '0:00');
    });

    test('仅有秒数', () {
      expect(
        SubtitleParser.formatDuration(const Duration(seconds: 45)),
        '0:45',
      );
    });

    test('正好 1 小时', () {
      expect(
        SubtitleParser.formatDuration(const Duration(hours: 1)),
        '1:00:00',
      );
    });
  });

  group('SubtitleParser.parseSubtitle', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('subtitle_parser_test_');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Future<String> writeFile(String name, String content) async {
      final f = File(p.join(tmp.path, name));
      await f.writeAsString(content);
      return f.path;
    }

    group('SRT', () {
      test('标准 SRT — 文本、起止时间、index 顺序正确', () async {
        const srt = '''1
00:00:01,000 --> 00:00:03,500
Hello world.

2
00:00:04,000 --> 00:00:06,000
This is a test.
''';
        final path = await writeFile('a.srt', srt);
        final s = await SubtitleParser.parseSubtitle(path);

        expect(s.length, 2);
        expect(s[0].index, 0);
        expect(s[0].text, 'Hello world.');
        expect(s[0].startTime, const Duration(seconds: 1));
        expect(s[0].endTime, const Duration(seconds: 3, milliseconds: 500));
        expect(s[1].index, 1);
        expect(s[1].text, 'This is a test.');
        expect(s[1].startTime, const Duration(seconds: 4));
        expect(s[1].endTime, const Duration(seconds: 6));
      });

      test('CRLF 换行可正常解析', () async {
        const srt = '1\r\n00:00:01,000 --> 00:00:02,000\r\nCRLF line.\r\n\r\n';
        final path = await writeFile('crlf.srt', srt);
        final s = await SubtitleParser.parseSubtitle(path);

        expect(s.length, 1);
        expect(s[0].text, 'CRLF line.');
      });

      test('UTF-8 BOM 可正常解析', () async {
        const srt = '﻿1\n00:00:01,000 --> 00:00:02,000\nBOM start.\n\n';
        final path = await writeFile('bom.srt', srt);
        final s = await SubtitleParser.parseSubtitle(path);

        expect(s.length, 1);
        expect(s[0].text, 'BOM start.');
      });

      test('多行 cue 的文本以换行连接', () async {
        const srt = '''1
00:00:01,000 --> 00:00:03,000
Line one
Line two

2
00:00:04,000 --> 00:00:06,000
Single.
''';
        final path = await writeFile('multi.srt', srt);
        final s = await SubtitleParser.parseSubtitle(path);

        expect(s.length, 2);
        expect(s[0].text, 'Line one\nLine two');
        expect(s[1].text, 'Single.');
      });

      test('HTML 富文本标签被剥除', () async {
        const srt = '''1
00:00:01,000 --> 00:00:03,000
<i>italic</i> and <b>bold</b> text.
''';
        final path = await writeFile('tag.srt', srt);
        final s = await SubtitleParser.parseSubtitle(path);

        expect(s.length, 1);
        expect(s[0].text, isNot(contains('<')));
        expect(s[0].text, isNot(contains('>')));
        expect(s[0].text, contains('italic'));
        expect(s[0].text, contains('bold'));
      });

      test('毫秒精度保留', () async {
        const srt = '''1
00:00:01,234 --> 00:00:02,567
Precise.
''';
        final path = await writeFile('ms.srt', srt);
        final s = await SubtitleParser.parseSubtitle(path);

        expect(s.length, 1);
        expect(s[0].startTime, const Duration(milliseconds: 1234));
        expect(s[0].endTime, const Duration(milliseconds: 2567));
      });

      test('跨小时时间戳', () async {
        const srt = '''1
01:23:45,000 --> 01:23:50,000
Long video.
''';
        final path = await writeFile('hour.srt', srt);
        final s = await SubtitleParser.parseSubtitle(path);

        expect(s.length, 1);
        expect(
          s[0].startTime,
          const Duration(hours: 1, minutes: 23, seconds: 45),
        );
        expect(
          s[0].endTime,
          const Duration(hours: 1, minutes: 23, seconds: 50),
        );
      });
    });

    group('VTT', () {
      test('标准 VTT — 文本、起止时间正确', () async {
        const vtt = '''WEBVTT

00:00:01.000 --> 00:00:03.500
Hello world.

00:00:04.000 --> 00:00:06.000
This is a test.
''';
        final path = await writeFile('a.vtt', vtt);
        final s = await SubtitleParser.parseSubtitle(path);

        expect(s.length, 2);
        expect(s[0].text, 'Hello world.');
        expect(s[0].startTime, const Duration(seconds: 1));
        expect(s[0].endTime, const Duration(seconds: 3, milliseconds: 500));
        expect(s[1].text, 'This is a test.');
      });

      test('cue identifier 可正常解析', () async {
        const vtt = '''WEBVTT

cue-1
00:00:01.000 --> 00:00:03.000
First cue.

cue-2
00:00:04.000 --> 00:00:06.000
Second cue.
''';
        final path = await writeFile('cue.vtt', vtt);
        final s = await SubtitleParser.parseSubtitle(path);

        expect(s.length, 2);
        expect(s[0].text, 'First cue.');
        expect(s[1].text, 'Second cue.');
      });

      test('NOTE 注释块被忽略', () async {
        const vtt = '''WEBVTT

NOTE this is a comment block

00:00:01.000 --> 00:00:02.000
Hello.

NOTE another note

00:00:03.000 --> 00:00:04.000
World.
''';
        final path = await writeFile('note.vtt', vtt);
        final s = await SubtitleParser.parseSubtitle(path);

        expect(s.length, 2);
        expect(s[0].text, 'Hello.');
        expect(s[1].text, 'World.');
      });

      test('省略小时位的时间戳 (mm:ss.ms)', () async {
        const vtt = '''WEBVTT

01:05.000 --> 01:07.000
No hours.
''';
        final path = await writeFile('nohour.vtt', vtt);
        final s = await SubtitleParser.parseSubtitle(path);

        expect(s.length, 1);
        expect(s[0].text, 'No hours.');
        expect(s[0].startTime, const Duration(minutes: 1, seconds: 5));
        expect(s[0].endTime, const Duration(minutes: 1, seconds: 7));
      });

      test('毫秒精度保留', () async {
        const vtt = '''WEBVTT

00:00:01.234 --> 00:00:02.567
Precise.
''';
        final path = await writeFile('ms.vtt', vtt);
        final s = await SubtitleParser.parseSubtitle(path);

        expect(s.length, 1);
        expect(s[0].startTime, const Duration(milliseconds: 1234));
        expect(s[0].endTime, const Duration(milliseconds: 2567));
      });
    });

    group('错误处理与扩展名', () {
      test('文件不存在返回空列表，不抛异常', () async {
        final s = await SubtitleParser.parseSubtitle(
          p.join(tmp.path, 'nonexistent.srt'),
        );
        expect(s, isEmpty);
      });

      test('未知扩展名按 SRT 解析（fallback）', () async {
        const srt = '''1
00:00:01,000 --> 00:00:02,000
Fallback.
''';
        final path = await writeFile('a.txt', srt);
        final s = await SubtitleParser.parseSubtitle(path);

        expect(s.length, 1);
        expect(s[0].text, 'Fallback.');
      });

      test('扩展名大小写不敏感 — .SRT 视作 SRT', () async {
        const srt = '''1
00:00:01,000 --> 00:00:02,000
Upper.
''';
        final path = await writeFile('upper.SRT', srt);
        final s = await SubtitleParser.parseSubtitle(path);

        expect(s.length, 1);
        expect(s[0].text, 'Upper.');
      });

      test('扩展名大小写不敏感 — .VTT 视作 VTT', () async {
        const vtt = '''WEBVTT

00:00:01.000 --> 00:00:02.000
Upper.
''';
        final path = await writeFile('upper.VTT', vtt);
        final s = await SubtitleParser.parseSubtitle(path);

        expect(s.length, 1);
        expect(s[0].text, 'Upper.');
      });
    });
  });

  group('SubtitleParser.parseSubtitleStrict', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('subtitle_parser_strict_');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Future<String> writeFile(String name, String content) async {
      final f = File(p.join(tmp.path, name));
      await f.writeAsString(content);
      return f.path;
    }

    Future<String> writeBytes(String name, List<int> bytes) async {
      final f = File(p.join(tmp.path, name));
      await f.writeAsBytes(bytes);
      return f.path;
    }

    group('成功路径', () {
      test('标准 SRT 返回 sentence 列表', () async {
        const srt = '''1
00:00:01,000 --> 00:00:02,000
Hello.

2
00:00:03,000 --> 00:00:04,000
World.
''';
        final path = await writeFile('a.srt', srt);
        final s = await SubtitleParser.parseSubtitleStrict(path);

        expect(s.length, 2);
        expect(s[0].text, 'Hello.');
        expect(s[1].text, 'World.');
      });

      test('标准 VTT 返回 sentence 列表', () async {
        const vtt = '''WEBVTT

00:00:01.000 --> 00:00:02.000
Hello.
''';
        final path = await writeFile('a.vtt', vtt);
        final s = await SubtitleParser.parseSubtitleStrict(path);

        expect(s.length, 1);
        expect(s[0].text, 'Hello.');
      });

      test('扩展名大写 .SRT 仍接受', () async {
        const srt = '''1
00:00:01,000 --> 00:00:02,000
Upper.
''';
        final path = await writeFile('a.SRT', srt);
        final s = await SubtitleParser.parseSubtitleStrict(path);
        expect(s.length, 1);
      });

      test('扩展名大写 .VTT 仍接受', () async {
        const vtt = '''WEBVTT

00:00:01.000 --> 00:00:02.000
Upper.
''';
        final path = await writeFile('a.VTT', vtt);
        final s = await SubtitleParser.parseSubtitleStrict(path);
        expect(s.length, 1);
      });
    });

    group('unsupportedFormat — 扩展名不在白名单', () {
      test('.lrc 抛 unsupportedFormat，detail 为 lrc', () async {
        const lrc = '[00:01.00]Hello\n[00:03.00]World\n';
        final path = await writeFile('song.lrc', lrc);

        expect(
          () => SubtitleParser.parseSubtitleStrict(path),
          throwsA(
            isA<SubtitleParseException>()
                .having(
                  (e) => e.kind,
                  'kind',
                  SubtitleParseErrorKind.unsupportedFormat,
                )
                .having((e) => e.detail, 'detail', 'lrc'),
          ),
        );
      });

      test('.ass 抛 unsupportedFormat', () async {
        final path = await writeFile('a.ass', 'whatever');
        expect(
          () => SubtitleParser.parseSubtitleStrict(path),
          throwsA(
            isA<SubtitleParseException>().having(
              (e) => e.kind,
              'kind',
              SubtitleParseErrorKind.unsupportedFormat,
            ),
          ),
        );
      });

      test('.ssa 抛 unsupportedFormat', () async {
        final path = await writeFile('a.ssa', 'whatever');
        expect(
          () => SubtitleParser.parseSubtitleStrict(path),
          throwsA(
            isA<SubtitleParseException>().having(
              (e) => e.kind,
              'kind',
              SubtitleParseErrorKind.unsupportedFormat,
            ),
          ),
        );
      });

      test('.txt 抛 unsupportedFormat', () async {
        final path = await writeFile('a.txt', 'whatever');
        expect(
          () => SubtitleParser.parseSubtitleStrict(path),
          throwsA(
            isA<SubtitleParseException>().having(
              (e) => e.kind,
              'kind',
              SubtitleParseErrorKind.unsupportedFormat,
            ),
          ),
        );
      });

      test('无扩展名抛 unsupportedFormat', () async {
        final path = await writeFile('subtitle', 'whatever');
        expect(
          () => SubtitleParser.parseSubtitleStrict(path),
          throwsA(
            isA<SubtitleParseException>().having(
              (e) => e.kind,
              'kind',
              SubtitleParseErrorKind.unsupportedFormat,
            ),
          ),
        );
      });
    });

    group('formatInvalid — 扩展名对但内容无法解析', () {
      test('文件不存在抛 formatInvalid', () async {
        expect(
          () => SubtitleParser.parseSubtitleStrict(
            p.join(tmp.path, 'nonexistent.srt'),
          ),
          throwsA(
            isA<SubtitleParseException>().having(
              (e) => e.kind,
              'kind',
              SubtitleParseErrorKind.formatInvalid,
            ),
          ),
        );
      });

      test('随机二进制内容（无法 readAsString）抛 formatInvalid', () async {
        final path = await writeBytes('binary.srt', [
          0xFF,
          0xFE,
          0xFD,
          0xFC,
          0x00,
          0x01,
        ]);
        expect(
          () => SubtitleParser.parseSubtitleStrict(path),
          throwsA(
            isA<SubtitleParseException>().having(
              (e) => e.kind,
              'kind',
              SubtitleParseErrorKind.formatInvalid,
            ),
          ),
        );
      });

      test('.ass 格式内容改名为 .srt 抛 formatInvalid 或 empty', () async {
        const ass = '''[Script Info]
Title: Default
ScriptType: v4.00+

[Events]
Format: Layer, Start, End, Text
Dialogue: 0,0:00:01.00,0:00:03.00,Hello world.
''';
        final path = await writeFile('fake.srt', ass);
        // 解析器可能抛异常，也可能成功解析为 0 cues；两种都算"出错"，关键是不能成功返回非空
        try {
          final s = await SubtitleParser.parseSubtitleStrict(path);
          fail('应抛异常或为空，实际返回 ${s.length} 句');
        } on SubtitleParseException catch (e) {
          expect(
            e.kind,
            anyOf(
              SubtitleParseErrorKind.formatInvalid,
              SubtitleParseErrorKind.empty,
            ),
          );
        }
      });
    });

    group('empty — 解析成功但 0 cue', () {
      test('空 .vtt 文件抛 empty 或 formatInvalid', () async {
        final path = await writeFile('empty.vtt', '');
        try {
          await SubtitleParser.parseSubtitleStrict(path);
          fail('应抛异常');
        } on SubtitleParseException catch (e) {
          expect(
            e.kind,
            anyOf(
              SubtitleParseErrorKind.empty,
              SubtitleParseErrorKind.formatInvalid,
            ),
          );
        }
      });

      test('仅 WEBVTT 头无 cue 抛 empty', () async {
        final path = await writeFile('head.vtt', 'WEBVTT\n\n');
        try {
          await SubtitleParser.parseSubtitleStrict(path);
          fail('应抛异常');
        } on SubtitleParseException catch (e) {
          expect(
            e.kind,
            anyOf(
              SubtitleParseErrorKind.empty,
              SubtitleParseErrorKind.formatInvalid,
            ),
          );
        }
      });

      test('VTT 仅含 NOTE 块抛 empty', () async {
        final path = await writeFile(
          'note.vtt',
          'WEBVTT\n\nNOTE just a comment\n\n',
        );
        try {
          await SubtitleParser.parseSubtitleStrict(path);
          fail('应抛异常');
        } on SubtitleParseException catch (e) {
          expect(
            e.kind,
            anyOf(
              SubtitleParseErrorKind.empty,
              SubtitleParseErrorKind.formatInvalid,
            ),
          );
        }
      });
    });

    group('parseSubtitleString（从字符串解析，DB 列入口）', () {
      const srt =
          '1\n00:00:00,000 --> 00:00:02,000\nHello world\n\n'
          '2\n00:00:02,000 --> 00:00:04,000\nHow are you\n';

      test('解析 SRT 字符串返回句子', () async {
        final sentences = await SubtitleParser.parseSubtitleString(srt);
        expect(sentences, hasLength(2));
        expect(sentences[0].text, 'Hello world');
        expect(sentences[0].startTime, Duration.zero);
        expect(sentences[1].text, 'How are you');
      });

      test('空字符串返回空列表', () async {
        final sentences = await SubtitleParser.parseSubtitleString('');
        expect(sentences, isEmpty);
      });

      test('相邻重复文本仍保留为独立句子', () async {
        const srt = '''1
00:00:01,000 --> 00:00:02,000
Repeat this line.

2
00:00:02,020 --> 00:00:03,000
Repeat this line.
''';

        final sentences = await SubtitleParser.parseSubtitleString(srt);

        expect(sentences, hasLength(2));
        expect(sentences[0].index, 0);
        expect(sentences[1].index, 1);
        expect(sentences[0].text, sentences[1].text);
        expect(sentences[0].endTime, const Duration(seconds: 2));
        expect(
          sentences[1].startTime,
          const Duration(seconds: 2, milliseconds: 20),
        );
      });

      test('1815 条字幕全部保留且顺序正确', () async {
        String timestamp(int seconds) {
          final hours = seconds ~/ 3600;
          final minutes = (seconds % 3600) ~/ 60;
          final remainingSeconds = seconds % 60;
          return '${hours.toString().padLeft(2, '0')}:'
              '${minutes.toString().padLeft(2, '0')}:'
              '${remainingSeconds.toString().padLeft(2, '0')},000';
        }

        final srt = List.generate(1815, (index) {
          final start = index * 2;
          return '${index + 1}\n'
              '${timestamp(start)} --> ${timestamp(start + 1)}\n'
              'Cue $index';
        }).join('\n\n');

        final sentences = await SubtitleParser.parseSubtitleString(srt);

        expect(sentences, hasLength(1815));
        expect(sentences.first.index, 0);
        expect(sentences.first.text, 'Cue 0');
        expect(sentences.last.index, 1814);
        expect(sentences.last.text, 'Cue 1814');
        expect(sentences.last.startTime, const Duration(seconds: 3628));
      });
    });

    group('parseSubtitleStrictString（字符串严格校验）', () {
      test('有效 SRT 返回句子', () async {
        final sentences = await SubtitleParser.parseSubtitleStrictString(
          '1\n00:00:00,000 --> 00:00:01,000\nHi\n',
        );
        expect(sentences.single.text, 'Hi');
      });

      test('空内容抛 empty 异常', () async {
        try {
          await SubtitleParser.parseSubtitleStrictString('');
          fail('应抛异常');
        } on SubtitleParseException catch (e) {
          expect(
            e.kind,
            anyOf(
              SubtitleParseErrorKind.empty,
              SubtitleParseErrorKind.formatInvalid,
            ),
          );
        }
      });
    });
  });
}
