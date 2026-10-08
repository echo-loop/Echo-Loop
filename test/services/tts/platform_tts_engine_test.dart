import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';

import 'package:echo_loop/services/tts/platform_tts_engine.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';

class MockFlutterTts extends Mock implements FlutterTts {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFlutterTts tts;
  late VoidCallback startHandler;
  late VoidCallback completionHandler;
  late VoidCallback cancelHandler;

  PlatformTtsEngine buildEngine({
    String format = 'wav',
    bool useNativeMacosSynth = false,
    NativeMacosSynthesize? nativeMacosSynth,
  }) {
    return PlatformTtsEngine(
      ttsFactory: () => tts,
      formatResolver: () => format,
      // 测试在 macOS host 跑，默认关掉 macOS 原生路径，让现有用例走 flutter_tts
      // synthesizeToFile 分支；macOS 原生用例单独打开。
      useNativeMacosSynth: () => useNativeMacosSynth,
      nativeMacosSynth: nativeMacosSynth,
    );
  }

  setUp(() {
    tts = MockFlutterTts();
    // 配置类方法返回 Future。
    when(() => tts.awaitSpeakCompletion(any())).thenAnswer((_) async => 1);
    when(() => tts.awaitSynthCompletion(any())).thenAnswer((_) async => 1);
    when(() => tts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => tts.setSpeechRate(any())).thenAnswer((_) async => 1);
    when(() => tts.setPitch(any())).thenAnswer((_) async => 1);
    when(() => tts.setVolume(any())).thenAnswer((_) async => 1);
    when(() => tts.speak(any())).thenAnswer((_) async => 1);
    when(() => tts.stop()).thenAnswer((_) async => 1);
    // 捕获 handler。
    when(() => tts.setStartHandler(any())).thenAnswer((inv) {
      startHandler = inv.positionalArguments[0] as VoidCallback;
    });
    when(() => tts.setCompletionHandler(any())).thenAnswer((inv) {
      completionHandler = inv.positionalArguments[0] as VoidCallback;
    });
    when(() => tts.setCancelHandler(any())).thenAnswer((inv) {
      cancelHandler = inv.positionalArguments[0] as VoidCallback;
    });
    when(() => tts.setErrorHandler(any())).thenReturn(null);
  });

  group('applyConfig', () {
    test('英音 → setLanguage(en-GB)', () async {
      final engine = buildEngine();
      await engine.applyConfig(const TtsSpeechConfig(languageTag: 'en-GB'));
      verify(() => tts.setLanguage('en-GB')).called(1);
    });

    test('美音 → setLanguage(en-US) + 语速', () async {
      final engine = buildEngine();
      await engine.applyConfig(
        const TtsSpeechConfig(languageTag: 'en-US', rate: 0.45),
      );
      verify(() => tts.setLanguage('en-US')).called(1);
      verify(() => tts.setSpeechRate(0.45)).called(1);
    });
  });

  group('synthesize', () {
    test('默认合成格式使用 WAV', () async {
      final tempDir = await Directory.systemTemp.createTemp('synth_default');
      addTearDown(() => tempDir.delete(recursive: true));
      when(() => tts.synthesizeToFile(any(), any(), any())).thenAnswer((
        _,
      ) async {
        await File('${tempDir.path}/abc.wav').writeAsBytes([1, 2, 3]);
        return 1;
      });

      final engine = PlatformTtsEngine(
        ttsFactory: () => tts,
        useNativeMacosSynth: () => false,
      );
      final result = await engine.synthesize(
        'Hello',
        outputDir: tempDir.path,
        baseName: 'abc',
      );

      expect(result, isNotNull);
      expect(result?.format, 'wav');
      expect(result?.filePath, '${tempDir.path}/abc.wav');
      verify(
        () => tts.synthesizeToFile('Hello', '${tempDir.path}/abc.wav', true),
      ).called(1);
    });

    test('成功写盘 → 返回结果(路径+格式)', () async {
      final tempDir = await Directory.systemTemp.createTemp('synth_ok');
      addTearDown(() => tempDir.delete(recursive: true));
      when(() => tts.synthesizeToFile(any(), any(), any())).thenAnswer((
        inv,
      ) async {
        final path = inv.positionalArguments[1] as String;
        await File(path).writeAsBytes([1, 2, 3]);
        return 1;
      });

      final engine = buildEngine(format: 'wav');
      final result = await engine.synthesize(
        'Hello',
        outputDir: tempDir.path,
        baseName: 'abc',
      );
      expect(result, isNotNull);
      expect(result!.format, 'wav');
      expect(result.filePath, '${tempDir.path}/abc.wav');
      expect(await File(result.filePath).exists(), isTrue);
      verify(() => tts.awaitSynthCompletion(true)).called(1);
    });

    test('传入 config → 合成前按该口音 setLanguage（产物与缓存键一致）', () async {
      final tempDir = await Directory.systemTemp.createTemp('synth_cfg');
      addTearDown(() => tempDir.delete(recursive: true));
      when(() => tts.synthesizeToFile(any(), any(), any())).thenAnswer((
        inv,
      ) async {
        final path = inv.positionalArguments[1] as String;
        await File(path).writeAsBytes([1, 2, 3]);
        return 1;
      });

      final engine = buildEngine(format: 'wav');
      // 试听非当前口音：显式传 en-GB，应优先于环境态。
      final result = await engine.synthesize(
        'Hello',
        outputDir: tempDir.path,
        baseName: 'abc',
        config: const TtsSpeechConfig(languageTag: 'en-GB'),
      );
      expect(result, isNotNull);
      verify(() => tts.setLanguage('en-GB')).called(1);
    });

    test('synthesizeToFile 抛异常 → 返回 null（降级兜底）', () async {
      final tempDir = await Directory.systemTemp.createTemp('synth_err');
      addTearDown(() => tempDir.delete(recursive: true));
      when(
        () => tts.synthesizeToFile(any(), any(), any()),
      ).thenThrow(Exception('iOS synth bug'));

      final engine = buildEngine();
      final result = await engine.synthesize(
        'Hello',
        outputDir: tempDir.path,
        baseName: 'abc',
      );
      expect(result, isNull);
    });

    test('产出空文件 → 返回 null', () async {
      final tempDir = await Directory.systemTemp.createTemp('synth_empty');
      addTearDown(() => tempDir.delete(recursive: true));
      when(() => tts.synthesizeToFile(any(), any(), any())).thenAnswer((
        inv,
      ) async {
        final path = inv.positionalArguments[1] as String;
        await File(path).writeAsBytes([]); // 空
        return 1;
      });
      final engine = buildEngine();
      final result = await engine.synthesize(
        'Hello',
        outputDir: tempDir.path,
        baseName: 'abc',
      );
      expect(result, isNull);
    });
  });

  group('macOS 原生合成（绕过 flutter_tts 漏设 voice）', () {
    test('原生合成成功写盘 → 返回 wav 结果，不调 flutter_tts.synthesizeToFile', () async {
      final tempDir = await Directory.systemTemp.createTemp('synth_native');
      addTearDown(() => tempDir.delete(recursive: true));

      String? gotLang;
      final engine = buildEngine(
        format: 'wav',
        useNativeMacosSynth: true,
        nativeMacosSynth:
            ({
              required text,
              required filePath,
              required languageTag,
              required rate,
              required pitch,
              required volume,
            }) async {
              gotLang = languageTag;
              await File(filePath).writeAsBytes([1, 2, 3]);
              return true;
            },
      );
      final result = await engine.synthesize(
        'Hello',
        outputDir: tempDir.path,
        baseName: 'abc',
        config: const TtsSpeechConfig(languageTag: 'en-GB'),
      );

      expect(result, isNotNull);
      expect(result!.format, 'wav');
      expect(result.filePath, '${tempDir.path}/abc.wav');
      expect(await File(result.filePath).exists(), isTrue);
      // 口音经 config 透传到原生层。
      expect(gotLang, 'en-GB');
      // 不再走 flutter_tts 的 synthesizeToFile。
      verifyNever(() => tts.synthesizeToFile(any(), any()));
      verifyNever(() => tts.synthesizeToFile(any(), any(), any()));
    });

    test('原生合成返回 false → synthesize 返回 null（降级 speakLive）', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'synth_native_fail',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final engine = buildEngine(
        format: 'wav',
        useNativeMacosSynth: true,
        nativeMacosSynth:
            ({
              required text,
              required filePath,
              required languageTag,
              required rate,
              required pitch,
              required volume,
            }) async => false,
      );
      final result = await engine.synthesize(
        'Hello',
        outputDir: tempDir.path,
        baseName: 'abc',
        config: const TtsSpeechConfig(languageTag: 'en-US'),
      );
      expect(result, isNull);
    });

    test('原生合成报成功但产出为空 → 返回 null', () async {
      final tempDir = await Directory.systemTemp.createTemp('synth_native_emp');
      addTearDown(() => tempDir.delete(recursive: true));

      final engine = buildEngine(
        format: 'wav',
        useNativeMacosSynth: true,
        nativeMacosSynth:
            ({
              required text,
              required filePath,
              required languageTag,
              required rate,
              required pitch,
              required volume,
            }) async {
              await File(filePath).writeAsBytes([]); // 空
              return true;
            },
      );
      final result = await engine.synthesize(
        'Hello',
        outputDir: tempDir.path,
        baseName: 'abc',
        config: const TtsSpeechConfig(languageTag: 'en-US'),
      );
      expect(result, isNull);
    });
  });

  group('speakLive（§7.2 防竞态）', () {
    test('completion handler 到达后返回 true', () async {
      final engine = buildEngine();
      await engine.initialize();
      final fut = engine.speakLive('hi');
      await pumpEventQueue();
      startHandler();
      completionHandler();
      expect(await fut, isTrue);
    });

    test('speak 抛异常 → 返回 false 不悬挂', () async {
      when(() => tts.speak(any())).thenThrow(Exception('boom'));
      final engine = buildEngine();
      await engine.initialize();
      expect(await engine.speakLive('hi'), isFalse);
    });

    test('start 前到达的 completion（stale）被忽略', () async {
      final engine = buildEngine();
      await engine.initialize();
      final fut = engine.speakLive('hi');
      await pumpEventQueue();
      // 模拟旧 stop 的 stale cancel：_started 仍为 false → 应被忽略，future 不完成。
      cancelHandler();
      var done = false;
      // ignore: unawaited_futures
      fut.then((_) => done = true);
      await pumpEventQueue();
      expect(done, isFalse);
      // 正常 start + completion 才完成。
      startHandler();
      completionHandler();
      expect(await fut, isTrue);
    });

    test('新 speak 抢占旧 speak：旧 future 立即 false 不悬挂', () async {
      final engine = buildEngine();
      await engine.initialize();
      final f1 = engine.speakLive('a');
      await pumpEventQueue();
      startHandler(); // a 已开始
      // 新 speak 抢占：内部先 stop() → 解除 f1（被抢占=false）
      final f2 = engine.speakLive('b');
      expect(await f1, isFalse);
      await pumpEventQueue();
      startHandler(); // b 开始
      completionHandler();
      expect(await f2, isTrue);
    });

    test('stop 解除等待中的 speak', () async {
      final engine = buildEngine();
      await engine.initialize();
      final fut = engine.speakLive('hi');
      await pumpEventQueue();
      await engine.stop();
      expect(await fut, isFalse);
    });

    test('completion 回调始终不来 → 超时后返回 true（不永挂，§7.25）', () {
      fakeAsync((async) {
        final engine = buildEngine();
        engine.initialize();
        async.flushMicrotasks();
        bool? result;
        // 从不调用 startHandler/completionHandler，模拟平台完成信号丢失。
        engine.speakLive('hi').then((v) => result = v);
        async.flushMicrotasks();
        expect(result, isNull, reason: '超时前不返回');
        async.elapse(const Duration(seconds: 11)); // 下限 10s
        async.flushMicrotasks();
        expect(result, isTrue, reason: '超时按已播完解除，不永挂');
      });
    });
  });
}
