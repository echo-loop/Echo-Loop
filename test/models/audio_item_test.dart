import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/audio_item.dart';

void main() {
  group('AudioItem', () {
    final now = DateTime(2026, 1, 15, 10, 30);

    AudioItem createSample({
      String? transcriptPath = 'transcripts/test.srt',
      int totalDuration = 120,
      int sentenceCount = 10,
      int wordCount = 50,
      bool isPinned = false,
      TranscriptSource? transcriptSource,
      String? audioSha256,
      String? originalAudioSha256,
      String? transcriptLanguage,
      AudioImportSourceType? importSourceType,
      String? importSourceUrl,
    }) {
      return AudioItem(
        id: 'audio-1',
        name: '测试音频',
        audioPath: 'audios/test.mp3',
        transcriptPath: transcriptPath,
        addedDate: now,
        totalDuration: totalDuration,
        sentenceCount: sentenceCount,
        wordCount: wordCount,
        isPinned: isPinned,
        transcriptSource: transcriptSource,
        audioSha256: audioSha256,
        originalAudioSha256: originalAudioSha256,
        transcriptLanguage: transcriptLanguage,
        importSourceType: importSourceType,
        importSourceUrl: importSourceUrl,
      );
    }

    group('toJson / fromJson 往返序列化', () {
      test('完整字段往返一致', () {
        final item = createSample();
        final json = item.toJson();
        final restored = AudioItem.fromJson(json);

        expect(restored.id, item.id);
        expect(restored.name, item.name);
        expect(restored.audioPath, item.audioPath);
        expect(restored.transcriptPath, item.transcriptPath);
        expect(restored.addedDate, item.addedDate);
        expect(restored.totalDuration, item.totalDuration);
        expect(restored.sentenceCount, item.sentenceCount);
        expect(restored.wordCount, item.wordCount);
        expect(restored.isPinned, item.isPinned);
      });

      test('导入来源字段往返一致', () {
        final item = createSample(
          importSourceType: AudioImportSourceType.directUrl,
          importSourceUrl: 'https://example.com/audio.mp3',
        );
        final json = item.toJson();
        final restored = AudioItem.fromJson(json);

        expect(restored.importSourceType, AudioImportSourceType.directUrl);
        expect(restored.importSourceUrl, 'https://example.com/audio.mp3');
      });

      test('isPinned=true 往返一致', () {
        final item = createSample(isPinned: true);
        final json = item.toJson();
        final restored = AudioItem.fromJson(json);

        expect(restored.isPinned, isTrue);
      });

      test('transcriptPath 为 null 时往返一致', () {
        final item = createSample(transcriptPath: null);
        final json = item.toJson();
        final restored = AudioItem.fromJson(json);

        expect(restored.transcriptPath, isNull);
      });
    });

    group('copyWith', () {
      test('部分字段覆盖', () {
        final item = createSample();
        final copied = item.copyWith(name: '新名称', totalDuration: 300);

        expect(copied.name, '新名称');
        expect(copied.totalDuration, 300);
        // 未修改的字段保持不变
        expect(copied.id, item.id);
        expect(copied.audioPath, item.audioPath);
        expect(copied.transcriptPath, item.transcriptPath);
        expect(copied.addedDate, item.addedDate);
        expect(copied.sentenceCount, item.sentenceCount);
        expect(copied.wordCount, item.wordCount);
      });

      test('sentenceCount 和 wordCount 覆盖', () {
        final item = createSample();
        final copied = item.copyWith(sentenceCount: 20, wordCount: 100);

        expect(copied.sentenceCount, 20);
        expect(copied.wordCount, 100);
      });

      test('isPinned 覆盖', () {
        final item = createSample(isPinned: false);
        final copied = item.copyWith(isPinned: true);

        expect(copied.isPinned, isTrue);
        // 未修改的字段保持不变
        expect(copied.id, item.id);
        expect(copied.name, item.name);
      });

      test('导入来源支持显式清空', () {
        final item = createSample(
          importSourceType: AudioImportSourceType.directUrl,
          importSourceUrl: 'https://example.com/audio.mp3',
        );
        final copied = item.copyWith(
          importSourceType: null,
          importSourceUrl: null,
        );

        expect(copied.importSourceType, isNull);
        expect(copied.importSourceUrl, isNull);
      });

      test('不传参数时保持原值', () {
        final item = createSample();
        final copied = item.copyWith();

        expect(copied.id, item.id);
        expect(copied.name, item.name);
      });
    });

    group('hasTranscript', () {
      // 字幕内容入库后，hasTranscript 以 transcriptSource 是否有值为准
      // （内容存 DB 列，不再依赖 transcriptPath）。
      test('有 transcriptSource 时返回 true（transcriptPath 为 null 也成立）', () {
        final item = createSample(
          transcriptPath: null,
          transcriptSource: TranscriptSource.ai,
        );
        expect(item.hasTranscript, isTrue);
      });

      test('transcriptSource 为 null 时返回 false（即使有遗留 transcriptPath）', () {
        final item = createSample(
          transcriptPath: 'transcripts/test.srt',
          transcriptSource: null,
        );
        expect(item.hasTranscript, isFalse);
      });

      test('本地字幕来源返回 true', () {
        final item = createSample(transcriptSource: TranscriptSource.local);
        expect(item.hasTranscript, isTrue);
      });

      test('无字幕（source=null）时 isAudioReady 仍可为 true（有音频但没字幕）', () {
        final item = createSample(transcriptPath: null, transcriptSource: null);
        expect(item.hasTranscript, isFalse);
        expect(item.isAudioReady, isTrue);
      });
    });

    group('getFullTranscriptPath', () {
      // 字幕内容入库后，DB-only 行 transcriptPath=null 即使 hasTranscript=true 也
      // 必须安全返回 null（而非 transcriptPath! 空断言崩溃）。
      test('DB-only 行（source 非空、path=null）返回 null 不崩溃', () async {
        final item = createSample(
          transcriptPath: null,
          transcriptSource: TranscriptSource.ai,
        );
        expect(item.hasTranscript, isTrue);
        expect(await item.getFullTranscriptPath(), isNull);
      });

      test('transcriptPath 为空字符串返回 null', () async {
        final item = createSample(
          transcriptPath: '',
          transcriptSource: TranscriptSource.local,
        );
        expect(await item.getFullTranscriptPath(), isNull);
      });
    });

    group('isAudioReady', () {
      test('audioPath 非空 → true', () {
        final item = createSample();
        expect(item.isAudioReady, isTrue);
      });

      test('audioPath=null → false（官方合集未下载占位行）', () {
        final item = AudioItem(
          id: 'oc-1',
          name: '官方音频',
          audioPath: null,
          transcriptPath: null,
          addedDate: now,
          remoteAudioId: 'r-1',
        );
        expect(item.isAudioReady, isFalse);
        expect(item.hasTranscript, isFalse);
      });
    });

    test('fromJson 处理缺失 totalDuration 字段（默认 0）', () {
      final json = {
        'id': 'audio-1',
        'name': '测试',
        'audioPath': 'audios/test.mp3',
        'transcriptPath': null,
        'addedDate': now.toIso8601String(),
        // 无 totalDuration
      };
      final item = AudioItem.fromJson(json);
      expect(item.totalDuration, 0);
    });

    test('fromJson 处理缺失 sentenceCount/wordCount 字段（默认 0）', () {
      final json = {
        'id': 'audio-1',
        'name': '测试',
        'audioPath': 'audios/test.mp3',
        'transcriptPath': null,
        'addedDate': now.toIso8601String(),
        'totalDuration': 60,
        // 无 sentenceCount / wordCount
      };
      final item = AudioItem.fromJson(json);
      expect(item.sentenceCount, 0);
      expect(item.wordCount, 0);
    });

    test('fromJson 处理缺失 isPinned 字段（默认 false）', () {
      final json = {
        'id': 'audio-1',
        'name': '测试',
        'audioPath': 'audios/test.mp3',
        'transcriptPath': null,
        'addedDate': now.toIso8601String(),
        'totalDuration': 60,
        // 无 isPinned
      };
      final item = AudioItem.fromJson(json);
      expect(item.isPinned, isFalse);
    });

    test('默认 sentenceCount、wordCount 为 0，isPinned 为 false', () {
      final item = AudioItem(
        id: 'audio-1',
        name: '测试',
        audioPath: 'audios/test.mp3',
        addedDate: now,
      );
      expect(item.sentenceCount, 0);
      expect(item.wordCount, 0);
      expect(item.isPinned, isFalse);
    });

    group('TranscriptSource 枚举', () {
      test('fromIndex 正确映射', () {
        expect(TranscriptSource.fromIndex(0), TranscriptSource.local);
        expect(TranscriptSource.fromIndex(1), TranscriptSource.ai);
        expect(TranscriptSource.fromIndex(2), TranscriptSource.device);
        expect(TranscriptSource.fromIndex(null), isNull);
        expect(TranscriptSource.fromIndex(99), isNull);
        expect(TranscriptSource.fromIndex(-1), isNull);
      });

      test('index 属性正确（既有值不变，device 追加在末尾）', () {
        expect(TranscriptSource.local.index, 0);
        expect(TranscriptSource.ai.index, 1);
        expect(TranscriptSource.device.index, 2);
      });
    });

    group('transcriptSource 字段', () {
      test('toJson / fromJson 往返一致 — local', () {
        final item = createSample(transcriptSource: TranscriptSource.local);
        final json = item.toJson();
        expect(json['transcriptSource'], 0);

        final restored = AudioItem.fromJson(json);
        expect(restored.transcriptSource, TranscriptSource.local);
      });

      test('toJson / fromJson 往返一致 — ai', () {
        final item = createSample(transcriptSource: TranscriptSource.ai);
        final json = item.toJson();
        expect(json['transcriptSource'], 1);

        final restored = AudioItem.fromJson(json);
        expect(restored.transcriptSource, TranscriptSource.ai);
      });

      test('toJson / fromJson 往返一致 — device', () {
        final item = createSample(transcriptSource: TranscriptSource.device);
        final json = item.toJson();
        expect(json['transcriptSource'], 2);

        final restored = AudioItem.fromJson(json);
        expect(restored.transcriptSource, TranscriptSource.device);
      });

      test('toJson / fromJson 往返一致 — null', () {
        final item = createSample(transcriptSource: null);
        final json = item.toJson();
        expect(json['transcriptSource'], isNull);

        final restored = AudioItem.fromJson(json);
        expect(restored.transcriptSource, isNull);
      });

      test('copyWith 覆盖为 ai', () {
        final item = createSample(transcriptSource: TranscriptSource.local);
        final copied = item.copyWith(transcriptSource: TranscriptSource.ai);
        expect(copied.transcriptSource, TranscriptSource.ai);
      });

      test('copyWith 不传参保持原值', () {
        final item = createSample(transcriptSource: TranscriptSource.ai);
        final copied = item.copyWith();
        expect(copied.transcriptSource, TranscriptSource.ai);
      });

      test('copyWith 显式传 null', () {
        final item = createSample(transcriptSource: TranscriptSource.local);
        final copied = item.copyWith(transcriptSource: null);
        expect(copied.transcriptSource, isNull);
      });
    });

    group('audioSha256 字段', () {
      test('toJson / fromJson 往返一致', () {
        final item = createSample(audioSha256: 'abc123sha');
        final json = item.toJson();
        expect(json['audioSha256'], 'abc123sha');

        final restored = AudioItem.fromJson(json);
        expect(restored.audioSha256, 'abc123sha');
      });

      test('copyWith 覆盖', () {
        final item = createSample();
        final copied = item.copyWith(audioSha256: 'new-sha');
        expect(copied.audioSha256, 'new-sha');
      });

      test('copyWith 不传参保持原值', () {
        final item = createSample(audioSha256: 'keep-me');
        final copied = item.copyWith();
        expect(copied.audioSha256, 'keep-me');
      });

      test('copyWith 显式传 null', () {
        final item = createSample(audioSha256: 'to-clear');
        final copied = item.copyWith(audioSha256: null);
        expect(copied.audioSha256, isNull);
      });
    });

    group('originalAudioSha256 字段', () {
      test('toJson / fromJson 往返一致', () {
        final item = createSample(originalAudioSha256: 'source-sha');
        final json = item.toJson();
        expect(json['originalAudioSha256'], 'source-sha');

        final restored = AudioItem.fromJson(json);
        expect(restored.originalAudioSha256, 'source-sha');
      });

      test('copyWith 覆盖', () {
        final item = createSample();
        final copied = item.copyWith(originalAudioSha256: 'new-source-sha');
        expect(copied.originalAudioSha256, 'new-source-sha');
      });

      test('copyWith 不传参保持原值', () {
        final item = createSample(originalAudioSha256: 'keep-source');
        final copied = item.copyWith();
        expect(copied.originalAudioSha256, 'keep-source');
      });

      test('copyWith 显式传 null', () {
        final item = createSample(originalAudioSha256: 'to-clear');
        final copied = item.copyWith(originalAudioSha256: null);
        expect(copied.originalAudioSha256, isNull);
      });
    });

    group('transcriptLanguage 字段', () {
      test('toJson / fromJson 往返一致', () {
        final item = createSample(transcriptLanguage: 'en');
        final json = item.toJson();
        expect(json['transcriptLanguage'], 'en');

        final restored = AudioItem.fromJson(json);
        expect(restored.transcriptLanguage, 'en');
      });

      test('copyWith 覆盖', () {
        final item = createSample(transcriptLanguage: 'en');
        final copied = item.copyWith(transcriptLanguage: 'multi');
        expect(copied.transcriptLanguage, 'multi');
      });

      test('copyWith 显式传 null', () {
        final item = createSample(transcriptLanguage: 'en');
        final copied = item.copyWith(transcriptLanguage: null);
        expect(copied.transcriptLanguage, isNull);
      });
    });

    test(
      'fromJson 处理缺失 transcriptSource/audioSha256/originalAudioSha256/transcriptLanguage 字段',
      () {
        final json = {
          'id': 'audio-1',
          'name': '测试',
          'audioPath': 'audios/test.mp3',
          'transcriptPath': null,
          'addedDate': now.toIso8601String(),
          'totalDuration': 60,
          // 无新增字段
        };
        final item = AudioItem.fromJson(json);
        expect(item.transcriptSource, isNull);
        expect(item.audioSha256, isNull);
        expect(item.originalAudioSha256, isNull);
        expect(item.transcriptLanguage, isNull);
      },
    );

    test('默认 transcriptSource, audioSha256, transcriptLanguage 为 null', () {
      final item = AudioItem(
        id: 'audio-1',
        name: '测试',
        audioPath: 'audios/test.mp3',
        addedDate: now,
      );
      expect(item.transcriptSource, isNull);
      expect(item.audioSha256, isNull);
      expect(item.originalAudioSha256, isNull);
      expect(item.transcriptLanguage, isNull);
    });

    group('官方合集字段（remoteAudioId）+ audioPath nullable', () {
      test('默认 remoteAudioId=null（用户自建音频）', () {
        final item = AudioItem(
          id: 'audio-1',
          name: '测试',
          audioPath: 'audios/test.mp3',
          addedDate: now,
        );
        expect(item.remoteAudioId, isNull);
        expect(item.isAudioReady, isTrue);
      });

      test('官方合集未下载音频：remoteAudioId 有值，audioPath=null', () {
        final item = AudioItem(
          id: 'audio-1',
          name: 'Day 1',
          audioPath: null,
          addedDate: now,
          remoteAudioId: 'remote-audio-1',
        );
        expect(item.remoteAudioId, 'remote-audio-1');
        expect(item.isAudioReady, isFalse);
      });

      test('toJson / fromJson 往返一致（audioPath=null 场景）', () {
        final item = AudioItem(
          id: 'a1',
          name: 'n',
          audioPath: null,
          addedDate: now,
          remoteAudioId: 'r1',
        );
        final restored = AudioItem.fromJson(item.toJson());
        expect(restored.remoteAudioId, 'r1');
        expect(restored.audioPath, isNull);
        expect(restored.isAudioReady, isFalse);
      });

      test('copyWith 能覆盖 audioPath（从 null 变成非 null，模拟下载完成）', () {
        final item = AudioItem(
          id: 'a1',
          name: 'n',
          audioPath: null,
          addedDate: now,
          remoteAudioId: 'r1',
        );
        final copied = item.copyWith(
          audioPath: 'audios/official/hash.m4a',
          transcriptSource: TranscriptSource.ai,
        );
        expect(copied.isAudioReady, isTrue);
        expect(copied.hasTranscript, isTrue);
      });

      test('copyWith 能把 audioPath 显式传 null（模拟重置）', () {
        final item = createSample();
        final copied = item.copyWith(audioPath: null);
        expect(copied.audioPath, isNull);
        expect(copied.isAudioReady, isFalse);
      });
    });

    group('AudioContentStatus 枚举', () {
      test('fromIndex 正确映射', () {
        expect(AudioContentStatus.fromIndex(0), AudioContentStatus.ok);
        expect(
          AudioContentStatus.fromIndex(1),
          AudioContentStatus.suspectEmpty,
        );
        expect(AudioContentStatus.fromIndex(null), isNull);
        expect(AudioContentStatus.fromIndex(99), isNull);
        expect(AudioContentStatus.fromIndex(-1), isNull);
      });

      test('index 属性正确', () {
        expect(AudioContentStatus.ok.index, 0);
        expect(AudioContentStatus.suspectEmpty.index, 1);
      });
    });

    group('contentStatus 字段', () {
      test('默认 null（未检测）', () {
        expect(createSample().contentStatus, isNull);
      });

      test('toJson / fromJson 往返一致 — suspectEmpty', () {
        final item = createSample().copyWith(
          contentStatus: AudioContentStatus.suspectEmpty,
        );
        final json = item.toJson();
        expect(json['contentStatus'], 1);

        final restored = AudioItem.fromJson(json);
        expect(restored.contentStatus, AudioContentStatus.suspectEmpty);
      });

      test('toJson / fromJson 往返一致 — null', () {
        final item = createSample();
        final json = item.toJson();
        expect(json['contentStatus'], isNull);

        final restored = AudioItem.fromJson(json);
        expect(restored.contentStatus, isNull);
      });

      test('fromJson 缺失字段默认 null', () {
        final json = {
          'id': 'a1',
          'name': 'n',
          'audioPath': 'audios/test.mp3',
          'transcriptPath': null,
          'addedDate': now.toIso8601String(),
          'totalDuration': 60,
        };
        expect(AudioItem.fromJson(json).contentStatus, isNull);
      });

      test('copyWith 覆盖为 ok', () {
        final item = createSample().copyWith(
          contentStatus: AudioContentStatus.suspectEmpty,
        );
        final copied = item.copyWith(contentStatus: AudioContentStatus.ok);
        expect(copied.contentStatus, AudioContentStatus.ok);
      });

      test('copyWith 不传参保持原值', () {
        final item = createSample().copyWith(
          contentStatus: AudioContentStatus.suspectEmpty,
        );
        expect(item.copyWith().contentStatus, AudioContentStatus.suspectEmpty);
      });

      test('copyWith 显式传 null', () {
        final item = createSample().copyWith(
          contentStatus: AudioContentStatus.suspectEmpty,
        );
        expect(item.copyWith(contentStatus: null).contentStatus, isNull);
      });
    });

    group('originalDate', () {
      test('默认 null（用户自建音频）', () {
        expect(createSample().originalDate, isNull);
      });

      test('toJson / fromJson 往返一致', () {
        final date = DateTime.utc(2020, 5, 1);
        final item = createSample().copyWith(originalDate: date);
        final restored = AudioItem.fromJson(item.toJson());
        expect(restored.originalDate, date);
      });

      test('copyWith 能显式覆盖为 null', () {
        final item = createSample().copyWith(
          originalDate: DateTime.utc(2020, 5, 1),
        );
        final reset = item.copyWith(originalDate: null);
        expect(reset.originalDate, isNull);
      });
    });
  });
}
