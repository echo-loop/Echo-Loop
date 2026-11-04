import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/file_size.dart';
import '../media_failure_message.dart';
import '../media_provisioner.dart';
import '../media_readiness.dart';
import '../media_readiness_provider.dart';

/// 计划页在媒体未就绪时的占位视图。纯展示：所有操作通过 [mediaEnsurerProvider] 发出。
///
/// 进度读取与列表行共用同一下载快照，因此两处显示的百分比一致。
class MediaPreparingView extends ConsumerWidget {
  const MediaPreparingView({
    super.key,
    required this.audioItemId,
    required this.name,
  });

  final String audioItemId;

  /// 条目名称，用于失败文案。
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final readiness = ref.watch(mediaReadinessProvider(audioItemId));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: _buildContent(context, ref, l10n, readiness),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    MediaReadiness readiness,
  ) {
    return switch (readiness) {
      MediaReady() => const SizedBox.shrink(),
      MediaChecking() => const CircularProgressIndicator(),
      MediaQueued() => _statusColumn(
        const CircularProgressIndicator(),
        Text(l10n.mediaQueued, textAlign: TextAlign.center),
      ),
      MediaDownloading(:final progress, :final speedBytesPerSecond) =>
        _downloadingColumn(l10n, progress, speedBytesPerSecond),
      MediaNotDownloaded() => _retryColumn(
        ref,
        l10n,
        Text(l10n.mediaPreparingHint, textAlign: TextAlign.center),
      ),
      MediaFailed(:final error) => _retryColumn(
        ref,
        l10n,
        Text(
          _failureText(l10n, error),
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      MediaUnavailable() => Text(
        l10n.communityFileUnavailable,
        textAlign: TextAlign.center,
      ),
      MediaFileMissing() || MediaItemMissing() => Text(
        l10n.audioFileNotFound,
        textAlign: TextAlign.center,
      ),
    };
  }

  Widget _downloadingColumn(
    AppLocalizations l10n,
    double? progress,
    double? speedBytesPerSecond,
  ) {
    final percent = progress == null
        ? ''
        : ' ${(progress * 100).clamp(0, 100).round()}%';
    final speed = speedBytesPerSecond == null
        ? ''
        : ' · ${formatBytes(speedBytesPerSecond.round())}/s';
    return _statusColumn(
      CircularProgressIndicator(value: progress),
      Text(
        '${l10n.audioDownloadInProgress}$percent$speed',
        key: const Key('media_preparing_progress_text'),
      ),
    );
  }

  Widget _retryColumn(WidgetRef ref, AppLocalizations l10n, Widget message) {
    return _statusColumn(
      message,
      FilledButton(
        key: const Key('media_preparing_retry'),
        onPressed: () => ref.read(mediaEnsurerProvider).ensure(audioItemId),
        child: Text(l10n.retry),
      ),
    );
  }

  Widget _statusColumn(Widget first, Widget second) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.m,
      children: [first, second],
    );
  }

  String _failureText(AppLocalizations l10n, Object error) {
    final detail = mediaFailureDetail(l10n, error);
    final title = l10n.downloadFailed(name);
    return detail == null ? title : '$title\n$detail';
  }
}
