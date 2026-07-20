/// accumulateNdjsonText 测试：delta 累计 / done / meta / 错误归一 / 无 done。
library;

import 'dart:async';

import 'package:echo_loop/features/chatbot/services/ndjson_text_stream.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Stream<Map<String, dynamic>> from(List<Map<String, dynamic>> events) =>
      Stream.fromIterable(events);

  test('delta 逐帧累计', () async {
    final frames = await accumulateNdjsonText(
      from([
        {'delta': '它'},
        {'delta': '表示'},
        {'delta': '……'},
        {'done': true},
      ]),
    ).toList();
    expect(frames.map((f) => f.text).toList(), ['它', '它表示', '它表示……', '它表示……']);
    expect(frames.map((f) => f.isFinal).toList(), [false, false, false, true]);
  });

  test('done → isFinal，累计全文透传', () async {
    final frames = await accumulateNdjsonText(
      from([
        {'delta': 'hi'},
        {'done': true},
      ]),
    ).toList();
    expect(frames.last.isFinal, isTrue);
    expect(frames.last.text, 'hi');
  });

  test('meta.messageId 透传，不产生额外帧', () async {
    final frames = await accumulateNdjsonText(
      from([
        {
          'meta': {'messageId': 'msg_1'},
        },
        {'delta': 'a'},
        {'done': true},
      ]),
    ).toList();
    // meta 帧不 yield，仅 delta + done 两帧
    expect(frames, hasLength(2));
    expect(frames.every((f) => f.messageId == 'msg_1'), isTrue);
  });

  test('__error → ChatStreamException', () {
    expect(
      accumulateNdjsonText(
        from([
          {'delta': 'a'},
          {'__error': 'boom'},
        ]),
      ).toList(),
      throwsA(isA<ChatStreamException>()),
    );
  });

  test('行损坏（FormatException）归一为 ChatStreamException', () {
    Stream<Map<String, dynamic>> broken() async* {
      yield {'delta': 'a'};
      throw const FormatException('bad line');
    }

    expect(
      accumulateNdjsonText(broken()).toList(),
      throwsA(isA<ChatStreamException>()),
    );
  });

  test('空闲超时（TimeoutException）归一为 ChatStreamException', () {
    Stream<Map<String, dynamic>> stalled() async* {
      yield {'delta': 'a'};
      throw TimeoutException('idle');
    }

    expect(
      accumulateNdjsonText(stalled()).toList(),
      throwsA(isA<ChatStreamException>()),
    );
  });

  test('无 done 自然结束 → 不 yield final', () async {
    final frames = await accumulateNdjsonText(
      from([
        {'delta': 'a'},
        {'delta': 'b'},
      ]),
    ).toList();
    expect(frames, hasLength(2));
    expect(frames.every((f) => !f.isFinal), isTrue);
  });

  test('未知键忽略', () async {
    final frames = await accumulateNdjsonText(
      from([
        {'unknown': 1},
        {'delta': 'a'},
        {'done': true},
      ]),
    ).toList();
    expect(frames, hasLength(2)); // unknown 帧被忽略
    expect(frames.first.text, 'a');
  });
}
