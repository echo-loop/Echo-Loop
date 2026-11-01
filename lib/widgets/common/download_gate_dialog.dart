import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/download_provider.dart';
import '../../services/download/download_task_store.dart';

Future<bool> ensureDownloadReady(
  BuildContext context,
  WidgetRef ref,
  String resourceId,
) async {
  final coordinator = ref.read(downloadTaskCoordinatorProvider);
  final state = await coordinator.refresh(resourceId);
  if (state.isReady) return true;
  if (!context.mounted) return false;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => DownloadGateDialog(resourceId: resourceId),
  );
  return result == true;
}

class DownloadGateDialog extends ConsumerStatefulWidget {
  const DownloadGateDialog({required this.resourceId, super.key});

  final String resourceId;

  @override
  ConsumerState<DownloadGateDialog> createState() => _DownloadGateDialogState();
}

class _DownloadGateDialogState extends ConsumerState<DownloadGateDialog> {
  @override
  Widget build(BuildContext context) {
    final coordinator = ref.read(downloadTaskCoordinatorProvider);
    final resource = coordinator.resourceOf(widget.resourceId);
    final state =
        ref.watch(downloadTaskStateProvider(widget.resourceId)).value ??
        coordinator.stateOf(widget.resourceId);
    final l10n = AppLocalizations.of(context)!;
    if (state.isReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    }
    final failed = state.status == DownloadTaskStatus.failed;
    final active = state.isActive;
    return AlertDialog(
      title: Text(resource.displayName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            failed
                ? l10n.downloadFailed(resource.displayName)
                : l10n.downloadLoading,
          ),
          if (active) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: state.progress == 0 ? null : state.progress,
            ),
            const SizedBox(height: 8),
            Text('${(state.progress * 100).toStringAsFixed(0)}%'),
          ],
        ],
      ),
      actions: [
        if (active)
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await coordinator.cancel(widget.resourceId);
              if (mounted) navigator.pop(false);
            },
            child: Text(l10n.cancelDownload),
          )
        else if (failed)
          FilledButton(
            onPressed: () => coordinator.start(widget.resourceId),
            child: Text(l10n.retryDownload),
          )
        else
          FilledButton(
            onPressed: () => coordinator.start(widget.resourceId),
            child: Text(l10n.download),
          ),
      ],
    );
  }
}
