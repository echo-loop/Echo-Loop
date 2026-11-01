/// sense_group_validate 单元测试
///
/// 与后端 validate-chunks 两段式一致：精确 concat 或剥空白+标点后相等即通过。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/utils/sense_group_validate.dart';

void main() {
  group('validateSenseGroupChunks', () {
    const sentence = 'I run a company.';

    test('精确 concat 还原原句（chunk 用前导空格表达间距）→ 通过', () {
      expect(
        validateSenseGroupChunks(['I run', ' a company.'], sentence),
        isTrue,
      );
    });

    test('仅空白差异（chunk 被 trim）→ 慢路径剥空白后通过', () {
      expect(
        validateSenseGroupChunks(['I run', 'a company.'], sentence),
        isTrue,
      );
    });

    test('标点/空白漂移但字母数字内容一致 → 慢路径通过', () {
      expect(
        validateSenseGroupChunks(['I', 'run', 'a', 'company'], sentence),
        isTrue,
      );
    });

    test('缺词 → 拼接无法还原 → 失败', () {
      expect(validateSenseGroupChunks(['I run'], sentence), isFalse);
    });

    test('多词 → 拼接超出原句 → 失败', () {
      expect(
        validateSenseGroupChunks(['I run a company. Now.'], sentence),
        isFalse,
      );
    });

    test('内容完全不符 → 失败', () {
      expect(validateSenseGroupChunks(['Goodbye'], sentence), isFalse);
    });

    test('空列表 → 失败', () {
      expect(validateSenseGroupChunks([], sentence), isFalse);
    });

    test('单 chunk 恰为原句 → 通过', () {
      expect(validateSenseGroupChunks([sentence], sentence), isTrue);
    });
  });
}
