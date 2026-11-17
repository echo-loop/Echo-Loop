import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/side_by_side_split_fraction_notifier.dart';

/// 字幕编辑页左右分栏中左栏（画面 + 波形）占可用宽度的比例；null 表示自动适配。
///
/// 与学习任务页的视频比例分开保存：两边左栏内容不同，共用会互相干扰。
class SubtitleEditorSplitNotifier extends SideBySideSplitFractionNotifier {
  SubtitleEditorSplitNotifier() : super(storageKey, 'SubtitleEditorLayout');

  static const storageKey = 'subtitle_editor_side_by_side_media_fraction';
}

final subtitleEditorSplitProvider =
    NotifierProvider<SubtitleEditorSplitNotifier, double?>(
      SubtitleEditorSplitNotifier.new,
    );
