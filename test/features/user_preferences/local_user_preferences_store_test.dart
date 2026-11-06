import 'dart:convert';

import 'package:echo_loop/features/user_preferences/data/local_user_preferences_store.dart';
import 'package:echo_loop/features/user_preferences/domain/user_preferences_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'captures the user preference whitelist and excludes device state',
    () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'dark',
        'locale': 'zh-CN',
        'native_language': 'zh-TW',
        'learning_auto_skip_retell': true,
        'learning_retell_auto_playback_prompt_shown': true,
        'demo_mode': true,
        'developer_time_machine_at_ms': 123,
        'audio_list_sort_type': 'nameAsc',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = LocalUserPreferencesStore(prefs);

      final document = store.capture();
      final json = document.toJson();

      expect(document.preferences['appearance'], {
        'themeMode': 'dark',
        'locale': 'zh-CN',
        'nativeLanguage': 'zh-TW',
      });
      expect(
        (document.preferences['learning'] as Map)['autoSkipRetell'],
        isTrue,
      );
      expect(
        (document.preferences['lists'] as Map)['audioSortType'],
        'nameAsc',
      );
      expect(jsonEncode(json), isNot(contains('demo_mode')));
      expect(jsonEncode(json), isNot(contains('developer_time_machine')));
      expect(
        (document.preferences['learning']
            as Map)['retellAutoPlaybackPromptShown'],
        isTrue,
      );
    },
  );

  test('captures one-time prompt markers only, never guide state', () async {
    SharedPreferences.setMockInitialValues({
      'learning_pdf_export_reminder_shown': true,
      'learning_unclear_auto_save_reminder_shown': true,
      'guide_enabled': false,
      'guide_v1_library_create_collection_seen': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = LocalUserPreferencesStore(prefs);

    final learning =
        store.capture().preferences['learning'] as Map<String, Object?>;

    expect(learning['pdfExportReminderShown'], isTrue);
    expect(learning['unclearAutoSaveReminderShown'], isTrue);
    expect(learning['retellAutoPlaybackPromptShown'], isFalse);
    // 新手引导的开关与已看状态只保存在本机，不进入云端快照。
    expect(learning.containsKey('guideEnabled'), isFalse);
    expect(learning.containsKey('guideSeen'), isFalse);
  });

  test('applies cloud prompt markers and ignores guide state', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalUserPreferencesStore(prefs);

    await store.apply(
      UserPreferencesDocument({
        'learning': {
          'retellAutoPlaybackPromptShown': true,
          'pdfExportReminderShown': true,
          'unclearAutoSaveReminderShown': true,
          'guideEnabled': false,
        },
      }),
    );

    expect(prefs.getBool('learning_retell_auto_playback_prompt_shown'), isTrue);
    expect(prefs.getBool('learning_pdf_export_reminder_shown'), isTrue);
    expect(prefs.getBool('learning_unclear_auto_save_reminder_shown'), isTrue);
    // 云端的引导开关不写入本机，新手引导状态只属于本机。
    expect(prefs.getBool('guide_enabled'), isNull);
  });

  test(
    'keeps local prompt markers when the cloud snapshot omits them',
    () async {
      SharedPreferences.setMockInitialValues({
        'learning_pdf_export_reminder_shown': true,
        'learning_unclear_auto_save_reminder_shown': true,
        'guide_enabled': false,
        'guide_v1_library_create_collection_seen': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = LocalUserPreferencesStore(prefs);

      // 旧客户端写入的快照不含这些字段，不能把本地已展示状态清回默认值。
      await store.apply(
        UserPreferencesDocument({
          'learning': {'autoSkipRetell': true},
        }),
      );

      expect(prefs.getBool('learning_pdf_export_reminder_shown'), isTrue);
      expect(
        prefs.getBool('learning_unclear_auto_save_reminder_shown'),
        isTrue,
      );
      expect(prefs.getBool('guide_enabled'), isFalse);
    },
  );

  test(
    'never clears a locally shown marker when the cloud says not shown',
    () async {
      SharedPreferences.setMockInitialValues({
        'learning_pdf_export_reminder_shown': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = LocalUserPreferencesStore(prefs);

      // 新设备首次登录时云端可能是未展示的快照，已看过的提示不能因此重新出现。
      await store.apply(
        UserPreferencesDocument({
          'learning': {'pdfExportReminderShown': false},
        }),
      );

      expect(prefs.getBool('learning_pdf_export_reminder_shown'), isTrue);
    },
  );

  test('syncs the study recommendation visibility preference', () async {
    SharedPreferences.setMockInitialValues({
      'learning_show_study_recommendation': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = LocalUserPreferencesStore(prefs);

    final captured = store.capture();
    expect(
      (captured.preferences['learning'] as Map)['showStudyRecommendation'],
      isFalse,
    );

    await store.apply(
      UserPreferencesDocument({
        'learning': {'showStudyRecommendation': true},
      }),
    );
    expect(prefs.getBool('learning_show_study_recommendation'), isTrue);
  });

  test('syncs the weekly study chart visibility preference', () async {
    SharedPreferences.setMockInitialValues({
      'learning_show_weekly_study_chart': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = LocalUserPreferencesStore(prefs);

    final captured = store.capture();
    expect(
      (captured.preferences['learning'] as Map)['showWeeklyStudyChart'],
      isFalse,
    );

    await store.apply(
      UserPreferencesDocument({
        'learning': {'showWeeklyStudyChart': true},
      }),
    );
    expect(prefs.getBool('learning_show_weekly_study_chart'), isTrue);
  });

  test('applies cloud settings without touching developer state', () async {
    SharedPreferences.setMockInitialValues({
      'demo_mode': true,
      'developer_time_machine_at_ms': 987,
      'learning_retell_auto_playback_prompt_shown': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = LocalUserPreferencesStore(prefs);

    await store.apply(
      UserPreferencesDocument({
        'appearance': {
          'themeMode': 'light',
          'locale': 'en',
          'nativeLanguage': 'zh-CN',
        },
        'learning': {'autoSkipRetell': true},
        'playback': {'skipSilenceEnabled': false},
      }),
    );

    expect(prefs.getString('theme_mode'), 'light');
    expect(prefs.getBool('learning_auto_skip_retell'), isTrue);
    expect(prefs.getBool('skip_silence_enabled'), isFalse);
    expect(prefs.getBool('demo_mode'), isTrue);
    expect(prefs.getInt('developer_time_machine_at_ms'), 987);
    expect(prefs.getBool('learning_retell_auto_playback_prompt_shown'), isTrue);
  });

  test('暂停后从句首继续开关随 playback 分组双向同步', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalUserPreferencesStore(prefs);

    await store.apply(
      UserPreferencesDocument({
        'playback': {'resumeFromSentenceStartEnabled': true},
      }),
    );
    expect(prefs.getBool('resume_from_sentence_start_enabled'), isTrue);

    final document = store.capture();
    expect(
      (document.preferences['playback']
          as Map)['resumeFromSentenceStartEnabled'],
      isTrue,
    );
  });

  test('未设置暂停后从句首继续时云端快照默认为关闭', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalUserPreferencesStore(prefs);

    final document = store.capture();

    expect(
      (document.preferences['playback']
          as Map)['resumeFromSentenceStartEnabled'],
      isFalse,
    );
  });

  test('每日学习目标随 learning 分组双向同步', () async {
    SharedPreferences.setMockInitialValues({'learning_daily_goal_minutes': 30});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalUserPreferencesStore(prefs);

    expect(
      (store.capture().preferences['learning'] as Map)['dailyGoalMinutes'],
      30,
    );

    await store.apply(
      UserPreferencesDocument({
        'learning': {'dailyGoalMinutes': 60},
      }),
    );
    expect(prefs.getInt('learning_daily_goal_minutes'), 60);
  });

  test('云端缺失每日学习目标时保留本地解析值，不覆盖引导页答案', () async {
    SharedPreferences.setMockInitialValues({'onboarding_daily_minutes': '20'});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalUserPreferencesStore(prefs);

    await store.apply(
      UserPreferencesDocument({
        'learning': {'autoSkipRetell': true},
      }),
    );

    expect(prefs.getInt('learning_daily_goal_minutes'), 20);
  });

  test('云端每日学习目标越界时钳制到合法范围', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalUserPreferencesStore(prefs);

    await store.apply(
      UserPreferencesDocument({
        'learning': {'dailyGoalMinutes': 100000},
      }),
    );

    expect(prefs.getInt('learning_daily_goal_minutes'), 720);
  });
}
