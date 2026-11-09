import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/providers.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/study_stats_provider.dart';
import '../../../services/app_logger.dart';
import '../../../services/backend_dio.dart';
import '../../../services/runtime_endpoint_router.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../user_region/user_region_providers.dart';
import '../data/daily_check_in_share_image.dart';
import '../data/daily_share_background_store.dart';
import '../data/daily_share_background_repository.dart';
import '../data/daily_share_decoded_image_cache.dart';
import '../data/share_card_api.dart';
import '../domain/share_card_template.dart';
import 'daily_goal_check_in_provider.dart';

final dailyShareUserIdProvider = Provider<String?>(
  (ref) => ref.watch(
    supabaseSessionProvider.select((session) => session.value?.user.id),
  ),
);

final shareCardApiProvider = Provider<ShareCardRemoteDataSource>((ref) {
  final backend = createBackendDio(
    endpointRouter: runtimeEndpointRouter,
    apiLogTag: 'DAILY_SHARE',
  );
  final images = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  ref.onDispose(() {
    backend.close(force: true);
    images.close(force: true);
  });
  return ShareCardApi(backend, images);
});

final dailyShareBackgroundStoreProvider = Provider<DailyShareBackgroundStore>(
  (ref) => DailyShareBackgroundStore(),
);

final dailyShareBackgroundRepositoryProvider =
    Provider<DailyShareBackgroundRepository>(
      (ref) => DailyShareBackgroundRepository(
        ref.watch(shareCardApiProvider),
        ref.watch(dailyShareBackgroundStoreProvider),
      ),
    );

typedef DailyShareImageGenerator =
    Future<GeneratedDailyCheckInShareImage> Function({
      required ShareCardTemplate template,
      required DailyCheckInShareData data,
      required DailyCheckInShareAssets assets,
    });

final dailyShareDecodedImageCacheProvider =
    Provider<DailyShareDecodedImageCache>((ref) {
      final cache = DailyShareDecodedImageCache();
      ref.onDispose(cache.dispose);
      return cache;
    });

final dailyShareImageGeneratorProvider = Provider<DailyShareImageGenerator>((
  ref,
) {
  final fonts = DailyShareFontLoader();
  final cache = ref.watch(dailyShareDecodedImageCacheProvider);
  return ({required template, required data, required assets}) async {
    await fonts.load();
    return generateDailyCheckInShareImage(
      template: template,
      data: data,
      assets: assets,
      decodedImageCache: cache,
    );
  };
});

/// 独立的时钟入口避免真实日期或开发时光机影响测试及分享的有效期。
final dailyShareNowProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

enum DailyShareStatus { idle, preparing, ready, failed }

class PreparedDailyCheckInShare {
  const PreparedDailyCheckInShare({
    required this.userId,
    required this.date,
    required this.template,
    required this.image,
  });
  final String userId;
  final DateTime date;
  final ShareCardTemplate template;
  final GeneratedDailyCheckInShareImage image;

  PreparedDailyCheckInShare clone() => PreparedDailyCheckInShare(
    userId: userId,
    date: date,
    template: template,
    image: image.clone(),
  );
}

class DailyCheckInShareState {
  const DailyCheckInShareState({
    this.status = DailyShareStatus.idle,
    this.card,
    this.isChanging = false,
    this.isRefreshing = false,
    this.noAvailableCards = false,
    this.failure,
  });
  final DailyShareStatus status;
  final PreparedDailyCheckInShare? card;
  final bool isChanging;
  final bool isRefreshing;
  final bool noAvailableCards;
  final Object? failure;
}

final dailyCheckInShareProvider =
    NotifierProvider<DailyCheckInShareNotifier, DailyCheckInShareState>(
      DailyCheckInShareNotifier.new,
    );

typedef _DailyShareRenderInput = ({
  String templateId,
  DateTime date,
  int totalMinutes,
  int inputMinutes,
  int outputMinutes,
  int streak,
  String nickname,
  Uint8List? avatar,
  bool isChinese,
  String nativeLanguage,
  bool isChina,
});

/// 常驻准备任务只生成图片，不决定是否弹窗；完成回调不会触发补弹。
class DailyCheckInShareNotifier extends Notifier<DailyCheckInShareState> {
  int _generation = 0;
  GeneratedDailyCheckInShareImage? _ownedImage;
  Future<void>? _preparing;
  Timer? _expiryTimer;
  _DailyShareRenderInput? _renderedInput;
  bool _refreshRequested = false;
  int _assetEpoch = 0;
  String? _avatarUrl;
  Uint8List? _avatarBytes;
  DailyShareDecodedImageCache? _decodedCache;
  final Map<String, Future<Uint8List>> _bundledAssets = {};

  Future<Uint8List> _asset(String path) {
    return _bundledAssets.putIfAbsent(path, () async {
      try {
        final asset = await rootBundle.load(path);
        return asset.buffer.asUint8List(
          asset.offsetInBytes,
          asset.lengthInBytes,
        );
      } on Object {
        _bundledAssets.remove(path);
        rethrow;
      }
    });
  }

  void _resetInputs() {
    _assetEpoch++;
    _decodedCache?.clear();
    _avatarUrl = null;
    _avatarBytes = null;
    _renderedInput = null;
    _refreshRequested = false;
  }

  void _prepareAvatar(String? url, String userId) {
    if (_avatarUrl == url) return;
    _avatarUrl = url;
    _avatarBytes = null;
    if (url == null) return;
    final epoch = _assetEpoch;
    final api = ref.read(shareCardApiProvider);
    unawaited(() async {
      final watch = Stopwatch()..start();
      try {
        final bytes = await api.downloadImage(url);
        if (!ref.mounted ||
            epoch != _assetEpoch ||
            _avatarUrl != url ||
            ref.read(dailyShareUserIdProvider) != userId) {
          return;
        }
        _avatarBytes = bytes;
        AppLogger.log(
          'DailyShare',
          '头像后台下载完成 durationMs=${watch.elapsedMilliseconds}',
        );
        unawaited(prepare(refresh: true));
      } on Object catch (error, stackTrace) {
        // 头像是可选装饰，失败不阻塞成品；相同 URL 不随统计变化重复重试。
        AppLogger.log('DailyShare', '头像后台下载失败，保留占位: $error\n$stackTrace');
      }
    }());
  }

  @override
  DailyCheckInShareState build() {
    _decodedCache = ref.read(dailyShareDecodedImageCacheProvider);
    final userId = ref.watch(dailyShareUserIdProvider);
    _generation++;
    _preparing = null;
    _resetInputs();
    ref.onDispose(() {
      _generation++;
      _expiryTimer?.cancel();
      _ownedImage?.dispose();
      _ownedImage = null;
      _resetInputs();
    });
    if (userId == null) return const DailyCheckInShareState();
    ref.watch(studyTimeServiceProvider);
    ref.listen(
      appSettingsProvider.select(
        (settings) => (settings.locale, settings.nativeLanguage),
      ),
      (_, _) => _invalidateComposition(),
    );
    ref.listen(isChinaUserProvider, (_, _) => _invalidateComposition());
    _scheduleExpiry();
    ref.listen(dailyGoalCheckInProvider, (_, event) {
      if (event != null &&
          _sameDay(event.date, ref.read(dailyShareNowProvider)())) {
        unawaited(prepare());
      }
    });
    // 后台刷新保留已完成的卡片，只有实际绘制内容变化才重新合成。
    ref.listen(studyStatsProvider, (previous, next) {
      if (next.value?.isTodayCheckedIn == true &&
          previous?.value != next.value) {
        unawaited(prepare(refresh: true));
      }
    });
    ref.listen(userProfileProvider, (previous, next) {
      if (previous?.value != next.value && next.hasValue) {
        unawaited(prepare(refresh: true));
      }
    });
    final generation = _generation;
    scheduleMicrotask(() {
      if (ref.mounted && generation == _generation) unawaited(prepare());
    });
    return const DailyCheckInShareState();
  }

  /// 语言和二维码地区只影响合成，不清理背景、头像及固定资源缓存。
  void _invalidateComposition() {
    _generation++;
    _preparing = null;
    _refreshRequested = false;
    _renderedInput = null;
    _ownedImage?.dispose();
    _ownedImage = null;
    state = const DailyCheckInShareState();
    unawaited(prepare(refresh: true));
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final now = ref.read(dailyShareNowProvider)();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _expiryTimer = Timer(midnight.difference(now), () {
      if (!ref.mounted) return;
      clear();
      unawaited(
        ref
            .read(dailyShareBackgroundRepositoryProvider)
            .removeExpired(ref.read(dailyShareNowProvider)()),
      );
      _scheduleExpiry();
    });
  }

  bool get hasCurrentCard {
    final card = state.card;
    return state.status == DailyShareStatus.ready &&
        card != null &&
        card.userId == ref.read(dailyShareUserIdProvider) &&
        _sameDay(card.date, ref.read(dailyShareNowProvider)());
  }

  /// 返回 false 表示没有其它模板；异常由调用入口提示，旧卡保持可用。
  Future<bool> changeCard() async {
    if (!hasCurrentCard || _preparing != null) return false;
    final oldId = state.card!.template.id;
    await _startPreparation(changeFrom: oldId);
    final failure = state.failure;
    if (failure != null) throw failure;
    return hasCurrentCard && state.card!.template.id != oldId;
  }

  Future<void> prepare({bool refresh = false}) {
    if (ref.read(dailyShareUserIdProvider) == null) return Future<void>.value();
    if (_preparing != null) {
      _refreshRequested |= refresh;
      return _preparing!;
    }
    if (hasCurrentCard && !refresh) return Future<void>.value();
    return _startPreparation();
  }

  Future<void> _startPreparation({String? changeFrom}) {
    final future = _prepare(changeFrom: changeFrom);
    _preparing = future;
    return future.whenComplete(() {
      if (!identical(_preparing, future)) return;
      _preparing = null;
      if (_refreshRequested && ref.mounted) {
        _refreshRequested = false;
        unawaited(prepare(refresh: true));
      }
    });
  }

  Future<void> _prepare({String? changeFrom}) async {
    final userId = ref.read(dailyShareUserIdProvider);
    if (userId == null) return;
    final generation = ++_generation;
    final now = ref.read(dailyShareNowProvider)();
    final date = DateTime(now.year, now.month, now.day);
    final service = ref.read(studyTimeServiceProvider);
    final backgrounds = ref.read(dailyShareBackgroundRepositoryProvider);
    final generate = ref.read(dailyShareImageGeneratorProvider);
    final settings = ref.read(appSettingsProvider);
    final isChina = ref.read(isChinaUserProvider);
    final watch = Stopwatch()..start();
    final oldCard = hasCurrentCard ? state.card : null;
    state = DailyCheckInShareState(
      status: oldCard == null
          ? DailyShareStatus.preparing
          : DailyShareStatus.ready,
      card: oldCard,
      isRefreshing: oldCard != null && changeFrom == null,
      isChanging: changeFrom != null,
    );
    try {
      if (oldCard == null && !await service.isDailyGoalCheckedIn(date)) {
        if (_isCurrent(generation, userId, date)) {
          state = const DailyCheckInShareState();
        }
        return;
      }
      if (!_isCurrent(generation, userId, date)) return;
      final canReuse =
          changeFrom == null && backgrounds.hasCurrentBackground(date);
      final resourceWatch = Stopwatch()..start();
      final cached = changeFrom == null
          ? await backgrounds.getToday(date)
          : await backgrounds.getRandom(changeFrom);
      if (!_isCurrent(generation, userId, date)) return;
      final template = cached.template;
      if (changeFrom == template.id) {
        state = DailyCheckInShareState(
          status: DailyShareStatus.ready,
          card: oldCard,
        );
        return;
      }
      final background = cached.bytes;
      AppLogger.log(
        'DailyShare',
        '模板背景准备完成 内存命中=$canReuse 耗时=${resourceWatch.elapsedMilliseconds}ms',
      );
      final stats =
          ref.read(studyStatsProvider).value ??
          await ref.read(studyStatsProvider.future);
      if (!_isCurrent(generation, userId, date)) return;
      if (stats == null) throw StateError('分享图片缺少学习统计');
      // 此前排队的更新已包含在即将读取的快照中，只有后续变化才需追加任务。
      _refreshRequested = false;
      final snapshot = ref.read(userProfileProvider).value;
      final profile = snapshot?.userId == userId ? snapshot : null;
      _prepareAvatar(profile?.avatarUrl, userId);
      final avatar = _avatarBytes;
      final isChinese = resolveUiLocale(settings.locale).languageCode == 'zh';
      // 与生成器显示口径一致；秒数及未绘制的周统计变化不产生新图片。
      final input = _currentRenderInput(template, date);
      if (oldCard != null && _renderedInput == input) {
        state = DailyCheckInShareState(
          status: DailyShareStatus.ready,
          card: oldCard,
        );
        AppLogger.log(
          'DailyShare',
          '复用分享成品，绘制内容未变化 durationMs=${watch.elapsedMilliseconds}',
        );
        return;
      }
      final logo = await _asset('assets/icon/app-icon-1024-alpha.png');
      final qr = await _asset(dailyShareQrAsset(isChina));
      if (!_isCurrent(generation, userId, date)) return;
      final image = await generate(
        template: template,
        data: DailyCheckInShareData(
          date: date,
          totalSeconds: stats.todaySeconds,
          inputSeconds: stats.todayInputSeconds,
          outputSeconds: stats.todayOutputSeconds,
          streak: stats.streak,
          nickname: profile?.nickname,
          isChinese: isChinese,
          nativeLanguage: settings.nativeLanguage,
        ),
        assets: DailyCheckInShareAssets(
          background: background,
          avatar: avatar,
          logo: logo,
          qrCode: qr,
        ),
      );
      if (!_isCurrent(generation, userId, date) ||
          (_refreshRequested &&
              changeFrom == null &&
              _currentRenderInput(template, date) != input)) {
        image.dispose();
        return;
      }
      if (_currentRenderInput(template, date) == input) {
        _refreshRequested = false;
      }
      _ownedImage?.dispose();
      _ownedImage = image;
      _renderedInput = input;
      if (changeFrom != null) {
        unawaited(backgrounds.rememberSelection(date, cached));
      }
      state = DailyCheckInShareState(
        status: DailyShareStatus.ready,
        card: PreparedDailyCheckInShare(
          userId: userId,
          date: date,
          template: template,
          image: image,
        ),
      );
      AppLogger.log(
        'DailyShare',
        '今日分享图片已准备完成 backgroundCache=$canReuse totalMs=${watch.elapsedMilliseconds}',
      );
    } on Object catch (error, stackTrace) {
      // 后台准备是独立边界：失败只更新分享状态，不能中断学习或打卡。
      AppLogger.log('DailyShare', '准备分享图片失败: $error\n$stackTrace');
      if (!_isCurrent(generation, userId, date)) return;
      state = DailyCheckInShareState(
        status: oldCard != null
            ? DailyShareStatus.ready
            : DailyShareStatus.failed,
        card: oldCard,
        noAvailableCards:
            error is DioException &&
            switch (error.response?.data) {
              {'code': 'no_available_cards'} => true,
              _ => false,
            },
        failure: error,
      );
    }
  }

  _DailyShareRenderInput? _currentRenderInput(
    ShareCardTemplate template,
    DateTime date,
  ) {
    final stats = ref.read(studyStatsProvider).value;
    if (stats == null) return null;
    final userId = ref.read(dailyShareUserIdProvider);
    final snapshot = ref.read(userProfileProvider).value;
    final profile = snapshot?.userId == userId ? snapshot : null;
    final settings = ref.read(appSettingsProvider);
    final isChina = ref.read(isChinaUserProvider);
    final isChinese = resolveUiLocale(settings.locale).languageCode == 'zh';
    final avatar = _avatarUrl == profile?.avatarUrl ? _avatarBytes : null;
    return (
      templateId: template.id,
      date: date,
      totalMinutes: dailyShareDisplayMinutes(stats.todaySeconds),
      inputMinutes: dailyShareDisplayMinutes(
        math.min(stats.todayInputSeconds, stats.todaySeconds),
      ),
      outputMinutes: dailyShareDisplayMinutes(
        math.min(stats.todayOutputSeconds, stats.todaySeconds),
      ),
      streak: stats.streak,
      nickname: profile?.nickname?.trim() ?? '',
      avatar: avatar,
      isChinese: isChinese,
      nativeLanguage: settings.nativeLanguage,
      isChina: isChina,
    );
  }

  bool _isCurrent(int generation, String userId, DateTime date) =>
      ref.mounted &&
      _generation == generation &&
      ref.read(dailyShareUserIdProvider) == userId &&
      _sameDay(date, ref.read(dailyShareNowProvider)());

  void clear() {
    _generation++;
    _resetInputs();
    _preparing = null;
    _ownedImage?.dispose();
    _ownedImage = null;
    state = const DailyCheckInShareState();
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
