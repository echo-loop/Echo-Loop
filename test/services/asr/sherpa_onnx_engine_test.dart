import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/services/asr/sherpa_onnx_engine.dart';

void main() {
  group('SherpaOnnxEngine', () {
    test('初始状态：isReady 为 false，currentModel 为 null', () {
      final engine = SherpaOnnxEngine();
      expect(engine.isReady, isFalse);
      expect(engine.currentModel, isNull);
      expect(engine.name, 'sherpa-onnx');
    });

    test('未初始化时 transcribe 抛出 StateError', () async {
      final engine = SherpaOnnxEngine();
      expect(() => engine.transcribe('/any/path.wav'), throwsStateError);
    });

    test('未初始化时 transcribeSegments 抛出 StateError', () async {
      final engine = SherpaOnnxEngine();
      expect(
        () => engine.transcribeSegments('/any/path.wav'),
        throwsStateError,
      );
    });
  });

  group('parseWhisperSegments（首选：whisper 原生 segment 时间戳）', () {
    test('三数组等长：逐段配对 text/start/duration', () {
      const json =
          '{"text":"Hi there. How are you?",'
          '"segment_texts":[" Hi there."," How are you?"],'
          '"segment_timestamps":[0.0,1.2],'
          '"segment_durations":[1.1,1.5]}';
      final segs = parseWhisperSegments(json);
      expect(segs.length, 2);
      expect(segs[0].text, 'Hi there.');
      expect(segs[0].startSec, 0.0);
      expect(segs[0].durationSec, 1.1);
      expect(segs[1].text, 'How are you?');
      expect(segs[1].startSec, 1.2);
      expect(segs[1].durationSec, 1.5);
    });

    test('文本 trim + 丢弃空段', () {
      const json =
          '{"segment_texts":["  Hi  ","   "],'
          '"segment_timestamps":[0.0,1.0],'
          '"segment_durations":[0.8,0.5]}';
      final segs = parseWhisperSegments(json);
      expect(segs.length, 1);
      expect(segs.single.text, 'Hi');
    });

    test('缺 segment 字段 → 空列表（调用方回退按句切分）', () {
      const json = '{"text":"Hi there.","tokens":[" Hi"," there."]}';
      expect(parseWhisperSegments(json), isEmpty);
    });

    test('三数组长度不齐 → 空列表', () {
      const json =
          '{"segment_texts":[" a"," b"],'
          '"segment_timestamps":[0.0],'
          '"segment_durations":[1.0,1.0]}';
      expect(parseWhisperSegments(json), isEmpty);
    });

    test('非法 JSON → 空列表', () {
      expect(parseWhisperSegments('not json'), isEmpty);
      expect(parseWhisperSegments('[1,2,3]'), isEmpty);
    });
  });

  group('firstAudibleFrameIndex（静音跳过：能量检测，非人声检测）', () {
    // 帧长 320；构造若干帧。
    Float32List frames(List<double> perFrameAmp) {
      final out = Float32List(perFrameAmp.length * 320);
      for (var f = 0; f < perFrameAmp.length; f++) {
        for (var i = 0; i < 320; i++) {
          out[f * 320 + i] = perFrameAmp[f];
        }
      }
      return out;
    }

    test('全静音 → -1', () {
      // 均方 = 1e-6 < 1e-4 阈值。
      expect(firstAudibleFrameIndex(frames([0.001, 0.001, 0.0])), -1);
    });

    test('首个可听帧的起始下标（前面两帧静音，第三帧有声）', () {
      // 0.05 均方 = 2.5e-3 ≥ 阈值。
      expect(firstAudibleFrameIndex(frames([0.0, 0.001, 0.05])), 640);
    });

    test('第一帧即有声 → 0', () {
      expect(firstAudibleFrameIndex(frames([0.2, 0.0])), 0);
    });

    test('不足一帧的残余忽略', () {
      expect(firstAudibleFrameIndex(Float32List(100)), -1);
    });
  });

  group('splitTextIntoSentences（回退：无 segment 时间戳时按标点切句）', () {
    test('按 . ? ! 切句，保留标点、归一空白、trim', () {
      final s = splitTextIntoSentences(
        'Hello, Genos.  How many people?   Four! ',
      );
      expect(s, ['Hello, Genos.', 'How many people?', 'Four!']);
    });

    test('末尾无标点的残句也成一句', () {
      expect(splitTextIntoSentences('Hi there. Let us see'), [
        'Hi there.',
        'Let us see',
      ]);
    });

    test('连续标点（省略号/?!）归入同一句', () {
      expect(splitTextIntoSentences('Wait... Really?!'), [
        'Wait...',
        'Really?!',
      ]);
    });

    test('空串 → 空列表', () {
      expect(splitTextIntoSentences(''), isEmpty);
      expect(splitTextIntoSentences('   '), isEmpty);
    });
  });

  group('slidingWindowCues（滑窗编排核心：注入 fake 解码，覆盖各种长短音频）', () {
    const rate = 16000;

    // 恒有声音频（均方 4e-4 ≥ 阈值），readWindow 越界截断、超尾空。
    Float32List Function(int, int) audible(int total) => (start, count) {
      final end = (start + count > total) ? total : start + count;
      if (start >= end) return Float32List(0);
      return Float32List(end - start)..fillRange(0, end - start, 0.02);
    };

    // 前 [silentSamples] 静音、其后有声。
    Float32List Function(int, int) silentThenAudible(
      int total,
      int silentSamples,
    ) => (start, count) {
      final end = (start + count > total) ? total : start + count;
      if (start >= end) return Float32List(0);
      final out = Float32List(end - start);
      for (var i = 0; i < out.length; i++) {
        out[i] = (start + i) < silentSamples ? 0.0 : 0.02;
      }
      return out;
    };

    // 按调用序返回预置解码结果，并记录调用次数。
    WindowDecoder scripted(
      List<(List<WhisperSegment>, String)> responses,
      List<int> callCount,
    ) => (samples) {
      final r = responses[callCount[0]];
      callCount[0]++;
      return r;
    };

    WhisperSegment seg(String t, double start, double dur) =>
        WhisperSegment(t, start, dur);

    test('短音频（< 30s 单窗）单段：绝对时间正确', () {
      final calls = [0];
      final cues = slidingWindowCues(
        5 * rate,
        audible(5 * rate),
        scripted([
          ([seg('hello', 0.0, 4.5)], 'hello'),
        ], calls),
      );
      expect(calls[0], 1);
      expect(cues, [const TranscriptionCue('hello', 0, 4500)]);
    });

    test('单窗多段（末窗全保留，不丢末段）', () {
      final calls = [0];
      final cues = slidingWindowCues(
        10 * rate,
        audible(10 * rate),
        scripted([
          ([seg('a', 0, 3), seg('b', 3, 4), seg('c', 7, 2)], 'a b c'),
        ], calls),
      );
      expect(calls[0], 1);
      expect(cues, const [
        TranscriptionCue('a', 0, 3000),
        TranscriptionCue('b', 3000, 7000),
        TranscriptionCue('c', 7000, 9000),
      ]);
    });

    test('多窗滑动：推进到倒数第二段结束、丢末段并在下一窗重解析，无重复无间隙', () {
      final calls = [0];
      final cues = slidingWindowCues(
        60 * rate,
        audible(60 * rate),
        scripted([
          // 窗[0,30) 非末窗：丢 C，推进到 B.end=20s
          ([seg('A', 0, 10), seg('B', 10, 10), seg('C', 20, 8)], 'A B C'),
          // 窗[20,50) 非末窗：C 重解析并输出、丢 E，推进到 D.end=20+18=38s
          ([seg('C', 0, 8), seg('D', 8, 10), seg('E', 18, 8)], 'C D E'),
          // 窗[38,60)=22s 末窗：全用
          ([seg('E', 0, 10), seg('F', 10, 10)], 'E F'),
        ], calls),
      );
      expect(calls[0], 3);
      expect(cues, const [
        TranscriptionCue('A', 0, 10000),
        TranscriptionCue('B', 10000, 20000),
        TranscriptionCue('C', 20000, 28000),
        TranscriptionCue('D', 28000, 38000),
        TranscriptionCue('E', 38000, 48000),
        TranscriptionCue('F', 48000, 58000),
      ]);
    });

    test('全静音音频：不解码、空结果、正常终止', () {
      final total = 10 * rate;
      final cues = slidingWindowCues(total, (start, count) {
        final end = (start + count > total) ? total : start + count;
        return start >= end ? Float32List(0) : Float32List(end - start);
      }, (samples) => fail('全静音不应触发解码'));
      expect(cues, isEmpty);
    });

    test('前导长静音被跳过：首个 cue 从有声处起（含 0.15s 前导）', () {
      final calls = [0];
      final total = 15 * rate;
      const silent = 10 * rate; // 前 10s 静音
      final cues = slidingWindowCues(
        total,
        silentThenAudible(total, silent),
        scripted([
          ([seg('late', 0.0, 4.0)], 'late'),
        ], calls),
      );
      expect(calls[0], 1);
      expect(cues.length, 1);
      // seek 跳到 10s - 0.5s 前导 = 9.5s，cue 从此起。
      expect(cues.single.startMs, 9500);
      expect(cues.single.text, 'late');
    });

    test('无 segment 但有文本：按句切分 + 字符比例估时（回退路径）', () {
      final calls = [0];
      final cues = slidingWindowCues(
        6 * rate,
        audible(6 * rate),
        scripted([(<WhisperSegment>[], 'Hello there. Bye.')], calls),
      );
      // 'Hello there.'(12) + 'Bye.'(4) = 16 chars，跨度 6s。
      expect(cues, const [
        TranscriptionCue('Hello there.', 0, 4500),
        TranscriptionCue('Bye.', 4500, 6000),
      ]);
    });

    test('防打转：整窗单段（连续说话无停顿）逐窗推进、正常终止', () {
      final calls = [0];
      final cues = slidingWindowCues(
        90 * rate,
        audible(90 * rate),
        scripted([
          ([seg('X', 0, 30)], 'X'),
          ([seg('Y', 0, 30)], 'Y'),
          ([seg('Z', 0, 30)], 'Z'),
        ], calls),
      );
      expect(calls[0], 3);
      expect(cues, const [
        TranscriptionCue('X', 0, 30000),
        TranscriptionCue('Y', 30000, 60000),
        TranscriptionCue('Z', 60000, 90000),
      ]);
    });

    test('短段+超长段：丢末段推进不足 → 改全用整窗，长段不被漏掉', () {
      final calls = [0];
      final cues = slidingWindowCues(
        60 * rate,
        audible(60 * rate),
        scripted([
          // 窗[0,30) 非末窗：candidate=tiny.end=0.5s<1s → 全用、推进整窗
          ([seg('tiny', 0.0, 0.5), seg('huge', 0.5, 28.5)], 'tiny huge'),
          ([seg('W', 0, 20)], 'W'), // 窗[30,60) 末窗
        ], calls),
      );
      expect(calls[0], 2);
      expect(cues, const [
        TranscriptionCue('tiny', 0, 500),
        TranscriptionCue('huge', 500, 29000),
        TranscriptionCue('W', 30000, 50000),
      ]);
    });

    test('空音频（0 样本）：空结果、不解码', () {
      final cues = slidingWindowCues(
        0,
        (start, count) => Float32List(0),
        (samples) => fail('空音频不应解码'),
      );
      expect(cues, isEmpty);
    });

    test('进度回调单调递增、末尾到达总样本数', () {
      final calls = [0];
      final progress = <int>[];
      slidingWindowCues(
        50 * rate,
        audible(50 * rate),
        scripted([
          // 窗[0,30) 非末窗：丢 C、推进到 B.end=20s
          ([seg('A', 0, 10), seg('B', 10, 10), seg('C', 20, 8)], 'A B C'),
          // 窗[20,50)=30s 末窗：全用、推进整窗 → 结束
          ([seg('C', 0, 8), seg('D', 8, 10)], 'C D'),
        ], calls),
        onProgress: progress.add,
      );
      expect(calls[0], 2);
      // 单调不减。
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
      }
      expect(progress.last, 50 * rate);
    });
  });
}
