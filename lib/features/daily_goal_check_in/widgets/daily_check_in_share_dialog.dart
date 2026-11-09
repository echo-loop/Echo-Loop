import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gal/gal.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/app_logger.dart';
import '../../../providers/learning_settings_provider.dart';
import '../../../widgets/app_toast.dart';
import '../data/daily_check_in_share_actions.dart';
import '../providers/daily_check_in_share_provider.dart';
import '../providers/daily_check_in_share_presentation_provider.dart';
import 'daily_check_in_share_icon.dart';

/// 手动入口不等待图片，也不在准备完成后补弹；自动入口仅消费本次返回检查。
Future<void> showDailyCheckInShareDialog(
  BuildContext context,
  WidgetRef ref, {
  bool automatic = false,
  bool Function()? canPresent,
}) async {
  void skip(String reason) {
    if (automatic) AppLogger.log('DailyShare', '跳过自动分享弹窗：$reason');
  }

  if (automatic && !ref.read(learningSettingsProvider).autoShowDailyShare) {
    skip('已关闭自动显示');
    return;
  }

  final l10n = AppLocalizations.of(context)!;
  final userId = ref.read(dailyShareUserIdProvider);
  if (userId == null) {
    skip('未登录');
    if (!automatic) {
      _toast(context, l10n.shareCardNotSignedIn);
    }
    return;
  }
  final presentation = ref.read(dailyShareDialogPresentationProvider);
  if (presentation.isOpen) {
    skip('已有分享弹窗');
    return;
  }
  final notifier = ref.read(dailyCheckInShareProvider.notifier);
  if (!notifier.hasCurrentCard) {
    skip('图片未就绪');
    final state = ref.read(dailyCheckInShareProvider);
    if (!automatic) {
      _toast(
        context,
        state.noAvailableCards
            ? l10n.shareCardNoCards
            : state.status == DailyShareStatus.failed
            ? l10n.shareCardPreparationFailed
            : l10n.shareCardPreparing,
      );
    }
    unawaited(notifier.prepare());
    return;
  }
  presentation.isOpen = true;
  try {
    final date = ref
        .read(dailyShareNowProvider)()
        .toIso8601String()
        .substring(0, 10);
    if (automatic && !presentation.canAutoShow(userId, date)) {
      skip('当天已展示或账号已变化');
      return;
    }
    if (!context.mounted ||
        ref.read(dailyShareUserIdProvider) != userId ||
        ref.read(dailyShareNowProvider)().toIso8601String().substring(0, 10) !=
            date ||
        !ref.read(dailyCheckInShareProvider.notifier).hasCurrentCard ||
        (canPresent != null && !canPresent()) ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      skip('页面、账号、日期或前台状态已变化');
      return;
    }
    final card = ref.read(dailyCheckInShareProvider).card!.clone();
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _DailyCheckInShareDialog(
        initialCard: card,
        onShown: () {
          presentation.didShow(userId, date);
        },
      ),
    );
  } finally {
    presentation.isOpen = false;
  }
}

void _toast(BuildContext context, String message) => showAppToast(
  overlayState: Overlay.of(context, rootOverlay: true),
  message: message,
);

const _shuffleIconAsset = 'assets/icon/shuffle.svg';
const _downloadIconAsset = 'assets/icon/download.svg';

/// 图标 SVG 使用 currentColor，通过 colorFilter 按按钮前景色着色。
Widget _shareIcon(String asset, Color color, {double size = 24}) {
  return SvgPicture.asset(
    asset,
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

class _DailyCheckInShareDialog extends ConsumerStatefulWidget {
  const _DailyCheckInShareDialog({
    required this.initialCard,
    required this.onShown,
  });
  final PreparedDailyCheckInShare initialCard;
  final VoidCallback onShown;

  @override
  ConsumerState<_DailyCheckInShareDialog> createState() =>
      _DailyCheckInShareDialogState();
}

class _DailyCheckInShareDialogState
    extends ConsumerState<_DailyCheckInShareDialog> {
  late PreparedDailyCheckInShare _card;
  bool _busy = false;
  // 仅换卡时显示加载态；保存/分享同样禁用按钮，但不改变换卡图标。
  bool _changing = false;

  @override
  void initState() {
    super.initState();
    _card = widget.initialCard;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isCurrent) widget.onShown();
    });
  }

  bool get _isCurrent =>
      ref.read(dailyShareUserIdProvider) == _card.userId &&
      ref.read(dailyShareNowProvider)().toIso8601String().substring(0, 10) ==
          _card.date.toIso8601String().substring(0, 10);

  void _closeIfExpired() {
    if (_isCurrent) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null) {
        Navigator.of(context).removeRoute(route);
      }
    });
  }

  Future<void> _change() async {
    if (_busy || !_isCurrent) return;
    if (!ref.read(dailyCheckInShareProvider.notifier).hasCurrentCard) {
      _toast(context, AppLocalizations.of(context)!.shareCardPreparing);
      return;
    }
    setState(() {
      _busy = true;
      _changing = true;
    });
    try {
      final changed = await ref
          .read(dailyCheckInShareProvider.notifier)
          .changeCard();
      if (!mounted || !_isCurrent) return;
      if (!changed) {
        _toast(context, AppLocalizations.of(context)!.shareCardNoAlternative);
        return;
      }
      final next = ref.read(dailyCheckInShareProvider).card!.clone();
      final previous = _card;
      setState(() => _card = next);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => previous.image.dispose(),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.log('DailyShare', '换卡失败，保留原图: $error\n$stackTrace');
      if (mounted) {
        _toast(context, AppLocalizations.of(context)!.shareCardActionFailed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _changing = false;
        });
      }
    }
  }

  Future<void> _export({required bool share}) async {
    if (_busy || !_isCurrent) return;
    setState(() => _busy = true);
    final actions = ref.read(dailyShareActionsProvider);
    final api = ref.read(shareCardApiProvider);
    try {
      if (share) {
        final box = context.findRenderObject();
        final origin = box is RenderBox
            ? box.localToGlobal(Offset.zero) & box.size
            : const Rect.fromLTWH(0, 0, 1, 1);
        await actions.share(_card, origin);
        if (mounted && _isCurrent) {
          // 匿名点击计数不重试，也不影响系统分享的结果。
          unawaited(
            api.recordShare(_card.template.id).catchError((
              Object error,
              StackTrace stackTrace,
            ) {
              AppLogger.log('DailyShare', '分享点击计数失败: $error\n$stackTrace');
            }),
          );
        }
      } else {
        final saved = await actions.save(_card);
        if (saved && mounted && _isCurrent) {
          _toast(context, AppLocalizations.of(context)!.shareCardSaved);
        }
      }
    } on GalException catch (error) {
      AppLogger.log('DailyShare', '保存到相册失败: ${error.type.name}');
      if (mounted) {
        _toast(
          context,
          error.type == GalExceptionType.accessDenied
              ? AppLocalizations.of(context)!.shareCardPermissionDenied
              : AppLocalizations.of(context)!.shareCardActionFailed,
        );
      }
    } on Object catch (error, stackTrace) {
      // 平台交互边界统一反馈，取消由平台适配器返回，不进入错误提示。
      AppLogger.log('DailyShare', '导出分享图片失败: $error\n$stackTrace');
      if (mounted) {
        _toast(context, AppLocalizations.of(context)!.shareCardActionFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dailyShareUserIdProvider, (_, _) => _closeIfExpired());
    ref.listen(dailyCheckInShareProvider, (_, _) => _closeIfExpired());
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight:
              MediaQuery.sizeOf(context).height -
              MediaQuery.paddingOf(context).vertical -
              48,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.shareCardTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.shareCardChange,
                    onPressed: _busy ? null : _change,
                    icon: _changing
                        ? SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        : _shareIcon(
                            _shuffleIconAsset,
                            theme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 卡片作为海报展示，圆角与投影让预览脱离弹窗底色。
              // 不能包 Center：Center 会撑满 Flexible 的剩余高度，产生多余空白。
              Flexible(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: RawImage(
                        image: _card.image.preview,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 保存为次要操作，分享为主操作，两者等宽并排。
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: _busy ? null : () => _export(share: false),
                      icon: _shareIcon(
                        _downloadIconAsset,
                        theme.colorScheme.primary,
                        size: 18,
                      ),
                      label: Text(
                        Platform.isIOS || Platform.isAndroid
                            ? l10n.shareCardSave
                            : l10n.shareCardSaveDesktop,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: _busy ? null : () => _export(share: true),
                      icon: DailyCheckInShareIcon(
                        color: theme.colorScheme.onPrimary,
                        size: 18,
                      ),
                      label: Text(l10n.shareCardShare),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _card.image.dispose();
    super.dispose();
  }
}
