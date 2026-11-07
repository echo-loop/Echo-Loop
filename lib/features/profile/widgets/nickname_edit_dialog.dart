import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/nickname_validator.dart';

/// 昵称编辑对话框。保存成功时以 `pop(true)` 关闭。
class NicknameEditDialog extends StatefulWidget {
  const NicknameEditDialog({
    super.key,
    required this.initialNickname,
    required this.onSave,
  });

  final String? initialNickname;

  /// 保存回调，失败时应抛出异常，对话框会保持打开并提示用户。
  final Future<void> Function(String nickname) onSave;

  @override
  State<NicknameEditDialog> createState() => _NicknameEditDialogState();
}

class _NicknameEditDialogState extends State<NicknameEditDialog> {
  late final TextEditingController _controller;
  bool _isSaving = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNickname ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 不使用 TextField.maxLength：它按 UTF-16 计数，emoji 会被提前截断，
  // 与后端「按码点计 30」的规则不一致。长度由 validateNickname 统一判断。
  NicknameValidationError? get _validationError =>
      validateNickname(_controller.text);

  bool get _canSave {
    final error = _validationError;
    if (_isSaving || error != null) return false;
    return _controller.text.trim() != (widget.initialNickname ?? '').trim();
  }

  String? _errorText(AppLocalizations l10n) {
    if (_saveFailed) return l10n.profileSaveFailed;
    if (_controller.text.trim().isEmpty) return null;
    return switch (_validationError) {
      null => null,
      NicknameValidationError.empty => l10n.profileNicknameEmpty,
      NicknameValidationError.tooLong => l10n.profileNicknameTooLong,
      NicknameValidationError.containsControlCharacter =>
        l10n.profileNicknameInvalid,
    };
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _isSaving = true;
      _saveFailed = false;
    });
    try {
      await widget.onSave(_controller.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Exception {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.profileNickname),
      content: TextField(
        controller: _controller,
        autofocus: true,
        enabled: !_isSaving,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: l10n.profileNicknameHint,
          errorText: _errorText(l10n),
        ),
        onChanged: (_) => setState(() => _saveFailed = false),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
