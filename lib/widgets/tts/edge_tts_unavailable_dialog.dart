/// Edge 在线 TTS 不可用提示弹窗。
///
/// Edge 为默认引擎但依赖非公开端点与网络：用户主动发音失败时提示原因，并引导到
/// 语音合成设置页改用本地/系统引擎。不自动切换引擎（尊重用户选择）。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../router/app_router.dart';
import '../../screens/tts_settings_screen.dart';
import '../../services/app_logger.dart';
import '../../services/tts/edge_tts_engine.dart';

/// 在根 Navigator 上弹出 Edge 不可用提示（不等待关闭）。
///
/// [showSettingsAction] 为 false 时不显示「去设置」（如已在语音合成设置页内试听）。
void showEdgeTtsUnavailableDialog(
  EdgeTtsFailureKind failure, {
  required bool showSettingsAction,
}) {
  final context = rootNavigatorKey.currentContext;
  if (context == null || !context.mounted) {
    AppLogger.log('EdgeTts', '提示弹窗跳过：根 Navigator 不可用');
    return;
  }
  AppLogger.log(
    'EdgeTts',
    '弹出不可用提示：类型=${failure.name} 显示去设置=$showSettingsAction',
  );
  showDialog<void>(
    context: context,
    builder: (_) => EdgeTtsUnavailableDialog(
      failure: failure,
      showSettingsAction: showSettingsAction,
    ),
  );
}

class EdgeTtsUnavailableDialog extends StatelessWidget {
  const EdgeTtsUnavailableDialog({
    super.key,
    required this.failure,
    required this.showSettingsAction,
  });

  final EdgeTtsFailureKind failure;
  final bool showSettingsAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = switch (failure) {
      EdgeTtsFailureKind.network => l10n.edgeTtsUnavailableNetworkMessage,
      EdgeTtsFailureKind.service => l10n.edgeTtsUnavailableServiceMessage,
    };
    return AlertDialog(
      title: Text(l10n.edgeTtsUnavailableTitle),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.edgeTtsUnavailableDismiss),
        ),
        if (showSettingsAction)
          FilledButton(
            onPressed: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) => const TtsSettingsScreen(),
                ),
              );
            },
            child: Text(l10n.edgeTtsUnavailableOpenSettings),
          ),
      ],
    );
  }
}
