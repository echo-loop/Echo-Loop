/// 收藏导出预览页
///
/// 从收藏页「导出」进入：按选项只读加载本地数据并生成 PDF，再用 [PdfBytesPreview] 预览。
/// 顶栏下载（另存为）与分享，与学习材料预览页共用同一套保存 / 分享实现。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';

import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../models/favorites_export/favorites_export_data.dart';
import '../models/favorites_export/favorites_export_options.dart';
import '../providers/dictionary/dictionary_registry.dart';
import '../providers/settings_provider.dart';
import '../services/favorites_export/favorites_export_loader.dart';
import '../services/favorites_export/favorites_export_service.dart';
import '../services/favorites_export/favorites_pdf_builder.dart';
import '../services/pdf_export/common/pdf_document_shell.dart';
import '../services/pdf_export/common/pdf_file_actions.dart';
import '../utils/route_entrance_transition.dart';
import '../widgets/pdf/pdf_bytes_preview.dart';

/// 预览区构造器（测试注入缝：`PdfPreview` 走 method channel，widget 测试中需替身）
typedef FavoritesPreviewBuilder = Widget Function(
  BuildContext context,
  Uint8List bytes,
);

/// 收藏导出预览页
class FavoritesExportPreviewScreen extends ConsumerStatefulWidget {
  /// 导出入参（内容选项 + 格式）
  final FavoritesExportRequest request;

  /// 导出服务（测试注入；为 null 时按 DAO / 词典 provider 组装）
  final FavoritesExportService? service;

  /// 预览区构造器（测试注入；为 null 时用 [PdfBytesPreview]）
  final FavoritesPreviewBuilder? previewBuilder;

  const FavoritesExportPreviewScreen({
    super.key,
    required this.request,
    this.service,
    this.previewBuilder,
  });

  @override
  ConsumerState<FavoritesExportPreviewScreen> createState() =>
      _FavoritesExportPreviewScreenState();
}

class _FavoritesExportPreviewScreenState
    extends ConsumerState<FavoritesExportPreviewScreen> {
  late final FavoritesExportService _service;

  /// 生成好的 PDF 字节（下载 / 分享 / 预览共用）
  Uint8List? _bytes;

  /// 生成失败信息（非 null 时显示错误态 + 重试）
  Object? _error;

  /// 生成代际：重试时递增，过期结果不覆盖新状态
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? _createService();
    // 等进场转场结束再开工，避免与路由动画抢主 isolate
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await awaitRouteEntranceTransition(context);
      if (!mounted) return;
      unawaited(_generate());
    });
  }

  /// 按 DAO 与只读缓存函数组装服务（缓存读取全部不发网络请求）
  FavoritesExportService _createService() {
    final aiSource = ref.read(aiDictionarySourceProvider);
    final dictionaryService = ref.read(dictionaryServiceProvider);
    return FavoritesExportService(
      loader: FavoritesExportLoader(
        audioItemDao: ref.read(audioItemDaoProvider),
        bookmarkDao: ref.read(bookmarkDaoProvider),
        savedWordDao: ref.read(savedWordDaoProvider),
        savedSenseGroupDao: ref.read(savedSenseGroupDaoProvider),
        aiCacheDao: ref.read(sentenceAiCacheDaoProvider),
        readAiEntry: (word, {required targetLanguage}) =>
            aiSource.readCachedEntry(word, targetLanguage: targetLanguage),
        readLocalDict: dictionaryService.readCachedAll,
      ),
    );
  }

  Future<void> _generate() async {
    final generation = ++_generation;
    final l10n = AppLocalizations.of(context)!;
    final targetLanguage = ref.read(
      appSettingsProvider.select((s) => s.nativeLanguage),
    );
    setState(() {
      _error = null;
      _bytes = null;
    });
    try {
      final bytes = await _service.export(
        options: widget.request.options,
        format: widget.request.format,
        targetLanguage: targetLanguage,
        buildLabels: (document) => _labelsFor(l10n, document),
      );
      if (!mounted || generation != _generation) return;
      setState(() => _bytes = bytes);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = e);
    }
  }

  /// PDF 内文案（isolate 内拿不到 l10n，在主 isolate 组装）
  FavoritesExportLabels _labelsFor(
    AppLocalizations l10n,
    FavoritesExportDocument document,
  ) {
    return FavoritesExportLabels(
      title: l10n.favoritesExportTitle,
      sentencesSection: l10n.favoritesExportSentencesSection,
      wordsSection: l10n.favoritesExportWordsSection,
      unknownSource: l10n.favoritesExportUnknownSource,
      metaSentences: l10n.pdfMetaSentences(document.sentenceCount),
      metaWords: l10n.pdfMetaWords(document.vocabularyCount),
    );
  }

  /// 文件名与分享标题：「Echo Loop 收藏导出 yyyy-MM-dd」
  String _documentTitle(AppLocalizations l10n) =>
      'Echo Loop ${l10n.favoritesExportTitle} ${pdfDateText(DateTime.now())}';

  Future<void> _download(AppLocalizations l10n) async {
    final bytes = _bytes;
    if (bytes == null) return;
    try {
      final saved = await savePdfBytes(
        bytes: bytes,
        title: _documentTitle(l10n),
        dialogTitle: l10n.exportPdf,
      );
      if (!saved || !mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.exportSuccess)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.pdfExportFailed('$e'))));
    }
  }

  Future<void> _share(AppLocalizations l10n) async {
    final bytes = _bytes;
    if (bytes == null) return;
    try {
      // iPad 弹出框 / macOS 分享 popover 需要锚点位置
      final box = context.findRenderObject() as RenderBox?;
      await sharePdfBytes(
        bytes: bytes,
        title: _documentTitle(l10n),
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : Rect.zero,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.pdfExportFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasBytes = _bytes != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pdfPreviewTitle),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.arrow_down_to_line, size: 21),
            tooltip: l10n.download,
            onPressed: hasBytes ? () => unawaited(_download(l10n)) : null,
          ),
          IconButton(
            icon: Icon(
              Platform.isIOS || Platform.isMacOS
                  ? CupertinoIcons.share
                  : Icons.share_outlined,
              size: 21,
            ),
            tooltip: l10n.pdfShare,
            onPressed: hasBytes ? () => unawaited(_share(l10n)) : null,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final error = _error;
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                l10n.pdfExportFailed('$error'),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => unawaited(_generate()),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    final bytes = _bytes;
    if (bytes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final builder = widget.previewBuilder;
    return builder != null
        ? builder(context, bytes)
        : PdfBytesPreview(bytes: bytes);
  }
}
