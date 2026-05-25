import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/app_database.dart' as db;
import '../database/providers.dart';
import '../models/tag.dart';

part 'tag_provider.g.dart';

/// 标签状态
class TagState {
  /// 所有活跃标签
  final List<Tag> tags;

  /// 是否正在加载
  final bool isLoading;

  /// 缓存每个标签的音频 ID 列表（tagId → audioIds）
  final Map<String, List<String>> audioIdsMap;

  const TagState({
    this.tags = const [],
    this.isLoading = false,
    this.audioIdsMap = const {},
  });

  bool get isEmpty => tags.isEmpty;

  /// 获取标签关联的音频 ID 列表
  List<String> getAudioIds(String tagId) {
    return audioIdsMap[tagId] ?? [];
  }

  /// 反向索引：audioId → 所属标签 ID 列表
  Map<String, List<String>> get audioToTagsMap {
    final result = <String, List<String>>{};
    for (final entry in audioIdsMap.entries) {
      for (final audioId in entry.value) {
        (result[audioId] ??= []).add(entry.key);
      }
    }
    return result;
  }

  TagState copyWith({
    List<Tag>? tags,
    bool? isLoading,
    Map<String, List<String>>? audioIdsMap,
  }) {
    return TagState(
      tags: tags ?? this.tags,
      isLoading: isLoading ?? this.isLoading,
      audioIdsMap: audioIdsMap ?? this.audioIdsMap,
    );
  }
}

@Riverpod(keepAlive: true)
class TagList extends _$TagList {
  @override
  TagState build() {
    return const TagState();
  }

  /// 从数据库加载所有标签及其关联
  Future<void> loadTags() async {
    state = state.copyWith(isLoading: true);

    final dao = ref.read(tagDaoProvider);
    final dbTags = await dao.getAllActive();

    final tags = dbTags
        .map(
          (row) => Tag(
            id: row.id,
            name: row.name,
            colorValue: row.color,
            createdDate: row.createdDate,
          ),
        )
        .toList();

    // 加载每个标签的音频 ID 列表
    final audioIdsMap = <String, List<String>>{};
    for (final t in tags) {
      audioIdsMap[t.id] = await dao.getAudioIds(t.id);
    }

    state = state.copyWith(
      tags: tags,
      isLoading: false,
      audioIdsMap: audioIdsMap,
    );
  }

  /// 创建标签
  Future<void> createTag(String name, int colorValue) async {
    final now = DateTime.now();
    final tag = Tag(
      id: now.millisecondsSinceEpoch.toString(),
      name: name,
      colorValue: colorValue,
      createdDate: now,
    );
    state = state.copyWith(tags: [...state.tags, tag]);
    await _upsertTag(tag);
  }

  /// 删除标签（硬删除，CASCADE 自动清理 junction）
  Future<void> deleteTag(String id) async {
    final newMap = Map<String, List<String>>.from(state.audioIdsMap)
      ..remove(id);
    state = state.copyWith(
      tags: state.tags.where((t) => t.id != id).toList(),
      audioIdsMap: newMap,
    );
    final dao = ref.read(tagDaoProvider);
    await dao.hardDelete(id);
  }

  /// 重命名标签
  Future<void> renameTag(String id, String newName) async {
    final tags = [...state.tags];
    final index = tags.indexWhere((t) => t.id == id);
    if (index != -1) {
      tags[index] = tags[index].copyWith(name: newName);
      state = state.copyWith(tags: tags);
      await _upsertTag(tags[index]);
    }
  }

  /// 更新标签颜色
  Future<void> updateTagColor(String id, int colorValue) async {
    final tags = [...state.tags];
    final index = tags.indexWhere((t) => t.id == id);
    if (index != -1) {
      tags[index] = tags[index].copyWith(colorValue: colorValue);
      state = state.copyWith(tags: tags);
      await _upsertTag(tags[index]);
    }
  }

  /// 添加音频到标签
  Future<void> addAudioToTag(String tagId, String audioId) async {
    final dao = ref.read(tagDaoProvider);
    await dao.addAudio(tagId, audioId);

    // 更新缓存
    final newMap = Map<String, List<String>>.from(state.audioIdsMap);
    final ids = List<String>.from(newMap[tagId] ?? []);
    if (!ids.contains(audioId)) {
      ids.add(audioId);
      newMap[tagId] = ids;
      state = state.copyWith(audioIdsMap: newMap);
    }
  }

  /// 从标签中移除音频
  Future<void> removeAudioFromTag(String tagId, String audioId) async {
    final dao = ref.read(tagDaoProvider);
    await dao.removeAudio(tagId, audioId);

    // 更新缓存
    final newMap = Map<String, List<String>>.from(state.audioIdsMap);
    final ids = List<String>.from(newMap[tagId] ?? []);
    ids.remove(audioId);
    newMap[tagId] = ids;
    state = state.copyWith(audioIdsMap: newMap);
  }

  /// 从所有标签中移除指定音频的引用（当音频从音频库删除时调用）
  /// CASCADE 已自动清理 junction 表，此方法仅更新内存缓存
  Future<void> removeAudioFromAllTags(String audioId) async {
    final newMap = Map<String, List<String>>.from(state.audioIdsMap);
    for (final key in newMap.keys) {
      newMap[key] = List<String>.from(newMap[key]!)..remove(audioId);
    }
    state = state.copyWith(audioIdsMap: newMap);
  }

  /// 批量更新音频的标签归属（diff 模式）
  ///
  /// 对比当前归属和目标归属，只执行增删操作。
  Future<void> updateAudioTagMembership(
    String audioId,
    Set<String> targetTagIds,
  ) async {
    final currentTags = state.audioToTagsMap[audioId]?.toSet() ?? <String>{};
    final toAdd = targetTagIds.difference(currentTags);
    final toRemove = currentTags.difference(targetTagIds);

    for (final tagId in toAdd) {
      await addAudioToTag(tagId, audioId);
    }
    for (final tagId in toRemove) {
      await removeAudioFromTag(tagId, audioId);
    }
  }

  /// 根据 ID 获取标签
  Tag? getTagById(String id) {
    try {
      return state.tags.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 将 Tag 模型写入 Drift 数据库
  Future<void> _upsertTag(Tag tag) async {
    final dao = ref.read(tagDaoProvider);
    await dao.upsert(
      db.TagsCompanion(
        id: Value(tag.id),
        name: Value(tag.name),
        color: Value(tag.colorValue),
        createdDate: Value(tag.createdDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
