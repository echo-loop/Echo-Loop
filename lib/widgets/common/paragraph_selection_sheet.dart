/// 段落选择底部弹窗（通用）
///
/// 盲听和复述共用的段落时长选择弹窗。
/// 显示图标 + 标题 + 说明 + 段落时长下拉 + (可选)段间停顿下拉 + 段落数预览 + 开始按钮。
library;

import 'package:flutter/material.dart';
import 'app_dropdown.dart';
import 'pause_choice_dropdown.dart';
import 'setting_labeled_row.dart';
import '../../l10n/app_localizations.dart';
import '../../models/blind_listen_settings.dart';
import '../../models/retell_settings.dart';
import '../../models/sentence.dart';
import '../../models/stage_settings_overrides.dart' show BriefingPauseChoice;
import '../../theme/app_theme.dart';
import '../../utils/playback_speed.dart';
import '../../utils/paragraph_grouping.dart';
import '../guide_flow.dart';
import 'learning_briefing_sheet_content.dart';
import '../review/review_briefing_sheet.dart' show formatEstimatedDuration;

/// 目标段落时长选项（秒）
/// 0 = 逐句，-1 = 不分段（全文一段）
const paragraphDurationOptions = [0, 10, 15, 20, 25, 30, 45, 60, 90, -1];

/// 显示段落选择弹窗
///
/// [icon] 顶部图标
/// [iconColor] 顶部任务图标颜色；未传时使用主题主色
/// [title] 标题文字
/// [subtitle] 说明文字
/// [sentences] 字幕句子列表
/// [defaultSeconds] 默认段落时长（秒）
/// [showPauseMultiplier] 是否显示段间停顿行
/// [showPlaybackSpeed] 是否显示播放速度行（盲听专用，会话内生效）
/// [playbackSpeedOptions] 播放速度离散选项，不传时使用盲听默认档位
/// [stageLabel] 标题下方显示的阶段名（如"第三轮复习"），可选
/// [estimatedDurationText] 说明下方显示的预估时长文本，可选（静态文案，不随选项变化）
/// [estimateDurationBuilder] 动态预估时长 builder，根据当前选中的段落时长 + 停顿倍数实时计算；
///   优先级高于 [estimatedDurationText]，二者同时传入时取 builder
/// [defaultKeywordRatio] 传入则显示可见词比例下拉行（复述专用），盲听不传
/// [onStartPractice] 回调，传递 (目标时长, 停顿倍数, 可见词比例)
Future<void> showParagraphSelectionSheet({
  required BuildContext context,
  required IconData icon,
  Color? iconColor,
  required String title,
  required String subtitle,
  required List<Sentence> sentences,
  int defaultSeconds = 30,
  bool showPauseMultiplier = false,
  bool showPlaybackSpeed = false,
  List<double>? playbackSpeedOptions,
  double defaultPlaybackSpeed = 1.0,
  List<double>? pauseMultiplierOptions,
  List<int>? fixedPauseOptions,
  BriefingPauseChoice defaultPause = const BriefingPauseChoice.smart(),
  String? stageLabel,
  String? estimatedDurationText,
  Duration? Function(int targetSeconds, double pauseMultiplier)?
  estimateDurationBuilder,
  KeywordRatio? defaultKeywordRatio,
  required void Function(
    Duration targetDuration,
    BriefingPauseChoice pause,
    KeywordRatio? keywordRatio,
  )
  onStartPractice,
  void Function(
    Duration targetDuration,
    BriefingPauseChoice pause,
    KeywordRatio? keywordRatio,
    double playbackSpeed,
  )?
  onStartPracticeWithPlaybackSpeed,
  void Function(
    Duration targetDuration,
    BriefingPauseChoice pause,
    KeywordRatio? keywordRatio,
    double playbackSpeed,
  )?
  onSelectionChanged,
  String? skipLabel,
  VoidCallback? onSkip,
  String? skipGuideFlowId,
  String? skipGuideTitle,
  String? skipGuideDescription,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _ParagraphSelectionSheet(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      sentences: sentences,
      defaultSeconds: defaultSeconds,
      showPauseMultiplier: showPauseMultiplier,
      showPlaybackSpeed: showPlaybackSpeed,
      playbackSpeedOptions: playbackSpeedOptions,
      defaultPlaybackSpeed: defaultPlaybackSpeed,
      pauseMultiplierOptions: pauseMultiplierOptions,
      fixedPauseOptions: fixedPauseOptions,
      defaultPause: defaultPause,
      stageLabel: stageLabel,
      estimatedDurationText: estimatedDurationText,
      estimateDurationBuilder: estimateDurationBuilder,
      defaultKeywordRatio: defaultKeywordRatio,
      onStartPractice: onStartPractice,
      onStartPracticeWithPlaybackSpeed: onStartPracticeWithPlaybackSpeed,
      onSelectionChanged: onSelectionChanged,
      skipLabel: skipLabel,
      onSkip: onSkip,
      skipGuideFlowId: skipGuideFlowId,
      skipGuideTitle: skipGuideTitle,
      skipGuideDescription: skipGuideDescription,
    ),
  );
}

class _ParagraphSelectionSheet extends StatefulWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final List<Sentence> sentences;
  final int defaultSeconds;
  final bool showPauseMultiplier;
  final bool showPlaybackSpeed;
  final List<double>? playbackSpeedOptions;
  final double defaultPlaybackSpeed;
  final List<double>? pauseMultiplierOptions;
  final List<int>? fixedPauseOptions;
  final BriefingPauseChoice defaultPause;
  final String? stageLabel;
  final String? estimatedDurationText;
  final Duration? Function(int targetSeconds, double pauseMultiplier)?
  estimateDurationBuilder;
  final KeywordRatio? defaultKeywordRatio;
  final void Function(
    Duration targetDuration,
    BriefingPauseChoice pause,
    KeywordRatio? keywordRatio,
  )
  onStartPractice;
  final void Function(
    Duration targetDuration,
    BriefingPauseChoice pause,
    KeywordRatio? keywordRatio,
    double playbackSpeed,
  )?
  onStartPracticeWithPlaybackSpeed;
  final void Function(
    Duration targetDuration,
    BriefingPauseChoice pause,
    KeywordRatio? keywordRatio,
    double playbackSpeed,
  )?
  onSelectionChanged;
  final String? skipLabel;
  final VoidCallback? onSkip;
  final String? skipGuideFlowId;
  final String? skipGuideTitle;
  final String? skipGuideDescription;

  const _ParagraphSelectionSheet({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    required this.sentences,
    required this.defaultSeconds,
    required this.showPauseMultiplier,
    required this.showPlaybackSpeed,
    this.playbackSpeedOptions,
    required this.defaultPlaybackSpeed,
    this.pauseMultiplierOptions,
    this.fixedPauseOptions,
    this.defaultPause = const BriefingPauseChoice.smart(),
    this.stageLabel,
    this.estimatedDurationText,
    this.estimateDurationBuilder,
    this.defaultKeywordRatio,
    required this.onStartPractice,
    this.onStartPracticeWithPlaybackSpeed,
    this.onSelectionChanged,
    this.skipLabel,
    this.onSkip,
    this.skipGuideFlowId,
    this.skipGuideTitle,
    this.skipGuideDescription,
  });

  @override
  State<_ParagraphSelectionSheet> createState() =>
      _ParagraphSelectionSheetState();
}

class _ParagraphSelectionSheetState extends State<_ParagraphSelectionSheet> {
  late int _targetSeconds = widget.defaultSeconds;

  /// 句间停顿选择(自动/固定间隔/句长倍数),初值来自 [widget.defaultPause]。
  late BriefingPauseChoice _pause = widget.defaultPause;

  late double _playbackSpeed = widget.defaultPlaybackSpeed;
  late KeywordRatio? _keywordRatio = widget.defaultKeywordRatio;

  /// 用于「跳过」按钮新手引导的 showcase key；仅在调用方传入 flow id 时使用。
  final GlobalKey _skipGuideKey = GlobalKey();

  /// 任一控件改动后即时回调当前完整选择(改完即记,无需「开始练习」)。
  void _notifyChanged() {
    final duration = _targetSeconds < 0
        ? const Duration(hours: 24)
        : Duration(seconds: _targetSeconds);
    widget.onSelectionChanged?.call(
      duration,
      _pause,
      _keywordRatio,
      _playbackSpeed,
    );
  }

  int get _paragraphCount {
    if (_targetSeconds == 0) return widget.sentences.length;
    if (_targetSeconds < 0) return 1;
    return groupSentencesIntoParagraphs(
      widget.sentences,
      Duration(seconds: _targetSeconds),
    ).length;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final body = LearningBriefingSheetContent(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.m),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 图标
          Icon(
            widget.icon,
            size: 56,
            color: widget.iconColor ?? theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.s),

          // 标题
          Text(
            widget.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          // 阶段名（可选，如"第三轮复习"）
          if (widget.stageLabel != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.stageLabel!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xs),

          // 学习提示与其他任务入口统一使用灯泡提示卡片。
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    widget.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.m),

          // 段落时长行
          SettingLabeledRow(
            label: Text(
              l10n.blindListenTargetDuration,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: AppDropdown<int>(
              value: _targetSeconds,
              isExpanded: true,
              isDense: true,
              items: paragraphDurationOptions.map((s) {
                final label = switch (s) {
                  0 => l10n.retellBriefingSentenceLevel,
                  -1 => l10n.blindListenNoParagraph,
                  _ => '${s}s',
                };
                return DropdownMenuItem(value: s, child: Text(label));
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _targetSeconds = v);
                  _notifyChanged();
                }
              },
            ),
          ),

          // 段间停顿行（仅盲听显示，且不分段时无段间隔可言，隐藏）
          if (widget.showPauseMultiplier && _targetSeconds != -1) ...[
            const SizedBox(height: AppSpacing.s),
            SettingLabeledRow(
              label: Text(
                l10n.blindListenPauseBetween,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: PauseChoiceDropdown(
                value: _pause,
                fixedOptions: widget.fixedPauseOptions ?? const [],
                multiplierOptions:
                    widget.pauseMultiplierOptions ??
                    BlindListenSettings.multiplierOptions,
                onChanged: (v) {
                  setState(() => _pause = v);
                  _notifyChanged();
                },
              ),
            ),
          ],

          if (widget.showPlaybackSpeed) ...[
            const SizedBox(height: AppSpacing.s),
            SettingLabeledRow(
              label: Text(
                l10n.playbackSpeed,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: AppDropdown<double>(
                value: _playbackSpeed,
                isExpanded: true,
                isDense: true,
                items:
                    (widget.playbackSpeedOptions ??
                            BlindListenSettings.briefingPlaybackSpeedOptions)
                        .map(
                          (speed) => DropdownMenuItem(
                            value: speed,
                            child: Text(_formatSpeed(speed)),
                          ),
                        )
                        .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _playbackSpeed = v);
                    _notifyChanged();
                  }
                },
              ),
            ),
          ],

          // 可见词比例行（仅复述时传入 defaultKeywordRatio 才显示）
          if (_keywordRatio != null) ...[
            const SizedBox(height: AppSpacing.s),
            SettingLabeledRow(
              label: Text(
                l10n.retellKeywordRatio,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: AppDropdown<KeywordRatio>(
                value: _keywordRatio,
                isExpanded: true,
                isDense: true,
                items: KeywordRatio.values
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text('${r.percent}%'),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _keywordRatio = v);
                    _notifyChanged();
                  }
                },
              ),
            ),
          ],

          // 段落数 + 预计时长（同一行节省空间）
          // 不分段时段落数无意义，仅显示预计时长（若有）
          Builder(
            builder: (_) {
              final showParagraphCount = _targetSeconds != -1;
              final estimatedDuration = widget.estimateDurationBuilder?.call(
                _targetSeconds,
                // 固定/自动 走 smart 估算(-1);仅倍数模式用真实倍数。
                // 固定模式的精确预估为次要,显示近似值可接受。
                _pause.legacyPauseMultiplier,
              );
              final dynamicText = estimatedDuration == null
                  ? null
                  : formatEstimatedDuration(l10n, estimatedDuration);
              final estimatedText = dynamicText ?? widget.estimatedDurationText;
              if (!showParagraphCount && estimatedText == null) {
                return const SizedBox.shrink();
              }
              final pieces = <Widget>[];
              if (showParagraphCount) {
                pieces.add(
                  Text(
                    l10n.blindListenParagraphCount(_paragraphCount),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }
              if (estimatedText != null) {
                if (pieces.isNotEmpty) {
                  pieces.add(
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s,
                      ),
                      child: Text(
                        '·',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }
                pieces.addAll([
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    estimatedText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ]);
              }
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: pieces,
                ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.m),

          // 跳过 + 开始练习按钮（宽度 1:2，仅当 onSkip 提供时显示跳过）
          _buildActionButtons(context, l10n),
        ],
      ),
    );

    // 仅在调用方为「跳过」按钮配置了新手引导时，挂载 GuideFlowSequenceHost。
    // 引导 key 与按钮上的 GuideTarget.key 共用同一 [_skipGuideKey] 实例，保证
    // showcaseview 能在 tree 内通过 key 定位到目标。
    final skipFlowId = widget.skipGuideFlowId;
    final skipDescription = widget.skipGuideDescription;
    if (widget.onSkip != null &&
        skipFlowId != null &&
        skipDescription != null) {
      return GuideFlowSequenceHost(
        flows: [
          GuideFlow(
            flowId: skipFlowId,
            shouldRun: true,
            steps: [
              GuideStep(
                key: _skipGuideKey,
                title: widget.skipGuideTitle,
                description: skipDescription,
              ),
            ],
          ),
        ],
        child: body,
      );
    }
    return body;
  }

  /// 底部按钮区：
  /// - onSkip == null：「开始练习」满宽 FilledButton（盲听弹窗等共用组件）
  /// - onSkip != null：左侧灰底 FilledButton.tonal「跳过」(flex:1) +
  ///   右侧 FilledButton「开始练习」(flex:2)，与学习计划页「暂停 / 继续」
  ///   按钮组同款配色（surfaceContainerHighest 灰底 + onSurfaceVariant 前景）。
  Widget _buildActionButtons(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final startButton = FilledButton(
      onPressed: () {
        Navigator.of(context).pop();
        final duration = _targetSeconds < 0
            ? const Duration(hours: 24)
            : Duration(seconds: _targetSeconds);
        final speedCallback = widget.onStartPracticeWithPlaybackSpeed;
        if (speedCallback != null) {
          speedCallback(duration, _pause, _keywordRatio, _playbackSpeed);
        } else {
          widget.onStartPractice(duration, _pause, _keywordRatio);
        }
      },
      child: Text(l10n.startPractice),
    );

    final skipLabel = widget.skipLabel;
    final onSkip = widget.onSkip;
    if (onSkip == null || skipLabel == null) {
      return SizedBox(width: double.infinity, child: startButton);
    }

    final skipButton = FilledButton.tonal(
      onPressed: () {
        Navigator.of(context).pop();
        onSkip();
      },
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        // 纯黑深色主题下底色与背景接近，加描边保证按钮边界清晰
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(skipLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
    );

    final skipDescription = widget.skipGuideDescription;
    final guidedSkip = widget.skipGuideFlowId != null && skipDescription != null
        ? GuideTarget(
            step: GuideStep(
              key: _skipGuideKey,
              title: widget.skipGuideTitle,
              description: skipDescription,
            ),
            child: skipButton,
          )
        : skipButton;

    return Row(
      children: [
        Expanded(flex: 1, child: guidedSkip),
        const SizedBox(width: AppSpacing.m),
        Expanded(flex: 2, child: startButton),
      ],
    );
  }

  /// 统一显示速度标签：始终保留一位小数。
  String _formatSpeed(double speed) => formatPlaybackSpeedLabel(speed);
}
