/// 录音权限入口前置阻塞弹窗。
///
/// 进入跟读类录音页面前，先确认麦克风（始终需要）和平台语音识别（仅当
/// 启用 ASR 且 backend == platform 时需要）权限就绪。权限不通过则阻塞进入。
///
/// 与本地 ASR 模型下载弹窗（`asr_download_prompt_dialog.dart`）解耦：
/// 本文件只管系统授权；模型下载在权限通过后由
/// [ensureAsrReadyBeforeSpeechPractice] 串接执行。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/enums.dart';
import '../l10n/app_localizations.dart';
import '../models/speech_practice_models.dart';
import '../providers/offline_asr_settings_provider.dart';
import '../services/app_logger.dart';
import '../services/speech_permission_service.dart';
import 'asr_download_prompt_dialog.dart';

/// 该 subStage 是否会进入需要录音的流程。
///
/// 与本地 ASR 模型的需求列表完全一致（复用 [requiresAsrBeforeEnteringSubStage]）。
bool requiresMicForSubStage(SubStageType subStage) =>
    requiresAsrBeforeEnteringSubStage(subStage);

/// 在进入语音练习前确认录音权限 + ASR 模型就绪。
///
/// 仅在目标 [subStage] 需要录音时执行检查；否则直接放行。
///
/// 返回：
/// - `true`：允许继续原本的进入动作
/// - `false`：用户取消 / 权限不通过，本次停留在当前页
Future<bool> ensureSpeechReadyForSubStage(
  BuildContext context,
  WidgetRef ref,
  SubStageType subStage,
) async {
  if (!requiresMicForSubStage(subStage)) return true;
  return ensureSpeechReadyForRecording(context, ref);
}

/// 调用方已确认会进入录音流程时使用的入口（如聚合页按钮）。
///
/// 顺序：平台支持检查 → 权限弹窗 → ASR 模型下载弹窗。
Future<bool> ensureSpeechReadyForRecording(
  BuildContext context,
  WidgetRef ref,
) async {
  AppLogger.log('SpeechPermGate', '┌ ensureSpeechReadyForRecording');
  final service = ref.read(speechPermissionServiceProvider);
  if (!service.isSupported) {
    AppLogger.log('SpeechPermGate', '└ unsupported platform → false');
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    if (messenger != null && l10n != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.speechPermUnsupportedToast)),
      );
    }
    return false;
  }

  final permOk = await _ensurePermissions(context, ref);
  if (!permOk || !context.mounted) {
    AppLogger.log(
      'SpeechPermGate',
      '└ permOk=$permOk mounted=${context.mounted} → false',
    );
    return false;
  }

  AppLogger.log('SpeechPermGate', '│ perm ok → check asr model');
  final asrOk = await ensureAsrReadyBeforeSpeechPractice(context, ref);
  AppLogger.log('SpeechPermGate', '└ asrOk=$asrOk');
  return asrOk;
}

/// 仅检查权限（mic + 可选 speech）。
Future<bool> _ensurePermissions(BuildContext context, WidgetRef ref) async {
  final needsSpeech = _needsPlatformSpeechPermission(ref);
  final service = ref.read(speechPermissionServiceProvider);
  AppLogger.log('SpeechPermGate', '│ needsSpeech=$needsSpeech');

  final SpeechPracticePermissionState initial;
  try {
    initial = await service.getStatus();
  } catch (e) {
    AppLogger.log('SpeechPermGate', '│ getStatus threw: $e → false');
    return false;
  }
  if (!context.mounted) return false;

  if (_isCovered(initial, needsSpeech: needsSpeech)) {
    AppLogger.log('SpeechPermGate', '│ already covered → true');
    return true;
  }

  AppLogger.log(
    'SpeechPermGate',
    '│ not covered (mic=${initial.microphone.name} speech=${initial.speech.name}) → show dialog',
  );
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PermissionGateDialog(
      initialStatus: initial,
      needsSpeech: needsSpeech,
    ),
  );
  AppLogger.log('SpeechPermGate', '│ dialog closed result=$result');
  return result ?? false;
}

/// 是否需要平台语音识别权限。
bool _needsPlatformSpeechPermission(WidgetRef ref) {
  final asrSettings = ref.read(offlineAsrSettingsProvider);
  return asrSettings.enabled && asrSettings.backend == AsrBackend.platform;
}

/// 当前权限是否已经覆盖所需项。
bool _isCovered(
  SpeechPracticePermissionState status, {
  required bool needsSpeech,
}) {
  final micOk = status.microphone == SpeechPracticePermissionStatus.granted;
  final speechOk =
      !needsSpeech || status.speech == SpeechPracticePermissionStatus.granted;
  return micOk && speechOk;
}

/// 计算当前应展示的弹窗模式。
_DialogMode _computeMode(
  SpeechPracticePermissionState status, {
  required bool needsSpeech,
}) {
  final micRestricted =
      status.microphone == SpeechPracticePermissionStatus.restricted;
  final speechRestricted =
      needsSpeech && status.speech == SpeechPracticePermissionStatus.restricted;
  if (micRestricted || speechRestricted) return _DialogMode.restricted;

  final micDenied = status.microphone == SpeechPracticePermissionStatus.denied;
  final speechDenied =
      needsSpeech && status.speech == SpeechPracticePermissionStatus.denied;
  if (micDenied || speechDenied) return _DialogMode.denied;

  return _DialogMode.request;
}

/// 弹窗模式。
enum _DialogMode {
  /// 首次或全部 notDetermined：可调起系统授权弹窗。
  request,

  /// 任一项已 denied：只能引导用户去系统设置。
  denied,

  /// 任一项 restricted（家长控制 / MDM）：仅展示提示，不可恢复。
  restricted,
}

/// 权限引导弹窗。
class _PermissionGateDialog extends ConsumerStatefulWidget {
  final SpeechPracticePermissionState initialStatus;
  final bool needsSpeech;

  const _PermissionGateDialog({
    required this.initialStatus,
    required this.needsSpeech,
  });

  @override
  ConsumerState<_PermissionGateDialog> createState() =>
      _PermissionGateDialogState();
}

class _PermissionGateDialogState extends ConsumerState<_PermissionGateDialog>
    with WidgetsBindingObserver {
  late SpeechPracticePermissionState _status;
  late _DialogMode _mode;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _status = widget.initialStatus;
    _mode = _computeMode(_status, needsSpeech: widget.needsSpeech);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 用户从系统设置回到 App 时自动重查。
    if (state == AppLifecycleState.resumed) {
      unawaited(_recheck());
    }
  }

  Future<void> _recheck() async {
    if (_busy) return;
    try {
      final next = await ref.read(speechPermissionServiceProvider).getStatus();
      if (!mounted) return;
      if (_isCovered(next, needsSpeech: widget.needsSpeech)) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _status = next;
        _mode = _computeMode(next, needsSpeech: widget.needsSpeech);
      });
    } catch (_) {
      // 查询失败保持当前状态，不破坏 UI。
    }
  }

  Future<void> _onGrant() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final after = await ref
          .read(speechPermissionServiceProvider)
          .request(onlyMic: !widget.needsSpeech);
      if (!mounted) return;
      if (_isCovered(after, needsSpeech: widget.needsSpeech)) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _status = after;
        // request 之后仍未通过：要么用户拒绝（denied），要么 restricted。
        _mode = _computeMode(after, needsSpeech: widget.needsSpeech);
      });
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onOpenSettings() async {
    if (_busy) return;
    await ref.read(speechPermissionServiceProvider).openAppSettings();
    // 不主动 pop；didChangeAppLifecycleState.resumed 回到 App 后自动重查。
  }

  void _onCancel() {
    if (_busy) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // 用 PopScope 拦住 Android 物理返回 / iOS 边缘滑动手势——
    // 否则系统手势会让 showDialog 返回 null，上层调用方误判为「用户取消」
    // 进而 pop 当前页面，体验突兀。用户必须显式点关闭按钮 / 主操作按钮才能离开。
    return PopScope(
      canPop: false,
      child: AlertDialog(
        titlePadding: EdgeInsets.zero,
        title: _DialogTitle(title: _titleFor(l10n), onClose: _onCancel),
        content: _buildBody(context, l10n),
        actions: _buildActions(l10n),
      ),
    );
  }

  String _titleFor(AppLocalizations l10n) {
    return switch (_mode) {
      _DialogMode.request => l10n.speechPermDialogTitleRequest,
      _DialogMode.denied => l10n.speechPermDialogTitleDenied,
      _DialogMode.restricted => l10n.speechPermDialogTitleRestricted,
    };
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PermissionItem(
          icon: Icons.mic_outlined,
          name: l10n.speechPermItemMic,
          desc: l10n.speechPermItemMicDesc,
          status: _status.microphone,
          theme: theme,
          l10n: l10n,
        ),
        if (widget.needsSpeech) ...[
          const SizedBox(height: 12),
          _PermissionItem(
            icon: Icons.record_voice_over_outlined,
            name: l10n.speechPermItemSpeech,
            desc: l10n.speechPermItemSpeechDesc,
            status: _status.speech,
            theme: theme,
            l10n: l10n,
          ),
        ],
        if (_mode == _DialogMode.denied) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.speechPermDeniedHint,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_mode == _DialogMode.restricted) ...[
          const SizedBox(height: 12),
          Text(
            l10n.speechPermRestrictedHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildActions(AppLocalizations l10n) {
    return switch (_mode) {
      _DialogMode.request => [
        FilledButton(
          onPressed: _busy ? null : _onGrant,
          child: Text(l10n.speechPermActionGrant),
        ),
      ],
      _DialogMode.denied => [
        FilledButton(
          onPressed: _busy ? null : _onOpenSettings,
          child: Text(l10n.speechPermActionOpenSettings),
        ),
      ],
      _DialogMode.restricted => const [],
    };
  }
}

/// 单项权限的展示 row。
class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String name;
  final String desc;
  final SpeechPracticePermissionStatus status;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _PermissionItem({
    required this.icon,
    required this.name,
    required this.desc,
    required this.status,
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(name, style: theme.textTheme.titleSmall),
                  const SizedBox(width: 8),
                  _StatusChip(status: status, theme: theme, l10n: l10n),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 状态徽标（待授权 / 已拒绝 / 受限）；已授权不展示。
class _StatusChip extends StatelessWidget {
  final SpeechPracticePermissionStatus status;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _StatusChip({
    required this.status,
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SpeechPracticePermissionStatus.granted => (null, null),
      SpeechPracticePermissionStatus.notDetermined => (
        l10n.speechPermStatusPending,
        theme.colorScheme.onSurfaceVariant,
      ),
      SpeechPracticePermissionStatus.denied => (
        l10n.speechPermStatusDenied,
        theme.colorScheme.error,
      ),
      SpeechPracticePermissionStatus.restricted => (
        l10n.speechPermStatusDenied,
        theme.colorScheme.error,
      ),
    };
    if (label == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color!.withValues(alpha: 0.6), width: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

/// 弹窗标题：标题 + 右上角关闭按钮（与 ASR 弹窗保持一致）。
class _DialogTitle extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _DialogTitle({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 48, 0),
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
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

