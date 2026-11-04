import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:echo_loop/models/pronunciation/pronunciation_clip.dart';
import 'package:echo_loop/providers/pronunciation/pronunciation_providers.dart';
import 'package:echo_loop/services/pronunciation/local_audio_clip_player.dart';
import 'package:echo_loop/widgets/tts/speak_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

/// 记录 speak 调用、可注入初始 speakingKey 的假控制器。
class FakeTtsController extends TtsController {
  FakeTtsController({this.initialSpeakingKey});

  final String? initialSpeakingKey;
  final List<({String text, String key})> calls = [];

  @override
  TtsControllerState build() =>
      TtsControllerState(speakingKey: initialSpeakingKey);

  @override
  Future<void> speak(
    String text, {
    String? key,
    bool promptIfModelMissing = true,
  }) async {
    calls.add((text: text, key: key ?? text));
  }

  @override
  Future<AudioPlaybackResult> speakWithResult(
    String text, {
    String? key,
    bool promptIfModelMissing = true,
  }) async {
    calls.add((text: text, key: key ?? text));
    return AudioPlaybackResult.completed;
  }

  @override
  Future<void> stop() async {}
}

/// 记录统一入口是否优先把单词交给离线发音控制器。
class FakePronunciationPlayback extends TextPlaybackController {
  final List<PronunciationClip> calls = [];

  @override
  TextPlaybackState build() => const TextPlaybackState();

  @override
  Future<AudioPlaybackResult> speakWithResult(
    String text, {
    String? key,
    bool promptIfModelMissing = true,
  }) async {
    final clips = ref.read(pronunciationClipsProvider(text));
    if (clips.isNotEmpty) {
      calls.add(clips.first);
      return AudioPlaybackResult.completed;
    }
    return AudioPlaybackResult.failed;
  }
}

Widget _wrap(
  FakeTtsController fake,
  Widget child, {
  Set<String> locallyPronouncedWords = const {},
  FakePronunciationPlayback? pronunciationPlayback,
}) {
  return ProviderScope(
    overrides: dedupeOverrides([
      ttsControllerProvider.overrideWith(() => fake),
      pronunciationClipsProvider.overrideWith(
        (ref, word) => locallyPronouncedWords.contains(word)
            ? [
                PronunciationClip(
                  word: word,
                  locale: 'us',
                  audioFilename: '${word}_us.opus',
                  absolutePath: '/audio/${word}_us.opus',
                  reason: null,
                ),
              ]
            : const [],
      ),
      if (pronunciationPlayback != null)
        textPlaybackProvider.overrideWith(() => pronunciationPlayback),
    ]),
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('点击 → speak(text, key)', (tester) async {
    final fake = FakeTtsController();
    await tester.pumpWidget(
      _wrap(fake, const SpeakButton(text: 'hello', speakKey: 'k')),
    );
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(fake.calls, [(text: 'hello', key: 'k')]);
  });

  testWidgets('未传 key → 默认用文本作 key', (tester) async {
    final fake = FakeTtsController();
    await tester.pumpWidget(_wrap(fake, const SpeakButton(text: 'world')));
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(fake.calls.single.key, 'world');
  });

  testWidgets('离线单词优先走本地发音，不调用 TTS', (tester) async {
    final tts = FakeTtsController();
    final pronunciation = FakePronunciationPlayback();
    await tester.pumpWidget(
      _wrap(
        tts,
        const SpeakButton(text: 'hello'),
        locallyPronouncedWords: {'hello'},
        pronunciationPlayback: pronunciation,
      ),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    expect(pronunciation.calls.single.absolutePath, '/audio/hello_us.opus');
    expect(tts.calls, isEmpty);
  });

  testWidgets('空文本 → 按钮禁用，不发音', (tester) async {
    final fake = FakeTtsController();
    await tester.pumpWidget(_wrap(fake, const SpeakButton(text: '   ')));
    final btn = tester.widget<IconButton>(find.byType(IconButton));
    expect(btn.onPressed, isNull);
  });

  testWidgets('正在朗读该项 → 图标显主色（激活态）', (tester) async {
    final fake = FakeTtsController(initialSpeakingKey: 'hello');
    await tester.pumpWidget(_wrap(fake, const SpeakButton(text: 'hello')));
    await tester.pump();

    final context = tester.element(find.byType(SpeakButton));
    final primary = Theme.of(context).colorScheme.primary;
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, primary);
  });

  testWidgets('非当前朗读项 → 图标非主色', (tester) async {
    final fake = FakeTtsController(initialSpeakingKey: 'other');
    await tester.pumpWidget(_wrap(fake, const SpeakButton(text: 'hello')));
    await tester.pump();

    final context = tester.element(find.byType(SpeakButton));
    final primary = Theme.of(context).colorScheme.primary;
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, isNot(primary));
  });
}
