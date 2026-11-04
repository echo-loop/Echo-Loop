import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../features/audio_import/audio_import_models.dart';
import '../features/audio_import/audio_import_provider.dart';
import '../features/audio_import/subtitle_pairing.dart';
import '../features/baidu_netdisk/models/cloud_drive_models.dart';
import '../features/baidu_netdisk/models/baidu_account_profile.dart';
import '../features/baidu_netdisk/providers/baidu_netdisk_import_controller.dart';
import '../features/baidu_netdisk/providers/baidu_netdisk_import_tasks_provider.dart';
import '../features/baidu_netdisk/providers/baidu_netdisk_providers.dart';
import '../features/remote_config/remote_config.dart';
import '../features/remote_config/remote_config_providers.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'add_audio_dialog.dart';
import 'common/form_input_style.dart';
import 'common/secondary_action_button.dart';
import 'media_type_icon.dart';

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
  bool _localImporting = false;

  @override
  void initState() {
    super.initState();
    // 对勾只在本次导入弹窗内有效：每次打开时清除上一次会话的成功标记。
    Future<void>.microtask(() {
      if (!mounted) return;
      ref.read(baiduNetdiskImportTasksProvider.notifier).clearAddedTasks();
    });
  }

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
    final baiduTasks = ref.watch(baiduNetdiskImportTasksProvider);
    final unavailableFsIds = _unavailableBaiduFsIds(baiduTasks);
    final cloudDriveImportEnabled = ref.watch(
      remoteFeatureEnabledProvider(RemoteFeature.cloudDriveImport),
    );
    final busy = _isBusy(state) || baiduState.isBusy || _localImporting;
    final importing = _isBusy(state) || _localImporting;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !importing,
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
                  showClose: !importing,
                  titleSmall: _step == _ImportStep.baiduNetdisk,
                  onBack: _goBack,
                  trailing: _baiduHeaderTrailing(
                    l10n: l10n,
                    state: baiduState,
                    busy: busy,
                    unavailableFsIds: unavailableFsIds,
                    onToggleSelectAll: () => baiduController.toggleSelectAll(
                      unavailableFsIds: unavailableFsIds,
                    ),
                  ),
                  onClose: () => Navigator.pop(context),
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
    required Set<int> unavailableFsIds,
    required VoidCallback onToggleSelectAll,
  }) {
    if (_step != _ImportStep.baiduNetdisk) return null;
    if (state.selectedFsIds.isNotEmpty) {
      return _HeaderTextButton(
        label: state.isAllSelectableSelected(unavailableFsIds: unavailableFsIds)
            ? l10n.baiduNetdiskClearSelectionAction
            : l10n.baiduNetdiskSelectAllAction,
        onPressed: busy ? null : onToggleSelectAll,
      );
    }
    final canLogout = switch (state.phase) {
      BaiduNetdiskImportPhase.ready || BaiduNetdiskImportPhase.failed => true,
      BaiduNetdiskImportPhase.idle ||
      BaiduNetdiskImportPhase.authorizationRequired ||
      BaiduNetdiskImportPhase.authorizing ||
      BaiduNetdiskImportPhase.loading => false,
    };
    if (!canLogout) return null;
    return _BaiduAvatarButton(
      profile: state.accountProfile,
      loading: state.accountProfileLoading,
      onPressed: busy ? null : _showBaiduAccountDialog,
    );
  }

  Future<void> _showBaiduAccountDialog() async {
    final state = ref.read(baiduNetdiskImportControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _BaiduAccountDialog(
        profile: state.accountProfile,
        loading: state.accountProfileLoading,
        onDisconnect: () async {
          final activeCount = ref
              .read(baiduNetdiskImportTasksProvider)
              .values
              .where((task) => task.isActive)
              .length;
          if (activeCount > 0) {
            final confirmed = await _confirmCancelActiveImports(
              dialogContext,
              l10n,
              activeCount,
            );
            if (!confirmed || !dialogContext.mounted) return;
          }
          ref.read(baiduNetdiskImportTasksProvider.notifier).cancelAll();
          await ref.read(baiduCredentialRepositoryProvider).disconnect();
          if (!dialogContext.mounted) return;
          Navigator.pop(dialogContext);
          if (mounted) Navigator.pop(context);
        },
        l10n: l10n,
      ),
    );
  }

  /// 断开连接会取消进行中的导入，先让用户确认，避免误丢下载。
  Future<bool> _confirmCancelActiveImports(
    BuildContext context,
    AppLocalizations l10n,
    int activeCount,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.baiduDisconnectActiveTitle),
        content: Text(l10n.baiduDisconnectActiveMessage(activeCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.baiduNetdiskDisconnect),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  String _titleFor(AppLocalizations l10n, BaiduNetdiskImportState baiduState) {
    return switch (_step) {
      _ImportStep.chooseSource => l10n.importAudio,
      _ImportStep.localFile => l10n.importAudioFromFile,
      _ImportStep.directUrl => l10n.importAudioFromUrl,
      _ImportStep.cloudDrive => l10n.importAudioFromCloudDrive,
      _ImportStep.baiduNetdisk => _directoryName(l10n, baiduState.currentPath),
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
          onImportingChanged: (isImporting) {
            if (_localImporting == isImporting || !mounted) return;
            setState(() => _localImporting = isImporting);
          },
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
    });
  }

  void _goBackToCloudDriveSources() {
    ref.read(baiduNetdiskImportControllerProvider.notifier).reset();
    setState(() {
      _step = _ImportStep.cloudDrive;
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
      _goBackFromBaiduNetdisk();
      return;
    }
    _goBackToSource();
  }

  /// 切到独立完成页。
  ///
  /// 只服务链接导入：它一次只导一个文件、没有列表可展示结果。本地文件与网盘导入
  /// 都把成功/跳过状态就地渲染在各自的已选列表里，不经过这里。
  void _handleImported(AudioImportOutcome outcome) {
    // 无任何结果（既没成功也没跳过）时不前进，停留原页供用户重选。
    if (outcome.added.isEmpty && outcome.duplicates.isEmpty) return;
    setState(() {
      _outcome = outcome;
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
    _handleImported((added: [item], duplicates: const []));
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
    this.showClose = true,
    this.titleSmall = false,
    this.trailing,
    required this.onBack,
    required this.onClose,
  });

  final String title;
  final bool showBack;
  final bool showClose;
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
                child: !showBack && !showClose
                    ? const SizedBox(width: 40, height: 40)
                    : showBack
                    ? IconButton(
                        onPressed: onBack,
                        tooltip: MaterialLocalizations.of(context)
                            .backButtonTooltip,
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
                        tooltip: MaterialLocalizations.of(context)
                            .closeButtonTooltip,
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
        fixedSize: const Size(30, 30),
        minimumSize: const Size(30, 30),
        maximumSize: const Size(30, 30),
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

class _BaiduAvatarButton extends StatelessWidget {
  const _BaiduAvatarButton({
    this.profile,
    required this.loading,
    this.onPressed,
  });

  final BaiduAccountProfile? profile;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('baidu-account-button'),
      tooltip: AppLocalizations.of(context)!.baiduNetdiskAccountTooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
        maximumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: _BaiduAvatar(
        profile: profile,
        loading: loading,
        diameter: 40,
        avatarKey: const ValueKey('baidu-header-avatar'),
      ),
    );
  }
}

/// 以固定正方形边界裁切百度账户头像，防止图片被拉伸为椭圆。
class _BaiduAvatar extends StatelessWidget {
  const _BaiduAvatar({
    required this.profile,
    required this.loading,
    required this.diameter,
    this.avatarKey,
  });

  final BaiduAccountProfile? profile;
  final bool loading;
  final double diameter;
  final Key? avatarKey;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl;
    return SizedBox.square(
      key: avatarKey,
      dimension: diameter,
      child: ClipOval(
        child: avatarUrl == null
            ? const ColoredBox(
                color: Colors.transparent,
                child: Icon(Icons.account_circle_outlined),
              )
            : Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.account_circle_outlined),
                loadingBuilder: loading
                    ? (_, _, _) => const Icon(Icons.account_circle_outlined)
                    : null,
              ),
      ),
    );
  }
}

class _BaiduAccountDialog extends StatelessWidget {
  const _BaiduAccountDialog({
    required this.profile,
    required this.loading,
    required this.onDisconnect,
    required this.l10n,
  });

  final BaiduAccountProfile? profile;
  final bool loading;
  final VoidCallback? onDisconnect;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = profile;
    return AlertDialog(
      title: Text(l10n.baiduNetdiskAccountTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BaiduAvatar(
              profile: value,
              loading: loading,
              diameter: 72,
              avatarKey: const ValueKey('baidu-dialog-avatar'),
            ),
            const SizedBox(height: AppSpacing.m),
            _accountRow(
              context,
              l10n.baiduNetdiskUsername,
              value?.baiduName ?? l10n.baiduNetdiskUnavailable,
            ),
            if (value?.netdiskName case final netdiskName?
                when netdiskName.trim().isNotEmpty)
              _accountRow(context, l10n.baiduNetdiskNetdiskName, netdiskName),
            _accountRow(
              context,
              l10n.baiduNetdiskMembership,
              value?.membershipLabel ?? l10n.baiduNetdiskUnavailable,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onDisconnect,
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          child: Text(l10n.baiduNetdiskDisconnect),
        ),
      ],
    );
  }

  Widget _accountRow(BuildContext context, String label, String value) {
    final style = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: style.bodySmall)),
          Expanded(child: Text(value, textAlign: TextAlign.end)),
        ],
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
    required this.onBack,
  });

  final String? collectionId;
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
    final tasks = ref.watch(baiduNetdiskImportTasksProvider);
    final tasksController = ref.read(baiduNetdiskImportTasksProvider.notifier);
    final importedFsIds = ref.watch(baiduImportedFsIdsProvider);
    final nativelyQueuedFsIds = ref.watch(baiduNativelyQueuedFsIdsProvider);
    final importedCollectionNames = ref.watch(
      baiduImportedCollectionNamesProvider,
    );
    final plan = planBaiduImport(
      selectedAudios: state.selectedAudioEntries,
      selectedSubtitles: state.selectedSubtitleEntries,
      importedAudios: [
        for (final entry in state.entries)
          if (_isImportableAudio(entry) && importedFsIds.contains(entry.fsId))
            entry,
      ],
    );
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: state.isBusy
          ? null
          : (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity > 300) widget.onBack();
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
                BaiduNetdiskImportPhase.ready => _BaiduFileBrowser(
                  state: state,
                  plan: plan,
                  importedCollectionNames: importedCollectionNames,
                  tasks: tasks,
                  importedFsIds: importedFsIds,
                  nativelyQueuedFsIds: nativelyQueuedFsIds,
                  onOpenDirectory: controller.loadDirectory,
                  onToggle: controller.toggleEntry,
                  onImport: () {
                    controller.clearSelection();
                    tasksController.enqueue(
                      audioEntries: plan.audioEntries,
                      subtitleEntries: plan.subtitleEntries,
                      collectionId: widget.collectionId,
                    );
                  },
                  onCancelTask: tasksController.cancel,
                  onRetryTask: tasksController.retry,
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
    required this.plan,
    required this.importedCollectionNames,
    required this.tasks,
    required this.importedFsIds,
    required this.nativelyQueuedFsIds,
    required this.onOpenDirectory,
    required this.onToggle,
    required this.onImport,
    required this.onCancelTask,
    required this.onRetryTask,
  });

  final BaiduNetdiskImportState state;
  final BaiduImportPlan plan;
  final Map<int, List<String>> importedCollectionNames;
  final Map<int, BaiduImportTask> tasks;
  final Set<int> importedFsIds;

  /// 已提交原生队列但尚未开始下载的音频 fs_id，目录行据此显示"排队中"。
  final Set<int> nativelyQueuedFsIds;
  final ValueChanged<String> onOpenDirectory;
  final ValueChanged<CloudDriveEntry> onToggle;
  final VoidCallback onImport;
  final ValueChanged<int> onCancelTask;
  final ValueChanged<int> onRetryTask;

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
    final plan = widget.plan;
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
                final task = _taskCarrying(entry, widget.tasks);
                final status = _rowStatusFor(
                  task,
                  isImported: widget.importedFsIds.contains(entry.fsId),
                  isNativelyQueued:
                      task != null &&
                      widget.nativelyQueuedFsIds.contains(task.audioEntry.fsId),
                );
                // 已勾选却没有匹配到同名音频（本次选中或已导入）的字幕，需要提示用户。
                final isUnmatchedSubtitle = plan.unmatchedSubtitleFsIds
                    .contains(entry.fsId);
                return _BaiduFileTile(
                  entry: entry,
                  selected: widget.state.selectedFsIds.contains(entry.fsId),
                  status: status,
                  task: task,
                  unmatchedSubtitle: isUnmatchedSubtitle,
                  collectionNames:
                      widget.importedCollectionNames[entry.fsId] ?? const [],
                  onOpenDirectory: widget.onOpenDirectory,
                  onToggle: widget.onToggle,
                  onCancel: task == null || !task.isActive
                      ? null
                      : () => widget.onCancelTask(task.audioEntry.fsId),
                  onRetry: task == null
                      ? null
                      : () => widget.onRetryTask(task.audioEntry.fsId),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: plan.audioEntries.isEmpty ? null : widget.onImport,
            child: Text(
              plan.audioEntries.isEmpty
                  ? l10n.importAudioShort
                  : l10n.importAudioAndSubtitleCount(
                      plan.audioEntries.length,
                      plan.subtitleByAudio.length,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 目录行的导入展示状态，由下载任务与音频库派生。
enum _BaiduRowStatus {
  pending,
  queued,
  downloading,

  /// 资源库中已有该素材（副标题显示"已导入"，仍可勾选）。
  added,

  /// 本次导入弹窗内成功导入（额外显示对勾）。
  addedThisSession,
  duplicate,
  failed,
}

_BaiduRowStatus _rowStatusFor(
  BaiduImportTask? task, {
  required bool isImported,
  required bool isNativelyQueued,
}) {
  if (task != null) {
    return switch (task.status) {
      BaiduImportTaskStatus.queued => _BaiduRowStatus.queued,
      BaiduImportTaskStatus.downloading when isNativelyQueued =>
        _BaiduRowStatus.queued,
      BaiduImportTaskStatus.downloading => _BaiduRowStatus.downloading,
      BaiduImportTaskStatus.added => _BaiduRowStatus.addedThisSession,
      BaiduImportTaskStatus.duplicate => _BaiduRowStatus.duplicate,
      BaiduImportTaskStatus.failed => _BaiduRowStatus.failed,
    };
  }
  return isImported ? _BaiduRowStatus.added : _BaiduRowStatus.pending;
}

/// 返回承载该条目的任务：音频取自身任务，字幕取其配对音频的任务。
BaiduImportTask? _taskCarrying(
  CloudDriveEntry entry,
  Map<int, BaiduImportTask> tasks,
) {
  final own = tasks[entry.fsId];
  if (own != null) return own;
  for (final task in tasks.values) {
    if (task.subtitleEntry?.fsId == entry.fsId) return task;
  }
  return null;
}

/// 下载中的行在副标题末尾追加当前速度；速度未知时保持原副标题。
String? _withSpeed(String? subtitle, double? bytesPerSecond) {
  if (bytesPerSecond == null) return subtitle;
  final speedText = '${_formatBytes(bytesPerSecond.round())}/s';
  return subtitle == null ? speedText : '$subtitle · $speedText';
}

/// 不可再勾选的百度条目：下载任务中的音频及其字幕，以及本次会话已成功导入的条目。
///
/// 资源库中之前导入的素材不计入此处，仍可勾选。
Set<int> _unavailableBaiduFsIds(Map<int, BaiduImportTask> tasks) {
  return {
    for (final task in tasks.values) ...[
      task.audioEntry.fsId,
      ?task.subtitleEntry?.fsId,
    ],
  };
}

class _BaiduFileTile extends StatelessWidget {
  const _BaiduFileTile({
    required this.entry,
    required this.selected,
    required this.status,
    required this.task,
    required this.unmatchedSubtitle,
    required this.collectionNames,
    required this.onOpenDirectory,
    required this.onToggle,
    required this.onCancel,
    required this.onRetry,
  });

  final CloudDriveEntry entry;
  final bool selected;
  final _BaiduRowStatus status;
  final BaiduImportTask? task;

  /// 已勾选但没有匹配到同名音频的字幕，副标题下方会显示提示。
  final bool unmatchedSubtitle;

  /// 已导入素材所在的合集名称；仅在资源库中时为空列表。
  final List<String> collectionNames;
  final ValueChanged<String> onOpenDirectory;
  final ValueChanged<CloudDriveEntry> onToggle;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAudio = _isImportableAudio(entry);
    final isSubtitle = _isImportableSubtitle(entry);
    final isSelectableFile = isAudio || isSubtitle;
    final isUnsupportedFile = !entry.isDirectory && !isSelectableFile;
    // 已导入的素材仍可勾选，用于加入其他合集或补挂字幕。
    // 本次会话已导入的不可再选；资源库中之前导入的仍可选（加入其他合集或补挂字幕）。
    final isSelectable =
        status == _BaiduRowStatus.pending || status == _BaiduRowStatus.added;
    final isAdded =
        status == _BaiduRowStatus.added ||
        status == _BaiduRowStatus.addedThisSession;
    final isFailed = status == _BaiduRowStatus.failed;
    final speed = status == _BaiduRowStatus.downloading
        ? task?.speedBytesPerSecond
        : null;
    final baseSubtitle = _entrySubtitle(entry);
    final subtitleText = isFailed
        ? l10n.baiduNetdiskImportFailed
        : _withSpeed(baseSubtitle, speed);
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
      subtitle: subtitleText == null && !unmatchedSubtitle && !isAdded
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subtitleText != null)
                  Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isFailed
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant.withValues(
                              alpha: isUnsupportedFile ? 0.44 : 0.64,
                            ),
                    ),
                  ),
                if (isAdded)
                  Text(
                    collectionNames.isEmpty
                        ? l10n.baiduImportedToLibrary
                        : l10n.baiduImportedToCollections(
                            collectionNames.join('、'),
                          ),
                    key: const Key('baidu_import_added_label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.successColor,
                    ),
                  ),
                if (unmatchedSubtitle)
                  Text(
                    l10n.baiduSubtitleUnmatched,
                    key: const Key('baidu_subtitle_unmatched_label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
              ],
            ),
      trailing: entry.isDirectory
          ? const Icon(Icons.chevron_right)
          : isSelectableFile
          ? _statusTrailing(l10n, theme)
          : null,
      onTap: entry.isDirectory
          ? () => onOpenDirectory(entry.path)
          : isSelectableFile && isSelectable
          ? () => onToggle(entry)
          : null,
    );
  }

  Widget _statusTrailing(AppLocalizations l10n, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return switch (status) {
      _BaiduRowStatus.pending ||
      _BaiduRowStatus.added => _selectionCheckbox(colorScheme),
      // 本次导入会话中已成功导入的文件不可再选，只显示对勾。
      // 与 Checkbox 使用相同的 48 点击区域并居中，保证同一列图标水平对齐。
      _BaiduRowStatus.addedThisSession => SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Icon(Icons.check_circle, size: 18, color: colorScheme.primary),
        ),
      ),
      _BaiduRowStatus.queued => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.audioQueued, style: theme.textTheme.bodySmall),
          _cancelButton(l10n),
        ],
      ),
      _BaiduRowStatus.downloading => _downloadingTrailing(l10n, theme),
      _BaiduRowStatus.duplicate => Text(
        l10n.baiduImportDuplicate,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      _BaiduRowStatus.failed => IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: l10n.retry,
        onPressed: onRetry,
      ),
    };
  }

  /// 下载中：进度圈 + 百分比（总量未知时只显示不定进度）+ 取消。
  Widget _downloadingTrailing(AppLocalizations l10n, ThemeData theme) {
    final progress = task?.progress;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(value: progress, strokeWidth: 2.5),
        ),
        if (progress != null) ...[
          const SizedBox(width: 6),
          Text(
            '${(progress * 100).round()}%',
            style: theme.textTheme.bodySmall,
          ),
        ],
        _cancelButton(l10n),
      ],
    );
  }

  Widget _selectionCheckbox(ColorScheme colorScheme) {
    return Checkbox(
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
    );
  }

  /// 文字按钮：目录行里的 X 图标含义不直观，尤其在触屏设备上没有悬停提示。
  Widget _cancelButton(AppLocalizations l10n) {
    return TextButton(
      onPressed: onCancel,
      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      child: Text(l10n.cancel),
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
        if (busy)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.onCancelBusy,
              child: Text(l10n.cancelImport),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: SecondaryActionButton(
                  onPressed: widget.onBackIdle,
                  label: l10n.back,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: widget.controller.text.trim().isEmpty
                      ? null
                      : widget.onSubmit,
                  child: Text(l10n.downloadAndImportAudio),
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
          MediaTypeIcon(
            isVideo: isVideoImportExtension(dup.attempted),
            size: 18,
            color: colorScheme.primary,
          ),
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
  return !entry.isDirectory &&
      isImportablePrimaryMediaExtension(entry.extension);
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
