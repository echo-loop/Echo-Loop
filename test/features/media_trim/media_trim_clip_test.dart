import 'package:echo_loop/features/media_trim/media_trim_clip.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/word_timestamp.dart';
import 'package:flutter_test/flutter_test.dart';

Duration ms(int value) => Duration(milliseconds: value);

Sentence sentence(int index, int startMs, int endMs) => Sentence(
  index: index,
  text: 'Sentence $index',
  startTime: ms(startMs),
  endTime: ms(endMs),
);

MediaTrimClip clip(int startMs, int endMs) =>
    MediaTrimClip(id: 1, start: ms(startMs), end: ms(endMs));

MediaTrimClip clipForSpans(
  int id,
  MediaTrimBoundaries boundaries,
  int first,
  int last,
) {
  final (start, end) = boundaries.rangeForSpans(first, last);
  return MediaTrimClip(id: id, start: start, end: end);
}

/// 从一系列播放头位置（每 500ms 一个）新建片段，校验结果不与已有片段重叠、
/// 位于媒体内且不为空；找不到空白时必须返回 null。
void _expectGapRangesValid(
  MediaTrimBoundaries boundaries,
  List<MediaTrimClip> clips,
) {
  for (var at = Duration.zero; at <= boundaries.total; at += ms(500)) {
    final range = boundaries.rangeInGap(clips, at);
    if (range == null) continue;
    final (start, end) = range;
    expect(start >= Duration.zero && end <= boundaries.total, isTrue);
    expect(end > start, isTrue, reason: 'anchor=$at');
    for (final existing in clips) {
      expect(
        end <= existing.start || start >= existing.end,
        isTrue,
        reason:
            'anchor=$at 新片段 $start-$end 与 ${existing.start}-${existing.end} 重叠',
      );
    }
  }
}

void main() {
  group('句子单元与边界', () {
    test('重叠字幕合并为不可拆分单元', () {
      final boundaries = MediaTrimBoundaries(
        total: ms(10000),
        sentences: [
          sentence(0, 1000, 4000),
          sentence(1, 3000, 6000),
          sentence(2, 7000, 8000),
        ],
      );
      expect(boundaries.spans, hasLength(2));
      expect(boundaries.spans.first.start, ms(1000));
      expect(boundaries.spans.first.end, ms(6000));
      expect(boundaries.spanOfSentence(1), 0);
      expect(boundaries.spanOfSentence(2), 1);
    });

    test('边界向句间空隙外扩留余量，但不越过空隙中点和媒体首尾', () {
      final boundaries = MediaTrimBoundaries(
        total: ms(5000),
        sentences: [
          sentence(0, 100, 1000),
          sentence(1, 1200, 2000),
          sentence(2, 3000, 4900),
        ],
      );
      // 首句前只有 100ms，钳到 0。
      expect(boundaries.startAt(0), Duration.zero);
      // 与前句只隔 200ms：余量 300ms 超过中点，取中点 1100ms。
      expect(boundaries.startAt(1), ms(1100));
      expect(boundaries.endAt(0), ms(1100));
      // 空隙 1000ms 足够，正常外扩 300ms。
      expect(boundaries.endAt(1), ms(2300));
      expect(boundaries.startAt(2), ms(2700));
      // 末句后只剩 100ms，钳到总时长。
      expect(boundaries.endAt(2), ms(5000));
    });

    test('拖动吸附到最近的合法边界，无字幕时只取整到毫秒', () {
      final withSentences = MediaTrimBoundaries(
        total: ms(10000),
        sentences: [sentence(0, 1000, 2000), sentence(1, 5000, 6000)],
      );
      expect(withSentences.snap(MediaTrimEdge.start, ms(4000)), ms(4700));
      expect(withSentences.snap(MediaTrimEdge.end, ms(3000)), ms(2300));

      final free = MediaTrimBoundaries(total: ms(10000), sentences: const []);
      expect(
        free.snap(MediaTrimEdge.start, const Duration(microseconds: 1234567)),
        ms(1235),
      );
      expect(free.snap(MediaTrimEdge.end, ms(12000)), ms(10000));
    });

    test('一端不能越过另一端：停在片段内首 / 末一句或最短长度，不整段跳走', () {
      final boundaries = MediaTrimBoundaries(
        total: ms(10000),
        sentences: [
          sentence(0, 1000, 2000),
          sentence(1, 4000, 5000),
          sentence(2, 7000, 8000),
        ],
      );
      final twoSpans = MediaTrimClip(
        id: 1,
        start: boundaries.startAt(0),
        end: boundaries.endAt(1),
      );
      expect(
        boundaries.moveEdge(twoSpans, MediaTrimEdge.start, ms(9000)),
        boundaries.rangeForSpans(1, 1),
      );
      expect(
        boundaries.moveEdge(twoSpans, MediaTrimEdge.end, ms(0)),
        boundaries.rangeForSpans(0, 0),
      );

      final free = MediaTrimBoundaries(total: ms(10000), sentences: const []);
      expect(free.moveEdge(clip(1000, 3000), MediaTrimEdge.start, ms(5000)), (
        ms(2700),
        ms(3000),
      ));
      expect(free.moveEdge(clip(8000, 9000), MediaTrimEdge.end, ms(500)), (
        ms(8000),
        ms(8300),
      ));
    });

    test('微调按整句或 100ms 步进，并钳在范围内', () {
      final boundaries = MediaTrimBoundaries(
        total: ms(10000),
        sentences: [sentence(0, 1000, 2000), sentence(1, 4000, 5000)],
      );
      final current = MediaTrimClip(
        id: 1,
        start: boundaries.startAt(0),
        end: boundaries.endAt(0),
      );
      expect(
        boundaries.step(current, MediaTrimEdge.end, 1),
        boundaries.endAt(1),
      );
      expect(
        boundaries.step(current, MediaTrimEdge.start, -1),
        boundaries.startAt(0),
      );
      final free = MediaTrimBoundaries(total: ms(10000), sentences: const []);
      expect(free.step(clip(0, 2000), MediaTrimEdge.start, -1), Duration.zero);
      expect(free.step(clip(0, 2000), MediaTrimEdge.end, 1), ms(2100));
    });

    test('新片段：有字幕取播放头所在或之后的句子，无字幕取 2 分钟并贴近末尾', () {
      final boundaries = MediaTrimBoundaries(
        total: ms(10000),
        sentences: [sentence(0, 1000, 2000), sentence(1, 4000, 5000)],
      );
      expect(
        boundaries.defaultRangeAt(ms(3000)),
        boundaries.rangeForSpans(1, 1),
      );
      expect(
        boundaries.defaultRangeAt(ms(9000)),
        boundaries.rangeForSpans(1, 1),
      );

      final free = MediaTrimBoundaries(total: ms(60000), sentences: const []);
      expect(free.defaultRangeAt(ms(10000)), (ms(10000), ms(60000)));
      expect(free.defaultRangeAt(ms(59900)), (ms(0), ms(60000)));
    });

    group('空白处新建片段', () {
      Duration s(int seconds) => Duration(seconds: seconds);
      MediaTrimClip range(int id, Duration start, Duration end) =>
          MediaTrimClip(id: id, start: start, end: end);
      final free = MediaTrimBoundaries(total: s(600), sentences: const []);

      test('无字幕：从播放头起取 2 分钟；播放头在片段内时从片段末尾起', () {
        expect(free.rangeInGap(const [], s(30)), (s(30), s(150)));
        expect(free.rangeInGap([range(1, s(0), s(60))], s(10)), (
          s(60),
          s(180),
        ));
      });

      test('无字幕：空白不足 2 分钟用整段空白；播放头后剩余太短时贴空白末尾', () {
        final clips = [range(1, s(0), s(60)), range(2, s(100), s(600))];
        expect(free.rangeInGap(clips, s(0)), (s(60), s(100)));
        expect(free.rangeInGap(clips, s(95)), (s(60), s(100)));
      });

      test('无字幕：后面没有空白时回到开头；空白都不足 10 秒时返回 null', () {
        expect(free.rangeInGap([range(1, s(60), s(600))], s(300)), (
          s(0),
          s(60),
        ));
        expect(free.rangeInGap([range(1, s(0), s(595))], s(0)), isNull);
        final short = MediaTrimBoundaries(total: s(6), sentences: const []);
        expect(short.rangeInGap(const [], s(0)), (
          s(0),
          s(6),
        ), reason: '媒体不足 10 秒用全长');
      });

      test('有字幕：按整句累积到不超过 2 分钟，连续新建依次向后', () {
        final boundaries = MediaTrimBoundaries(
          total: s(300),
          sentences: [
            for (var i = 0; i < 30; i++)
              sentence(i, i * 10000 + 1000, i * 10000 + 8000),
          ],
        );
        final first = boundaries.rangeInGap(const [], s(0))!;
        expect(first, boundaries.rangeForSpans(0, 11));
        final next = boundaries.rangeInGap([
          range(1, first.$1, first.$2),
        ], first.$1);
        expect(next, boundaries.rangeForSpans(12, 23));
      });

      test('有字幕：播放头在片段内且片段之后没有空白时，回到前面的空白，不与片段重叠', () {
        final boundaries = MediaTrimBoundaries(
          total: s(100),
          sentences: [
            for (var i = 0; i < 10; i++)
              sentence(i, i * 10000 + 1000, i * 10000 + 8000),
          ],
        );
        final occupied = boundaries.rangeForSpans(3, 9);
        final clips = [range(1, occupied.$1, occupied.$2)];
        expect(
          boundaries.rangeInGap(clips, occupied.$1 + s(5)),
          boundaries.rangeForSpans(0, 2),
        );
      });

      test('任意播放头位置新建的片段都不与现有片段重叠，且落在媒体内', () {
        final sentenceBoundaries = MediaTrimBoundaries(
          total: s(100),
          sentences: [
            for (var i = 0; i < 10; i++)
              sentence(i, i * 10000 + 1000, i * 10000 + 8000),
          ],
        );
        final sentenceLayouts = [
          const <MediaTrimClip>[],
          [clipForSpans(1, sentenceBoundaries, 3, 9)],
          [
            clipForSpans(1, sentenceBoundaries, 0, 2),
            clipForSpans(2, sentenceBoundaries, 6, 7),
          ],
          [clipForSpans(1, sentenceBoundaries, 0, 9)],
        ];
        final freeLayouts = [
          const <MediaTrimClip>[],
          [range(1, s(60), s(600))],
          [range(1, s(0), s(60)), range(2, s(100), s(600))],
          [range(1, s(0), s(595))],
        ];
        for (final layout in sentenceLayouts) {
          _expectGapRangesValid(sentenceBoundaries, layout);
        }
        for (final layout in freeLayouts) {
          _expectGapRangesValid(free, layout);
        }
      });
    });

    test('校验拒绝句内切分、过短和越界', () {
      final boundaries = MediaTrimBoundaries(
        total: ms(10000),
        sentences: [sentence(0, 1000, 4000)],
      );
      expect(
        boundaries.validate(clip(2000, 5000)),
        MediaTrimFailure.clipSplitsSentence,
      );
      expect(
        boundaries.validate(clip(5000, 5100)),
        MediaTrimFailure.clipTooShort,
      );
      expect(
        boundaries.validate(clip(5000, 11000)),
        MediaTrimFailure.clipOutOfRange,
      );
      expect(boundaries.validate(clip(4000, 9000)), isNull);
    });
  });

  group('自动分段', () {
    test('无字幕时等分，末段过短并入前一段', () {
      final boundaries = MediaTrimBoundaries(
        total: ms(310000),
        sentences: const [],
      );
      final ranges = boundaries.autoSplit(const Duration(minutes: 1));
      // 310s / 60s：末段 10s 不足三成，合并后等分为 5 段。
      expect(ranges, hasLength(5));
      expect(ranges.first.$1, Duration.zero);
      expect(ranges.last.$2, ms(310000));
      for (var i = 1; i < ranges.length; i++) {
        expect(ranges[i].$1, ranges[i - 1].$2);
      }
    });

    test('有字幕时按整句累积，切点都在句间，末段过短合并', () {
      final sentences = [
        for (var i = 0; i < 10; i++) sentence(i, i * 10000, i * 10000 + 8000),
      ];
      final boundaries = MediaTrimBoundaries(
        total: ms(100000),
        sentences: sentences,
      );
      final ranges = boundaries.autoSplit(const Duration(seconds: 30));
      for (final (start, end) in ranges) {
        expect(
          boundaries.validate(MediaTrimClip(id: 1, start: start, end: end)),
          isNull,
        );
      }
      // 除了吸收了零碎末段的最后一段，其余都不超过目标时长。
      for (final (start, end) in ranges.take(ranges.length - 1)) {
        expect(end - start <= const Duration(seconds: 30), isTrue);
      }
      expect(ranges.first.$1, boundaries.startAt(0));
      expect(ranges.last.$2, boundaries.endAt(9));
      // 每段 3 句，共 4 段，末段只有 1 句（< 30% × 30s），并入第 3 段。
      expect(ranges, hasLength(3));
    });
  });

  test('字幕与词级时间戳只做整体平移，不改原数据', () {
    final sentences = [sentence(0, 1000, 2000), sentence(1, 3000, 5000)];
    final trimmed = clip(2700, 5300);
    final words = [
      WordTimestamp(word: 'Hello', startTime: ms(3100), endTime: ms(3400)),
      WordTimestamp(word: 'Gone', startTime: ms(1100), endTime: ms(1400)),
    ];
    expect(trimmed.sentencesWithin(sentences).single.index, 1);
    expect(
      trimmed.shiftedSubtitle(sentences),
      contains('00:00:00,300 --> 00:00:02,300'),
    );
    expect(trimmed.shiftedWords(words).single.startTime, ms(400));
    expect(words.first.startTime, ms(3100));
    expect(sentences.last.startTime, ms(3000));
  });
}
