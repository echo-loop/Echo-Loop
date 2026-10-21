// 转录任务状态管理 Provider
//
// keepAlive: 弹窗关闭后任务继续在后台运行。
// 管理各音频的 AI 转录任务生命周期：
// 上传 → 转录 → 完成（或失败）。
import 'dart:math' show min;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider, Ref;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../analytics/models/event_names.dart';
import '../features/usage/usage_event.dart';
import '../features/usage/usage_providers.dart';
import '../utils/app_data_dir.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/providers.dart';
import '../features/audio_import/audio_finalization_service.dart';
import '../features/audio_import/audio_transcode_service.dart';
import '../features/audio_import/transcription_audio_extractor.dart';
import '../features/remote_config/remote_config_providers.dart';
import '../features/subscription/providers/subscription_controller.dart'
    show entitlementQuotaDivergenceHandlerProvider;
import '../features/subscription/models/ai_quota_rejection.dart';
import '../models/audio_item.dart';
import '../models/word_timestamp.dart';
import '../providers/audio_library_provider.dart';
import '../services/app_logger.dart';
import '../services/subtitle_auto_align_service.dart';
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

  /// 获取应用数据目录
  Future<Directory> getDataDir() => getAppDataDirectory();
}

/// 文件操作 Provider（测试时可覆盖）
@Riverpod(keepAlive: true)
TranscriptionFileOps transcriptionFileOps(Ref ref) =>
    const TranscriptionFileOps();

/// 转录成功后把原始音频转码为 m4a 的服务 Provider（测试时可覆盖）
@Riverpod(keepAlive: true)
AudioFinalizationService transcriptionFinalizationService(Ref ref) =>
    AudioFinalizationService();

/// 视频转录前抽取音轨的服务 Provider（测试时可覆盖）
@Riverpod(keepAlive: true)
TranscriptionAudioExtractor transcriptionAudioExtractor(Ref ref) =>
    TranscriptionAudioExtractor();

/// 云端转录上传前的临时音频压缩服务（测试时可覆盖）。
final transcriptionUploadTranscodeServiceProvider =
    Provider<AudioTranscodeService>((ref) => AudioTranscodeService());

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

/// 正在将过大的上传文件压缩为临时音频。
class TranscriptionCompressing extends TranscriptionTaskState {
  const TranscriptionCompressing();
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

/// 转录成功但无语音内容（音乐/背景音）
class TranscriptionEmptyResult extends TranscriptionTaskState {
  const TranscriptionEmptyResult();
}

/// 本月免费额度用尽（后端返回 402）——由 UI 引导订阅升级。
class TranscriptionQuotaExceeded extends TranscriptionTaskState {
  const TranscriptionQuotaExceeded({
    this.reason = AiQuotaRejectionReason.exhausted,
  });

  final AiQuotaRejectionReason reason;
}

// ─── Provider ──────────────────────────────────────────────

/// 转录任务管理器
///
/// keepAlive: 弹窗关闭后任务仍在后台运行。
/// state: `Map<String, TranscriptionTaskState>`（audioId -> state）
@Riverpod(keepAlive: true)
class TranscriptionTaskManager extends _$TranscriptionTaskManager {
  static const _appMaxUploadBytes = 25 * 1024 * 1024;

  /// 各任务的 CancelToken
  final Map<String, CancelToken> _cancelTokens = {};
  final _uuid = const Uuid();

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
  /// [accessToken] Supabase 登录态 token，用于访问受保护的 v2 转录 API。
  /// [autoMergeShortSentences] 是否自动合并短句（默认开启）。关闭时后端返回
  /// provider 原生未合并分句（句子更短）。
  Future<void> startTranscription(
    AudioItem audioItem,
    String language, {
    required String accessToken,
    bool autoMergeShortSentences = true,
  }) async {
    final audioId = audioItem.id;

    // 防止重复发起
    final current = state[audioId];
    if (current is TranscriptionHashing ||
        current is TranscriptionCompressing ||
        current is TranscriptionUploading ||
        current is TranscriptionProcessing) {
      return;
    }

    final cancelToken = CancelToken();
    _cancelTokens[audioId] = cancelToken;

    // 上传压缩和视频抽音轨均可能产生临时文件，结束后统一清理。
    File? temporaryUploadFile;
    String? tempAudioPath;

    try {
      final api = ref.read(transcriptionApiClientProvider);
      final fileOps = ref.read(transcriptionFileOpsProvider);

      // ── 步骤 1: 计算 SHA256 ──
      _updateState(audioId, const TranscriptionHashing());
      final docDir = await fileOps.getDataDir();
      final fullPath = p.join(docDir.path, audioItem.audioPath);
      final finalAudioSha256 =
          audioItem.audioSha256 ?? await fileOps.computeSha256(fullPath);
      // 转录缓存 key（服务端）。始终用视频/原始文件指纹：同一视频在各平台 sha
      // 一致，跨设备/重导入才能命中缓存。视频抽出的音轨只是上传内容，其 ffmpeg
      // 产物 sha 因设备而异，绝不能用作缓存 key。
      var transcriptionSha256 =
          audioItem.originalAudioSha256 ?? finalAudioSha256;

      if (cancelToken.isCancelled) return;

      // 缓存最终文件 SHA256 到 AudioItem；转录缓存 key 不覆盖本地文件指纹。
      if (audioItem.audioSha256 == null) {
        ref
            .read(audioLibraryProvider.notifier)
            .updateAudioItem(audioItem.copyWith(audioSha256: finalAudioSha256));
      }

      // ── 步骤 2: 视频先抽音轨；超限时再压缩实际上传文件。 ──

      // 视频条目：转录前抽出音轨，只上传音频（省带宽、免服务端解码视频）。
      // uploadPath 指向实际上传的文件，视频抽取成功时为临时 m4a，否则为原文件。
      // 抽取失败静默回退上传原视频（后端兼容 mp4 容器）。缓存 key
      // (transcriptionSha256) 不受影响，仍是稳定的视频 sha——音轨仅作上传内容。
      var uploadPath = fullPath;
      if (audioItem.isVideo) {
        final extracted = await ref
            .read(transcriptionAudioExtractorProvider)
            .extractAudioTrack(dataDir: docDir, videoAbsolutePath: fullPath);
        if (cancelToken.isCancelled) return;
        if (extracted != null) {
          tempAudioPath = extracted;
          uploadPath = extracted;
        }
      }

      final remoteMaxUploadBytes = ref
          .read(remoteTranscriptionLimitsProvider)
          .maxUploadBytes;
      final maxUploadBytes = min(remoteMaxUploadBytes, _appMaxUploadBytes);
      var mimeType = _getMimeType(uploadPath);
      var fileSize = await fileOps.getFileSize(uploadPath);
      if (fileSize > maxUploadBytes) {
        _updateState(audioId, const TranscriptionCompressing());
        final tempDir = Directory(
          p.join(docDir.path, 'tmp', 'transcription_upload'),
        );
        await tempDir.create(recursive: true);
        temporaryUploadFile = File(p.join(tempDir.path, '${_uuid.v4()}.m4a'));
        final compressed = await ref
            .read(transcriptionUploadTranscodeServiceProvider)
            .transcodeForTranscriptionUpload(
              source: File(uploadPath),
              output: temporaryUploadFile,
            );
        if (cancelToken.isCancelled) return;
        if (!compressed) {
          _updateState(
            audioId,
            const TranscriptionFailed(message: 'compression'),
          );
          return;
        }
        uploadPath = temporaryUploadFile.path;
        fileSize = await fileOps.getFileSize(uploadPath);
        if (fileSize > maxUploadBytes) {
          _updateState(
            audioId,
            const TranscriptionFailed(message: 'compressedFileTooLarge'),
          );
          return;
        }
        transcriptionSha256 = await fileOps.computeSha256(uploadPath);
        mimeType = 'audio/mp4';
      }

      _updateState(audioId, const TranscriptionUploading());
      AppLogger.log(
        'Transcription',
        'Step 2 上传 | isVideo=${audioItem.isVideo} sha256=$transcriptionSha256 '
            'size=$fileSize mime=$mimeType',
      );

      final uploadResp = await api.getUploadUrl(
        sha256: transcriptionSha256,
        mimeType: mimeType,
        fileSize: fileSize,
        accessToken: accessToken,
      );

      if (cancelToken.isCancelled) return;

      // 音频未存在，需上传
      if (!uploadResp.audioExists && uploadResp.uploadUrl != null) {
        await api.uploadToR2(
          uploadUrl: uploadResp.uploadUrl!,
          filePath: uploadPath,
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
        sha256: transcriptionSha256,
        fileName: _displayFileNameForTranscription(audioItem, fullPath),
        objectName: uploadResp.objectName,
        publicUrl: uploadResp.publicUrl,
        mimeType: mimeType,
        fileSize: fileSize,
        language: language,
        accessToken: accessToken,
        mergeSentences: autoMergeShortSentences,
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
          finalAudioSha256,
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
        transcriptionSha256,
        finalAudioSha256,
        language,
        accessToken,
        cancelToken,
        autoMergeShortSentences,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      AppLogger.log(
        'Transcription',
        '❌ 转录失败(Dio) | type=${e.type} status=${e.response?.statusCode} '
            'msg=${e.message ?? e.error} body=${e.response?.data}',
      );
      // 后端本月免费额度用尽 → 交由 UI 引导订阅（区别于普通失败的重试提示）。
      if (e.response?.statusCode == 402) {
        // E7：后端 402 与本地 premium 分歧时回源对账（handler 内部判 isActive）。
        ref.read(entitlementQuotaDivergenceHandlerProvider)('transcription');
        final rejection = AiQuotaRejection.fromResponseData(e.response?.data);
        _updateState(
          audioId,
          TranscriptionQuotaExceeded(reason: rejection.reason),
        );
        return;
      }
      _updateState(
        audioId,
        TranscriptionFailed(message: _userFriendlyError(e)),
      );
    } catch (e, st) {
      AppLogger.log('Transcription', '❌ 转录失败(非网络) | $e\n$st');
      _updateState(audioId, const TranscriptionFailed(message: 'unknown'));
    } finally {
      // 清理视频抽出的临时音轨（上传后即无用；原视频文件不受影响）。
      if (tempAudioPath != null) {
        try {
          final tmp = File(tempAudioPath);
          if (await tmp.exists()) await tmp.delete();
        } catch (_) {}
      }
      if (temporaryUploadFile != null && await temporaryUploadFile.exists()) {
        try {
          await temporaryUploadFile.delete();
        } catch (e) {
          AppLogger.log('Transcription', '临时压缩文件清理失败: $e');
        }
      }
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
    final responseData = e.response?.data;
    final backendCode = responseData is Map ? responseData['code'] : null;
    if (backendCode is String) {
      final localizedCode = switch (backendCode) {
        'file_too_large' => 'fileTooLarge',
        'audio_not_found' => 'audioNotFound',
        'audio_expired' => 'audioExpired',
        'missing_fields' => 'requestInvalid',
        'api_deprecated' => 'apiDeprecated',
        _ => null,
      };
      if (localizedCode != null) return localizedCode;
    }

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

  /// 轮询任务状态（指数退避：2s 起步，×1.5 增长，封顶 15s，最多 5 分钟）
  ///
  /// 转录任务本身耗时数十秒，固定高频轮询前期多为空查询、浪费请求。
  /// 改用退避策略后 5 分钟内请求数从约 100 次降至约 23 次，显著减轻服务器压力；
  /// 代价是任务完成后用户最多多等约 15s，对本就耗时的转录可接受。
  Future<void> _pollJobStatus(
    AudioItem audioItem,
    String jobId,
    String transcriptionSha256,
    String finalAudioSha256,
    String language,
    String accessToken,
    CancelToken cancelToken,
    bool autoMergeShortSentences,
  ) async {
    final api = ref.read(transcriptionApiClientProvider);
    const initialInterval = Duration(seconds: 2);
    const maxInterval = Duration(seconds: 15);
    const maxDuration = Duration(minutes: 5);
    final deadline = DateTime.now().add(maxDuration);
    var interval = initialInterval;

    while (DateTime.now().isBefore(deadline)) {
      if (cancelToken.isCancelled) return;

      await Future<void>.delayed(interval);
      if (cancelToken.isCancelled) return;

      // 下一轮间隔 ×1.5 增长，封顶 maxInterval
      final grown = (interval.inMilliseconds * 1.5).round();
      interval = grown >= maxInterval.inMilliseconds
          ? maxInterval
          : Duration(milliseconds: grown);

      try {
        final status = await api.getJobStatus(jobId, accessToken: accessToken);

        if (status.isCompleted) {
          final transcript = await api.getTranscript(
            transcriptionSha256,
            language,
            accessToken: accessToken,
            mergeSentences: autoMergeShortSentences,
          );
          if (cancelToken.isCancelled) return;
          await _saveTranscriptAndFinish(
            audioItem,
            transcript,
            language,
            finalAudioSha256,
          );
          return;
        }

        if (status.isFailed) {
          AppLogger.log(
            'Transcription',
            '❌ 后端任务失败 | jobId=$jobId errorMessage=${status.errorMessage}',
          );
          _updateState(
            audioItem.id,
            const TranscriptionFailed(message: 'server'),
          );
          return;
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) return;
        // 轮询中的网络错误不立即失败，继续重试（拦截器已记录详情）
        AppLogger.log(
          'Transcription',
          '轮询出错(将重试) | jobId=$jobId type=${e.type} status=${e.response?.statusCode}',
        );
      }
    }

    // 超时
    _updateState(audioItem.id, const TranscriptionFailed(message: 'timeout'));
  }

  /// 保存转录结果到 DB（transcript_srt 列）并更新 AudioItem
  Future<void> _saveTranscriptAndFinish(
    AudioItem audioItem,
    TranscriptResult transcript,
    String language,
    String sha256,
  ) async {
    // 转录结果为空（音频无人声），不保存 SRT，提示用户
    if (transcript.sentences.isEmpty) {
      _cancelTokens.remove(audioItem.id);
      _updateState(audioItem.id, const TranscriptionEmptyResult());
      return;
    }

    final alignedSentences = await _alignSentencesIfPossible(
      audioItem,
      transcript,
    );
    final srtContent = generateSrtContent(alignedSentences);
    final stats = await getTranscriptStatsFromSrt(srtContent);

    // ── 转码（best-effort）──
    // 新流程：导入保留原始音频，转录上传原始；拿到字幕后顺带把原始转码为 m4a。
    // 转码失败静默处理：仍保存字幕、保留原始音频，避免转码 bug 把音频挡在学习外。
    // 仅对「尚未转码的用户导入」执行：remoteAudioId==null（非社区）且
    // audioSha256==originalAudioSha256（存的还是原始文件）。老数据/已转码/社区跳过。
    //
    // 视频条目必须跳过：transcodeExisting 只保留音轨转 m4a，会把视频转成纯音频、
    // 丢掉画面并令 isVideo 派生失真。视频永远保留原始文件（后续要真实播放视频）。
    final needTranscode =
        audioItem.remoteAudioId == null &&
        !audioItem.isVideo &&
        audioItem.audioPath != null &&
        audioItem.originalAudioSha256 != null &&
        audioItem.audioSha256 == audioItem.originalAudioSha256;
    var finalAudioPath = audioItem.audioPath;
    var finalSha = sha256;
    var transcoded = false;
    if (needTranscode) {
      try {
        final dataDir = await ref
            .read(transcriptionFileOpsProvider)
            .getDataDir();
        final finalizationService = ref.read(
          transcriptionFinalizationServiceProvider,
        );
        final result = await finalizationService.transcodeExisting(
          dataDir: dataDir,
          relativePath: audioItem.audioPath!,
        );
        finalAudioPath = result.relativePath;
        finalSha = result.sha256;
        transcoded = true;
      } catch (e) {
        AppLogger.log(
          'Transcription',
          '转码失败(静默,保留原始) id=${audioItem.id} err=$e',
        );
      }
    }

    // 字幕内容 + 词级时间戳原子写入 DB（transcript_srt 列成为唯一真相源）
    final wordsJson = (transcript.words != null && transcript.words!.isNotEmpty)
        ? encodeWordTimestamps(transcript.words!)
        : null;
    try {
      final audioDao = ref.read(audioItemDaoProvider);
      await audioDao.saveTranscriptContent(
        audioItem.id,
        srt: srtContent,
        wordTimestampsJson: wordsJson,
      );
    } catch (e) {
      debugPrint('保存字幕内容失败: $e');
    }

    // 更新 AudioItem 模型列（transcriptPath 置 null，内容在 DB 列）
    ref
        .read(audioLibraryProvider.notifier)
        .updateAudioItem(
          audioItem.copyWith(
            audioPath: finalAudioPath,
            transcriptPath: null,
            transcriptSource: TranscriptSource.ai,
            transcriptLanguage: language,
            audioSha256: finalSha,
            sentenceCount: stats.$1,
            wordCount: stats.$2,
          ),
        );

    // DB 更新后再删除旧原始文件，避免中途崩溃导致 audioPath 指向不存在文件。
    // 引用检查：同内容导入会复用同一文件（多个条目共享 audioPath）。当前条目已
    // 更新为转码后路径，若仍有其他条目引用旧文件则不能删，否则会删掉它们的音频。
    if (transcoded &&
        finalAudioPath != audioItem.audioPath &&
        audioItem.audioPath != null) {
      final stillReferenced = ref
          .read(audioLibraryProvider)
          .audioItems
          .any((it) => it.audioPath == audioItem.audioPath);
      if (!stillReferenced) {
        try {
          final dataDir = await ref
              .read(transcriptionFileOpsProvider)
              .getDataDir();
          final oldFile = File(p.join(dataDir.path, audioItem.audioPath!));
          if (await oldFile.exists()) await oldFile.delete();
        } catch (e) {
          AppLogger.log('Transcription', '删除原始音频失败(忽略) err=$e');
        }
      }
    }

    _updateState(audioItem.id, const TranscriptionCompleted());
    _cancelTokens.remove(audioItem.id);
    ref
        .read(usageTrackerProvider)
        .record(
          UsageEvent.aiTranscriptionCompleted,
          analyticsParams: {
            EventParams.audioId: audioItem.id,
            EventParams.audioName: audioItem.name,
          },
        );

    // 10 秒后自动清理 completed 状态，避免内存累积
    Future.delayed(const Duration(seconds: 10), () {
      if (state[audioItem.id] is TranscriptionCompleted) {
        clearState(audioItem.id);
      }
    });
  }

  /// 在 AI 转录完成后尝试用本地音频静音区间微调句边界。
  ///
  /// 仅对“用户自己的音频 + AI 词级时间戳齐全”生效。
  /// 任意失败都只记录日志并回退到原始句边界。
  Future<List<TranscriptSentence>> _alignSentencesIfPossible(
    AudioItem audioItem,
    TranscriptResult transcript,
  ) async {
    if (audioItem.remoteAudioId != null ||
        audioItem.audioPath == null ||
        audioItem.audioPath!.isEmpty ||
        transcript.words == null ||
        transcript.words!.isEmpty ||
        transcript.sentences.isEmpty) {
      return transcript.sentences;
    }

    final fileOps = ref.read(transcriptionFileOpsProvider);
    final fullAudioPath = await _resolveAudioPath(audioItem, fileOps);
    if (fullAudioPath == null) {
      AppLogger.log(
        'SubtitleAutoAlign',
        'skip auto-align: audio path unavailable for ${audioItem.id}',
      );
      return transcript.sentences;
    }

    try {
      final autoAlignService = ref.read(subtitleAutoAlignServiceProvider);
      return await autoAlignService.alignIfPossible(
        audioPath: fullAudioPath,
        sentences: transcript.sentences,
        words: transcript.words!,
      );
    } catch (error) {
      AppLogger.log(
        'SubtitleAutoAlign',
        'skip auto-align in transcription flow: $error',
      );
      return transcript.sentences;
    }
  }

  Future<String?> _resolveAudioPath(
    AudioItem audioItem,
    TranscriptionFileOps fileOps,
  ) async {
    final audioPath = audioItem.audioPath;
    if (audioPath == null || audioPath.isEmpty) return null;
    if (p.isAbsolute(audioPath)) return audioPath;

    final dataDir = await fileOps.getDataDir();
    return p.join(dataDir.path, audioPath);
  }

  /// AI 转录提交给后端的文件名优先使用用户可见的音频名称。
  ///
  /// 本地导入/下载后的沙盒文件名可能是 SHA256，不能代表用户原始音频名称；
  /// 异常空名称则回退到实际路径 basename，保证后端仍收到可用文件名。
  String _displayFileNameForTranscription(
    AudioItem audioItem,
    String fullPath,
  ) {
    final displayName = audioItem.name.trim();
    return displayName.isNotEmpty ? displayName : p.basename(fullPath);
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
