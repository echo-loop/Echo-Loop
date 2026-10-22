# Echo Loop — development fork

A Flutter English-listening and speaking application with audio/subtitle import, sentence practice and spaced review.

[简体中文](README.zh-CN.md) · [Upstream: echo-loop/Echo-Loop](https://github.com/echo-loop/Echo-Loop) · [Fork source v1.0.39](https://github.com/styayur/Echo-Loop/releases/tag/v1.0.39)

**Fork / development source.** This repository retains upstream work and contributor attribution. Its v1.0.39 release contains a source ZIP, not independently validated mobile/desktop installers. Upstream store listings and releases are upstream products; they do not certify this fork's builds or production services.

<img src="assets/screenshots/04-intensive.png" alt="Upstream promotional image of sentence practice inside a device frame" width="280" />

Existing upstream promotional image with a device frame, not an independently captured running fork or a new device-acceptance result. Original product/methodology acknowledgements remain available in the [pre-governance upstream-derived README](https://github.com/styayur/Echo-Loop/blob/a28e2a31503e33065e25136b630763c880e98325/README.en.md).

## Implemented scope and known risks

Source includes intensive listening, shadowing, blind listening, retelling, favorites/flashcards, dictionaries, progress/statistics, AI translation/analysis/transcription and optional downloaded Kokoro v1.1 local TTS/text-to-lesson. Core workflow, UI, backend and distribution channels have separate verification needs; no learning-outcome guarantee is made.

[PLAN.md](PLAN.md) and [TASKS.md](TASKS.md) record unresolved Android offline-ASR native crashes after recording, recording-module reuse, startup/device acceptance and production subscription checks. These remain open; source presence and unit tests are not production readiness. iOS/Android are the principal mobile build targets. macOS/Windows directories or upstream platform badges do not establish a validated fork release.

## Source setup

Use Flutter **3.41.5**, the version pinned in [CI](.github/workflows/ci.yml); `pubspec.yaml` declares Dart `^3.9.2`, not Flutter 3.9.2. Install the target platform SDK: Android SDK/Java 17 for Android, or macOS/Xcode/CocoaPods for iOS. Choose a configured emulator/device.

From a new checkout in PowerShell:

```powershell
git clone https://github.com/styayur/Echo-Loop.git
cd Echo-Loop
Copy-Item .dev.env.template .dev.env
flutter pub get
dart run build_runner build
flutter devices
```

Edit `.dev.env` with your own authorized development Supabase, Google and backend settings using the template's variable names; do not overwrite an existing file or commit credentials. This repository is not the production backend and does not provision those services. For an Android/iOS development device:

```text
flutter run --flavor dev -d <DEVICE_ID> --dart-define-from-file=.dev.env
```

Replace `<DEVICE_ID>` with an ID from `flutter devices`. Development and production flavors/signing differ; follow the existing scripts and [subscription setup](docs/subscription-setup.md) before attempting a release. Do not use upstream production accounts or payment configuration as test fixtures.

## Data and network boundary

Local audio, progress, favorites and downloaded models coexist with external authentication, AI and subscription integrations. AI requests can send material to configured services and incur charges. Back up local data before migration/testing; source setup is not a private/offline-by-default assurance.

The inherited source includes PostHog analytics and session replay. Dart defaults enable replay without masking all text/images; platform-native setup and consent behavior need device review. Inspect [analytics configuration](lib/analytics/channels/posthog_channel.dart), [channel selection](lib/analytics/analytics_providers.dart) and platform initialization before using private learning material. Debug logging behavior does not establish release privacy. No telemetry or service settings are changed by this documentation PR.

## Tests and contributing

Read [AGENTS.md](AGENTS.md), then PLAN and TASKS. Keep changes focused and preserve upstream credits, licenses and the separate Claude configuration files. For affected Dart code, run the relevant analysis and tests:

```text
flutter analyze <affected-files>
flutter test <relevant-test-files>
```

The existing general CI ignores Markdown-only changes; the CodeForge regression workflow still applies to PRs. Device/UI verification uses the existing Maestro scripts when the appropriate device/toolchain is available; [AGENTS.md](AGENTS.md) describes when to run broader checks. A documentation-only change does not constitute Flutter, mobile-build, live ASR or purchase acceptance.

Use [fork Issues](https://github.com/styayur/Echo-Loop/issues) for fork-specific redacted reproductions, and distinguish upstream defects from fork changes. Report sensitive issues through the upstream project's published private contact rather than posting personal learning data, accounts, recordings or credentials publicly.

## License and provenance

Keep the existing [AGPL-3.0 license](LICENSE) and upstream contributor notices. [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) records independent model/library terms and historical TinyTTS MIT attribution. Current TinyTTS uses GPL-3.0-or-later; the historical notice does not label current versions as MIT. The exact adapted TinyTTS revision remains a provenance follow-up. External contributors and third-party assets are not relicensed by this governance work.
