import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../data/avatar_image_processor.dart';
import '../domain/user_profile.dart';
import '../providers/user_profile_provider.dart';
import '../screens/avatar_crop_screen.dart';
import 'nickname_edit_dialog.dart';
import 'user_avatar.dart';

/// 账号页顶部的资料编辑区：点击头像直接选图更换，昵称与移除头像以列表行操作。
class ProfileEditSection extends ConsumerStatefulWidget {
  const ProfileEditSection({super.key});

  @override
  ConsumerState<ProfileEditSection> createState() => _ProfileEditSectionState();
}

class _ProfileEditSectionState extends ConsumerState<ProfileEditSection> {
  static const double _avatarSize = 88;

  bool _isSaving = false;

  /// 直接打开系统相册/文件选择。iOS 与 Android 为相册，macOS 为文件选择框。
  /// 选图 → 预处理 → 裁剪 → 压缩 → 上传；用户在任一步取消都静默返回。
  Future<void> _changeAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final sourceBytes = await picked.readAsBytes();
    final preparedBytes = await prepareAvatarSourceForCrop(sourceBytes);
    if (!mounted) return;

    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => AvatarCropScreen(imageBytes: preparedBytes),
      ),
    );
    if (croppedBytes == null) return;

    final uploadBytes = await encodeAvatarForUpload(croppedBytes);
    await ref.read(userProfileProvider.notifier).uploadAvatar(uploadBytes);
  }

  /// 统一处理保存中状态与错误提示，避免在每个操作里重复 try/catch。
  Future<void> _runSave(Future<void> Function() task) async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);
    try {
      await task();
    } on AvatarImageException {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileImageUnsupported)),
      );
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaveFailed)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _retryLoad() {
    ref.invalidate(userProfileProvider);
  }

  Future<void> _editNickname(UserProfile profile) async {
    // 保存成功即关闭对话框，资料已由 provider 更新，无需额外提示。
    await showDialog<bool>(
      context: context,
      builder: (_) => NicknameEditDialog(
        initialNickname: profile.nickname,
        onSave: ref.read(userProfileProvider.notifier).updateNickname,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profileState = ref.watch(userProfileProvider);
    final profile = profileState.value;
    final nicknameText = profile?.nickname;
    // 资料加载失败（如后端接口未部署或网络异常）时，入口仍可点击以重新加载，
    // 而不是静默失效。
    final isLoadFailed = profile == null && profileState.hasError;
    final VoidCallback? onRetry = isLoadFailed ? _retryLoad : null;

    return Column(
      children: [
        const SizedBox(height: AppSpacing.s),
        Semantics(
          button: true,
          label: l10n.profileChangeAvatar,
          child: GestureDetector(
            onTap: _isSaving
                ? null
                : profile != null
                ? () => _runSave(_changeAvatar)
                : onRetry,
            child: Stack(
              alignment: Alignment.center,
              children: [
                UserAvatar(size: _avatarSize, avatarUrl: profile?.avatarUrl),
                if (_isSaving)
                  Container(
                    width: _avatarSize,
                    height: _avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      child: Icon(
                        Icons.edit,
                        size: 14,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s,
              0,
              0,
              AppSpacing.s,
            ),
            child: Text(
              l10n.profileSection,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(l10n.profileNickname),
                subtitle: isLoadFailed
                    ? Text(l10n.profileLoadFailed)
                    : nicknameText == null
                    ? null
                    : Text(nicknameText),
                trailing: const Icon(Icons.chevron_right),
                onTap: profile != null ? () => _editNickname(profile) : onRetry,
              ),
              if (profile?.avatarUrl != null) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.profileRemoveAvatar),
                  enabled: !_isSaving,
                  onTap: () => _runSave(
                    () => ref.read(userProfileProvider.notifier).removeAvatar(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
