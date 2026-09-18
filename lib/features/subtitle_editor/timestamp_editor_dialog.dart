import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/sentence.dart';
import '../../theme/app_theme.dart';
import 'subtitle_editor_controller.dart';

/// 显示时间戳编辑对话框，用于调整单句字幕的起止时间。
///
/// 返回 `true` 表示用户保存了修改，`null` 或 `false` 表示取消。
Future<bool?> showTimestampEditor({
  required BuildContext context,
  required SubtitleEditorController controller,
  required int sentenceIndex,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _TimestampEditorSheet(
      controller: controller,
      sentenceIndex: sentenceIndex,
    ),
  );
}

class _TimestampEditorSheet extends StatefulWidget {
  final SubtitleEditorController controller;
  final int sentenceIndex;

  const _TimestampEditorSheet({
    required this.controller,
    required this.sentenceIndex,
  });

  @override
  State<_TimestampEditorSheet> createState() => _TimestampEditorSheetState();
}

class _TimestampEditorSheetState extends State<_TimestampEditorSheet> {
  late int _currentIndex;
  late Duration _startTime;
  late Duration _endTime;
  double _stepSeconds = 0.1;
  bool _isPlayingStart = false;
  bool _isPlayingEnd = false;

  SubtitleEditorController get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.sentenceIndex;
    _loadSentenceTimes();
  }

  void _loadSentenceTimes() {
    final sentences = _ctrl.snapshot.sentences;
    if (_currentIndex < 0 || _currentIndex >= sentences.length) return;
    final s = sentences[_currentIndex];
    _startTime = s.startTime;
    _endTime = s.endTime;
  }

  Sentence? get _currentSentence {
    final sentences = _ctrl.snapshot.sentences;
    if (_currentIndex < 0 || _currentIndex >= sentences.length) return null;
    return sentences[_currentIndex];
  }

  bool get _hasPrevious => _currentIndex > 0;
  bool get _hasNext => _currentIndex < _ctrl.snapshot.sentences.length - 1;

  void _adjustStart(Duration delta) {
    final newStart = _startTime + delta;
    if (newStart.isNegative || newStart >= _endTime) return;
    setState(() => _startTime = newStart);
  }

  void _adjustEnd(Duration delta) {
    final newEnd = _endTime + delta;
    if (newEnd <= _startTime) return;
    final totalDuration = _ctrl.snapshot.totalDuration;
    if (totalDuration != null && newEnd > totalDuration) return;
    setState(() => _endTime = newEnd);
  }

  Future<void> _playStart() async {
    if (_isPlayingStart || _isPlayingEnd) return;
    setState(() => _isPlayingStart = true);
    try {
      final playEnd = _startTime + const Duration(seconds: 1);
      final sentence = _currentSentence;
      final actualEnd = sentence != null && playEnd > sentence.endTime
          ? sentence.endTime
          : playEnd;
      await _ctrl.playRange(_startTime, actualEnd);
    } finally {
      if (mounted) setState(() => _isPlayingStart = false);
    }
  }

  Future<void> _playEnd() async {
    if (_isPlayingStart || _isPlayingEnd) return;
    setState(() => _isPlayingEnd = true);
    try {
      final sentence = _currentSentence;
      final playStart = _startTime > _endTime - const Duration(seconds: 1)
          ? _startTime
          : _endTime - const Duration(seconds: 1);
      final actualStart = sentence != null && playStart < sentence.startTime
          ? sentence.startTime
          : playStart;
      await _ctrl.playRange(actualStart, _endTime);
    } finally {
      if (mounted) setState(() => _isPlayingEnd = false);
    }
  }

  void _goToPrevious() {
    if (!_hasPrevious) return;
    _saveCurrent(false);
    setState(() {
      _currentIndex--;
      _loadSentenceTimes();
    });
  }

  void _goToNext() {
    if (!_hasNext) return;
    _saveCurrent(false);
    setState(() {
      _currentIndex++;
      _loadSentenceTimes();
    });
  }

  void _saveCurrent(bool dismiss) {
    _ctrl.updateSentenceTimestamps(
      _currentIndex,
      startTime: _startTime,
      endTime: _endTime,
    );
    if (dismiss && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  String _formatDuration(Duration d) {
    final seconds = d.inMilliseconds / 1000;
    return seconds.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sentence = _currentSentence;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.l,
            AppSpacing.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽指示条
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.m),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 标题
              Text(
                l10n.timestampEditorTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // 当前句文本
              if (sentence != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.m),
                  child: Text(
                    sentence.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // 起始 / 结束时间调节区
              Row(
                children: [
                  Expanded(
                    child: _TimeAdjuster(
                      label: l10n.timestampStart,
                      value: _formatDuration(_startTime),
                      isPlaying: _isPlayingStart,
                      onDecrease: () => _adjustStart(
                        Duration(milliseconds: (-_stepSeconds * 1000).round()),
                      ),
                      onIncrease: () => _adjustStart(
                        Duration(milliseconds: (_stepSeconds * 1000).round()),
                      ),
                      onPlay: _playStart,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: _TimeAdjuster(
                      label: l10n.timestampEnd,
                      value: _formatDuration(_endTime),
                      isPlaying: _isPlayingEnd,
                      onDecrease: () => _adjustEnd(
                        Duration(milliseconds: (-_stepSeconds * 1000).round()),
                      ),
                      onIncrease: () => _adjustEnd(
                        Duration(milliseconds: (_stepSeconds * 1000).round()),
                      ),
                      onPlay: _playEnd,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.m),

              // 步长滑块
              Row(
                children: [
                  Text(
                    '${l10n.timestampStep}：',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${_stepSeconds.toStringAsFixed(1)}s',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _stepSeconds,
                      min: 0.1,
                      max: 3.0,
                      divisions: 29,
                      onChanged: (v) => setState(() => _stepSeconds = v),
                    ),
                  ),
                ],
              ),

              // 上一句 / 当前句 / 下一句
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _hasPrevious ? _goToPrevious : null,
                    child: Text(l10n.previousSentence),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _loadSentenceTimes());
                    },
                    child: Text(l10n.currentSentence),
                  ),
                  TextButton(
                    onPressed: _hasNext ? _goToNext : null,
                    child: Text(l10n.nextSentence),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.s),

              // Save 按钮
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _saveCurrent(true),
                  child: Text(l10n.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 时间调节器：标签 + 数值 + 播放按钮 + 加减按钮。
class _TimeAdjuster extends StatelessWidget {
  final String label;
  final String value;
  final bool isPlaying;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onPlay;

  const _TimeAdjuster({
    required this.label,
    required this.value,
    required this.isPlaying,
    required this.onDecrease,
    required this.onIncrease,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        GestureDetector(
          onTap: isPlaying ? null : onPlay,
          child: Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isPlaying ? colorScheme.primary : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: onDecrease,
              icon: const Icon(Icons.remove_circle_outline),
              iconSize: 28,
              visualDensity: VisualDensity.compact,
            ),
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                onPressed: isPlaying ? null : onPlay,
                icon: isPlaying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.play_circle_outline,
                        color: colorScheme.primary,
                      ),
                iconSize: 28,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            IconButton(
              onPressed: onIncrease,
              icon: const Icon(Icons.add_circle_outline),
              iconSize: 28,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }
}
