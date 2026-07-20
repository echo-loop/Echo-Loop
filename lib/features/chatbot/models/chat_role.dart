/// 对话角色定义。
library;

/// 对话角色。仅 user / assistant 参与后端历史。
enum ChatRole {
  /// 用户消息。
  user,

  /// AI 助手消息。
  assistant,
}
