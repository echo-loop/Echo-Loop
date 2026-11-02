/// LoopSettingsPopup 组件测试
///
/// 测试循环设置浮层的渲染与交互：两组独立循环（整篇 / 单句）各有主开关，
/// 开启后展开「标签 + 滑条 + 值」单行滑块。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:echo_loop/widgets/settings_dialog.dart';
import 'package:echo_loop/models/playback_settings.dart';
import 'package:echo_loop/models/repeat_count_options.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

/// 辅助函数：直接渲染循环设置浮层内容。
///
/// 单句循环依赖字幕分句，浮层会在无字幕时隐藏它。这些用例验证「有字幕」下的完整
/// 双循环行为，故默认注入测试句子；显式传入已含句子的 state 时保持不变。
Widget _buildLoopPopupTest({ListeningPracticeState? practiceState}) {
  final base = practiceState ?? const ListeningPracticeState();
  final state = base.hasSentences
      ? base
      : base.copyWith(sentences: createTestSentences(count: 3));
  return createTestApp(
    const Align(child: LoopSettingsPopup()),
    overrides: dedupeOverrides([
      appSettingsProvider.overrideWith(() => TestAppSettings()),
      listeningPracticeProvider.overrideWith(
        () => TestListeningPractice(state),
      ),
      audioEngineProvider.overrideWith(() => TestAudioEngine()),
    ]),
  );
}

void main() {
  group('LoopSettingsPopup', () {
    group('渲染', () {
      testWidgets('显示两组循环主开关（无标题）', (tester) async {
        await tester.pumpWidget(_buildLoopPopupTest());
        await tester.pumpAndSettle();

        // 浮层不再显示「循环设置」标题
        expect(find.text('Loop Settings'), findsNothing);
        expect(find.text('loop entire media'), findsOneWidget);
        expect(find.text('Single-sentence loop'), findsOneWidget);
        expect(find.byType(Switch), findsNWidgets(2));
      });

      testWidgets('两个循环都关时不显示子滑块', (tester) async {
        await tester.pumpWidget(_buildLoopPopupTest());
        await tester.pumpAndSettle();

        expect(find.byType(Slider), findsNothing);
        expect(find.text('Repeat Count'), findsNothing);
      });

      testWidgets('整篇循环开启时展开重复次数 + 间隔滑块', (tester) async {
        await tester.pumpWidget(
          _buildLoopPopupTest(
            practiceState: const ListeningPracticeState(
              settings: PlaybackSettings(loopWhole: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Slider), findsNWidgets(2));
        expect(find.text('Repeat Count'), findsOneWidget);
        // 间隔 label 不带单位；值列英文用「Ns」、次数用「Nx」
        expect(find.text('Interval Duration'), findsOneWidget);
        expect(find.text('3s'), findsWidgets);
        expect(find.text('3x'), findsWidgets);
      });

      testWidgets('循环次数滑块包含 20/30/40/50 和无限位置', (tester) async {
        await tester.pumpWidget(
          _buildLoopPopupTest(
            practiceState: const ListeningPracticeState(
              settings: PlaybackSettings(loopWhole: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final slider = tester.widget<Slider>(find.byType(Slider).first);
        expect(slider.min, 0);
        expect(slider.max, kRepeatCountOptions.length - 1);
        expect(slider.divisions, kRepeatCountOptions.length - 1);
      });

      testWidgets('两组循环同时开启时展开 4 个滑块', (tester) async {
        await tester.pumpWidget(
          _buildLoopPopupTest(
            practiceState: const ListeningPracticeState(
              settings: PlaybackSettings(loopWhole: true, loopSentence: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Slider), findsNWidgets(4));
      });

      testWidgets('无限次数显示 ∞ 文案', (tester) async {
        await tester.pumpWidget(
          _buildLoopPopupTest(
            practiceState: const ListeningPracticeState(
              settings: PlaybackSettings(loopWhole: true, wholeLoopCount: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('∞'), findsOneWidget);
      });

      testWidgets('收藏 tab 默认展开单句循环 1 次 + 1 秒', (tester) async {
        await tester.pumpWidget(
          _buildLoopPopupTest(
            practiceState: const ListeningPracticeState(
              playlistMode: PlaylistMode.bookmarks,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Slider), findsNWidgets(2));
        expect(find.text('1x'), findsOneWidget);
        expect(find.text('1s'), findsOneWidget);
      });

      testWidgets('无字幕只显示整篇循环，隐藏单句循环', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const Align(child: LoopSettingsPopup()),
            overrides: dedupeOverrides([
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              listeningPracticeProvider.overrideWith(
                // 默认 state.sentences 为空 → 无字幕。
                () => TestListeningPractice(const ListeningPracticeState()),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('loop entire media'), findsOneWidget);
        expect(find.text('Single-sentence loop'), findsNothing);
        expect(find.byType(Switch), findsOneWidget);
      });
    });

    group('交互', () {
      testWidgets('切换主开关触发 updateSettings 并展开子滑块', (tester) async {
        late ListeningPractice controller;
        await tester.pumpWidget(
          createTestApp(
            Align(
              child: Consumer(
                builder: (context, ref, _) {
                  controller = ref.read(listeningPracticeProvider.notifier);
                  return const LoopSettingsPopup();
                },
              ),
            ),
            overrides: dedupeOverrides([
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(const ListeningPracticeState()),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        // 点击「整篇循环」主开关
        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();

        expect(controller.state.settings.loopWhole, isTrue);
        expect(find.byType(Slider), findsNWidgets(2));
      });

      testWidgets('收藏 tab 修改循环设置时不串改全文 tab', (tester) async {
        late ListeningPractice controller;
        await tester.pumpWidget(
          createTestApp(
            Align(
              child: Consumer(
                builder: (context, ref, _) {
                  controller = ref.read(listeningPracticeProvider.notifier);
                  return const LoopSettingsPopup();
                },
              ),
            ),
            overrides: dedupeOverrides([
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(
                  const ListeningPracticeState(
                    playlistMode: PlaylistMode.bookmarks,
                    fullSettings: PlaybackSettings(loopWhole: true),
                    bookmarkSettings: PlaybackSettings(loopWhole: false),
                  ),
                ),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();

        expect(controller.state.fullSettings.loopWhole, isTrue);
        expect(controller.state.bookmarkSettings.loopWhole, isTrue);
      });
    });
  });
}
