# Contributing to Echo Loop

Thanks for helping improve Echo Loop. This project is an English listening and speaking trainer built around one complete practice loop: blind listening, intensive listening, shadowing, retelling, and spaced review.

## Good first contributions

- Fix a bug that affects importing audio, subtitles, playback, review scheduling, or speech practice.
- Improve Chinese or English copy in the app and README.
- Add focused tests for learning flow, review reminders, subtitle parsing, ASR settings, or import edge cases.
- Improve Android, iOS, macOS, Windows, or Linux compatibility.
- Improve documentation for setup, release, privacy, or troubleshooting.

## Before opening an issue

Please include:

- What you expected to happen.
- What actually happened.
- Your platform and app version.
- Reproduction steps, preferably with a small sample file if the issue involves audio or subtitles.
- Screenshots or logs when they help explain the problem.

Do not attach private learning materials unless you have permission to share them.

## Development setup

```bash
git clone git@github.com:echo-loop/Echo-Loop.git
cd Echo-Loop
flutter pub get
dart run build_runner build
flutter run -d <ios|android|macos>
```

## Quality checks

Run these before submitting a pull request:

```bash
dart format .
flutter analyze
flutter test
```

If you only changed documentation, mention that no app tests were run because the change is docs-only.

## Pull request checklist

- Keep the change focused on one problem.
- Add or update tests when behavior changes.
- Update README or docs when user-facing behavior changes.
- Keep generated files in sync after Riverpod, Drift, or localization changes.
- Explain manual testing for platform-specific changes.

## Commit style

Use the repository's existing prefix style:

```text
FEAT: add focused review entry point
FIX: handle empty subtitle import
DOCS: clarify Android APK install path
TEST: cover review schedule boundaries
CHORE: update release script comments
```

Common prefixes include `FEAT`, `FIX`, `DOCS`, `MOD`, `OPT`, `CHORE`, `CI`, `RELEASE`, and `TEST`.

## Community standards

Be respectful, specific, and practical. Assume maintainers and contributors are working with limited time. Avoid personal attacks, harassment, spam, and low-effort promotion.

