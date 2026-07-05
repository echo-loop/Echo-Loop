// 管理字幕底部弹窗
//
// 提供本地上传、AI 转录和删除字幕三种操作。
// AI 转录在后台运行，弹窗关闭后任务继续。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_io/io.dart';
import '../analytics/models/event_names.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/auth/sign_in_required_dialog.dart';
import '../features/usage/usage_event.dart';
import '../features/usage/usage_providers.dart';
import '../models/audio_item.dart';
import '../database/providers.dart';
import '../providers/audio_library_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../providers/new_user_guide_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transcription_task_provider.dart';
import '../providers/local_transcription_task_provider.dart';
import '../providers/local_transcription_model_provider.dart';
import '../providers/offline_asr_settings_provider.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../services/asr/asr_model_manager.dart';
import '../services/asr/offline_asr_engine.dart';
import '../services/subtitle_parser.dart';
import 'asr_download_prompt_dialog.dart';
import '../theme/app_theme.dart';
import '../models/word_timestamp.dart';
import '../utils/synthetic_word_timestamps.dart';
import '../utils/transcript_picker.dart';
import '../utils/transcript_stats.dart';
import 'common/anchored_bubble.dart';
import 'guide_flow.dart';

/// 字幕操作选项
enum _SubtitleAction { localUpload, aiTranscription, offlineTranscription }

/// 内联错误提示的种类（决定图标和标题，文案外部传入）。
enum _UploadErrorKind { unsupportedFormat, formatInvalid, empty, generic }

/// 内联错误条的数据载体。
class _InlineError {
  final _UploadErrorKind kind;
  final String message;
  const _InlineError(this.kind, this.message);
}

/// 管理字幕底部弹窗
///
/// 遵循 EditTagMembershipSheet 布局模式：
/// SafeArea > Padding > Column(mainAxisSize.min)
class ManageSubtitlesSheet extends ConsumerStatefulWidget {
  /// 要管理字幕的音频项
  final AudioItem audioItem;

  const ManageSubtitlesSheet({super.key, required this.audioItem});

  @override
  ConsumerState<ManageSubtitlesSheet> createState() =>
      _ManageSubtitlesSheetState();
}

class _ManageSubtitlesSheetState extends ConsumerState<ManageSubtitlesSheet> {
  /// 默认选中首位「AI 转录」（与选项排序一致，避免高亮落在末尾）。
  _SubtitleAction _selectedAction = _SubtitleAction.aiTranscription;
  String _selectedLanguage = 'en';

  /// AI 转录「自动合并短句」开关，初值取自设置（记住上次选择），默认开启。
  bool _autoMergeShortSentences = true;

  /// 是否刚打开弹窗（用于首帧跳过残留终态的渲染）
  bool _initialClear = true;

  /// 本地上传失败时的内联错误（null 表示无错误）。
  /// 用 sheet 内联卡片而非 SnackBar，是为了规避 modal bottom sheet 内 SnackBar 被遮挡的问题。
  _InlineError? _error;
  Timer? _errorClearTimer;

  // Guide step keys
  final _keyAiTranscription = GlobalKey();
  final _keyStartTranscription = GlobalKey();

  /// 识别模型档位选择气泡浮层控制器。
  final OverlayPortalController _modelMenuController =
      OverlayPortalController();

  @override
  void initState() {
    super.initState();
    // 取上次记住的「自动合并短句」选择作为默认值
    _autoMergeShortSentences = ref
        .read(appSettingsProvider)
        .aiTranscriptionAutoMergeEnabled;
    // 打开弹窗时异步清除之前的失败/空结果状态
    final taskState = ref.read(
      transcriptionTaskManagerProvider,
    )[widget.audioItem.id];
    if (taskState is TranscriptionFailed ||
        taskState is TranscriptionEmptyResult) {
      Future(() {
        if (!mounted) return;
        ref
            .read(transcriptionTaskManagerProvider.notifier)
            .clearState(widget.audioItem.id);
        _initialClear = false;
      });
    } else {
      _initialClear = false;
    }

    // 同样清除本地转录残留的终态（失败/空结果），避免重开闪现旧状态。
    final localTaskState = ref.read(
      localTranscriptionTaskManagerProvider,
    )[widget.audioItem.id];
    if (localTaskState is LocalTranscriptionFailed ||
        localTaskState is LocalTranscriptionEmptyResult) {
      Future(() {
        if (!mounted) return;
        ref
            .read(localTranscriptionTaskManagerProvider.notifier)
            .clearState(widget.audioItem.id);
      });
    }
  }

  @override
  void dispose() {
    _errorClearTimer?.cancel();
    super.dispose();
  }

  /// 显示内联错误条，5 秒后自动消失。重复触发会重置倒计时。
  void _showInlineError(_InlineError err) {
    _errorClearTimer?.cancel();
    setState(() => _error = err);
    _errorClearTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _error = null);
    });
  }

  void _dismissInlineError() {
    _errorClearTimer?.cancel();
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // 监听音频项变化以刷新 UI
    final audioItem =
        ref.watch(
          audioLibraryProvider.select(
            (s) => s.audioItems
                .where((i) => i.id == widget.audioItem.id)
                .firstOrNull,
          ),
        ) ??
        widget.audioItem;

    // 监听转录任务状态
    var taskState =
        ref.watch(
          transcriptionTaskManagerProvider.select((map) => map[audioItem.id]),
        ) ??
        const TranscriptionIdle();

    // 首帧跳过残留的终态，避免闪现旧状态 UI
    if (_initialClear &&
        (taskState is TranscriptionFailed ||
            taskState is TranscriptionEmptyResult)) {
      taskState = const TranscriptionIdle();
    }

    // 监听本地（离线）转录任务状态
    final localTaskState = ref.watch(
      localTranscriptionTaskManagerProvider.select((m) => m[audioItem.id]),
    );
    final isLocalTaskActive =
        localTaskState is LocalTranscriptionDecoding ||
        localTaskState is LocalTranscriptionTranscribing;
    final hasLocalTask =
        localTaskState != null && localTaskState is! LocalTranscriptionIdle;

    // 是否有进行中的任务
    final isTaskActive =
        taskState is TranscriptionHashing ||
        taskState is TranscriptionUploading ||
        taskState is TranscriptionProcessing ||
        isLocalTaskActive;

    // 转录完成后自动关闭弹窗
    ref.listen(
      transcriptionTaskManagerProvider.select((map) => map[audioItem.id]),
      (prev, next) {
        if (next is TranscriptionCompleted) {
          // 短暂显示完成状态后关闭
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!mounted || !context.mounted) return;
            ref
                .read(transcriptionTaskManagerProvider.notifier)
                .clearState(audioItem.id);
            Navigator.pop(context);
          });
        }
      },
    );

    // 本地转录完成后自动关闭弹窗
    ref.listen(
      localTranscriptionTaskManagerProvider.select((map) => map[audioItem.id]),
      (prev, next) {
        if (next is LocalTranscriptionCompleted) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!mounted || !context.mounted) return;
            ref
                .read(localTranscriptionTaskManagerProvider.notifier)
                .clearState(audioItem.id);
            Navigator.pop(context);
          });
        }
      },
    );

    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, AppSpacing.m, 0, AppSpacing.s),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖动手柄
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.m),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 标题行 + 编辑/删除按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.manageSubtitles,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // 本地转录进行中：右上角红色取消按钮（立即打断并清理临时文件）。
                    if (isLocalTaskActive)
                      TextButton(
                        onPressed: () => ref
                            .read(
                              localTranscriptionTaskManagerProvider.notifier,
                            )
                            .cancelTranscription(audioItem.id),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(l10n.cancel),
                      ),
                    // 编辑与删除仅在已有字幕且没有进行中的转录任务时显示。
                    if (audioItem.hasTranscript && !isTaskActive) ...[
                      Tooltip(
                        message: l10n.editSubtitles,
                        child: IconButton(
                          onPressed: () =>
                              _openSubtitleEditor(context, audioItem),
                          icon: const Icon(Icons.edit_note, size: 20),
                          color: theme.colorScheme.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      Tooltip(
                        message: l10n.deleteSubtitle,
                        child: IconButton(
                          onPressed: () =>
                              _handleDeleteSubtitle(context, audioItem),
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: theme.colorScheme.error,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              // 内联错误提示（淡入 + 上滑，sheet 高度平滑变化；5 秒自动消失）
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.08),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _error == null
                      ? const SizedBox(
                          key: ValueKey('no-err'),
                          width: double.infinity,
                        )
                      : Padding(
                          key: ValueKey(_error!.message),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.m,
                            0,
                            AppSpacing.m,
                            AppSpacing.s,
                          ),
                          child: _buildInlineErrorCard(theme, l10n, _error!),
                        ),
                ),
              ),
              // 进度模式 或 选择模式
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: hasLocalTask
                    ? _buildLocalBody(l10n, theme, localTaskState)
                    : isTaskActive || taskState is TranscriptionCompleted
                    ? _buildProgressView(l10n, theme, taskState)
                    : taskState is TranscriptionFailed
                    ? _buildErrorView(l10n, theme, taskState, audioItem)
                    : taskState is TranscriptionEmptyResult
                    ? _buildEmptyResultView(l10n, theme)
                    : _buildRadioOptions(l10n, theme, audioItem),
              ),
              const SizedBox(height: AppSpacing.m),
              // 操作按钮（进度模式下隐藏）
              if (!isTaskActive &&
                  taskState is! TranscriptionCompleted &&
                  localTaskState is! LocalTranscriptionCompleted)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                  child: SizedBox(
                    width: double.infinity,
                    child: _buildActionButton(l10n, audioItem, taskState),
                  ),
                ),
              const SizedBox(height: AppSpacing.s),
            ],
          ),
        ),
      ),
    );
    if (audioItem.hasTranscript) return content;
    return GuideFlowSequenceHost(
      flows: [
        GuideFlow(
          flowId: GuideFlowIds.subtitleSheetTranscription,
          shouldRun: true,
          steps: [_stepAiTranscription(l10n), _stepStartTranscription(l10n)],
        ),
      ],
      child: content,
    );
  }

  GuideStep _stepAiTranscription(AppLocalizations l10n) => GuideStep(
    key: _keyAiTranscription,
    title: l10n.guidePlanAiTranscriptionTitle,
    description: l10n.guidePlanAiTranscriptionDescription,
  );

  GuideStep _stepStartTranscription(AppLocalizations l10n) => GuideStep(
    key: _keyStartTranscription,
    description: l10n.guidePlanStartTranscriptionDescription,
  );

  /// 关闭管理弹窗后打开字幕编辑器，与音频菜单的编辑入口保持一致。
  void _openSubtitleEditor(BuildContext context, AudioItem audioItem) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push(AppRoutes.subtitleEditor(audioItem.id), extra: audioItem);
  }

  /// 构建进度视图（带圆角背景卡片 + 圆形图标容器）
  Widget _buildProgressView(
    AppLocalizations l10n,
    ThemeData theme,
    TranscriptionTaskState taskState,
  ) {
    final IconData icon;
    final String text;
    final Color iconColor;

    if (taskState is TranscriptionCompleted) {
      icon = Icons.check_circle;
      text = l10n.transcriptionComplete;
      iconColor = Colors.green;
    } else if (taskState is TranscriptionHashing) {
      icon = Icons.fingerprint;
      text = l10n.transcriptionUploading; // 对用户统一显示"上传中"
      iconColor = theme.colorScheme.primary;
    } else if (taskState is TranscriptionUploading) {
      icon = Icons.cloud_upload;
      text = l10n.transcriptionUploading;
      iconColor = theme.colorScheme.primary;
    } else {
      icon = Icons.auto_awesome;
      text = l10n.transcriptionProcessing;
      iconColor = theme.colorScheme.primary;
    }

    final isCompleted = taskState is TranscriptionCompleted;

    return Padding(
      key: const ValueKey('progress'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
        decoration: BoxDecoration(
          color: isCompleted
              ? Colors.green.withValues(alpha: 0.08)
              : theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: theme.textTheme.titleSmall?.copyWith(
                color: iconColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!isCompleted) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: taskState is TranscriptionUploading
                        ? taskState.progress
                        : null,
                    minHeight: 4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建错误视图（带圆角背景卡片 + 圆形图标容器）
  Widget _buildErrorView(
    AppLocalizations l10n,
    ThemeData theme,
    TranscriptionFailed taskState,
    AudioItem audioItem,
  ) {
    return Padding(
      key: const ValueKey('error'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 28,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.transcriptionFailed,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Text(
                _localizedErrorMessage(l10n, taskState.message),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 将错误码转换为本地化的用户友好提示
  String _localizedErrorMessage(AppLocalizations l10n, String code) {
    return switch (code) {
      'connection' => l10n.transcriptionErrorConnection,
      'timeout' => l10n.transcriptionErrorTimeout,
      'server' => l10n.transcriptionErrorServer,
      _ => l10n.transcriptionErrorUnknown,
    };
  }

  /// 构建空转录结果视图（音频无人声）
  /// 上传失败的内联错误条。
  ///
  /// 使用紧凑单行样式，避免占用底部弹窗过多垂直空间。
  Widget _buildInlineErrorCard(
    ThemeData theme,
    AppLocalizations l10n,
    _InlineError err,
  ) {
    final colorScheme = theme.colorScheme;
    final accent = colorScheme.error; // 红色错误风格，提高可见性

    final (IconData icon, String title) = switch (err.kind) {
      _UploadErrorKind.unsupportedFormat => (
        Icons.extension_off_outlined,
        l10n.subtitleErrorUnsupportedTitle,
      ),
      _UploadErrorKind.formatInvalid => (
        Icons.description_outlined,
        l10n.subtitleErrorInvalidTitle,
      ),
      _UploadErrorKind.empty => (
        Icons.inbox_outlined,
        l10n.subtitleErrorEmptyTitle,
      ),
      _UploadErrorKind.generic => (
        Icons.error_outline,
        l10n.subtitleErrorGenericTitle,
      ),
    };

    return Semantics(
      liveRegion: true,
      container: true,
      label: '$title. ${err.message}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colorScheme.error.withValues(alpha: 0.55),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: accent),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: ' · ${err.message}'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                  height: 1.25,
                ),
              ),
            ),
            IconButton(
              onPressed: _dismissInlineError,
              icon: const Icon(Icons.close, size: 18),
              color: colorScheme.error,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyResultView(AppLocalizations l10n, ThemeData theme) {
    return Padding(
      key: const ValueKey('empty-result'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hearing_disabled,
                size: 28,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.transcriptionEmptyResult,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Text(
                l10n.transcriptionEmptyResultHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 路由本地转录任务状态到对应视图。
  Widget _buildLocalBody(
    AppLocalizations l10n,
    ThemeData theme,
    LocalTranscriptionState st,
  ) {
    if (st is LocalTranscriptionFailed) {
      return _buildLocalFailedView(l10n, theme);
    }
    if (st is LocalTranscriptionEmptyResult) {
      return _buildEmptyResultView(l10n, theme);
    }
    return _buildLocalProgressView(l10n, theme, st);
  }

  /// 本地转录进度视图（解码=不定态，转录=determinate，完成=对勾）。
  Widget _buildLocalProgressView(
    AppLocalizations l10n,
    ThemeData theme,
    LocalTranscriptionState st,
  ) {
    final IconData icon;
    final String text;
    final Color iconColor;
    double? progress;
    final isCompleted = st is LocalTranscriptionCompleted;

    if (isCompleted) {
      icon = Icons.check_circle;
      text = l10n.transcriptionComplete;
      iconColor = Colors.green;
    } else if (st is LocalTranscriptionDecoding) {
      icon = Icons.graphic_eq;
      text = l10n.localTranscriptionDecoding;
      iconColor = theme.colorScheme.primary;
      progress = null;
    } else {
      icon = Icons.auto_awesome;
      text = l10n.transcriptionProcessing;
      iconColor = theme.colorScheme.primary;
      progress = st is LocalTranscriptionTranscribing ? st.progress : null;
    }

    return Padding(
      key: const ValueKey('local-progress'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
        decoration: BoxDecoration(
          color: isCompleted
              ? Colors.green.withValues(alpha: 0.08)
              : theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: theme.textTheme.titleSmall?.copyWith(
                color: iconColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!isCompleted) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: progress, minHeight: 4),
                ),
              ),
              // 数字进度：仅转录态（有确定进度）显示，解码不定态不显示。
              if (progress != null) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.localTranscriptionProgressPercent(
                    (progress.clamp(0.0, 1.0) * 100).round(),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: iconColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // 提醒保持前台：本地转录纯靠 Dart isolate 推理，切后台/锁屏
              // 进程被挂起会中断，故显式提示用户别切走。
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.localTranscriptionForegroundHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 本地转录失败视图。
  Widget _buildLocalFailedView(AppLocalizations l10n, ThemeData theme) {
    return Padding(
      key: const ValueKey('local-error'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 28,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.transcriptionFailed,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Text(
                l10n.transcriptionErrorUnknown,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建选项卡片列表（替代 RadioListTile）
  Widget _buildRadioOptions(
    AppLocalizations l10n,
    ThemeData theme,
    AudioItem audioItem,
  ) {
    return Padding(
      key: const ValueKey('options'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 排序：AI 转录（推荐默认）→ 本地转录（离线替代）→ 本地上传（进阶手动）。
          GuideTarget(
            step: _stepAiTranscription(l10n),
            child: _buildOptionTile(
              theme: theme,
              icon: Icons.auto_awesome_outlined,
              title: l10n.aiTranscription,
              subtitle: l10n.aiTranscriptionSubtitle,
              selected: _selectedAction == _SubtitleAction.aiTranscription,
              onTap: () => setState(
                () => _selectedAction = _SubtitleAction.aiTranscription,
              ),
            ),
          ),
          // AI 转录语言选择（动画展开/收起）
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _selectedAction == _SubtitleAction.aiTranscription
                ? _buildLanguageSelector(l10n, theme, audioItem)
                : const SizedBox(width: double.infinity, height: 0),
          ),
          const SizedBox(height: AppSpacing.s),
          // 本地（离线）转录选项
          _buildOptionTile(
            theme: theme,
            icon: Icons.offline_bolt_outlined,
            title: l10n.offlineTranscription,
            subtitle: l10n.offlineTranscriptionSubtitle,
            selected: _selectedAction == _SubtitleAction.offlineTranscription,
            onTap: () => setState(
              () => _selectedAction = _SubtitleAction.offlineTranscription,
            ),
          ),
          // 本地转录选项（语言 + 模型档位，动画展开/收起）
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _selectedAction == _SubtitleAction.offlineTranscription
                ? _buildOfflineOptions(l10n, theme)
                : const SizedBox(width: double.infinity, height: 0),
          ),
          const SizedBox(height: AppSpacing.s),
          // 本地上传（手动导入已有字幕文件）
          _buildOptionTile(
            theme: theme,
            icon: Icons.folder_open_outlined,
            title: l10n.localUpload,
            selected: _selectedAction == _SubtitleAction.localUpload,
            onTap: () =>
                setState(() => _selectedAction = _SubtitleAction.localUpload),
          ),
        ],
      ),
    );
  }

  /// 构建本地转录选项区（语言：仅英文可选；识别模型档位选择）。
  Widget _buildOfflineOptions(AppLocalizations l10n, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final selectedModel = ref.watch(localTranscriptionModelProvider);
    final asrState = ref.watch(offlineAsrSettingsProvider);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s, left: 4, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 语言行：当前仅英文可选（选择器可见，不隐含只支持英文）。
          Row(
            children: [
              Icon(
                Icons.translate_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  l10n.selectLanguage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              // 语言胶囊：当前仅英文一个选项，但仍做成可点菜单，避免与下方
              // 可点的「识别模型」胶囊外观一致却点不动造成困惑。
              PopupMenuButton<String>(
                initialValue: 'en',
                tooltip: '',
                position: PopupMenuPosition.under,
                offset: const Offset(0, 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.zero,
                itemBuilder: (context) => [
                  _buildOfflineLanguageMenuItem(
                    'en',
                    l10n.languageEnglish,
                    theme,
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.languageEnglish,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.unfold_more_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          // 「自动合并短句」开关（与 AI 转录共用）：开启时客户端把 VAD 相邻短段
          // 合并到目标时长，关闭时保留 VAD 原始切分。
          _buildAutoMergeToggle(l10n, theme),
          const SizedBox(height: AppSpacing.s),
          // 识别模型档位选择。
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  l10n.transcriptionModelTier,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              AnchoredBubble(
                controller: _modelMenuController,
                direction: BubbleDirection.up,
                width: 320,
                contentBuilder: (_) =>
                    _buildModelMenu(l10n, asrState, selectedModel.id, theme),
                child: Semantics(
                  button: true,
                  label: selectedModel.displayName,
                  onTap: _modelMenuController.toggle,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _modelMenuController.toggle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.45,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selectedModel.displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.unfold_more_rounded,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 本地转录语言下拉菜单项（当前仅英文，恒为选中态）。
  PopupMenuItem<String> _buildOfflineLanguageMenuItem(
    String value,
    String label,
    ThemeData theme,
  ) {
    return PopupMenuItem<String>(
      value: value,
      // 仅英文可选，选择不改变任何状态；菜单仅用于消除「看似可点却点不动」的困惑。
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Icon(
              Icons.check_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 识别模型档位气泡菜单内容：每档一行，选中打勾 + 下载状态 badge。
  Widget _buildModelMenu(
    AppLocalizations l10n,
    OfflineAsrSettingsState asrState,
    String selectedId,
    ThemeData theme,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final model in availableModels)
          _buildModelMenuRow(l10n, model, asrState, selectedId, theme),
      ],
    );
  }

  /// 模型档位气泡行：行首打勾（选中）+ 显示名称 + 行尾下载状态 badge。
  ///
  /// badge 仅展示状态（就绪 / 需下载），具体体积在设置页查看。名称单行不换行。
  Widget _buildModelMenuRow(
    AppLocalizations l10n,
    AsrModelInfo model,
    OfflineAsrSettingsState asrState,
    String selectedId,
    ThemeData theme,
  ) {
    final selected = model.id == selectedId;
    final ready = asrState.modelStateOf(model.id).isReady;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () {
          _modelMenuController.hide();
          ref.read(localTranscriptionModelProvider.notifier).select(model);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: 10,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      )
                    : null,
              ),
              Expanded(
                child: Text(
                  model.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              _ModelStatusBadge(
                label: ready
                    ? l10n.speechModelStatusReady
                    : l10n.speechModelStatusNeedsDownload,
                ready: ready,
                theme: theme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建语言选择区域（浅色背景圆角容器）
  Widget _buildLanguageSelector(
    AppLocalizations l10n,
    ThemeData theme,
    AudioItem audioItem,
  ) {
    final colorScheme = theme.colorScheme;
    final currentLabel = _selectedLanguage == 'auto'
        ? l10n.languageAutoDetect
        : l10n.languageEnglish;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s, left: 4, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 单行：标签在左（带语言图标），可点击的语言胶囊靠右
          Row(
            children: [
              Icon(
                Icons.translate_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  l10n.selectLanguage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              // 语言胶囊：填充主色调，呼应选中的 AI 转录卡片
              PopupMenuButton<String>(
                initialValue: _selectedLanguage,
                tooltip: '',
                position: PopupMenuPosition.under,
                offset: const Offset(0, 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) =>
                    setState(() => _selectedLanguage = value),
                padding: EdgeInsets.zero,
                itemBuilder: (context) => [
                  _buildLanguageMenuItem('en', l10n.languageEnglish, theme),
                  _buildLanguageMenuItem(
                    'auto',
                    l10n.languageAutoDetect,
                    theme,
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.unfold_more_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          _buildAutoMergeToggle(l10n, theme),
          // 仅在该选项已转录时提示，混合语言不支持的提示已移除
          if (_isAiDisabled(audioItem))
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 26),
              child: Text(
                l10n.alreadyTranscribedWithOption,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 「自动合并短句」开关行（AI 转录与本地转录共用）。
  ///
  /// AI 转录：透传给后端返回合并/未合并基线；本地转录：控制客户端把 VAD
  /// 相邻短段合并到目标时长。二者共用同一持久化偏好（记住上次选择，默认开启）。
  Widget _buildAutoMergeToggle(AppLocalizations l10n, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(
          Icons.compress_rounded,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.autoMergeShortSentences,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.autoMergeShortSentencesHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Switch.adaptive(
          value: _autoMergeShortSentences,
          onChanged: (value) {
            setState(() => _autoMergeShortSentences = value);
            ref
                .read(appSettingsProvider.notifier)
                .setAiTranscriptionAutoMergeEnabled(value);
          },
        ),
      ],
    );
  }

  /// 构建语言下拉菜单项（选中项前置勾选标记）
  PopupMenuItem<String> _buildLanguageMenuItem(
    String value,
    String label,
    ThemeData theme,
  ) {
    final selected = _selectedLanguage == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  )
                : null,
          ),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建选项卡片（带图标 + 选中态边框高亮）
  Widget _buildOptionTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colorScheme = theme.colorScheme;
    return Material(
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // 图标容器
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.primary.withValues(alpha: 0.12)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              // 文字内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: selected
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                  ],
                ),
              ),
              // Radio 指示器
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// AI 转录按钮是否禁用
  ///
  /// 当 transcriptSource==ai 且选中的语言==transcriptLanguage 时禁用
  bool _isAiDisabled(AudioItem audioItem) {
    return audioItem.transcriptSource == TranscriptSource.ai &&
        audioItem.transcriptLanguage == _selectedLanguage;
  }

  /// 操作按钮是否可用
  bool _getActionEnabled(AudioItem audioItem) {
    if (_selectedAction == _SubtitleAction.localUpload) return true;
    // 本地转录：始终可用（可重复转录/覆盖）。
    if (_selectedAction == _SubtitleAction.offlineTranscription) return true;
    // AI 转录：同语言已转录时禁用
    return !_isAiDisabled(audioItem);
  }

  Widget _buildActionButton(
    AppLocalizations l10n,
    AudioItem audioItem,
    TranscriptionTaskState taskState,
  ) {
    final enabled =
        taskState is TranscriptionFailed ||
        taskState is TranscriptionEmptyResult ||
        _getActionEnabled(audioItem);
    final label =
        taskState is TranscriptionFailed ||
            taskState is TranscriptionEmptyResult
        ? l10n.retryTranscription
        : _selectedAction == _SubtitleAction.localUpload
        ? l10n.uploadTranscript
        : _selectedAction == _SubtitleAction.aiTranscription &&
              _isAiDisabled(audioItem)
        ? l10n.alreadyTranscribedWithOption
        : l10n.startTranscription;

    final button = FilledButton(
      onPressed: enabled ? () => _handleAction(context, audioItem) : null,
      child: Text(label),
    );

    return GuideTarget(step: _stepStartTranscription(l10n), child: button);
  }

  /// 处理操作按钮点击
  Future<void> _handleAction(BuildContext context, AudioItem audioItem) async {
    switch (_selectedAction) {
      case _SubtitleAction.localUpload:
        await _handleLocalUpload(context, audioItem);
      case _SubtitleAction.aiTranscription:
        await _handleAiTranscription(context, audioItem);
      case _SubtitleAction.offlineTranscription:
        await _handleOfflineTranscription(context, audioItem);
    }
  }

  /// 处理本地（离线）转录：确认覆盖/疑似空音频 → 门控下载模型 → 启动后台任务。
  ///
  /// 无需登录、无云端大小/时长限制。
  Future<void> _handleOfflineTranscription(
    BuildContext context,
    AudioItem audioItem,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    // 疑似空音频确认（与 AI 转录一致，用确认而非硬拦截）。
    if (audioItem.contentStatus == AudioContentStatus.suspectEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.transcriptionSilentConfirmTitle),
          content: Text(l10n.transcriptionSilentConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.transcriptionSilentConfirmProceed),
            ),
          ],
        ),
      );
      if (proceed != true || !context.mounted) return;
    }

    // 已有字幕时弹出覆盖确认。
    if (audioItem.hasTranscript) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.overwriteExistingSubtitle),
          content: Text(l10n.overwriteExistingSubtitleMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.overwrite),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    // 门控：确保所选档位模型已下载（无视评分后端，不改评分设置）。
    final model = ref.read(localTranscriptionModelProvider);
    final ready = await ensureAsrModelReadyForTranscription(
      context,
      ref,
      model: model,
    );
    if (!ready || !context.mounted) return;

    // 启动后台本地转录任务。
    ref
        .read(localTranscriptionTaskManagerProvider.notifier)
        .startLocalTranscription(
          audioItem,
          model: model,
          autoMergeShortSentences: _autoMergeShortSentences,
        );
  }

  /// 处理本地上传
  Future<void> _handleLocalUpload(
    BuildContext context,
    AudioItem audioItem,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    // 已有字幕时弹出覆盖确认
    if (audioItem.hasTranscript) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: this.context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.overwriteExistingSubtitle),
          content: Text(l10n.overwriteExistingSubtitleMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.overwrite),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed != true) return;
    }

    try {
      final content = await pickTranscriptContent();
      if (content == null) return;

      final stats = await getTranscriptStatsFromSrt(content);

      // 本地字幕没有真实词级时间戳，保存时按字符长度生成近似词级时间戳。
      final wordTimestampsJson = encodeWordTimestamps(
        await generateSyntheticWordTimestampsFromSrt(content),
      );

      // 字幕内容 + 近似词级时间戳原子写入 DB；transcriptPath 置 null。
      await ref
          .read(audioItemDaoProvider)
          .saveTranscriptContent(
            audioItem.id,
            srt: content,
            wordTimestampsJson: wordTimestampsJson,
          );

      if (!context.mounted) return;
      ref
          .read(audioLibraryProvider.notifier)
          .updateAudioItem(
            audioItem.copyWith(
              transcriptPath: null,
              sentenceCount: stats.$1,
              wordCount: stats.$2,
              transcriptSource: TranscriptSource.local,
              transcriptLanguage: null,
            ),
          );

      ref
          .read(usageTrackerProvider)
          .record(
            UsageEvent.subtitleUploaded,
            analyticsParams: {
              EventParams.audioId: audioItem.id,
              EventParams.audioName: audioItem.name,
            },
          );
      if (context.mounted) Navigator.pop(context);
    } on SubtitleParseException catch (e) {
      if (!mounted) return;
      final kind = switch (e.kind) {
        SubtitleParseErrorKind.unsupportedFormat =>
          _UploadErrorKind.unsupportedFormat,
        SubtitleParseErrorKind.formatInvalid => _UploadErrorKind.formatInvalid,
        SubtitleParseErrorKind.empty => _UploadErrorKind.empty,
      };
      _showInlineError(_InlineError(kind, subtitleParseErrorMessage(l10n, e)));
    } catch (e) {
      if (!mounted) return;
      _showInlineError(
        _InlineError(
          _UploadErrorKind.generic,
          '${l10n.pickTranscriptFileFailed}: $e',
        ),
      );
    }
  }

  /// AI 转录文件大小上限（50MB）
  static const _maxFileSize = 50 * 1024 * 1024;

  /// AI 转录时长上限（30 分钟）
  static const _maxDurationSeconds = 30 * 60;

  /// 处理 AI 转录
  Future<void> _handleAiTranscription(
    BuildContext context,
    AudioItem audioItem,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final accessToken = (await ref.read(
      supabaseSessionProvider.future,
    ))?.accessToken;
    if (!mounted || !context.mounted) return;
    if (accessToken == null || accessToken.isEmpty) {
      await _showTranscriptionSignInDialog(context);
      return;
    }

    // 检查时长限制
    if (audioItem.totalDuration > _maxDurationSeconds) {
      _showInlineError(
        _InlineError(
          _UploadErrorKind.generic,
          l10n.transcriptionErrorTooLong(30),
        ),
      );
      return;
    }

    // 检查文件大小限制
    final fullPath = await audioItem.getFullAudioPath();
    if (fullPath == null) {
      if (!mounted) return;
      _showInlineError(
        _InlineError(_UploadErrorKind.generic, l10n.audioFileNotFound),
      );
      return;
    }
    final fileSize = await File(fullPath).length();
    if (!mounted) return;
    if (fileSize > _maxFileSize) {
      _showInlineError(
        _InlineError(
          _UploadErrorKind.generic,
          l10n.transcriptionErrorFileTooLarge(50),
        ),
      );
      return;
    }

    // 疑似空音频（解码失败 / 全程静音）拦截：用确认而非硬拦截，规避检测误判
    if (audioItem.contentStatus == AudioContentStatus.suspectEmpty) {
      if (!context.mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.transcriptionSilentConfirmTitle),
          content: Text(l10n.transcriptionSilentConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.transcriptionSilentConfirmProceed),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    // 已有字幕时弹出覆盖确认
    if (audioItem.hasTranscript) {
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.overwriteExistingSubtitle),
          content: Text(l10n.overwriteExistingSubtitleMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.overwrite),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    // 启动后台转录任务
    ref
        .read(transcriptionTaskManagerProvider.notifier)
        .startTranscription(
          audioItem,
          _selectedLanguage,
          accessToken: accessToken,
          autoMergeShortSentences: _autoMergeShortSentences,
        );
    ref
        .read(usageTrackerProvider)
        .record(
          UsageEvent.aiTranscriptionStarted,
          analyticsParams: {
            EventParams.audioId: audioItem.id,
            EventParams.audioName: audioItem.name,
          },
        );
  }

  /// 展示 AI 转录登录引导弹窗。
  ///
  /// AI 转录会上传音频并访问云端转录服务，因此只允许登录用户发起；
  /// 本地上传字幕和已有本地字幕不受影响。
  Future<void> _showTranscriptionSignInDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await ensureSignedInForAction(
      context: context,
      ref: ref,
      title:
          l10n?.transcriptionSignInRequiredTitle ??
          'Sign in to use AI transcription',
      message:
          l10n?.transcriptionSignInRequiredMessage ??
          'AI transcription uses the cloud transcription service. Sign in to transcribe audio with AI.',
    );
  }

  /// 处理删除字幕
  Future<void> _handleDeleteSubtitle(
    BuildContext context,
    AudioItem audioItem,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(ctx).colorScheme.error,
        ),
        title: Text(l10n.deleteSubtitleConfirm),
        content: Text(l10n.deleteSubtitleWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // 1. 删除本地字幕文件
    if (audioItem.transcriptPath != null) {
      try {
        final fullPath = await audioItem.getFullTranscriptPath();
        if (fullPath != null) {
          final file = File(fullPath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      } catch (_) {
        // 文件不存在不报错
      }
    }

    // 注意：不删除后端转录记录。
    // userAudios 表按 SHA256 去重，多个用户共享同一条记录，
    // 删除后端 transcript 会影响所有共用同一音频的用户。
    // 用户重新转录时，后端 upsert 会覆盖旧记录，无需手动删除。

    // 3. 清除字幕内容列与词级时间戳
    final audioDao = ref.read(audioItemDaoProvider);
    await audioDao.updateTranscriptSrt(audioItem.id, null);
    await audioDao.updateWordTimestamps(audioItem.id, null);

    // 4. 更新本地数据库：清除字幕相关字段
    ref
        .read(audioLibraryProvider.notifier)
        .updateAudioItem(
          audioItem.copyWith(
            transcriptPath: null,
            transcriptSource: null,
            transcriptLanguage: null,
            sentenceCount: 0,
            wordCount: 0,
          ),
        );

    // 5. 删除该音频的所有收藏句子
    await ref.read(bookmarkDaoProvider).removeAllForAudio(audioItem.id);

    // 6. 重置该音频的学习进度
    // 学习进度基于句子索引/段落索引，字幕删除后这些索引失去参照；
    // 若不重置，重新导入字幕时旧断点会指向错位的句子。
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .deleteProgress(audioItem.id);

    // 7. 清除 listeningPracticeProvider 中缓存的句子数据
    // 字幕内容入库后 transcriptPath 恒为 null，loadAudio 去重守卫（比较 id +
    // transcriptPath）无法察觉变化，必须强制重载才能让 keepAlive 的 LP 丢弃旧句子。
    final practiceState = ref.read(listeningPracticeProvider);
    if (practiceState.currentAudioItem?.id == audioItem.id) {
      ref
          .read(listeningPracticeProvider.notifier)
          .loadAudio(
            audioItem.copyWith(
              transcriptPath: null,
              transcriptSource: null,
              transcriptLanguage: null,
              sentenceCount: 0,
              wordCount: 0,
            ),
            forceTranscriptReload: true,
          );
    }
  }
}

/// 模型档位下载状态 badge：已就绪（primaryContainer）/ 需下载（surfaceVariant）。
class _ModelStatusBadge extends StatelessWidget {
  const _ModelStatusBadge({
    required this.label,
    required this.ready,
    required this.theme,
  });

  /// badge 文案（就绪 · 150 MB / 需下载 · 150 MB）。
  final String label;

  /// 是否已就绪（决定配色）。
  final bool ready;

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final bg = ready
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final fg = ready
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
