import 'dart:async';
import 'dart:ui' as ui;

import 'package:echo_loop/features/daily_goal_check_in/data/daily_check_in_share_image.dart';
import 'package:echo_loop/features/daily_goal_check_in/data/daily_share_background_store.dart';
import 'package:echo_loop/features/daily_goal_check_in/data/share_card_api.dart';
import 'package:echo_loop/features/daily_goal_check_in/domain/share_card_template.dart';
import 'package:echo_loop/features/profile/domain/user_profile.dart';
import 'package:echo_loop/features/profile/providers/user_profile_provider.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/study_stats_provider.dart';
import 'package:echo_loop/services/study_time_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mocktail/mocktail.dart';

import 'share_card_fixtures.dart';
export 'share_card_fixtures.dart';

Future<GeneratedDailyCheckInShareImage> tinyShareImage() async {
  final codec = await ui.instantiateImageCodec(shareTestPng);
  try {
    return GeneratedDailyCheckInShareImage(
      shareTestPng,
      (await codec.getNextFrame()).image,
    );
  } finally {
    codec.dispose();
  }
}

class ShareTestService extends Mock implements StudyTimeService {}

class ShareTestSettings extends AppSettings {
  @override
  AppSettingsState build() =>
      const AppSettingsState(locale: Locale('zh', 'CN'));
}

class ShareTestStats extends StudyStatsNotifier {
  static const checked = StudyStats(
    isTodayCheckedIn: true,
    todaySeconds: 1920,
    todayInputSeconds: 1200,
    todayOutputSeconds: 720,
    streak: 128,
  );
  @override
  Future<StudyStats> build() async => checked;
  @override
  Future<void> refresh() async {}
}

class ShareTestProfile extends UserProfileNotifier {
  @override
  Future<UserProfile?> build() async => null;
}

class ShareTestApi implements ShareCardRemoteDataSource {
  int todayCalls = 0;
  DateTime? lastTodayDate;
  int downloadCalls = 0;
  int shareCalls = 0;
  Completer<ShareCardTemplate>? pendingTemplate;
  Object? randomFailure;
  Completer<Uint8List>? pendingAvatar;
  final template = ShareCardTemplate.fromJson(cardJson());
  @override
  Future<ShareCardTemplate> getToday(DateTime date) async {
    todayCalls++;
    lastTodayDate = date;
    return pendingTemplate?.future ?? template;
  }

  @override
  Future<ShareCardTemplate> getRandom(String excludeId) async {
    final error = randomFailure;
    if (error != null) throw error;
    return ShareCardTemplate.fromJson({
      ...cardJson(),
      'id': '1917c08c-4ca6-4432-b8b3-a76595e69c8b',
    });
  }

  @override
  Future<Uint8List> downloadImage(String url) async {
    downloadCalls++;
    if (url.contains('avatar')) return pendingAvatar?.future ?? shareTestPng;
    return shareTestPng;
  }

  @override
  Future<void> recordShare(String id) async {
    shareCalls++;
  }
}

class ShareTestBackgroundStore extends DailyShareBackgroundStore {
  CachedDailyShareBackground? cached;
  DateTime? date;

  @override
  Future<CachedDailyShareBackground?> read(DateTime date) async =>
      date == this.date ? cached : null;

  @override
  Future<void> write(
    DateTime date,
    ShareCardTemplate template,
    Uint8List bytes,
  ) async {
    this.date = date;
    cached = CachedDailyShareBackground(template, bytes);
  }

  @override
  Future<void> clear() async {
    date = null;
    cached = null;
  }

  @override
  Future<void> removeExpired(DateTime date) async {
    if (this.date != date) await clear();
  }
}
