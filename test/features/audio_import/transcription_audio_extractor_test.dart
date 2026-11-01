// TranscriptionAudioExtractor 单元测试
//
// 通过 fake AudioTranscodeService 避免真实 ffmpeg 调用，验证：
// 抽取成功返回临时 m4a 路径（位于 tmp/transcription 下、按视频名命名）；
// 抽取失败返回 null。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:echo_loop/features/audio_import/audio_transcode_service.dart';
import 'package:echo_loop/features/audio_import/transcription_audio_extractor.dart';

/// 转码桩：按预设结果返回，记录传入的 source/output。
class _FakeTranscodeService extends AudioTranscodeService {
  _FakeTranscodeService({required this.success});

  final bool success;
  File? lastSource;
  File? lastOutput;

  @override
  Future<bool> transcodeToFile({
    required File source,
    required File output,
  }) async {
    lastSource = source;
    lastOutput = output;
    if (success) {
      await output.parent.create(recursive: true);
      await output.writeAsBytes([0]);
    }
    return success;
  }
}

void main() {
  late Directory dataDir;

  setUp(() async {
    dataDir = await Directory.systemTemp.createTemp('tx_extractor_');
  });

  tearDown(() async {
    if (await dataDir.exists()) await dataDir.delete(recursive: true);
  });

  test('抽取成功 — 返回 tmp/transcription 下按视频名命名的 m4a 路径', () async {
    final fake = _FakeTranscodeService(success: true);
    final extractor = TranscriptionAudioExtractor(transcodeService: fake);
    final videoPath = p.join(dataDir.path, 'audios', 'video-sha.mp4');

    final result = await extractor.extractAudioTrack(
      dataDir: dataDir,
      videoAbsolutePath: videoPath,
    );

    final expected = p.join(
      dataDir.path,
      'tmp',
      'transcription',
      'video-sha.m4a',
    );
    expect(result, expected);
    expect(fake.lastSource!.path, videoPath);
    expect(fake.lastOutput!.path, expected);
    expect(await File(expected).exists(), isTrue);
  });

  test('抽取失败 — 返回 null', () async {
    final fake = _FakeTranscodeService(success: false);
    final extractor = TranscriptionAudioExtractor(transcodeService: fake);

    final result = await extractor.extractAudioTrack(
      dataDir: dataDir,
      videoAbsolutePath: p.join(dataDir.path, 'audios', 'video-sha.mp4'),
    );

    expect(result, isNull);
  });
}
