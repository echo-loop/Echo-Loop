import 'package:echo_loop/features/subtitle_editor/subtitle_editor_controller.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_simple_editor_screen.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';
import 'subtitle_editor_test_support.dart';

void main() {
  late AudioItem audioItem;
  late TestAudioItemDao audioItemDao;
  late ProviderContainer container;

  setUp(() async {
    await useTemporaryAppDataDirectory();
    audioItem = createTestAudioItem(totalDuration: 6);
    audioItemDao = TestAudioItemDao();
  });

  Future<void> pumpEditor(WidgetTester tester, List<Sentence> sentences) async {
    audioItemDao.transcriptSrtStore[audioItem.id] = srtOf(sentences);
    await tester.pumpWidget(
      createTestApp(
        Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context, listen: false);
            return SubtitleSimpleEditorScreen(audioItem: audioItem);
          },
        ),
        overrides: dedupeOverrides([
          ...subtitleEditorPlaybackOverrides(
            RangeRecordingBackend(
              const Duration(seconds: 6),
              completesImmediately: true,
            ),
          ),
          audioItemDaoProvider.overrideWithValue(audioItemDao),
        ]),
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

  testWidgets('后插：词旁出现空输入框，回车后插入；标题栏撤销 / 重做', (tester) async {
    await pumpEditor(tester, singleSentence());

    await tester.tap(find.text('two'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('subtitle-word-insert-after-1')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('subtitle-word-insert-field')),
      'and',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(state().sentences[0].text, 'one two and three');

    await tester.tap(find.byKey(const ValueKey('subtitle-editor-undo')));
    await tester.pump();
    expect(state().sentences[0].text, 'one two three');
    expect(state().isDirty, isFalse);

    await tester.tap(find.byKey(const ValueKey('subtitle-editor-redo')));
    await tester.pump();
    expect(state().sentences[0].text, 'one two and three');
  });

  testWidgets('插词输入框按 Esc 取消，不改字幕', (tester) async {
    await pumpEditor(tester, singleSentence());

    await tester.tap(find.text('two'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('subtitle-word-insert-before-1')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('subtitle-word-insert-field')),
      'big',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('subtitle-word-insert-field')),
      findsNothing,
    );
    expect(state().sentences[0].text, 'one two three');
    expect(state().canUndo, isFalse);
  });

  testWidgets('删除按钮删掉该词', (tester) async {
    await pumpEditor(tester, singleSentence());

    await tester.tap(find.text('two'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('subtitle-word-delete-button-1')),
    );
    await tester.pump();

    expect(state().sentences[0].text, 'one three');
  });

  testWidgets('「编辑文字」整句改文字，回车保存', (tester) async {
    await pumpEditor(tester, singleSentence());

    await tester.tap(
      find.byKey(const ValueKey('subtitle-sentence-edit-text-0')),
    );
    await tester.pump();
    final field = find.byKey(const ValueKey('subtitle-sentence-text-field-0'));
    expect(field, findsOne);
    await tester.enterText(
      find.descendant(of: field, matching: find.byType(TextField)),
      'one two three four',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(state().sentences[0].text, 'one two three four');
    expect(field, findsNothing);
  });

  testWidgets('桌面快捷键：⌘Z 撤销、⇧⌘Z 重做；输入文字时不响应', (tester) async {
    await pumpEditor(tester, singleSentence());

    await tester.tap(find.text('two'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('subtitle-word-delete-button-1')),
    );
    await tester.pump();
    expect(state().sentences[0].text, 'one three');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(state().sentences[0].text, 'one two three');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(state().sentences[0].text, 'one three');

    // 打开整句输入框后，⌘Z 交给输入框，不撤销字幕。
    await tester.tap(
      find.byKey(const ValueKey('subtitle-sentence-edit-text-0')),
    );
    await tester.pump();
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>(),
      isNotNull,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(state().sentences[0].text, 'one three');
  });

  testWidgets('输入框里按空格交给输入框，不被页面快捷键拦截（回归：新句无法输入空格）', (tester) async {
    await pumpEditor(tester, singleSentence());

    Future<void> expectSpaceReachesField(String where) async {
      await tester.pump();
      final typing = FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>();
      expect(typing, isNotNull, reason: '$where：输入框应已获得焦点');
      // 页面若处理了空格（返回 true），macOS 不会再把字符交给输入框。
      expect(
        await tester.sendKeyEvent(LogicalKeyboardKey.space),
        isFalse,
        reason: '$where：空格应交给输入框',
      );
      expect(state().isPlaying, isFalse, reason: '$where：不应触发播放');
    }

    // 整句改文字。
    await tester.tap(
      find.byKey(const ValueKey('subtitle-sentence-edit-text-0')),
    );
    await expectSpaceReachesField('整句输入框');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    // 插词。
    await tester.tap(find.text('two'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('subtitle-word-insert-after-1')),
    );
    await expectSpaceReachesField('插词输入框');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    // 字幕编辑不需要空格播放：不在输入时空格也不被页面处理、不触发播放。
    await tester.pump();
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.space), isFalse);
    expect(state().isPlaying, isFalse);
  });
}
