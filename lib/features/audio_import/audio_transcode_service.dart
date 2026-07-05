import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

import '../../services/app_logger.dart';

/// 用户音频统一转码服务。
///
/// 使用与 `~/bin/convert-to-m4a` 默认分支一致的参数：AAC 64k、单声道、
/// 44.1kHz，去掉 metadata 和 chapters。仅做「源 → 指定输出」的纯转码，不负责
/// 删除源文件或落盘命名（由上层 [AudioFinalizationService] 编排），转码失败时
/// 删除半成品输出、保持源文件不动。
class AudioTranscodeService {
  static const _logTag = 'AudioTranscode';

  /// 把 [source] 转码为 m4a 写入 [output]。
  ///
  /// 成功返回 `true`；失败（ffmpeg 非零返回、抛异常或输出缺失）删除半成品
  /// [output]、返回 `false`，**不删除/不改动 [source]**。
  Future<bool> transcodeToFile({
    required File source,
    required File output,
  }) async {
    if (!await source.exists()) {
      AppLogger.log(_logTag, 'skip: source missing path=${source.path}');
      return false;
    }
    await output.parent.create(recursive: true);

    try {
      // 全局选项（-nostdin/-y/-loglevel）必须在 -i 之前；放到 output 之后部分
      // ffmpeg 版本会解析不到或当成下一个 output 的选项，行为不可靠。
      final session = await FFmpegKit.executeWithArguments([
        '-nostdin',
        '-y',
        '-loglevel',
        'error',
        '-i',
        source.path,
        '-map',
        '0:a:0',
        '-map_metadata',
        '-1',
        '-map_chapters',
        '-1',
        '-c:a',
        'aac',
        '-b:a',
        '64k',
        '-ac',
        '1',
        '-ar',
        '44100',
        output.path,
      ]);
      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode) || !await output.exists()) {
        final logs = await session.getOutput();
        AppLogger.log(
          _logTag,
          'failed: returnCode=$returnCode source=${p.basename(source.path)} output=${p.basename(output.path)} logs=${logs ?? ''}',
        );
        await _deleteIfExists(output);
        return false;
      }
      return true;
    } catch (error, stackTrace) {
      AppLogger.log(
        _logTag,
        'exception: source=${p.basename(source.path)} error=$error stack=$stackTrace',
      );
      await _deleteIfExists(output);
      return false;
    }
  }

  /// 把 [source] 解码为 16kHz / 单声道 / PCM16 的 WAV 写入 [output]。
  ///
  /// 供离线 ASR 转录使用：sherpa-onnx Whisper 需要 16kHz 单声道 PCM，
  /// 而库音频多为 m4a/mp3（`audio_file_reader` 只认 WAV/CAF），故先经 ffmpeg
  /// 解码为标准 WAV。成功返回 `true`；失败（ffmpeg 非零返回、抛异常或输出缺失）
  /// 删除半成品 [output]、返回 `false`，**不删除/不改动 [source]**。
  Future<bool> transcodeToPcmWav16k({
    required File source,
    required File output,
  }) async {
    if (!await source.exists()) {
      AppLogger.log(_logTag, 'skip wav16k: source missing path=${source.path}');
      return false;
    }
    await output.parent.create(recursive: true);

    try {
      // 全局选项须在 -i 之前（同 transcodeToFile）。-vn 丢弃视频轨，
      // -ac 1 单声道，-ar 16000 采样率，pcm_s16le 16-bit little-endian。
      final session = await FFmpegKit.executeWithArguments([
        '-nostdin',
        '-y',
        '-loglevel',
        'error',
        '-i',
        source.path,
        '-vn',
        '-map',
        '0:a:0',
        '-map_metadata',
        '-1',
        '-map_chapters',
        '-1',
        '-ac',
        '1',
        '-ar',
        '16000',
        '-c:a',
        'pcm_s16le',
        output.path,
      ]);
      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode) || !await output.exists()) {
        final logs = await session.getOutput();
        AppLogger.log(
          _logTag,
          'wav16k failed: returnCode=$returnCode source=${p.basename(source.path)} output=${p.basename(output.path)} logs=${logs ?? ''}',
        );
        await _deleteIfExists(output);
        return false;
      }
      return true;
    } catch (error, stackTrace) {
      AppLogger.log(
        _logTag,
        'wav16k exception: source=${p.basename(source.path)} error=$error stack=$stackTrace',
      );
      await _deleteIfExists(output);
      return false;
    }
  }

  Future<void> _deleteIfExists(File file) async {
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {}
  }
}
