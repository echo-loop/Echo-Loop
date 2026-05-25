// 管理字幕底部弹窗
//
// 提供本地上传、AI 转录和删除字幕三种操作。
// AI 转录在后台运行，弹窗关闭后任务继续。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import '../analytics/analytics_providers.dart';
import '../analytics/models/event_names.dart';
import '../models/audio_item.dart';
import '../database/providers.dart';
import '../providers/audio_library_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../providers/new_user_guide_provider.dart';
import '../providers/transcription_task_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../utils/transcript_picker.dart';
import '../utils/transcript_stats.dart';
import 'guide_flow.dart';

/// 字幕操作选项
enum _SubtitleAction { localUpload, aiTranscription }

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
  _SubtitleAction _selectedAction = _SubtitleAction.localUpload;
  String _selectedLanguage = 'auto';

  /// 是否刚打开弹窗（用于首帧跳过残留终态的渲染）
  bool _initialClear = true;

  // Guide step keys
  final _keyAiTranscription = GlobalKey();
  final _keyStartTranscription = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (!widget.audioItem.hasTranscript) {
      _selectedAction = _SubtitleAction.aiTranscription;
    }
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

    // 是否有进行中的任务
    final isTaskActive =
        taskState is TranscriptionHashing ||
        taskState is TranscriptionUploading ||
        taskState is TranscriptionProcessing;

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
              // 标题行 + 删除按钮
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
                    // 删除按钮（仅有字幕且非进度模式时显示）
                    if (audioItem.hasTranscript && !isTaskActive)
                      Tooltip(
                        message: l10n.deleteSubtitle,
                        child: IconButton(
                          onPressed: () =>
                              _handleDeleteSubtitle(context, audioItem),
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: theme.colorScheme.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              // 进度模式 或 选择模式
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isTaskActive || taskState is TranscriptionCompleted
                    ? _buildProgressView(l10n, theme, taskState)
                    : taskState is TranscriptionFailed
                    ? _buildErrorView(l10n, theme, taskState, audioItem)
                    : taskState is TranscriptionEmptyResult
                    ? _buildEmptyResultView(l10n, theme)
                    : _buildRadioOptions(l10n, theme, audioItem),
              ),
              const SizedBox(height: AppSpacing.m),
              // 操作按钮（进度模式下隐藏）
              if (!isTaskActive && taskState is! TranscriptionCompleted)
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
          _buildOptionTile(
            theme: theme,
            icon: Icons.folder_open_outlined,
            title: l10n.localUpload,
            subtitle: l10n.uploadTranscript,
            selected: _selectedAction == _SubtitleAction.localUpload,
            onTap: () =>
                setState(() => _selectedAction = _SubtitleAction.localUpload),
          ),
          const SizedBox(height: AppSpacing.s),
          GuideTarget(
            step: _stepAiTranscription(l10n),
            child: _buildOptionTile(
              theme: theme,
              icon: Icons.auto_awesome_outlined,
              title: l10n.aiTranscription,
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
        ],
      ),
    );
  }

  /// 构建语言选择区域（浅色背景圆角容器）
  Widget _buildLanguageSelector(
    AppLocalizations l10n,
    ThemeData theme,
    AudioItem audioItem,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.selectLanguage,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: 'auto',
                    label: Text(l10n.languageAutoDetect),
                  ),
                  ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
                ],
                selected: {_selectedLanguage},
                onSelectionChanged: (selected) {
                  setState(() => _selectedLanguage = selected.first);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _isAiDisabled(audioItem)
                    ? l10n.alreadyTranscribedWithOption
                    : l10n.mixedLanguageNotSupported,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.primary.withValues(alpha: 0.12)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 20,
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
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
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
        : _isAiDisabled(audioItem)
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
    if (_selectedAction == _SubtitleAction.localUpload) {
      await _handleLocalUpload(context, audioItem);
    } else {
      await _handleAiTranscription(context, audioItem);
    }
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
      final newPath = await pickAndSaveTranscript();
      if (newPath == null) return;

      final stats = await getTranscriptStats(newPath);

      if (!context.mounted) return;
      ref
          .read(audioLibraryProvider.notifier)
          .updateAudioItem(
            audioItem.copyWith(
              transcriptPath: newPath,
              sentenceCount: stats.$1,
              wordCount: stats.$2,
              transcriptSource: TranscriptSource.local,
              transcriptLanguage: null,
            ),
          );

      ref.read(analyticsServiceProvider).track(Events.subtitleUploaded, {
        EventParams.audioId: audioItem.id,
        EventParams.audioName: audioItem.name,
      });
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.pickTranscriptFileFailed}: $e')),
      );
    }
  }

  /// AI 转录文件大小上限（50MB）
  static const _maxFileSize = 50 * 1024 * 1024;

  /// AI 转录时长上限（15 分钟）
  static const _maxDurationSeconds = 15 * 60;

  /// 处理 AI 转录
  Future<void> _handleAiTranscription(
    BuildContext context,
    AudioItem audioItem,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    // 检查时长限制
    if (audioItem.totalDuration > _maxDurationSeconds) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.transcriptionErrorTooLong(15))),
        );
      }
      return;
    }

    // 检查文件大小限制
    final fullPath = await audioItem.getFullAudioPath();
    if (fullPath == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.audioFileNotFound)));
      return;
    }
    final fileSize = await File(fullPath).length();
    if (!context.mounted) return;
    if (fileSize > _maxFileSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.transcriptionErrorFileTooLarge(50))),
      );
      return;
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
        .startTranscription(audioItem, _selectedLanguage);
    ref.read(analyticsServiceProvider).track(Events.transcriptionStarted, {
      EventParams.audioId: audioItem.id,
      EventParams.audioName: audioItem.name,
    });
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

    // 3. 清除词级时间戳
    await ref
        .read(audioItemDaoProvider)
        .updateWordTimestamps(audioItem.id, null);

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
          );
    }
  }
}
