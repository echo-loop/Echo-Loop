/// App 冒烟测试
///
/// 验证 App 能正常启动并显示首页。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:fluency/main.dart';
import 'package:fluency/providers/settings_provider.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/collection_provider.dart';
import 'package:fluency/providers/tag_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/package_info_provider.dart';

import 'helpers/mock_providers.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final packageInfo = PackageInfo(
      appName: 'Fluency',
      packageName: 'top.valuespot.fluency',
      version: '1.0.0',
      buildNumber: '1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith(() => TestAppSettings()),
          audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
          collectionListProvider.overrideWith(() => TestCollectionList()),
          tagListProvider.overrideWith(() => TestTagList()),
          listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
          audioEngineProvider.overrideWith(() => TestAudioEngine()),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(),
          ),
          packageInfoProvider.overrideWithValue(packageInfo),
        ],
        child: const FluencyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 验证 App 正常加载 — 默认显示学习页
    expect(find.text('Study feature coming soon'), findsOneWidget);
  });
}
