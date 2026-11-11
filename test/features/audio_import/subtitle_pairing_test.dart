import 'package:echo_loop/features/audio_import/subtitle_pairing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('matchSubtitlesForAudios', () {
    test('基本同名配对', () {
      final result = matchSubtitlesForAudios(['a.mp3', 'a.srt', 'b.m4a']);
      expect(result['a.mp3'], 'a.srt');
      expect(result['b.m4a'], isNull);
    });

    test('大小写不敏感配对', () {
      final result = matchSubtitlesForAudios(['Song.MP3', 'song.SRT']);
      expect(result['Song.MP3'], 'song.SRT');
    });

    test('同名多字幕按 srt > vtt > lrc 优先', () {
      final r1 = matchSubtitlesForAudios(['a.mp3', 'a.vtt', 'a.lrc', 'a.srt']);
      expect(r1['a.mp3'], 'a.srt');

      final r2 = matchSubtitlesForAudios(['a.mp3', 'a.vtt', 'a.lrc']);
      expect(r2['a.mp3'], 'a.vtt');

      final r3 = matchSubtitlesForAudios(['a.mp3', 'a.lrc']);
      expect(r3['a.mp3'], 'a.lrc');
    });

    test('多音频各自配对', () {
      final result = matchSubtitlesForAudios([
        'a.mp3',
        'a.srt',
        'b.mp3',
        'b.lrc',
        'c.wav',
      ]);
      expect(result['a.mp3'], 'a.srt');
      expect(result['b.mp3'], 'b.lrc');
      expect(result['c.wav'], isNull);
    });

    test('无扩展名与无关文件忽略', () {
      final result = matchSubtitlesForAudios([
        'a.mp3',
        'a.srt',
        'noext',
        'cover.jpg',
        'readme.txt',
      ]);
      expect(result.keys, ['a.mp3']);
      expect(result['a.mp3'], 'a.srt');
    });

    test('只有字幕没有音频时结果为空', () {
      final result = matchSubtitlesForAudios(['a.srt', 'b.vtt']);
      expect(result, isEmpty);
    });

    test('subtitleExtensionOf 返回小写扩展名', () {
      expect(subtitleExtensionOf('a.SRT'), 'srt');
      expect(subtitleExtensionOf('noext'), '');
    });

    test('同名多个不同音频后缀：都配对到同一字幕', () {
      final result = matchSubtitlesForAudios(['a.mp3', 'a.wav', 'a.srt']);
      expect(result['a.mp3'], 'a.srt');
      expect(result['a.wav'], 'a.srt');
    });

    test('文件名含点号：按最后一个扩展名切分 stem', () {
      final result = matchSubtitlesForAudios([
        'TPO-30.L1.m4a',
        'TPO-30.L1.srt',
      ]);
      expect(result['TPO-30.L1.m4a'], 'TPO-30.L1.srt');
    });

    test('字幕带音频扩展名前缀（song.m4a.srt）不与 song.m4a 匹配', () {
      // stem 分别为 song / song.m4a，视为不同名，按当前严格同名策略不配对。
      final result = matchSubtitlesForAudios(['song.m4a', 'song.m4a.srt']);
      expect(result['song.m4a'], isNull);
    });

    test('文件名含空格与中文正常配对', () {
      final result = matchSubtitlesForAudios(['第 1 课.mp3', '第 1 课.srt']);
      expect(result['第 1 课.mp3'], '第 1 课.srt');
    });

    test('大小写混合的扩展名也纳入白名单', () {
      final result = matchSubtitlesForAudios(['a.M4A', 'a.Srt']);
      expect(result['a.M4A'], 'a.Srt');
    });

    test('多个音频有的配对有的不配对', () {
      final result = matchSubtitlesForAudios([
        'a.mp3',
        'b.mp3',
        'c.mp3',
        'a.srt',
        'c.lrc',
      ]);
      expect(result['a.mp3'], 'a.srt');
      expect(result['b.mp3'], isNull);
      expect(result['c.mp3'], 'c.lrc');
    });

    test('空输入返回空', () {
      expect(matchSubtitlesForAudios([]), isEmpty);
    });

    test('同名字幕重复出现（同扩展名）不报错，稳定取其一', () {
      final result = matchSubtitlesForAudios(['a.mp3', 'a.srt', 'a.srt']);
      expect(result['a.mp3'], 'a.srt');
    });
  });

  group('classifyImportFiles', () {
    test('区分音频 / 字幕 / 不支持', () {
      final c = classifyImportFiles([
        'a.mp3',
        'a.srt',
        'b.m4a',
        'b.lrc',
        'cover.jpg',
        'notes.txt',
        'noext',
      ]);
      expect(c.audioNames, ['a.mp3', 'b.m4a']);
      expect(c.subtitleNames, ['a.srt', 'b.lrc']);
      expect(c.rejectedExtensions, ['jpg', 'txt', '?']);
    });

    test('全部音频时无字幕无拒绝', () {
      final c = classifyImportFiles(['a.mp3', 'b.wav', 'c.aac', 'd.flac']);
      expect(c.audioNames.length, 4);
      expect(c.subtitleNames, isEmpty);
      expect(c.rejectedExtensions, isEmpty);
    });

    test('全部字幕时无音频', () {
      final c = classifyImportFiles(['a.srt', 'b.vtt', 'c.lrc']);
      expect(c.audioNames, isEmpty);
      expect(c.subtitleNames.length, 3);
    });

    test('大写扩展名归类正确', () {
      final c = classifyImportFiles(['A.MP3', 'A.SRT', 'X.PDF']);
      expect(c.audioNames, ['A.MP3']);
      expect(c.subtitleNames, ['A.SRT']);
      expect(c.rejectedExtensions, ['pdf']);
    });

    test('空输入全为空', () {
      final c = classifyImportFiles([]);
      expect(c.audioNames, isEmpty);
      expect(c.subtitleNames, isEmpty);
      expect(c.rejectedExtensions, isEmpty);
    });

    test('保持输入顺序', () {
      final c = classifyImportFiles(['z.mp3', 'a.mp3', 'm.mp3']);
      expect(c.audioNames, ['z.mp3', 'a.mp3', 'm.mp3']);
    });

    test('mp4/mov/m4v 归入 videoNames 且不进 rejected', () {
      final c = classifyImportFiles(['a.mp4', 'b.mov', 'c.m4v']);
      expect(c.videoNames, ['a.mp4', 'b.mov', 'c.m4v']);
      expect(c.audioNames, isEmpty);
      expect(c.rejectedExtensions, isEmpty);
    });

    test('大写视频扩展名归类正确', () {
      final c = classifyImportFiles(['A.MP4', 'B.MOV']);
      expect(c.videoNames, ['A.MP4', 'B.MOV']);
      expect(c.rejectedExtensions, isEmpty);
    });

    test('音频+视频混选各自分类，视频不落 rejected', () {
      final c = classifyImportFiles(['a.mp3', 'v.mp4', 'a.srt', 'cover.jpg']);
      expect(c.audioNames, ['a.mp3']);
      expect(c.videoNames, ['v.mp4']);
      expect(c.subtitleNames, ['a.srt']);
      expect(c.rejectedExtensions, ['jpg']);
    });

    test('opus/ogg 归入 audioNames 且不进 rejected', () {
      final c = classifyImportFiles(['a.opus', 'b.OGG']);
      expect(c.audioNames, ['a.opus', 'b.OGG']);
      expect(c.rejectedExtensions, isEmpty);
    });

    test('webm/avi 归入 videoNames 且不进 rejected', () {
      final c = classifyImportFiles(['a.webm', 'b.AVI']);
      expect(c.videoNames, ['a.webm', 'b.AVI']);
      expect(c.rejectedExtensions, isEmpty);
    });
  });

  group('isImportablePrimaryMediaExtension', () {
    test('音频和视频扩展名都视为主素材', () {
      expect(isImportablePrimaryMediaExtension('mp3'), isTrue);
      expect(isImportablePrimaryMediaExtension('.m4a'), isTrue);
      expect(isImportablePrimaryMediaExtension('.opus'), isTrue);
      expect(isImportablePrimaryMediaExtension('ogg'), isTrue);
      expect(isImportablePrimaryMediaExtension('mp4'), isTrue);
      expect(isImportablePrimaryMediaExtension('.MOV'), isTrue);
      expect(isImportablePrimaryMediaExtension('.mkv'), isTrue);
      expect(isImportablePrimaryMediaExtension('.webm'), isTrue);
      expect(isImportablePrimaryMediaExtension('avi'), isTrue);
      expect(isImportablePrimaryMediaExtension('txt'), isFalse);
    });

    test('isVideoImportExtension 只识别视频扩展名', () {
      expect(isVideoImportExtension('mp4'), isTrue);
      expect(isVideoImportExtension('.m4v'), isTrue);
      expect(isVideoImportExtension('MKV'), isTrue);
      expect(isVideoImportExtension('.webm'), isTrue);
      expect(isVideoImportExtension('avi'), isTrue);
      expect(isVideoImportExtension('mp3'), isFalse);
      expect(isVideoImportExtension('opus'), isFalse);
    });
  });

  group('视频同名字幕配对', () {
    test('视频与同名字幕配对成功', () {
      final result = matchSubtitlesForAudios(['clip.mp4', 'clip.srt']);
      expect(result['clip.mp4'], 'clip.srt');
    });

    test('mov/m4v/mkv 也参与配对', () {
      final result = matchSubtitlesForAudios([
        'a.mov',
        'a.vtt',
        'b.m4v',
        'b.lrc',
        'c.mkv',
        'c.srt',
      ]);
      expect(result['a.mov'], 'a.vtt');
      expect(result['b.m4v'], 'b.lrc');
      expect(result['c.mkv'], 'c.srt');
    });

    test('音频+视频混选各自配对同名字幕', () {
      final result = matchSubtitlesForAudios([
        'song.mp3',
        'song.srt',
        'movie.mp4',
        'movie.srt',
      ]);
      expect(result['song.mp3'], 'song.srt');
      expect(result['movie.mp4'], 'movie.srt');
    });
  });
}
