import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../features/audio_import/audio_import_models.dart';
import '../features/audio_import/audio_import_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/audio_item.dart';
import '../theme/app_theme.dart';
import 'add_audio_dialog.dart';
import 'common/form_input_style.dart';
import 'common/secondary_action_button.dart';

/// 显示统一的音频导入流程。
Future<void> showImportAudioSheet(
  BuildContext context, {
  String? collectionId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ImportAudioFlowSheet(collectionId: collectionId),
  );
}

enum _ImportStep { chooseSource, localFile, directUrl, completed }

class ImportAudioFlowSheet extends ConsumerStatefulWidget {
  const ImportAudioFlowSheet({super.key, this.collectionId});

  final String? collectionId;

  @override
  ConsumerState<ImportAudioFlowSheet> createState() =>
      _ImportAudioFlowSheetState();
}

class _ImportAudioFlowSheetState extends ConsumerState<ImportAudioFlowSheet> {
  final _urlController = TextEditingController();
  _ImportStep _step = _ImportStep.chooseSource;
  List<AudioItem> _importedItems = const [];

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(audioImportControllerProvider);
    final busy = _isBusy(state);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && busy) _cancelUrlImport();
      },
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.86,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ImportHeader(
                  title: _titleFor(l10n),
                  showBack: _step != _ImportStep.chooseSource && !busy,
                  onBack: _goBackToSource,
                  onClose: busy
                      ? _cancelUrlImport
                      : () => Navigator.pop(context),
                ),
                const SizedBox(height: AppSpacing.m),
                Flexible(
                  child: SingleChildScrollView(child: _buildStep(l10n, state)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isBusy(AudioImportState state) {
    return state is AudioImportResolving ||
        state is AudioImportDownloading ||
        state is AudioImportSaving;
  }

  String _titleFor(AppLocalizations l10n) {
    return switch (_step) {
      _ImportStep.chooseSource => l10n.importAudio,
      _ImportStep.localFile => l10n.importAudioFromFile,
      _ImportStep.directUrl => l10n.importAudioFromUrl,
      _ImportStep.completed => l10n.audioImportComplete,
    };
  }

  Widget _buildStep(AppLocalizations l10n, AudioImportState state) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (_step) {
        _ImportStep.chooseSource => _ChooseSourcePanel(
          key: const ValueKey('choose-source'),
          onLocalFile: () => setState(() => _step = _ImportStep.localFile),
          onDirectUrl: () => setState(() => _step = _ImportStep.directUrl),
        ),
        _ImportStep.localFile => AddAudioDialog(
          key: const ValueKey('local-file'),
          collectionId: widget.collectionId,
          embedded: true,
          autoPickOnStart: true,
          onComplete: _handleImported,
          onPickerDismissedEmpty: _goBackToSource,
        ),
        _ImportStep.directUrl => _DirectUrlPanel(
          key: const ValueKey('direct-url'),
          controller: _urlController,
          state: state,
          onSubmit: _submitUrl,
          onBackIdle: _goBackToSource,
          onCancelBusy: _cancelUrlImport,
        ),
        _ImportStep.completed => _CompletedPanel(
          key: const ValueKey('completed'),
          items: _importedItems,
          onDone: () => Navigator.pop(context),
        ),
      },
    );
  }

  void _goBackToSource() {
    ref.read(audioImportControllerProvider.notifier).reset();
    setState(() => _step = _ImportStep.chooseSource);
  }

  void _handleImported(List<AudioItem> items) {
    if (items.isEmpty) return;
    setState(() {
      _importedItems = items;
      _step = _ImportStep.completed;
    });
  }

  Future<void> _submitUrl() async {
    final input = _urlController.text.trim();
    if (input.isEmpty) {
      ref.read(audioImportControllerProvider.notifier).reset();
      return;
    }
    final item = await ref
        .read(audioImportControllerProvider.notifier)
        .importFromUrl(input, collectionId: widget.collectionId);
    if (!mounted || item == null) return;
    _handleImported([item]);
  }

  Future<void> _cancelUrlImport() async {
    await ref.read(audioImportControllerProvider.notifier).cancel();
    if (!mounted) return;
    setState(() => _step = _ImportStep.directUrl);
  }
}

class _ImportHeader extends StatelessWidget {
  const _ImportHeader({
    required this.title,
    required this.showBack,
    required this.onBack,
    required this.onClose,
  });

  final String title;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: showBack
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: onBack,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                  )
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                  ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 40, height: 40),
        ],
      ),
    );
  }
}

class _ChooseSourcePanel extends StatelessWidget {
  const _ChooseSourcePanel({
    super.key,
    required this.onLocalFile,
    required this.onDirectUrl,
  });

  final VoidCallback onLocalFile;
  final VoidCallback onDirectUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ImportOptionTile(
          key: const ValueKey('import-option-local-file'),
          icon: Icons.audio_file_outlined,
          title: l10n.importAudioFromFile,
          description: l10n.importAudioFromFileDescription,
          onTap: onLocalFile,
        ),
        const SizedBox(height: 12),
        _ImportOptionTile(
          key: const ValueKey('import-option-direct-url'),
          icon: Icons.link,
          title: l10n.importAudioFromUrl,
          description: l10n.importAudioFromUrlDescription,
          onTap: onDirectUrl,
        ),
      ],
    );
  }
}

class _ImportOptionTile extends StatelessWidget {
  const _ImportOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectUrlPanel extends StatefulWidget {
  const _DirectUrlPanel({
    super.key,
    required this.controller,
    required this.state,
    required this.onSubmit,
    required this.onBackIdle,
    required this.onCancelBusy,
  });

  final TextEditingController controller;
  final AudioImportState state;
  final VoidCallback onSubmit;
  final VoidCallback onBackIdle;
  final VoidCallback onCancelBusy;

  @override
  State<_DirectUrlPanel> createState() => _DirectUrlPanelState();
}

class _DirectUrlPanelState extends State<_DirectUrlPanel> {
  String? _clipboardError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = widget.state;
    final busy =
        state is AudioImportResolving ||
        state is AudioImportDownloading ||
        state is AudioImportSaving;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          enabled: !busy,
          autofocus: false,
          style: compactFormTextStyle(context),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          decoration: compactFormInputDecoration(
            context,
            labelText: l10n.audioUrlLabel,
            hintText: l10n.audioUrlHint,
            suffixIcon: widget.controller.text.isEmpty || busy
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(widget.controller.clear),
                  ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: busy ? null : (_) => widget.onSubmit(),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Spacer(),
            TextButton.icon(
              onPressed: busy ? null : () => _pasteFromClipboard(l10n),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.content_paste, size: 18),
              label: Text(l10n.pasteAudioLink),
            ),
          ],
        ),
        if (_clipboardError != null) ...[
          const SizedBox(height: 8),
          _InlineInfoCard(message: _clipboardError!),
        ],
        if (state is AudioImportFailed) ...[
          const SizedBox(height: 12),
          _ImportErrorCard(error: state.error),
        ],
        if (state is AudioImportDownloading) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: state.progress < 0 ? null : state.progress,
          ),
          const SizedBox(height: 8),
          Text(
            _progressLabel(l10n, state),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.l),
        Row(
          children: [
            Expanded(
              child: SecondaryActionButton(
                onPressed: busy ? widget.onCancelBusy : widget.onBackIdle,
                label: busy ? l10n.cancelDownload : l10n.back,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: busy || widget.controller.text.trim().isEmpty
                    ? null
                    : widget.onSubmit,
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.downloadAndImportAudio),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pasteFromClipboard(AppLocalizations l10n) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;

    final text = data?.text?.trim() ?? '';
    if (!_isHttpUrl(text)) {
      setState(() => _clipboardError = l10n.audioClipboardNoValidLink);
      return;
    }

    widget.controller.text = text;
    widget.controller.selection = TextSelection.collapsed(offset: text.length);
    setState(() => _clipboardError = null);
  }

  bool _isHttpUrl(String text) {
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  String _progressLabel(AppLocalizations l10n, AudioImportDownloading state) {
    final received = state.receivedBytes;
    final total = state.totalBytes;
    if (received == null || total == null || total <= 0) {
      return l10n.audioDownloadInProgress;
    }
    return '${l10n.audioDownloadInProgress} '
        '${(state.progress * 100).clamp(0, 100).toStringAsFixed(0)}%';
  }
}

class _InlineInfoCard extends StatelessWidget {
  const _InlineInfoCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedPanel extends StatelessWidget {
  const _CompletedPanel({super.key, required this.items, required this.onDone});

  final List<AudioItem> items;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final singleItem = items.length == 1 ? items.first : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: colorScheme.primary, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                singleItem == null
                    ? l10n.multipleAudioAdded(items.length)
                    : singleItem.name,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.l),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: onDone, child: Text(l10n.done)),
        ),
      ],
    );
  }
}

class _ImportErrorCard extends StatelessWidget {
  const _ImportErrorCard({required this.error});

  final AudioImportException error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final message = _messageFor(l10n, error);
    return Semantics(
      liveRegion: true,
      container: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _messageFor(AppLocalizations l10n, AudioImportException error) {
    return switch (error.code) {
      AudioImportFailureCode.invalidUrl ||
      AudioImportFailureCode.unsupportedScheme => l10n.audioUrlInvalid,
      AudioImportFailureCode.unsupportedFormat => l10n.audioUrlUnsupported,
      AudioImportFailureCode.notAudio => l10n.audioUrlNotDirectAudio,
      AudioImportFailureCode.duplicate => l10n.audioUrlDuplicate,
      AudioImportFailureCode.canceled => l10n.audioImportCanceled,
      AudioImportFailureCode.network ||
      AudioImportFailureCode.storage ||
      AudioImportFailureCode.unknown => l10n.audioDownloadFailed,
    };
  }
}
