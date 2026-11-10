import 'dart:async';
import 'dart:io';

import '../../../services/app_logger.dart';
import 'daily_share_background_store.dart';
import 'share_card_api.dart';

/// 公开模板背景独立于账号和语言；先读当日磁盘缓存，并合并并发下载。
class DailyShareBackgroundRepository {
  DailyShareBackgroundRepository(this.api, this.store);

  final ShareCardRemoteDataSource api;
  final DailyShareBackgroundStore store;
  DateTime? _date;
  CachedDailyShareBackground? _cached;
  Future<CachedDailyShareBackground>? _pending;
  int _generation = 0;

  bool hasCurrentBackground(DateTime date) =>
      _cached != null && _date == DateTime(date.year, date.month, date.day);

  Future<CachedDailyShareBackground> getToday(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (_date != day) {
      _generation++;
      _date = day;
      _cached = null;
      _pending = null;
    }
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    final pending = _pending;
    if (pending != null) return pending;
    final generation = _generation;
    final loading = _load(day, generation);
    _pending = loading;
    return loading.whenComplete(() {
      if (identical(_pending, loading)) _pending = null;
    });
  }

  Future<CachedDailyShareBackground> _load(
    DateTime date,
    int generation,
  ) async {
    final watch = Stopwatch()..start();
    CachedDailyShareBackground? result;
    try {
      result = await store.read(date);
    } on FileSystemException catch (error) {
      AppLogger.log('DailyShare', '读取背景缓存失败，改用网络: ${error.osError?.errorCode}');
    }
    final hit = result != null;
    if (result == null) {
      final template = await api.getToday(date);
      result = CachedDailyShareBackground(
        template,
        await api.downloadImage(template.imageUrl),
      );
      if (generation == _generation) unawaited(_write(date, result));
    }
    if (generation == _generation) _cached = result;
    AppLogger.log(
      'DailyShare',
      '今日背景加载完成 磁盘命中=$hit 耗时=${watch.elapsedMilliseconds}ms',
    );
    return result;
  }

  Future<CachedDailyShareBackground> getRandom(String excludeId) async {
    final template = await api.getRandom(excludeId);
    if (template.id == excludeId) {
      final previous = _cached;
      if (previous != null && previous.template.id == excludeId) {
        return previous;
      }
    }
    return CachedDailyShareBackground(
      template,
      await api.downloadImage(template.imageUrl),
    );
  }

  /// 仅在换卡渲染成功后记住选择，失败不能覆盖当前可用背景。
  Future<void> rememberSelection(
    DateTime date,
    CachedDailyShareBackground background,
  ) async {
    final day = DateTime(date.year, date.month, date.day);
    if (_date != day) return;
    _cached = background;
    await _write(day, background);
  }

  Future<void> _write(
    DateTime date,
    CachedDailyShareBackground background,
  ) async {
    try {
      await store.write(date, background.template, background.bytes);
    } on FileSystemException catch (error) {
      // 缓存写入失败不能阻断已下载的有效资源。
      AppLogger.log(
        'DailyShare',
        '保存背景缓存失败，下次启动可重试: ${error.osError?.errorCode}',
      );
    } on FormatException catch (error) {
      if (identical(_cached, background)) _cached = null;
      AppLogger.log('DailyShare', '背景资源校验失败，不保留缓存: $error');
    }
  }

  Future<void> removeExpired(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    if (_date != day) {
      _generation++;
      _date = day;
      _cached = null;
      _pending = null;
    }
    try {
      await store.removeExpired(day);
    } on FileSystemException catch (error) {
      AppLogger.log('DailyShare', '清理过期背景失败: ${error.osError?.errorCode}');
    }
  }

  Future<void> clear() async {
    _generation++;
    _cached = null;
    _pending = null;
    await store.clear();
  }
}
