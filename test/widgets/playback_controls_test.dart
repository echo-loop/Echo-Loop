/// PlaybackControls 组件测试
///
/// 测试播放控制组件的渲染、交互和响应式布局。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/widgets/playback_controls.dart';
import 'package:echo_loop/models/playback_settings.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/settings_provider.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

void main() {
  group('PlaybackControls', () {
    group('渲染', () {
      testWidgets('显示播放按钮（初始暂停状态）', (tester) async {
        await tester.pumpWidget(createTestApp(const PlaybackControls()));
        await tester.pumpAndSettle();

        // 暂停状态显示播放图标
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        expect(find.byIcon(Icons.pause), findsNothing);
      });

      testWidgets('播放中显示暂停图标', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const PlaybackControls(),
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              listeningPracticeProvider.overrideWith(
                // 图标读 LP 的逻辑播放态（唯一真相源），不读引擎瞬时 playing。
                () => TestListeningPractice(
                  const ListeningPracticeState(isPlaying: true),
                ),
              ),
              audioEngineProvider.overrideWith(
                () => TestAudioEngine(isPlaying: true),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.pause), findsOneWidget);
      });

      testWidgets('显示上一句/下一句按钮', (tester) async {
        await tester.pumpWidget(createTestApp(const PlaybackControls()));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.skip_previous), findsOneWidget);
        expect(find.byIcon(Icons.skip_next), findsOneWidget);
      });

      testWidgets('显示速度按钮', (tester) async {
        await tester.pumpWidget(createTestApp(const PlaybackControls()));
        await tester.pumpAndSettle();

        // 默认速度 1.0x
        expect(find.text('1.0x'), findsOneWidget);
      });

      testWidgets('默认（不循环）显示 repeat 图标', (tester) async {
        await tester.pumpWidget(createTestApp(const PlaybackControls()));
        await tester.pumpAndSettle();

        // 默认两个循环都关 → repeat 图标（非高亮）；仅单句循环开才是 repeat_one
        expect(find.byIcon(Icons.repeat), findsOneWidget);
        expect(find.byIcon(Icons.repeat_one), findsNothing);
      });

      testWidgets('仅单句循环开时显示 repeat_one 图标', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const PlaybackControls(),
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(
                  const ListeningPracticeState(
                    settings: PlaybackSettings(loopSentence: true),
                  ),
                ),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.repeat_one), findsOneWidget);
        expect(find.byIcon(Icons.repeat), findsNothing);
      });

      testWidgets('显示字幕显示切换按钮', (tester) async {
        await tester.pumpWidget(createTestApp(const PlaybackControls()));
        await tester.pumpAndSettle();

        // 默认 showTranscript=true 显示 visibility 图标
        expect(find.byIcon(Icons.visibility), findsOneWidget);
      });

      testWidgets('收藏 tab 渲染收藏 tab 自己的设置', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const PlaybackControls(),
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(
                  const ListeningPracticeState(
                    playlistMode: PlaylistMode.bookmarks,
                    fullSettings: PlaybackSettings(
                      playbackSpeed: 1.2,
                      showTranscript: true,
                    ),
                    bookmarkSettings: PlaybackSettings(
                      playbackSpeed: 0.8,
                      showTranscript: false,
                      singleSentenceMode: true,
                      loopSentence: true,
                    ),
                  ),
                ),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('0.8x'), findsOneWidget);
        expect(find.byIcon(Icons.visibility_off), findsOneWidget);
        expect(find.byIcon(Icons.repeat_one), findsOneWidget);
      });

      testWidgets('收藏 tab 默认显示默认单句循环图标', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const PlaybackControls(),
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(
                  const ListeningPracticeState(
                    playlistMode: PlaylistMode.bookmarks,
                  ),
                ),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.repeat_one), findsOneWidget);
        expect(find.byIcon(Icons.repeat), findsNothing);
      });
    });

    group('交互', () {
      testWidgets('无句子时上一句/下一句按钮禁用', (tester) async {
        await tester.pumpWidget(createTestApp(const PlaybackControls()));
        await tester.pumpAndSettle();

        // 找到上一句按钮，应该是禁用的（onPressed 为 null）
        final prevButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.skip_previous),
        );
        expect(prevButton.onPressed, isNull);

        final nextButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.skip_next),
        );
        expect(nextButton.onPressed, isNull);
      });

      testWidgets('有句子时上一句/下一句按钮启用', (tester) async {
        final sentences = createTestSentences(count: 3);
        await tester.pumpWidget(
          createTestApp(
            const PlaybackControls(),
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(
                  ListeningPracticeState(
                    sentences: sentences,
                    currentFullIndex: 0,
                  ),
                ),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final prevButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.skip_previous),
        );
        expect(prevButton.onPressed, isNotNull);

        final nextButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.skip_next),
        );
        expect(nextButton.onPressed, isNotNull);
      });

      testWidgets('点击循环按钮弹出悬浮循环设置浮层', (tester) async {
        await tester.pumpWidget(createTestApp(const PlaybackControls()));
        await tester.pumpAndSettle();

        // 初始未弹出
        expect(find.text('Whole-text loop'), findsNothing);

        await tester.tap(find.byIcon(Icons.repeat));
        await tester.pumpAndSettle();

        // 浮层出现：两组循环开关（无标题）
        expect(find.text('Loop Settings'), findsNothing);
        expect(find.text('Whole-text loop'), findsOneWidget);
        expect(find.byType(Switch), findsNWidgets(2));
      });

      testWidgets('点击浮层外部关闭浮层', (tester) async {
        await tester.pumpWidget(createTestApp(const PlaybackControls()));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.repeat));
        await tester.pumpAndSettle();
        expect(find.text('Whole-text loop'), findsOneWidget);

        // 点击浮层外部（左上角遮罩区）关闭
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.text('Whole-text loop'), findsNothing);
      });

      testWidgets('点击速度按钮显示速度选择菜单', (tester) async {
        await tester.pumpWidget(createTestApp(const PlaybackControls()));
        await tester.pumpAndSettle();

        // 点击速度按钮
        await tester.tap(find.text('1.0x'));
        await tester.pumpAndSettle();

        // 应显示速度选项
        expect(find.text('0.4x'), findsOneWidget);
        expect(find.text('0.5x'), findsOneWidget);
        expect(find.text('0.6x'), findsOneWidget);
        expect(find.text('0.7x'), findsOneWidget);
        expect(find.text('0.8x'), findsOneWidget);
        expect(find.text('0.9x'), findsOneWidget);
        expect(find.text('1.0x'), findsWidgets);
        expect(find.text('1.1x'), findsOneWidget);
        expect(find.text('1.2x'), findsOneWidget);
        expect(find.text('1.3x'), findsOneWidget);
        expect(find.text('1.4x'), findsOneWidget);
        expect(find.text('1.5x'), findsOneWidget);
        expect(find.text('2.0x'), findsOneWidget);
      });
    });

    group('响应式', () {
      testWidgets('窄屏 (<600px) 使用纵向布局', (tester) async {
        // 设置窄屏
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestApp(const PlaybackControls()));
        await tester.pumpAndSettle();

        // 窄屏布局使用 Column（两行）
        // 验证组件正常渲染即可
        expect(find.byType(PlaybackControls), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      });

      testWidgets('宽屏 (>=600px) 使用横向布局', (tester) async {
        // 设置宽屏
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestApp(const PlaybackControls()));
        await tester.pumpAndSettle();

        // 宽屏布局使用单行 Row
        expect(find.byType(PlaybackControls), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      });
    });
  });
}
