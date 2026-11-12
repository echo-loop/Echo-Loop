import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/app_logger.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/dot_lottie_decoder.dart';

const _confettiAnimationAsset = 'assets/animation/confetti-2.lottie';

/// 文字入场时长，与彩带同时开始。
const _textEntranceDuration = Duration(milliseconds: 700);

/// 文字在彩带播完前这段时间开始淡出，避免文字与画面结束生硬切换。
const _textExitDuration = Duration(milliseconds: 400);

/// 彩带加载失败时只显示文字的停留时长，保证卡片不会因此被卡住。
const _fallbackHoldDuration = Duration(milliseconds: 2500);

/// 系统开启「减少动画」时不播放彩带，文字静止停留的时长。
const _reducedMotionHoldDuration = Duration(milliseconds: 1200);

/// 自动弹出今日一刻卡片前播放的全屏庆祝动画。
///
/// 动画播完、点击屏幕或按返回键后返回，由调用方继续展示卡片。
Future<void> showDailyGoalCelebration(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: 'daily-goal-celebration',
    // 叠加在学习页之上，不遮罩页面内容，用户仍能看到下方页面。
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (_, _, _) => const _DailyGoalCelebration(),
  );
}

class _DailyGoalCelebration extends StatefulWidget {
  const _DailyGoalCelebration();

  @override
  State<_DailyGoalCelebration> createState() => _DailyGoalCelebrationState();
}

class _DailyGoalCelebrationState extends State<_DailyGoalCelebration>
    with TickerProviderStateMixin {
  late final AnimationController _textEntrance;
  late final AnimationController _confetti;
  LottieComposition? _composition;
  Timer? _textExitTimer;
  Timer? _closeTimer;
  bool _textExiting = false;
  bool _closed = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _textEntrance = AnimationController(
      vsync: this,
      duration: _textEntranceDuration,
    );
    _confetti = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 依赖 MediaQuery 的初始化只做一次，之后系统设置变化不再重新播放。
    if (_started) return;
    _started = true;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _textEntrance.value = 1;
      _closeTimer = Timer(_reducedMotionHoldDuration, () => _close());
      AppLogger.log('DailyShare', '减少动画已开启，仅显示庆祝文字');
      return;
    }
    _textEntrance.forward();
    unawaited(_loadConfetti());
  }

  Future<void> _loadConfetti() async {
    try {
      final data = await rootBundle.load(_confettiAnimationAsset);
      final composition = await decodeDotLottieAnimation(
        data.buffer.asUint8List(),
      );
      if (!mounted) return;
      if (composition == null) {
        _onConfettiUnavailable('压缩包中没有动画 JSON');
        return;
      }
      _playConfetti(composition);
    } on Object catch (error, stackTrace) {
      if (!mounted) return;
      AppLogger.log('DailyShare', '庆祝动画加载失败，仅显示文字: $error\n$stackTrace');
      _onConfettiUnavailable('加载失败');
    }
  }

  void _onConfettiUnavailable(String reason) {
    AppLogger.log('DailyShare', '庆祝彩带不可用（$reason），仅显示文字');
    _closeTimer = Timer(_fallbackHoldDuration, () => _close());
  }

  void _playConfetti(LottieComposition composition) {
    AppLogger.log(
      'DailyShare',
      '开始播放庆祝动画，时长 ${composition.duration.inMilliseconds}ms',
    );
    _confetti.duration = composition.duration;
    _textExitTimer = Timer(composition.duration - _textExitDuration, () {
      if (mounted) setState(() => _textExiting = true);
    });
    setState(() => _composition = composition);
    _confetti.forward().then((_) => _close());
  }

  void _close({bool skipped = false}) {
    if (_closed || !mounted) return;
    _closed = true;
    AppLogger.log('DailyShare', skipped ? '庆祝动画已跳过' : '庆祝动画播放结束');
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _textExitTimer?.cancel();
    _closeTimer?.cancel();
    _textEntrance.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final composition = _composition;
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _close(skipped: true),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (composition != null)
              // 素材为 16:9 横版，竖屏无法完整铺满；按屏幕宽度等比展开贴在顶部，
              // 彩带完整可见且不被裁切，下方页面仍然可见。
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height:
                    MediaQuery.sizeOf(context).width *
                    composition.bounds.height /
                    composition.bounds.width,
                child: IgnorePointer(
                  child: Lottie(
                    composition: composition,
                    controller: _confetti,
                    repeat: false,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            _GoalAchievedText(
              title: AppLocalizations.of(context)!.dailyGoalAchievedTitle,
              entrance: _textEntrance,
              exiting: _textExiting,
            ),
          ],
        ),
      ),
    );
  }
}

/// 绿色勾选 + 标题，浮在彩带上方；白底胶囊保证彩带经过时文字仍清晰。
class _GoalAchievedText extends StatelessWidget {
  const _GoalAchievedText({
    required this.title,
    required this.entrance,
    required this.exiting,
  });

  final String title;
  final AnimationController entrance;
  final bool exiting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppTheme.successColor,
              size: 32,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return AnimatedOpacity(
      opacity: exiting ? 0 : 1,
      duration: _textExitDuration,
      child: AnimatedBuilder(
        animation: entrance,
        child: badge,
        builder: (context, child) {
          // 入场：淡入 + 上浮约 16px + 从 0.9 放大到 1.0。
          final progress = Curves.easeOutCubic.transform(entrance.value);
          return Opacity(
            opacity: progress,
            child: Transform.translate(
              offset: Offset(0, (1 - progress) * 16),
              child: Transform.scale(scale: 0.9 + 0.1 * progress, child: child),
            ),
          );
        },
      ),
    );
  }
}
