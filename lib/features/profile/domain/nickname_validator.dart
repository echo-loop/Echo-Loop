/// 昵称长度上限（按 Unicode 码点计，emoji 计 1）。与后端 `/api/v1/me/profile` 保持一致。
const int nicknameMaxLength = 30;

enum NicknameValidationError { empty, tooLong, containsControlCharacter }

/// 包含控制字符、行分隔符与段分隔符；后端同样拒绝这些字符。
final RegExp _controlCharacterPattern = RegExp(
  r'[\p{Cc}\p{Zl}\p{Zp}]',
  unicode: true,
);

/// 校验昵称输入，仅用于即时提示；最终以后端返回的 400 为准。
///
/// 先 trim 再校验，与后端「trim 后 1–30 码点」的规则一致。
/// 返回 `null` 表示合法。
NicknameValidationError? validateNickname(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return NicknameValidationError.empty;
  if (trimmed.runes.length > nicknameMaxLength) {
    return NicknameValidationError.tooLong;
  }
  if (_controlCharacterPattern.hasMatch(trimmed)) {
    return NicknameValidationError.containsControlCharacter;
  }
  return null;
}
