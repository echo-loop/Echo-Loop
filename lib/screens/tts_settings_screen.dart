/// 语音合成（TTS）设置页。
///
/// 合成引擎（平台 TTS / Echo Loop）+ 口音（美音 / 英音）；选中 Echo Loop 时在
/// 「Echo Loop TTS」归属标题下用一张卡集中显示其专属子设置（模型下载状态 + 音色）。
/// 音色按业界惯例收成单行（当前值 + 展开），点开用底部弹层选择，避免多音色平铺撑长
/// 页面。切换立即生效（写 SP → 协调器热重配）。
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/tts/kokoro_model_provider.dart';
import '../providers/tts/piper_model_provider.dart';
import '../providers/tts/tts_controller_provider.dart';
import '../providers/tts/tts_model_installation_provider.dart';
import '../providers/tts/tts_settings_provider.dart';
import '../services/tts/kokoro_model_manager.dart'
    show AsrModelDownloadStatus, KokoroModelVariant;
import '../services/tts/kokoro_voices.dart';
import '../services/tts/piper_model_catalog.dart';
import '../services/tts/tts_engine.dart';
import '../theme/app_theme.dart';
import '../utils/download_failure_message.dart';
import '../widgets/common/prewarm_visibility.dart';

/// 语音合成设置页。
class TtsSettingsScreen extends ConsumerStatefulWidget {
  const TtsSettingsScreen({super.key});

  @override
  ConsumerState<TtsSettingsScreen> createState() => _TtsSettingsScreenState();
}

/// Android 固定使用本地 TTS，设置页不提供系统语音入口。
bool showPlatformTtsEngine(bool isAndroid) => !isAndroid;

class _TtsSettingsScreenState extends ConsumerState<TtsSettingsScreen> {
  /// 缓存的 TTS 控制器（供 dispose 时取消预热——dispose 中不可用 ref）。
  TtsController? _controller;

  /// initState 注册的预热触发订阅（就绪翻转 / 变体切换），dispose 时关闭。
  /// 用 listenManual 而非 build 内 ref.listen：注册即生效、不受 build 时序影响，
  /// 可靠捕获「模型下载完成后就绪翻转」这次关键事件（见 PLAN 根因分析）。
  final List<ProviderSubscription<Object?>> _prewarmSubs = [];
  bool _isPrewarmVisible = false;
  int _prewarmVisibilityEpoch = 0;

  @override
  void initState() {
    super.initState();
    // 模型变就绪（下载完成后翻转 false→true）→ 预热各音色。注册即生效，不依赖
    // 首帧后 postFrame 的一次性时机（那次常读到 ready=false 而提前返回）。
    _prewarmSubs.add(
      ref.listenManual<bool>(kokoroReadyProvider, (_, isReady) {
        if (isReady && _isPrewarmVisible) {
          ref.read(ttsControllerProvider.notifier).prewarmVoicePreviews();
        }
      }),
    );
    // 切换变体（fp32↔int8，缓存键随 modelTag 变）→ 按新签名重新预热各音色。
    _prewarmSubs.add(
      ref.listenManual<KokoroModelVariant>(
        ttsSettingsProvider.select((s) => s.kokoroVariant),
        (_, __) {
          if (_isPrewarmVisible) {
            unawaited(
              ref.read(ttsControllerProvider.notifier).prewarmVoicePreviews(),
            );
          }
        },
      ),
    );
    // Piper 当前音色就绪（下载完成翻转 false→true）→ 预热该音色试听。同 Kokoro，
    // 覆盖「首帧 postFrame 时模型尚未就绪、提前返回」的关键事件。
    _prewarmSubs.add(
      ref.listenManual<bool>(piperReadyProvider, (_, isReady) {
        if (isReady && _isPrewarmVisible) {
          ref.read(ttsControllerProvider.notifier).prewarmActivePiperVoice();
        }
      }),
    );
  }

  /// 页面每次重新可见都重新检查安装状态并启动对应预热批次。
  void _onPrewarmVisibilityChanged(bool visible) {
    _isPrewarmVisible = visible;
    final epoch = ++_prewarmVisibilityEpoch;
    if (!visible) {
      _controller?.cancelVoicePreviewPrewarm();
      unawaited(_controller?.stop() ?? Future<void>.value());
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isPrewarmVisible || epoch != _prewarmVisibilityEpoch) {
        return;
      }
      unawaited(_startPrewarm(epoch));
    });
  }

  Future<void> _startPrewarm(int epoch) async {
    final controller = ref.read(ttsControllerProvider.notifier);
    _controller = controller;
    await ref
        .read(ttsModelInstallationGateProvider)
        .ensureInstallationStatesLoaded();
    if (!mounted || !_isPrewarmVisible || epoch != _prewarmVisibilityEpoch) {
      return;
    }
    final settings = ref.read(ttsSettingsProvider);
    unawaited(controller.warmUpCurrentEngine());
    if (settings.engine == TtsEngineKind.kokoro) {
      unawaited(controller.prewarmVoicePreviews());
    } else if (settings.engine == TtsEngineKind.piper) {
      unawaited(controller.prewarmActivePiperVoice());
    } else {
      unawaited(controller.prewarmAccentPreviews());
    }
  }

  @override
  void dispose() {
    // 离开页面：关闭预热触发订阅，并停止在途试听预热（旧批次下轮即放弃）。
    // dispose 中不可用 ref，故用 build 时缓存的 notifier 引用（仅自增 token，安全）。
    for (final sub in _prewarmSubs) {
      sub.close();
    }
    _controller?.cancelVoicePreviewPrewarm();
    // 返回上一页即停止正在试听的发音（预热缓存保留，不影响下次进页秒播）。
    _controller?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = ref.watch(ttsSettingsProvider);
    final isEchoLoop = settings.engine == TtsEngineKind.kokoro;
    final isPiper = settings.engine == TtsEngineKind.piper;
    final showPlatformEngine = showPlatformTtsEngine(Platform.isAndroid);
    // 任一已下载模型（Advanced/Kokoro 变体 或 Balanced/Piper 音色）即提供管理入口
    //（删除回收空间），不限当前引擎。
    final models = ref.watch(kokoroModelProvider);
    final piperModels = ref.watch(piperModelProvider);
    final anyDownloaded =
        KokoroModelVariant.values.any((v) => models.of(v).isReady) ||
        piperVoices.any((v) => piperModels.of(v.id).isReady);
    final ready = ref.watch(kokoroReadyProvider);
    // 缓存 notifier 引用供 dispose 取消预热（dispose 中不可用 ref）。
    // 预热触发（就绪翻转 / 变体切换）已移至 initState 的 listenManual。
    _controller = ref.read(ttsControllerProvider.notifier);

    return PrewarmVisibility(
      mainTabIndex: 3,
      onChanged: _onPrewarmVisibilityChanged,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.ttsSettings)),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.m),
          children: [
            // 说明文字
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s,
                0,
                AppSpacing.s,
                AppSpacing.m,
              ),
              child: Text(
                l10n.ttsSettingsDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            // 合成引擎
            _SectionLabel(text: l10n.ttsEngine),
            Card(
              child: RadioGroup<TtsEngineKind>(
                groupValue: settings.engine,
                onChanged: _onEngineChanged,
                child: Column(
                  children: [
                    if (showPlatformEngine) ...[
                      RadioListTile<TtsEngineKind>(
                        title: Text(platformSpeechEngineName(l10n)),
                        subtitle: Text(
                          l10n.ttsEnginePlatformDescription,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        value: TtsEngineKind.platform,
                        selected: settings.engine == TtsEngineKind.platform,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                    RadioListTile<TtsEngineKind>(
                      title: Text(l10n.ttsEnginePiper),
                      subtitle: Text(
                        l10n.ttsEnginePiperDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      value: TtsEngineKind.piper,
                      selected: settings.engine == TtsEngineKind.piper,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    RadioListTile<TtsEngineKind>(
                      title: Text(l10n.ttsEngineEchoLoop),
                      subtitle: Text(
                        l10n.ttsEngineEchoLoopDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      value: TtsEngineKind.kokoro,
                      selected: settings.engine == TtsEngineKind.kokoro,
                    ),
                  ],
                ),
              ),
            ),

            if (isEchoLoop) ...[
              // Echo Loop（自然/Kokoro）专属：归属标题 + 一张卡（模型 + 音色单行）。
              // 不显示独立口音——音色名已自带口音，选音色即定口音（见 _VoiceDisclosure）。
              const SizedBox(height: AppSpacing.m),
              _SectionLabel(text: l10n.ttsEngineEchoLoop),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _ModelPicker(l10n: l10n, theme: theme),
                    if (ready) ...[
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _VoiceDisclosure(l10n: l10n),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _SpeedSetting(l10n: l10n),
                    ],
                  ],
                ),
              ),
            ] else if (isPiper) ...[
              // Piper（平衡）专属：归属标题 + 音色列表（每音色一个独立模型，
              // 行内显示各自下载状态，点击就绪音色即试听、点未下载音色即下载）。
              const SizedBox(height: AppSpacing.m),
              _SectionLabel(text: l10n.ttsEnginePiper),
              Card(
                clipBehavior: Clip.antiAlias,
                child: _PiperVoiceList(l10n: l10n),
              ),
              const SizedBox(height: AppSpacing.m),
              _SectionLabel(text: l10n.ttsSpeed),
              Card(child: _SpeedSetting(l10n: l10n)),
            ] else ...[
              // 平台 TTS：无具名音色，仅显示口音（美/英，决定系统音色语言）。
              // 点击口音即选中并试听该口音（进页已后台预热，多数秒播）。
              const SizedBox(height: AppSpacing.m),
              // 提示弱化显示在「口音」分组标题后：部分机型/系统语音不区分美/英音。
              _SectionLabel(text: l10n.ttsAccent, hint: l10n.ttsAccentHint),
              Card(
                child: Column(
                  children: [
                    _AccentPreviewRow(accent: TtsAccent.us, l10n: l10n),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _AccentPreviewRow(accent: TtsAccent.uk, l10n: l10n),
                  ],
                ),
              ),

              // 本地仍有残留模型（非当前引擎、未在使用）：收成一行存储清理入口，
              // 不再平铺两张模型卡（避免在「平台 TTS」下误读为可选设置）。
              if (anyDownloaded) ...[
                const SizedBox(height: AppSpacing.m),
                _ModelStorageRow(l10n: l10n),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _onEngineChanged(TtsEngineKind? value) {
    if (value == null) return;
    // 切换引擎先停掉正在试听的旧引擎发音（如 Apple 语音→Echo Loop），避免旧例子
    // 继续播到尾。
    ref.read(ttsControllerProvider.notifier).stop();
    ref.read(ttsSettingsProvider.notifier).setEngine(value);
    if (value == TtsEngineKind.kokoro) {
      final variant = ref.read(ttsSettingsProvider).kokoroVariant;
      ref.read(kokoroModelProvider.notifier).ensureDownloaded(variant);
      // 切到 Echo Loop：立即预热各音色（与平台分支对称）。模型已就绪则即时开跑；
      // 未就绪则此调用在 ready 门控提前返回，待下载完成 kokoroReady 翻转由
      // initState 的 listenManual 补触发——两条路径都覆盖，不留「已下载却不预热」空档。
      ref.read(ttsControllerProvider.notifier).prewarmVoicePreviews();
    } else if (value == TtsEngineKind.piper) {
      // 切到 Piper：确保当前口音选中的音色已下载，并预热该音色试听（仅当前音色——
      // 换音色需重载模型，批量不经济；其余音色走点击 on-demand）。模型未就绪时此调用
      // 在门控提前返回，待下载完成 piperReady 翻转由 initState 的 listenManual 补触发。
      final voiceId = ref.read(ttsSettingsProvider).activePiperVoice;
      ref.read(piperModelProvider.notifier).ensureDownloaded(voiceId);
      ref.read(ttsControllerProvider.notifier).prewarmActivePiperVoice();
    } else {
      // 切回平台 TTS：后台预热两个口音试听片段（模型仍在本地则由下方常驻
      //「删除模型」入口回收，不再弹窗）。
      ref.read(ttsControllerProvider.notifier).prewarmAccentPreviews();
    }
  }
}

/// Echo Loop 模型选择列表：列出 fp32（高质量·推荐）/ int8（轻量）两个变体。
///
/// 内嵌于 Echo Loop 归属卡（不包 Card）。每个变体可单选切换为「使用中」，点未下载变体
/// 即下载并启用；非使用中的已下载变体可删除（正在用的不可删，对齐 ASR 约定）。
class _ModelPicker extends ConsumerWidget {
  const _ModelPicker({required this.l10n, required this.theme});

  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(ttsSettingsProvider).kokoroVariant;
    final models = ref.watch(kokoroModelProvider);

    final rows = <Widget>[];
    for (var i = 0; i < KokoroModelVariant.values.length; i++) {
      final variant = KokoroModelVariant.values[i];
      if (i > 0) {
        rows.add(const Divider(height: 1, indent: 16, endIndent: 16));
      }
      rows.add(
        _ModelRow(
          l10n: l10n,
          theme: theme,
          variant: variant,
          state: models.of(variant),
          isActive: variant == active,
        ),
      );
    }
    return Column(children: rows);
  }
}

/// 单个模型变体行：标题 + 描述 + 状态，尾部按状态显示下载进度/取消/重试/删除。
class _ModelRow extends ConsumerWidget {
  const _ModelRow({
    required this.l10n,
    required this.theme,
    required this.variant,
    required this.state,
    required this.isActive,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final KokoroModelVariant variant;
  final KokoroModelState state;
  final bool isActive;

  bool get _isFp32 => variant == KokoroModelVariant.fp32;

  String get _name => _isFp32 ? l10n.ttsModelHighQuality : l10n.ttsModelLite;

  String get _description => _isFp32
      ? l10n.ttsModelHighQualityDescription
      : l10n.ttsModelLiteDescription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(kokoroModelProvider.notifier);

    // 标题：名称 +（fp32）推荐徽标。
    final title = Row(
      children: [
        Flexible(child: Text(_name)),
        if (_isFp32) ...[
          const SizedBox(width: 8),
          _RecommendedBadge(text: l10n.ttsModelRecommended, theme: theme),
        ],
      ],
    );

    return ListTile(
      leading: Radio<KokoroModelVariant>(
        value: variant,
        // ignore: deprecated_member_use
        groupValue: ref.watch(ttsSettingsProvider).kokoroVariant,
        // ignore: deprecated_member_use
        onChanged: (_) => _select(ref),
      ),
      title: title,
      subtitle: _subtitle(),
      trailing: _trailing(context, ref, notifier),
      onTap: () => _select(ref),
    );
  }

  /// 切换为使用中变体并确保其已下载。
  void _select(WidgetRef ref) {
    ref.read(ttsSettingsProvider.notifier).setKokoroVariant(variant);
    ref.read(kokoroModelProvider.notifier).ensureDownloaded(variant);
  }

  /// 描述 + 动态状态行。
  Widget _subtitle() {
    final children = <Widget>[
      // 描述用与引擎卡 subtitle 一致的弱化色（次要色 + alpha 0.6），不喧宾夺主。
      Text(
        _description,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    ];
    if (state.isDownloading) {
      final pct = '${(state.downloadProgress * 100).toStringAsFixed(0)}%';
      children.add(const SizedBox(height: 6));
      children.add(LinearProgressIndicator(value: state.downloadProgress));
      children.add(const SizedBox(height: 2));
      children.add(
        Text(
          l10n.speechModelDownloading(pct),
          style: theme.textTheme.bodySmall,
        ),
      );
    } else if (state.downloadStatus == AsrModelDownloadStatus.failed) {
      children.add(
        Text(
          downloadFailureMessage(l10n, state.downloadError),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      );
    } else if (state.isReady) {
      children.add(
        Text(
          l10n.speechModelReady(
            state.localSizeBytes > 0
                ? formatModelBytes(state.localSizeBytes)
                : '—',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.successColor,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// 尾部操作：下载中→取消；失败→重试；已下载且非使用中→删除；否则无。
  Widget? _trailing(
    BuildContext context,
    WidgetRef ref,
    KokoroModelNotifier notifier,
  ) {
    if (state.isDownloading && !isActive) {
      return TextButton(
        onPressed: () => notifier.cancelDownload(variant),
        child: Text(l10n.ttsCancelDownload),
      );
    }
    if (state.downloadStatus == AsrModelDownloadStatus.failed) {
      return TextButton(
        onPressed: () => notifier.retryDownload(variant),
        child: Text(l10n.retryDownload),
      );
    }
    // 正在使用的变体不显删除（不删正在用的语音）；其余已下载变体可删除回收。
    if (state.isReady && !isActive) {
      return IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.ttsDeleteModel,
        onPressed: () => _confirmDelete(context, ref),
      );
    }
    return null;
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.ttsDeleteModelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(kokoroModelProvider.notifier).deleteModel(variant);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.ttsDeleteModel),
          ),
        ],
      ),
    );
  }
}

/// 残留模型存储清理行（平台 TTS 引擎下，本地仍有已下载但未在使用的模型）。
///
/// 把可能存在的全部残留模型——Advanced/Kokoro 两个变体 + Balanced/Piper 各音色——收成
/// **一行**存储入口：标题 + 总占用空间 + 删除，而不是平铺多张模型卡，避免在「平台 TTS」
/// 下被误读为可选设置。删除清空全部已下载模型（切回对应引擎会按需重新下载）。
class _ModelStorageRow extends ConsumerWidget {
  const _ModelStorageRow({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final models = ref.watch(kokoroModelProvider);
    final piperModels = ref.watch(piperModelProvider);
    final kokoroDownloaded = KokoroModelVariant.values
        .where((v) => models.of(v).isReady)
        .toList();
    final piperDownloaded = piperVoices
        .where((v) => piperModels.of(v.id).isReady)
        .toList();
    final totalBytes =
        kokoroDownloaded.fold<int>(
          0,
          (sum, v) => sum + models.of(v).localSizeBytes,
        ) +
        piperDownloaded.fold<int>(
          0,
          (sum, v) => sum + piperModels.of(v.id).localSizeBytes,
        );

    return Card(
      child: ListTile(
        leading: Icon(
          Icons.sd_storage_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(l10n.ttsDownloadedModelsTitle),
        subtitle: Text(
          l10n.ttsDownloadedModelsDesc(formatModelBytes(totalBytes)),
          style: theme.textTheme.bodySmall,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: l10n.ttsDeleteModel,
          onPressed: () => _confirmDeleteAll(
            context,
            ref,
            kokoroDownloaded,
            piperDownloaded,
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAll(
    BuildContext context,
    WidgetRef ref,
    List<KokoroModelVariant> kokoroDownloaded,
    List<PiperVoice> piperDownloaded,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.ttsDeleteModelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final kokoroNotifier = ref.read(kokoroModelProvider.notifier);
              for (final v in kokoroDownloaded) {
                kokoroNotifier.deleteModel(v);
              }
              final piperNotifier = ref.read(piperModelProvider.notifier);
              for (final v in piperDownloaded) {
                piperNotifier.deleteModel(v.id);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.ttsDeleteModel),
          ),
        ],
      ),
    );
  }
}

/// 「推荐」小徽标。
class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 平台语音引擎的显示名：避免「平台 TTS」这类术语。
///
/// Apple 平台（iOS/macOS）的系统 TTS 唯一且确定，显「Apple 语音」；Android 系统默认 TTS
/// 引擎不固定（Google / 三星 / 厂商自带），不声称具体厂商，统一显「系统语音」。
String platformSpeechEngineName(AppLocalizations l10n) {
  if (Platform.isIOS || Platform.isMacOS) return l10n.ttsEnginePlatformApple;
  return l10n.ttsEnginePlatform;
}

/// 人类可读的模型体积（B / KB / MB）。
String formatModelBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
}

/// 音色「当前值 + 展开」单行：标题 + 当前音色（名称 · 性别）+ 雪佛龙；点开底部弹层选。
///
/// 弹层按「美音 / 英音」分组列出 v1.1 的全部英文音色。音色名自带口音，选中某音色即同时把
/// 全局口音设为该音色的口音（见 [_openSheet]），故 Echo Loop 下无需单独的口音控件。
class _VoiceDisclosure extends ConsumerWidget {
  const _VoiceDisclosure({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(ttsSettingsProvider);
    final current =
        voiceById(settings.activeKokoroVoice) ?? defaultVoice(settings.accent);
    final gender = current.isFemale ? l10n.ttsVoiceFemale : l10n.ttsVoiceMale;
    // 音色名不含口音信息，单独标出（美/英），便于一眼分辨。
    final accent = current.accent == TtsAccent.uk
        ? l10n.ttsAccentUk
        : l10n.ttsAccentUs;

    return ListTile(
      title: Text(l10n.ttsVoice),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$accent · ${current.displayName} · $gender',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
      onTap: () => _openSheet(context, ref),
    );
  }

  /// 弹出底部音色选择器（全部英文音色，按口音分组）。点任一行即提交选中并试听该音色，
  /// 弹层**不关闭**——便于连续试听、重点当前项重播。用户手动下滑/返回关闭。
  void _openSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _voiceGroup(theme, l10n.ttsAccentUs, TtsAccent.us),
                _voiceGroup(theme, l10n.ttsAccentUk, TtsAccent.uk),
                const SizedBox(height: AppSpacing.s),
              ],
            ),
          ),
        );
      },
    ).whenComplete(
      // 关闭弹层即停止正在试听的音色（预热缓存保留，不影响下次秒播）。
      () => ref.read(ttsControllerProvider.notifier).stop(),
    );
  }

  /// 一个口音分组：小标题 + 该口音下的音色行。
  Widget _voiceGroup(ThemeData theme, String label, TtsAccent accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // 与列表行 contentPadding 左右对齐（均为 AppSpacing.m）。
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.m,
            AppSpacing.m,
            AppSpacing.xs,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
        for (final v in voicesForAccent(accent))
          _VoicePreviewRow(voice: v, l10n: l10n),
      ],
    );
  }
}

/// 本地神经 TTS 语速设置。
class _SpeedSetting extends ConsumerWidget {
  const _SpeedSetting({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(ttsSettingsProvider.select((s) => s.speed));
    return ListTile(
      title: Row(
        children: [
          Expanded(child: Text(l10n.ttsSpeed)),
          Text('${speed.toStringAsFixed(1)}x'),
        ],
      ),
      subtitle: Slider(
        value: speed,
        min: 0.5,
        max: 2.0,
        divisions: 15,
        label: '${speed.toStringAsFixed(1)}x',
        onChanged: (value) =>
            ref.read(ttsSettingsProvider.notifier).setSpeed(value),
      ),
    );
  }
}

/// 音色弹层内的单行：单选指示 + 名称 + 性别，点击即选中并试听该音色。
///
/// 自管理响应式状态：选中态读 [ttsSettingsProvider]（点击实时更新），播放态读
/// [ttsControllerProvider]（试听该音色时显播放图标）。点击始终触发，故当前选中项
/// 再次点击也会重播（不同于 RadioGroup 选中项点击不回调）。
class _VoicePreviewRow extends ConsumerWidget {
  const _VoicePreviewRow({required this.voice, required this.l10n});

  final KokoroVoice voice;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedId = ref.watch(
      ttsSettingsProvider.select((s) => s.activeKokoroVoice),
    );
    final isPlaying =
        ref.watch(ttsControllerProvider.select((s) => s.speakingKey)) ==
        ttsVoicePreviewKey(voice.id);

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      leading: Radio<String>(
        value: voice.id,
        // ignore: deprecated_member_use
        groupValue: selectedId,
        // ignore: deprecated_member_use
        onChanged: (_) => _onTap(ref),
      ),
      title: Text(
        voice.displayName,
        style: theme.textTheme.titleSmall,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 试听播放中显喇叭图标（品牌色）；空闲不占位。
          if (isPlaying) ...[
            Icon(Icons.volume_up, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
          ],
          // 性别：国际通用 粉=女 / 蓝=男，弱化为标签权重。
          Text(
            voice.isFemale ? l10n.ttsVoiceFemale : l10n.ttsVoiceMale,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: voice.isFemale
                  ? AppTheme.femaleVoiceColor
                  : AppTheme.maleVoiceColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      onTap: () => _onTap(ref),
    );
  }

  /// 点击：提交选中（口音 + 音色）并试听该音色。不关闭弹层。
  void _onTap(WidgetRef ref) {
    final notifier = ref.read(ttsSettingsProvider.notifier);
    // 音色自带口音：先对齐全局口音，再写入该口音下的音色。
    notifier.setAccent(voice.accent);
    notifier.setKokoroVoice(voice.accent, voice.id);
    ref.read(ttsControllerProvider.notifier).previewVoice(voice);
  }
}

/// 平台 TTS 口音行：单选指示 + 名称（美音 / 英音），点击即选中该口音并试听。
///
/// 自管理响应式状态：选中态读 [ttsSettingsProvider]（点击实时更新），播放态读
/// [ttsControllerProvider]（试听该口音时显播放图标）。点击始终触发，故当前选中口音
/// 再次点击也会重播（不同于 RadioGroup 选中项点击不回调）。
class _AccentPreviewRow extends ConsumerWidget {
  const _AccentPreviewRow({required this.accent, required this.l10n});

  final TtsAccent accent;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selected = ref.watch(ttsSettingsProvider.select((s) => s.accent));
    final isPlaying =
        ref.watch(ttsControllerProvider.select((s) => s.speakingKey)) ==
        ttsAccentPreviewKey(accent);
    final name = accent == TtsAccent.uk ? l10n.ttsAccentUk : l10n.ttsAccentUs;

    return ListTile(
      leading: Radio<TtsAccent>(
        value: accent,
        // ignore: deprecated_member_use
        groupValue: selected,
        // ignore: deprecated_member_use
        onChanged: (_) => _onTap(ref),
      ),
      title: Text(name),
      // 试听播放中显喇叭图标（品牌色）；空闲不占位。
      trailing: isPlaying
          ? Icon(Icons.volume_up, size: 18, color: theme.colorScheme.primary)
          : null,
      onTap: () => _onTap(ref),
    );
  }

  /// 点击：选中该口音并试听。
  void _onTap(WidgetRef ref) {
    ref.read(ttsSettingsProvider.notifier).setAccent(accent);
    ref.read(ttsControllerProvider.notifier).previewAccent(accent);
  }
}

/// Piper（平衡档）音色列表：按「美音 / 英音」分组列出全部 9 个音色。
///
/// 与 Kokoro 不同，Piper 每音色是独立模型，故行内直接呈现各音色的下载状态与操作
/// （不收进底部弹层）：点击就绪音色 = 选中 + 试听；点未下载音色 = 选中 + 下载。
class _PiperVoiceList extends ConsumerWidget {
  const _PiperVoiceList({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rows = <Widget>[];

    void addGroup(String label, TtsAccent accent) {
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.m,
            AppSpacing.m,
            AppSpacing.xs,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
      );
      for (final v in piperVoicesByAccent(accent)) {
        rows.add(_PiperVoiceRow(voice: v, l10n: l10n));
      }
    }

    addGroup(l10n.ttsAccentUs, TtsAccent.us);
    addGroup(l10n.ttsAccentUk, TtsAccent.uk);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// Piper 音色行的名称列固定宽度（容纳最长名 `Kristin`，使各行性别列对齐）。
const double _kNameColumnWidth = 76;

/// Piper 音色行的性别列固定宽度（容纳 `Female`，使各行状态列对齐）。
const double _kGenderColumnWidth = 44;

/// Piper 单个音色行：单选指示 + 名称/性别 + 该音色独立模型的下载状态/操作。
///
/// 点击：选中（口音 + 音色）并——就绪则试听该音色；未下载则触发下载；失败则重试。
/// 尾部按状态显示 下载中→取消 / 失败→重试 / 已下载且非当前→删除 / 试听中→喇叭。
class _PiperVoiceRow extends ConsumerWidget {
  const _PiperVoiceRow({required this.voice, required this.l10n});

  final PiperVoice voice;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedId = ref.watch(
      ttsSettingsProvider.select((s) => s.activePiperVoice),
    );
    final accent = ref.watch(ttsSettingsProvider.select((s) => s.accent));
    final state = ref.watch(piperModelProvider.select((s) => s.of(voice.id)));
    final isPlaying =
        ref.watch(ttsControllerProvider.select((s) => s.speakingKey)) ==
        ttsVoicePreviewKey(voice.id);
    // 「当前使用中」：该音色被选中且其口音正是全局口音（同 Kokoro，正在用的不可删）。
    final isActive = selectedId == voice.id && accent == voice.accent;

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      leading: Radio<String>(
        value: voice.id,
        // ignore: deprecated_member_use
        groupValue: isActive ? voice.id : selectedId,
        // ignore: deprecated_member_use
        onChanged: (_) => _onTap(ref),
      ),
      // 单行布局：名称 · 性别 · 状态三列。名称/性别用固定列宽，使各行性别、状态
      // 纵向对齐（名称长短不一，不定宽会导致每行起始位置参差）。
      title: Row(
        children: [
          SizedBox(
            width: _kNameColumnWidth,
            child: Text(
              voice.displayName,
              style: theme.textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _kGenderColumnWidth,
            child: Text(
              voice.isFemale ? l10n.ttsVoiceFemale : l10n.ttsVoiceMale,
              style: theme.textTheme.bodySmall?.copyWith(
                color: voice.isFemale
                    ? AppTheme.femaleVoiceColor
                    : AppTheme.maleVoiceColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _statusText(theme, state)),
        ],
      ),
      trailing: _trailing(context, ref, theme, state, isPlaying, isActive),
      onTap: () => _onTap(ref),
    );
  }

  /// 单行内联状态文本：下载中→百分比；失败→简短错误；就绪→体积；否则→未下载。
  Widget _statusText(ThemeData theme, PiperModelState state) {
    String text;
    Color? color;
    if (state.isDownloading) {
      final pct = '${(state.downloadProgress * 100).toStringAsFixed(0)}%';
      text = l10n.speechModelDownloading(pct);
      color = theme.colorScheme.onSurfaceVariant;
    } else if (state.downloadStatus == AsrModelDownloadStatus.failed) {
      text = downloadFailureMessage(l10n, state.downloadError);
      color = theme.colorScheme.error;
    } else if (state.isReady) {
      text = l10n.speechModelReady(
        state.localSizeBytes > 0 ? formatModelBytes(state.localSizeBytes) : '—',
      );
      color = AppTheme.successColor;
    } else {
      text = l10n.ttsModelNotDownloaded;
      color = theme.colorScheme.onSurfaceVariant;
    }
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(color: color),
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 尾部操作（图标按钮，保持单行高度）：试听中→喇叭；下载中→进度+取消；
  /// 失败→重试；未下载→下载；就绪且非当前→删除；就绪且当前→无（选中态已由单选指示）。
  Widget? _trailing(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    PiperModelState state,
    bool isPlaying,
    bool isActive,
  ) {
    if (isPlaying) {
      // 套 48×48 居中盒，与下方 IconButton（删除/重试等）的图标中心对齐，
      // 否则裸 Icon 贴右边会比其他行的删除图标更靠右。
      return SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Icon(
            Icons.volume_up,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }
    final notifier = ref.read(piperModelProvider.notifier);
    if (state.isDownloading) {
      if (isActive) {
        // 当前音色不可取消，但仍保留 Piper 专属的圆形进度反馈。
        return SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: state.downloadProgress > 0
                    ? state.downloadProgress
                    : null,
              ),
            ),
          ),
        );
      }
      // 进度环 + 取消，二者并排仍是单行高度。
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: state.downloadProgress > 0 ? state.downloadProgress : null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            iconSize: 20,
            tooltip: l10n.ttsCancelDownload,
            onPressed: () => notifier.cancelDownload(voice.id),
          ),
        ],
      );
    }
    if (state.downloadStatus == AsrModelDownloadStatus.failed) {
      return IconButton(
        icon: const Icon(Icons.refresh),
        iconSize: 20,
        color: theme.colorScheme.primary,
        tooltip: l10n.retryDownload,
        onPressed: () => notifier.retryDownload(voice.id),
      );
    }
    if (state.isReady) {
      if (isActive) return null;
      return IconButton(
        icon: const Icon(Icons.delete_outline_rounded),
        iconSize: 20,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
        tooltip: l10n.ttsDeleteModel,
        onPressed: () => _confirmDelete(context, ref),
      );
    }
    // 未下载：下载图标（点行亦可下载，图标提供明确入口）。
    return IconButton(
      icon: const Icon(Icons.download_rounded),
      iconSize: 22,
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
      tooltip: l10n.ttsModelNotDownloaded,
      onPressed: () => _onTap(ref),
    );
  }

  /// 点击：选中（口音 + 音色），并按状态触发试听 / 下载 / 重试。
  void _onTap(WidgetRef ref) {
    final settingsNotifier = ref.read(ttsSettingsProvider.notifier);
    settingsNotifier.setAccent(voice.accent);
    settingsNotifier.setPiperVoice(voice.accent, voice.id);
    final st = ref.read(piperModelProvider).of(voice.id);
    final notifier = ref.read(piperModelProvider.notifier);
    if (!st.isReady) {
      // 点击未下载音色会切换当前配置并启动下载；先停止旧音色试听，避免下载期间继续播放旧音频。
      unawaited(ref.read(ttsControllerProvider.notifier).stop());
    }
    if (st.isReady) {
      ref.read(ttsControllerProvider.notifier).previewPiperVoice(voice);
    } else if (st.downloadStatus == AsrModelDownloadStatus.failed) {
      notifier.retryDownload(voice.id);
    } else if (!st.isDownloading) {
      notifier.ensureDownloaded(voice.id);
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.ttsDeleteModelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(piperModelProvider.notifier).deleteModel(voice.id);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.ttsDeleteModel),
          ),
        ],
      ),
    );
  }
}

/// 分组小标题。
///
/// 与全局设置页（`settings_screen.dart` 的 `_buildSection`）保持一致：titleSmall +
/// 品牌色 + 加粗。也用作「Echo Loop TTS」归属标题——点名其下子设置的所属引擎。
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.hint});

  final String text;

  /// 可选弱化提示，显示在标题右侧（小字、次要色），用于补充说明而不喧宾夺主。
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.m,
        AppSpacing.s,
      ),
      child: hint == null
          ? label
          : Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                label,
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    hint!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
