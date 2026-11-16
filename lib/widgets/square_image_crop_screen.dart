import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// 1:1 图片裁剪页，头像（圆形框）与合集封面（方形框）共用。
///
/// 用户确认后以 `pop` 返回裁剪结果（PNG 字节；圆形框时圆外为透明），
/// 取消或返回时 `pop` 为 null。
class SquareImageCropScreen extends StatefulWidget {
  const SquareImageCropScreen({
    super.key,
    required this.imageBytes,
    required this.title,
    required this.isCircle,
  });

  /// 已由 `prepareSquareCropSource` 处理过的 JPEG 字节。
  final Uint8List imageBytes;

  final String title;

  /// true 为圆形裁剪框（头像），false 为方形裁剪框（合集封面）。
  final bool isCircle;

  @override
  State<SquareImageCropScreen> createState() => _SquareImageCropScreenState();
}

class _SquareImageCropScreenState extends State<SquareImageCropScreen> {
  /// 裁剪区域在桌面宽窗口下的上限边长，避免裁剪框撑满整个窗口。
  static const double _maxCropSide = 480;

  final _cropController = CropController();
  bool _isCropping = false;

  void _confirm() {
    setState(() => _isCropping = true);
    _cropController.crop();
  }

  void _handleCropResult(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() => _isCropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.profileImageUnsupported,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side = math.min(
                      _maxCropSide,
                      math.min(constraints.maxWidth, constraints.maxHeight),
                    );
                    return SizedBox.square(
                      dimension: side,
                      child: Crop(
                        image: widget.imageBytes,
                        controller: _cropController,
                        onCropped: _handleCropResult,
                        withCircleUi: widget.isCircle,
                        aspectRatio: 1,
                        interactive: true,
                        baseColor: colorScheme.surfaceContainerLowest,
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isCropping
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isCropping ? null : _confirm,
                      child: Text(l10n.done),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
