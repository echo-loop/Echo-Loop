import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/review_statistics/review_statistics_provider.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('统计加载失败时记录异常上下文', () async {
    final db = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
    addTearDown(db.close);
    await db.customStatement('DROP TABLE memory_schedules');
    AppLogger.instance.clear();
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(reviewStatisticsProvider.future),
      throwsA(anything),
    );

    expect(
      AppLogger.instance.entries.any(
        (entry) =>
            entry.tag == 'ReviewStatistics' && entry.message.contains('加载失败'),
      ),
      isTrue,
    );
  });
}
