/// 意群数据服务
///
/// 纯数据类，封装词级时间戳加载、AI 意群拆分请求和时间范围计算。
/// 不包含 UI 状态或播放逻辑，由 [AnnotationContentView] 内部使用。
library;

import 'package:flutter/foundation.dart';

import '../database/daos/audio_item_dao.dart';
import '../models/audio_item.dart';
import '../models/sense_group_result.dart';
import '../models/word_timestamp.dart';
import '../providers/sentence_ai_provider.dart';
import '../services/transcription_api_client.dart';
import 'sense_group_timing.dart';

/// 意群数据服务
class SenseGroupService {
  /// 加载词级时间戳（DB 优先，未命中则从 API 拉取并保存）
  ///
  /// 返回词级时间戳列表，无数据时返回 null。
  Future<List<WordTimestamp>?> fetchWordTimestamps({
    required String audioItemId,
    required AudioItemDao dao,
    required TranscriptionApiClient api,
  }) async {
    final audioItem = await dao.getById(audioItemId);
    if (audioItem == null) return null;
    // 仅 AI 转录有词级时间戳
    if (audioItem.transcriptSource != TranscriptSource.ai.index) return null;

    // 1. 优先从 audio_items 表读取
    final json = audioItem.wordTimestampsJson;
    if (json != null) {
      final words = decodeWordTimestamps(json);
      if (words != null && words.isNotEmpty) return words;
      // JSON 解析失败，清除脏数据
      await dao.updateWordTimestamps(audioItemId, null);
    }

    // 2. DB 未命中，从 API 拉取并保存
    final sha256 = audioItem.audioSha256;
    final language = audioItem.transcriptLanguage;
    if (sha256 == null || language == null) return null;

    try {
      final result = await api.getTranscript(sha256, language);
      if (result.words != null && result.words!.isNotEmpty) {
        await dao.updateWordTimestamps(
          audioItemId,
          encodeWordTimestamps(result.words!),
        );
        return result.words;
      }
    } catch (e) {
      debugPrint('获取词级时间戳失败: $e');
    }
    return null;
  }

  /// 请求 AI 拆分意群
  ///
  /// 返回拆分结果和对应的时间范围。有词级时间戳时精确计算，否则按词数均分。
  Future<(SenseGroupResult result, List<SenseGroupTiming> timings)>
  requestSenseGroups({
    required String text,
    required SentenceAiNotifier ai,
    required int sentenceStartMs,
    required int sentenceEndMs,
    List<WordTimestamp>? wordTimestamps,
  }) async {
    final result = await ai.getSenseGroups(text);
    final timings = computeTimings(
      chunks: result.medium,
      wordTimestamps: wordTimestamps ?? const [],
      sentenceStartMs: sentenceStartMs,
      sentenceEndMs: sentenceEndMs,
    );
    return (result, timings);
  }

  /// 计算意群时间范围
  List<SenseGroupTiming> computeTimings({
    required List<String> chunks,
    required List<WordTimestamp> wordTimestamps,
    required int sentenceStartMs,
    required int sentenceEndMs,
  }) {
    // 找到句子在 words 中的范围
    var startIdx = 0;
    var endIdx = wordTimestamps.length - 1;

    for (var i = 0; i < wordTimestamps.length; i++) {
      if (wordTimestamps[i].startTime.inMilliseconds >= sentenceStartMs - 100) {
        startIdx = i;
        break;
      }
    }
    for (var i = wordTimestamps.length - 1; i >= 0; i--) {
      if (wordTimestamps[i].endTime.inMilliseconds <= sentenceEndMs + 100) {
        endIdx = i;
        break;
      }
    }

    return mapSenseGroupTimings(
      chunks: chunks,
      words: wordTimestamps,
      sentenceStart: Duration(milliseconds: sentenceStartMs),
      sentenceEnd: Duration(milliseconds: sentenceEndMs),
      sentenceStartWordIndex: startIdx,
      sentenceEndWordIndex: endIdx,
    );
  }
}
