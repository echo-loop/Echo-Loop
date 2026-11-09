import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/config/client_distribution.dart';
import 'package:echo_loop/screens/settings_screen.dart';

void main() {
  group('showsRatingEntry', () {
    test('iOS 所有渠道保持显示', () {
      expect(
        showsRatingEntry(TargetPlatform.iOS, ClientDistribution.appStore),
        isTrue,
      );
      expect(showsRatingEntry(TargetPlatform.iOS, null), isTrue);
    });

    test('Android Google Play 包显示', () {
      expect(
        showsRatingEntry(TargetPlatform.android, ClientDistribution.play),
        isTrue,
      );
    });

    test('Android 直装 APK 不显示', () {
      expect(
        showsRatingEntry(TargetPlatform.android, ClientDistribution.direct),
        isFalse,
      );
    });

    test('Android 渠道未注入时不显示', () {
      expect(showsRatingEntry(TargetPlatform.android, null), isFalse);
    });

    test('其他平台不显示', () {
      expect(
        showsRatingEntry(TargetPlatform.macOS, ClientDistribution.direct),
        isFalse,
      );
    });
  });
}
