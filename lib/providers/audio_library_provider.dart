import 'dart:io';
import 'package:flutter/foundation.dart';
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
    
    // 验证文件是否存在，过滤掉无效的条目
    final validItems = <AudioItem>[];
    bool hasInvalidItems = false;
    
    for (final item in allItems) {
      // 检查音频文件是否存在
      final audioFile = File(item.audioPath);
      final audioExists = await audioFile.exists();
      
      // 只保留音频文件存在的条目（字幕文件是可选的，不影响有效性）
      if (audioExists) {
        validItems.add(item);
      } else {
        hasInvalidItems = true;
        print('Removed invalid audio item: ${item.name} (audio file not found)');
      }
    }
    
    _audioItems = validItems;
    
    // 如果有无效条目被移除，更新存储
    if (hasInvalidItems) {
      await _saveLibrary();
      print('Cleaned up ${allItems.length - validItems.length} invalid audio items');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addAudioItem(AudioItem item) async {
    _audioItems.add(item);
    await _saveLibrary();
    notifyListeners();
  }

  Future<void> removeAudioItem(String id) async {
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
