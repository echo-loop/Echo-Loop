/// EdgeTtsEngine 单元测试
///
/// 覆盖：成功写 mp3、服务端失败重试一次、网络失败不重试并记录类型、成功后清除失败记录。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:echo_loop/services/tts/edge_tts_engine.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';
import 'package:flutter_edge_tts/flutter_edge_tts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  const config = TtsSpeechConfig(
    languageTag: 'en-GB',
    voiceName: 'en-GB-RyanNeural',
  );

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('edge_tts_engine_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  /// 按顺序返回预设结果（字节或异常）的 fake 合成器，记录每次调用的参数。
  EdgeSynthesize scripted(
    List<Object> outcomes,
    List<({String text, String voice, String languageTag})> calls,
  ) {
    var index = 0;
    return ({
      required String text,
      required String voice,
      required String languageTag,
    }) async {
      calls.add((text: text, voice: voice, languageTag: languageTag));
      final outcome = outcomes[index++];
      if (outcome is Exception) throw outcome;
      return outcome as Uint8List;
    };
  }

  Future<TtsSynthesisResult?> synthesize(EdgeTtsEngine engine) =>
      engine.synthesize(
        'hello',
        outputDir: tempDir.path,
        baseName: 'key',
        config: config,
      );

  test('成功 → 写入 mp3 文件，按 config 的音色与语言合成', () async {
    final calls = <({String text, String voice, String languageTag})>[];
    final engine = EdgeTtsEngine(
      synthesizer: scripted([
        Uint8List.fromList([1, 2, 3]),
      ], calls),
    );

    final result = await synthesize(engine);

    expect(result, isNotNull);
    expect(result!.format, 'mp3');
    expect(result.filePath, p.join(tempDir.path, 'key.mp3'));
    expect(File(result.filePath).readAsBytesSync(), [1, 2, 3]);
    expect(calls.single.voice, 'en-GB-RyanNeural');
    expect(calls.single.languageTag, 'en-GB');
  });

  test('服务端偶发空音频 → 重试一次后成功，不记录失败', () async {
    final calls = <({String text, String voice, String languageTag})>[];
    final recorder = EdgeTtsFailureRecorder();
    final engine = EdgeTtsEngine(
      failureRecorder: recorder,
      synthesizer: scripted([
        const EdgeTtsException('empty_audio', 'empty'),
        Uint8List.fromList([9]),
      ], calls),
    );

    final result = await synthesize(engine);

    expect(result, isNotNull);
    expect(calls, hasLength(2));
    expect(recorder.lastFailure, isNull);
  });

  test('服务端连续失败 → 返回 null 并记录 service', () async {
    final calls = <({String text, String voice, String languageTag})>[];
    final recorder = EdgeTtsFailureRecorder();
    final engine = EdgeTtsEngine(
      failureRecorder: recorder,
      synthesizer: scripted([
        const EdgeTtsException(
          'connection_failed',
          'failed',
          cause: EdgeTtsException('websocket_upgrade_failed', '403'),
        ),
        const EdgeTtsException('empty_audio', 'empty'),
      ], calls),
    );

    expect(await synthesize(engine), isNull);
    expect(calls, hasLength(2));
    expect(recorder.lastFailure, EdgeTtsFailureKind.service);
  });

  test('网络不可达 → 不重试，返回 null 并记录 network', () async {
    final calls = <({String text, String voice, String languageTag})>[];
    final recorder = EdgeTtsFailureRecorder();
    final engine = EdgeTtsEngine(
      failureRecorder: recorder,
      synthesizer: scripted([
        const EdgeTtsException(
          'connection_failed',
          'failed',
          cause: SocketException('Failed host lookup'),
        ),
      ], calls),
    );

    expect(await synthesize(engine), isNull);
    expect(calls, hasLength(1));
    expect(recorder.lastFailure, EdgeTtsFailureKind.network);
  });

  test('再次合成成功 → 清除之前的失败记录', () async {
    final calls = <({String text, String voice, String languageTag})>[];
    final recorder = EdgeTtsFailureRecorder()
      ..recordFailure(EdgeTtsFailureKind.network);
    final engine = EdgeTtsEngine(
      failureRecorder: recorder,
      synthesizer: scripted([
        Uint8List.fromList([1]),
      ], calls),
    );

    await synthesize(engine);

    expect(recorder.lastFailure, isNull);
  });

  test('Edge 无实时朗读兜底', () async {
    expect(await EdgeTtsEngine().speakLive('hello'), isFalse);
  });
}
