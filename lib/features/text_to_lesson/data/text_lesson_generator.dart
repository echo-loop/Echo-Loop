/// Text → Lesson 编排层。
///
/// 把纯文本切句后逐段调用统一 TTS 协调器，将每段 PCM WAV 流式合并为一个
/// 16-bit PCM WAV，并生成 SRT 后写入现有 AudioItem/字幕数据库模型。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../database/daos/audio_item_dao.dart';
import '../../../models/audio_item.dart';
import '../../../models/sentence.dart';
import '../../../services/app_logger.dart';
import '../../../services/tts/kokoro_model_catalog.dart';
import '../../../services/tts/text_segmenter.dart';
import '../../../services/tts/tts_coordinator.dart';
import '../../../services/tts/tts_engine.dart';
import '../../../services/tts/wav_audio_assembler.dart';
import '../../../utils/app_data_dir.dart';
import '../../../utils/word_counter.dart';

/// 可取消 token；生成流程在每段边界检查。
class TextLessonCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// 生成进度。
class TextLessonProgress {
  const TextLessonProgress({
    required this.completedSegments,
    required this.totalSegments,
    required this.message,
  });

  final int completedSegments;
  final int totalSegments;
  final String message;

  double get fraction => totalSegments == 0
      ? 0
      : (completedSegments / totalSegments).clamp(0.0, 1.0);
}

/// 生成结果。
class TextLessonResult {
  const TextLessonResult({required this.audioItem, required this.audioFile});

  final AudioItem audioItem;
  final AssembledWav audioFile;
}

class TextLessonCancelledException implements Exception {
  const TextLessonCancelledException();

  @override
  String toString() => 'Text lesson generation cancelled.';
}

class TextLessonGenerationException implements Exception {
  const TextLessonGenerationException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// 可注入的 TTS 文件合成端口，避免编排层直接依赖 sherpa_onnx。
abstract interface class TextLessonSynthesizer {
  Future<String?> renderToCache(
    String text, {
    required TtsEngineKind kind,
    required TtsSpeechConfig config,
  });
}

class CoordinatorTextLessonSynthesizer implements TextLessonSynthesizer {
  const CoordinatorTextLessonSynthesizer(this._coordinator);

  final TtsCoordinator _coordinator;

  @override
  Future<String?> renderToCache(
    String text, {
    required TtsEngineKind kind,
    required TtsSpeechConfig config,
  }) {
    return _coordinator.renderToCache(text, kind: kind, config: config);
  }
}

typedef AddGeneratedAudioItem = Future<void> Function(AudioItem item);

class TextLessonGenerator {
  TextLessonGenerator({
    required TextLessonSynthesizer synthesizer,
    required AudioItemDao audioItemDao,
    required AddGeneratedAudioItem addAudioItem,
    Future<Directory> Function()? dataDirectoryResolver,
    TextSegmenter? segmenter,
    Uuid? uuid,
  }) : _synthesizer = synthesizer,
       _audioItemDao = audioItemDao,
       _addAudioItem = addAudioItem,
       _dataDirectoryResolver = dataDirectoryResolver ?? getAppDataDirectory,
       _segmenter = segmenter ?? const TextSegmenter(),
       _uuid = uuid ?? const Uuid();

  final TextLessonSynthesizer _synthesizer;
  final AudioItemDao _audioItemDao;
  final AddGeneratedAudioItem _addAudioItem;
  final Future<Directory> Function() _dataDirectoryResolver;
  final TextSegmenter _segmenter;
  final Uuid _uuid;

  Future<TextLessonResult> generate({
    required String title,
    required String text,
    required String voiceId,
    required double speed,
    required KokoroModelVariant modelVariant,
    TextLessonCancellationToken? cancellationToken,
    void Function(TextLessonProgress progress)? onProgress,
  }) async {
    final segments = _segmenter.split(text);
    if (segments.isEmpty) {
      throw const TextLessonGenerationException('Text is empty.');
    }
    final id = _uuid.v4();
    final dataDir = await _dataDirectoryResolver();
    final relativeAudioPath = p.join('audios', 'generated', '$id.wav');
    final absoluteAudioPath = p.join(dataDir.path, relativeAudioPath);
    final assembler = WavAudioAssembler(outputPath: absoluteAudioPath);
    final startedAt = DateTime.now();

    try {
      await assembler.start();
      for (var index = 0; index < segments.length; index++) {
        if (cancellationToken?.isCancelled ?? false) {
          throw const TextLessonCancelledException();
        }
        final segment = segments[index];
        onProgress?.call(
          TextLessonProgress(
            completedSegments: index,
            totalSegments: segments.length,
            message: 'Synthesizing ${index + 1}/${segments.length}',
          ),
        );
        final synthesized = await _synthesizer.renderToCache(
          segment,
          kind: TtsEngineKind.kokoro,
          config: TtsSpeechConfig(
            languageTag: RegExp(r'[\u3400-\u9fff]').hasMatch(segment)
                ? 'zh-CN'
                : 'en-US',
            voiceName: voiceId,
            speed: speed.clamp(0.5, 2.0).toDouble(),
            modelTag: kokoroSpecOf(modelVariant).id,
          ),
        );
        if (synthesized == null || synthesized.isEmpty) {
          throw TextLessonGenerationException(
            'Failed to synthesize segment ${index + 1}.',
          );
        }
        await assembler.addWav(synthesized, segment);
        onProgress?.call(
          TextLessonProgress(
            completedSegments: index + 1,
            totalSegments: segments.length,
            message: 'Synthesized ${index + 1}/${segments.length}',
          ),
        );
      }

      if (cancellationToken?.isCancelled ?? false) {
        throw const TextLessonCancelledException();
      }

      onProgress?.call(
        TextLessonProgress(
          completedSegments: segments.length,
          totalSegments: segments.length,
          message: 'Finalizing audio',
        ),
      );
      final assembled = await assembler.finish();
      final srt = _buildSrt(assembled.sentences);
      final audioItem = AudioItem(
        id: id,
        name: title.trim().isEmpty ? 'Text Lesson' : title.trim(),
        audioPath: relativeAudioPath,
        transcriptPath: null,
        addedDate: startedAt,
        totalDuration: assembled.duration.inSeconds.clamp(1, 1 << 31).toInt(),
        sentenceCount: assembled.sentences.length,
        wordCount: countWords(text),
        transcriptSource: TranscriptSource.local,
      );
      await _addAudioItem(audioItem);
      await _audioItemDao.saveTranscriptContent(
        id,
        srt: srt,
        wordTimestampsJson: null,
      );
      AppLogger.log(
        'TextLesson',
        'generated id=$id segments=${segments.length} '
            'durationMs=${assembled.duration.inMilliseconds} '
            'bytes=${assembled.byteLength}',
      );
      return TextLessonResult(audioItem: audioItem, audioFile: assembled);
    } on TextLessonCancelledException {
      await assembler.abort();
      rethrow;
    } on TextLessonGenerationException {
      await assembler.abort();
      rethrow;
    } catch (error, stackTrace) {
      await assembler.abort();
      AppLogger.log('TextLesson', 'generation failed: $error\n$stackTrace');
      throw TextLessonGenerationException(
        'Failed to generate lesson audio.',
        error,
      );
    }
  }

  String _buildSrt(List<AssembledSentence> sentences) {
    final buffer = StringBuffer();
    for (var index = 0; index < sentences.length; index++) {
      final sentence = sentences[index];
      buffer.writeln(index + 1);
      buffer.writeln(
        '${_formatSrtTime(sentence.start)} --> ${_formatSrtTime(sentence.end)}',
      );
      buffer.writeln(sentence.text.trim());
      if (index < sentences.length - 1) buffer.writeln();
    }
    return buffer.toString();
  }

  String _formatSrtTime(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final millis = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds,$millis';
  }
}

/// 供显示/测试使用的句子索引映射，保持与 SRT 顺序一致。
List<Sentence> sentencesFromAssembled(List<AssembledSentence> sentences) {
  return [
    for (final sentence in sentences)
      Sentence(
        index: sentence.index,
        text: sentence.text,
        startTime: sentence.start,
        endTime: sentence.end,
      ),
  ];
}
