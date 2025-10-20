import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/audio_item.dart';
import '../services/storage_service.dart';

class AudioLibraryProvider extends ChangeNotifier {
  List<AudioItem> _audioItems = [];
  bool _isLoading = false;

  List<AudioItem> get audioItems => _audioItems;
  bool get isLoading => _isLoading;
  bool get isEmpty => _audioItems.isEmpty;

  Future<void> loadLibrary() async {
    _isLoading = true;
    notifyListeners();

    final allItems = await StorageService.loadAudioLibrary();
    
    // 验证文件是否存在，并迁移旧的绝对路径为相对路径
    final validItems = <AudioItem>[];
    bool hasInvalidItems = false;
    bool hasMigratedItems = false;
    
    for (final item in allItems) {
      AudioItem processedItem = item;
      
      // 迁移旧的绝对路径为相对路径
      if (item.audioPath.startsWith('/')) {
        // 这是旧的绝对路径，尝试迁移
        final migratedItem = await _migrateToRelativePath(item);
        if (migratedItem != null) {
          processedItem = migratedItem;
          hasMigratedItems = true;
          print('Migrated ${item.name} from absolute to relative path');
        } else {
          // 迁移失败，标记为无效
          hasInvalidItems = true;
          print('Failed to migrate ${item.name}, marking as invalid');
          continue;
        }
      }
      
      // 检查音频文件是否存在（使用相对路径动态获取完整路径）
      final fullAudioPath = await processedItem.getFullAudioPath();
      final audioFile = File(fullAudioPath);
      final audioExists = await audioFile.exists();
      
      // 只保留音频文件存在的条目（字幕文件是可选的，不影响有效性）
      if (audioExists) {
        validItems.add(processedItem);
      } else {
        hasInvalidItems = true;
        print('Removed invalid audio item: ${processedItem.name} (audio file not found at: $fullAudioPath)');
      }
    }
    
    _audioItems = validItems;
    
    // 如果有变更（无效条目被移除或路径被迁移），更新存储
    if (hasInvalidItems || hasMigratedItems) {
      await _saveLibrary();
      if (hasInvalidItems) {
        print('Cleaned up ${allItems.length - validItems.length} invalid audio items');
      }
      if (hasMigratedItems) {
        print('Migrated paths from absolute to relative format');
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 将旧的绝对路径迁移为相对路径
  Future<AudioItem?> _migrateToRelativePath(AudioItem item) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final docsPath = docs.path;
      
      // 检查音频路径是否在Documents目录下
      if (!item.audioPath.startsWith(docsPath)) {
        return null; // 不在Documents目录下，无法迁移
      }
      
      // 提取相对路径
      final relativeAudioPath = item.audioPath.substring(docsPath.length + 1);
      
      // 处理字幕路径
      String? relativeTranscriptPath;
      if (item.transcriptPath != null && item.transcriptPath!.startsWith(docsPath)) {
        relativeTranscriptPath = item.transcriptPath!.substring(docsPath.length + 1);
      } else if (item.transcriptPath != null && !item.transcriptPath!.startsWith('/')) {
        // 已经是相对路径
        relativeTranscriptPath = item.transcriptPath;
      }
      
      return item.copyWith(
        audioPath: relativeAudioPath,
        transcriptPath: relativeTranscriptPath,
      );
    } catch (e) {
      print('Error migrating path for ${item.name}: $e');
      return null;
    }
  }

  Future<void> addAudioItem(AudioItem item) async {
    _audioItems.add(item);
    await _saveLibrary();
    notifyListeners();
  }

  Future<void> removeAudioItem(String id) async {
    // 查找要删除的item
    AudioItem? item;
    try {
      item = _audioItems.firstWhere((item) => item.id == id);
    } catch (e) {
      print('Audio item not found: $id');
      return; // 如果找不到，直接返回
    }

    // 删除音频文件
    try {
      final audioPath = await item.getFullAudioPath();
      final audioFile = File(audioPath);
      if (await audioFile.exists()) {
        await audioFile.delete();
        print('Deleted audio file: $audioPath');
      }
    } catch (e) {
      print('Error deleting audio file: $e');
    }

    // 删除字幕文件（如果有）
    if (item.hasTranscript) {
      try {
        final transcriptPath = await item.getFullTranscriptPath();
        if (transcriptPath != null) {
          final transcriptFile = File(transcriptPath);
          if (await transcriptFile.exists()) {
            await transcriptFile.delete();
            print('Deleted transcript file: $transcriptPath');
          }
        }
      } catch (e) {
        print('Error deleting transcript file: $e');
      }
    }

    // 从列表中移除
    _audioItems.removeWhere((item) => item.id == id);
    await _saveLibrary();
    notifyListeners();
  }

  Future<void> updateAudioItem(AudioItem updatedItem) async {
    final index = _audioItems.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      _audioItems[index] = updatedItem;
      await _saveLibrary();
      notifyListeners();
    }
  }

  AudioItem? getItemById(String id) {
    try {
      return _audioItems.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveLibrary() async {
    await StorageService.saveAudioLibrary(_audioItems);
  }
}
