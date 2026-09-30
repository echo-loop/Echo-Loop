import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:echo_loop/services/tts/kokoro_model_manager.dart'
    show KokoroModelPaths;
import 'package:echo_loop/services/tts/kokoro_synthesizer.dart';
import 'package:echo_loop/services/tts/kokoro_tts_engine.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';

/// 记录调用并按需写假 wav 的 fake 合成器。
class _FakeSynth implements KokoroNativeSynthesizer {
  _FakeSynth({this.failSynthesis = false});

  final bool failSynthesis;
  int initCount = 0;
  int disposeCount = 0;
  int? lastSid;
  double? lastSpeed;
  String? lastText;
  String? lastOutputPath;

  @override
  Future<void> init(KokoroModelPaths paths, {int numThreads = 2}) async {
    initCount++;
  }

  @override
  Future<int?> synthesize({
    required String text,
    required int sid,
    required double speed,
    required String outputPath,
  }) async {
    lastText = text;
    lastSid = sid;
    lastSpeed = speed;
    lastOutputPath = outputPath;
    if (failSynthesis) return null;
    await File(outputPath).writeAsBytes(const [0, 1, 2, 3]);
    return 24000;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }
}

void main() {
  late Directory outDir;
  const paths = KokoroModelPaths(
    model: '/m/model.int8.onnx',
    voices: '/m/voices.bin',
    tokens: '/m/tokens.txt',
    dataDir: '/m/espeak-ng-data',
  );

  KokoroTtsEngine build(_FakeSynth synth) => KokoroTtsEngine(
    resolvePaths: () async => paths,
    synthesizerFactory: () => synth,
  );

  setUp(() async {
    outDir = await Directory.systemTemp.createTemp('kokoro-engine-test');
  });
  tearDown(() async {
    if (await outDir.exists()) await outDir.delete(recursive: true);
  });

  test('synthesize 产出 wav，返回正确路径/格式/采样率', () async {
    final synth = _FakeSynth();
    final engine = build(synth);
    await engine.applyConfig(const TtsSpeechConfig(languageTag: 'en-US'));

    final result = await engine.synthesize(
      'hello',
      outputDir: outDir.path,
      baseName: 'abc',
    );

    expect(result, isNotNull);
    expect(result!.format, 'wav');
    expect(result.filePath, p.join(outDir.path, 'abc.wav'));
    expect(result.sampleRate, 24000);
    expect(File(result.filePath).existsSync(), isTrue);
    expect(synth.lastText, 'hello');
  });

  test('voiceName → 对应 sid', () async {
    final synth = _FakeSynth();
    final engine = build(synth);
    await engine.applyConfig(
      const TtsSpeechConfig(languageTag: 'en-GB', voiceName: 'bf_vale'),
    );
    await engine.synthesize('x', outputDir: outDir.path, baseName: 'b');
    expect(synth.lastSid, 2); // bf_vale
  });

  test('无 voiceName：按语言标签回退该口音默认音色 sid', () async {
    final synth = _FakeSynth();
    final engine = build(synth);
    await engine.applyConfig(const TtsSpeechConfig(languageTag: 'en-GB'));
    await engine.synthesize('x', outputDir: outDir.path, baseName: 'b');
    expect(synth.lastSid, 2); // bf_vale（英音默认）

    await engine.applyConfig(const TtsSpeechConfig(languageTag: 'en-US'));
    await engine.synthesize('x', outputDir: outDir.path, baseName: 'c');
    expect(synth.lastSid, 1); // af_sol（美音默认）
  });

  test('speed 透传到 native synthesizer 并夹在 0.5..2.0', () async {
    final synth = _FakeSynth();
    final engine = build(synth);
    await engine.applyConfig(
      const TtsSpeechConfig(languageTag: 'en-US', speed: 1.7),
    );
    await engine.synthesize('x', outputDir: outDir.path, baseName: 'speed');
    expect(synth.lastSpeed, 1.7);

    await engine.applyConfig(
      const TtsSpeechConfig(languageTag: 'en-US', speed: 3.0),
    );
    await engine.synthesize('y', outputDir: outDir.path, baseName: 'speed2');
    expect(synth.lastSpeed, 2.0);
  });

  test('中文文本自动切到中文默认音色 sid', () async {
    final synth = _FakeSynth();
    final engine = build(synth);
    await engine.applyConfig(
      const TtsSpeechConfig(languageTag: 'en-US', voiceName: 'af_sol'),
    );
    await engine.synthesize('你好，world', outputDir: outDir.path, baseName: 'zh');
    expect(synth.lastSid, 3);
  });

  test('合成失败（synth 返回 null）→ engine 返回 null', () async {
    final synth = _FakeSynth(failSynthesis: true);
    final engine = build(synth);
    await engine.applyConfig(const TtsSpeechConfig(languageTag: 'en-US'));
    final result = await engine.synthesize(
      'x',
      outputDir: outDir.path,
      baseName: 'b',
    );
    expect(result, isNull);
  });

  test('initialize 幂等：多次 synthesize 只 init 一次', () async {
    final synth = _FakeSynth();
    final engine = build(synth);
    await engine.applyConfig(const TtsSpeechConfig(languageTag: 'en-US'));
    await engine.synthesize('x', outputDir: outDir.path, baseName: 'b');
    await engine.synthesize('y', outputDir: outDir.path, baseName: 'c');
    expect(synth.initCount, 1);
  });

  test('speakLive 返回 false（不抛）', () async {
    final engine = build(_FakeSynth());
    expect(await engine.speakLive('x'), isFalse);
  });

  test('dispose 转发并允许重新初始化', () async {
    final synth = _FakeSynth();
    final engine = build(synth);
    await engine.synthesize('x', outputDir: outDir.path, baseName: 'b');
    await engine.dispose();
    expect(synth.disposeCount, 1);
    // 再次合成会重新 init。
    await engine.synthesize('y', outputDir: outDir.path, baseName: 'c');
    expect(synth.initCount, 2);
  });
}
