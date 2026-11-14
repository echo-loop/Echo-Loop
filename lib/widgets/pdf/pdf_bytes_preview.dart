/// PDF 字节预览（学习材料与收藏导出共用）
///
/// 双指缩放由外层 [InteractiveViewer] 提供，内部是 `PdfPreview` 的懒加载列表，
/// 单指竖滑滚动文档。栅格化 DPI 为「适配屏宽」的 1.75 倍（上限 2800px 宽防内存暴涨）。
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// PDF 字节预览组件
class PdfBytesPreview extends StatefulWidget {
  /// 要预览的 PDF 字节
  final Uint8List bytes;

  const PdfBytesPreview({super.key, required this.bytes});

  @override
  State<PdfBytesPreview> createState() => _PdfBytesPreviewState();
}

class _PdfBytesPreviewState extends State<PdfBytesPreview> {
  /// 当前缓存的 build 回调对应的字节（identity 比较）
  Uint8List? _buildFnBytes;

  /// 稳定的 build 回调（仅在字节变化时重建）
  Future<Uint8List> Function(PdfPageFormat)? _buildFn;

  /// 返回绑定到 [Uint8List] 的稳定 build 回调。
  ///
  /// `PdfPreview.didUpdateWidget` 仅在 `build` 引用变化时重新栅格化；若每次
  /// 父级重建都传新闭包，会触发**重复栅格化**，而 printing 5.14.3 的重复栅格化
  /// 在 dispose 竞态下会抛 `RangeError`。同一字节保持同一引用可从根上避开。
  Future<Uint8List> Function(PdfPageFormat) _stableBuild(Uint8List bytes) {
    if (!identical(_buildFnBytes, bytes) || _buildFn == null) {
      _buildFnBytes = bytes;
      _buildFn = (_) async => bytes;
    }
    return _buildFn!;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final targetPixelWidth = math.min(
      mq.size.width * mq.devicePixelRatio * 1.75,
      2800.0,
    );
    final dpi = targetPixelWidth / PdfPageFormat.a4.width * PdfPageFormat.inch;
    return InteractiveViewer(
      maxScale: 4,
      child: PdfPreview(
        // key 绑定字节：字节变化即全新 PdfPreview，pages 从空开始
        key: ValueKey(widget.bytes),
        build: _stableBuild(widget.bytes),
        useActions: false,
        allowPrinting: false,
        allowSharing: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        dpi: dpi,
        padding: EdgeInsets.zero,
        previewPageMargin: EdgeInsets.zero,
        scrollViewDecoration: const BoxDecoration(color: Colors.white),
        pdfPreviewPageDecoration: const BoxDecoration(color: Colors.white),
      ),
    );
  }
}
