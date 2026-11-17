import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/side_by_side_split_fraction_notifier.dart';

/// 剪辑页左右分栏中左栏（时间轴 + 转写）占可用宽度的比例；null 表示右栏保持默认宽度。
class MediaTrimSplitNotifier extends SideBySideSplitFractionNotifier {
  MediaTrimSplitNotifier() : super(storageKey, 'MediaTrimLayout');

  static const storageKey = 'media_trim_side_by_side_left_fraction';
}

final mediaTrimSplitProvider =
    NotifierProvider<MediaTrimSplitNotifier, double?>(
      MediaTrimSplitNotifier.new,
    );
