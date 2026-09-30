/// Text → Lesson Riverpod 状态与依赖装配。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/providers.dart';
import '../../../providers/audio_library_provider.dart';
import '../../../providers/tts/tts_controller_provider.dart';
import '../../../providers/tts/tts_settings_provider.dart';
import '../../../services/tts/tts_engine.dart';
import '../../../widgets/tts/tts_model_download_prompt_dialog.dart';
import '../data/text_lesson_generator.dart';

enum TextLessonStatus { idle, generating, completed, failed, cancelled }

class TextLessonState {
  const TextLessonState({
    this.status = TextLessonStatus.idle,
    this.progress,
    this.result,
    this.error,
  });

  final TextLessonStatus status;
  final TextLessonProgress? progress;
  final TextLessonResult? result;
  final String? error;

  bool get isGenerating => status == TextLessonStatus.generating;
}

final textLessonGeneratorProvider = Provider<TextLessonGenerator>((ref) {
  final coordinator = ref.read(ttsControllerProvider.notifier).coordinator;
  return TextLessonGenerator(
    synthesizer: CoordinatorTextLessonSynthesizer(coordinator),
    audioItemDao: ref.read(audioItemDaoProvider),
    addAudioItem: ref.read(audioLibraryProvider.notifier).addAudioItem,
  );
});

final textLessonControllerProvider =
    NotifierProvider<TextLessonController, TextLessonState>(
      TextLessonController.new,
    );

class TextLessonController extends Notifier<TextLessonState> {
  int _generationToken = 0;
  TextLessonCancellationToken? _cancellationToken;

  @override
  TextLessonState build() => const TextLessonState();

  /// 生成课时；模型未下载时先走统一下载门控。
  Future<TextLessonResult?> generate({
    required String title,
    required String text,
    required String voiceId,
    required double speed,
  }) async {
    final token = ++_generationToken;
    final settings = ref.read(ttsSettingsProvider);
    final modelReady = await isTtsModelReadyForConfig(
      ref,
      engine: TtsEngineKind.kokoro,
      kokoroVariant: settings.kokoroVariant,
    );
    if (!modelReady) {
      state = const TextLessonState(
        status: TextLessonStatus.failed,
        error: 'offline_model_required',
      );
      return null;
    }
    if (token != _generationToken) return null;

    final cancellationToken = TextLessonCancellationToken();
    _cancellationToken = cancellationToken;
    state = const TextLessonState(status: TextLessonStatus.generating);
    try {
      final result = await ref
          .read(textLessonGeneratorProvider)
          .generate(
            title: title,
            text: text,
            voiceId: voiceId,
            speed: speed,
            modelVariant: settings.kokoroVariant,
            cancellationToken: cancellationToken,
            onProgress: (progress) {
              if (token != _generationToken) return;
              state = TextLessonState(
                status: TextLessonStatus.generating,
                progress: progress,
              );
            },
          );
      if (token != _generationToken) return null;
      state = TextLessonState(
        status: TextLessonStatus.completed,
        result: result,
      );
      return result;
    } on TextLessonCancelledException {
      if (token == _generationToken) {
        state = const TextLessonState(status: TextLessonStatus.cancelled);
      }
      return null;
    } on TextLessonGenerationException catch (error) {
      if (token == _generationToken) {
        state = TextLessonState(
          status: TextLessonStatus.failed,
          error: error.message,
        );
      }
      return null;
    } finally {
      if (token == _generationToken) _cancellationToken = null;
    }
  }

  Future<void> cancel() async {
    _generationToken++;
    _cancellationToken?.cancel();
    _cancellationToken = null;
    state = const TextLessonState(status: TextLessonStatus.cancelled);
  }

  void reset() {
    _generationToken++;
    _cancellationToken?.cancel();
    _cancellationToken = null;
    state = const TextLessonState();
  }
}
