// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_sentences_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 某音频的完整句子列表（index 0..N-1 连续，`list[i-1]/list[i+1]` 即前后句）。
///
/// 无字幕或解析失败返回空列表。直接走 `getTranscriptSrt + SubtitleParser`，
/// 不经 `AudioEngine.loadTranscript`，与播放态解耦。

@ProviderFor(audioSentences)
final audioSentencesProvider = AudioSentencesFamily._();

/// 某音频的完整句子列表（index 0..N-1 连续，`list[i-1]/list[i+1]` 即前后句）。
///
/// 无字幕或解析失败返回空列表。直接走 `getTranscriptSrt + SubtitleParser`，
/// 不经 `AudioEngine.loadTranscript`，与播放态解耦。

final class AudioSentencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Sentence>>,
          List<Sentence>,
          FutureOr<List<Sentence>>
        >
    with $FutureModifier<List<Sentence>>, $FutureProvider<List<Sentence>> {
  /// 某音频的完整句子列表（index 0..N-1 连续，`list[i-1]/list[i+1]` 即前后句）。
  ///
  /// 无字幕或解析失败返回空列表。直接走 `getTranscriptSrt + SubtitleParser`，
  /// 不经 `AudioEngine.loadTranscript`，与播放态解耦。
  AudioSentencesProvider._({
    required AudioSentencesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'audioSentencesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$audioSentencesHash();

  @override
  String toString() {
    return r'audioSentencesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Sentence>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Sentence>> create(Ref ref) {
    final argument = this.argument as String;
    return audioSentences(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AudioSentencesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$audioSentencesHash() => r'8b1e4ea41b12398926a1840c16ecfbffd1a26c98';

/// 某音频的完整句子列表（index 0..N-1 连续，`list[i-1]/list[i+1]` 即前后句）。
///
/// 无字幕或解析失败返回空列表。直接走 `getTranscriptSrt + SubtitleParser`，
/// 不经 `AudioEngine.loadTranscript`，与播放态解耦。

final class AudioSentencesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Sentence>>, String> {
  AudioSentencesFamily._()
    : super(
        retry: null,
        name: r'audioSentencesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 某音频的完整句子列表（index 0..N-1 连续，`list[i-1]/list[i+1]` 即前后句）。
  ///
  /// 无字幕或解析失败返回空列表。直接走 `getTranscriptSrt + SubtitleParser`，
  /// 不经 `AudioEngine.loadTranscript`，与播放态解耦。

  AudioSentencesProvider call(String audioItemId) =>
      AudioSentencesProvider._(argument: audioItemId, from: this);

  @override
  String toString() => r'audioSentencesProvider';
}
