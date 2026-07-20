/// 追问引用的纯逻辑：把用户问题/指令与被引用文本拼成发后端的一条文本。
///
/// 仅在序列化发后端时使用（[ChatMessage.toWire]），不参与气泡显示——显示层
/// 用 content（纯问题）+ quote（引用）分离渲染。
library;

/// 把 [message]（用户问题或快捷指令）与被引用文本 [quote] 拼成发后端的文本。
///
/// 结构：显式指令 [instruction] + `<quote></quote>` 标签包裹的引用原文 + 用户问题。
/// 用 XML 标签明确界定引用边界（模型对该类标签识别最稳定），让模型清楚「这是一段
/// 引用，需基于它作答」，避免脱离引用泛泛回答。
///
/// [instruction] 由调用方按界面语言传入（本地化文案），使指令语言与用户界面一致——
/// 否则英文指令会让模型倾向用英文回答。空引用时原样返回 [message]。
String composeFollowUp(
  String message,
  String quote, {
  required String instruction,
}) {
  final trimmedQuote = quote.trim();
  if (trimmedQuote.isEmpty) return message;
  return '$instruction\n\n'
      '<quote>\n$trimmedQuote\n</quote>\n\n'
      '$message';
}
