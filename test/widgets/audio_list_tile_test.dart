import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/blind_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/tag_provider.dart';
import 'package:echo_loop/features/audio_import/audio_import_models.dart';
import 'package:echo_loop/features/audio_import/audio_import_provider.dart';
import 'package:echo_loop/features/official_collections/download/download_progress.dart';
import 'package:echo_loop/features/official_collections/download/official_download_notifier.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/audio_list_tile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

/// 包装器：从 Provider 读取第一个音频项，传给 AudioListTile
/// 模拟真实场景中父组件 watch provider → 传 item 给子组件的模式
class _AudioListTileWrapper extends ConsumerWidget {
  const _AudioListTileWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(audioLibraryProvider.select((s) => s.audioItems));
    if (items.isEmpty) return const SizedBox.shrink();
    return AudioListTile(audioItem: items.first);
  }
}

class _DownloadingAudioImportController extends PodcastDownloadController {
  @override
  AudioImportState build() => const AudioImportDownloading(
    displayName: 'https://example.com/episode.mp3',
    progress: 0.42,
    receivedBytes: 42,
    totalBytes: 100,
  );
}

class _DownloadingOfficial extends OfficialDownload {
  _DownloadingOfficial(this.audioItemId);

  final String audioItemId;

  @override
  DownloadProgress build() => DownloadInProgress(
    audioItemId: audioItemId,
    displayName: 'Official Audio',
    progress: 0.42,
    receivedBytes: 42,
    totalBytes: 100,
  );
}

class _PendingAudioImportController extends PodcastDownloadController {
  final Completer<bool> _completer = Completer<bool>();

  @override
  AudioImportState build() => const AudioImportIdle();

  @override
  Future<bool> downloadPodcastEpisode(AudioItem item) {
    // 立即进入下载态（不定进度），承载行内进度条；下载结果由测试控制。
    state = AudioImportDownloading(
      displayName: item.podcastEnclosureUrl!,
      progress: -1.0,
    );
    return _completer.future;
  }

  void complete([bool ok = false]) {
    if (!_completer.isCompleted) {
      // 收尾置回 idle，停止不定进度动画，避免 pumpAndSettle 超时。
      state = const AudioImportIdle();
      _completer.complete(ok);
    }
  }
}

Session _signedInSession() {
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

void main() {
  group('AudioListTile 字幕标签', () {
    Widget buildTile(AudioItem item) {
      return createTestApp(
        Center(
          child: SizedBox(width: 360, child: AudioListTile(audioItem: item)),
        ),
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
          ),
        ],
      );
    }

    testWidgets('有字幕时第三行显示带图标、描边和浅色底的字幕标签', (tester) async {
      final item = createTestAudioItem(name: 'Audio with transcript');

      await tester.pumpWidget(buildTile(item));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('audio_list_tile_metadata_row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('audio_list_tile_badge_row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('audio_list_tile_transcript_badge')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.subtitles_outlined), findsOneWidget);
      expect(find.text('Transcript'), findsOneWidget);

      final badge = tester.widget<Container>(
        find.byKey(const Key('audio_list_tile_transcript_badge')),
      );
      switch (badge.decoration) {
        case BoxDecoration(:final color, :final border):
          expect(color, isNotNull);
          expect(border, isNotNull);
        default:
          fail('字幕标签应使用 BoxDecoration');
      }

      final titleY = tester.getTopLeft(find.text('Audio with transcript')).dy;
      final metadataY = tester
          .getTopLeft(find.byKey(const Key('audio_list_tile_metadata_row')))
          .dy;
      final badgeY = tester
          .getTopLeft(find.byKey(const Key('audio_list_tile_badge_row')))
          .dy;
      expect(metadataY, greaterThan(titleY));
      expect(badgeY, greaterThan(metadataY));
    });

    testWidgets('无任何 badge 时只显示标题和元数据两行', (tester) async {
      final item = createTestAudioItem(
        name: 'Audio without transcript',
        transcriptPath: null,
        transcriptSource: null,
      );

      await tester.pumpWidget(buildTile(item));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('audio_list_tile_transcript_badge')),
        findsNothing,
      );
      expect(find.byKey(const Key('audio_list_tile_badge_row')), findsNothing);
      expect(find.byIcon(Icons.subtitles_outlined), findsNothing);
      expect(find.text('Transcript'), findsNothing);
    });
  });

  group('AudioListTile 导出 PDF 菜单项', () {
    Widget buildTile(AudioItem item) {
      return createTestApp(
        Center(
          child: SizedBox(width: 360, child: AudioListTile(audioItem: item)),
        ),
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
          ),
        ],
      );
    }

    testWidgets('有字幕时菜单包含「导出 PDF」', (tester) async {
      final item = createTestAudioItem();

      await tester.pumpWidget(buildTile(item));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Export PDF'), findsOneWidget);
    });

    testWidgets('无字幕时菜单不含「导出 PDF」', (tester) async {
      final item = createTestAudioItem(
        transcriptPath: null,
        transcriptSource: null,
      );

      await tester.pumpWidget(buildTile(item));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Export PDF'), findsNothing);
    });
  });

  group('AudioListTile 删除下载菜单项', () {
    Widget buildTile(AudioItem item) {
      return createTestApp(
        Center(
          child: SizedBox(width: 360, child: AudioListTile(audioItem: item)),
        ),
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
          ),
        ],
      );
    }

    testWidgets('官方已下载音频菜单含「删除下载」', (tester) async {
      final item = createTestAudioItem(
        name: 'Official Audio',
      ).copyWith(remoteAudioId: 'remote-1');

      await tester.pumpWidget(buildTile(item));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Audio'), findsOneWidget);
      // 官方音频不提供整条删除
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('官方未下载音频菜单不含「删除下载」', (tester) async {
      final item = createTestAudioItem(
        name: 'Official Audio',
      ).copyWith(remoteAudioId: 'remote-1', audioPath: null);

      await tester.pumpWidget(buildTile(item));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Audio'), findsNothing);
    });

    testWidgets('播客已下载单集菜单含「删除下载」', (tester) async {
      final item = createTestAudioItem(
        name: 'Podcast Episode',
      ).copyWith(podcastEpisodeGuid: 'guid-1');

      await tester.pumpWidget(buildTile(item));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Audio'), findsOneWidget);
    });

    testWidgets('用户自建音频菜单不含「删除下载」（仅普通删除）', (tester) async {
      final item = createTestAudioItem(name: 'User Audio');

      await tester.pumpWidget(buildTile(item));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Audio'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('点「删除下载」清空 audioPath', (tester) async {
      final item = createTestAudioItem(
        name: 'Official Audio',
      ).copyWith(remoteAudioId: 'remote-1');
      final library = TestAudioLibrary(AudioLibraryState(audioItems: [item]));

      await tester.pumpWidget(
        createTestApp(
          Center(
            child: SizedBox(width: 360, child: AudioListTile(audioItem: item)),
          ),
          overrides: [audioLibraryProvider.overrideWith(() => library)],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Audio'));
      await tester.pumpAndSettle();

      expect(library.state.audioItems.single.audioPath, isNull);
    });
  });

  group('AudioListTile 内容异常警告', () {
    Widget buildTile(AudioItem item) {
      return createTestApp(
        Center(
          child: SizedBox(width: 360, child: AudioListTile(audioItem: item)),
        ),
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
          ),
        ],
      );
    }

    testWidgets('suspectEmpty 时显示警告徽章', (tester) async {
      final item = createTestAudioItem(
        name: 'Empty Audio',
        transcriptPath: null,
        transcriptSource: null,
      ).copyWith(contentStatus: AudioContentStatus.suspectEmpty);

      await tester.pumpWidget(buildTile(item));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('audio_list_tile_content_warning_badge')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Possibly empty'), findsOneWidget);
    });

    testWidgets('suspectEmpty 且 totalDuration=0 时不渲染时长行', (tester) async {
      final item = createTestAudioItem(
        name: 'Empty Audio',
        totalDuration: 0,
        transcriptPath: null,
        transcriptSource: null,
      ).copyWith(contentStatus: AudioContentStatus.suspectEmpty);

      await tester.pumpWidget(buildTile(item));
      await tester.pumpAndSettle();

      expect(find.textContaining('Duration:'), findsNothing);
      expect(
        find.byKey(const Key('audio_list_tile_content_warning_badge')),
        findsOneWidget,
      );
    });

    testWidgets('contentStatus=ok 时不显示警告徽章', (tester) async {
      final item = createTestAudioItem(
        name: 'Normal Audio',
        transcriptPath: null,
        transcriptSource: null,
      ).copyWith(contentStatus: AudioContentStatus.ok);

      await tester.pumpWidget(buildTile(item));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('audio_list_tile_content_warning_badge')),
        findsNothing,
      );
    });

    testWidgets('contentStatus=null（未检测）时不显示警告徽章', (tester) async {
      final item = createTestAudioItem(
        name: 'Unchecked Audio',
        transcriptPath: null,
        transcriptSource: null,
      );

      await tester.pumpWidget(buildTile(item));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('audio_list_tile_content_warning_badge')),
        findsNothing,
      );
    });
  });

  group('AudioListTile 日期元信息', () {
    Widget buildTile(AudioItem item) {
      return createTestApp(
        Center(
          child: SizedBox(width: 360, child: AudioListTile(audioItem: item)),
        ),
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
          ),
        ],
      );
    }

    testWidgets('用户自建普通音频显示「添加于」', (tester) async {
      final item = createTestAudioItem(name: 'User Audio');

      await tester.pumpWidget(buildTile(item));
      await tester.pumpAndSettle();

      expect(find.textContaining('Added'), findsOneWidget);
      expect(find.textContaining('Published'), findsNothing);
    });

    testWidgets('podcast 单集显示「发布于」而非「添加于」', (tester) async {
      final item = createTestAudioItem(name: 'Podcast Episode').copyWith(
        podcastEpisodeGuid: 'episode-guid-1',
        podcastEnclosureUrl: 'https://example.com/episode.mp3',
        originalDate: DateTime(2025, 3, 31),
      );

      await tester.pumpWidget(buildTile(item));
      await tester.pumpAndSettle();

      expect(find.textContaining('Published'), findsOneWidget);
      expect(find.textContaining('Added'), findsNothing);
    });
  });

  group('AudioListTile Podcast 单集', () {
    testWidgets('未下载单集显示对应的懒下载进度', (tester) async {
      final item =
          createTestAudioItem(
            name: 'Podcast Episode',
            transcriptPath: null,
            transcriptSource: null,
          ).copyWith(
            audioPath: null,
            podcastEpisodeGuid: 'episode-guid-1',
            podcastEnclosureUrl: 'https://example.com/episode.mp3',
            podcastEnclosureType: 'audio/mpeg',
          );

      await tester.pumpWidget(
        createTestApp(
          Center(
            child: SizedBox(width: 420, child: AudioListTile(audioItem: item)),
          ),
          overrides: [
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
            ),
            podcastDownloadControllerProvider.overrideWith(
              _DownloadingAudioImportController.new,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('audio_list_tile_download_progress')),
        findsOneWidget,
      );
      expect(find.textContaining('Downloading audio 42%'), findsOneWidget);
    });

    testWidgets('未下载单集点击时只下载音频并显示行内进度', (tester) async {
      final controller = _PendingAudioImportController();
      final item =
          createTestAudioItem(
            name: 'Podcast Episode',
            transcriptPath: null,
            transcriptSource: null,
          ).copyWith(
            audioPath: null,
            podcastEpisodeGuid: 'episode-guid-1',
            podcastEnclosureUrl: 'https://example.com/episode.mp3',
            podcastEnclosureType: 'audio/mpeg',
          );

      await tester.pumpWidget(
        createTestApp(
          Center(
            child: SizedBox(width: 420, child: AudioListTile(audioItem: item)),
          ),
          overrides: [
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
            ),
            podcastDownloadControllerProvider.overrideWith(() => controller),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Podcast Episode'));
      await tester.pump();

      // 下载进度落在列表项行内（不定进度，无百分比），且仅下载音频。
      expect(
        find.byKey(const Key('audio_list_tile_download_progress')),
        findsOneWidget,
      );
      expect(find.text('Downloading audio'), findsOneWidget);
      expect(find.text('Downloading audio and subtitle...'), findsNothing);

      controller.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('未下载单集左侧显示下载图标而非进度环', (tester) async {
      final item =
          createTestAudioItem(
            name: 'Podcast Episode',
            transcriptPath: null,
            transcriptSource: null,
          ).copyWith(
            audioPath: null,
            podcastEpisodeGuid: 'episode-guid-1',
            podcastEnclosureUrl: 'https://example.com/episode.mp3',
            podcastEnclosureType: 'audio/mpeg',
          );

      await tester.pumpWidget(
        createTestApp(
          Center(
            child: SizedBox(width: 420, child: AudioListTile(audioItem: item)),
          ),
          overrides: [
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('audio_list_tile_download_icon')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('audio_list_tile_downloading_icon')),
        findsNothing,
      );
    });

    testWidgets('单集下载中时左侧显示下载进度环', (tester) async {
      final item =
          createTestAudioItem(
            name: 'Podcast Episode',
            transcriptPath: null,
            transcriptSource: null,
          ).copyWith(
            audioPath: null,
            podcastEpisodeGuid: 'episode-guid-1',
            podcastEnclosureUrl: 'https://example.com/episode.mp3',
            podcastEnclosureType: 'audio/mpeg',
          );

      await tester.pumpWidget(
        createTestApp(
          Center(
            child: SizedBox(width: 420, child: AudioListTile(audioItem: item)),
          ),
          overrides: [
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
            ),
            podcastDownloadControllerProvider.overrideWith(
              _DownloadingAudioImportController.new,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('audio_list_tile_downloading_icon')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('audio_list_tile_download_icon')),
        findsNothing,
      );
    });

    testWidgets('已下载单集左侧显示学习进度图标而非下载图标', (tester) async {
      final item =
          createTestAudioItem(
            name: 'Podcast Episode',
            transcriptPath: null,
            transcriptSource: null,
          ).copyWith(
            audioPath: 'podcast/episode.m4a',
            podcastEpisodeGuid: 'episode-guid-1',
            podcastEnclosureUrl: 'https://example.com/episode.mp3',
            podcastEnclosureType: 'audio/mpeg',
          );

      await tester.pumpWidget(
        createTestApp(
          Center(
            child: SizedBox(width: 420, child: AudioListTile(audioItem: item)),
          ),
          overrides: [
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('audio_list_tile_download_icon')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('audio_list_tile_downloading_icon')),
        findsNothing,
      );
    });

    testWidgets('未下载官方音频左侧显示下载图标而非进度环', (tester) async {
      final item = createTestAudioItem(
        name: 'Official Audio',
        transcriptPath: null,
        transcriptSource: null,
      ).copyWith(audioPath: null, remoteAudioId: 'remote-audio-1');

      await tester.pumpWidget(
        createTestApp(
          Center(
            child: SizedBox(width: 420, child: AudioListTile(audioItem: item)),
          ),
          overrides: [
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('audio_list_tile_download_icon')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('audio_list_tile_downloading_icon')),
        findsNothing,
      );
    });

    testWidgets('官方音频下载中时左侧显示下载进度环', (tester) async {
      final item = createTestAudioItem(
        name: 'Official Audio',
        transcriptPath: null,
        transcriptSource: null,
      ).copyWith(audioPath: null, remoteAudioId: 'remote-audio-1');

      await tester.pumpWidget(
        createTestApp(
          Center(
            child: SizedBox(width: 420, child: AudioListTile(audioItem: item)),
          ),
          overrides: [
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
            ),
            officialDownloadProvider.overrideWith(
              () => _DownloadingOfficial(item.id),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('audio_list_tile_downloading_icon')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('audio_list_tile_download_icon')),
        findsNothing,
      );
      // 官方下载与播客一致：行内进度条（无弹窗）。
      expect(
        find.byKey(const Key('audio_list_tile_download_progress')),
        findsOneWidget,
      );
      expect(find.textContaining('Downloading audio 42%'), findsOneWidget);
    });

    testWidgets('已下载官方音频左侧显示学习进度图标而非下载图标', (tester) async {
      final item =
          createTestAudioItem(
            name: 'Official Audio',
            transcriptPath: null,
            transcriptSource: null,
          ).copyWith(
            audioPath: 'official/audio.m4a',
            remoteAudioId: 'remote-audio-1',
          );

      await tester.pumpWidget(
        createTestApp(
          Center(
            child: SizedBox(width: 420, child: AudioListTile(audioItem: item)),
          ),
          overrides: [
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('audio_list_tile_download_icon')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('audio_list_tile_downloading_icon')),
        findsNothing,
      );
    });

    testWidgets('菜单管理字幕 AI 转录音频过长时显示弹窗内错误提示', (tester) async {
      final item = createTestAudioItem(
        name: 'Long Audio',
        totalDuration: 31 * 60, // 超过 AI 转录 30 分钟上限
      ).copyWith(transcriptSource: TranscriptSource.local);

      await tester.pumpWidget(
        createTestApp(
          Center(
            child: SizedBox(width: 420, child: AudioListTile(audioItem: item)),
          ),
          overrides: [
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
            ),
            supabaseSessionProvider.overrideWith(
              (ref) => Stream<Session?>.value(_signedInSession()),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Subtitles'));
      await tester.pumpAndSettle();

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

    testWidgets('单集信息展示简介、网页链接和音频下载链接', (tester) async {
      final item =
          createTestAudioItem(
            name: 'Podcast Episode',
            transcriptPath: null,
            transcriptSource: null,
            totalDuration: 1830,
          ).copyWith(
            audioPath: null,
            podcastEpisodeGuid: 'episode-guid-1',
            podcastEnclosureUrl: 'https://example.com/episode.mp3',
            podcastEnclosureType: 'audio/mpeg',
            podcastDescription: 'Episode summary for learners.',
            podcastImageUrl: 'https://example.com/episode.jpg',
            podcastLink: 'https://example.com/episode',
          );

      await tester.pumpWidget(
        createTestApp(
          Center(
            child: SizedBox(width: 420, child: AudioListTile(audioItem: item)),
          ),
          overrides: [
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Episode Info'));
      await tester.pumpAndSettle();

      expect(find.text('Podcast Episode'), findsWidgets);
      expect(find.text('Episode summary for learners.'), findsOneWidget);
      expect(find.text('Link'), findsOneWidget);
      expect(find.text('https://example.com/episode'), findsOneWidget);
      expect(find.text('Audio URL'), findsOneWidget);
      expect(find.text('https://example.com/episode.mp3'), findsOneWidget);
      expect(find.text('GUID'), findsNothing);
      expect(find.text('episode-guid-1'), findsNothing);
      expect(find.text('Audio Type'), findsNothing);
      expect(find.text('audio/mpeg'), findsNothing);
      expect(find.byIcon(Icons.open_in_new_rounded), findsNWidgets(2));
      // 时长展示在弹窗 meta 行；audioDuration 文案带「Duration: 」前缀。
      // 列表行同样渲染该时长，故限定在底部弹窗内断言唯一。
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Duration: 30:30'),
        ),
        findsOneWidget,
      );
      // 单集封面区域渲染（无图时回退 podcasts 占位图标）。
      expect(find.byIcon(Icons.podcasts_rounded), findsWidgets);
    });

    testWidgets('单集信息用 http guid 兜底展示网页链接', (tester) async {
      final item =
          createTestAudioItem(
            name: 'VOA Episode',
            transcriptPath: null,
            transcriptSource: null,
          ).copyWith(
            audioPath: null,
            podcastEpisodeGuid:
                'https://learningenglish.voanews.com/a/8008768.html',
            podcastEnclosureUrl: 'https://voa-audio.voanews.eu/vle/episode.mp3',
            podcastDescription: 'VOA episode summary.',
          );

      await tester.pumpWidget(
        createTestApp(
          Center(
            child: SizedBox(width: 420, child: AudioListTile(audioItem: item)),
          ),
          overrides: [
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Episode Info'));
      await tester.pumpAndSettle();

      expect(find.text('Link'), findsOneWidget);
      expect(
        find.text('https://learningenglish.voanews.com/a/8008768.html'),
        findsOneWidget,
      );
      expect(find.text('Audio URL'), findsOneWidget);
      expect(
        find.text('https://voa-audio.voanews.eu/vle/episode.mp3'),
        findsOneWidget,
      );
    });
  });

  group('AudioListTile 置顶菜单', () {
    final baseItem = createTestAudioItem(id: 'star-1', name: 'Star Audio');

    Widget buildTile(AudioLibraryState libraryState) {
      return createTestApp(
        const _AudioListTileWrapper(),
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(libraryState),
          ),
        ],
      );
    }

    Widget buildCompactTile(AudioLibraryState libraryState) {
      return createTestApp(
        Center(
          child: SizedBox(width: 360, child: const _AudioListTileWrapper()),
        ),
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(libraryState),
          ),
        ],
      );
    }

    testWidgets('右侧仅显示一个菜单按钮', (tester) async {
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [baseItem])),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('audio_list_tile_menu_hit_area')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
      expect(find.byIcon(Icons.push_pin), findsNothing);
    });

    testWidgets('已置顶时使用淡背景色标记', (tester) async {
      final pinnedItem = baseItem.copyWith(isPinned: true);
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [pinnedItem])),
      );
      await tester.pumpAndSettle();

      final card = tester.widget<Card>(find.byType(Card).first);
      expect(card.color, isNotNull);
    });

    testWidgets('未置顶时卡片保持默认背景', (tester) async {
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [baseItem])),
      );
      await tester.pumpAndSettle();

      final card = tester.widget<Card>(find.byType(Card).first);
      expect(card.color, isNull);
    });

    testWidgets('已置顶时 leading 音频图标颜色不受置顶影响（显示进度状态）', (tester) async {
      final pinnedItem = baseItem.copyWith(isPinned: true);
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [pinnedItem])),
      );
      await tester.pumpAndSettle();

      // leading 图标现在显示进度状态，不再根据置顶变色
      final audioIcon = tester.widget<Icon>(find.byIcon(Icons.graphic_eq));
      expect(audioIcon.color, isNotNull);
      expect(audioIcon.color, isNot(AppTheme.bookmarkColor));
    });

    testWidgets('菜单内点击置顶触发 togglePin 并更新背景', (tester) async {
      await tester.pumpWidget(
        buildCompactTile(AudioLibraryState(audioItems: [baseItem])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();
      expect(find.text('Pin to Top'), findsOneWidget);

      await tester.tap(find.text('Pin to Top'));
      await tester.pumpAndSettle();

      final card = tester.widget<Card>(find.byType(Card).first);
      expect(card.color, isNotNull);
    });

    testWidgets('菜单首项根据状态显示 pin 或 unpin', (tester) async {
      await tester.pumpWidget(
        buildTile(
          AudioLibraryState(audioItems: [baseItem.copyWith(isPinned: true)]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Unpin'), findsOneWidget);
    });

    testWidgets('官方音频菜单显示更新字幕，不显示管理字幕', (tester) async {
      final officialItem = baseItem.copyWith(
        remoteAudioId: 'remote-audio-1',
        transcriptPath: null,
      );
      await tester.pumpWidget(
        buildCompactTile(AudioLibraryState(audioItems: [officialItem])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Update Subtitle'), findsOneWidget);
      expect(find.text('Manage Subtitles'), findsNothing);
      expect(find.text('Edit subtitles'), findsNothing);
    });

    testWidgets('用户音频有字幕时显示编辑字幕菜单', (tester) async {
      final item = baseItem.copyWith(transcriptPath: 'transcripts/user.srt');
      await tester.pumpWidget(
        buildCompactTile(AudioLibraryState(audioItems: [item])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Manage Subtitles'), findsOneWidget);
      expect(find.text('Edit subtitles'), findsOneWidget);
    });

    testWidgets('用户音频无字幕时不显示编辑字幕菜单', (tester) async {
      final item = baseItem.copyWith(
        transcriptPath: null,
        transcriptSource: null,
      );
      await tester.pumpWidget(
        buildCompactTile(AudioLibraryState(audioItems: [item])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Manage Subtitles'), findsOneWidget);
      expect(find.text('Edit subtitles'), findsNothing);
    });

    testWidgets('播客单集菜单不显示删除项，仍保留单集信息项', (tester) async {
      final episode = baseItem.copyWith(
        podcastEpisodeGuid: 'episode-guid-1',
        podcastEnclosureUrl: 'https://example.com/episode.mp3',
        transcriptPath: null,
        transcriptSource: null,
      );
      await tester.pumpWidget(
        buildCompactTile(AudioLibraryState(audioItems: [episode])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      // 单集由 feed 统一管理，删除后刷新会重新插回，故隐藏删除项。
      expect(find.text('Delete'), findsNothing);
      // 播客专属能力（单集信息）未被误伤。
      expect(find.text('Episode Info'), findsOneWidget);
    });

    testWidgets('用户音频菜单仍显示删除项', (tester) async {
      final item = baseItem.copyWith(
        transcriptPath: null,
        transcriptSource: null,
      );
      await tester.pumpWidget(
        buildCompactTile(AudioLibraryState(audioItems: [item])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Episode Info'), findsNothing);
      expect(find.byType(PopupMenuDivider), findsOneWidget);
    });

    testWidgets('点击官方更新字幕先弹出清空进度确认框', (tester) async {
      final officialItem = baseItem.copyWith(
        remoteAudioId: 'remote-audio-1',
        transcriptPath: 'transcripts/official_x.srt',
      );
      await tester.pumpWidget(
        buildCompactTile(AudioLibraryState(audioItems: [officialItem])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update Subtitle'));
      await tester.pumpAndSettle();

      expect(find.text('Update subtitle?'), findsOneWidget);
      expect(
        find.textContaining('clear all bookmarked sentences'),
        findsOneWidget,
      );
    });
  });

  group('AudioListTile 当前播放展示', () {
    final baseItem = createTestAudioItem(
      id: 'playing-1',
      name: 'Playing Audio',
    );

    Widget buildCollectionTile() {
      return createTestApp(
        AudioListTile(audioItem: baseItem, collectionId: 'collection-1'),
        overrides: [
          appSettingsProvider.overrideWith(
            () => TestAppSettings(const AppSettingsState()),
          ),
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [baseItem])),
          ),
          collectionListProvider.overrideWith(() => TestCollectionList()),
          tagListProvider.overrideWith(() => TestTagList()),
          listeningPracticeProvider.overrideWith(
            () => TestListeningPractice(
              ListeningPracticeState(currentAudioItem: baseItem),
            ),
          ),
          audioEngineProvider.overrideWith(() => TestAudioEngine()),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(),
          ),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          blindListenPlayerProvider.overrideWith(() => TestBlindListenPlayer()),
        ],
      );
    }

    testWidgets('合集上下文当前播放时不显示 Last 标签', (tester) async {
      await tester.pumpWidget(buildCollectionTile());
      await tester.pumpAndSettle();

      final card = tester.widget<Card>(find.byType(Card).first);
      expect(card.color, isNull, reason: '当前播放态不应持久保留卡片背景色');
      expect(find.text('Last'), findsNothing);
      expect(find.text('上次'), findsNothing);
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });
  });

  group('AudioListTile 暂停学习菜单', () {
    final baseItem = createTestAudioItem(id: 'pause-1', name: 'Pause Audio');

    LearningProgress makeProgress({required bool isPaused}) {
      return LearningProgress(
        audioItemId: baseItem.id,
        currentStage: LearningStage.review2,
        currentSubStage: SubStageType.blindListen,
        lastStageCompletedAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
        isPaused: isPaused,
      );
    }

    Widget buildWithProgress(LearningProgress progress) {
      return createTestApp(
        Center(
          child: SizedBox(width: 360, child: const _AudioListTileWrapper()),
        ),
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [baseItem])),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(
                progressMap: {progress.audioItemId: progress},
              ),
            ),
          ),
        ],
      );
    }

    testWidgets('未暂停时菜单显示 Pause Learning，点击弹出确认弹窗', (tester) async {
      await tester.pumpWidget(buildWithProgress(makeProgress(isPaused: false)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Pause Learning'), findsOneWidget);
      expect(find.text('Resume Learning'), findsNothing);

      await tester.tap(find.text('Pause Learning'));
      await tester.pumpAndSettle();

      expect(find.text('Pause Learning?'), findsOneWidget);
      expect(
        find.textContaining('Review scheduling for this audio will stop'),
        findsOneWidget,
      );
    });

    testWidgets('暂停态下菜单显示 Resume Learning，且卡片显示 Paused chip', (tester) async {
      await tester.pumpWidget(buildWithProgress(makeProgress(isPaused: true)));
      await tester.pumpAndSettle();

      // 卡片上的轮次 chip 被替换为「Paused」
      expect(find.text('Paused'), findsOneWidget);

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Resume Learning'), findsOneWidget);
      expect(find.text('Pause Learning'), findsNothing);
    });

    testWidgets('未开始学习的音频不显示暂停菜单项', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Center(
            child: SizedBox(width: 360, child: const _AudioListTileWrapper()),
          ),
          overrides: [
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(AudioLibraryState(audioItems: [baseItem])),
            ),
            learningProgressNotifierProvider.overrideWith(
              () => TestLearningProgressNotifier(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Pause Learning'), findsNothing);
      expect(find.text('Resume Learning'), findsNothing);
    });
  });
}
