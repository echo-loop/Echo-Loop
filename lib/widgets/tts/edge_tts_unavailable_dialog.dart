/// Edge 在线 TTS 不可用提示弹窗。
///
/// Edge 为默认引擎但依赖非公开端点与网络：用户主动发音失败时仅提示原因，
/// 不引导切换引擎，也不自动切换（尊重用户选择）。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../router/app_router.dart';
import '../../services/app_logger.dart';
import '../../services/tts/edge_tts_engine.dart';

/// 在根 Navigator 上弹出 Edge 不可用提示（不等待关闭）。
///
/// 点击弹窗外任意位置即可关闭，与「知道了」等效。
void showEdgeTtsUnavailableDialog(EdgeTtsFailureKind failure) {
  final context = rootNavigatorKey.currentContext;
  if (context == null || !context.mounted) {
    AppLogger.log('EdgeTts', '提示弹窗跳过：根 Navigator 不可用');
    return;
  }
  AppLogger.log('EdgeTts', '弹出不可用提示：类型=${failure.name}');
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => EdgeTtsUnavailableDialog(failure: failure),
  );
}

class EdgeTtsUnavailableDialog extends StatelessWidget {
  const EdgeTtsUnavailableDialog({super.key, required this.failure});

  final EdgeTtsFailureKind failure;

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
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.edgeTtsUnavailableDismiss),
        ),
      ],
    );
  }
}
