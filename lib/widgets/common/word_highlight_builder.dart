import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/word_highlight_binding.dart';
import '../../providers/settings_provider.dart';
import '../../providers/word_highlight_provider.dart';
import '../../services/app_logger.dart';
import '../../utils/word_highlight.dart';

/// 为共享句子文本渲染提供当前播放词序号。
class WordHighlightBuilder extends ConsumerStatefulWidget {
  /// 要显示的原始句子文本。
  final String text;

  /// 当前句子对应的音频与播放时间轴；null 时保持普通文本渲染。
  final WordHighlightBinding? binding;

  /// 使用当前词序号构建文本。null 表示当前没有可高亮的词。
  final Widget Function(BuildContext context, int? activeWordIndex) builder;

  const WordHighlightBuilder({
    super.key,
    required this.text,
    required this.builder,
    this.binding,
  });

  @override
  ConsumerState<WordHighlightBuilder> createState() =>
      _WordHighlightBuilderState();
}

class _WordHighlightBuilderState extends ConsumerState<WordHighlightBuilder> {
  Object? _diagnosticKey;
  int? _lastDiagnosticWordIndex;
  bool _hasDiagnosticWordIndex = false;

  @override
  Widget build(BuildContext context) {
    final currentBinding = widget.binding;
    final enabled = ref.watch(
      appSettingsProvider.select((settings) => settings.wordHighlightEnabled),
    );
    if (!enabled || currentBinding == null) {
      return widget.builder(context, null);
    }

    final timestamps = ref
        .watch(wordTimestampsProvider(currentBinding.source.audioItemId))
        .value;
    if (timestamps == null || timestamps.isEmpty) {
      return widget.builder(context, null);
    }

    final start = Duration(milliseconds: currentBinding.sentenceStartMs);
    final end = Duration(milliseconds: currentBinding.sentenceEndMs);
    final source = currentBinding.source;
    final sourceKey = (
      source.audioItemId,
      currentBinding.sentenceStartMs,
      currentBinding.sentenceEndMs,
    );
    return StreamBuilder<WordHighlightPlaybackStatus>(
      key: ValueKey((sourceKey, source.playbackStatusStream)),
      stream: source.playbackStatusStream,
      initialData: source.playbackStatus,
      builder: (context, snapshot) {
        final playbackStatus = snapshot.data;
        return StreamBuilder<Duration>(
          key: ValueKey((sourceKey, source.positionStream)),
          stream: source.positionStream,
          initialData: source.currentPosition,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data;
            final activeRangeStartMs = currentBinding.activeRangeStartMs;
            final rollbackFloorMs = currentBinding.positionRollbackFloorMs;
            final rollbackDistanceMs =
                position == null || rollbackFloorMs == null
                ? null
                : rollbackFloorMs - position.inMilliseconds;
            final Duration? positionForHighlight;
            if (position != null &&
                rollbackFloorMs != null &&
                rollbackDistanceMs != null &&
                rollbackDistanceMs > 0 &&
                rollbackDistanceMs <=
                    wordHighlightSeekRollbackTolerance.inMilliseconds) {
              positionForHighlight = Duration(milliseconds: rollbackFloorMs);
            } else {
              positionForHighlight = position;
            }
            final highlightEnabled =
                !snapshot.hasError && playbackStatus?.allowsHighlight == true;
            final activeWordIndex =
                !highlightEnabled ||
                    positionSnapshot.hasError ||
                    positionForHighlight == null ||
                    (activeRangeStartMs != null &&
                        (position?.inMilliseconds ?? -1) < activeRangeStartMs)
                ? null
                : resolveActiveWordIndex(
                    text: widget.text,
                    timestamps: timestamps,
                    sentenceStart: start,
                    sentenceEnd: end,
                    position: positionForHighlight,
                  );
            _logActiveWordTransition(
              source: source,
              sourceKey: sourceKey,
              sentenceStartMs: currentBinding.sentenceStartMs,
              sentenceEndMs: currentBinding.sentenceEndMs,
              position: position,
              playbackStatus: playbackStatus,
              activeWordIndex: activeWordIndex,
            );
            return widget.builder(context, activeWordIndex);
          },
        );
      },
    );
  }

  void _logActiveWordTransition({
    required WordHighlightSource source,
    required Object sourceKey,
    required int sentenceStartMs,
    required int sentenceEndMs,
    required Duration? position,
    required WordHighlightPlaybackStatus? playbackStatus,
    required int? activeWordIndex,
  }) {
    final debugLabel = source.debugLabel;
    if (debugLabel == null) return;
    final diagnosticKey = (debugLabel, sourceKey);
    if (_diagnosticKey != diagnosticKey) {
      _diagnosticKey = diagnosticKey;
      _hasDiagnosticWordIndex = false;
    }
    if (_hasDiagnosticWordIndex &&
        _lastDiagnosticWordIndex == activeWordIndex) {
      return;
    }
    AppLogger.log(
      'WordHighlight',
      'transition source=$debugLabel '
          'audio=${source.audioItemId} '
          'sentence=$sentenceStartMs-$sentenceEndMs ms '
          'position=${position?.inMilliseconds}ms '
          'status=${playbackStatus?.name} '
          'from=${_hasDiagnosticWordIndex ? _lastDiagnosticWordIndex : 'initial'} '
          'to=$activeWordIndex',
    );
    _lastDiagnosticWordIndex = activeWordIndex;
    _hasDiagnosticWordIndex = true;
  }
}
