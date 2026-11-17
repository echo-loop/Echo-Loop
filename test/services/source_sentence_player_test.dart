import 'dart:io';

import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/services/pronunciation/local_audio_clip_player.dart';
import 'package:echo_loop/services/pronunciation/source_sentence_player.dart';
import 'package:echo_loop/utils/app_data_dir.dart' as app_data_dir;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shared/fake_daos.dart';

class _AudioItemDaoWithReadyAudio extends FakeAudioItemDao {
  @override
  Future<db.AudioItem?> getById(String id) async => db.AudioItem(
    id: id,
    name: 'Test audio',
    audioPath: 'audio/test.mp3',
    addedDate: DateTime(2026),
    totalDuration: 10,
    sentenceCount: 1,
    wordCount: 3,
    isPinned: false,
    updatedAt: DateTime(2026),
    syncStatus: 0,
  );
}

class _FailingRangePlayer extends LocalAudioClipPlayer {
  _FailingRangePlayer(this.onPlay)
    : super(backend: UnavailableAudioClipPlayerBackend());

  final void Function() onPlay;

  @override
  Future<AudioPlaybackResult> playRangeFile(
    String filePath, {
    required Duration start,
    required Duration end,
    String? playbackKey,
  }) async {
    onPlay();
    return AudioPlaybackResult.failed;
  }
}

void main() {
  setUp(() {
    app_data_dir.appDataDirectoryOverride = Directory.systemTemp;
  });

  tearDown(() {
    app_data_dir.appDataDirectoryOverride = null;
  });

  test('returns completed when the TTS fallback completes', () async {
    var speakCalls = 0;
    final player = SourceSentencePlayer(
      audioItemDao: FakeAudioItemDao(),
      audioClipPlayer: LocalAudioClipPlayer(),
      speak: (text, key) async {
        speakCalls++;
        expect(text, 'A fallback sentence.');
        expect(key, 'source-key');
        return AudioPlaybackResult.completed;
      },
    );

    final result = await player.play(
      audioItemId: null,
      sentenceText: ' A fallback sentence. ',
      sentenceStartMs: null,
      sentenceEndMs: null,
      playbackKey: 'source-key',
    );

    expect(result, AudioPlaybackResult.completed);
    expect(speakCalls, 1);
  });

  test(
    'propagates TTS cancellation without treating it as completion',
    () async {
      final player = SourceSentencePlayer(
        audioItemDao: FakeAudioItemDao(),
        audioClipPlayer: LocalAudioClipPlayer(),
        speak: (text, key) async => AudioPlaybackResult.cancelled,
      );

      final result = await player.play(
        audioItemId: null,
        sentenceText: 'A cancelled sentence.',
        sentenceStartMs: null,
        sentenceEndMs: null,
        playbackKey: 'source-key',
      );

      expect(result, AudioPlaybackResult.cancelled);
    },
  );

  test('returns failed when no source or fallback is available', () async {
    final player = SourceSentencePlayer(
      audioItemDao: FakeAudioItemDao(),
      audioClipPlayer: LocalAudioClipPlayer(),
      speak: (text, key) async => fail('TTS must not be called'),
    );

    final result = await player.play(
      audioItemId: null,
      sentenceText: '   ',
      sentenceStartMs: null,
      sentenceEndMs: null,
      playbackKey: 'source-key',
    );

    expect(result, AudioPlaybackResult.failed);
  });

  test('does not start TTS after cancellation during local fallback', () async {
    var isCurrent = true;
    var speakCalls = 0;
    final player = SourceSentencePlayer(
      audioItemDao: _AudioItemDaoWithReadyAudio(),
      audioClipPlayer: _FailingRangePlayer(() => isCurrent = false),
      isPlaybackCurrent: () => isCurrent,
      speak: (text, key) async {
        speakCalls++;
        return AudioPlaybackResult.completed;
      },
    );

    final result = await player.play(
      audioItemId: 'audio-1',
      sentenceText: 'A cancelled sentence.',
      sentenceStartMs: 1000,
      sentenceEndMs: 2000,
      playbackKey: 'source-key',
    );

    expect(result, AudioPlaybackResult.cancelled);
    expect(speakCalls, 0);
  });
}
