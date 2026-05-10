# Privacy and Data Notes

This document summarizes data-sensitive behavior visible from the open-source codebase. The in-app privacy policy remains the user-facing legal policy:

- Terms: https://www.echo-loop.top/terms
- Privacy policy: https://www.echo-loop.top/privacy

## Local learning materials

Echo Loop is designed around user-selected learning materials:

- Local audio files.
- Local subtitle files.
- Generated transcripts.
- Saved hard sentences, saved words, flashcards, review state, and learning progress.
- Speech-practice recordings or temporary audio files created during practice.

These files and records should be treated as private user data. Do not ask users to upload private materials in public GitHub issues. If a sample is needed for debugging, ask for a minimal non-private reproduction file.

## Networked features

Some features may contact Echo Loop services or third-party services depending on build configuration and user action:

- AI transcription, translation, sentence analysis, and vocabulary explanation.
- Official curated collections and remote collection metadata/content downloads.
- Update checks and release download links.
- Region lookup used by analytics/network configuration.

When documenting or changing these features, be explicit about whether user-provided audio, subtitles, transcripts, recordings, or derived text leave the device.

## Analytics

The current release-mode analytics path uses PostHog when configured in code. Firebase and Umeng channels exist in the codebase as fallback or legacy options, but the current provider comments indicate PostHog is the active release channel.

Analytics-related changes should be reviewed carefully because they may involve:

- A generated app user identifier.
- Screen and feature usage events.
- Super properties or user properties.
- Session replay configuration on supported platforms.
- Region or platform metadata.

Do not add analytics events containing raw audio text, full transcripts, speech recordings, imported file names, private collection names, or user-entered learning content unless there is an explicit privacy review and user-facing disclosure.

## Contributor checklist for data-sensitive changes

- Avoid logging private learning content.
- Avoid including private file paths in analytics or crash reports.
- Keep debug logs out of release behavior when they may contain private content.
- Prefer aggregate counts and state transitions over raw content.
- Update this document and the user-facing privacy policy when behavior changes.
- Add tests around deletion, export, backup, permission, or consent behavior when applicable.

## Public issue guidance

For bugs involving private content:

- Describe the symptom and platform.
- Share a synthetic sample when possible.
- Redact filenames, transcripts, personal notes, and recordings.
- Use the private security contact for suspected leaks or exposure.

