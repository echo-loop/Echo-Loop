import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/app_update_info.dart';
import 'package:echo_loop/providers/app_update_provider.dart';
import 'package:echo_loop/utils/version_compare.dart';

void main() {
  group('AppUpdate._determineUpdateType', () {
    const info = AppUpdateInfo(latestVersion: '2.0.0', minimumVersion: '1.5.0');

    test('低于最低版本时强制更新', () {
      expect(
        AppUpdate.determineUpdateType('1.0.0', info),
        AppUpdateType.forceUpdate,
      );
    });

    test('低于最新版但高于最低版本时软更新', () {
      expect(
        AppUpdate.determineUpdateType('1.5.0', info),
        AppUpdateType.softUpdate,
      );
    });

    test('高于最新版时无需更新', () {
      expect(AppUpdate.determineUpdateType('2.0.0', info), AppUpdateType.none);
    });

    test('高于最新版时无需更新（更高版本）', () {
      expect(AppUpdate.determineUpdateType('3.0.0', info), AppUpdateType.none);
    });

    test('恰好等于最低版本时软更新', () {
      expect(
        AppUpdate.determineUpdateType('1.5.0', info),
        AppUpdateType.softUpdate,
      );
    });

    test('在最低和最新之间时软更新', () {
      expect(
        AppUpdate.determineUpdateType('1.9.0', info),
        AppUpdateType.softUpdate,
      );
    });
  });

  group('版本比较辅助验证', () {
    test('compareVersions 正确比较 semver', () {
      expect(compareVersions('1.0.0', '1.5.0'), lessThan(0));
      expect(compareVersions('1.5.0', '2.0.0'), lessThan(0));
      expect(compareVersions('2.0.0', '2.0.0'), 0);
    });
  });

  group('构建号场景（不参与比较）', () {
    // 设计：versionName 唯一标识一次发布，buildNumber 是平台内部机制
    // （Android versionCode、iOS CFBundleVersion）。版本比较只看 versionName。

    test('同 versionName 不同构建号视为相等，无需更新', () {
      const info = AppUpdateInfo(
        latestVersion: '1.0.9+2',
        minimumVersion: '1.0.0',
      );
      expect(
        AppUpdate.determineUpdateType('1.0.9+1', info),
        AppUpdateType.none,
      );
    });

    test('本地带构建号、远端不带，相等无需更新', () {
      const info = AppUpdateInfo(
        latestVersion: '1.0.9',
        minimumVersion: '1.0.0',
      );
      expect(
        AppUpdate.determineUpdateType('1.0.9+1', info),
        AppUpdateType.none,
      );
    });

    test('本地不带构建号、远端带，相等无需更新', () {
      const info = AppUpdateInfo(
        latestVersion: '1.0.9+5',
        minimumVersion: '1.0.0',
      );
      expect(AppUpdate.determineUpdateType('1.0.9', info), AppUpdateType.none);
    });

    test('patch 升级，构建号被忽略', () {
      const info = AppUpdateInfo(
        latestVersion: '1.0.9+2',
        minimumVersion: '1.0.0',
      );
      expect(
        AppUpdate.determineUpdateType('1.0.8+99', info),
        AppUpdateType.softUpdate,
      );
    });

    test('本地 patch 更高，构建号被忽略', () {
      const info = AppUpdateInfo(
        latestVersion: '1.0.8+5',
        minimumVersion: '1.0.0',
      );
      expect(AppUpdate.determineUpdateType('1.0.9', info), AppUpdateType.none);
    });
  });
}
