/// PDF 渲染资源：字体与品牌图标的原始字节
///
/// 字节可跨 isolate 传递（compute 入参），因此渲染端只依赖本类，
/// 不直接读 assets。加载见 [PdfAssetsLoader]（只能在主 isolate 调用）。
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../../app_logger.dart';

/// 字体与图标字节（不可变）
class PdfAssets {
  /// 英文正文字体（NotoSans-Regular，TrueType）
  final Uint8List latinRegular;

  /// 英文粗体字体（NotoSans-Bold）
  final Uint8List latinBold;

  /// 英文斜体字体（NotoSans-Italic）
  final Uint8List latinItalic;

  /// CJK 回退字体（NotoSansSC-Regular）
  final Uint8List cjkRegular;

  /// 应用图标 PNG（品牌角标用；null 时只渲染品牌文字）
  final Uint8List? appIconPng;

  const PdfAssets({
    required this.latinRegular,
    required this.latinBold,
    required this.latinItalic,
    required this.cjkRegular,
    this.appIconPng,
  });
}

/// 从 rootBundle 读取 [PdfAssets]，会话内缓存（同会话多次导出免重读约 12MB 字体）
class PdfAssetsLoader {
  static PdfAssets? _cache;

  /// 读取资源；字体缺失视为构建错误直接抛出，图标缺失降级为纯文字角标
  Future<PdfAssets> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final sw = Stopwatch()..start();
    final assets = PdfAssets(
      latinRegular: await _loadAsset('assets/fonts/pdf/NotoSans-Regular.ttf'),
      latinBold: await _loadAsset('assets/fonts/pdf/NotoSans-Bold.ttf'),
      latinItalic: await _loadAsset('assets/fonts/pdf/NotoSans-Italic.ttf'),
      cjkRegular: await _loadAsset('assets/fonts/pdf/NotoSansSC-Regular.ttf'),
      appIconPng: await _loadOptionalAsset('assets/icon/app-icon-96.png'),
    );
    AppLogger.log('PdfExport', '读字体 ${sw.elapsedMilliseconds}ms (首次读 assets)');
    _cache = assets;
    return assets;
  }

  Future<Uint8List> _loadAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return Uint8List.sublistView(data);
  }

  /// 品牌图标仅为装饰：加载失败（如旧构建未含该 asset）降级为 null，不让导出失败
  Future<Uint8List?> _loadOptionalAsset(String assetPath) async {
    try {
      return await _loadAsset(assetPath);
    } catch (_) {
      return null;
    }
  }
}
