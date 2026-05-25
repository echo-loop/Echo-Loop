/// Apple NLEmbedding 平台桥接，提供文本 embedding 计算能力。
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 文本 embedding 后端抽象接口（方便测试 mock）。
abstract class TextEmbeddingBackend {
  /// 当前平台是否支持 embedding 能力。
  bool get isSupported;

  /// 计算文本的 embedding 向量。
  ///
  /// 返回 [List<double>]，维度由平台 NLEmbedding 模型决定。
  /// 当平台不支持或计算失败时抛出 [TextEmbeddingPlatformException]。
  Future<List<double>> embed(String text);
}

/// 平台桥接异常。
class TextEmbeddingPlatformException implements Exception {
  /// 平台错误码。
  final String code;

  /// 错误消息。
  final String message;

  const TextEmbeddingPlatformException(this.code, this.message);

  @override
  String toString() => 'TextEmbeddingPlatformException($code, $message)';
}

/// 通过 MethodChannel 调用 Apple NLEmbedding 的实现。
class TextEmbeddingPlatform implements TextEmbeddingBackend {
  TextEmbeddingPlatform();

  static TextEmbeddingPlatform _instance = TextEmbeddingPlatform();
  static const MethodChannel _channel = MethodChannel(
    'top.echo-loop/text_embedding',
  );

  /// 全局单例。
  static TextEmbeddingPlatform get instance => _instance;

  /// 测试时替换单例。
  @visibleForTesting
  static TextEmbeddingPlatform replaceInstance(TextEmbeddingPlatform platform) {
    final old = _instance;
    _instance = platform;
    return old;
  }

  @override
  bool get isSupported => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  @override
  Future<List<double>> embed(String text) async {
    if (!isSupported) {
      throw const TextEmbeddingPlatformException(
        'notSupported',
        'Text embedding is only supported on iOS and macOS',
      );
    }
    try {
      final result = await _channel.invokeMethod<Object?>('embed', {
        'text': text,
      });
      if (result is List) {
        return result.cast<double>();
      }
      throw const TextEmbeddingPlatformException(
        'invalidResult',
        'Platform returned unexpected result type',
      );
    } on MissingPluginException {
      throw const TextEmbeddingPlatformException(
        'notAvailable',
        'Text embedding plugin is not registered on this platform',
      );
    } on PlatformException catch (e) {
      throw TextEmbeddingPlatformException(
        e.code,
        e.message ?? 'Unknown platform error',
      );
    }
  }
}
