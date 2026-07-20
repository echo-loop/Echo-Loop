/// Debug 假流实现：不发网络请求，按预置分片逐帧吐 delta、末帧 done。
///
/// 用途：后端端点不存在时跑通手动验收（流式 / 停止 / markdown / 多轮）。
/// 仅当 kChatbotUseFakeApi=true 时由 provider 返回；不进 release 逻辑分支。
library;

import 'dart:async';

import 'package:dio/dio.dart';

import '../models/chat_message.dart';
import '../models/chat_role.dart';
import 'chat_api_client.dart';
import 'ndjson_text_stream.dart';

/// Debug 假实现：按预置 NDJSON 分片以固定间隔逐帧吐 delta、末帧 done，
/// 模拟真实流式节奏；响应 cancelToken 取消（停止吐帧、流结束）。
class FakeChatApiClient implements ChatApi {
  /// 每帧之间的模拟延迟。
  final Duration frameDelay;

  const FakeChatApiClient({this.frameDelay = const Duration(milliseconds: 50)});

  @override
  Stream<ChatTextFrame> streamChat({
    required String endpoint,
    required List<ChatMessage> history,
    required Map<String, Object?> context,
    required String followUpInstruction,
    String? targetLanguage,
    required String accessToken,
    CancelToken? cancelToken,
  }) async* {
    final chunks = _replyChunks(history);
    final buffer = StringBuffer();
    for (final chunk in chunks) {
      if (cancelToken?.isCancelled ?? false) return;
      await Future<void>.delayed(frameDelay);
      if (cancelToken?.isCancelled ?? false) return;
      buffer.write(chunk);
      yield ChatTextFrame(text: buffer.toString(), isFinal: false);
    }
    if (cancelToken?.isCancelled ?? false) return;
    yield ChatTextFrame(text: buffer.toString(), isFinal: true);
  }

  /// 按最后一条用户消息生成一段带 markdown 的假回答分片。
  List<String> _replyChunks(List<ChatMessage> history) {
    final lastUser = history.lastWhere(
      (m) => m.role == ChatRole.user,
      orElse: () => ChatMessage.user(
        id: 'fake',
        content: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    final reply =
        '# Markdown 调试回答\n\n'
        '关于「${lastUser.content}」，可以这样理解：这是一段**较长的假数据**，用于检查流式渲染、选中文本、气泡操作条和各种 markdown 样式。\n\n'
        '## 1. 核心解释\n\n'
        '> 这是一段引用内容。它应该有清晰的左侧引用线，并且在选中时高亮不能被遮挡。\n\n'
        '- **要点一**：粗体应该稳定显示，中文和 English 混排不跳动。\n'
        '- *要点二*：斜体用于测试 inline style。\n'
        '- `inline code`：行内代码需要半透明背景，选区颜色要能透出来。\n'
        '- [示例链接](https://example.com)：链接样式和点击区域需要可见。\n\n'
        '## 2. 分步骤说明\n\n'
        '1. 先观察流式输出时段落是否逐步增长。\n'
        '2. 再拖选跨段文本，确认复制和「问 AI」菜单位置正常。\n'
        '3. 最后检查列表、表格、代码块在窄屏下是否换行。\n\n'
        '## 3. 小表格\n\n'
        '| 类型 | 用途 | 期望效果 |\n'
        '| --- | --- | --- |\n'
        '| 粗体 | 强调重点 | **清晰可读** |\n'
        '| 行内代码 | 标记变量 | `token` 不遮挡选区 |\n'
        '| 表格 | 检查布局 | 单元格自动换行 |\n\n'
        '## 4. 代码块\n\n'
        '```dart\n'
        'final selectedText = message.selection.trim();\n'
        'if (selectedText.isNotEmpty) {\n'
        '  askAi(selectedText);\n'
        '}\n'
        '```\n\n'
        '---\n\n'
        '### 快速结论\n\n'
        '这条 fake response 覆盖了标题、引用、列表、链接、表格、代码块、分隔线和中英文混排。你可以用它来调试 markdown 渲染、流式滚动和选区 toolbar。';
    // 按 2~4 字切片，模拟 token 级流式。
    final chunks = <String>[];
    for (var i = 0; i < reply.length; i += 3) {
      chunks.add(reply.substring(i, (i + 3).clamp(0, reply.length)));
    }
    return chunks;
  }

  @override
  void dispose() {}
}
