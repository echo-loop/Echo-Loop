/// 字幕列表内单句 AI 译文。
///
/// 列表逐句展示译文时，每个可见句子订阅一条译文流。缓存键与句子讲解页一致
/// （含前后句上下文），已翻译过的句子直接命中 L1/L2 缓存；同句进行中的请求
/// 由 [SentenceAiNotifier] 复用同一条后端流，与预热不会重复计费。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/providers/auth_providers.dart';
import 'audio_sentences_provider.dart';
import 'sentence_ai_prewarm.dart';
import 'sentence_ai_provider.dart';
import 'settings_provider.dart';

/// 单句译文流：逐帧输出累积译文。
///
/// 关闭自动重试：登录失效、额度用尽等错误重试也不会成功，反而重复撞后端；
/// 失败交给界面展示并由用户点击重试。
final sentenceTranslationProvider = StreamProvider.autoDispose
    .family<String, SentenceAiPrewarmTarget>((ref, target) async* {
      final ai = ref.watch(sentenceAiNotifierProvider);
      final accessToken = ref.watch(
        supabaseSessionProvider.select((session) => session.value?.accessToken),
      );
      final targetLanguage = ref.watch(
        appSettingsProvider.select((settings) => settings.nativeLanguage),
      );
      String? previous;
      String? next;
      final audioItemId = target.audioItemId;
      final sentenceIndex = target.sentenceIndex;
      if (audioItemId != null &&
          audioItemId.isNotEmpty &&
          sentenceIndex != null) {
        final sentences = await ref.watch(
          audioSentencesProvider(audioItemId).future,
        );
        String? at(int i) =>
            (i >= 0 && i < sentences.length) ? sentences[i].text : null;
        previous = at(sentenceIndex - 1);
        next = at(sentenceIndex + 1);
      }
      await for (final translation in ai.getTranslationStream(
        target.text,
        previous: previous,
        next: next,
        targetLanguage: targetLanguage,
        accessToken: accessToken,
        respectLocalQuotaReset: true,
      )) {
        yield translation.translation;
      }
    }, retry: (_, _) => null);
