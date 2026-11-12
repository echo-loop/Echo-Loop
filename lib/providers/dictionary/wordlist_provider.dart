/// 手动查词词表 Provider
///
/// 词表只在查词页存活期间被 watch：页面退出后无监听者，autoDispose 释放
/// [WordlistIndex] 引用，允许 GC 回收。不做空闲超时，也不主动清理 Flutter 的
/// Asset 缓存（这里以 `cache: false` 读取，原文不进入全局 asset 缓存）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../services/app_logger.dart';
import '../../services/dictionary/wordlist_index.dart';

part 'wordlist_provider.g.dart';

/// 本地英文词表的 Flutter Asset 路径
const kWordlistAssetPath = 'assets/dictionary/wordlist-en_US.txt';

/// 加载并解析本地词表。读取在主 isolate（rootBundle 仅主 isolate 可用），
/// 解析在后台 isolate 完成，不阻塞 UI 与用户输入。
@riverpod
Future<WordlistIndex> wordlist(Ref ref) async {
  try {
    final raw = await rootBundle.loadString(kWordlistAssetPath, cache: false);
    final stopwatch = Stopwatch()..start();
    final words = await compute(parseWordlist, raw);
    AppLogger.log(
      'Lookup',
      '本地词表加载完成 词数=${words.length} elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
    return WordlistIndex(words);
  } catch (error, stackTrace) {
    AppLogger.log('Lookup', '本地词表加载失败: $error');
    AppLogger.log('Lookup', stackTrace.toString());
    rethrow;
  }
}
