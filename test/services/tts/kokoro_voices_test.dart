import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/services/tts/kokoro_voices.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';

void main() {
  group('kokoroVoices 目录', () {
    test('共 103 个发音人，sid 连续覆盖 0..102 且唯一', () {
      expect(kokoroVoices.length, 103);
      final sids = kokoroVoices.map((v) => v.sid).toList()..sort();
      expect(sids, List.generate(103, (i) => i));
    });

    test('id 唯一', () {
      expect(kokoroVoices.map((v) => v.id).toSet().length, 103);
    });

    test('语言分组：英文 3 个、中文 100 个', () {
      expect(voicesForLanguage(TtsLanguage.english).length, 3);
      expect(voicesForLanguage(TtsLanguage.chinese).length, 100);
    });

    test('英文口音分组：美音 2 个、英音 1 个', () {
      expect(voicesForAccent(TtsAccent.us).length, 2);
      expect(voicesForAccent(TtsAccent.uk).length, 1);
    });

    test('英文口音由 id 前缀推导：a*=美音 b*=英音', () {
      expect(voiceById('af_maple')!.accent, TtsAccent.us);
      expect(voiceById('af_sol')!.accent, TtsAccent.us);
      expect(voiceById('bf_vale')!.accent, TtsAccent.uk);
    });

    test('性别由第二字符推导：*f_=女声 *m_=男声', () {
      expect(voiceById('af_maple')!.isFemale, isTrue);
      expect(voiceById('zf_001')!.isFemale, isTrue);
      expect(voiceById('zm_009')!.isFemale, isFalse);
    });
  });

  group('voiceById', () {
    test('已知 id 往返', () {
      final v = voiceById('zf_001');
      expect(v, isNotNull);
      expect(v!.sid, 3);
      expect(v.language, TtsLanguage.chinese);
    });

    test('未知 id 返回 null', () {
      expect(voiceById('not_a_voice'), isNull);
    });
  });

  group('defaultVoice', () {
    test('美音默认 af_sol，且属于美音', () {
      final v = defaultVoice(TtsAccent.us);
      expect(v.id, kokoroDefaultVoiceUs);
      expect(v.id, 'af_sol');
      expect(v.accent, TtsAccent.us);
    });

    test('英音默认 bf_vale，且属于英音', () {
      final v = defaultVoice(TtsAccent.uk);
      expect(v.id, kokoroDefaultVoiceUk);
      expect(v.id, 'bf_vale');
      expect(v.accent, TtsAccent.uk);
    });

    test('中文默认 zf_001', () {
      expect(defaultChineseVoice.id, kokoroDefaultVoiceZh);
      expect(defaultChineseVoice.sid, 3);
    });
  });

  group('sidForVoiceId', () {
    test('已知 voiceId → 对应 sid', () {
      expect(sidForVoiceId('bf_vale', fallbackAccent: TtsAccent.us), 2);
      expect(sidForVoiceId('zf_002', fallbackAccent: TtsAccent.us), 4);
    });

    test('null → 回退到该口音默认音色 sid', () {
      expect(sidForVoiceId(null, fallbackAccent: TtsAccent.us), 1);
      expect(sidForVoiceId(null, fallbackAccent: TtsAccent.uk), 2);
    });

    test('未知 voiceId → 回退默认', () {
      expect(sidForVoiceId('ghost', fallbackAccent: TtsAccent.uk), 2);
    });
  });
}
