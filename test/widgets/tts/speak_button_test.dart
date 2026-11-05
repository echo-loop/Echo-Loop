import 'package:echo_loop/providers/pronunciation/pronunciation_providers.dart';
import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
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

/// 记录统一入口收到的朗读请求，并可注入正在播放的 key。
class FakeTextPlayback extends TextPlaybackController {
  FakeTextPlayback({this.initialPlayingKey});

  final String? initialPlayingKey;
  final List<({String text, String key})> calls = [];

  @override
  TextPlaybackState build() => TextPlaybackState(playingKey: initialPlayingKey);

  @override
  Future<AudioPlaybackResult> speakWithResult(
    String text, {
    String? key,
    bool promptIfModelMissing = true,
  }) async {
    calls.add((text: text, key: key ?? text));
    return AudioPlaybackResult.completed;
  }
}

Widget _wrap(
  FakeTtsController fake,
  Widget child, {
  FakeTextPlayback? textPlayback,
}) {
  return ProviderScope(
    overrides: dedupeOverrides([
      ttsControllerProvider.overrideWith(() => fake),
      if (textPlayback != null)
        textPlaybackProvider.overrideWith(() => textPlayback),
    ]),
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('点击 → 经统一朗读入口发音（传入 key）', (tester) async {
    final fake = FakeTtsController();
    final textPlayback = FakeTextPlayback();
    await tester.pumpWidget(
      _wrap(
        fake,
        const SpeakButton(text: 'hello', speakKey: 'k'),
        textPlayback: textPlayback,
      ),
    );
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(textPlayback.calls, [(text: 'hello', key: 'k')]);
  });

  testWidgets('未传 key → 默认用文本作 key', (tester) async {
    final fake = FakeTtsController();
    final textPlayback = FakeTextPlayback();
    await tester.pumpWidget(
      _wrap(fake, const SpeakButton(text: 'world'), textPlayback: textPlayback),
    );
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(textPlayback.calls.single.key, 'world');
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

  testWidgets('统一入口正在播放该项（如 CDN 音频）→ 图标显主色', (tester) async {
    final fake = FakeTtsController();
    final textPlayback = FakeTextPlayback(initialPlayingKey: 'hello');
    await tester.pumpWidget(
      _wrap(
        fake,
        const SpeakButton(text: 'hello'),
        textPlayback: textPlayback,
      ),
    );
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
