import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:echo_loop/services/tts/tts_cache_store.dart';
import 'package:echo_loop/services/tts/tts_coordinator.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';
import 'package:echo_loop/services/tts/tts_player.dart';

class MockTtsEngine extends Mock implements TtsEngine {}

class MockTtsCacheStore extends Mock implements TtsCacheStore {}

class MockTtsPlayer extends Mock implements TtsPlayer {}

const _config = TtsSpeechConfig(languageTag: 'en-US');

void _stubEngine(MockTtsEngine engine, {String filePath = '/tmp/out.wav'}) {
  when(() => engine.initialize()).thenAnswer((_) async {});
  when(() => engine.applyConfig(any())).thenAnswer((_) async {});
  when(() => engine.stop()).thenAnswer((_) async {});
  when(() => engine.dispose()).thenAnswer((_) async {});
  when(() => engine.speakLive(any())).thenAnswer((_) async => true);
  when(
    () => engine.synthesize(
      any(),
      outputDir: any(named: 'outputDir'),
      baseName: any(named: 'baseName'),
      config: any(named: 'config'),
    ),
  ).thenAnswer(
    (_) async => TtsSynthesisResult(filePath: filePath, format: 'wav'),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_config);
    registerFallbackValue(TtsEngineKind.platform);
    registerFallbackValue(
      const TtsSynthesisResult(filePath: '/tmp/x.wav', format: 'wav'),
    );
  });

  late MockTtsEngine engine;
  late MockTtsCacheStore store;
  late MockTtsPlayer player;

  TtsCoordinator build() {
    return TtsCoordinator(
      factory: (_) => engine,
      cacheStore: store,
      player: player,
    );
  }

  setUp(() {
    engine = MockTtsEngine();
    store = MockTtsCacheStore();
    player = MockTtsPlayer();

    when(() => engine.initialize()).thenAnswer((_) async {});
    when(() => engine.applyConfig(any())).thenAnswer((_) async {});
    when(() => engine.stop()).thenAnswer((_) async {});
    when(() => engine.dispose()).thenAnswer((_) async {});
    when(() => engine.speakLive(any())).thenAnswer((_) async => true);
    when(
      () => engine.synthesize(
        any(),
        outputDir: any(named: 'outputDir'),
        baseName: any(named: 'baseName'),
        config: any(named: 'config'),
      ),
    ).thenAnswer(
      (_) async =>
          const TtsSynthesisResult(filePath: '/tmp/out.wav', format: 'wav'),
    );

    when(
      () => store.deriveKey(
        text: any(named: 'text'),
        engine: any(named: 'engine'),
        voiceId: any(named: 'voiceId'),
        speed: any(named: 'speed'),
        modelTag: any(named: 'modelTag'),
      ),
    ).thenReturn('key1');
    when(() => store.reserveDir()).thenAnswer((_) async => '/tmp');
    when(() => store.lookup(any())).thenAnswer((_) async => null);
    when(
      () => store.store(
        cacheKey: any(named: 'cacheKey'),
        text: any(named: 'text'),
        engine: any(named: 'engine'),
        voiceId: any(named: 'voiceId'),
        languageCode: any(named: 'languageCode'),
        speed: any(named: 'speed'),
        result: any(named: 'result'),
      ),
    ).thenAnswer((_) async {});

    when(() => player.stop()).thenAnswer((_) async {});
    when(() => player.dispose()).thenAnswer((_) async {});
    when(() => player.playFileToEnd(any())).thenAnswer((_) async => true);
  });

  group('configure（惰性引擎）', () {
    test('configure 仅记录目标，不立即初始化引擎', () async {
      final c = build();
      await c.configure(TtsEngineKind.platform, _config);
      verifyNever(() => engine.initialize());
    });

    test('首次 speak 才惰性初始化引擎', () async {
      final c = build();
      await c.configure(TtsEngineKind.platform, _config);
      await c.speak('hi');
      verify(() => engine.initialize()).called(1);
      verify(() => engine.applyConfig(_config)).called(1);
    });

    test('引擎已建后仅配置变化 → 只 applyConfig 不重建', () async {
      final c = build();
      await c.configure(TtsEngineKind.platform, _config);
      await c.speak('hi'); // 惰性建引擎 + applyConfig(_config)
      const config2 = TtsSpeechConfig(languageTag: 'en-GB');
      await c.configure(TtsEngineKind.platform, config2);
      verify(() => engine.initialize()).called(1);
      verify(() => engine.applyConfig(config2)).called(1);
    });

    test('引擎已建后种类变化 → 停旧、弃旧、建新', () async {
      final engineA = MockTtsEngine();
      final engineB = MockTtsEngine();
      for (final e in [engineA, engineB]) {
        when(() => e.initialize()).thenAnswer((_) async {});
        when(() => e.applyConfig(any())).thenAnswer((_) async {});
        when(() => e.stop()).thenAnswer((_) async {});
        when(() => e.dispose()).thenAnswer((_) async {});
        when(() => e.speakLive(any())).thenAnswer((_) async => true);
        when(
          () => e.synthesize(
            any(),
            outputDir: any(named: 'outputDir'),
            baseName: any(named: 'baseName'),
            config: any(named: 'config'),
          ),
        ).thenAnswer((_) async => null);
      }
      final c = TtsCoordinator(
        factory: (kind) => kind == TtsEngineKind.platform ? engineA : engineB,
        cacheStore: store,
        player: player,
      );
      await c.configure(TtsEngineKind.platform, _config);
      await c.speak('hi'); // 建 engineA
      await c.configure(TtsEngineKind.echoLoop, _config); // 引擎已存在 → 切换重建
      verify(() => engineA.dispose()).called(1);
      verify(() => engineB.initialize()).called(1);
    });
  });

  group('speak', () {
    test('缓存命中 → 不合成，直接播放缓存文件', () async {
      when(
        () => store.lookup(any()),
      ).thenAnswer((_) async => File('/tmp/cached.wav'));

      final c = build();
      await c.configure(TtsEngineKind.platform, _config);
      final ok = await c.speak('hello');

      expect(ok, isTrue);
      verifyNever(
        () => engine.synthesize(
          any(),
          outputDir: any(named: 'outputDir'),
          baseName: any(named: 'baseName'),
          config: any(named: 'config'),
        ),
      );
      verify(() => player.playFileToEnd('/tmp/cached.wav')).called(1);
    });

    test('缓存未命中 → 合成、入库、播放合成文件', () async {
      final c = build();
      await c.configure(TtsEngineKind.platform, _config);
      final ok = await c.speak('hello');

      expect(ok, isTrue);
      verify(
        () => engine.synthesize(
          'hello',
          outputDir: '/tmp',
          baseName: 'key1',
          config: any(named: 'config'),
        ),
      ).called(1);
      verify(
        () => store.store(
          cacheKey: 'key1',
          text: 'hello',
          engine: TtsEngineKind.platform,
          voiceId: any(named: 'voiceId'),
          languageCode: 'en-US',
          speed: any(named: 'speed'),
          result: any(named: 'result'),
        ),
      ).called(1);
      verify(() => player.playFileToEnd('/tmp/out.wav')).called(1);
    });

    test('合成返回 null → 降级实时朗读，不入库', () async {
      when(
        () => engine.synthesize(
          any(),
          outputDir: any(named: 'outputDir'),
          baseName: any(named: 'baseName'),
          config: any(named: 'config'),
        ),
      ).thenAnswer((_) async => null);

      final c = build();
      await c.configure(TtsEngineKind.platform, _config);
      final ok = await c.speak('hello');

      expect(ok, isTrue);
      verify(() => engine.speakLive('hello')).called(1);
      verifyNever(
        () => store.store(
          cacheKey: any(named: 'cacheKey'),
          text: any(named: 'text'),
          engine: any(named: 'engine'),
          voiceId: any(named: 'voiceId'),
          languageCode: any(named: 'languageCode'),
          speed: any(named: 'speed'),
          result: any(named: 'result'),
        ),
      );
    });

    test('发音前停止上一次播放与引擎（打断重播）', () async {
      final c = build();
      await c.configure(TtsEngineKind.platform, _config);
      await c.speak('hello');
      verify(() => player.stop()).called(1);
      verify(() => engine.stop()).called(1);
    });

    test('空文本 → 直接返回 false，不动引擎', () async {
      final c = build();
      await c.configure(TtsEngineKind.platform, _config);
      final ok = await c.speak('   ');
      expect(ok, isFalse);
      verifyNever(() => player.playFileToEnd(any()));
    });
  });

  group('并发引擎构建（in-flight 守卫）', () {
    test('并发 speak 在 _engine==null 窗口内只构建一个引擎', () async {
      // 引擎 initialize 故意拖慢，制造「两次 speak 都在 _engine==null 时进入」的窗口。
      var created = 0;
      final initStarted = <int>[];
      TtsEngine makeEngine(int id) {
        final e = MockTtsEngine();
        when(() => e.initialize()).thenAnswer((_) async {
          initStarted.add(id);
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        when(() => e.applyConfig(any())).thenAnswer((_) async {});
        when(() => e.stop()).thenAnswer((_) async {});
        when(() => e.dispose()).thenAnswer((_) async {});
        when(() => e.speakLive(any())).thenAnswer((_) async => true);
        when(
          () => e.synthesize(
            any(),
            outputDir: any(named: 'outputDir'),
            baseName: any(named: 'baseName'),
            config: any(named: 'config'),
          ),
        ).thenAnswer(
          (_) async =>
              const TtsSynthesisResult(filePath: '/tmp/out.wav', format: 'wav'),
        );
        return e;
      }

      final c = TtsCoordinator(
        factory: (_) => makeEngine(created++),
        cacheStore: store,
        player: player,
      );
      await c.configure(TtsEngineKind.echoLoop, _config);

      // 同时发起两次 speak，二者都会在引擎尚未就绪时调用 _ensureEngine。
      await Future.wait([c.speak('a'), c.speak('b')]);

      // 仅构建并初始化了一个引擎（无 worker isolate 泄漏）。
      expect(created, 1, reason: '并发构建应复用同一引擎');
      expect(initStarted.length, 1, reason: 'initialize 只应执行一次');
    });
  });

  group('speakWith（指定音色试听）', () {
    const previewConfig = TtsSpeechConfig(
      languageTag: 'en-GB',
      voiceName: 'bf_emma',
      modelTag: 'int8',
    );

    test('用传入配置派生缓存键、合成并播放（不依赖当前选中配置）', () async {
      when(
        () => store.deriveKey(
          text: any(named: 'text'),
          engine: any(named: 'engine'),
          voiceId: any(named: 'voiceId'),
          speed: any(named: 'speed'),
          modelTag: any(named: 'modelTag'),
        ),
      ).thenReturn('previewKey');

      final c = build();
      await c.configure(TtsEngineKind.echoLoop, _config);
      final ok = await c.speakWith('hi', TtsEngineKind.echoLoop, previewConfig);

      expect(ok, isTrue);
      // 派生键用传入配置的 voiceId / modelTag。
      verify(
        () => store.deriveKey(
          text: 'hi',
          engine: TtsEngineKind.echoLoop,
          voiceId: 'bf_emma',
          speed: any(named: 'speed'),
          modelTag: 'int8',
        ),
      ).called(1);
      // 合成时把该配置传给引擎（音色随之）。
      verify(
        () => engine.synthesize(
          'hi',
          outputDir: any(named: 'outputDir'),
          baseName: 'previewKey',
          config: previewConfig,
        ),
      ).called(1);
      verify(() => player.playFileToEnd('/tmp/out.wav')).called(1);
    });

    test('当前为平台引擎时，speakWith Echo Loop 会切到 Echo Loop 引擎合成', () async {
      final platformEngine = MockTtsEngine();
      final echoEngine = MockTtsEngine();
      _stubEngine(platformEngine, filePath: '/tmp/platform.wav');
      _stubEngine(echoEngine, filePath: '/tmp/echo.wav');
      final c = TtsCoordinator(
        factory: (kind) =>
            kind == TtsEngineKind.platform ? platformEngine : echoEngine,
        cacheStore: store,
        player: player,
      );

      await c.configure(TtsEngineKind.platform, _config);
      await c.speak('platform-first');
      clearInteractions(player);

      final ok = await c.speakWith('hi', TtsEngineKind.echoLoop, previewConfig);

      expect(ok, isTrue);
      verify(
        () => echoEngine.synthesize(
          'hi',
          outputDir: any(named: 'outputDir'),
          baseName: any(named: 'baseName'),
          config: previewConfig,
        ),
      ).called(1);
      verifyNever(
        () => platformEngine.synthesize(
          'hi',
          outputDir: any(named: 'outputDir'),
          baseName: any(named: 'baseName'),
          config: any(named: 'config'),
        ),
      );
      verify(() => player.playFileToEnd('/tmp/echo.wav')).called(1);
    });

    test('合成期间被新发音抢占 → 不播放', () async {
      final synthStarted = Completer<void>();
      final release = Completer<void>();
      when(
        () => engine.synthesize(
          any(),
          outputDir: any(named: 'outputDir'),
          baseName: any(named: 'baseName'),
          config: any(named: 'config'),
        ),
      ).thenAnswer((_) async {
        if (!synthStarted.isCompleted) synthStarted.complete();
        await release.future;
        return const TtsSynthesisResult(
          filePath: '/tmp/out.wav',
          format: 'wav',
        );
      });

      final c = build();
      await c.configure(TtsEngineKind.echoLoop, _config);
      final first = c.speakWith('hi', TtsEngineKind.echoLoop, previewConfig);
      await synthStarted.future; // 第一次已进入合成
      await c.stop(); // 抢占（递增代际）
      release.complete();
      final ok = await first;

      expect(ok, isFalse, reason: '被抢占的渲染不应播放');
    });
  });

  group('prewarm（后台预热，不播放）', () {
    test('未命中 → 合成入库，但不触发播放器', () async {
      final c = build();
      await c.configure(TtsEngineKind.echoLoop, _config);
      await c.prewarm('hi', TtsEngineKind.echoLoop, _config);

      verify(
        () => engine.synthesize(
          'hi',
          outputDir: any(named: 'outputDir'),
          baseName: any(named: 'baseName'),
          config: _config,
        ),
      ).called(1);
      verify(
        () => store.store(
          cacheKey: any(named: 'cacheKey'),
          text: 'hi',
          engine: TtsEngineKind.echoLoop,
          voiceId: any(named: 'voiceId'),
          languageCode: any(named: 'languageCode'),
          speed: any(named: 'speed'),
          result: any(named: 'result'),
        ),
      ).called(1);
      verifyNever(() => player.playFileToEnd(any()));
    });

    test('当前为平台引擎时，prewarm Piper 会切到 Piper 引擎合成入库', () async {
      const piperConfig = TtsSpeechConfig(
        languageTag: 'en-US',
        voiceName: 'piper_kristin',
      );
      final platformEngine = MockTtsEngine();
      final piperEngine = MockTtsEngine();
      _stubEngine(platformEngine, filePath: '/tmp/platform.wav');
      _stubEngine(piperEngine, filePath: '/tmp/piper.wav');
      final c = TtsCoordinator(
        factory: (kind) =>
            kind == TtsEngineKind.platform ? platformEngine : piperEngine,
        cacheStore: store,
        player: player,
      );

      await c.configure(TtsEngineKind.platform, _config);
      await c.speak('platform-first');
      clearInteractions(player);

      await c.prewarm('hello', TtsEngineKind.piper, piperConfig);

      verify(
        () => piperEngine.synthesize(
          'hello',
          outputDir: any(named: 'outputDir'),
          baseName: any(named: 'baseName'),
          config: piperConfig,
        ),
      ).called(1);
      verifyNever(
        () => platformEngine.synthesize(
          'hello',
          outputDir: any(named: 'outputDir'),
          baseName: any(named: 'baseName'),
          config: any(named: 'config'),
        ),
      );
      verify(
        () => store.store(
          cacheKey: any(named: 'cacheKey'),
          text: 'hello',
          engine: TtsEngineKind.piper,
          voiceId: 'piper_kristin',
          languageCode: 'en-US',
          speed: any(named: 'speed'),
          result: any(named: 'result'),
        ),
      ).called(1);
      verifyNever(() => player.playFileToEnd(any()));
    });

    test('同 key 合成在途 → 并发请求复用，仅合成一次', () async {
      // 合成阻塞在闸门，制造「prewarm 与 speakWith 同时在途」窗口。
      final gate = Completer<void>();
      var synthCalls = 0;
      when(
        () => engine.synthesize(
          any(),
          outputDir: any(named: 'outputDir'),
          baseName: any(named: 'baseName'),
          config: any(named: 'config'),
        ),
      ).thenAnswer((_) async {
        synthCalls++;
        await gate.future;
        return const TtsSynthesisResult(
          filePath: '/tmp/out.wav',
          format: 'wav',
        );
      });

      final c = build();
      await c.configure(TtsEngineKind.echoLoop, _config);
      // 两路并发渲染同一 key（deriveKey 全局桩恒返回 'key1'）。
      final f1 = c.prewarm('hi', TtsEngineKind.echoLoop, _config);
      final f2 = c.speakWith('hi', TtsEngineKind.echoLoop, _config);
      await Future<void>.delayed(Duration.zero); // 让两路都过 lookup、其一登记在途
      gate.complete();
      await Future.wait([f1, f2]);

      expect(synthCalls, 1, reason: '同 key 在途应只合成一次');
    });

    test('命中缓存 → 跳过合成（去重）', () async {
      when(
        () => store.lookup(any()),
      ).thenAnswer((_) async => File('/tmp/cached.wav'));

      final c = build();
      await c.configure(TtsEngineKind.echoLoop, _config);
      await c.prewarm('hi', TtsEngineKind.echoLoop, _config);

      verifyNever(
        () => engine.synthesize(
          any(),
          outputDir: any(named: 'outputDir'),
          baseName: any(named: 'baseName'),
          config: any(named: 'config'),
        ),
      );
      verifyNever(() => player.playFileToEnd(any()));
    });

    test('复用在途合成播放时不打断该合成（§7.18）→ 合成期间不停引擎，完成后照常播放', () async {
      // 合成阻塞在闸门，模拟「预热在途」窗口；随后 speakWith 复用同一 key。
      final gate = Completer<void>();
      when(
        () => engine.synthesize(
          any(),
          outputDir: any(named: 'outputDir'),
          baseName: any(named: 'baseName'),
          config: any(named: 'config'),
        ),
      ).thenAnswer((_) async {
        await gate.future;
        return const TtsSynthesisResult(
          filePath: '/tmp/out.wav',
          format: 'wav',
        );
      });

      final c = build();
      await c.configure(TtsEngineKind.echoLoop, _config);
      final pre = c.prewarm('hi', TtsEngineKind.echoLoop, _config); // 登记在途
      await Future<void>.delayed(Duration.zero);
      final play = c.speakWith('hi', TtsEngineKind.echoLoop, _config); // 复用在途
      await Future<void>.delayed(Duration.zero);

      // 在途合成期间绝不停引擎：否则平台引擎 synthesizeToFile 被打断、复用方挂起。
      verifyNever(() => engine.stop());

      gate.complete();
      expect(await play, isTrue);
      await pre;
      // 合成完成后照常播放复用产物。
      verify(() => player.playFileToEnd('/tmp/out.wav')).called(1);
    });
  });

  group('prewarmCurrent（按当前配置预热）', () {
    test('未配置 → no-op，不建引擎不合成', () async {
      final c = build();
      await c.prewarmCurrent('hi');
      verifyNever(() => engine.initialize());
      verifyNever(
        () => engine.synthesize(
          any(),
          outputDir: any(named: 'outputDir'),
          baseName: any(named: 'baseName'),
          config: any(named: 'config'),
        ),
      );
    });

    test('已配置 → 用当前 kind/config 合成入库，不播放', () async {
      const cfg = TtsSpeechConfig(
        languageTag: 'en-US',
        voiceName: 'am_adam',
        modelTag: 'int8',
      );
      final c = build();
      await c.configure(TtsEngineKind.echoLoop, cfg);
      await c.prewarmCurrent('hello');

      verify(
        () => engine.synthesize(
          'hello',
          outputDir: any(named: 'outputDir'),
          baseName: any(named: 'baseName'),
          config: cfg,
        ),
      ).called(1);
      verify(
        () => store.store(
          cacheKey: any(named: 'cacheKey'),
          text: 'hello',
          engine: TtsEngineKind.echoLoop,
          voiceId: any(named: 'voiceId'),
          languageCode: any(named: 'languageCode'),
          speed: any(named: 'speed'),
          result: any(named: 'result'),
        ),
      ).called(1);
      verifyNever(() => player.playFileToEnd(any()));
    });

    test('命中缓存 → 跳过合成（与 speak 同源 key 即命中）', () async {
      when(
        () => store.lookup(any()),
      ).thenAnswer((_) async => File('/tmp/cached.wav'));

      final c = build();
      await c.configure(TtsEngineKind.echoLoop, _config);
      await c.prewarmCurrent('hi');

      verifyNever(
        () => engine.synthesize(
          any(),
          outputDir: any(named: 'outputDir'),
          baseName: any(named: 'baseName'),
          config: any(named: 'config'),
        ),
      );
    });
  });

  group('优先级队列（合成调度）', () {
    // deriveKey 按文本分桶，避免去重把不同任务合并成一个合成。
    void keyByText() {
      when(
        () => store.deriveKey(
          text: any(named: 'text'),
          engine: any(named: 'engine'),
          voiceId: any(named: 'voiceId'),
          speed: any(named: 'speed'),
          modelTag: any(named: 'modelTag'),
        ),
      ).thenAnswer((inv) => 'key-${inv.namedArguments[#text]}');
    }

    /// 用按文本命名的闸门拦住合成，返回「执行顺序记录」与「按文本放行」闭包。
    (List<String>, void Function(String)) gatedSynth() {
      final order = <String>[];
      final gates = <String, Completer<void>>{};
      Completer<void> gateFor(String t) =>
          gates.putIfAbsent(t, () => Completer<void>());
      when(
        () => engine.synthesize(
          any(),
          outputDir: any(named: 'outputDir'),
          baseName: any(named: 'baseName'),
          config: any(named: 'config'),
        ),
      ).thenAnswer((inv) async {
        final text = inv.positionalArguments[0] as String;
        order.add(text);
        await gateFor(text).future;
        return const TtsSynthesisResult(
          filePath: '/tmp/out.wav',
          format: 'wav',
        );
      });
      return (order, (t) => gateFor(t).complete());
    }

    test('用户任务优先于后台预热；用户任务之间按提交顺序 FIFO', () async {
      keyByText();
      final (order, release) = gatedSynth();

      final c = build();
      await c.configure(TtsEngineKind.echoLoop, _config);

      // 后台预热 A 先占住 worker（running，不可打断）。
      final fa = c.prewarm('A', TtsEngineKind.echoLoop, _config);
      await pumpEventQueue();
      expect(order, ['A'], reason: 'A 已进入合成并占用 worker');

      // A 运行期间，依次提交：后台 bg、用户 u1、用户 u2。
      final fbg = c.prewarm('bg', TtsEngineKind.echoLoop, _config);
      final fu1 = c.speakWith('u1', TtsEngineKind.echoLoop, _config);
      final fu2 = c.speakWith('u2', TtsEngineKind.echoLoop, _config);
      await pumpEventQueue();
      expect(order, ['A'], reason: 'worker 忙于 A，其余排队等待');

      // 放行 A → 应先跑用户 u1（FIFO 队首），再 u2，最后才后台 bg。
      release('A');
      await pumpEventQueue();
      expect(order, ['A', 'u1']);
      release('u1');
      await pumpEventQueue();
      expect(order, ['A', 'u1', 'u2']);
      release('u2');
      await pumpEventQueue();
      expect(order, ['A', 'u1', 'u2', 'bg']);
      release('bg');

      await Future.wait([fa, fbg, fu1, fu2]);
    });

    test('被后发用户发音抢占的任务仍合成入缓存（只是不播放）', () async {
      keyByText();
      final (order, release) = gatedSynth();

      final c = build();
      await c.configure(TtsEngineKind.echoLoop, _config);

      // task1、task2 背靠背发起：task2 抢占 task1 的播放，但两者都应合成入队。
      final t1 = c.speak('t1');
      final t2 = c.speak('t2');
      await pumpEventQueue();

      // task1 先入队先合成（FIFO）。
      expect(order, ['t1']);
      release('t1');
      await pumpEventQueue();
      // task1 合成完入库，task2 接着合成。
      expect(order, ['t1', 't2']);
      release('t2');

      final r1 = await t1;
      final r2 = await t2;

      // 两者都合成入库（各一次 store）。
      verify(
        () => store.store(
          cacheKey: 'key-t1',
          text: 't1',
          engine: any(named: 'engine'),
          voiceId: any(named: 'voiceId'),
          languageCode: any(named: 'languageCode'),
          speed: any(named: 'speed'),
          result: any(named: 'result'),
        ),
      ).called(1);
      verify(
        () => store.store(
          cacheKey: 'key-t2',
          text: 't2',
          engine: any(named: 'engine'),
          voiceId: any(named: 'voiceId'),
          languageCode: any(named: 'languageCode'),
          speed: any(named: 'speed'),
          result: any(named: 'result'),
        ),
      ).called(1);

      // 被抢占的 task1 不播放，最新的 task2 播放。
      expect(r1, isFalse, reason: 'task1 播放被 task2 抢占');
      expect(r2, isTrue);
      verify(() => player.playFileToEnd('/tmp/out.wav')).called(1);
    });
  });

  group('stop', () {
    test('未建引擎时仅停播放器，不报错', () async {
      final c = build();
      await c.configure(TtsEngineKind.platform, _config);
      await c.stop();
      verify(() => player.stop()).called(1);
    });

    test('已惰性建引擎后 stop 同时停引擎', () async {
      final c = build();
      await c.configure(TtsEngineKind.platform, _config);
      await c.speak('hi'); // 惰性建引擎
      await c.stop();
      verify(() => engine.stop()).called(greaterThanOrEqualTo(1));
    });
  });
}
