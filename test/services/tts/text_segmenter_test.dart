import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/services/tts/text_segmenter.dart';

void main() {
  const segmenter = TextSegmenter(maxChars: 80);

  group('TextSegmenter', () {
    test('空输入返回空列表', () {
      expect(segmenter.split('   \n  '), isEmpty);
    });

    test('英文按句末切分并保留标点', () {
      expect(segmenter.split('Hello world. How are you? Fine!'), [
        'Hello world.',
        'How are you?',
        'Fine!',
      ]);
    });

    test('中文按中文标点切分', () {
      expect(segmenter.split('你好。今天好吗？很好！'), ['你好。', '今天好吗？', '很好！']);
    });

    test('中英混合按各自标点切分', () {
      expect(segmenter.split('I am learning 机器学习。它很有趣！'), [
        'I am learning 机器学习。',
        '它很有趣！',
      ]);
    });

    test('小数不误切', () {
      expect(segmenter.split('Pi is 3.14 now.'), ['Pi is 3.14 now.']);
    });

    test('常见缩写不误切', () {
      expect(segmenter.split('Mr. Smith met Dr. Brown. Then he left.'), [
        'Mr. Smith met Dr. Brown.',
        'Then he left.',
      ]);
    });

    test('URL 与文件名不误切', () {
      expect(segmenter.split('Open https://example.com/docs.txt now. Done.'), [
        'Open https://example.com/docs.txt now.',
        'Done.',
      ]);
    });

    test('重复标点作为同一句结尾', () {
      expect(segmenter.split('Really?! Yes...'), ['Really?!', 'Yes...']);
    });

    test('长句优先按逗号软切', () {
      final text =
          'alpha, beta, gamma, delta, epsilon, zeta, eta, theta, iota, '
          'kappa, lambda, mu, nu, xi, omicron, pi, rho, sigma';
      final segments = segmenter.split(text);
      expect(segments.length, greaterThan(1));
      expect(segments.every((s) => s.length <= 80), isTrue);
      expect(segments.join(' '), text);
    });

    test('没有标点的超长文本按空白或硬边界切分', () {
      final text = 'a' * 201;
      final segments = segmenter.split(text);
      expect(segments.length, greaterThan(1));
      expect(segments.join(), text);
      expect(segments.every((s) => s.length <= 80), isTrue);
    });
  });
}
