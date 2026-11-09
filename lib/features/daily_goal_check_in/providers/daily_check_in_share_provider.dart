import 'dart:async';

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
import '../../profile/domain/user_profile.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../user_region/user_region_providers.dart';
import '../data/daily_check_in_share_image.dart';
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

typedef DailyShareImageGenerator =
    Future<GeneratedDailyCheckInShareImage> Function({
      required ShareCardTemplate template,
      required DailyCheckInShareData data,
      required DailyCheckInShareAssets assets,
    });

final dailyShareImageGeneratorProvider = Provider<DailyShareImageGenerator>((
  ref,
) {
  final fonts = DailyShareFontLoader();
  return ({required template, required data, required assets}) async {
    await fonts.load();
    return generateDailyCheckInShareImage(
      template: template,
      data: data,
      assets: assets,
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
    this.noAvailableCards = false,
    this.failure,
  });
  final DailyShareStatus status;
  final PreparedDailyCheckInShare? card;
  final bool isChanging;
  final bool noAvailableCards;
  final Object? failure;
}

final dailyCheckInShareProvider =
    NotifierProvider<DailyCheckInShareNotifier, DailyCheckInShareState>(
      DailyCheckInShareNotifier.new,
    );

/// 常驻准备任务只生成图片，不决定是否弹窗；完成回调不会触发补弹。
class DailyCheckInShareNotifier extends Notifier<DailyCheckInShareState> {
  int _generation = 0;
  GeneratedDailyCheckInShareImage? _ownedImage;
  Future<void>? _preparing;
  Timer? _expiryTimer;
  ShareCardTemplate? _cachedTemplate;
  Uint8List? _cachedBackground;
  DateTime? _cachedDate;

  @override
  DailyCheckInShareState build() {
    final userId = ref.watch(dailyShareUserIdProvider);
    _generation++;
    _preparing = null;
    ref.onDispose(() {
      _generation++;
      _expiryTimer?.cancel();
      _ownedImage?.dispose();
      _ownedImage = null;
      _cachedTemplate = null;
      _cachedBackground = null;
      _cachedDate = null;
    });
    if (userId == null) return const DailyCheckInShareState();
    ref.watch(studyTimeServiceProvider);
    ref.watch(
      appSettingsProvider.select(
        (settings) => (settings.locale, settings.nativeLanguage),
      ),
    );
    ref.watch(isChinaUserProvider);
    _scheduleExpiry();
    ref.listen(dailyGoalCheckInProvider, (_, event) {
      if (event != null &&
          _sameDay(event.date, ref.read(dailyShareNowProvider)())) {
        unawaited(prepare());
      }
    });
    // 统计更新后在后台重新合成；重新准备期间首页检查会跳过自动弹出。
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

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final now = ref.read(dailyShareNowProvider)();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _expiryTimer = Timer(midnight.difference(now), () {
      if (!ref.mounted) return;
      clear();
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
    if (_preparing != null) return _preparing!;
    if (hasCurrentCard && !refresh) return Future<void>.value();
    return _startPreparation(reuseBackground: refresh);
  }

  Future<void> _startPreparation({
    String? changeFrom,
    bool reuseBackground = false,
  }) {
    final future = _prepare(
      changeFrom: changeFrom,
      reuseBackground: reuseBackground,
    );
    _preparing = future;
    return future.whenComplete(() {
      if (identical(_preparing, future)) _preparing = null;
    });
  }

  Future<void> _prepare({
    String? changeFrom,
    required bool reuseBackground,
  }) async {
    final userId = ref.read(dailyShareUserIdProvider);
    if (userId == null) return;
    final generation = ++_generation;
    final now = ref.read(dailyShareNowProvider)();
    final date = DateTime(now.year, now.month, now.day);
    final service = ref.read(studyTimeServiceProvider);
    final api = ref.read(shareCardApiProvider);
    final generate = ref.read(dailyShareImageGeneratorProvider);
    final settings = ref.read(appSettingsProvider);
    final isChina = ref.read(isChinaUserProvider);
    final oldCard = state.card;
    if (changeFrom == null) {
      _ownedImage?.dispose();
      _ownedImage = null;
    }
    state = DailyCheckInShareState(
      status: changeFrom == null
          ? DailyShareStatus.preparing
          : DailyShareStatus.ready,
      card: changeFrom == null ? null : oldCard,
      isChanging: changeFrom != null,
    );
    try {
      if (!await service.isDailyGoalCheckedIn(date)) {
        if (_isCurrent(generation, userId, date)) {
          state = const DailyCheckInShareState();
        }
        return;
      }
      if (!_isCurrent(generation, userId, date)) return;
      final cachedTemplate = _cachedTemplate;
      final cachedBackground = _cachedBackground;
      final cachedDate = _cachedDate;
      final canReuse =
          reuseBackground &&
          cachedTemplate != null &&
          cachedBackground != null &&
          cachedDate != null &&
          _sameDay(cachedDate, date);
      final template = canReuse
          ? cachedTemplate
          : await (changeFrom == null
                ? api.getToday()
                : api.getRandom(changeFrom));
      if (!_isCurrent(generation, userId, date)) return;
      if (changeFrom == template.id) {
        state = DailyCheckInShareState(
          status: DailyShareStatus.ready,
          card: oldCard,
        );
        return;
      }
      final (background, profile) = await (
        canReuse
            ? Future.value(cachedBackground)
            : api.downloadImage(template.imageUrl),
        _profile(),
      ).wait;
      if (!_isCurrent(generation, userId, date)) return;
      // 时长变化只重新绘制，避免每次返回首页都重复下载同一背景。
      _cachedTemplate = template;
      _cachedBackground = background;
      _cachedDate = date;
      final stats = await ref.read(studyStatsProvider.future);
      if (!_isCurrent(generation, userId, date)) return;
      final logo = await rootBundle.load('assets/icon/app-icon-1024-alpha.png');
      final qr = await rootBundle.load(dailyShareQrAsset(isChina));
      Uint8List? avatar;
      if (profile?.avatarUrl != null) {
        try {
          avatar = await api.downloadImage(profile!.avatarUrl!);
        } on DioException catch (error) {
          AppLogger.log('DailyShare', '头像下载失败，使用首字占位: ${error.type.name}');
        } on FormatException catch (error) {
          AppLogger.log('DailyShare', '头像内容无效，使用首字占位: $error');
        }
      }
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
          isChinese: resolveUiLocale(settings.locale).languageCode == 'zh',
          nativeLanguage: settings.nativeLanguage,
        ),
        assets: DailyCheckInShareAssets(
          background: background,
          avatar: avatar,
          logo: logo.buffer.asUint8List(logo.offsetInBytes, logo.lengthInBytes),
          qrCode: qr.buffer.asUint8List(qr.offsetInBytes, qr.lengthInBytes),
        ),
      );
      if (!_isCurrent(generation, userId, date)) {
        image.dispose();
        return;
      }
      _ownedImage?.dispose();
      _ownedImage = image;
      state = DailyCheckInShareState(
        status: DailyShareStatus.ready,
        card: PreparedDailyCheckInShare(
          userId: userId,
          date: date,
          template: template,
          image: image,
        ),
      );
      AppLogger.log('DailyShare', '今日分享图片已下载并渲染完成');
    } on Object catch (error, stackTrace) {
      // 后台准备是独立边界：失败只更新分享状态，不能中断学习或打卡。
      AppLogger.log('DailyShare', '准备分享图片失败: $error\n$stackTrace');
      if (!_isCurrent(generation, userId, date)) return;
      state = DailyCheckInShareState(
        status: changeFrom != null && oldCard != null
            ? DailyShareStatus.ready
            : DailyShareStatus.failed,
        card: changeFrom != null ? oldCard : null,
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

  Future<UserProfile?> _profile() async {
    try {
      return await ref.read(userProfileProvider.future);
    } on DioException catch (error) {
      AppLogger.log('DailyShare', '资料获取失败，省略用户资料: ${error.type.name}');
      return null;
    } on FormatException catch (error) {
      AppLogger.log('DailyShare', '资料格式无效，省略用户资料: $error');
      return null;
    }
  }

  bool _isCurrent(int generation, String userId, DateTime date) =>
      ref.mounted &&
      _generation == generation &&
      ref.read(dailyShareUserIdProvider) == userId &&
      _sameDay(date, ref.read(dailyShareNowProvider)());

  void clear() {
    _generation++;
    _preparing = null;
    _ownedImage?.dispose();
    _ownedImage = null;
    _cachedTemplate = null;
    _cachedBackground = null;
    _cachedDate = null;
    state = const DailyCheckInShareState();
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
