import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../database/providers.dart';

part 'saved_sense_group_provider.g.dart';

/// 收藏意群列表 Provider（流式）
///
/// 监听所有收藏意群的变化，按收藏时间倒序。
@Riverpod(keepAlive: true)
class SavedSenseGroupList extends _$SavedSenseGroupList {
  @override
  Stream<List<SavedSenseGroup>> build() {
    final dao = ref.watch(savedSenseGroupDaoProvider);
    return dao.watchAll();
  }

  /// 收藏意群
  ///
  /// [phraseText] 归一化后的文本（小写 + trim + 去句末标点）。
  /// [displayText] 原始文本（保留大小写）。
  Future<void> saveSenseGroup({
    required String phraseText,
    required String displayText,
    String? audioItemId,
    int? sentenceIndex,
    String? sentenceText,
    int? sentenceStartMs,
    int? sentenceEndMs,
    int? groupStartMs,
    int? groupEndMs,
  }) async {
    final dao = ref.read(savedSenseGroupDaoProvider);
    await dao.saveSenseGroup(
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
  Future<void> removeSenseGroup(String phraseText) async {
    final dao = ref.read(savedSenseGroupDaoProvider);
    await dao.removeSenseGroup(phraseText);
  }
}

/// 监听已收藏意群的归一化文本集合（用于 badge 染色）
@Riverpod(keepAlive: true)
class SavedSenseGroupTexts extends _$SavedSenseGroupTexts {
  @override
  Stream<Set<String>> build() {
    final dao = ref.watch(savedSenseGroupDaoProvider);
    return dao.watchSavedPhraseTexts();
  }
}

/// 监听单个意群是否已收藏
@riverpod
Stream<bool> isSenseGroupSaved(ref, String phraseText) {
  final dao = ref.watch(savedSenseGroupDaoProvider);
  return dao.watchIsSenseGroupSaved(phraseText);
}
