import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:universal_io/io.dart';

import '../../services/app_logger.dart';

/// 音频转码结果。
///
/// [relativePath] 永远指向调用方后续应保存的沙盒音频路径；转码失败时回退为原始
/// [relativePath]，让导入流程继续可用。
class AudioTranscodeResult {
  const AudioTranscodeResult({
    required this.relativePath,
    required this.transcoded,
  });

  final String relativePath;
  final bool transcoded;
}

/// 用户音频统一转码服务。
///
/// 使用与 `~/bin/convert-to-m4a` 默认分支一致的参数：AAC 64k、单声道、
/// 44.1kHz，去掉 metadata 和 chapters。任何转码异常都会回退到原始音频。
class AudioTranscodeService {
  AudioTranscodeService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static const _logTag = 'AudioTranscode';

  final Uuid _uuid;

  Future<AudioTranscodeResult> transcodeToM4a({
    required Directory dataDir,
    required String relativePath,
  }) async {
    final source = File(p.join(dataDir.path, relativePath));
    if (!await source.exists()) {
      AppLogger.log(_logTag, 'skip: source missing path=$relativePath');
      return AudioTranscodeResult(
        relativePath: relativePath,
        transcoded: false,
      );
    }

    final sourceDir = p.dirname(source.path);
    final sourceBase = p.basenameWithoutExtension(source.path);
    final sourceExt = p.extension(source.path).toLowerCase();
    final desiredPath = p.join(sourceDir, '$sourceBase.m4a');
    final replacingSource = p.equals(source.path, desiredPath);
    final outputPath = replacingSource
        ? p.join(sourceDir, '$sourceBase-${_uuid.v4()}.m4a')
        : await _uniqueOutputPath(sourceDir, '$sourceBase.m4a');
    final output = File(outputPath);

    try {
      final session = await FFmpegKit.executeWithArguments([
        '-y',
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
        '-loglevel',
        'error',
        '-nostdin',
      ]);
      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode) || !await output.exists()) {
        final logs = await session.getOutput();
        AppLogger.log(
          _logTag,
          'failed: returnCode=$returnCode source=$relativePath output=${p.basename(output.path)} logs=${logs ?? ''}',
        );
        await _deleteIfExists(output);
        return AudioTranscodeResult(
          relativePath: relativePath,
          transcoded: false,
        );
      }

      if (replacingSource) {
        return _replaceSourceWithOutput(
          dataDir: dataDir,
          source: source,
          output: output,
          desiredPath: desiredPath,
        );
      } else if (sourceExt != '.m4a') {
        await _deleteIfExists(source);
      }

      return AudioTranscodeResult(
        relativePath: p.relative(output.path, from: dataDir.path),
        transcoded: true,
      );
    } catch (error, stackTrace) {
      AppLogger.log(
        _logTag,
        'exception: source=$relativePath error=$error stack=$stackTrace',
      );
      await _deleteIfExists(output);
      return AudioTranscodeResult(
        relativePath: relativePath,
        transcoded: false,
      );
    }
  }

  Future<String> _uniqueOutputPath(String dir, String requestedName) async {
    var candidate = p.join(dir, requestedName);
    if (!await File(candidate).exists()) return candidate;

    final base = p.basenameWithoutExtension(requestedName);
    final ext = p.extension(requestedName);
    for (var i = 0; i < 20; i++) {
      candidate = p.join(dir, '$base-${_uuid.v4().substring(0, 8)}$ext');
      if (!await File(candidate).exists()) return candidate;
    }
    return p.join(dir, '${_uuid.v4()}$ext');
  }

  /// 用备份文件替换同名 `.m4a`，避免输出落盘失败时先删掉用户原始音频。
  Future<AudioTranscodeResult> _replaceSourceWithOutput({
    required Directory dataDir,
    required File source,
    required File output,
    required String desiredPath,
  }) async {
    final sourceDir = p.dirname(source.path);
    final sourceBase = p.basenameWithoutExtension(source.path);
    final backupPath = p.join(
      sourceDir,
      '$sourceBase-${_uuid.v4()}.backup.m4a',
    );
    final backup = await source.rename(backupPath);
    try {
      await output.rename(desiredPath);
      await _deleteIfExists(backup);
      return AudioTranscodeResult(
        relativePath: p.relative(desiredPath, from: dataDir.path),
        transcoded: true,
      );
    } catch (error, stackTrace) {
      AppLogger.log(
        _logTag,
        'replace failed: source=${p.relative(source.path, from: dataDir.path)} error=$error stack=$stackTrace',
      );
      await _deleteIfExists(output);
      var fallbackPath = backup.path;
      if (!await source.exists() && await backup.exists()) {
        try {
          await backup.rename(source.path);
          fallbackPath = source.path;
        } catch (_) {
          fallbackPath = backup.path;
        }
      }
      return AudioTranscodeResult(
        relativePath: p.relative(fallbackPath, from: dataDir.path),
        transcoded: false,
      );
    }
  }

  Future<void> _deleteIfExists(File file) async {
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {}
  }
}
