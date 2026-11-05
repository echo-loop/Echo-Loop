import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/audio_event_params.dart';
import '../analytics/models/event_names.dart';
import '../features/usage/usage_event.dart';
import '../features/usage/usage_providers.dart';
import '../database/app_database.dart' as db;
import '../database/providers.dart';
import '../models/dict_entry.dart';
import 'dictionary/dictionary_registry.dart';
import '../utils/saved_text_index.dart';
import 'notification_permission_provider.dart';
import 'favorite_vocabulary_lifecycle_provider.dart';
import 'saved_sense_group_provider.dart';

part 'saved_word_provider.g.dart';

/// 收藏单词列表 Provider（流式）
///
/// 监听所有收藏单词的变化，按收藏时间倒序。
///
/// 手写而非 `@Riverpod` 生成：riverpod_generator 4.x 无法解析 drift 生成的
/// 数据类（[db.SavedWord]）作为 provider 类型参数，会报 InvalidTypeException。
/// analyzer 本身能正常解析该类型，运行时行为与生成版一致（非 autoDispose，常驻）。
class SavedWordList extends StreamNotifier<List<db.SavedWord>> {
  @override
  Stream<List<db.SavedWord>> build() {
    final dao = ref.watch(savedWordDaoProvider);
    return dao.watchAll();
  }

  /// 收藏单词
  ///
  /// [word] 为归一化后的**表面词形**（用户实际选中/查询的词），非词干/原形——
  /// 正文收藏下划线按表面词形匹配（见 [SavedTextIndex]），保存原形会导致
  /// 正文无法标记。在线词典也仅按该词形精确匹配，避免释义和发音错位。
  /// 可选提供来源音频和句子信息。
  Future<void> saveWord({
    required String word,
    String? audioItemId,
    int? sentenceIndex,
    String? sentenceText,
    int? sentenceStartMs,
    int? sentenceEndMs,
  }) async {
    await ref
        .read(favoriteVocabularyLifecycleProvider)
        .saveWord(
          word: word,
          audioItemId: audioItemId,
          sentenceIndex: sentenceIndex,
          sentenceText: sentenceText,
          sentenceStartMs: sentenceStartMs,
          sentenceEndMs: sentenceEndMs,
        );

    // 埋点：收藏单词
    ref
        .read(usageTrackerProvider)
        .record(
          UsageEvent.wordSaved,
          analyticsParams: {
            EventParams.word: word,
            ...ref.audioEventParams(audioItemId),
          },
        );

    // 价值锚点：首次收藏单词 → 尝试触发通知权限 pre-prompt
    unawaited(
      ref.read(notificationPermissionServiceProvider).maybeTriggerPrompt(),
    );
  }

  /// 取消收藏单词
  Future<void> removeWord(String word) =>
      ref.read(favoriteVocabularyLifecycleProvider).removeWord(word);
}

/// 收藏单词列表 Provider 实例（常驻，见 [SavedWordList]）
final savedWordListProvider =
    StreamNotifierProvider<SavedWordList, List<db.SavedWord>>(
      SavedWordList.new,
    );

/// 监听已收藏单词的 key 集合（用于正文收藏词下划线标记）
///
/// 收藏标记是辅助功能：数据库未初始化（如宿主 widget 测试环境）时
/// 降级为空集，不崩宿主页（CLAUDE.md §7.18 默认值降级规则）。
/// 降级必须留日志——keepAlive 会把空集缓存整个会话，静默降级会把
/// 真实 DB 故障伪装成「用户没有收藏词」。
@Riverpod(keepAlive: true)
class SavedWordTexts extends _$SavedWordTexts {
  @override
  Stream<Set<String>> build() {
    try {
      final dao = ref.watch(savedWordDaoProvider);
      return dao.watchSavedWordTexts();
    } catch (e) {
      debugPrint('[SavedWordTexts] 数据库不可用，收藏词集合降级为空集: $e');
      return Stream.value(const <String>{});
    }
  }
}

/// 收藏文本匹配索引（正文收藏标记的唯一消费入口）
///
/// 合并两张收藏表的 key 并统一归一化分桶（见 [SavedTextIndex]）。
/// keepAlive + 派生自两个流 provider：索引只在收藏集合变化时重建，
/// 被所有可见句子共享（避免每个句子组件各自重复归一化全部 key）。
@Riverpod(keepAlive: true)
SavedTextIndex savedTextIndex(Ref ref) {
  final words =
      ref.watch(savedWordTextsProvider).value ?? const <String>{};
  final phrases =
      ref.watch(savedSenseGroupTextsProvider).value ?? const <String>{};
  if (words.isEmpty && phrases.isEmpty) return const SavedTextIndex.empty();
  return SavedTextIndex.build(savedWords: words, savedPhrases: phrases);
}

/// 收藏单词列表的批量字典条目
///
/// 监听 [savedWordListProvider]，当单词列表变化时批量查询所有字典释义。
/// 避免每个列表项独立异步查询导致释义延迟闪烁。
@riverpod
Future<Map<String, DictEntry>> savedWordDictEntries(Ref ref) async {
  final wordsAsync = await ref.watch(savedWordListProvider.future);
  if (wordsAsync.isEmpty) return {};
  final wordStrings = wordsAsync.map((w) => w.word).toList();
  return ref.watch(dictionaryServiceProvider).lookupAll(wordStrings);
}
