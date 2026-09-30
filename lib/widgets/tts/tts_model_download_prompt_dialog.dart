/// TTS 发音前的本地模型就绪门控。
///
/// 模型下载由设置页或本弹窗的显式按钮触发；用户点击发音时模型未就绪，本次发音
/// 不会在下载完成后自动继续。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/tts/kokoro_model_provider.dart';
import '../../providers/tts/piper_model_provider.dart';
import '../../providers/tts/tts_settings_provider.dart';
import '../../providers/tts/tts_model_installation_provider.dart';
import '../../router/app_router.dart';
import '../../services/app_logger.dart';
import '../../services/download/download_failure.dart';
import '../../services/tts/kokoro_model_catalog.dart';
import '../../services/tts/kokoro_model_manager.dart';
import '../../services/tts/piper_model_catalog.dart';
import '../../services/tts/tts_engine.dart';
import '../../utils/file_size.dart';
import '../../utils/download_failure_message.dart';

/// 当前 TTS 选中引擎所依赖的本地模型状态。
class TtsPlaybackModelState {
  final TtsEngineKind engine;
  final AsrModelDownloadStatus status;
  final double progress;
  final DownloadFailureKind? failure;
  final int estimatedDownloadBytes;

  const TtsPlaybackModelState({
    required this.engine,
    required this.status,
    required this.progress,
    required this.failure,
    required this.estimatedDownloadBytes,
  });

  bool get isReady =>
      engine == TtsEngineKind.platform ||
      status == AsrModelDownloadStatus.downloaded;
}

/// 从全局 TTS provider 派生当前发音所需模型的单一状态快照。
final ttsPlaybackModelStateProvider = Provider<TtsPlaybackModelState>((ref) {
  final settings = ref.watch(ttsSettingsProvider);
  switch (settings.engine) {
    case TtsEngineKind.platform:
      return const TtsPlaybackModelState(
        engine: TtsEngineKind.platform,
        status: AsrModelDownloadStatus.downloaded,
        progress: 1,
        failure: null,
        estimatedDownloadBytes: 0,
      );
    case TtsEngineKind.kokoro:
      final state = ref.watch(kokoroModelProvider).of(settings.kokoroVariant);
      return TtsPlaybackModelState(
        engine: settings.engine,
        status: state.downloadStatus,
        progress: state.downloadProgress,
        failure: state.downloadError,
        estimatedDownloadBytes: kokoroSpecOf(
          settings.kokoroVariant,
        ).estimatedDownloadBytes,
      );
    case TtsEngineKind.piper:
      final state = ref.watch(piperModelProvider).of(settings.activePiperVoice);
      return TtsPlaybackModelState(
        engine: settings.engine,
        status: state.downloadStatus,
        progress: state.downloadProgress,
        failure: state.downloadError,
        estimatedDownloadBytes:
            piperVoiceById(settings.activePiperVoice)?.estimatedDownloadBytes ??
            0,
      );
  }
});

/// 发音前检查当前本地 TTS 模型。
///
/// 返回 true 才允许本次发音；下载中、未下载或失败均只展示全局状态弹窗，返回 false。
Future<bool> ensureTtsModelReadyForPlayback(Ref ref) async {
  await ref
      .read(ttsModelInstallationGateProvider)
      .ensureInstallationStatesLoaded();
  final state = ref.read(ttsPlaybackModelStateProvider);
  if (state.isReady) return true;

  final context = rootNavigatorKey.currentContext;
  if (context == null || !context.mounted) return false;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const TtsModelDownloadDialog(),
  );
  return false;
}

/// [ensureTtsModelReadyForPlayback] 的 WidgetRef 版本，供页面直接调用。
Future<bool> ensureTtsModelReadyForPlaybackFromWidget(WidgetRef ref) async {
  await ref
      .read(ttsModelInstallationGateProvider)
      .ensureInstallationStatesLoaded();
  final state = ref.read(ttsPlaybackModelStateProvider);
  if (state.isReady) return true;

  final context = rootNavigatorKey.currentContext;
  if (context == null || !context.mounted) return false;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const TtsModelDownloadDialog(),
  );
  return false;
}

/// 只检查指定 TTS 配置是否可用，不弹窗、不下载，供后台 warmup 使用。
Future<bool> isTtsModelReadyForConfig(
  Ref ref, {
  required TtsEngineKind engine,
  KokoroModelVariant? kokoroVariant,
  String? piperVoiceId,
}) async {
  if (engine == TtsEngineKind.platform) return true;
  await ref
      .read(ttsModelInstallationGateProvider)
      .ensureInstallationStatesLoaded();
  final ready = switch (engine) {
    TtsEngineKind.platform => true,
    TtsEngineKind.kokoro =>
      kokoroVariant != null &&
          ref.read(kokoroModelProvider).of(kokoroVariant).isReady,
    TtsEngineKind.piper =>
      piperVoiceId != null &&
          ref.read(piperModelProvider).of(piperVoiceId).isReady,
  };
  AppLogger.log(
    'TtsModelGate',
    '后台配置检查 engine=${engine.diagnosticName} '
        'kokoroVariant=${kokoroVariant?.name} piperVoice=$piperVoiceId ready=$ready',
  );
  return ready;
}

/// 检查指定 TTS 配置所依赖的本地模型，并在缺失时触发下载。
///
/// 只负责模型状态与下载，不弹窗；设置页试听使用此函数，让下载进度继续由
/// 设置页列表展示。普通文本播放若需要弹窗，仍使用 [ensureTtsModelReadyForPlayback]。
Future<bool> ensureTtsModelReadyForConfig(
  Ref ref, {
  required TtsEngineKind engine,
  KokoroModelVariant? kokoroVariant,
  String? piperVoiceId,
}) async {
  AppLogger.log(
    'TtsModelGate',
    '指定配置检查开始 engine=${engine.diagnosticName} '
        'kokoroVariant=${kokoroVariant?.name} piperVoice=$piperVoiceId',
  );
  // 已有内存 ready 状态时同步放行，避免正常试听因重新扫描安装标记产生可见延迟。
  switch (engine) {
    case TtsEngineKind.platform:
      AppLogger.log('TtsModelGate', '指定配置检查结果 ready=true engine=platform');
      return true;
    case TtsEngineKind.kokoro:
      final variant = kokoroVariant;
      if (variant != null &&
          ref.read(kokoroModelProvider).of(variant).isReady) {
        AppLogger.log(
          'TtsModelGate',
          '指定配置检查结果 ready=true source=memory variant=${variant.name}',
        );
        return true;
      }
    case TtsEngineKind.piper:
      final voiceId = piperVoiceId;
      if (voiceId != null && ref.read(piperModelProvider).of(voiceId).isReady) {
        AppLogger.log(
          'TtsModelGate',
          '指定配置检查结果 ready=true source=memory voice=$voiceId',
        );
        return true;
      }
  }
  await ref
      .read(ttsModelInstallationGateProvider)
      .ensureInstallationStatesLoaded();
  switch (engine) {
    case TtsEngineKind.platform:
      AppLogger.log('TtsModelGate', '指定配置刷新后结果 ready=true engine=platform');
      return true;
    case TtsEngineKind.kokoro:
      final variant = kokoroVariant;
      if (variant == null) return false;
      final state = ref.read(kokoroModelProvider).of(variant);
      AppLogger.log(
        'TtsModelGate',
        '指定配置刷新后状态 variant=${variant.name} status=${state.downloadStatus}',
      );
      if (state.isReady) return true;
      if (state.downloadStatus == AsrModelDownloadStatus.notDownloaded) {
        unawaited(
          ref.read(kokoroModelProvider.notifier).ensureDownloaded(variant),
        );
      }
      return false;
    case TtsEngineKind.piper:
      final voiceId = piperVoiceId;
      if (voiceId == null) return false;
      final state = ref.read(piperModelProvider).of(voiceId);
      AppLogger.log(
        'TtsModelGate',
        '指定配置刷新后状态 voice=$voiceId status=${state.downloadStatus}',
      );
      if (state.isReady) return true;
      if (state.downloadStatus == AsrModelDownloadStatus.notDownloaded) {
        unawaited(
          ref.read(piperModelProvider.notifier).ensureDownloaded(voiceId),
        );
      }
      return false;
  }
}

class TtsModelDownloadDialog extends ConsumerWidget {
  const TtsModelDownloadDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(ttsSettingsProvider);
    final model = switch (settings.engine) {
      TtsEngineKind.platform => const TtsPlaybackModelState(
        engine: TtsEngineKind.platform,
        status: AsrModelDownloadStatus.downloaded,
        progress: 1,
        failure: null,
        estimatedDownloadBytes: 0,
      ),
      TtsEngineKind.kokoro => _kokoroState(ref, settings),
      TtsEngineKind.piper => _piperState(ref, settings),
    };

    if (model.isReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
    }
    final failed = model.status == AsrModelDownloadStatus.failed;
    final notDownloaded = model.status == AsrModelDownloadStatus.notDownloaded;
    final downloading = model.status == AsrModelDownloadStatus.downloading;
    final progress = '${(model.progress * 100).toStringAsFixed(0)}%';
    final size = formatBytes(model.estimatedDownloadBytes);
    final title = switch (model.status) {
      AsrModelDownloadStatus.notDownloaded =>
        l10n.ttsModelDownloadRequiredTitle,
      AsrModelDownloadStatus.downloading => l10n.ttsModelDownloadingTitle,
      AsrModelDownloadStatus.failed => l10n.ttsModelDownloadFailedTitle,
      AsrModelDownloadStatus.downloaded => l10n.ttsModel,
    };
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notDownloaded)
            _DownloadMessage(
              children: [
                Text(l10n.ttsModelDownloadIntro),
                Text(l10n.ttsModelDownloadEstimate(size)),
                Text(l10n.ttsModelDownloadSettingsHint),
              ],
            ),
          if (downloading) ...[
            _DownloadMessage(
              children: [Text(l10n.ttsModelDownloadingMessage(size))],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: model.progress),
            const SizedBox(height: 8),
            Text(
              l10n.ttsModelDownloadProgress(progress),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (failed) ...[
            const SizedBox(height: 8),
            _DownloadMessage(
              children: [
                Text(l10n.ttsModelDownloadFailedMessage(size)),
                Text(l10n.ttsModelDownloadSettingsHint),
              ],
            ),
            if (model.failure != null) ...[
              const SizedBox(height: 8),
              Text(
                downloadFailureMessage(l10n, model.failure),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ],
      ),
      actions: downloading
          ? [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // 先关闭弹窗，避免取消下载触发状态刷新时短暂显示“下载模型”按钮。
                  unawaited(_cancelDownload(ref, settings.engine));
                },
                child: Text(l10n.downloadCancel),
              ),
            ]
          : failed
          ? [
              FilledButton(
                onPressed: () => _retryDownload(ref, settings.engine),
                child: Text(l10n.retryDownload),
              ),
            ]
          : model.status == AsrModelDownloadStatus.notDownloaded
          ? [
              FilledButton(
                onPressed: () => _startDownload(ref, settings.engine),
                child: Text(l10n.ttsDownloadModel),
              ),
            ]
          : const [],
    );
  }

  TtsPlaybackModelState _kokoroState(WidgetRef ref, TtsSettings settings) {
    final state = ref.watch(kokoroModelProvider).of(settings.kokoroVariant);
    return TtsPlaybackModelState(
      engine: settings.engine,
      status: state.downloadStatus,
      progress: state.downloadProgress,
      failure: state.downloadError,
      estimatedDownloadBytes: kokoroSpecOf(
        settings.kokoroVariant,
      ).estimatedDownloadBytes,
    );
  }

  TtsPlaybackModelState _piperState(WidgetRef ref, TtsSettings settings) {
    final state = ref.watch(piperModelProvider).of(settings.activePiperVoice);
    return TtsPlaybackModelState(
      engine: settings.engine,
      status: state.downloadStatus,
      progress: state.downloadProgress,
      failure: state.downloadError,
      estimatedDownloadBytes:
          piperVoiceById(settings.activePiperVoice)?.estimatedDownloadBytes ??
          0,
    );
  }

  void _retryDownload(WidgetRef ref, TtsEngineKind engine) {
    final settings = ref.read(ttsSettingsProvider);
    switch (engine) {
      case TtsEngineKind.platform:
        return;
      case TtsEngineKind.kokoro:
        ref
            .read(kokoroModelProvider.notifier)
            .retryDownload(settings.kokoroVariant);
      case TtsEngineKind.piper:
        ref
            .read(piperModelProvider.notifier)
            .retryDownload(settings.activePiperVoice);
    }
  }

  void _startDownload(WidgetRef ref, TtsEngineKind engine) {
    final settings = ref.read(ttsSettingsProvider);
    switch (engine) {
      case TtsEngineKind.platform:
        return;
      case TtsEngineKind.kokoro:
        ref
            .read(kokoroModelProvider.notifier)
            .ensureDownloaded(settings.kokoroVariant);
      case TtsEngineKind.piper:
        ref
            .read(piperModelProvider.notifier)
            .ensureDownloaded(settings.activePiperVoice);
    }
  }

  Future<void> _cancelDownload(WidgetRef ref, TtsEngineKind engine) async {
    final settings = ref.read(ttsSettingsProvider);
    switch (engine) {
      case TtsEngineKind.platform:
        return;
      case TtsEngineKind.kokoro:
        await ref
            .read(kokoroModelProvider.notifier)
            .cancelDownload(settings.kokoroVariant);
      case TtsEngineKind.piper:
        await ref
            .read(piperModelProvider.notifier)
            .cancelDownload(settings.activePiperVoice);
    }
  }
}

/// 将下载说明拆成有间距的段落，避免英文长句在弹窗中连续挤压换行。
class _DownloadMessage extends StatelessWidget {
  const _DownloadMessage({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          DefaultTextStyle.merge(style: style, child: children[index]),
        ],
      ],
    );
  }
}
