import 'package:echo_loop/analytics/models/event_names.dart';
import 'package:echo_loop/analytics/posthog_event_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PostHogEventPolicy', () {
    test('只允许核心漏斗和新增关键结果事件', () {
      expect(PostHogEventPolicy.shouldCapture(Events.learningStart), isTrue);
      expect(PostHogEventPolicy.shouldCapture(Events.collectionCreate), isTrue);
      expect(
        PostHogEventPolicy.shouldCapture(Events.communityCollectionEnroll),
        isTrue,
      );
      expect(PostHogEventPolicy.shouldCapture(Events.audioUpload), isFalse);
      expect(PostHogEventPolicy.shouldCapture(Events.screenView), isFalse);
      expect(
        PostHogEventPolicy.shouldCapture(Events.subscriptionPageViewed),
        isTrue,
      );
      expect(
        PostHogEventPolicy.shouldCapture(Events.blindListenComplete),
        isTrue,
      );
      expect(
        PostHogEventPolicy.shouldCapture(Events.intensiveListenComplete),
        isTrue,
      );
      expect(
        PostHogEventPolicy.shouldCapture(Events.listenRepeatComplete),
        isTrue,
      );
      expect(PostHogEventPolicy.shouldCapture(Events.retellComplete), isTrue);
      expect(
        PostHogEventPolicy.shouldCapture(Events.difficultPracticeComplete),
        isTrue,
      );
      expect(PostHogEventPolicy.shouldCapture(Events.chatTurnResult), isTrue);
      expect(
        PostHogEventPolicy.shouldCapture(Events.dailyGoalCheckedIn),
        isTrue,
      );
      expect(
        PostHogEventPolicy.shouldCapture(Events.themeModeChanged),
        isFalse,
      );
      expect(PostHogEventPolicy.shouldCapture(Events.bookmarkToggle), isFalse);
    });
  });
}
