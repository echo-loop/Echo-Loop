import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../features/audio_import/audio_import_models.dart';
import '../features/audio_import/audio_import_provider.dart';
import '../features/audio_import/subtitle_pairing.dart';
import '../features/baidu_netdisk/models/cloud_drive_models.dart';
import '../features/baidu_netdisk/providers/baidu_netdisk_import_controller.dart';
import '../features/baidu_netdisk/providers/baidu_netdisk_providers.dart';
import '../features/remote_config/remote_config.dart';
import '../features/remote_config/remote_config_providers.dart';
import '../l10n/app_localizations.dart';
import '../models/audio_item.dart';
import '../theme/app_theme.dart';
import 'add_audio_dialog.dart';
import 'common/form_input_style.dart';
import 'common/secondary_action_button.dart';
import 'import_audio_selection_list.dart';

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

enum _ImportStep {
  chooseSource,
  localFile,
  directUrl,
  cloudDrive,
  baiduNetdisk,
  completed,
}

class ImportAudioFlowSheet extends ConsumerStatefulWidget {
  const ImportAudioFlowSheet({super.key, this.collectionId});

  final String? collectionId;

  @override
  ConsumerState<ImportAudioFlowSheet> createState() =>
      _ImportAudioFlowSheetState();
}

class _ImportAudioFlowSheetState extends ConsumerState<ImportAudioFlowSheet> {
  final _sheetScrollController = ScrollController();
  final _urlController = TextEditingController();
  _ImportStep _step = _ImportStep.chooseSource;
  AudioImportOutcome _outcome = (added: const [], duplicates: const []);
  bool _baiduConfirming = false;

  @override
  void dispose() {
    _sheetScrollController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(audioImportControllerProvider);
    final baiduState = ref.watch(baiduNetdiskImportControllerProvider);
    final baiduController = ref.read(
      baiduNetdiskImportControllerProvider.notifier,
    );
    final cloudDriveImportEnabled = ref.watch(
      remoteFeatureEnabledProvider(RemoteFeature.cloudDriveImport),
    );
    final busy = _isBusy(state) || baiduState.isBusy;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && busy) _cancelActiveImport();
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
                  title: _titleFor(l10n, baiduState),
                  showBack: _step != _ImportStep.chooseSource && !busy,
                  titleSmall:
                      _step == _ImportStep.baiduNetdisk && !_baiduConfirming,
                  onBack: _goBack,
                  trailing: _baiduHeaderTrailing(
                    l10n: l10n,
                    state: baiduState,
                    busy: busy,
                    onToggleSelectAll: baiduController.toggleSelectAll,
                  ),
                  onClose: busy
                      ? _cancelActiveImport
                      : () => Navigator.pop(context),
                ),
                const SizedBox(height: AppSpacing.m),
                Flexible(
                  child: SingleChildScrollView(
                    controller: _sheetScrollController,
                    primary: false,
                    child: _buildStep(
                      l10n,
                      state,
                      cloudDriveImportEnabled: cloudDriveImportEnabled,
                    ),
                  ),
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

  Widget? _baiduHeaderTrailing({
    required AppLocalizations l10n,
    required BaiduNetdiskImportState state,
    required bool busy,
    required VoidCallback onToggleSelectAll,
  }) {
    if (_step != _ImportStep.baiduNetdisk || _baiduConfirming) return null;
    if (state.selectedFsIds.isNotEmpty) {
      return _HeaderTextButton(
        label: state.isAllSelectableSelected
            ? l10n.baiduNetdiskClearSelectionAction
            : l10n.baiduNetdiskSelectAllAction,
        onPressed: busy ? null : onToggleSelectAll,
      );
    }
    final canLogout = switch (state.phase) {
      BaiduNetdiskImportPhase.ready ||
      BaiduNetdiskImportPhase.importing ||
      BaiduNetdiskImportPhase.completed ||
      BaiduNetdiskImportPhase.failed => true,
      BaiduNetdiskImportPhase.idle ||
      BaiduNetdiskImportPhase.authorizationRequired ||
      BaiduNetdiskImportPhase.authorizing ||
      BaiduNetdiskImportPhase.loading => false,
    };
    if (!canLogout) return null;
    return _HeaderIconButton(
      icon: Icons.logout,
      tooltip: l10n.baiduNetdiskLogoutTooltip,
      onPressed: busy ? null : _confirmBaiduLogout,
    );
  }

  String _titleFor(AppLocalizations l10n, BaiduNetdiskImportState baiduState) {
    return switch (_step) {
      _ImportStep.chooseSource => l10n.importAudio,
      _ImportStep.localFile => l10n.importAudioFromFile,
      _ImportStep.directUrl => l10n.importAudioFromUrl,
      _ImportStep.cloudDrive => l10n.importAudioFromCloudDrive,
      _ImportStep.baiduNetdisk =>
        _baiduConfirming
            ? l10n.importList
            : _directoryName(l10n, baiduState.currentPath),
      _ImportStep.completed => l10n.audioImportComplete,
    };
  }

  Widget _buildStep(
    AppLocalizations l10n,
    AudioImportState state, {
    required bool cloudDriveImportEnabled,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (_step) {
        _ImportStep.chooseSource => _ChooseSourcePanel(
          key: const ValueKey('choose-source'),
          showCloudDrive: cloudDriveImportEnabled,
          onLocalFile: () => setState(() => _step = _ImportStep.localFile),
          onDirectUrl: () => setState(() => _step = _ImportStep.directUrl),
          onCloudDrive: () => setState(() => _step = _ImportStep.cloudDrive),
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
        _ImportStep.cloudDrive => _CloudDriveSourcePanel(
          key: const ValueKey('cloud-drive-source'),
          onBaiduNetdisk: () =>
              setState(() => _step = _ImportStep.baiduNetdisk),
        ),
        _ImportStep.baiduNetdisk => _BaiduNetdiskPanel(
          key: const ValueKey('baidu-netdisk'),
          collectionId: widget.collectionId,
          confirming: _baiduConfirming,
          onShowConfirm: () => setState(() => _baiduConfirming = true),
          onHideConfirm: () => setState(() => _baiduConfirming = false),
          onBack: _goBackFromBaiduNetdisk,
        ),
        _ImportStep.completed => _CompletedPanel(
          key: const ValueKey('completed'),
          outcome: _outcome,
          onDone: () => Navigator.pop(context),
        ),
      },
    );
  }

  void _goBackToSource() {
    ref.read(audioImportControllerProvider.notifier).reset();
    ref.read(baiduNetdiskImportControllerProvider.notifier).reset();
    setState(() {
      _step = _ImportStep.chooseSource;
      _baiduConfirming = false;
    });
  }

  void _goBackToCloudDriveSources() {
    ref.read(baiduNetdiskImportControllerProvider.notifier).reset();
    setState(() {
      _step = _ImportStep.cloudDrive;
      _baiduConfirming = false;
    });
  }

  void _goBackFromBaiduNetdisk() {
    final controller = ref.read(baiduNetdiskImportControllerProvider.notifier);
    final path = ref.read(baiduNetdiskImportControllerProvider).currentPath;
    if (path == '/' || path.isEmpty) {
      _goBackToCloudDriveSources();
      return;
    }
    controller.loadDirectory(_parentPath(path));
  }

  void _goBack() {
    if (_step == _ImportStep.baiduNetdisk) {
      if (_baiduConfirming) {
        final baiduController = ref.read(
          baiduNetdiskImportControllerProvider.notifier,
        );
        final baiduPhase = ref.read(baiduNetdiskImportControllerProvider).phase;
        if (baiduPhase == BaiduNetdiskImportPhase.completed) {
          baiduController.returnToReady();
        }
        setState(() => _baiduConfirming = false);
        return;
      }
      _goBackFromBaiduNetdisk();
      return;
    }
    _goBackToSource();
  }

  Future<void> _confirmBaiduLogout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.baiduNetdiskLogoutTitle),
          content: Text(l10n.baiduNetdiskLogoutMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.baiduNetdiskLogoutConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await ref.read(baiduCredentialRepositoryProvider).clearCredential();
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _handleImported(AudioImportOutcome outcome) {
    // 无任何结果（既没成功也没跳过）时不前进，停留原页供用户重选。
    if (outcome.added.isEmpty && outcome.duplicates.isEmpty) return;
    setState(() {
      _outcome = outcome;
      _step = _ImportStep.completed;
      _baiduConfirming = false;
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
    _handleImported((added: [item], duplicates: const []));
  }

  Future<void> _cancelUrlImport() async {
    await ref.read(audioImportControllerProvider.notifier).cancel();
    if (!mounted) return;
    setState(() => _step = _ImportStep.directUrl);
  }

  Future<void> _cancelActiveImport() async {
    if (_step == _ImportStep.baiduNetdisk) {
      ref.read(baiduNetdiskImportControllerProvider.notifier).cancel();
      return;
    }
    await _cancelUrlImport();
  }
}

class _ImportHeader extends StatelessWidget {
  const _ImportHeader({
    required this.title,
    required this.showBack,
    this.titleSmall = false,
    this.trailing,
    required this.onBack,
    required this.onClose,
  });

  final String title;
  final bool showBack;
  final bool titleSmall;
  final Widget? trailing;
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: trailing == null ? 48 : 72,
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: titleSmall
                  ? theme.textTheme.bodyLarge?.copyWith(fontSize: 16)
                  : theme.textTheme.titleLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 40, maxWidth: 40),
              child: SizedBox(
                height: 40,
                child: showBack
                    ? IconButton(
                        onPressed: onBack,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 28,
                        ),
                        style: IconButton.styleFrom(
                          fixedSize: const Size(40, 40),
                          minimumSize: const Size(40, 40),
                          maximumSize: const Size(40, 40),
                          shape: const CircleBorder(),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ),
                      )
                    : _HeaderIconButton(
                        icon: Icons.close,
                        onPressed: onClose,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                      ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 40,
                maxWidth: trailing == null ? 40 : 64,
              ),
              child: SizedBox(
                height: 40,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: trailing ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
        maximumSize: const Size(40, 40),
        shape: const CircleBorder(),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        hoverColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        highlightColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.52,
        ),
      ),
    );
  }
}

class _HeaderTextButton extends StatelessWidget {
  const _HeaderTextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        fixedSize: const Size(56, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: theme.textTheme.labelLarge,
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _ChooseSourcePanel extends StatelessWidget {
  const _ChooseSourcePanel({
    super.key,
    required this.showCloudDrive,
    required this.onLocalFile,
    required this.onDirectUrl,
    required this.onCloudDrive,
  });

  final bool showCloudDrive;
  final VoidCallback onLocalFile;
  final VoidCallback onDirectUrl;
  final VoidCallback onCloudDrive;

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
          onTap: onLocalFile,
        ),
        if (showCloudDrive) ...[
          const SizedBox(height: 8),
          _ImportOptionTile(
            key: const ValueKey('import-option-cloud-drive'),
            icon: Icons.cloud_outlined,
            title: l10n.importAudioFromCloudDrive,
            onTap: onCloudDrive,
          ),
        ],
        const SizedBox(height: 8),
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

class _CloudDriveSourcePanel extends StatelessWidget {
  const _CloudDriveSourcePanel({super.key, required this.onBaiduNetdisk});

  final VoidCallback onBaiduNetdisk;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ImportOptionTile(
          key: const ValueKey('cloud-drive-option-baidu-netdisk'),
          leading: SvgPicture.asset(
            'assets/icon/baidu-netdisk.svg',
            width: 30,
            height: 30,
          ),
          title: l10n.baiduNetdisk,
          onTap: onBaiduNetdisk,
        ),
      ],
    );
  }
}

class _BaiduNetdiskPanel extends ConsumerStatefulWidget {
  const _BaiduNetdiskPanel({
    super.key,
    required this.collectionId,
    required this.confirming,
    required this.onShowConfirm,
    required this.onHideConfirm,
    required this.onBack,
  });

  final String? collectionId;
  final bool confirming;
  final VoidCallback onShowConfirm;
  final VoidCallback onHideConfirm;
  final VoidCallback onBack;

  @override
  ConsumerState<_BaiduNetdiskPanel> createState() => _BaiduNetdiskPanelState();
}

class _BaiduNetdiskPanelState extends ConsumerState<_BaiduNetdiskPanel> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () =>
          ref.read(baiduNetdiskImportControllerProvider.notifier).loadInitial(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(baiduNetdiskImportControllerProvider);
    final controller = ref.read(baiduNetdiskImportControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: state.isBusy
          ? null
          : (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity > 300) {
                if (widget.confirming) {
                  widget.onHideConfirm();
                } else {
                  widget.onBack();
                }
              }
            },
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.58,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.errorMessage != null) ...[
              _InlineInfoCard(message: state.errorMessage!),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: switch (state.phase) {
                BaiduNetdiskImportPhase.idle ||
                BaiduNetdiskImportPhase.authorizationRequired =>
                  _BaiduAuthPrompt(onAuthorize: controller.authorizeAndLoad),
                BaiduNetdiskImportPhase.authorizing => _BaiduBusyPanel(
                  message: l10n.baiduNetdiskWaitingAuthorization,
                ),
                BaiduNetdiskImportPhase.loading => _BaiduBusyPanel(
                  message: l10n.baiduNetdiskLoadingFiles,
                ),
                BaiduNetdiskImportPhase.ready =>
                  widget.confirming
                      ? _BaiduSelectedFilesConfirmPanel(
                          state: state,
                          onImport: () => controller.importSelected(
                            collectionId: widget.collectionId,
                          ),
                          onRemove: controller.toggleEntry,
                          onDone: () => Navigator.pop(context),
                        )
                      : _BaiduFileBrowser(
                          state: state,
                          onOpenDirectory: controller.loadDirectory,
                          onToggle: controller.toggleEntry,
                          onImport: widget.onShowConfirm,
                        ),
                BaiduNetdiskImportPhase.importing =>
                  widget.confirming
                      ? _BaiduSelectedFilesConfirmPanel(
                          state: state,
                          onImport: () {},
                          onRemove: null,
                          onDone: () => Navigator.pop(context),
                        )
                      : _BaiduImportingPanel(
                          state: state,
                          onCancel: controller.cancel,
                        ),
                BaiduNetdiskImportPhase.completed =>
                  widget.confirming
                      ? _BaiduSelectedFilesConfirmPanel(
                          state: state,
                          onImport: () {},
                          onRemove: null,
                          onDone: () => Navigator.pop(context),
                        )
                      : _BaiduFileBrowser(
                          state: state,
                          onOpenDirectory: controller.loadDirectory,
                          onToggle: controller.toggleEntry,
                          onImport: widget.onShowConfirm,
                        ),
                BaiduNetdiskImportPhase.failed => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.baiduNetdiskImportFailed,
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () =>
                            controller.loadDirectory(state.currentPath),
                        child: Text(l10n.retry),
                      ),
                    ),
                  ],
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BaiduAuthPrompt extends StatelessWidget {
  const _BaiduAuthPrompt({required this.onAuthorize});

  final VoidCallback onAuthorize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.baiduNetdiskConnectTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          l10n.baiduNetdiskConnectDescription,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onAuthorize,
            icon: const Icon(Icons.open_in_browser),
            label: Text(l10n.baiduNetdiskConnectAction),
          ),
        ),
      ],
    );
  }
}

class _BaiduBusyPanel extends StatelessWidget {
  const _BaiduBusyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Text(message),
      ],
    );
  }
}

class _BaiduFileBrowser extends StatefulWidget {
  const _BaiduFileBrowser({
    required this.state,
    required this.onOpenDirectory,
    required this.onToggle,
    required this.onImport,
  });

  final BaiduNetdiskImportState state;
  final ValueChanged<String> onOpenDirectory;
  final ValueChanged<CloudDriveEntry> onToggle;
  final VoidCallback onImport;

  @override
  State<_BaiduFileBrowser> createState() => _BaiduFileBrowserState();
}

class _BaiduFileBrowserState extends State<_BaiduFileBrowser> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final selectedCount = widget.state.selectedAudioEntries.length;
    final selectedSubtitleCount = _matchedSubtitleFsIdsFor(widget.state).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView.separated(
              controller: _scrollController,
              primary: false,
              itemCount: widget.state.entries.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
              itemBuilder: (context, index) {
                final entry = widget.state.entries[index];
                return _BaiduFileTile(
                  entry: entry,
                  selected: widget.state.selectedFsIds.contains(entry.fsId),
                  onOpenDirectory: widget.onOpenDirectory,
                  onToggle: widget.onToggle,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: selectedCount == 0 ? null : widget.onImport,
            child: Text(
              selectedCount == 0
                  ? l10n.importAudioShort
                  : l10n.importAudioAndSubtitleCount(
                      selectedCount,
                      selectedSubtitleCount,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BaiduFileTile extends StatelessWidget {
  const _BaiduFileTile({
    required this.entry,
    required this.selected,
    required this.onOpenDirectory,
    required this.onToggle,
  });

  final CloudDriveEntry entry;
  final bool selected;
  final ValueChanged<String> onOpenDirectory;
  final ValueChanged<CloudDriveEntry> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAudio = _isImportableAudio(entry);
    final isSubtitle = _isImportableSubtitle(entry);
    final isSelectableFile = isAudio || isSubtitle;
    final isUnsupportedFile = !entry.isDirectory && !isAudio && !isSubtitle;
    final iconColor = isUnsupportedFile
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.38)
        : colorScheme.primary;
    return ListTile(
      dense: true,
      enabled: !isUnsupportedFile,
      leading: Icon(
        entry.isDirectory
            ? Icons.folder_outlined
            : isAudio
            ? Icons.graphic_eq
            : isSubtitle
            ? Icons.subtitles_outlined
            : Icons.insert_drive_file_outlined,
        color: iconColor,
      ),
      title: Text(
        entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isUnsupportedFile
            ? TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.52),
              )
            : null,
      ),
      subtitle: _entrySubtitle(entry) == null
          ? null
          : Text(
              _entrySubtitle(entry)!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(
                  alpha: isUnsupportedFile ? 0.44 : 0.64,
                ),
              ),
            ),
      trailing: entry.isDirectory
          ? const Icon(Icons.chevron_right)
          : isSelectableFile
          ? Checkbox(
              value: selected,
              side: BorderSide(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.62),
                width: 1.6,
              ),
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return colorScheme.primary.withValues(alpha: 0.86);
                }
                return Colors.transparent;
              }),
              checkColor: colorScheme.onPrimary,
              onChanged: (_) => onToggle(entry),
            )
          : null,
      onTap: entry.isDirectory
          ? () => onOpenDirectory(entry.path)
          : isSelectableFile
          ? () => onToggle(entry)
          : null,
    );
  }
}

class _BaiduSelectedFilesConfirmPanel extends StatelessWidget {
  const _BaiduSelectedFilesConfirmPanel({
    required this.state,
    required this.onImport,
    required this.onRemove,
    required this.onDone,
  });

  final BaiduNetdiskImportState state;
  final VoidCallback onImport;
  final ValueChanged<CloudDriveEntry>? onRemove;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final matchedSubtitleFsIds = _matchedSubtitleFsIdsFor(state);
    final audios = state.selectedAudioEntries;
    final completed = state.phase == BaiduNetdiskImportPhase.completed;
    final subtitleCount = matchedSubtitleFsIds.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ImportAudioSelectionList(
            items: [
              for (final entry in audios)
                _selectionItemFor(entry, matchedSubtitleFsIds),
            ],
            progress: _importProgress(l10n, state),
            summary: _summaryFor(state),
            onRemove: onRemove == null
                ? null
                : (id) {
                    final fsId = int.tryParse(id);
                    if (fsId == null) return;
                    for (final entry in audios) {
                      if (entry.fsId == fsId) {
                        onRemove!(entry);
                        return;
                      }
                    }
                  },
            maxHeight: double.infinity,
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        if (completed)
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onDone, child: Text(l10n.done)),
          )
        else
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: audios.isEmpty || state.isBusy ? null : onImport,
              child: state.isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      audios.isEmpty
                          ? l10n.importAudioShort
                          : l10n.importAudioAndSubtitleCount(
                              audios.length,
                              subtitleCount,
                            ),
                    ),
            ),
          ),
      ],
    );
  }

  AudioImportSelectionItem _selectionItemFor(
    CloudDriveEntry entry,
    Set<int> matchedSubtitleFsIds,
  ) {
    final duplicateExistingName = _duplicateExistingNameFor(entry);
    return AudioImportSelectionItem(
      id: entry.fsId.toString(),
      displayName: entry.name,
      fileSize: entry.size,
      hasSubtitle: _hasSubtitleForEntry(entry, matchedSubtitleFsIds),
      status: _selectionStatusFor(entry, duplicateExistingName),
      duplicateExistingName: duplicateExistingName,
    );
  }

  bool _hasSubtitleForEntry(
    CloudDriveEntry entry,
    Set<int> matchedSubtitleFsIds,
  ) {
    final outcome = state.importOutcome;
    if (state.phase == BaiduNetdiskImportPhase.completed && outcome != null) {
      final importedItem = state.importedItemsByFsId[entry.fsId];
      if (importedItem != null) {
        return importedItem.transcriptSource == TranscriptSource.local;
      }
      for (var i = 0; i < outcome.added.length; i++) {
        if (outcome.added[i].fsId != entry.fsId) continue;
        final item = i < outcome.addedItems.length
            ? outcome.addedItems[i]
            : null;
        return item?.transcriptSource == TranscriptSource.local;
      }
    }
    return matchedSubtitleFsIds.contains(entry.fsId);
  }

  AudioImportSelectionStatus _selectionStatusFor(
    CloudDriveEntry entry,
    String? duplicateExistingName,
  ) {
    final status = state.importItemStatuses[entry.fsId];
    if (status != null &&
        (state.phase == BaiduNetdiskImportPhase.importing ||
            state.phase == BaiduNetdiskImportPhase.completed)) {
      return status;
    }
    if (state.phase == BaiduNetdiskImportPhase.importing) {
      return state.importingEntry?.fsId == entry.fsId
          ? AudioImportSelectionStatus.importing
          : AudioImportSelectionStatus.pending;
    }
    if (state.phase == BaiduNetdiskImportPhase.completed) {
      final outcome = state.importOutcome;
      final addedFsIds =
          outcome?.added.map((entry) => entry.fsId).toSet() ?? const <int>{};
      if (addedFsIds.contains(entry.fsId)) {
        return AudioImportSelectionStatus.added;
      }
      if (duplicateExistingName != null) {
        return AudioImportSelectionStatus.skipped;
      }
    }
    return AudioImportSelectionStatus.pending;
  }

  String? _duplicateExistingNameFor(CloudDriveEntry entry) {
    final stateName = state.importDuplicateExistingNames[entry.fsId];
    if (stateName != null) return stateName;
    final duplicates =
        state.importOutcome?.audioDuplicates ?? const <AudioImportDuplicate>[];
    final displayName = _entryDisplayNameWithoutExtension(entry);
    for (final duplicate in duplicates) {
      if (duplicate.attempted == displayName) return duplicate.existing;
    }
    return null;
  }

  AudioImportSelectionSummary? _summaryFor(BaiduNetdiskImportState state) {
    if (state.phase != BaiduNetdiskImportPhase.completed) return null;
    final outcome = state.importOutcome;
    if (outcome == null) return null;
    return AudioImportSelectionSummary(
      addedCount: outcome.addedItems.length,
      subtitleCount: outcome.addedItems
          .where((item) => item.transcriptSource == TranscriptSource.local)
          .length,
      skippedCount: outcome.audioDuplicates.length,
    );
  }

  AudioImportSelectionProgress? _importProgress(
    AppLocalizations l10n,
    BaiduNetdiskImportState state,
  ) {
    if (state.phase != BaiduNetdiskImportPhase.importing) return null;
    final entry = state.importingEntry;
    return AudioImportSelectionProgress(
      value: state.importProgress < 0 ? null : state.importProgress,
      label: entry == null
          ? l10n.baiduNetdiskImporting
          : l10n.importingFileProgress(
              state.importingIndex <= 0 ? 1 : state.importingIndex,
              state.importTotal <= 0
                  ? state.selectedAudioEntries.length
                  : state.importTotal,
              entry.name,
            ),
    );
  }
}

Set<int> _matchedSubtitleFsIdsFor(BaiduNetdiskImportState state) {
  final audios = state.selectedAudioEntries;
  final subtitles = state.selectedSubtitleEntries;
  if (audios.isEmpty || subtitles.isEmpty) return const <int>{};
  final entriesByName = <String, CloudDriveEntry>{
    for (final entry in [...audios, ...subtitles]) entry.name: entry,
  };
  final pairing = matchSubtitlesForAudios(entriesByName.keys);
  return {
    for (final audio in audios)
      if (pairing[audio.name] != null) audio.fsId,
  };
}

class _BaiduImportingPanel extends StatelessWidget {
  const _BaiduImportingPanel({required this.state, required this.onCancel});

  final BaiduNetdiskImportState state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final entry = state.importingEntry;
    final l10n = AppLocalizations.of(context)!;
    final current = state.importingIndex <= 0 ? 1 : state.importingIndex;
    final total = state.importTotal <= 0 ? 1 : state.importTotal;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: state.importProgress < 0 ? null : state.importProgress,
        ),
        const SizedBox(height: 12),
        Text(
          entry == null
              ? l10n.baiduNetdiskImporting
              : l10n.importingFileProgress(current, total, entry.name),
        ),
        const SizedBox(height: AppSpacing.l),
        SizedBox(
          width: double.infinity,
          child: SecondaryActionButton(onPressed: onCancel, label: l10n.cancel),
        ),
      ],
    );
  }
}

class _ImportOptionTile extends StatelessWidget {
  const _ImportOptionTile({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.description,
    required this.onTap,
  }) : assert(icon != null || leading != null);

  final IconData? icon;

  /// 自定义入口图标。用于保留品牌 SVG 原始形态。
  final Widget? leading;
  final String title;

  /// 可选说明文案，为 null 时不显示说明行。
  final String? description;
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: leading ?? Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 10),
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
                    if (description != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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

/// 导入完成页：统一展示成功入库的音频与因内容重复被跳过的项。
///
/// 成功与跳过结果合并到同一页，替代原先独立的重复项提示弹窗。
class _CompletedPanel extends StatelessWidget {
  const _CompletedPanel({
    super.key,
    required this.outcome,
    required this.onDone,
  });

  final AudioImportOutcome outcome;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final added = outcome.added;
    final duplicates = outcome.duplicates;
    // 成功导入数（含 0）与其中带字幕的数量。
    final addedCount = added.length;
    final subtitleCount = added.where((a) => a.hasTranscript).length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 成功入库摘要（始终显示，哪怕 0 个）。
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle, color: colorScheme.primary, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.audioImportedCount(addedCount),
                    style: theme.textTheme.titleMedium,
                  ),
                  // 成功导入数不为 0 时，再显示其中多少个带字幕。
                  if (addedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        l10n.audioImportedWithSubtitleCount(subtitleCount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        // 跳过的重复项列表（有跳过项才显示）。
        if (duplicates.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.l),
          Row(
            children: [
              Icon(
                Icons.skip_next_rounded,
                color: colorScheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.duplicatesSkipped(duplicates.length),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.duplicatesSkippedDetail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(child: _DuplicatesList(duplicates: duplicates)),
        ],
        const SizedBox(height: AppSpacing.l),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: onDone, child: Text(l10n.done)),
        ),
      ],
    );
  }
}

/// 重复项限高滚动列表：单条为音频图标 + 导入名（+ 与哪个已有音频内容相同）。
class _DuplicatesList extends StatefulWidget {
  const _DuplicatesList({required this.duplicates});

  final List<AudioImportDuplicate> duplicates;

  @override
  State<_DuplicatesList> createState() => _DuplicatesListState();
}

class _DuplicatesListState extends State<_DuplicatesList> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _scrollController,
        child: ListView.separated(
          controller: _scrollController,
          primary: false,
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: widget.duplicates.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 1,
            indent: 44,
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          itemBuilder: (_, i) =>
              _buildRow(theme, context, widget.duplicates[i]),
        ),
      ),
    );
  }

  Widget _buildRow(
    ThemeData theme,
    BuildContext context,
    AudioImportDuplicate dup,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 与本地文件导入列表统一使用波形图标（非音乐图标）。
          Icon(Icons.graphic_eq, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dup.attempted,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // 仅当导入名与已有名不同时，标注与哪个已有音频内容相同。
                if (dup.existing != dup.attempted)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l10n.duplicateOfExisting(dup.existing),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.75,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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

String _parentPath(String path) {
  if (path == '/' || path.isEmpty) return '/';
  final trimmed = path.endsWith('/') && path.length > 1
      ? path.substring(0, path.length - 1)
      : path;
  final slash = trimmed.lastIndexOf('/');
  if (slash <= 0) return '/';
  return trimmed.substring(0, slash);
}

String _directoryName(AppLocalizations l10n, String path) {
  if (path == '/' || path.isEmpty) return l10n.baiduNetdiskAllFiles;
  return _lastPathSegment(path);
}

String _lastPathSegment(String path) {
  final trimmed = path.endsWith('/') && path.length > 1
      ? path.substring(0, path.length - 1)
      : path;
  final slash = trimmed.lastIndexOf('/');
  if (slash < 0 || slash == trimmed.length - 1) return trimmed;
  return trimmed.substring(slash + 1);
}

String _entryDisplayNameWithoutExtension(CloudDriveEntry entry) {
  final name = entry.name;
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return name;
  return name.substring(0, dot);
}

String? _entrySubtitle(CloudDriveEntry entry) {
  final parts = <String>[];
  final modifiedAt = entry.modifiedAt;
  if (modifiedAt != null) {
    parts.add(_formatDate(modifiedAt));
  }
  if (!entry.isDirectory) {
    parts.add(_formatBytes(entry.size));
  }
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

String _formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.year}/${local.month}/${local.day}';
}

bool _isImportableAudio(CloudDriveEntry entry) {
  return !entry.isDirectory && audioImportExtensions.contains(entry.extension);
}

bool _isImportableSubtitle(CloudDriveEntry entry) {
  return !entry.isDirectory &&
      subtitleImportExtensions.contains(entry.extension);
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  final digits = value >= 10 || unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}
