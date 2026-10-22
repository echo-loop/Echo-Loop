/// 学习练习页面返回给学习计划页的完成结果。
///
/// 只有用户确认完成练习后才返回 [completed]；取消完成弹窗、重播或主动退出
/// 均返回 `null`，调用方可据此避免把退出误判为一次完成事件。
enum PracticeCompletionResult { completed }
