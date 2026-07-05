import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/tag_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_session/blind_listen_player_provider.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/transcription_task_provider.dart';
import 'package:echo_loop/providers/local_transcription_task_provider.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/services/transcription_api_client.dart';
import 'package:echo_loop/widgets/manage_subtitles_sheet.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

void main() {
  Session signedInSession() {
    final user = User(
      id: 'user-1',
      appMetadata: const {'provider': 'email'},
      userMetadata: const {},
      aud: 'authenticated',
      email: 'learner@example.com',
      createdAt: '2026-06-12T00:00:00.000Z',
    );
    return Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: user,
      refreshToken: 'refresh',
    );
  }

  group('ManageSubtitlesSheet', () {
    /// 构建弹窗测试 App（包含所有必要的 provider override）
    Widget buildSheet(
      AudioItem audioItem, {
      LearningProgressState? progressState,
      Session? session,
      AppSettingsState appSettingsState = const AppSettingsState(
        locale: Locale('en'),
      ),
      List<Override> extraOverrides = const [],
    }) {
      final libraryState = AudioLibraryState(audioItems: [audioItem]);
      return createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => ManageSubtitlesSheet(audioItem: audioItem),
              );
            },
            child: const Text('Open'),
          ),
        ),
        overrides: [
          analyticsOverride(),
          appSettingsProvider.overrideWith(
            () => TestAppSettings(appSettingsState),
          ),
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(libraryState),
          ),
          collectionListProvider.overrideWith(() => TestCollectionList()),
          tagListProvider.overrideWith(() => TestTagList()),
          listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
          audioEngineProvider.overrideWith(() => TestAudioEngine()),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              progressState ?? const LearningProgressState(),
            ),
          ),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          blindListenPlayerProvider.overrideWith(() => TestBlindListenPlayer()),
          transcriptionTaskManagerProvider.overrideWith(
            () => TestTranscriptionTaskManager(),
          ),
          transcriptionApiClientProvider.overrideWith(
            (ref) => createTestTranscriptionApiClient(),
          ),
          supabaseSessionProvider.overrideWith(
            (ref) => Stream<Session?>.value(session),
          ),
          ...extraOverrides,
        ],
      );
    }

    group('初始状态', () {
      testWidgets('无字幕音频：显示两个 Radio 选项，无删除按钮', (tester) async {
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        // 打开弹窗
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 两个 Radio 选项
        expect(find.text('Local Upload'), findsOneWidget);
        expect(find.text('Cloud Transcription'), findsOneWidget);

        // 无删除按钮
        expect(find.byTooltip('Delete Subtitle'), findsNothing);
      });

      testWidgets('有本地字幕音频：显示编辑和红色删除按钮', (tester) async {
        final item = createTestAudioItem().copyWith(
          transcriptSource: TranscriptSource.local,
        );
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 标题栏右侧依次显示编辑和删除按钮。
        expect(find.byTooltip('Edit subtitles'), findsOneWidget);
        expect(find.byTooltip('Delete Subtitle'), findsOneWidget);

        final deleteButton = tester.widget<IconButton>(
          find.descendant(
            of: find.byTooltip('Delete Subtitle'),
            matching: find.byType(IconButton),
          ),
        );
        final theme = Theme.of(
          tester.element(find.byType(ManageSubtitlesSheet)),
        );
        expect(deleteButton.color, theme.colorScheme.error);
      });

      testWidgets('有 AI(en) 字幕音频：AI 同语言禁用', (tester) async {
        final item = createTestAudioItem().copyWith(
          transcriptSource: TranscriptSource.ai,
          transcriptLanguage: 'en',
        );
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 切换到 AI 选项
        await tester.tap(find.text('Cloud Transcription'));
        await tester.pumpAndSettle();

        // 切换语言到 English（与现有字幕语言相同）
        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();

        // AI 选中 + en 选中 → 按钮显示"已使用该选项转录"
        expect(
          find.text('Already transcribed with this option'),
          findsAtLeast(1),
        );
      });
    });

    group('交互', () {
      testWidgets('切换 Radio 选项：按钮文字正确切换', (tester) async {
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 无字幕时默认 AI → FilledButton 显示"开始转录"
        expect(
          find.widgetWithText(FilledButton, 'Start Transcription'),
          findsOneWidget,
        );

        // 切换到本地上传
        await tester.tap(find.text('Local Upload'));
        await tester.pumpAndSettle();

        // FilledButton 显示"上传字幕"
        expect(
          find.widgetWithText(FilledButton, 'Upload Transcript'),
          findsOneWidget,
        );
      });

      testWidgets('删除按钮弹出确认对话框', (tester) async {
        final item = createTestAudioItem().copyWith(
          transcriptSource: TranscriptSource.local,
        );
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 点击删除图标按钮
        await tester.tap(find.byTooltip('Delete Subtitle'));
        await tester.pumpAndSettle();

        // 确认对话框出现
        expect(
          find.text('Are you sure you want to delete the subtitle?'),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      });

      testWidgets('取消删除不影响状态', (tester) async {
        final item = createTestAudioItem().copyWith(
          transcriptSource: TranscriptSource.local,
        );
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Delete Subtitle'));
        await tester.pumpAndSettle();

        // 点击取消
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // 删除按钮仍在（状态不变）
        expect(find.byTooltip('Delete Subtitle'), findsOneWidget);
      });

      testWidgets('AI(en) 已转录 + 选中 auto → 按钮可点击', (tester) async {
        final item = createTestAudioItem().copyWith(
          transcriptSource: TranscriptSource.ai,
          transcriptLanguage: 'en',
        );
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 切换到 AI 选项
        await tester.tap(find.text('Cloud Transcription'));
        await tester.pumpAndSettle();

        // 切换到 auto（与已转录的 en 不同）→ 按钮可点击
        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Auto Detect'));
        await tester.pumpAndSettle();

        final filledButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Start Transcription'),
        );
        expect(filledButton.onPressed, isNotNull);
      });

      testWidgets('未登录点击 AI 转录时显示登录弹窗', (tester) async {
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(FilledButton, 'Start Transcription'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sign in to use AI transcription'), findsOneWidget);
        expect(
          find.textContaining(
            'AI transcription uses the cloud transcription service',
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Sign in to use AI transcription'), findsNothing);
      });

      testWidgets('AI 转录音频过长时在弹窗内显示 5 秒错误提示', (tester) async {
        final item = createTestAudioItem(
          totalDuration: 31 * 60,
        ).copyWith(transcriptSource: TranscriptSource.local);
        await tester.pumpWidget(buildSheet(item, session: signedInSession()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.pump();

        await tester.tap(find.text('Cloud Transcription'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(FilledButton, 'Start Transcription'),
        );
        await tester.pump();

        expect(find.textContaining('Audio too long'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        expect(find.textContaining('Audio too long'), findsNothing);
      });
    });

    group('删除字幕警告', () {
      testWidgets('删除确认显示收藏句子警告', (tester) async {
        final item = createTestAudioItem().copyWith(
          transcriptSource: TranscriptSource.local,
        );
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Delete Subtitle'));
        await tester.pumpAndSettle();

        // 显示收藏句子删除警告
        expect(
          find.text(
            'Deleting the subtitle will also clear all bookmarked sentences and learning progress for this audio.',
          ),
          findsOneWidget,
        );
      });
    });

    group('语言选择 UI', () {
      testWidgets('AI 选中时显示语言选择', (tester) async {
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 无字幕时默认选中 AI → 语言选择显示
        expect(find.text('Select Language'), findsOneWidget);

        // 切换到本地上传 → 语言选择隐藏
        await tester.tap(find.text('Local Upload'));
        await tester.pumpAndSettle();

        expect(find.text('Select Language'), findsNothing);
      });

      testWidgets('本地上传选中时隐藏语言选择', (tester) async {
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 切换到 AI
        await tester.tap(find.text('Cloud Transcription'));
        await tester.pumpAndSettle();
        expect(find.text('Select Language'), findsOneWidget);

        // 切换回本地上传
        await tester.tap(find.text('Local Upload'));
        await tester.pumpAndSettle();

        // 语言选择隐藏
        expect(find.text('Select Language'), findsNothing);
      });
    });

    group('自动合并短句开关', () {
      testWidgets('AI 选中时显示开关，默认开启，仅本地上传时隐藏', (tester) async {
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 无字幕默认 AI → 开关显示且默认开启
        expect(find.text('Auto-merge short sentences'), findsOneWidget);
        final sw = tester.widget<Switch>(find.byType(Switch));
        expect(sw.value, isTrue);

        // 切换到本地上传 → 开关隐藏
        await tester.tap(find.text('Local Upload'));
        await tester.pumpAndSettle();
        expect(find.text('Auto-merge short sentences'), findsNothing);
      });

      testWidgets('点击开关可切换为关闭', (tester) async {
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      });

      testWidgets('已保存关闭时，首次打开弹窗默认显示关闭', (tester) async {
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(
          buildSheet(
            item,
            appSettingsState: const AppSettingsState(
              locale: Locale('en'),
              aiTranscriptionAutoMergeEnabled: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Auto-merge short sentences'), findsOneWidget);
        expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      });
    });

    group('本地（离线）转录', () {
      testWidgets('无字幕音频：显示本地转录选项', (tester) async {
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('On-Device Transcription'), findsOneWidget);
      });

      testWidgets('选中本地转录：显示语言（英文）与模型档位选择', (tester) async {
        // 用已有字幕的音频，避免无字幕时的新手引导 coachmark 干扰 pumpAndSettle。
        SharedPreferences.setMockInitialValues({});
        final sp = await SharedPreferences.getInstance();
        final item = createTestAudioItem();
        await tester.pumpWidget(
          buildSheet(
            item,
            extraOverrides: [sharedPreferencesProvider.overrideWithValue(sp)],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('On-Device Transcription'));
        await tester.pumpAndSettle();

        // 语言选择（仅英文）与模型档位选择出现。
        expect(find.text('Select Language'), findsOneWidget);
        expect(find.text('English'), findsWidgets);
        expect(find.text('Recognition model'), findsOneWidget);
        // 档位选择器显示当前档位（测试环境推荐档位 = 'Test Model'）。
        expect(find.text('Test Model'), findsOneWidget);
        // 自动合并短句开关在离线区也出现（与 AI 转录对齐）。
        expect(find.text('Auto-merge short sentences'), findsOneWidget);
      });

      testWidgets('选中本地转录：语言胶囊可点击弹出菜单（仅英文一项）', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final sp = await SharedPreferences.getInstance();
        final item = createTestAudioItem();
        await tester.pumpWidget(
          buildSheet(
            item,
            extraOverrides: [sharedPreferencesProvider.overrideWithValue(sp)],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('On-Device Transcription'));
        await tester.pumpAndSettle();

        // 离线语言选择器是可点的 PopupMenuButton（不再是死胶囊）。
        final langButton = find.byType(PopupMenuButton<String>);
        expect(langButton, findsOneWidget);

        // 点击弹出菜单，出现单个 English 选项（额外的 English 文本）。
        final englishBefore = find.text('English').evaluate().length;
        await tester.tap(langButton);
        await tester.pumpAndSettle();
        expect(
          find.text('English').evaluate().length,
          greaterThan(englishBefore),
        );
      });

      testWidgets('转录进行中：显示保持前台提示', (tester) async {
        final item = createTestAudioItem();
        await tester.pumpWidget(
          buildSheet(
            item,
            extraOverrides: [
              localTranscriptionTaskManagerProvider.overrideWith(
                () => TestLocalTranscriptionTaskManager({
                  item.id: const LocalTranscriptionTranscribing(progress: 0.3),
                }),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 进度视图渲染时展示保持前台的提示与数字进度百分比。
        expect(find.textContaining('Keep the app open'), findsOneWidget);
        expect(find.text('30% done'), findsOneWidget);
        // 提供取消按钮。
        expect(find.text('Cancel'), findsOneWidget);
      });

      testWidgets('转录进行中：点取消回到选项界面', (tester) async {
        final item = createTestAudioItem();
        await tester.pumpWidget(
          buildSheet(
            item,
            extraOverrides: [
              localTranscriptionTaskManagerProvider.overrideWith(
                () => TestLocalTranscriptionTaskManager({
                  item.id: const LocalTranscriptionTranscribing(progress: 0.3),
                }),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // 取消后状态回 Idle，进度视图消失，重新显示转录选项。
        expect(find.textContaining('Keep the app open'), findsNothing);
        expect(find.text('On-Device Transcription'), findsOneWidget);
      });
    });
  });
}
