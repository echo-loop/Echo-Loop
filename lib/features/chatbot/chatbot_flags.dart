/// 通用 Chatbot 组件的编译期开关。
///
/// 后端流式聊天端点尚未上线，若无开关，一旦合入线上用户就会看到一个每次必失败的
/// AI 入口。组件与测试照常合入，后端就绪后翻开关即可。
library;

/// 是否对用户暴露 chatbot 入口（句子讲解页 AppBar AI 按钮等）。
///
/// 默认 **false**：后端端点未就绪前不上线。后端就绪后改 true 发布。
const bool kChatbotEnabled = true;

/// 是否使用 debug 假流实现（[FakeChatApiClient]）替代真实网络客户端。
///
/// 默认 **false**（走真实后端）。仅本地联调 / 手动验收（后端未就绪时跑通流式/停止/
/// markdown/多轮）时临时置 true；不进 release 逻辑分支。
const bool kChatbotUseFakeApi = true;
