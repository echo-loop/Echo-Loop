import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _iosShareIconAsset = 'assets/icon/share.svg';
const _androidShareIconAsset = 'assets/icon/share-android.svg';

/// 今日一刻分享图标：Android 使用 Android 风格，其他平台使用 iOS 风格。
/// 图标 SVG 使用 currentColor，通过 colorFilter 按调用方传入的颜色着色。
class DailyCheckInShareIcon extends StatelessWidget {
  const DailyCheckInShareIcon({
    super.key,
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      Platform.isAndroid ? _androidShareIconAsset : _iosShareIconAsset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
