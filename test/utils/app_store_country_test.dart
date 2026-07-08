import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/utils/app_store_country.dart';

void main() {
  group('appStoreCountryFromStorefront', () {
    // storefront（RevenueCat）给 ISO 3166-1 alpha-3 大写，
    // iTunes Lookup 要 alpha-2 小写，需正确转换。

    test('美区 USA → us', () {
      expect(appStoreCountryFromStorefront('USA'), 'us');
    });

    test('中国区 CHN → cn', () {
      expect(appStoreCountryFromStorefront('CHN'), 'cn');
    });

    test('英国 GBR → gb', () {
      expect(appStoreCountryFromStorefront('GBR'), 'gb');
    });

    test('日本 JPN → jp', () {
      expect(appStoreCountryFromStorefront('JPN'), 'jp');
    });

    test('大小写不敏感、去空白', () {
      expect(appStoreCountryFromStorefront('usa'), 'us');
      expect(appStoreCountryFromStorefront(' Chn '), 'cn');
    });

    test('null / 空 → null（回退默认区）', () {
      expect(appStoreCountryFromStorefront(null), isNull);
      expect(appStoreCountryFromStorefront(''), isNull);
      expect(appStoreCountryFromStorefront('   '), isNull);
    });

    test('未知 / 非法码 → null（回退默认区）', () {
      expect(appStoreCountryFromStorefront('ZZZ'), isNull);
      expect(appStoreCountryFromStorefront('US'), isNull); // alpha-2 非本函数输入
    });
  });
}
