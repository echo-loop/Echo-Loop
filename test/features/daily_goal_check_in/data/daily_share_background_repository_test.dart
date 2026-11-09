import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:echo_loop/features/daily_goal_check_in/domain/share_card_template.dart';

import 'package:echo_loop/features/daily_goal_check_in/data/daily_share_background_repository.dart';
import 'package:echo_loop/features/daily_goal_check_in/data/daily_share_background_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../share_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ShareTestApi api;
  late DailyShareBackgroundStore store;
  final date = DateTime(2026, 11, 9);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'daily-share-repository-',
    );
    api = ShareTestApi();
    store = DailyShareBackgroundStore(resolveDirectory: () async => directory);
  });
  tearDown(() async => directory.delete(recursive: true));

  test('重启后从真实磁盘恢复，同日不重新请求模板或背景', () async {
    final first = DailyShareBackgroundRepository(api, store);
    final initial = await first.getToday(date);
    // 读取排在后台写入之后，模拟已持久化的完整启动周期。
    expect(await store.read(date), isNotNull);
    final restarted = DailyShareBackgroundRepository(
      api,
      DailyShareBackgroundStore(resolveDirectory: () async => directory),
    );
    final restored = await restarted.getToday(date);
    expect(restored.template.id, initial.template.id);
    expect(restored.bytes, initial.bytes);
    expect(api.todayCalls, 1);
    expect(api.downloadCalls, 1);
    expect(await restarted.getToday(date), same(restored));
  });

  test('并发首次加载只请求一次，下一天重新加载并清理旧日', () async {
    final repository = DailyShareBackgroundRepository(api, store);
    final cards = await Future.wait([
      repository.getToday(date),
      repository.getToday(date),
      repository.getToday(date),
    ]);
    expect(cards[0], same(cards[1]));
    expect(api.todayCalls, 1);
    await repository.getToday(DateTime(2026, 11, 10));
    expect(api.todayCalls, 2);
    expect(await store.read(DateTime(2026, 11, 10)), isNotNull);
  });

  test('换卡只有成功选择后持久化，下次重启保留选择', () async {
    final repository = DailyShareBackgroundRepository(api, store);
    final original = await repository.getToday(date);
    final random = await repository.getRandom(original.template.id);
    expect((await repository.getToday(date)).template.id, original.template.id);
    await repository.rememberSelection(date, random);
    final restarted = DailyShareBackgroundRepository(api, store);
    expect((await restarted.getToday(date)).template.id, random.template.id);
    expect(api.todayCalls, 1);
    expect(api.downloadCalls, 2);
  });

  test('清缓存期间的旧响应不能重新写入持久缓存', () async {
    api.pendingTemplate = Completer<ShareCardTemplate>();
    final repository = DailyShareBackgroundRepository(api, store);
    final pending = repository.getToday(date);
    while (api.todayCalls == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await repository.clear();
    api.pendingTemplate!.complete(api.template);
    await pending;
    expect(await store.read(date), isNull);
    expect(repository.hasCurrentBackground(date), isFalse);
  });

  test('缓存写入失败不阻断本次已下载背景', () async {
    final repository = DailyShareBackgroundRepository(api, _UnwritableStore());
    final background = await repository.getToday(date);
    expect(background.template.id, api.template.id);
    expect(background.bytes, shareTestPng);
    await Future<void>.delayed(Duration.zero);
    expect(repository.hasCurrentBackground(date), isTrue);
  });
}

class _UnwritableStore extends ShareTestBackgroundStore {
  @override
  Future<void> write(
    DateTime date,
    ShareCardTemplate template,
    Uint8List bytes,
  ) async {
    throw const FileSystemException('test read-only disk');
  }
}
