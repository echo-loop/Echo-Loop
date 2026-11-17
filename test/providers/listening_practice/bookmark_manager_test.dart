import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/listening_practice/bookmark_manager.dart';

void main() {
  group('BookmarkManager', () {
    Sentence createSentence(int index, String text) {
      return Sentence(
        index: index,
        text: text,
        startTime: Duration(seconds: index * 5),
        endTime: Duration(seconds: (index + 1) * 5),
      );
    }

    group('updateSentenceBookmarkStatus', () {
      test('正确设置 isBookmarked 标志', () {
        final sentences = [
          createSentence(0, 'A'),
          createSentence(1, 'B'),
          createSentence(2, 'C'),
        ];
        BookmarkManager.updateSentenceBookmarkStatus(sentences, {0, 2});

        expect(sentences[0].isBookmarked, isTrue);
        expect(sentences[1].isBookmarked, isFalse);
        expect(sentences[2].isBookmarked, isTrue);
      });

      test('不在 set 中的句子标记为 false', () {
        final sentences = [
          createSentence(0, 'A')..isBookmarked = true,
          createSentence(1, 'B')..isBookmarked = true,
        ];
        // 空集合 → 全部设为 false
        BookmarkManager.updateSentenceBookmarkStatus(sentences, {});

        expect(sentences[0].isBookmarked, isFalse);
        expect(sentences[1].isBookmarked, isFalse);
      });
    });

    group('createSentenceBookmarkSnapshot', () {
      test('创建收藏状态副本且不修改共享字幕对象', () {
        final source = [
          createSentence(0, 'A'),
          createSentence(1, 'B')..isBookmarked = true,
          createSentence(2, 'C'),
        ];

        final snapshot = BookmarkManager.createSentenceBookmarkSnapshot(
          source,
          {0, 2},
        );

        expect(snapshot.map((sentence) => sentence.isBookmarked), [
          true,
          false,
          true,
        ]);
        expect(snapshot.map((sentence) => sentence.index), [0, 1, 2]);
        expect(identical(snapshot[0], source[0]), isFalse);
        expect(source.map((sentence) => sentence.isBookmarked), [
          false,
          true,
          false,
        ]);
      });

      test('保留段落结构并为每句创建独立副本', () {
        final source = [
          [createSentence(0, 'A'), createSentence(1, 'B')],
          [createSentence(2, 'C')],
        ];

        final snapshot = BookmarkManager.createParagraphBookmarkSnapshot(
          source,
          {1, 2},
        );

        expect(snapshot.map((paragraph) => paragraph.length), [2, 1]);
        expect(
          snapshot
              .expand((paragraph) => paragraph)
              .map((sentence) => sentence.isBookmarked),
          [false, true, true],
        );
        expect(identical(snapshot[0][0], source[0][0]), isFalse);
      });
    });

    group('toggleBookmark', () {
      test('未收藏时为添加，无替代焦点', () {
        final sentences = [createSentence(0, 'A'), createSentence(1, 'B')];
        final (isRemoving, nextIndex) = BookmarkManager.toggleBookmark(
          0,
          sentences,
          {},
          true,
        );

        expect(isRemoving, isFalse);
        expect(nextIndex, isNull);
      });

      test('已收藏时为取消', () {
        final sentences = [createSentence(0, 'A'), createSentence(1, 'B')];
        final (isRemoving, _) = BookmarkManager.toggleBookmark(0, sentences, {
          0,
          1,
        }, false);

        expect(isRemoving, isTrue);
      });

      test('同文本的其他收藏不受影响：替代焦点就是后一条同文本收藏', () {
        final sentences = [
          createSentence(0, 'Same'),
          createSentence(1, 'Same'),
          createSentence(2, 'Different'),
        ];
        final (isRemoving, nextIndex) = BookmarkManager.toggleBookmark(
          0,
          sentences,
          {0, 1, 2},
          true,
        );

        expect(isRemoving, isTrue);
        expect(nextIndex, 1, reason: '只取消当前这一句，同文本的第 1 句仍是收藏');
      });

      test('非书签模式 nextIndex 为 null', () {
        final sentences = [createSentence(0, 'A'), createSentence(1, 'B')];
        final (_, nextIndex) = BookmarkManager.toggleBookmark(0, sentences, {
          0,
          1,
        }, false);

        expect(nextIndex, isNull);
      });

      test('书签模式移除最后一个书签时 nextIndex 为 null', () {
        final sentences = [createSentence(0, 'A')];
        final (_, nextIndex) = BookmarkManager.toggleBookmark(0, sentences, {
          0,
        }, true);

        expect(nextIndex, isNull);
      });

      test('书签模式移除末尾书签但前面仍有收藏时回退到前一个', () {
        final sentences = [
          createSentence(0, 'A'),
          createSentence(1, 'B'),
          createSentence(2, 'C'),
          createSentence(3, 'D'),
        ];
        final (_, nextIndex) = BookmarkManager.toggleBookmark(3, sentences, {
          0,
          1,
          3,
        }, true);

        expect(nextIndex, 1);
      });
    });
  });
}
