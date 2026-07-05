/// 本地（离线）转录任务管理 Provider。
///
/// 云端 [TranscriptionTaskManager] 的离线对偶：用设备已下载的 Whisper 模型
/// 在本机转录音频生成字幕，不上传、不登录。
/// keepAlive：弹窗关闭后任务继续在后台运行。
///
/// 流水线：ffmpeg 解码为 16kHz WAV → 专用引擎按所选档位分段转录（段级真实时间戳）
/// → 合成词级时间戳 → 写入 DB（transcript_srt + wordTimestampsJson）。
/// 引擎为**专用实例**（用后即 dispose），与评分共享引擎解耦（见 PLAN ADR / §组件3）。
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:universal_io/io.dart';
import 'package:uuid/uuid.dart';

import '../database/providers.dart';
import '../features/audio_import/audio_transcode_service.dart';
import '../models/audio_item.dart';
import '../models/word_timestamp.dart';
import '../services/app_logger.dart';
import '../services/asr/asr_model_manager.dart';
import '../services/asr/offline_asr_engine.dart';
import '../services/asr/sherpa_onnx_engine.dart';
import '../utils/srt_generator.dart';
import '../utils/synthetic_word_timestamps.dart';
import '../utils/transcript_stats.dart';
import 'asr_engine_provider.dart';
import 'audio_library_provider.dart';
import 'transcription_task_provider.dart' show transcriptionFileOpsProvider;

part 'local_transcription_task_provider.g.dart';

// ─── 可注入 seam（便于测试） ──────────────────────────────────

/// 专用转录引擎工厂（测试时覆盖为 mock 引擎）。
///
/// 每个转录任务用一个独立引擎实例，用后 dispose，不复用评分共享引擎，
/// 以免切换档位时 dispose/reload 扰乱评分已加载的模型。
@Riverpod(keepAlive: true)
OfflineAsrEngine Function() localTranscriptionEngineFactory(Ref ref) =>
    () => SherpaOnnxEngine();

/// 转录用转码服务 Provider（测试时可覆盖）。
@Riverpod(keepAlive: true)
AudioTranscodeService localTranscriptionTranscodeService(Ref ref) =>
    AudioTranscodeService();

// ─── 任务状态 ─────────────────────────────────────────────

/// 本地转录任务状态基类。
sealed class LocalTranscriptionState {
  const LocalTranscriptionState();
}

/// 空闲（未开始或已清除）。
class LocalTranscriptionIdle extends LocalTranscriptionState {
  const LocalTranscriptionIdle();
}

/// 解码音频为 16kHz WAV 中（不定态进度）。
class LocalTranscriptionDecoding extends LocalTranscriptionState {
  const LocalTranscriptionDecoding();
}

/// 转录推理中（determinate 进度 0.0~1.0）。
class LocalTranscriptionTranscribing extends LocalTranscriptionState {
  final double progress;
  const LocalTranscriptionTranscribing({this.progress = 0});
}

/// 转录完成。
class LocalTranscriptionCompleted extends LocalTranscriptionState {
  const LocalTranscriptionCompleted();
}

/// 转录失败。[code] 为简短错误码（decode / engine / unknown）。
class LocalTranscriptionFailed extends LocalTranscriptionState {
  final String code;
  const LocalTranscriptionFailed({required this.code});
}

/// 转录成功但无语音内容（音乐/全静音）。
class LocalTranscriptionEmptyResult extends LocalTranscriptionState {
  const LocalTranscriptionEmptyResult();
}

// ─── Provider ────────────────────────────────────────────

/// 本地转录任务管理器。
///
/// keepAlive：弹窗关闭后任务仍在后台运行。
/// state：`Map<String, LocalTranscriptionState>`（audioId -> state）。
@Riverpod(keepAlive: true)
class LocalTranscriptionTaskManager extends _$LocalTranscriptionTaskManager {
  /// 已请求取消的 audioId 集合。
  final Set<String> _cancelled = {};

  /// 各 audioId 在途转录的取消信号：取消时 complete，用于立即打断
  /// `transcribeSegments` 的 await（否则要等阻塞的 worker 跑完才返回）。
  final Map<String, Completer<void>> _cancelSignals = {};
  final _uuid = const Uuid();

  @override
  Map<String, LocalTranscriptionState> build() => {};

  /// 获取指定音频的任务状态。
  LocalTranscriptionState getTaskState(String audioId) {
    return state[audioId] ?? const LocalTranscriptionIdle();
  }

  /// 启动本地转录任务。
  ///
  /// [audioItem] 要转录的音频项（须已就绪，audioPath 非空）。
  /// [model] 使用的 Whisper 档位（须已下载，由门控保证）。
  /// [autoMergeShortSentences] 是否把 VAD 切出的相邻短段合并到目标时长
  /// （对齐 AI 转录的「自动合并短句」；关闭时保留 VAD 原始切分）。
  Future<void> startLocalTranscription(
    AudioItem audioItem, {
    required AsrModelInfo model,
    bool autoMergeShortSentences = true,
  }) async {
    final audioId = audioItem.id;

    // 防重入：进行中忽略。
    final current = state[audioId];
    if (current is LocalTranscriptionDecoding ||
        current is LocalTranscriptionTranscribing) {
      return;
    }
    _cancelled.remove(audioId);
    final cancelSignal = Completer<void>();
    _cancelSignals[audioId] = cancelSignal;

    OfflineAsrEngine? engine;
    File? tempWav;
    try {
      final fileOps = ref.read(transcriptionFileOpsProvider);
      final dataDir = await fileOps.getDataDir();
      final audioPath = audioItem.audioPath;
      if (audioPath == null || audioPath.isEmpty) {
        _update(audioId, const LocalTranscriptionFailed(code: 'unknown'));
        return;
      }
      final fullPath = p.isAbsolute(audioPath)
          ? audioPath
          : p.join(dataDir.path, audioPath);

      // ── 1. 解码为 16kHz WAV ──
      _update(audioId, const LocalTranscriptionDecoding());
      if (_isCancelled(audioId)) return;

      final tmpDir = Directory(p.join(dataDir.path, 'tmp', 'asr_transcribe'));
      await tmpDir.create(recursive: true);
      tempWav = File(p.join(tmpDir.path, '${_uuid.v4()}.wav'));
      final transcode = ref.read(localTranscriptionTranscodeServiceProvider);
      final decoded = await transcode.transcodeToPcmWav16k(
        source: File(fullPath),
        output: tempWav,
      );
      if (_isCancelled(audioId)) return;
      if (!decoded) {
        _update(audioId, const LocalTranscriptionFailed(code: 'decode'));
        return;
      }

      // ── 2. 初始化专用引擎（按所选档位）──
      final modelManager = ref.read(asrModelManagerProvider);
      final config = await _buildModelConfig(modelManager, model);
      engine = ref.read(localTranscriptionEngineFactoryProvider)();
      await engine.initialize(config);
      if (_isCancelled(audioId)) return;

      // ── 3. 分段转录（带进度）──
      // 用 Future.any 让取消信号能立即打断 await：native 推理阻塞、worker 无法
      // 中途响应，取消后主流程即返回走 finally 清理（dispose 引擎 + 删临时 WAV），
      // 不必等 worker 跑完。在途的 transcribeSegments 变 orphan，随引擎 dispose 失效。
      _update(audioId, const LocalTranscriptionTranscribing(progress: 0));
      List<AsrSegment>? segments;
      await Future.any(<Future<void>>[
        engine
            .transcribeSegments(
              tempWav.path,
              onProgress: (progress) {
                if (_isCancelled(audioId)) return;
                _update(
                  audioId,
                  LocalTranscriptionTranscribing(progress: progress),
                );
              },
            )
            .then((s) => segments = s),
        cancelSignal.future,
      ]);
      if (_isCancelled(audioId) || segments == null) return;
      final resolvedSegments = segments!;

      // ── 4. 空结果（全静音/无语音）──
      if (resolvedSegments.isEmpty) {
        _update(audioId, const LocalTranscriptionEmptyResult());
        return;
      }

      // ── 5. 段列表 →（可选合并短句）→ SRT + 合成词级时间戳 ──
      final merged = autoMergeShortSentences
          ? mergeShortAsrSegments(resolvedSegments)
          : resolvedSegments;
      final sentences = merged
          .map(
            (s) => TranscriptSentence(
              text: s.text,
              startTime: s.start,
              endTime: s.end,
            ),
          )
          .toList();
      final srt = generateSrtContent(sentences);
      // 词级时间戳按字符长度合成（与本地上传一致；VAD 已按静音切句，不接 auto-align）。
      final words = await generateSyntheticWordTimestampsFromSrt(srt);
      final wordsJson = words.isEmpty ? null : encodeWordTimestamps(words);
      final stats = await getTranscriptStatsFromSrt(srt);

      // ── 6. 写库 + 更新 AudioItem ──
      await ref
          .read(audioItemDaoProvider)
          .saveTranscriptContent(
            audioId,
            srt: srt,
            wordTimestampsJson: wordsJson,
          );
      ref
          .read(audioLibraryProvider.notifier)
          .updateAudioItem(
            audioItem.copyWith(
              transcriptPath: null,
              transcriptSource: TranscriptSource.device,
              transcriptLanguage: 'en',
              sentenceCount: stats.$1,
              wordCount: stats.$2,
            ),
          );

      _update(audioId, const LocalTranscriptionCompleted());

      // 10 秒后自动清理 completed 状态，避免内存累积。
      Future.delayed(const Duration(seconds: 10), () {
        if (state[audioId] is LocalTranscriptionCompleted) {
          clearState(audioId);
        }
      });
    } catch (e, st) {
      AppLogger.log('LocalTranscription', '❌ 本地转录失败 id=$audioId | $e\n$st');
      if (!_isCancelled(audioId)) {
        _update(audioId, const LocalTranscriptionFailed(code: 'unknown'));
      }
    } finally {
      // 释放专用引擎（isolate）与临时 WAV。transcribeSegments 已 await 完成，
      // 故 dispose 不会与在途推理竞争。
      await engine?.dispose();
      if (tempWav != null) {
        try {
          if (await tempWav.exists()) await tempWav.delete();
        } catch (_) {}
      }
      _cancelled.remove(audioId);
      _cancelSignals.remove(audioId);
    }
  }

  /// 取消转录任务。
  ///
  /// 置取消标记并 complete 取消信号，立即打断在途 `transcribeSegments` 的 await，
  /// 使主流程返回并走 finally 清理（dispose 引擎 + 删除临时 WAV）；native 解码/
  /// 推理仍会在 worker 内跑完，但引擎 dispose 会强制 kill 该 isolate，结果被丢弃。
  void cancelTranscription(String audioId) {
    if (state[audioId] == null) return;
    _cancelled.add(audioId);
    final signal = _cancelSignals[audioId];
    if (signal != null && !signal.isCompleted) signal.complete();
    _update(audioId, const LocalTranscriptionIdle());
  }

  /// 清除已完成/失败的状态。
  void clearState(String audioId) {
    state = Map.of(state)..remove(audioId);
  }

  // ─── 内部方法 ──────────────────────────────────────────

  bool _isCancelled(String audioId) => _cancelled.contains(audioId);

  void _update(String audioId, LocalTranscriptionState taskState) {
    state = Map.of(state)..[audioId] = taskState;
  }

  /// 按所选档位构建引擎配置（复用评分侧同款逻辑：modelDir + 可选 VAD 路径）。
  Future<AsrModelConfig> _buildModelConfig(
    AsrModelManager modelManager,
    AsrModelInfo model,
  ) async {
    final modelDir = await modelManager.modelDir(model.id);
    String? vadPath;
    if (await modelManager.isModelDownloaded(vadModelId)) {
      final vadDir = await modelManager.modelDir(vadModelId);
      vadPath = p.join(vadDir, 'silero_vad.onnx');
    }
    return AsrModelConfig(
      model: model,
      modelDir: modelDir,
      numThreads: AsrModelConfig.recommendedThreads(),
      vadModelPath: vadPath,
    );
  }

  /// 测试入口：直接注入取消标记。
  @visibleForTesting
  void markCancelledForTest(String audioId) => _cancelled.add(audioId);
}

/// 短句合并目标下限（秒）：一组合并后至少达到该时长才收尾。
///
/// 与 AI 转录「目标 4-7 秒」对齐：达到 4s 即收尾，单个长段不再拼接，
/// 自然落在 4-7s 区间；相邻两个极短段偶尔合并后略超 7s 属可接受。
const _mergeMinTargetSeconds = 4;

/// 把 VAD 切出的相邻短段贪心合并到目标时长（4~7 秒），对齐 AI 转录的
/// 「自动合并短句」体验。
///
/// 策略：逐段累积到当前组；当前组时长未达下限（4s）时并入下一段，达到下限即收尾。
/// 单个本就较长（≥下限）的段保持不动、绝不拆分；合并只发生在相邻短段之间。
/// 文本按空格拼接（VAD 段为独立语音区间，英文以空格连接自然）；区间取并集。
/// 空列表原样返回。
@visibleForTesting
List<AsrSegment> mergeShortAsrSegments(List<AsrSegment> segments) {
  if (segments.length <= 1) return segments;

  final result = <AsrSegment>[];
  AsrSegment? current;
  for (final seg in segments) {
    if (current == null) {
      current = seg;
      continue;
    }
    final curSeconds = (current.end - current.start).inMilliseconds / 1000.0;
    if (curSeconds >= _mergeMinTargetSeconds) {
      // 当前组已足够长，直接收尾，不再拼接（避免超出上限过多）。
      result.add(current);
      current = seg;
    } else {
      // 当前组过短，并入下一段以延长到目标时长。
      current = AsrSegment(
        text: '${current.text.trim()} ${seg.text.trim()}'.trim(),
        start: current.start,
        end: seg.end,
      );
    }
  }
  if (current != null) result.add(current);
  return result;
}
