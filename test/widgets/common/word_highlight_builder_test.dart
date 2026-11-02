import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/word_highlight_binding.dart';
import 'package:echo_loop/models/word_timestamp.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/word_highlight_provider.dart';
import 'package:echo_loop/widgets/common/word_highlight_builder.dart';
import '../../helpers/mock_providers.dart';

const _timestamps = [
  WordTimestamp(
    word: 'hello',
    startTime: Duration(milliseconds: 100),
    endTime: Duration(milliseconds: 300),
  ),
  WordTimestamp(
    word: 'world',
    startTime: Duration(milliseconds: 300),
    endTime: Duration(milliseconds: 600),
  ),
];

const _timestampsAtOneSecond = [
  WordTimestamp(
    word: 'hello',
    startTime: Duration(milliseconds: 1000),
    endTime: Duration(milliseconds: 1300),
  ),
  WordTimestamp(
    word: 'world',
    startTime: Duration(milliseconds: 1300),
    endTime: Duration(milliseconds: 1600),
  ),
];

void main() {
  testWidgets('开关关闭时保持普通文本且不加载时间戳', (tester) async {
    var loadCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: dedupeOverrides([
          appSettingsProvider.overrideWith(_TestSettings.disabledSettings),
          wordTimestampsProvider('audio').overrideWith((ref) async {
            loadCount++;
            return _timestamps;
          }),
        ]),
        child: MaterialApp(
          home: Scaffold(
            body: WordHighlightBuilder(
              text: 'hello world',
              binding: _binding(const Stream<Duration>.empty()),
              builder: (context, index) => Text('word:$index'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('word:null'), findsOneWidget);
    expect(loadCount, 0);
  });

  testWidgets('开启后初始播放位置和后续 seek 都更新活动词', (tester) async {
    final positions = StreamController<Duration>.broadcast();
    final playbackStatuses =
        StreamController<WordHighlightPlaybackStatus>.broadcast();
    addTearDown(positions.close);
    addTearDown(playbackStatuses.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: dedupeOverrides([
          appSettingsProvider.overrideWith(_TestSettings.enabledSettings),
          wordTimestampsProvider(
            'audio',
          ).overrideWith((ref) async => _timestamps),
        ]),
        child: MaterialApp(
          home: Scaffold(
            body: WordHighlightBuilder(
              text: 'hello world',
              binding: _binding(
                positions.stream,
                playbackStatusStream: playbackStatuses.stream,
              ),
              builder: (context, index) => Text('word:$index'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('word:null'), findsOneWidget);

    playbackStatuses.add(WordHighlightPlaybackStatus.playing);
    await tester.pumpAndSettle();
    expect(find.text('word:1'), findsOneWidget);

    positions.add(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('word:0'), findsOneWidget);

    playbackStatuses.add(WordHighlightPlaybackStatus.paused);
    await tester.pumpAndSettle();
    expect(find.text('word:0'), findsOneWidget);

    // 相邻词首尾相接时，completed 也必须清掉边界上可能命中的下一词。
    positions.add(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('word:1'), findsOneWidget);

    playbackStatuses.add(WordHighlightPlaybackStatus.completed);
    await tester.pumpAndSettle();
    expect(find.text('word:null'), findsOneWidget);

    // 定位事件先于重新播放到达；它必须在高亮关闭期间也被位置流接收。
    positions.add(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(find.text('word:null'), findsOneWidget);

    playbackStatuses.add(WordHighlightPlaybackStatus.playing);
    await tester.pumpAndSettle();
    expect(find.text('word:0'), findsOneWidget);
  });

  testWidgets('区间起点之前的短暂位置回退不高亮前一意群末词', (tester) async {
    final positions = StreamController<Duration>.broadcast();
    final playbackStatuses =
        StreamController<WordHighlightPlaybackStatus>.broadcast();
    addTearDown(positions.close);
    addTearDown(playbackStatuses.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: dedupeOverrides([
          appSettingsProvider.overrideWith(_TestSettings.enabledSettings),
          wordTimestampsProvider(
            'audio',
          ).overrideWith((ref) async => _timestamps),
        ]),
        child: MaterialApp(
          home: Scaffold(
            body: WordHighlightBuilder(
              text: 'hello world',
              binding: _binding(
                positions.stream,
                playbackStatusStream: playbackStatuses.stream,
                activeRangeStartMs: 300,
              ),
              builder: (context, index) => Text('word:$index'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    playbackStatuses.add(WordHighlightPlaybackStatus.playing);
    positions.add(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('word:1'), findsOneWidget);

    // iOS seek 后出现的起点前事件不能再命中上一意群最后一个词。
    positions.add(const Duration(milliseconds: 290));
    await tester.pumpAndSettle();
    expect(find.text('word:null'), findsOneWidget);

    positions.add(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    expect(find.text('word:1'), findsOneWidget);
  });

  testWidgets('全文列表句首 seek 后短暂回退仍连续高亮首词', (tester) async {
    final positions = StreamController<Duration>.broadcast();
    final playbackStatuses =
        StreamController<WordHighlightPlaybackStatus>.broadcast();
    addTearDown(positions.close);
    addTearDown(playbackStatuses.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: dedupeOverrides([
          appSettingsProvider.overrideWith(_TestSettings.enabledSettings),
          wordTimestampsProvider(
            'audio',
          ).overrideWith((ref) async => _timestampsAtOneSecond),
        ]),
        child: MaterialApp(
          home: Scaffold(
            body: WordHighlightBuilder(
              text: 'hello world',
              binding: _binding(
                positions.stream,
                playbackStatusStream: playbackStatuses.stream,
                currentPosition: const Duration(milliseconds: 1000),
                sentenceStartMs: 1000,
                sentenceEndMs: 1600,
                positionRollbackFloorMs: 1000,
              ),
              builder: (context, index) => Text('word:$index'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    playbackStatuses.add(WordHighlightPlaybackStatus.playing);
    positions.add(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.text('word:0'), findsOneWidget);

    // iOS seek 后回退 47ms 时，保持同一个首词，不出现 0 → null → 0。
    positions.add(const Duration(milliseconds: 953));
    await tester.pumpAndSettle();
    expect(find.text('word:0'), findsOneWidget);

    // 超过回退容差的旧位置仍按真实时间轴解析，不会提前高亮句首。
    positions.add(const Duration(milliseconds: 749));
    await tester.pumpAndSettle();
    expect(find.text('word:null'), findsOneWidget);
  });
}

WordHighlightBinding _binding(
  Stream<Duration> positionStream, {
  Stream<WordHighlightPlaybackStatus> playbackStatusStream =
      const Stream<WordHighlightPlaybackStatus>.empty(),
  int? activeRangeStartMs,
  int? positionRollbackFloorMs,
  int sentenceStartMs = 0,
  int sentenceEndMs = 1000,
  Duration currentPosition = const Duration(milliseconds: 450),
}) => WordHighlightBinding(
  source: WordHighlightSource(
    audioItemId: 'audio',
    positionStream: positionStream,
    currentPosition: currentPosition,
    playbackStatus: WordHighlightPlaybackStatus.idle,
    playbackStatusStream: playbackStatusStream,
  ),
  sentenceStartMs: sentenceStartMs,
  sentenceEndMs: sentenceEndMs,
  activeRangeStartMs: activeRangeStartMs,
  positionRollbackFloorMs: positionRollbackFloorMs,
);

class _TestSettings extends AppSettings {
  _TestSettings(this.isEnabled);

  final bool isEnabled;

  @override
  AppSettingsState build() => AppSettingsState(wordHighlightEnabled: isEnabled);

  static _TestSettings disabledSettings() => _TestSettings(false);
  static _TestSettings enabledSettings() => _TestSettings(true);
}
