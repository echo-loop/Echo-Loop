/// 集成测试入口
///
/// 单入口 + 分文件组织：只构建一次 App，测试逻辑按功能拆分到 groups/ 目录。
/// 新增测试流程时，在 groups/ 下创建文件并在此处调用即可。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_notifiers.dart';
import 'groups/navigation_tests.dart';
import 'groups/settings_tests.dart';
import 'groups/collection_tests.dart';
import 'groups/learning_plan_tests.dart';
import 'groups/blind_listen_tests.dart';
import 'groups/intensive_listen_tests.dart';
import 'groups/shadowing_tests.dart';
import 'groups/learning_flow_tests.dart';
import 'groups/audio_star_tests.dart';
import 'groups/tag_tests.dart';
import 'groups/stats_display_tests.dart';
import 'groups/retell_tests.dart';
import 'groups/review_sub_stage_tests.dart';
import 'groups/manage_subtitles_tests.dart';
import 'groups/flashcard_tests.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestAnalytics();
  });

  navigationTests();
  settingsTests();
  collectionTests();
  audioStarTests();
  tagTests();
  learningPlanTests();
  blindListenTests();
  intensiveListenTests();
  shadowingTests();
  learningFlowTests();
  statsDisplayTests();
  retellTests();
  reviewSubStageTests();
  manageSubtitlesTests();
  flashcardTests();
}
