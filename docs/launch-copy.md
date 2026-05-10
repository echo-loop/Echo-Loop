# Launch Copy

Use these as starting points. Adapt each post to the community instead of copying the same text everywhere.

## Chinese short post

标题：

```text
我做了一个开源英语听说训练 App：把盲听、精听、跟读、复述和复习串成一个闭环
```

正文：

```text
Echo Loop 是一个开源英语听说训练 App。

它不是再给你一堆材料，而是把一段音频练透：先盲听，再逐句精听，接着跟读、复述，最后按间隔复习把难句拉回来。

我做它的原因很简单：很多人不是不愿意练英语，而是每次打开材料都要重新判断下一步该做什么。Echo Loop 会直接告诉你当前步骤，把练习节奏自动推下去。

目前支持：
- 导入本地音频和字幕，也可以用 AI 生成字幕
- 逐句精听、长难句意群划分
- 跟读评测、段落复述
- 难句收藏、语境化闪卡和间隔复习
- iOS 已上架，Android APK 可在 GitHub Releases 下载

GitHub: https://github.com/echo-loop/Echo-Loop
App Store: https://apps.apple.com/cn/app/echo-loop-%E9%AB%98%E6%95%88%E8%8B%B1%E8%AF%AD%E5%90%AC%E8%AF%B4%E8%AE%AD%E7%BB%83/id6760324074

如果你正在练英语，欢迎拿一段 3 分钟音频试一次完整流程。更希望收到具体反馈：哪一步卡住了、哪里不够顺、哪些功能会让你继续用。
```

## English short post

Title:

```text
Echo Loop: an open-source English listening and speaking trainer
```

Body:

```text
I built Echo Loop, an open-source app for English listening and speaking practice.

Instead of giving learners more content and leaving them to figure out what to do next, Echo Loop turns one audio clip into a complete practice loop: blind listening, intensive listening, shadowing, retelling, and spaced review.

It supports local audio import, subtitles, AI-generated transcripts, sentence-by-sentence listening, hard-sentence review, contextual flashcards, and shadowing evaluation.

Repo: https://github.com/echo-loop/Echo-Loop
App Store: https://apps.apple.com/cn/app/echo-loop-%E9%AB%98%E6%95%88%E8%8B%B1%E8%AF%AD%E5%90%AC%E8%AF%B4%E8%AE%AD%E7%BB%83/id6760324074

I would appreciate concrete feedback from English learners, teachers, and Flutter developers. Try one short audio clip and tell me where the learning loop breaks or feels awkward.
```

## Show HN draft

```text
Show HN: Echo Loop, an open-source app for English listening and speaking practice

Hi HN, I built Echo Loop, an open-source Flutter app for structured English listening and speaking practice.

The idea is to make the practice method explicit. A learner imports an audio clip, then Echo Loop guides them through blind listening, sentence-by-sentence intensive listening, shadowing, retelling, and spaced review.

Why I built it: many learners already have enough content, but still have to decide what to do next, how many times to repeat, what to review, and when to come back. Echo Loop tries to automate that practice rhythm.

It currently supports local audio import, subtitles or AI-generated transcripts, sense-group splitting for long sentences, hard-sentence review, contextual flashcards, and ASR-based shadowing evaluation.

GitHub: https://github.com/echo-loop/Echo-Loop
App Store: https://apps.apple.com/cn/app/echo-loop-%E9%AB%98%E6%95%88%E8%8B%B1%E8%AF%AD%E5%90%AC%E8%AF%B4%E8%AE%AD%E7%BB%83/id6760324074

I would love feedback on the learning flow, the product shape, and the Flutter/audio implementation.
```

## Reddit draft

```text
I built an open-source app that guides English learners through a full listening/speaking loop

I have been working on Echo Loop, an open-source app for English listening and speaking practice.

The core workflow is:
1. Blind listen to a short audio clip.
2. Go sentence by sentence until the content is clear.
3. Shadow the speaker.
4. Retell the paragraph in your own words.
5. Review hard sentences later with spaced repetition.

It supports local audio, subtitles, AI transcripts, saved hard sentences, contextual flashcards, and shadowing evaluation.

GitHub: https://github.com/echo-loop/Echo-Loop

I am looking for practical feedback from learners and teachers: would this workflow fit your study routine, and where would it feel too heavy?
```

## Flutter developer post

```text
Echo Loop is an open-source Flutter app for English listening and speaking practice.

Technical areas that may be useful to other Flutter developers:
- local audio import and playback
- subtitle parsing and sentence tracking
- Drift persistence for learning state
- Riverpod-based learning flow
- native iOS/macOS/Android bridges for speech and audio processing
- spaced review scheduling and local notifications

Repo: https://github.com/echo-loop/Echo-Loop

Feedback on architecture, platform support, and test coverage is welcome.
```

## Direct outreach template

```text
Hi {name}, I am building Echo Loop, an open-source app for English listening and speaking practice.

It guides learners through one complete loop: blind listening, intensive listening, shadowing, retelling, and spaced review.

I noticed your work around {specific class/community/content}. If you have 10 minutes, could you try one short audio clip and tell me where the workflow feels useful or awkward?

GitHub: https://github.com/echo-loop/Echo-Loop
App Store: https://apps.apple.com/cn/app/echo-loop-%E9%AB%98%E6%95%88%E8%8B%B1%E8%AF%AD%E5%90%AC%E8%AF%B4%E8%AE%AD%E7%BB%83/id6760324074

No pressure to promote it. I am mainly looking for concrete product feedback.
```

## Release note template

```text
Echo Loop {version}

Highlights:
- {user-visible change}
- {bug fix}
- {learning-flow improvement}

Try it:
- iOS: {app_store_link}
- Android APK: {release_link}

Feedback wanted:
- Does the practice loop feel clear?
- Which step has the most friction?
- What would make you use it again tomorrow?
```

