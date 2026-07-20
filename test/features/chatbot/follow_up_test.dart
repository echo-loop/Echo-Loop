/// composeFollowUp 纯逻辑测试：指令 + <quote> 标签 + 问题 拼装。
library;

import 'package:echo_loop/features/chatbot/follow_up.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 指令由调用方按界面语言传入，测试用占位串即可。
  const instruction = '请仅根据下方引用的内容回答问题。';

  group('composeFollowUp', () {
    test('单行引用：指令 + <quote> 包裹 + 问题', () {
      expect(
        composeFollowUp('详细解释', 'pretty busy', instruction: instruction),
        '$instruction\n\n<quote>\npretty busy\n</quote>\n\n详细解释',
      );
    });

    test('多行引用：原文原样放入标签', () {
      expect(
        composeFollowUp('翻译', '第一行\n第二行', instruction: instruction),
        '$instruction\n\n<quote>\n第一行\n第二行\n</quote>\n\n翻译',
      );
    });

    test('引用两端空白被裁剪', () {
      expect(
        composeFollowUp('举个例子', '  hello  ', instruction: instruction),
        '$instruction\n\n<quote>\nhello\n</quote>\n\n举个例子',
      );
    });

    test('空引用原样返回问题', () {
      expect(composeFollowUp('你好', '', instruction: instruction), '你好');
      expect(composeFollowUp('你好', '   ', instruction: instruction), '你好');
    });
  });
}
