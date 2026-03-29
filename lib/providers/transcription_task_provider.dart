// 转录任务状态管理 Provider
//
// keepAlive: 弹窗关闭后任务继续在后台运行。
// 管理各音频的 AI 转录任务生命周期：
// 上传 → 转录 → 完成（或失败）。
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/providers.dart';
import '../models/audio_item.dart';
import '../models/word_timestamp.dart';
import '../providers/audio_library_provider.dart';
import '../services/transcription_api_client.dart';
import '../utils/audio_fingerprint.dart';
import '../utils/srt_generator.dart';
import '../utils/transcript_stats.dart';

part 'transcription_task_provider.g.dart';

// ─── 文件操作抽象（便于测试注入） ────────────────────────────

/// 封装转录流程中的文件系统操作，便于测试时 mock
class TranscriptionFileOps {
  const TranscriptionFileOps();

  /// 计算文件 SHA256
  Future<String> computeSha256(String filePath) => computeAudioSha256(filePath);

  /// 获取文件大小
  Future<int> getFileSize(String filePath) => File(filePath).length();

  /// 保存 SRT 文件，返回相对路径
  Future<String> saveSrt(String audioId, String srtContent) =>
      saveSrtFile(audioId, srtContent);

  /// 获取 SRT 统计 (sentenceCount, wordCount)
  Future<(int, int)> getStats(String srtFullPath) =>
      getTranscriptStats(srtFullPath);

  /// 获取应用文档目录
  Future<Directory> getDocDir() => getApplicationDocumentsDirectory();
}

/// 文件操作 Provider（测试时可覆盖）
@Riverpod(keepAlive: true)
TranscriptionFileOps transcriptionFileOps(Ref ref) =>
    const TranscriptionFileOps();

// ─── 转录任务状态 ──────────────────────────────────────────

/// 转录任务状态基类
sealed class TranscriptionTaskState {
  const TranscriptionTaskState();
}

/// 空闲（未开始或已清除）
class TranscriptionIdle extends TranscriptionTaskState {
  const TranscriptionIdle();
}

/// 计算 SHA256 中
class TranscriptionHashing extends TranscriptionTaskState {
  const TranscriptionHashing();
}

/// 上传音频到 R2 中
class TranscriptionUploading extends TranscriptionTaskState {
  /// 上传进度 0.0 ~ 1.0
  final double progress;
  const TranscriptionUploading({this.progress = 0});
}

/// 转录处理中（已提交到 Deepgram）
class TranscriptionProcessing extends TranscriptionTaskState {
  /// 后端任务 ID
  final String jobId;
  const TranscriptionProcessing({required this.jobId});
}

/// 转录完成
class TranscriptionCompleted extends TranscriptionTaskState {
  const TranscriptionCompleted();
}

/// 转录失败
class TranscriptionFailed extends TranscriptionTaskState {
  /// 错误信息
  final String message;
  const TranscriptionFailed({required this.message});
}

// ─── Provider ──────────────────────────────────────────────

/// 转录任务管理器
///
/// keepAlive: 弹窗关闭后任务仍在后台运行。
/// state: `Map<String, TranscriptionTaskState>`（audioId -> state）
@Riverpod(keepAlive: true)
class TranscriptionTaskManager extends _$TranscriptionTaskManager {
  /// 各任务的 CancelToken
  final Map<String, CancelToken> _cancelTokens = {};

  @override
  Map<String, TranscriptionTaskState> build() => {};

  /// 获取指定音频的任务状态
  TranscriptionTaskState getTaskState(String audioId) {
    return state[audioId] ?? const TranscriptionIdle();
  }

  /// 启动转录任务
  ///
  /// [audioItem] 要转录的音频项。
  /// [language] 转录语言 ('en' 或 'multi')。
  Future<void> startTranscription(AudioItem audioItem, String language) async {
    final audioId = audioItem.id;

    // 防止重复发起
    final current = state[audioId];
    if (current is TranscriptionHashing ||
        current is TranscriptionUploading ||
        current is TranscriptionProcessing) {
      return;
    }

    final cancelToken = CancelToken();
    _cancelTokens[audioId] = cancelToken;

    try {
      final api = ref.read(transcriptionApiClientProvider);
      final fileOps = ref.read(transcriptionFileOpsProvider);

      // ── 步骤 1: 计算 SHA256 ──
      _updateState(audioId, const TranscriptionHashing());
      final docDir = await fileOps.getDocDir();
      final fullPath = p.join(docDir.path, audioItem.audioPath);
      final sha256 =
          audioItem.audioSha256 ?? await fileOps.computeSha256(fullPath);

      if (cancelToken.isCancelled) return;

      // 缓存 SHA256 到 AudioItem
      if (audioItem.audioSha256 == null) {
        ref
            .read(audioLibraryProvider.notifier)
            .updateAudioItem(audioItem.copyWith(audioSha256: sha256));
      }

      // ── 步骤 2: 获取上传 URL + 上传 ──
      _updateState(audioId, const TranscriptionUploading());
      final mimeType = _getMimeType(fullPath);
      final fileSize = await fileOps.getFileSize(fullPath);
      print('[TRANSCRIPTION] Step 2: sha256=$sha256, size=$fileSize');

      final uploadResp = await api.getUploadUrl(
        sha256: sha256,
        mimeType: mimeType,
        fileSize: fileSize,
      );

      if (cancelToken.isCancelled) return;

      // 音频未存在，需上传
      if (!uploadResp.audioExists && uploadResp.uploadUrl != null) {
        await api.uploadToR2(
          uploadUrl: uploadResp.uploadUrl!,
          filePath: fullPath,
          contentType: mimeType,
          cancelToken: cancelToken,
          onProgress: (sent, total) {
            if (total > 0) {
              _updateState(
                audioId,
                TranscriptionUploading(progress: sent / total),
              );
            }
          },
        );
      }

      if (cancelToken.isCancelled) return;

      // ── 步骤 3: 提交转录 ──
      _updateState(audioId, const TranscriptionProcessing(jobId: ''));

      final submitResp = await api.submitTranscription(
        sha256: sha256,
        fileName: p.basename(fullPath),
        objectName: uploadResp.objectName,
        publicUrl: uploadResp.publicUrl,
        mimeType: mimeType,
        fileSize: fileSize,
        language: language,
      );

      if (cancelToken.isCancelled) return;

      if (submitResp.cached && submitResp.transcript != null) {
        // 字幕缓存命中 → 加短暂延迟让进度动画有展示机会
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (cancelToken.isCancelled) return;
        await _saveTranscriptAndFinish(
          audioItem,
          submitResp.transcript!,
          language,
          sha256,
        );
        return;
      }

      if (submitResp.jobId == null) {
        _updateState(audioId, const TranscriptionFailed(message: 'server'));
        return;
      }

      // ── 步骤 4: 轮询任务状态 ──
      _updateState(audioId, TranscriptionProcessing(jobId: submitResp.jobId!));
      await _pollJobStatus(
        audioItem,
        submitResp.jobId!,
        sha256,
        language,
        cancelToken,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      print('[TRANSCRIPTION] DioException: ${e.type} ${e.message} ${e.error}');
      _updateState(
        audioId,
        TranscriptionFailed(message: _userFriendlyError(e)),
      );
    } catch (e) {
      print('[TRANSCRIPTION] Error: $e');
      _updateState(audioId, const TranscriptionFailed(message: 'unknown'));
    }
  }

  /// 取消转录任务
  void cancelTranscription(String audioId) {
    _cancelTokens[audioId]?.cancel();
    _cancelTokens.remove(audioId);
    _updateState(audioId, const TranscriptionIdle());
  }

  /// 清除已完成/失败的状态
  void clearState(String audioId) {
    state = Map.of(state)..remove(audioId);
  }

  /// 将 DioException 转换为简短的错误码
  String _userFriendlyError(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout => 'connection',
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'timeout',
      DioExceptionType.badResponse => 'server',
      _ => 'unknown',
    };
  }

  // ─── 内部方法 ──────────────────────────────────────────

  void _updateState(String audioId, TranscriptionTaskState taskState) {
    state = Map.of(state)..[audioId] = taskState;
  }

  /// 轮询任务状态（3 秒间隔，最多 5 分钟）
  Future<void> _pollJobStatus(
    AudioItem audioItem,
    String jobId,
    String sha256,
    String language,
    CancelToken cancelToken,
  ) async {
    final api = ref.read(transcriptionApiClientProvider);
    const pollInterval = Duration(seconds: 3);
    const maxDuration = Duration(minutes: 5);
    final deadline = DateTime.now().add(maxDuration);

    while (DateTime.now().isBefore(deadline)) {
      if (cancelToken.isCancelled) return;

      await Future<void>.delayed(pollInterval);
      if (cancelToken.isCancelled) return;

      try {
        final status = await api.getJobStatus(jobId);

        if (status.isCompleted) {
          final transcript = await api.getTranscript(sha256, language);
          if (cancelToken.isCancelled) return;
          await _saveTranscriptAndFinish(
            audioItem,
            transcript,
            language,
            sha256,
          );
          return;
        }

        if (status.isFailed) {
          _updateState(
            audioItem.id,
            const TranscriptionFailed(message: 'server'),
          );
          return;
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) return;
        // 轮询中的网络错误不立即失败，继续重试
      }
    }

    // 超时
    _updateState(audioItem.id, const TranscriptionFailed(message: 'timeout'));
  }

  /// 保存转录结果到本地 SRT 文件并更新 AudioItem
  Future<void> _saveTranscriptAndFinish(
    AudioItem audioItem,
    TranscriptResult transcript,
    String language,
    String sha256,
  ) async {
    final fileOps = ref.read(transcriptionFileOpsProvider);
    final srtContent = generateSrtContent(transcript.sentences);
    final relativePath = await fileOps.saveSrt(audioItem.id, srtContent);

    // 获取 SRT 统计
    final docDir = await fileOps.getDocDir();
    final srtFullPath = p.join(docDir.path, relativePath);
    final stats = await fileOps.getStats(srtFullPath);

    // 更新 AudioItem
    ref
        .read(audioLibraryProvider.notifier)
        .updateAudioItem(
          audioItem.copyWith(
            transcriptPath: relativePath,
            transcriptSource: TranscriptSource.ai,
            transcriptLanguage: language,
            audioSha256: sha256,
            sentenceCount: stats.$1,
            wordCount: stats.$2,
          ),
        );

    // 保存词级时间戳到 audio_items 表（非阻塞，失败不影响主流程）
    if (transcript.words != null && transcript.words!.isNotEmpty) {
      try {
        final audioDao = ref.read(audioItemDaoProvider);
        await audioDao.updateWordTimestamps(
          audioItem.id,
          encodeWordTimestamps(transcript.words!),
        );
      } catch (e) {
        debugPrint('保存词级时间戳失败: $e');
      }
    }

    _updateState(audioItem.id, const TranscriptionCompleted());
    _cancelTokens.remove(audioItem.id);

    // 10 秒后自动清理 completed 状态，避免内存累积
    Future.delayed(const Duration(seconds: 10), () {
      if (state[audioItem.id] is TranscriptionCompleted) {
        clearState(audioItem.id);
      }
    });
  }

  /// 测试入口：根据文件扩展名推断 MIME 类型
  @visibleForTesting
  static String getMimeTypeForTest(String filePath) => _getMimeType(filePath);

  /// 根据文件扩展名推断 MIME 类型
  static String _getMimeType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    const mimeMap = {
      '.mp3': 'audio/mpeg',
      '.m4a': 'audio/mp4',
      '.aac': 'audio/aac',
      '.wav': 'audio/wav',
      '.flac': 'audio/flac',
      '.ogg': 'audio/ogg',
      '.wma': 'audio/x-ms-wma',
      '.opus': 'audio/opus',
      '.mp4': 'video/mp4',
      '.m4v': 'video/mp4',
      '.mov': 'video/quicktime',
      '.webm': 'video/webm',
    };
    return mimeMap[ext] ?? 'audio/mpeg';
  }
}
