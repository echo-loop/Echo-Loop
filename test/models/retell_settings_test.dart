import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart';
import 'package:echo_loop/models/retell_settings.dart';
import 'package:echo_loop/widgets/retell/retell_briefing_sheet.dart';

void main() {
  group('retellDefaultSeconds', () {
    test('null 阶段返回 10', () {
      expect(retellDefaultSeconds(null), 10);
    });

    test('首次学习返回 10', () {
      expect(retellDefaultSeconds(LearningStage.firstLearn), 10);
    });

    test('首轮复习返回 10', () {
      expect(retellDefaultSeconds(LearningStage.review0), 10);
    });

    test('review1 返回 10', () {
      expect(retellDefaultSeconds(LearningStage.review1), 10);
    });

    test('review2 返回 15', () {
      expect(retellDefaultSeconds(LearningStage.review2), 15);
    });

    test('review4 返回 20', () {
      expect(retellDefaultSeconds(LearningStage.review4), 20);
    });

    test('review7 返回 25', () {
      expect(retellDefaultSeconds(LearningStage.review7), 25);
    });

    test('review14 返回 30', () {
      expect(retellDefaultSeconds(LearningStage.review14), 30);
    });

    test('review28 返回 30', () {
      expect(retellDefaultSeconds(LearningStage.review28), 30);
    });

    test('completed 返回 10（兜底）', () {
      expect(retellDefaultSeconds(LearningStage.completed), 10);
    });
  });

  group('RetellSettings.calculatePauseDuration', () {
    test('smart 模式无评分：2秒 + 2倍段落时长', () {
      const settings = RetellSettings(pauseMode: PauseMode.smart);
      // 段落 10 秒，无评分 → 2 + 20 = 22 秒
      final result = settings.calculatePauseDuration(
        const Duration(seconds: 10),
      );
      expect(result, const Duration(seconds: 22));
    });

    test('smart 模式 perfect：2秒 + 0.5倍段落时长', () {
      const settings = RetellSettings(pauseMode: PauseMode.smart);
      // 段落 10 秒，score=0.95 (perfect) → 2 + 5 = 7 秒
      final result = settings.calculatePauseDuration(
        const Duration(seconds: 10),
        score: 0.95,
      );
      expect(result, const Duration(seconds: 7));
    });

    test('smart 模式 excellent：2秒 + 1倍段落时长', () {
      const settings = RetellSettings(pauseMode: PauseMode.smart);
      // 段落 10 秒，score=0.80 (excellent) → 2 + 10 = 12 秒
      final result = settings.calculatePauseDuration(
        const Duration(seconds: 10),
        score: 0.80,
      );
      expect(result, const Duration(seconds: 12));
    });

    test('smart 模式 good：2秒 + 1.5倍段落时长', () {
      const settings = RetellSettings(pauseMode: PauseMode.smart);
      // 段落 10 秒，score=0.55 (good) → 2 + 15 = 17 秒
      final result = settings.calculatePauseDuration(
        const Duration(seconds: 10),
        score: 0.55,
      );
      expect(result, const Duration(seconds: 17));
    });

    test('smart 模式：最短 3 秒', () {
      const settings = RetellSettings(pauseMode: PauseMode.smart);
      // 段落 0 秒，perfect → 2 + 0 = 2 秒，clamp 到 3 秒
      final result = settings.calculatePauseDuration(
        Duration.zero,
        score: 1.0,
      );
      expect(result, const Duration(seconds: 3));
    });

    test('smart 模式：最长 60 秒', () {
      const settings = RetellSettings(pauseMode: PauseMode.smart);
      // 段落 120 秒，无评分 → 2 + 240 = 242 秒，clamp 到 60 秒
      final result = settings.calculatePauseDuration(
        const Duration(seconds: 120),
      );
      expect(result, const Duration(seconds: 60));
    });

    test('fixed 模式：使用固定秒数', () {
      const settings = RetellSettings(
        pauseMode: PauseMode.fixed,
        fixedPauseSeconds: 20,
      );
      final result = settings.calculatePauseDuration(
        const Duration(seconds: 10),
      );
      expect(result, const Duration(seconds: 20));
    });

    test('multiplier 模式：段落时长乘以倍数', () {
      const settings = RetellSettings(
        pauseMode: PauseMode.multiplier,
        pauseMultiplier: 2.0,
      );
      final result = settings.calculatePauseDuration(
        const Duration(seconds: 10),
      );
      expect(result, const Duration(seconds: 20));
    });
  });
}
