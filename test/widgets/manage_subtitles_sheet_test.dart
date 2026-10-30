import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/podcast/podcast_transcript_downloader.dart';
import 'package:echo_loop/features/remote_config/remote_config.dart';
import 'package:echo_loop/features/remote_config/remote_config_providers.dart';
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
import 'package:echo_loop/features/subscription/models/premium_feature.dart';
import 'package:echo_loop/features/subscription/models/ai_quota_rejection.dart';
import 'package:echo_loop/features/subscription/services/free_allowance_policy.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:echo_loop/services/transcription_api_client.dart';
import 'package:echo_loop/utils/transcript_picker.dart';
import 'package:echo_loop/widgets/manage_subtitles_sheet.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

/// 可在字幕管理面板已打开后推送转录任务状态的测试 controller。
class _ManualTranscriptionTaskManager extends TestTranscriptionTaskManager {
  void emit(String audioId, TranscriptionTaskState taskState) {
    state = Map.of(state)..[audioId] = taskState;
  }
}

/// 播客 RSS 字幕内容（合法 SRT，可通过解析入库）。
const _podcastSrt = '1\n00:00:00,000 --> 00:00:01,000\nHello podcast\n';

/// 可预设返回内容或抛错、并记录请求地址的播客字幕下载器。
class _FakePodcastTranscriptDownloader extends PodcastTranscriptDownloader {
  _FakePodcastTranscriptDownloader({this.text = _podcastSrt, this.error});

  final String text;
  final Object? error;
  final List<String> requestedUrls = [];

  @override
  Future<String> download(
    String url, {
    required String format,
    CancelToken? cancelToken,
  }) async {
    requestedUrls.add(url);
    if (error case final e?) throw e;
    return text;
  }
}

class _DenyAiAllowancePolicy implements FreeAllowancePolicy {
  const _DenyAiAllowancePolicy();

  @override
  bool allows(PremiumFeature feature) => false;
}

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
      bool subscriptionPro = true,
      Future<TranscriptDecodeResult?> Function()? transcriptContentPicker,
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
                builder: (_) => ManageSubtitlesSheet(
                  audioItem: audioItem,
                  transcriptContentPicker: transcriptContentPicker,
                ),
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
          // 已登录用户视为已解锁（Pro），使转录机制测试不被额度闸拦截。
          subscriptionEntitlementOverride(pro: subscriptionPro),
          ...extraOverrides,
        ],
      );
    }

    setUp(() {
      AppLogger.instance.clear();
    });

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
        expect(find.byTooltip('Delete Subtitles'), findsNothing);
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
        expect(find.byTooltip('Delete Subtitles'), findsOneWidget);

        final deleteButton = tester.widget<IconButton>(
          find.descendant(
            of: find.byTooltip('Delete Subtitles'),
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
          find.widgetWithText(FilledButton, 'Upload Subtitles'),
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
        await tester.tap(find.byTooltip('Delete Subtitles'));
        await tester.pumpAndSettle();

        // 确认对话框出现
        expect(
          find.text('Are you sure you want to delete the subtitles?'),
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

        await tester.tap(find.byTooltip('Delete Subtitles'));
        await tester.pumpAndSettle();

        // 点击取消
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // 删除按钮仍在（状态不变）
        expect(find.byTooltip('Delete Subtitles'), findsOneWidget);
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

      testWidgets('免费用户点击 AI 转录时先显示额度提示', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(
          buildSheet(
            item,
            session: signedInSession(),
            subscriptionPro: false,
            extraOverrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              freeAllowancePolicyProvider.overrideWithValue(
                const _DenyAiAllowancePolicy(),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, 'Start Transcription'),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            "This month's free AI subtitle transcription quota is used up",
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();
        expect(find.byType(ManageSubtitlesSheet), findsOneWidget);
      });

      testWidgets('后端转录额度用尽时清状态并显示额度提示', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final item = createTestAudioItem(transcriptPath: null);
        final manager = _ManualTranscriptionTaskManager();
        await tester.pumpWidget(
          buildSheet(
            item,
            session: signedInSession(),
            extraOverrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              transcriptionTaskManagerProvider.overrideWith(() => manager),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        manager.emit(
          item.id,
          const TranscriptionQuotaExceeded(
            reason: AiQuotaRejectionReason.unsupportedForFreePlan,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text("The free plan doesn't support AI subtitle transcription"),
          findsOneWidget,
        );
        expect(manager.getTaskState(item.id), isA<TranscriptionIdle>());

        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();
        expect(find.byType(ManageSubtitlesSheet), findsOneWidget);
      });

      testWidgets('服务端文件超限时显示本地化的 25MB 提示', (tester) async {
        final item = createTestAudioItem(transcriptPath: null);
        final manager = _ManualTranscriptionTaskManager();
        await tester.pumpWidget(
          buildSheet(
            item,
            extraOverrides: [
              transcriptionTaskManagerProvider.overrideWith(() => manager),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        manager.emit(
          item.id,
          const TranscriptionFailed(message: 'fileTooLarge'),
        );
        await tester.pumpAndSettle();

        expect(find.text('File too large (max 25MB)'), findsOneWidget);
      });

      testWidgets('AI 转录读取远程时长限制并在弹窗内显示错误提示', (tester) async {
        final item = createTestAudioItem(
          totalDuration: 2 * 60,
        ).copyWith(transcriptSource: TranscriptSource.local);
        await tester.pumpWidget(
          buildSheet(
            item,
            session: signedInSession(),
            extraOverrides: [
              remoteTranscriptionLimitsProvider.overrideWithValue(
                const RemoteTranscriptionLimits(maxDurationSeconds: 60),
              ),
            ],
          ),
        );
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

        expect(
          find.textContaining('Audio too long (max 1 minutes)'),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);

        await tester.pump(const Duration(seconds: 12));
        await tester.pumpAndSettle();

        expect(find.textContaining('Audio too long'), findsNothing);
      });

      testWidgets('大文件预压缩时显示音频压缩中状态', (tester) async {
        final item = createTestAudioItem();
        await tester.pumpWidget(
          buildSheet(
            item,
            extraOverrides: [
              transcriptionTaskManagerProvider.overrideWith(
                () => TestTranscriptionTaskManager({
                  item.id: const TranscriptionCompressing(),
                }),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        // 压缩态的进度条是不定态动画，不能等待 settle。
        await tester.pump();

        expect(find.text('Compressing audio...'), findsOneWidget);
        expect(find.byIcon(Icons.compress), findsOneWidget);
      });

      testWidgets('本地上传失败时完整显示错误并写入日志', (tester) async {
        const failurePath =
            '/private/var/mobile/Containers/Shared/AppGroup/subtitle.srt';
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(
          buildSheet(
            item,
            transcriptContentPicker: () async =>
                throw const FileSystemException(
                  'Operation not permitted',
                  failurePath,
                  OSError('Permission denied', 1),
                ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Local Upload'));
        await tester.pumpAndSettle();

        await runZoned<Future<void>>(() async {
          await tester.tap(
            find.widgetWithText(FilledButton, 'Upload Subtitles'),
          );
          await tester.pump();
        }, zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}));

        expect(find.textContaining(failurePath), findsOneWidget);
        expect(find.textContaining('Operation not permitted'), findsOneWidget);

        final logLines = AppLogger.instance.entries.map((e) => e.toString());
        expect(
          logLines,
          contains(
            allOf(
              contains('[SubtitleUpload] failed local upload'),
              contains('errorType=FileSystemException'),
              contains(failurePath),
            ),
          ),
        );

        await tester.pump(const Duration(seconds: 12));
        await tester.pumpAndSettle();
      });

      testWidgets('本地上传成功时日志记录解码字符集', (tester) async {
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(
          buildSheet(
            item,
            transcriptContentPicker: () async => const TranscriptDecodeResult(
              text: '1\n00:00:00,000 --> 00:00:01,000\n你好\n',
              charset: 'gb18030',
            ),
            extraOverrides: [
              audioItemDaoProvider.overrideWithValue(TestAudioItemDao()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Local Upload'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Upload Subtitles'));
        await tester.pumpAndSettle();

        final logLines = AppLogger.instance.entries.map((e) => e.toString());
        expect(
          logLines,
          contains(
            allOf(
              contains('[SubtitleUpload] picked transcript'),
              contains('charset=gb18030'),
            ),
          ),
        );
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

        await tester.tap(find.byTooltip('Delete Subtitles'));
        await tester.pumpAndSettle();

        // 显示收藏句子删除警告
        expect(
          find.text(
            'Deleting the subtitles will also clear all saved sentences and learning progress of this audio.',
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
      testWidgets('无字幕音频：隐藏本地转录选项', (tester) async {
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('On-Device Transcription'), findsNothing);
      });

      // 本地转录入口暂时隐藏，保留展开态测试便于后续恢复。
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
      }, skip: true);

      // 本地转录入口暂时隐藏，保留语言选择器测试便于后续恢复。
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
      }, skip: true);

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

        // 取消后状态回 Idle，进度视图消失；本地转录入口保持隐藏。
        expect(find.textContaining('Keep the app open'), findsNothing);
        expect(find.text('On-Device Transcription'), findsNothing);
      });
    });

    group('播客字幕下载', () {
      const podcastUrl = 'https://example.com/episode.srt';

      AudioItem podcastItem({required bool hasTranscript}) {
        return createTestAudioItem(
          transcriptPath: hasTranscript ? 'transcripts/test.srt' : null,
        ).copyWith(
          podcastTranscriptUrl: podcastUrl,
          podcastTranscriptFormat: 'srt',
        );
      }

      testWidgets('无字幕地址：不显示下载播客字幕选项', (tester) async {
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Download Podcast Subtitles'), findsNothing);
      });

      testWidgets('有字幕地址：默认选中并下载入库，成功后关闭弹窗', (tester) async {
        final item = podcastItem(hasTranscript: false);
        final downloader = _FakePodcastTranscriptDownloader();
        final dao = TestAudioItemDao();
        await tester.pumpWidget(
          buildSheet(
            item,
            extraOverrides: [
              podcastTranscriptDownloaderProvider.overrideWithValue(downloader),
              audioItemDaoProvider.overrideWithValue(dao),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Download Podcast Subtitles'), findsOneWidget);
        await tester.tap(
          find.widgetWithText(FilledButton, 'Download Subtitles'),
        );
        await tester.pumpAndSettle();

        expect(downloader.requestedUrls, [podcastUrl]);
        expect(dao.transcriptSrtStore[item.id], contains('Hello podcast'));
        expect(find.byType(ManageSubtitlesSheet), findsNothing);
      });

      testWidgets('已有字幕：覆盖确认取消后不发起下载', (tester) async {
        final item = podcastItem(hasTranscript: true);
        final downloader = _FakePodcastTranscriptDownloader();
        await tester.pumpWidget(
          buildSheet(
            item,
            extraOverrides: [
              podcastTranscriptDownloaderProvider.overrideWithValue(downloader),
              audioItemDaoProvider.overrideWithValue(TestAudioItemDao()),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(FilledButton, 'Download Subtitles'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Overwrite existing subtitles?'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(downloader.requestedUrls, isEmpty);
        expect(find.byType(ManageSubtitlesSheet), findsOneWidget);
      });

      testWidgets('已有字幕：确认覆盖后替换为播客字幕', (tester) async {
        final item = podcastItem(hasTranscript: true);
        final downloader = _FakePodcastTranscriptDownloader();
        final dao = TestAudioItemDao();
        await tester.pumpWidget(
          buildSheet(
            item,
            extraOverrides: [
              podcastTranscriptDownloaderProvider.overrideWithValue(downloader),
              audioItemDaoProvider.overrideWithValue(dao),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(FilledButton, 'Download Subtitles'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Overwrite'));
        await tester.pumpAndSettle();

        expect(downloader.requestedUrls, [podcastUrl]);
        expect(dao.transcriptSrtStore[item.id], contains('Hello podcast'));
      });

      testWidgets('下载失败：显示内联错误，弹窗保留且不改动字幕', (tester) async {
        final item = podcastItem(hasTranscript: false);
        final downloader = _FakePodcastTranscriptDownloader(
          error: const PodcastTranscriptException('HTTP 500'),
        );
        final dao = TestAudioItemDao();
        await tester.pumpWidget(
          buildSheet(
            item,
            extraOverrides: [
              podcastTranscriptDownloaderProvider.overrideWithValue(downloader),
              audioItemDaoProvider.overrideWithValue(dao),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(FilledButton, 'Download Subtitles'),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Failed to download subtitles'),
          findsOneWidget,
        );
        expect(find.textContaining('HTTP 500'), findsOneWidget);
        expect(find.byType(ManageSubtitlesSheet), findsOneWidget);
        expect(dao.transcriptSrtStore[item.id], isNull);

        // 内联错误 5 秒后自动消失，等待计时器结束避免残留。
        await tester.pump(const Duration(seconds: 12));
        await tester.pumpAndSettle();
      });

      testWidgets('下载到空字幕：提示为空且不入库', (tester) async {
        final item = podcastItem(hasTranscript: false);
        final dao = TestAudioItemDao();
        await tester.pumpWidget(
          buildSheet(
            item,
            extraOverrides: [
              podcastTranscriptDownloaderProvider.overrideWithValue(
                _FakePodcastTranscriptDownloader(text: ''),
              ),
              audioItemDaoProvider.overrideWithValue(dao),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(FilledButton, 'Download Subtitles'),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('no subtitle entries found'),
          findsOneWidget,
        );
        expect(dao.transcriptSrtStore[item.id], isNull);

        await tester.pump(const Duration(seconds: 12));
        await tester.pumpAndSettle();
      });
    });
  });
}
