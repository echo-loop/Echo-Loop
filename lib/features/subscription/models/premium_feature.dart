/// 受付费墙保护的能力清单。
///
/// 业务各处只通过 `featureAccessProvider(feature)` 询问「某能力是否解锁」，
/// 永远不直接接触订阅 / RevenueCat 状态（解耦核心）。新增付费点只需在此加一项，
/// 调用点不变。
///
/// 本轮（Phase 0）只覆盖「消耗后端算力的 AI 功能」，核心学习闭环
/// （盲听 / 精听 / 跟读 / 复述 / 复习 / 收藏 / 离线 ASR）全部免费，不入此枚举。
library;

/// Premium 付费能力枚举。
enum PremiumFeature {
  /// AI 句子翻译（后端 LLM）。
  aiTranslation,

  /// AI 句子解析（后端 LLM）。
  aiAnalysis,

  /// AI 意群切分（后端 LLM）。
  aiSenseGroup,

  /// AI 单词深度解析（后端 LLM）。
  ///
  /// 注意（C2 前置约束）：当前词解端点 `/api/v1/ai/word-analyze`
  /// 是匿名端点（`SentenceAiApiClient.analyzeWord` 无 accessToken 参数）。
  /// 挂付费墙前必须先把该端点鉴权化，否则后端无法按 user_id 裁决配额，
  /// 付费墙在这一项形同虚设。详见计划文件 Phase 1。
  aiWordAnalysis,

  /// AI 转录字幕（后端转录算力，最耗成本）。
  aiTranscription,

  /// AI 对话助手（后端 LLM 多轮对话）。
  aiChat,
}
