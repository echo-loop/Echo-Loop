# Echo Loop — 开发 Fork

使用 Flutter 的英语听说应用，包含音频/字幕导入、句子训练与间隔复习。

[English](README.md) · [上游 echo-loop/Echo-Loop](https://github.com/echo-loop/Echo-Loop) · [Fork v1.0.39 源码](https://github.com/styayur/Echo-Loop/releases/tag/v1.0.39)

**Fork / 开发源码。** 保留上游作品与贡献者归属。此 Fork 的 v1.0.39 只提供源码 ZIP，没有独立验收的移动/桌面安装包。上游商店和 Release 属于上游产品，不能证明此 Fork 的构建或生产服务可用。

<img src="assets/screenshots/04-intensive.png" alt="上游句子训练宣传图，带设备边框" width="280" />

这是带设备边框的既有上游宣传图，不是独立捕获的 Fork 运行截图，也不是本次真机验收。原产品、方法论和学术指导致谢保留在[治理前的上游衍生说明](https://github.com/styayur/Echo-Loop/blob/a28e2a31503e33065e25136b630763c880e98325/README.en.md)。

## 源码能力与已知风险

包含精听、跟读、盲听、复述、收藏/闪卡、词典、进度统计、AI 翻译/解析/转录，以及需下载模型的 Kokoro v1.1 本地 TTS / 文本转课时。工作流、界面、后端和分发渠道须分别验证，不作学习效果保证。

[PLAN.md](PLAN.md) 和 [TASKS.md](TASKS.md)仍记录 Android 离线 ASR 结束录音 native 崩溃、录音模块复用、启动真机验收及生产订阅验证。源码存在、单测通过不代表生产就绪。iOS/Android 是主要移动构建目标；存在 macOS/Windows 目录或上游平台徽章不等于已验证的 Fork 发行版。

## 源码准备

使用 [CI](.github/workflows/ci.yml)固定的 **Flutter 3.41.5**。`pubspec.yaml` 的 Dart SDK 要求是 `^3.9.2`，不是 Flutter 3.9.2。Android 需 SDK / Java 17；iOS 需 macOS / Xcode / CocoaPods，并准备模拟器或设备。

在新检出的目录中，用 PowerShell 运行：

```powershell
git clone https://github.com/styayur/Echo-Loop.git
cd Echo-Loop
Copy-Item .dev.env.template .dev.env
flutter pub get
dart run build_runner build
flutter devices
```

按模板变量名称填写自己获授权的 Supabase、Google 与开发后端配置；不要覆盖已有 `.dev.env`，不要提交凭据。本仓库不提供生产后端，也不自动配置这些服务。Android/iOS dev 设备运行：

```text
flutter run --flavor dev -d <DEVICE_ID> --dart-define-from-file=.dev.env
```

用 `flutter devices` 中的 ID 替换 `<DEVICE_ID>`。开发和生产 flavor/签名不同，发版前阅读现有脚本及[订阅配置](docs/subscription-setup.md)，不要把上游生产账号或支付配置当成测试数据。

## 数据与联网边界

本地音频、进度、收藏和下载模型与外部认证、AI、订阅集成并存。AI 请求可向所选服务发送资料并产生费用；迁移/测试前备份本地数据。源码运行不保证默认私密或完全离线。

继承源码中包含 PostHog 分析和会话回放；Dart 默认开启 replay，未屏蔽全部文字/图像。平台原生初始化与同意机制还需真机审查。使用私密资料前检查[分析配置](lib/analytics/channels/posthog_channel.dart)、[通道选择](lib/analytics/analytics_providers.dart)和各平台入口。debug 日志行为不能证明 release 隐私；本次文档不修改遥测或服务设置。

## 测试与贡献

先按 [AGENTS.md](AGENTS.md) 阅读 PLAN、TASKS，保持小范围修改，保留上游归属、许可证和独立 Claude 配置。Dart 修改运行相关检查：

```text
flutter analyze <affected-files>
flutter test <relevant-test-files>
```

现有通用 CI 忽略纯 Markdown 修改，PR 仍运行 CodeForge regression。设备/UI 验证在工具链和设备可用时使用现有 Maestro 脚本；何时运行广泛检查见 AGENTS。本次纯文档修改不构成 Flutter、移动构建、真实 ASR 或购买验收。

通过 [Fork Issues](https://github.com/styayur/Echo-Loop/issues) 提交脱敏复现，注明上游问题或 Fork 差异。敏感问题使用上游已公布的私下联系方式，不在公开记录中放个人学习材料、账号、录音或凭据。

## 许可证与来源

保留现有 [AGPL-3.0](LICENSE) 及上游贡献者声明。[第三方声明](THIRD_PARTY_NOTICES.md)记录独立模型/库条款和历史 TinyTTS MIT 归属。当前 TinyTTS 是 GPL-3.0-or-later；历史说明不把当前版本标成 MIT。具体改编自哪个 TinyTTS 提交仍需补齐来源证据。本次治理不重新许可外部贡献或第三方素材。
