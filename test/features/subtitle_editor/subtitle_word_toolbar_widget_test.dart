import 'package:echo_loop/features/subtitle_editor/subtitle_editor_controller.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_simple_editor_screen.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

/// 字幕编辑器返回固定句子 / 时长、不触底层播放器的测试音频引擎。
class _FakeEditorAudioEngine extends FakeAudioEngine {
  _FakeEditorAudioEngine(this._sentences, this._duration);

  final List<Sentence> _sentences;
  final Duration _duration;

  @override
  Future<Duration?> loadAudio(
    AudioItem item,
    double speed, {
    String? subtitle,
  }) async => _duration;

  @override
  Future<List<Sentence>> loadTranscript(AudioItem audioItem) async =>
      _sentences;

  @override
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId, {
    void Function()? onClipReady,
  }) async {}

  @override
  Future<void> playClipOnce(Sentence sentence, int sessionId) async {}

  @override
  Future<void> stopPlayback() async {}
}

void main() {
  late AudioItem audioItem;
  late TestAudioItemDao audioItemDao;
  late ProviderContainer container;

  setUp(() {
    audioItem = createTestAudioItem(totalDuration: 6);
    audioItemDao = TestAudioItemDao();
  });

  Future<void> pumpEditor(WidgetTester tester, List<Sentence> sentences) async {
    final engine = _FakeEditorAudioEngine(
      sentences,
      const Duration(seconds: 6),
    );
    await tester.pumpWidget(
      createTestApp(
        Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context, listen: false);
            return SubtitleSimpleEditorScreen(audioItem: audioItem);
          },
        ),
        overrides: [
          audioEngineProvider.overrideWith(() => engine),
          audioItemDaoProvider.overrideWithValue(audioItemDao),
        ],
      ),
    );
    // load() 在 postFrame 触发，连续 pump 让其完成（避免 pumpAndSettle 卡在引导计时器）。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  SubtitleEditorController controller() =>
      container.read(subtitleEditorControllerProvider(audioItem).notifier);

  SubtitleEditorState state() =>
      container.read(subtitleEditorControllerProvider(audioItem));

  List<Sentence> singleSentence() => [
    Sentence(
      index: 0,
      text: 'one two three',
      startTime: Duration.zero,
      endTime: const Duration(seconds: 3),
    ),
  ];

  testWidgets('点词弹出工具栏：含铅笔与剪刀，铅笔进入就地编辑', (tester) async {
    await pumpEditor(tester, singleSentence());

    await tester.tap(find.text('two'));
    await tester.pump();

    expect(find.byKey(const ValueKey('subtitle-word-edit-button-1')), findsOne);
    expect(
      find.byKey(const ValueKey('subtitle-word-split-button-1')),
      findsOne,
    );

    await tester.tap(find.byKey(const ValueKey('subtitle-word-edit-button-1')));
    await tester.pump();
    expect(find.byKey(const ValueKey('subtitle-word-edit-1')), findsOne);
  });

  testWidgets('首词无剪刀按钮', (tester) async {
    await pumpEditor(tester, singleSentence());

    await tester.tap(find.text('one'));
    await tester.pump();

    expect(find.byKey(const ValueKey('subtitle-word-edit-button-0')), findsOne);
    expect(
      find.byKey(const ValueKey('subtitle-word-split-button-0')),
      findsNothing,
    );
  });

  testWidgets('就地编辑改名并回车提交，label 更新', (tester) async {
    await pumpEditor(tester, singleSentence());

    await tester.tap(find.text('two'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('subtitle-word-edit-button-1')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('subtitle-word-edit-1')),
      'TWO',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final words = controller().wordsOfSelectedSentence;
    expect(words.map((w) => w.word).toList(), ['one', 'TWO', 'three']);
    expect(find.text('TWO'), findsOne);
  });

  testWidgets('剪刀从该词分句，句子一分为二', (tester) async {
    await pumpEditor(tester, singleSentence());

    await tester.tap(find.text('two'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('subtitle-word-split-button-1')),
    );
    await tester.pump();

    expect(state().sentences.length, 2);
    expect(state().sentences[0].text, 'one');
    expect(state().sentences[1].text, 'two three');
  });
}
