# Echo Loop Growth Playbook

Goal: grow Echo Loop through authentic usage, feedback, and open-source visibility. Do not buy stars, trade stars, automate fake accounts, scrape private contacts, or post the same message repeatedly across communities.

Current baseline checked on 2026-05-10: 5 GitHub stars.

## Positioning

One-line pitch:

> Echo Loop is an open-source English listening and speaking trainer that guides learners through blind listening, intensive listening, shadowing, retelling, and spaced review.

Short pitch:

> Most English apps give you content, but still leave you deciding what to do next. Echo Loop turns one audio clip into a complete practice loop: listen first, understand sentence by sentence, shadow, retell, and review before you forget. It is open source, available on iOS, and supports local audio plus AI subtitles.

Primary audiences:

- English learners who already use podcasts, videos, or local audio but lack a repeatable practice method.
- Teachers and self-study groups that need a structured listening and speaking workflow.
- Flutter and open-source developers interested in language-learning apps, audio workflows, ASR, spaced review, and local-first learning tools.

## Growth targets

| Stage | Star target | Main proof needed | Primary action |
|---|---:|---|---|
| Baseline | 5 -> 50 | Clear repo page, install path, screenshots | Share with direct learning and Flutter communities |
| Early traction | 50 -> 200 | Real user feedback, bugs fixed quickly | Weekly releases and public changelog posts |
| Community fit | 200 -> 1000 | Repeatable use cases, teachers/groups trying it | Case studies, demo videos, bilingual posts |
| Broad awareness | 1000 -> 5000 | Strong demo, stable Android/iOS path, contributor flow | Launch campaigns, newsletters, curated lists |

## Repository readiness checklist

- [x] Clear Chinese README.
- [x] English README.
- [x] Screenshots in README.
- [x] App Store link.
- [x] Android APK link through GitHub Releases.
- [x] Contribution guide.
- [ ] GitHub repository topics set in the repo settings.
- [ ] Pinned release with APK and concise release notes.
- [ ] Short demo video or GIF near the top of README.
- [x] `SECURITY.md` or privacy/security note for audio, subtitles, analytics, and local files.
- [ ] Issue templates for bugs, feature requests, and learning-method feedback.

Suggested GitHub topics:

```text
english-learning
language-learning
listening-practice
speaking-practice
shadowing
spaced-repetition
flutter
dart
audio
asr
open-source
education
```

## 14-day launch cadence

Day 1:

- Confirm latest iOS and Android download links.
- Add GitHub topics.
- Pin the current stable release.
- Create one 60-90 second demo video showing import, intensive listening, shadowing, retelling, and review.

Day 2:

- Post to WeChat group and existing personal networks.
- Ask for concrete feedback, not stars. A useful call to action: "Try one 3-minute audio clip and tell us where the loop breaks."

Day 3:

- Publish a Chinese long-form post on Zhihu, Juejin, or a personal blog explaining the learning method and why the app is open source.
- Link to the repo and App Store once near the top and once at the end.

Day 4:

- Share a Flutter developer post focused on implementation: audio import, subtitle parsing, spaced review, native ASR, Drift, Riverpod.

Day 5:

- Open 3-5 beginner-friendly issues with clear scope.
- Label them `good first issue`, `docs`, or `help wanted`.

Day 6:

- Post to V2EX or similar developer communities with an honest build log. Ask for product and technical feedback.

Day 7:

- Review all comments and issues.
- Ship small fixes quickly and write a concise release note.

Day 8:

- Share a before/after clip: "one audio clip, practiced through Echo Loop's full loop."

Day 9:

- Reach out manually to 10 English teachers, study-group organizers, or content creators. Personalize every message.

Day 10:

- Submit to open-source directories and curated lists related to Flutter, education, language learning, and spaced repetition.

Day 11:

- Publish the English post for Reddit, Indie Hackers, Hacker News "Show HN", or Product Hunt. Use community-specific wording and follow each community's rules.

Day 12:

- Convert common questions into README FAQ entries.

Day 13:

- Share metrics transparently: downloads, stars, issues, fixes, lessons learned.

Day 14:

- Decide the next growth bet based on real signals: retention feedback, teacher adoption, Android demand, contributor interest, or content-library demand.

## Weekly maintenance loop

- Monday: check star/download issue metrics and update `docs/star-growth-log.md`.
- Tuesday: ship one user-visible improvement or documentation fix.
- Wednesday: publish one learning-method or build-log post.
- Thursday: reply to issues, discussions, and community comments.
- Friday: package a release note with screenshots or short clips.

## Channel guidance

GitHub:

- Keep releases frequent and clear.
- Use labels so new contributors can find work.
- Avoid asking only for stars. Ask users to try the app, report friction, and star only if they want to follow the project.

Zhihu / Juejin / WeChat:

- Lead with the learning pain: learners do not know what to do next after opening audio.
- Explain the loop and show screenshots.
- Include concrete usage steps.

V2EX / developer communities:

- Lead with the build story and technical tradeoffs.
- Be explicit that feedback is welcome.
- Do not cross-post identical text.

Reddit / HN / Product Hunt:

- Use English copy.
- Make the demo link obvious.
- Be ready to answer privacy, offline, Android, and roadmap questions.

## Guardrails

- Do not automate starring, comments, votes, follows, or fake accounts.
- Do not mass-DM strangers.
- Do not hide that the maintainer is affiliated with the project.
- Do not promise learning outcomes the app cannot prove.
- Do not reuse competitor trademarks in ads beyond fair comparison in documentation.
