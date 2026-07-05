/// 录音入口前置弹窗：在进入录音页面前阻塞式检查本地 ASR 是否就绪。
///
/// 本文件只负责“是否允许继续进入录音流程”的前置判断；
/// 真正进入录音页面后，不再额外弹本地 ASR 守卫 UI。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/enums.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_settings_provider.dart';
import '../providers/offline_asr_settings_provider.dart';
import '../services/asr/asr_model_manager.dart';
import '../services/asr/offline_asr_engine.dart';
import '../services/download/download_failure.dart';
import '../utils/download_failure_message.dart';

/// 判断某个学习子阶段是否会进入依赖本地 ASR 的录音流程。
bool requiresAsrBeforeEnteringSubStage(
  SubStageType subStage, {
  bool listenAndRepeatRatingEnabled = true,
  bool retellRatingEnabled = true,
}) {
  return switch (subStage) {
    SubStageType.listenAndRepeat => listenAndRepeatRatingEnabled,
    SubStageType.reviewDifficultPractice => listenAndRepeatRatingEnabled,
    SubStageType.retell => retellRatingEnabled,
    SubStageType.reviewRetellParagraph => retellRatingEnabled,
    SubStageType.reviewRetellSummary => retellRatingEnabled,
    _ => false,
  };
}

enum _AsrRatingPromptPurpose { listenAndRepeat, retell, generic }

_AsrRatingPromptPurpose _promptPurposeForSubStage(SubStageType subStage) {
  return switch (subStage) {
    SubStageType.listenAndRepeat || SubStageType.reviewDifficultPractice =>
      _AsrRatingPromptPurpose.listenAndRepeat,
    SubStageType.retell ||
    SubStageType.reviewRetellParagraph ||
    SubStageType.reviewRetellSummary => _AsrRatingPromptPurpose.retell,
    _ => _AsrRatingPromptPurpose.generic,
  };
}

({String purpose, String disablePath}) _downloadFailedCopy(
  AppLocalizations l10n,
  _AsrRatingPromptPurpose purpose,
) {
  return switch (purpose) {
    _AsrRatingPromptPurpose.listenAndRepeat => (
      purpose: l10n.speechModelDownloadFailedListenAndRepeatPurpose,
      disablePath: l10n.speechModelDisablePathListenAndRepeat,
    ),
    _AsrRatingPromptPurpose.retell => (
      purpose: l10n.speechModelDownloadFailedRetellPurpose,
      disablePath: l10n.speechModelDisablePathRetell,
    ),
    _AsrRatingPromptPurpose.generic => (
      purpose: l10n.speechModelDownloadFailedGenericPurpose,
      disablePath: l10n.speechModelDisablePathGeneric,
    ),
  };
}

/// 在进入语音练习前检查本地 ASR 是否已就绪。
///
/// 返回：
/// - `true`：允许继续原本的进入动作
/// - `false`：用户取消，本次停留在当前页
Future<bool> ensureAsrReadyBeforeSpeechPractice(
  BuildContext context,
  WidgetRef ref,
) {
  return _ensureAsrReadyBeforeSpeechPractice(
    context,
    ref,
    purpose: _AsrRatingPromptPurpose.generic,
  );
}

Future<bool> _ensureAsrReadyBeforeSpeechPractice(
  BuildContext context,
  WidgetRef ref, {
  required _AsrRatingPromptPurpose purpose,
}) async {
  final state = ref.read(offlineAsrSettingsProvider);

  // 非 offline 后端 → 不需要检查 Whisper 模型。
  if (state.backend != AsrBackend.offline) {
    return true;
  }

  if (state.downloadStatus == AsrModelDownloadStatus.downloaded) {
    // 后台异步加载引擎，不阻塞进入学习页面
    unawaited(_ensureEngineLoaded(ref));
    return true;
  }

  if (state.isDownloading) {
    return _showDownloadProgressDialog(
      context,
      ref,
      startDownload: false,
      purpose: purpose,
    );
  }

  if (state.downloadStatus == AsrModelDownloadStatus.failed) {
    return _showRepairPrompt(context, ref, purpose: purpose);
  }

  return _showEnableDownloadPrompt(context, ref, purpose: purpose);
}

/// 在发起本地（离线）转录前，确保指定 Whisper 档位模型已下载。
///
/// 与 [ensureAsrReadyBeforeSpeechPractice] 不同：**完全无视评分后端**
/// （不早退于 `backend != offline`）——本地转录必用 Whisper 模型。
/// 只按 [model] 检查/下载该档位，**绝不修改评分后端或评分选中模型**。
///
/// 返回 true 表示模型已就绪、可继续转录；false 表示用户取消。
Future<bool> ensureAsrModelReadyForTranscription(
  BuildContext context,
  WidgetRef ref, {
  required AsrModelInfo model,
}) async {
  final st = ref.read(offlineAsrSettingsProvider).modelStateOf(model.id);
  if (st.downloadStatus == AsrModelDownloadStatus.downloaded) {
    return true;
  }
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _TranscriptionModelDownloadDialog(model: model),
  );
  return result == true;
}

/// 仅在目标子阶段依赖本地 ASR 时执行前置检查。
Future<bool> ensureAsrReadyForSubStage(
  BuildContext context,
  WidgetRef ref,
  SubStageType subStage,
) async {
  final settings = ref.read(learningSettingsProvider);
  if (!requiresAsrBeforeEnteringSubStage(
    subStage,
    listenAndRepeatRatingEnabled: settings.listenAndRepeatRatingEnabled,
    retellRatingEnabled: settings.retellRatingEnabled,
  )) {
    return true;
  }
  return _ensureAsrReadyBeforeSpeechPractice(
    context,
    ref,
    purpose: _promptPurposeForSubStage(subStage),
  );
}

/// 后台加载引擎（fire-and-forget，不阻塞 UI）。
Future<void> _ensureEngineLoaded(WidgetRef ref) async {
  final state = ref.read(offlineAsrSettingsProvider);
  if (state.backend == AsrBackend.offline &&
      state.downloadStatus == AsrModelDownloadStatus.downloaded &&
      !state.engineReady) {
    await ref.read(offlineAsrSettingsProvider.notifier).loadEngine();
  }
}

Future<bool> _showEnableDownloadPrompt(
  BuildContext context,
  WidgetRef ref, {
  required _AsrRatingPromptPurpose purpose,
}) async {
  final shouldDownload = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const _EnableDownloadPromptDialog(),
  );

  if (shouldDownload == true && context.mounted) {
    return _showDownloadProgressDialog(
      context,
      ref,
      startDownload: true,
      purpose: purpose,
    );
  }

  // 用户选择"暂不启用"：仅阻止本次进入，不修改设置。
  // 下次进入练习时会再次提示下载。
  return false;
}

Future<bool> _showRepairPrompt(
  BuildContext context,
  WidgetRef ref, {
  required _AsrRatingPromptPurpose purpose,
}) async {
  final state = ref.read(offlineAsrSettingsProvider);
  final shouldDownload = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _RepairPromptDialog(
      isFailed: state.downloadStatus == AsrModelDownloadStatus.failed,
      downloadError: state.downloadError,
      purpose: purpose,
    ),
  );

  if (shouldDownload != true || !context.mounted) return false;
  return _showDownloadProgressDialog(
    context,
    ref,
    startDownload: true,
    purpose: purpose,
  );
}

/// 下载进度弹窗（阻塞式）。
Future<bool> _showDownloadProgressDialog(
  BuildContext context,
  WidgetRef ref, {
  required bool startDownload,
  required _AsrRatingPromptPurpose purpose,
}) async {
  final notifier = ref.read(offlineAsrSettingsProvider.notifier);
  if (startDownload) {
    notifier.enable();
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _DownloadProgressDialog(purpose: purpose),
  );

  if (result == true) {
    await _ensureEngineLoaded(ref);
    return true;
  }
  return false;
}

class _EnableDownloadPromptDialog extends ConsumerWidget {
  const _EnableDownloadPromptDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: _DialogTitle(
        title: l10n.speechRecognitionRequiredTitle,
        onClose: () => Navigator.of(context).pop(),
      ),
      content: Text(l10n.speechRecognitionRequiredMessage),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.downloadNow),
        ),
      ],
    );
  }
}

class _RepairPromptDialog extends ConsumerWidget {
  final bool isFailed;
  final DownloadFailureKind? downloadError;
  final _AsrRatingPromptPurpose purpose;

  const _RepairPromptDialog({
    required this.isFailed,
    required this.purpose,
    this.downloadError,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: _DialogTitle(
        title: isFailed
            ? l10n.speechModelDownloadFailedTitle
            : l10n.speechModelRepairTitle,
        onClose: () => Navigator.of(context).pop(),
      ),
      content: isFailed
          ? _DownloadFailedContent(
              downloadError: downloadError,
              purpose: purpose,
            )
          : Text(l10n.speechModelRepairMessage),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(isFailed ? l10n.retryDownload : l10n.downloadNow),
        ),
      ],
    );
  }
}

class _DownloadProgressDialog extends ConsumerWidget {
  final _AsrRatingPromptPurpose purpose;

  const _DownloadProgressDialog({required this.purpose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(offlineAsrSettingsProvider);

    if (state.isOfflineReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop(true);
      });
    }

    final isFailed = state.downloadStatus == AsrModelDownloadStatus.failed;

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: _DialogTitle(
        title: isFailed
            ? l10n.speechModelDownloadFailedTitle
            : l10n.downloadingSpeechModel,
        onClose: () => Navigator.of(context).pop(),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isFailed)
            Text(
              l10n.speechRecognitionRequiredMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (state.isDownloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: state.downloadProgress),
            const SizedBox(height: 8),
            Text(
              '${(state.downloadProgress * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          // 标题已是通用「下载失败」，仅当原因确定时再补一行具体指引（unknown 不重复）。
          if (isFailed &&
              state.downloadError != null &&
              state.downloadError != DownloadFailureKind.unknown) ...[
            const SizedBox(height: 8),
            Text(
              downloadFailureMessage(l10n, state.downloadError),
              style: const TextStyle(color: Colors.red),
            ),
          ],
          if (isFailed) ...[
            const SizedBox(height: 8),
            _DownloadFailedContent(downloadError: null, purpose: purpose),
          ],
        ],
      ),
      actions: state.downloadStatus == AsrModelDownloadStatus.failed
          ? [
              FilledButton(
                onPressed: () => ref
                    .read(offlineAsrSettingsProvider.notifier)
                    .retryDownload(),
                child: Text(l10n.retryDownload),
              ),
            ]
          : const [],
    );
  }
}

class _DownloadFailedContent extends StatelessWidget {
  final DownloadFailureKind? downloadError;
  final _AsrRatingPromptPurpose purpose;

  const _DownloadFailedContent({
    required this.downloadError,
    required this.purpose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final copy = _downloadFailedCopy(l10n, purpose);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (downloadError != null &&
            downloadError != DownloadFailureKind.unknown) ...[
          Text(
            downloadFailureMessage(l10n, downloadError),
            style: TextStyle(color: colorScheme.error),
          ),
          const SizedBox(height: 10),
        ],
        Text(copy.purpose, style: textTheme.bodyMedium),
        const SizedBox(height: 14),
        Text(
          l10n.speechModelDownloadFailedDisableHint,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          copy.disablePath,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// 本地转录专用的模型下载对话框（按指定档位）。
///
/// 打开时若该档位未在下载则自动开始下载（`retryDownload(modelId)` 只作用于该
/// 档位、不改评分后端/选中模型）；下载完成自动 pop(true)，失败可重试。
class _TranscriptionModelDownloadDialog extends ConsumerStatefulWidget {
  final AsrModelInfo model;

  const _TranscriptionModelDownloadDialog({required this.model});

  @override
  ConsumerState<_TranscriptionModelDownloadDialog> createState() =>
      _TranscriptionModelDownloadDialogState();
}

class _TranscriptionModelDownloadDialogState
    extends ConsumerState<_TranscriptionModelDownloadDialog> {
  @override
  void initState() {
    super.initState();
    // 打开即按需开始下载该档位（已在下载/已完成则 retryDownload 内部安全处理）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final st = ref
          .read(offlineAsrSettingsProvider)
          .modelStateOf(widget.model.id);
      if (st.downloadStatus != AsrModelDownloadStatus.downloading &&
          st.downloadStatus != AsrModelDownloadStatus.downloaded) {
        ref
            .read(offlineAsrSettingsProvider.notifier)
            .retryDownload(widget.model.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final st = ref.watch(
      offlineAsrSettingsProvider.select((s) => s.modelStateOf(widget.model.id)),
    );

    if (st.downloadStatus == AsrModelDownloadStatus.downloaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop(true);
      });
    }

    final isFailed = st.downloadStatus == AsrModelDownloadStatus.failed;

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: _DialogTitle(
        title: isFailed
            ? l10n.speechModelDownloadFailedTitle
            : l10n.localTranscriptionModelRequiredTitle,
        onClose: () => Navigator.of(context).pop(false),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isFailed)
            Text(
              l10n.localTranscriptionModelRequiredMessage(
                widget.model.displayName,
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (st.isDownloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: st.downloadProgress),
            const SizedBox(height: 8),
            Text(
              '${(st.downloadProgress * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (isFailed &&
              st.downloadError != null &&
              st.downloadError != DownloadFailureKind.unknown) ...[
            const SizedBox(height: 8),
            Text(
              downloadFailureMessage(l10n, st.downloadError),
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
      actions: isFailed
          ? [
              FilledButton(
                onPressed: () => ref
                    .read(offlineAsrSettingsProvider.notifier)
                    .retryDownload(widget.model.id),
                child: Text(l10n.retryDownload),
              ),
            ]
          : const [],
    );
  }
}

class _DialogTitle extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _DialogTitle({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 标题文字，右侧留出关闭按钮的空间
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 48, 0),
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        // 关闭按钮固定在右上角
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20),
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
        ),
      ],
    );
  }
}
