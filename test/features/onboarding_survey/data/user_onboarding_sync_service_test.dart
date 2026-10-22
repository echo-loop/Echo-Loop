import 'package:echo_loop/features/onboarding_survey/data/onboarding_survey_storage.dart';
import 'package:echo_loop/features/onboarding_survey/data/user_onboarding_api.dart';
import 'package:echo_loop/features/onboarding_survey/data/user_onboarding_sync_service.dart';
import 'package:echo_loop/features/onboarding_survey/models/onboarding_answers.dart';
import 'package:echo_loop/features/onboarding_survey/models/onboarding_question.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRemote implements UserOnboardingRemoteDataSource {
  int attempts = 0;
  int failuresRemaining = 0;
  final List<Map<String, Object?>> savedAnswers = [];

  @override
  Future<void> saveAnswers(Map<String, Object?> answers) async {
    attempts++;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('offline');
    }
    savedAnswers.add(Map<String, Object?>.from(answers));
  }
}

const _answers = OnboardingAnswers(
  goal: OnboardingGoal.work,
  dailyMinutes: OnboardingDailyMinutes.m20,
  referralSource: OnboardingReferralSource.friend,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('signed-out completion waits until login, then uploads once', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = OnboardingSurveyStorage(prefs);
    await storage.saveCompleted(_answers);
    final remote = _FakeRemote();
    final service = UserOnboardingSyncService(
      remote: remote,
      storage: storage,
      preferences: prefs,
    );
    addTearDown(service.dispose);

    await service.onSessionChanged(isSignedIn: false);
    expect(remote.attempts, 0);

    await service.onSessionChanged(isSignedIn: true);
    expect(remote.attempts, 1);
    expect(remote.savedAnswers.single, _answers.toJson());
    expect(prefs.getBool(UserOnboardingSyncService.uploadedKey), isTrue);

    await service.onSessionChanged(isSignedIn: false);
    await service.onSessionChanged(isSignedIn: true);
    expect(remote.attempts, 1);

    final restoredService = UserOnboardingSyncService(
      remote: remote,
      storage: storage,
      preferences: prefs,
    );
    addTearDown(restoredService.dispose);
    await restoredService.onSessionChanged(isSignedIn: true);
    expect(remote.attempts, 1);
  });

  test(
    'failed upload leaves the flag unset and retries on app resume',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      await storage.saveCompleted(_answers);
      final remote = _FakeRemote()..failuresRemaining = 1;
      final service = UserOnboardingSyncService(
        remote: remote,
        storage: storage,
        preferences: prefs,
      );
      addTearDown(service.dispose);

      await service.onSessionChanged(isSignedIn: true);
      expect(remote.attempts, 1);
      expect(prefs.getBool(UserOnboardingSyncService.uploadedKey), isNot(true));

      await service.onAppResumed();
      expect(remote.attempts, 2);
      expect(prefs.getBool(UserOnboardingSyncService.uploadedKey), isTrue);
    },
  );

  test(
    'does not mark upload complete when there are no valid answers',
    () async {
      SharedPreferences.setMockInitialValues({
        OnboardingSurveyKeys.completedAtMs: DateTime(
          2026,
        ).millisecondsSinceEpoch,
        OnboardingSurveyKeys.goal: 'invalid',
      });
      final prefs = await SharedPreferences.getInstance();
      final remote = _FakeRemote();
      final service = UserOnboardingSyncService(
        remote: remote,
        storage: OnboardingSurveyStorage(prefs),
        preferences: prefs,
      );
      addTearDown(service.dispose);

      await service.onSessionChanged(isSignedIn: true);

      expect(remote.attempts, 0);
      expect(prefs.getBool(UserOnboardingSyncService.uploadedKey), isNot(true));
    },
  );
}
