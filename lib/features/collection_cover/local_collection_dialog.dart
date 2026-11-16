// 本地合集的创建 / 编辑对话框：上方大封面 + 封面操作按钮，下方名称输入。
//
// 选好的封面只保存在对话框状态里（已裁剪编码的 JPEG），点保存才交给 `CollectionList`
// 落盘；取消或关闭对话框不产生任何文件或数据库修改。
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/collection.dart';
import '../../providers/collection_provider.dart';
import '../../services/app_logger.dart';
import '../../services/square_image_processor.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/common/form_input_style.dart';
import '../../widgets/square_image_crop_screen.dart';
import 'collection_cover_edit.dart';
import 'collection_cover_image.dart';
import 'collection_cover_store.dart';
import 'image_gallery_picker.dart';

const _logTag = 'CollectionCover';

/// 对话框与屏幕左右边缘的最小间距；窄屏下对话框按此铺满可用宽度。
const double _kDialogHorizontalInset = 24;

/// 对话框（含内边距）最大宽度：平板、桌面宽窗口下不随窗口继续拉宽。
const double _kDialogMaxWidth = 420;

/// AlertDialog 内容区左右内边距之和（Material 3 默认各 24）。
const double _kDialogContentPadding = 48;

/// 封面预览边长取内容宽度的比例，并限制在合理区间内，随屏幕自适应。
const double _kCoverWidthRatio = 0.36;
const double _kCoverMinSize = 88;
const double _kCoverMaxSize = 128;

/// 打开本地合集对话框。[collection] 为 null 时创建新合集，否则编辑该合集。
Future<void> showLocalCollectionDialog(
  BuildContext context, {
  Collection? collection,
}) {
  assert(collection == null || collection.isLocal, '只有本地合集可以编辑封面');
  return showDialog<void>(
    context: context,
    builder: (_) => _LocalCollectionDialog(collection: collection),
  );
}

class _LocalCollectionDialog extends ConsumerStatefulWidget {
  const _LocalCollectionDialog({required this.collection});

  /// 被编辑的合集；创建时为 null。
  final Collection? collection;

  @override
  ConsumerState<_LocalCollectionDialog> createState() =>
      _LocalCollectionDialogState();
}

class _LocalCollectionDialogState
    extends ConsumerState<_LocalCollectionDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.collection?.name ?? '',
  );
  CollectionCoverEdit _cover = const CollectionCoverUnchanged();
  String? _errorText;
  bool _isPickingCover = false;
  bool _isSaving = false;

  bool get _isEditing => widget.collection != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 当前预览应显示的图片；null 表示显示首字占位。
  ImageProvider? _previewImage(String? dataDirectoryPath) {
    return switch (_cover) {
      CollectionCoverReplaced(:final jpegBytes) => MemoryImage(jpegBytes),
      CollectionCoverRemoved() => null,
      CollectionCoverUnchanged() => switch (resolveCollectionCoverFile(
        dataDirectoryPath,
        widget.collection?.localCoverPath,
      )) {
        final file? => FileImage(file),
        null => null,
      },
    };
  }

  bool get _hasCover => switch (_cover) {
    CollectionCoverReplaced() => true,
    CollectionCoverRemoved() => false,
    CollectionCoverUnchanged() => widget.collection?.localCoverPath != null,
  };

  /// 选图 → 预处理（修正方向、限制尺寸）→ 方形裁剪 → 编码 512 JPEG。
  /// 选图或裁剪阶段取消都静默返回，保持原封面。
  Future<void> _pickCover() async {
    if (_isPickingCover || _isSaving) return;
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    setState(() => _isPickingCover = true);
    try {
      AppLogger.log(_logTag, 'pick start');
      final sourceBytes = await ref.read(imageGalleryPickerProvider)();
      if (sourceBytes == null) {
        AppLogger.log(_logTag, 'pick cancelled');
        return;
      }
      final prepared = await prepareSquareCropSource(sourceBytes);
      if (!mounted) return;
      AppLogger.log(
        _logTag,
        'picked: sourceBytes=${sourceBytes.length} prepared=${prepared.length}',
      );
      final cropped = await navigator.push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => SquareImageCropScreen(
            imageBytes: prepared,
            title: l10n.collectionCoverCropTitle,
            isCircle: false,
          ),
        ),
      );
      if (cropped == null) {
        AppLogger.log(_logTag, 'crop cancelled');
        return;
      }
      final jpeg = await encodeSquareJpeg(cropped);
      if (!mounted) return;
      AppLogger.log(
        _logTag,
        'cover drafted: croppedBytes=${cropped.length} jpegBytes=${jpeg.length}',
      );
      setState(() => _cover = CollectionCoverReplaced(jpeg));
    } on SquareImageException catch (error) {
      AppLogger.log(_logTag, 'image rejected: $error cause=${error.cause}');
      showAppToast(
        overlayState: overlay,
        message: l10n.profileImageUnsupported,
      );
    } finally {
      if (mounted) setState(() => _isPickingCover = false);
    }
  }

  void _removeCover() {
    AppLogger.log(_logTag, 'cover removal drafted');
    setState(() => _cover = const CollectionCoverRemoved());
  }

  /// 名称不能为空，也不能与其它合集重名（忽略大小写）；编辑时允许保留原名。
  String? _nameError(AppLocalizations l10n, String name) {
    if (name.isEmpty) return l10n.collectionNameEmpty;
    final editingId = widget.collection?.id;
    final exists = ref
        .read(collectionListProvider)
        .collections
        .any(
          (c) =>
              c.id != editingId && c.name.toLowerCase() == name.toLowerCase(),
        );
    return exists ? l10n.collectionNameExists : null;
  }

  Future<void> _submit() async {
    if (_isSaving || _isPickingCover) return;
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    final name = _nameController.text.trim();
    final error = _nameError(l10n, name);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    setState(() {
      _errorText = null;
      _isSaving = true;
    });
    final notifier = ref.read(collectionListProvider.notifier);
    try {
      final editing = widget.collection;
      if (editing == null) {
        await notifier.createCollection(
          name,
          coverJpeg: switch (_cover) {
            CollectionCoverReplaced(:final jpegBytes) => jpegBytes,
            CollectionCoverUnchanged() || CollectionCoverRemoved() => null,
          },
        );
      } else {
        await notifier.updateLocalCollection(
          editing.id,
          name: name,
          cover: _cover,
        );
      }
      if (mounted) navigator.pop();
    } on Exception catch (error, stackTrace) {
      // 对话框是用户操作的边界：文件或数据库失败都只能提示重试，详细原因写日志。
      AppLogger.log(_logTag, 'submit failed: $error\n$stackTrace');
      showAppToast(overlayState: overlay, message: l10n.collectionSaveFailed);
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isBusy = _isSaving || _isPickingCover;
    final canSubmit = _nameController.text.trim().isNotEmpty && !isBusy;
    // 按实际可用宽度确定对话框宽度：窄屏贴近两侧边距，宽屏封顶；封面随之缩放。
    final availableWidth =
        MediaQuery.sizeOf(context).width - _kDialogHorizontalInset * 2;
    final dialogWidth = availableWidth.clamp(0.0, _kDialogMaxWidth);
    final contentWidth = (dialogWidth - _kDialogContentPadding).clamp(
      0.0,
      double.infinity,
    );
    final coverSize = (contentWidth * _kCoverWidthRatio).clamp(
      _kCoverMinSize,
      _kCoverMaxSize,
    );
    return AlertDialog(
      key: const ValueKey('local-collection-dialog'),
      // 内容区可滚动：矮窗口或键盘弹出时不溢出。
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: _kDialogHorizontalInset,
        vertical: 24,
      ),
      title: Text(
        _isEditing ? l10n.editCollectionTitle : l10n.newCollectionOptionTitle,
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        width: contentWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CoverPreview(
              isBusy: isBusy,
              size: coverSize,
              label: _hasCover
                  ? l10n.collectionCoverChange
                  : l10n.collectionCoverAdd,
              onTap: _pickCover,
              cover: CollectionCoverImage(
                name: _nameController.text,
                size: coverSize,
                image: _previewImage(
                  ref.watch(appDataDirectoryPathProvider).value,
                ),
              ),
            ),
            // 点封面即可添加或更换；只有已有封面时才需要单独的「移除」入口。
            if (_hasCover)
              TextButton(
                key: const ValueKey('collection-cover-remove'),
                onPressed: isBusy ? null : _removeCover,
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                child: Text(l10n.collectionCoverRemove),
              )
            else
              const SizedBox(height: AppSpacing.s),
            const SizedBox(height: AppSpacing.m),
            TextField(
              key: const ValueKey('collection-name-field'),
              controller: _nameController,
              autofocus: !_isEditing,
              enabled: !_isSaving,
              style: compactFormTextStyle(context),
              textInputAction: TextInputAction.done,
              decoration: compactFormInputDecoration(
                context,
                labelText: l10n.collectionName,
                hintText: l10n.enterCollectionName,
                errorText: _errorText,
              ),
              onChanged: (_) => setState(() => _errorText = null),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                key: const ValueKey('collection-form-submit'),
                onPressed: canSubmit ? _submit : null,
                child: Text(_isEditing ? l10n.save : l10n.add),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 可点按的大封面：右下角相机角标提示可添加 / 更换，选图 / 保存期间角标换成进度圈。
class _CoverPreview extends StatelessWidget {
  const _CoverPreview({
    required this.isBusy,
    required this.size,
    required this.label,
    required this.onTap,
    required this.cover,
  });

  final bool isBusy;
  final double size;

  /// 无障碍与悬浮提示文案：无封面为「添加封面」，有封面为「更换图片」。
  final String label;
  final VoidCallback onTap;
  final Widget cover;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          key: const ValueKey('collection-cover-picker'),
          borderRadius: BorderRadius.circular(kCollectionCoverRadius),
          onTap: isBusy ? null : onTap,
          child: SizedBox.square(
            dimension: size + 8,
            child: Stack(
              alignment: Alignment.center,
              children: [
                cover,
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.surfaceContainerHigh,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: isBusy
                        ? SizedBox.square(
                            dimension: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : Icon(
                            Icons.photo_camera_outlined,
                            size: 16,
                            color: colorScheme.onPrimary,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
