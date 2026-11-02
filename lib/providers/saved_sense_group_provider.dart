import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart' as db;
import '../database/providers.dart';
import 'favorite_vocabulary_lifecycle_provider.dart';

part 'saved_sense_group_provider.g.dart';

/// 收藏意群列表 Provider（流式）
///
/// 监听所有收藏意群的变化，按收藏时间倒序。
///
/// 手写而非 `@Riverpod` 生成：riverpod_generator 4.x 无法解析 drift 生成的
/// 数据类（[db.SavedSenseGroup]）作为 provider 类型参数，会报 InvalidTypeException。
/// analyzer 本身能正常解析该类型，运行时行为与生成版一致（非 autoDispose，常驻）。
class SavedSenseGroupList extends StreamNotifier<List<db.SavedSenseGroup>> {
  @override
  Stream<List<db.SavedSenseGroup>> build() {
    final dao = ref.watch(savedSenseGroupDaoProvider);
    return dao.watchAll();
  }

  /// 收藏意群
  ///
  /// [phraseText] 归一化后的文本（小写 + trim + 去句末标点）。
  /// [displayText] 原始文本（保留大小写）。
  /// [audioItemId] 必须指向收藏发生时存在的父音频。
  Future<void> saveSenseGroup({
    required String phraseText,
    required String displayText,
    required String audioItemId,
    int? sentenceIndex,
    String? sentenceText,
    int? sentenceStartMs,
    int? sentenceEndMs,
    int? groupStartMs,
    int? groupEndMs,
  }) async {
    await ref
        .read(favoriteVocabularyLifecycleProvider)
        .saveSenseGroup(
          phraseText: phraseText,
          displayText: displayText,
          audioItemId: audioItemId,
          sentenceIndex: sentenceIndex,
          sentenceText: sentenceText,
          sentenceStartMs: sentenceStartMs,
          sentenceEndMs: sentenceEndMs,
          groupStartMs: groupStartMs,
          groupEndMs: groupEndMs,
        );
  }

  /// 取消收藏意群
  Future<void> removeSenseGroup(String phraseText) => ref
      .read(favoriteVocabularyLifecycleProvider)
      .removeSenseGroup(phraseText);
}

/// 收藏意群列表 Provider 实例（常驻，见 [SavedSenseGroupList]）
final savedSenseGroupListProvider =
    StreamNotifierProvider<SavedSenseGroupList, List<db.SavedSenseGroup>>(
      SavedSenseGroupList.new,
    );

/// 监听已收藏意群的归一化文本集合（用于 badge 染色与正文收藏标记）
///
/// 收藏标记是辅助功能：数据库未初始化（如宿主 widget 测试环境）时
/// 降级为空集，不崩宿主页（CLAUDE.md §7.18 默认值降级规则）。
/// 降级必须留日志——keepAlive 会把空集缓存整个会话，静默降级会把
/// 真实 DB 故障伪装成「用户没有收藏意群」。
@Riverpod(keepAlive: true)
class SavedSenseGroupTexts extends _$SavedSenseGroupTexts {
  @override
  Stream<Set<String>> build() {
    try {
      final dao = ref.watch(savedSenseGroupDaoProvider);
      return dao.watchSavedPhraseTexts();
    } catch (e) {
      debugPrint('[SavedSenseGroupTexts] 数据库不可用，收藏意群集合降级为空集: $e');
      return Stream.value(const <String>{});
    }
  }
}

/// 监听单个意群是否已收藏
@riverpod
Stream<bool> isSenseGroupSaved(Ref ref, String phraseText) {
  final dao = ref.watch(savedSenseGroupDaoProvider);
  return dao.watchIsSenseGroupSaved(phraseText);
}
