import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/services/app_update_migration.dart';

void main() {
  group('AppUpdateMigrationRunner', () {
    test('清理已废弃的 TTS 模型下载状态，不影响其它偏好', () async {
      SharedPreferences.setMockInitialValues({
        'kokoro_model_downloaded_fp32': true,
        'piper_model_downloaded_en_US-amy-medium': true,
        'offline_asr_downloaded_whisper-base-en-int8': true,
        'offline_asr_selected_model_id': 'whisper-base-en-int8',
      });
      final prefs = await SharedPreferences.getInstance();

      await removeLegacyTtsModelDownloadFlags(prefs);

      expect(prefs.containsKey('kokoro_model_downloaded_fp32'), isFalse);
      expect(
        prefs.containsKey('piper_model_downloaded_en_US-amy-medium'),
        isFalse,
      );
      expect(
        prefs.getBool('offline_asr_downloaded_whisper-base-en-int8'),
        isTrue,
      );
      expect(
        prefs.getString('offline_asr_selected_model_id'),
        'whisper-base-en-int8',
      );
    });

    test('按顺序执行未完成迁移并记录最新版本', () async {
      SharedPreferences.setMockInitialValues({appUpdateMigrationVersionKey: 1});
      final prefs = await SharedPreferences.getInstance();
      final applied = <int>[];
      final runner = AppUpdateMigrationRunner(
        prefs: prefs,
        migrations: [
          AppUpdateMigration(
            version: 1,
            name: 'one',
            action: () async => applied.add(1),
          ),
          AppUpdateMigration(
            version: 2,
            name: 'two',
            action: () async => applied.add(2),
          ),
          AppUpdateMigration(
            version: 3,
            name: 'three',
            action: () async => applied.add(3),
          ),
        ],
      );

      final version = await runner.migrate();

      expect(applied, [2, 3]);
      expect(version, 3);
      expect(prefs.getInt(appUpdateMigrationVersionKey), 3);
    });

    test('已完成迁移不会重复执行', () async {
      SharedPreferences.setMockInitialValues({appUpdateMigrationVersionKey: 2});
      final prefs = await SharedPreferences.getInstance();
      var executions = 0;
      final runner = AppUpdateMigrationRunner(
        prefs: prefs,
        migrations: [
          AppUpdateMigration(
            version: 1,
            name: 'one',
            action: () async => executions++,
          ),
          AppUpdateMigration(
            version: 2,
            name: 'two',
            action: () async => executions++,
          ),
        ],
      );

      await runner.migrate();

      expect(executions, 0);
    });

    test('迁移失败时不推进版本，下一次可从失败步骤重试', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var shouldFail = true;
      var executions = 0;
      final migrations = [
        AppUpdateMigration(
          version: 1,
          name: 'one',
          action: () async => executions++,
        ),
        AppUpdateMigration(
          version: 2,
          name: 'two',
          action: () async {
            if (shouldFail) throw StateError('temporary failure');
            executions++;
          },
        ),
      ];

      await expectLater(
        AppUpdateMigrationRunner(
          prefs: prefs,
          migrations: migrations,
        ).migrate(),
        throwsStateError,
      );
      expect(prefs.getInt(appUpdateMigrationVersionKey), 1);
      expect(executions, 1);

      shouldFail = false;
      await AppUpdateMigrationRunner(
        prefs: prefs,
        migrations: migrations,
      ).migrate();
      expect(prefs.getInt(appUpdateMigrationVersionKey), 2);
      expect(executions, 2);
    });

    test('拒绝不连续的迁移版本', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final runner = AppUpdateMigrationRunner(
        prefs: prefs,
        migrations: [
          AppUpdateMigration(version: 1, name: 'one', action: () async {}),
          AppUpdateMigration(version: 3, name: 'three', action: () async {}),
        ],
      );

      await expectLater(runner.migrate(), throwsStateError);
    });
  });

  group('currentAppUpdateMigrationVersion', () {
    // 备份会记录迁移链真实完成的版本，常量必须与迁移链末尾保持一致，
    // 否则应用会拒绝恢复自己生成的备份（见 docs/troubleshooting.md）。
    test('与已注册迁移链的最后一个版本一致', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final migrations = buildAppUpdateMigrations(prefs, isAndroid: false);

      expect(migrations.last.version, currentAppUpdateMigrationVersion);
    });
  });
}
