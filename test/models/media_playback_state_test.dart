import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/listening_practice_state.dart';
import 'package:echo_loop/models/media_playback_state.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/sentence_focus_reason.dart';

void main() {
  group('MediaPlaybackState', () {
    List<Sentence> createSentences(int count) {
      return List.generate(
        count,
        (i) => Sentence(
          index: i,
          text: '句子 $i',
          startTime: Duration(seconds: i * 5),
          endTime: Duration(seconds: (i + 1) * 5),
        ),
      );
    }

    group('isFirstSentence / isLastSentence', () {
      test('全文模式：第一句', () {
        final state = MediaPlaybackState(
          sentences: createSentences(3),
          currentFullIndex: 0,
        );
        expect(state.isFirstSentence, isTrue);
        expect(state.isLastSentence, isFalse);
      });

      test('全文模式：中间句', () {
        final state = MediaPlaybackState(
          sentences: createSentences(3),
          currentFullIndex: 1,
        );
        expect(state.isFirstSentence, isFalse);
        expect(state.isLastSentence, isFalse);
      });

      test('全文模式：最后一句', () {
        final state = MediaPlaybackState(
          sentences: createSentences(3),
          currentFullIndex: 2,
        );
        expect(state.isFirstSentence, isFalse);
        expect(state.isLastSentence, isTrue);
      });

      test('收藏模式：按收藏句子位置判定首/末句', () {
        final sentences = createSentences(5);
        final first = MediaPlaybackState(
          sentences: sentences,
          bookmarkedIndices: const {1, 3},
          currentBookmarkIndex: 1,
          playlistMode: PlaylistMode.bookmarks,
        );
        expect(first.isFirstSentence, isTrue);
        expect(first.isLastSentence, isFalse);

        final last = first.copyWith(currentBookmarkIndex: 3);
        expect(last.isFirstSentence, isFalse);
        expect(last.isLastSentence, isTrue);
      });

      test('无句子时首末句均为 true', () {
        const state = MediaPlaybackState();
        expect(state.isFirstSentence, isTrue);
        expect(state.isLastSentence, isTrue);
      });

      test('收藏模式无收藏句时首末句均为 true', () {
        final state = MediaPlaybackState(
          sentences: createSentences(3),
          playlistMode: PlaylistMode.bookmarks,
        );
        expect(state.isFirstSentence, isTrue);
        expect(state.isLastSentence, isTrue);
      });
    });

    test('句子聚焦请求记录原因并递增版本，普通状态更新不递增', () {
      const initial = MediaPlaybackState();
      final playback = initial.copyWith(
        currentFullIndex: 1,
        requestSentenceFocus: true,
        sentenceFocusReason: SentenceFocusReason.playback,
      );
      final navigation = playback.copyWith(
        requestSentenceFocus: true,
        sentenceFocusReason: SentenceFocusReason.navigation,
      );
      final progress = navigation.copyWith(
        position: const Duration(seconds: 2),
      );

      expect(playback.sentenceFocusRevision, 1);
      expect(playback.sentenceFocusReason, SentenceFocusReason.playback);
      expect(navigation.sentenceFocusRevision, 2);
      expect(navigation.sentenceFocusReason, SentenceFocusReason.navigation);
      expect(progress.sentenceFocusRevision, navigation.sentenceFocusRevision);
      expect(progress.sentenceFocusReason, navigation.sentenceFocusReason);
    });
  });
}
