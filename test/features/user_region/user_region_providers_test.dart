import 'package:echo_loop/features/user_region/user_region.dart';
import 'package:echo_loop/features/user_region/user_region_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the system country code CN is China', () {
    expect(isChinaSystemRegion('CN'), isTrue);
    expect(isChinaSystemRegion(' cn '), isTrue);
    expect(isChinaSystemRegion('US'), isFalse);
    expect(isChinaSystemRegion('CHN'), isFalse);
    expect(isChinaSystemRegion('zh'), isFalse);
    expect(isChinaSystemRegion(null), isFalse);
    expect(isChinaSystemRegion(''), isFalse);
  });

  test('isChinaUserProvider reads the system Region country code', () {
    final chinaContainer = ProviderContainer(
      overrides: [
        userRegionDeviceCountryCodeProvider.overrideWithValue(() => 'CN'),
      ],
    );
    addTearDown(chinaContainer.dispose);

    expect(chinaContainer.read(isChinaUserProvider), isTrue);
  });

  test('unknown or non-China system Region selects global', () {
    for (final countryCode in <String?>[null, '', 'US', 'CHN']) {
      final container = ProviderContainer(
        overrides: [
          userRegionDeviceCountryCodeProvider.overrideWithValue(
            () => countryCode,
          ),
        ],
      );
      expect(container.read(isChinaUserProvider), isFalse);
      container.dispose();
    }
  });

  test('a failed system Region read defaults to global', () {
    final container = ProviderContainer(
      overrides: [
        userRegionDeviceCountryCodeProvider.overrideWithValue(
          () => throw StateError('locale unavailable'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(isChinaUserProvider), isFalse);
  });
}
