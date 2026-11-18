import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_editor_controller.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'subtitle_editor_test_support.dart';

/// 回归：句子自然播放结束后，playbackPosition 必须停在句尾，绝不回跳到句首。
///
/// 根因（状态机层）：播放完成时 controller 的 finally 若「先停底层播放器再冻结
/// 状态」，停止过程中晚到的句首位置事件会在 isPlaying 仍为 true 时被
/// `_handlePosition` 采纳，把播放头拉回句首。
/// 修复：finally 中先冻结 isPlaying=false 再停播放器；并在 _handlePosition 丢弃
/// 大幅后退的残留事件。
void main() {
  test('单句播放自然结束后 playbackPosition 停在句尾、不回跳句首', () async {
    final sentences = [
      Sentence(
        index: 0,
        text: 'a',
        startTime: const Duration(seconds: 3),
        endTime: const Duration(seconds: 11),
      ),
      Sentence(
        index: 1,
        text: 'b',
        startTime: const Duration(seconds: 11),
        endTime: const Duration(seconds: 18),
      ),
    ];
    await useTemporaryAppDataDirectory();
    final engine = _StaleStopPositionBackend(const Duration(seconds: 60));
    final audioItem = createTestAudioItem();
    final dao = TestAudioItemDao()
      ..transcriptSrtStore[audioItem.id] = srtOf(sentences);
    final container = ProviderContainer(
      overrides: dedupeOverrides([
        ...subtitleEditorPlaybackOverrides(engine),
        audioItemDaoProvider.overrideWithValue(dao),
      ]),
    );
    addTearDown(container.dispose);

    // 订阅以保活 autoDispose provider，并记录每次状态变更（捕获中间帧）。
    final positions = <Duration>[];
    final sub = container.listen(
      subtitleEditorControllerProvider(audioItem),
      (_, next) => positions.add(next.playbackPosition),
    );
    addTearDown(sub.close);

    final ctrl = container.read(
      subtitleEditorControllerProvider(audioItem).notifier,
    );
    await ctrl.load();

    final playFuture = ctrl.playSentence(0);
    await Future<void>.delayed(const Duration(milliseconds: 1));

    // 推进播放位置到接近句尾。
    for (var s = 3; s <= 11; s++) {
      engine.emitPosition(Duration(seconds: s));
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    // 自然结束：区间播放返回 → finally 跑完（其间停止会吐出句首残留事件）。
    engine.completePlayback();
    await playFuture;
    await Future<void>.delayed(const Duration(milliseconds: 1));

    final state = container.read(subtitleEditorControllerProvider(audioItem));
    expect(state.isPlaying, isFalse);
    // 必须停在句尾 11s，绝不回跳到句首 3s。
    expect(state.playbackPosition, const Duration(seconds: 11));

    // 关键：任何中间帧都不得在到达 11s 后回退到句首附近（视图会据此渲染跳变）。
    final reachedEnd = positions.indexWhere(
      (p) => p >= const Duration(seconds: 11),
    );
    expect(reachedEnd, greaterThanOrEqualTo(0), reason: '应曾推进到句尾');
    for (final p in positions.sublist(reachedEnd)) {
      expect(
        p,
        greaterThanOrEqualTo(const Duration(seconds: 10)),
        reason: '到达句尾后不得回跳（残留 stop 事件把播放头拉回句首）',
      );
    }
  });
}

/// 停止时吐出一条句首残留位置事件：播放器停止 / 换区间前的旧位置事件可能晚到。
class _StaleStopPositionBackend extends RangeRecordingBackend {
  _StaleStopPositionBackend(super.duration);

  @override
  Future<void> pause() async {
    final rangeStart = ranges.isEmpty ? null : ranges.last.$1;
    await super.pause();
    if (rangeStart != null) emitPosition(rangeStart);
  }
}
