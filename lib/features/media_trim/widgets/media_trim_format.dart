import '../../../l10n/app_localizations.dart';
import '../media_trim_clip.dart';

/// 编辑用的精确时间：`m:ss.mmm`，超过一小时为 `h:mm:ss.mmm`。
String formatTrimTime(Duration value) {
  final milliseconds = value.inMilliseconds
      .remainder(1000)
      .toString()
      .padLeft(3, '0');
  return '${formatTrimClock(value)}.$milliseconds';
}

/// 概览用的时间：`m:ss`，超过一小时为 `h:mm:ss`。
String formatTrimClock(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}

/// 时长：一分钟内显示一位小数秒，便于区分短片段。
String formatTrimDuration(Duration value) {
  if (value < const Duration(minutes: 1)) {
    return '${(value.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }
  return formatTrimClock(value);
}

/// 解析 `h:mm:ss.mmm` / `m:ss.mmm` / `ss.mmm`；格式无效返回 null。
Duration? parseTrimTime(String input) {
  final parts = input.trim().split(':');
  if (parts.isEmpty || parts.length > 3) return null;
  var seconds = 0.0;
  for (var i = 0; i < parts.length; i++) {
    final value = double.tryParse(parts[i]);
    if (value == null || !value.isFinite || value < 0) return null;
    // 只有最后一段允许小数，且分、秒段不能超过 59。
    final isLast = i == parts.length - 1;
    if (!isLast && value != value.truncateToDouble()) return null;
    if (i > 0 && value >= 60) return null;
    seconds = seconds * 60 + value;
  }
  return Duration(microseconds: (seconds * 1000000).round());
}

String mediaTrimFailureMessage(
  AppLocalizations l10n,
  MediaTrimFailure failure,
) => switch (failure) {
  MediaTrimFailure.sourceMissing => l10n.mediaTrimFailureSourceMissing,
  MediaTrimFailure.transcriptNotReady =>
    l10n.mediaTrimFailureTranscriptNotReady,
  MediaTrimFailure.transcriptInvalid => l10n.mediaTrimFailureTranscriptInvalid,
  MediaTrimFailure.transcriptOutOfRange =>
    l10n.mediaTrimFailureTranscriptOutOfRange,
  MediaTrimFailure.durationUnreadable => l10n.mediaTrimFailureDuration,
  MediaTrimFailure.clipTooShort => l10n.mediaTrimFailureClipTooShort,
  MediaTrimFailure.clipOutOfRange => l10n.mediaTrimFailureClipOutOfRange,
  MediaTrimFailure.clipSplitsSentence => l10n.mediaTrimFailureSplitsSentence,
  MediaTrimFailure.noClips => l10n.mediaTrimFailureNoClips,
  MediaTrimFailure.invalidCollection => l10n.mediaTrimFailureInvalidCollection,
  MediaTrimFailure.collectionNameEmpty => l10n.mediaTrimFailureCollectionName,
  MediaTrimFailure.encodeFailed => l10n.mediaTrimFailureEncode,
  MediaTrimFailure.outputInvalid => l10n.mediaTrimFailureOutput,
  MediaTrimFailure.playbackFailed => l10n.mediaTrimFailurePlayback,
  MediaTrimFailure.cancelled => l10n.mediaTrimFailureCancelled,
  MediaTrimFailure.unexpected => l10n.mediaTrimFailureUnexpected,
};
