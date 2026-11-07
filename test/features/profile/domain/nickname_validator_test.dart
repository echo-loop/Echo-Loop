import 'package:echo_loop/features/profile/domain/nickname_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateNickname', () {
    test('接受 1 到 30 个码点的昵称', () {
      expect(validateNickname('A'), isNull);
      expect(validateNickname('a' * 30), isNull);
    });

    test('超过 30 个码点时拒绝', () {
      expect(validateNickname('a' * 31), NicknameValidationError.tooLong);
    });

    test('emoji 按一个码点计算，不按 UTF-16 代理对计算', () {
      expect(validateNickname('😀' * 30), isNull);
      expect(validateNickname('😀' * 31), NicknameValidationError.tooLong);
    });

    test('首尾空白不计入长度，去除后为空时拒绝', () {
      expect(validateNickname('  Ann  '), isNull);
      expect(validateNickname('   '), NicknameValidationError.empty);
      expect(validateNickname(''), NicknameValidationError.empty);
    });

    test('内部换行和控制字符拒绝', () {
      expect(
        validateNickname('An\nn'),
        NicknameValidationError.containsControlCharacter,
      );
      expect(
        validateNickname('An\tn'),
        NicknameValidationError.containsControlCharacter,
      );
    });
  });
}
