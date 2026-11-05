import 'package:echo_loop/services/pronunciation/word_audio_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 黄金样例由单词发音库生成端（identity.py normalize_v1 + object_key）计算得出，
  // 两端必须逐字节一致，否则 CDN 上的文件无法命中。
  group('wordAudioFileName 与生成端一致', () {
    const golden = <String, String>{
      'Hello': '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824.m4a',
      'Apple': '3a7bd3e2360a3d29eea436fcfb7e44c735d117c42d1c1835420b6b9942dd4f1b.m4a',
      'US': '9b202ecbc6d45c6d8901d989a918878397a3eb9d00e8f48022fc051b19d21a1d.m4a',
      'eBay': '10c2fec550e262efcc23279e9737cc8a9d33f065d1c5360c1db7c89130a61988.m4a',
      'I': 'a83dd0ccbffe39d071cc317ddf6e97f5c6b1c87af91919271f9fa140b0508c6c.m4a',
      'Mr.': '6405cf0c2f2418e27e5306348e1f3a887bb3ece435443a24a4318ce812352982.m4a',
      'U.S.': '5e4eb7c58d5394adc20a9b796aa9f693146cb3c384eeedc8bf275ddbf0442372.m4a',
      'café': '850f7dc43910ff890f8879c0ed26fe697c93a067ad93a7d50f466a7028a9bf4e.m4a',
      "don't": 'df7682099c96e3f66171aed65ba78ae5200ba7200278569327e6cabf16c98b96.m4a',
      'mother-in-law': '60ecead6c7be1b13ddfcd1f9d5387559a604ed247d181194115a061fe5d27e79.m4a',
    };

    golden.forEach((word, fileName) {
      test('$word -> $fileName', () {
        expect(wordAudioFileName(word), fileName);
      });
    });

    test('首尾空白先被去掉', () {
      expect(wordAudioFileName('  Hello  '), wordAudioFileName('Hello'));
    });
  });

  group('wordAudioFileName 拒绝不在 CDN 合同内的输入', () {
    const rejected = <String>[
      '',
      '   ',
      'a1',
      'two words',
      '-apple',
      "apple'",
      '你好',
      'hello!',
      // NFD：e + 组合重音。Dart 无 NFC，直接交给 TTS，避免哈希与生成端不一致。
      'café',
    ];

    for (final word in rejected) {
      test('"$word" 返回 null', () {
        expect(wordAudioFileName(word), isNull);
      });
    }
  });
}
