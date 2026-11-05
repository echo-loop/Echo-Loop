/// 学习材料 PDF 导出预览页
///
/// 从音频列表菜单「导出 PDF」进入：加载完整文档一次 → 按内容选项
/// （译文 / 单词释义 / 句子讲解，默认全选）过滤后生成 PDF 字节 →
/// `PdfPreview` 栅格化预览。顶栏三个动作：下载（另存为）、分享（系统
/// 分享面板）、菜单（勾选内容选项，切换后预览快速刷新）。
///
/// 生成的字节按选项组合缓存（最多 8 种），预览 / 下载 / 分享共用同一份。
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';

import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../models/audio_item.dart';
import '../models/pdf_export/study_pdf_data.dart';
import '../models/pdf_export/study_pdf_options.dart';
import '../providers/dictionary/dictionary_registry.dart';
import '../providers/learning_settings_provider.dart';
import '../providers/settings_provider.dart';
import '../services/app_logger.dart';
import '../services/audio_export_service.dart';
import '../services/pdf_export/study_pdf_export_service.dart';
import '../services/pdf_export/study_pdf_loader.dart';
import '../widgets/common/anchored_bubble.dart';

/// 预览区构造器（测试注入缝：`PdfPreview` 走 method channel，widget 测试
/// 中会 MissingPluginException，注入替身即可绕开）
typedef PdfPreviewBuilder =
    Widget Function(BuildContext context, Uint8List bytes, int optionsBitmask);

/// 学习材料 PDF 导出预览页
class PdfPreviewScreen extends ConsumerStatefulWidget {
  /// 要导出的音频
  final AudioItem audioItem;

  /// 数据加载器（测试注入；为 null 时按 DAO provider 组装）
  final StudyPdfLoader? loader;

  /// 导出服务（测试注入；为 null 时新建）
  final StudyPdfExportService? exportService;

  /// 预览区构造器（测试注入；为 null 时用 [PdfPreview]）
  final PdfPreviewBuilder? previewBuilder;

  const PdfPreviewScreen({
    super.key,
    required this.audioItem,
    this.loader,
    this.exportService,
    this.previewBuilder,
  });

  @override
  ConsumerState<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends ConsumerState<PdfPreviewScreen> {
  late final StudyPdfLoader _loader;
  late final StudyPdfExportService _exportService;

  /// 加载一次的完整文档（选项过滤在此基础上做纯变换）
  StudyPdfDocument? _document;

  /// 当前内容选项（默认全选）
  StudyPdfExportOptions _options = const StudyPdfExportOptions();

  /// 已生成字节缓存：选项位掩码 → PDF 字节（最多 8 种组合）
  final Map<int, Uint8List> _bytesCache = {};

  /// 当前预览/下载/分享用的字节
  Uint8List? _currentBytes;

  /// 是否正在生成（预览区盖半透明 loading）
  bool _generating = false;

  /// 加载/生成失败信息（非 null 时显示错误态 + 重试）
  Object? _error;

  /// 生成代际：切换选项/重试时递增，过期回调只入缓存、不改界面状态
  int _generation = 0;

  /// 内容选项气泡菜单显隐控制器
  final OverlayPortalController _menuController = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _loader =
        widget.loader ??
        StudyPdfLoader(
          audioItemDao: ref.read(audioItemDaoProvider),
          bookmarkDao: ref.read(bookmarkDaoProvider),
          savedWordDao: ref.read(savedWordDaoProvider),
          savedSenseGroupDao: ref.read(savedSenseGroupDaoProvider),
          aiCacheDao: ref.read(sentenceAiCacheDaoProvider),
          localDictLookup: ref.read(dictionaryServiceProvider).lookupAll,
        );
    _exportService = widget.exportService ?? StudyPdfExportService();
    // 推迟到进场转场动画结束再启动加载：加载会连续 spawn 若干 isolate 并
    // 序列化大对象（字幕解析 / 逐句组装 / PDF 生成），在转场动画期间抢占
    // 主 isolate 会让转场和 loading 动画掉帧。等页面稳定后再开工。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _awaitEntranceTransition();
      if (!mounted) return;
      await _maybeShowExportReminder();
      if (!mounted) return;
      unawaited(_loadAndGenerate());
    });
  }

  /// 首次进入导出预览时提醒：PDF 是首次学习的补充复习材料。
  ///
  /// 仅在从未提示过时弹出一次；点「知道了」后标记，永不再弹。提醒不阻断导出，
  /// 关闭后照常继续加载生成。
  Future<void> _maybeShowExportReminder() async {
    if (ref.read(learningSettingsProvider).pdfExportReminderShown || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.pdfExportReminderTitle),
        content: Text(l10n.pdfExportReminderMessage),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.pdfExportReminderConfirm),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await ref
        .read(learningSettingsProvider.notifier)
        .markPdfExportReminderShown();
  }

  /// 等待进场路由转场动画结束（无动画 / 已完成 / 被中断时立即返回）
  Future<void> _awaitEntranceTransition() {
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) return Future<void>.value();
    final completer = Completer<void>();
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        animation.removeStatusListener(listener);
        if (!completer.isCompleted) completer.complete();
      }
    }

    animation.addStatusListener(listener);
    return completer.future;
  }

  /// 加载文档（仅首次）并按当前选项生成字节
  Future<void> _loadAndGenerate() async {
    final generation = ++_generation;
    // 用户感知的端到端耗时：进预览页 → 首张图可见（数据加载 + 首次生成）
    final total = Stopwatch()..start();
    setState(() {
      _error = null;
      _generating = true;
    });
    try {
      final targetLanguage = ref.read(
        appSettingsProvider.select((s) => s.nativeLanguage),
      );
      _document ??= await _loader.load(
        widget.audioItem.id,
        targetLanguage: targetLanguage,
      );
      if (!mounted) return;
      await _generate(generation);
      AppLogger.log('PdfExport', '端到端总耗时 ${total.elapsedMilliseconds}ms');
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _generating = false;
      });
    }
  }

  /// 按当前选项生成（或取缓存）PDF 字节
  ///
  /// [generation] 过期时结果只入缓存、不改界面（防旧回调覆盖新选项的预览）。
  Future<void> _generate(int generation) async {
    final document = _document;
    if (document == null) return;
    final options = _options;

    final cached = _bytesCache[options.bitmask];
    if (cached != null) {
      if (generation != _generation) return;
      setState(() {
        _currentBytes = cached;
        _generating = false;
      });
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final labels = StudyPdfLabels(
      metaDuration: l10n.pdfMetaDuration(
        formatStudyPdfDuration(document.durationSeconds),
      ),
      metaSentences: l10n.pdfMetaSentences(document.sentenceCount),
      metaWords: l10n.pdfMetaWords(document.wordCount),
      appendixTitle: l10n.pdfAppendixTitle,
      grammar: l10n.aiGrammar,
      vocabulary: l10n.aiVocabulary,
      listening: l10n.aiListening,
    );

    final filtered = applyStudyPdfOptions(document, options);
    final bytes = await _exportService.buildBytes(filtered, labels: labels);
    _bytesCache[options.bitmask] = bytes;

    if (!mounted || generation != _generation) return;
    setState(() {
      _currentBytes = bytes;
      _generating = false;
    });
  }

  /// 切换内容选项：命中缓存秒回，否则重新生成
  void _setOptions(StudyPdfExportOptions next) {
    if (next == _options) return;
    final generation = ++_generation;
    setState(() {
      _options = next;
      _generating = true;
      _error = null;
    });
    unawaited(
      _generate(generation).catchError((Object e) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _error = e;
          _generating = false;
        });
      }),
    );
  }

  /// 下载：移动端走系统「存储到文件」（file_picker 直接写 bytes），
  /// 桌面端另存为对话框后自行写文件
  Future<void> _download() async {
    final bytes = _currentBytes;
    final document = _document;
    if (bytes == null || document == null) return;
    final l10n = AppLocalizations.of(context)!;

    final safeName = AudioExportService().sanitizeFileName(document.title);
    try {
      final isMobile = Platform.isIOS || Platform.isAndroid;
      final home = Platform.environment['HOME'];
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.exportPdf,
        fileName: '$safeName.pdf',
        bytes: bytes,
        initialDirectory: !isMobile && home != null ? '$home/Downloads' : null,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (savePath == null) return; // 用户取消
      if (!isMobile) {
        // 桌面端 saveFile 只返回路径，不写内容
        await File(savePath).writeAsBytes(bytes);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.exportSuccess)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.pdfExportFailed('$e'))));
    }
  }

  /// 分享：写临时文件 → 系统分享面板
  ///
  /// 分享后**不能**立即删除临时文件：macOS 的 `shareXFiles` 在用户
  /// 点选分享目标（如 AirDrop）时就 resolve，传输尚未开始，此时删文件
  /// 会让 AirDrop 永远卡在 Waiting。临时目录前缀 `pdf_export_` 已在
  /// temp_cleanup_service 白名单内，交由「清除缓存」统一回收。
  Future<void> _share() async {
    final bytes = _currentBytes;
    final document = _document;
    if (bytes == null || document == null) return;
    final l10n = AppLocalizations.of(context)!;

    try {
      final pdfPath = await _exportService.writeTempPdf(bytes, document.title);
      if (!mounted) return;
      // iPad 弹出框 / macOS 分享 popover 需要锚点位置
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(pdfPath, mimeType: 'application/pdf')],
        // subject 决定 iOS 分享面板 LinkPresentation 卡片的标题（不传则
        // metadata.title 为 nil，卡片只剩「PDF · 71 KB」副标题、无文件名）
        subject: document.title,
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : Rect.zero,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.pdfExportFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasBytes = _currentBytes != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pdfPreviewTitle),
        actions: [
          // 细线 iOS 风格图标，统一 21dp 视觉重量
          IconButton(
            icon: const Icon(CupertinoIcons.arrow_down_to_line, size: 21),
            tooltip: l10n.download,
            onPressed: hasBytes ? () => unawaited(_download()) : null,
          ),
          IconButton(
            // Apple 平台用 iOS 风格分享图标，其余平台用 Material 标准分享图标
            icon: Icon(
              Platform.isIOS || Platform.isMacOS
                  ? CupertinoIcons.share
                  : Icons.share_outlined,
              size: 21,
            ),
            tooltip: l10n.pdfShare,
            onPressed: hasBytes ? () => unawaited(_share()) : null,
          ),
          _buildOptionsMenu(l10n),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  /// 内容选项菜单：锚定按钮下方的气泡浮层（带指向按钮的小箭头），
  /// 与睡眠定时器等浮层共用 [AnchoredBubble] 视觉骨架。
  ///
  /// 勾选项点选即切换并刷新预览，浮层保持打开方便连续调整多个选项，
  /// 点浮层外关闭。
  Widget _buildOptionsMenu(AppLocalizations l10n) {
    return AnchoredBubble(
      controller: _menuController,
      direction: BubbleDirection.down,
      // 以最长的英文文案「Sentence Analysis」+ 行尾打勾为准，再窄会换行
      width: 168,
      contentBuilder: (_) => _buildOptionsMenuContent(l10n),
      child: IconButton(
        icon: const Icon(CupertinoIcons.ellipsis, size: 21),
        onPressed: _document != null ? _menuController.toggle : null,
      ),
    );
  }

  /// 气泡浮层内容：三个可勾选内容选项，选中行尾打勾
  Widget _buildOptionsMenuContent(AppLocalizations l10n) {
    final theme = Theme.of(context);

    Widget row({
      required String label,
      required bool checked,
      required VoidCallback onTap,
    }) {
      // 文字保持默认样式（不随选中变色/加粗），选中态只用行尾打勾表达
      return BubbleMenuRow(
        label: label,
        trailing: checked
            ? Icon(Icons.check, size: 18, color: theme.colorScheme.primary)
            : null,
        onTap: onTap,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            label: l10n.pdfOptionTranslation,
            checked: _options.includeTranslation,
            onTap: () => _setOptions(
              _options.copyWith(
                includeTranslation: !_options.includeTranslation,
              ),
            ),
          ),
          row(
            label: l10n.pdfOptionAnalysis,
            checked: _options.includeAnalysis,
            onTap: () => _setOptions(
              _options.copyWith(includeAnalysis: !_options.includeAnalysis),
            ),
          ),
          row(
            label: l10n.pdfOptionVocab,
            checked: _options.includeVocabNotes,
            onTap: () => _setOptions(
              _options.copyWith(includeVocabNotes: !_options.includeVocabNotes),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final error = _error;
    if (error != null) {
      // 错误态 + 重试
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
              onPressed: () => unawaited(_loadAndGenerate()),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    final bytes = _currentBytes;
    if (bytes == null) {
      // 首次加载/生成中
      return const Center(child: CircularProgressIndicator());
    }

    // 预览 + 重新生成时的半透明遮罩
    return Stack(
      children: [
        Positioned.fill(child: _buildPreview(bytes)),
        if (_generating)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  /// 预览区：默认 `PdfPreview`（关掉其自带工具栏，动作全在 AppBar）
  ///
  /// 连续阅读模式：页面占满屏宽、页间零间隔、去掉纸张阴影，
  /// 滚动背景与纸面同为白色，视觉上呈现为一篇连续文档。
  ///
  /// 双指缩放：外层 [InteractiveViewer] 提供捏合缩放/平移；内部
  /// 仍是 `PdfPreview` 的懒加载 ListView，单指竖滑滚动文档。
  /// 栅格化 DPI 提高到「适配屏宽」的 1.75 倍（上限 2800px 宽防止
  /// 大屏内存暴涨），放大后文字仍清晰。
  ///
  /// key 与 build 回调都绑定到**字节对象本身**，两点缺一不可：
  /// - `key: ValueKey(bytes)`：字节变即全新 `PdfPreview`（pages 从空开始，
  ///   只走「新增页」分支）；
  /// - `build` 回调按字节缓存、跨重建保持同一引用：`PdfPreview.didUpdateWidget`
  ///   仅在 `build` 引用变化时重新栅格化，若每次都传新闭包 `(_) async => bytes`，
  ///   父级任意重建都会触发**重复栅格化**，而 printing 5.14.3 的重复栅格化在
  ///   dispose 竞态下会抛 `RangeError`（pages 被清空后仍按旧下标赋值）。
  ///   稳定引用后同一字节永不重复栅格化，从根上避开该分支。
  Widget _buildPreview(Uint8List bytes) {
    final builder = widget.previewBuilder;
    if (builder != null) {
      return builder(context, bytes, _options.bitmask);
    }
    final mq = MediaQuery.of(context);
    final targetPixelWidth = math.min(
      mq.size.width * mq.devicePixelRatio * 1.75,
      2800.0,
    );
    final dpi = targetPixelWidth / PdfPageFormat.a4.width * PdfPageFormat.inch;
    return InteractiveViewer(
      maxScale: 4,
      child: PdfPreview(
        key: ValueKey(bytes),
        build: _stableBuildFor(bytes),
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

  /// 当前缓存的 build 回调对应的字节（identity 比较）
  Uint8List? _buildFnBytes;

  /// 稳定的 build 回调（仅在字节变化时重建，见 [_buildPreview] 说明）
  Future<Uint8List> Function(PdfPageFormat)? _buildFn;

  /// 返回绑定到 [bytes] 的稳定 build 回调：同一字节对象跨重建返回同一引用，
  /// 使 `PdfPreview` 不因父级重建而重复栅格化。
  Future<Uint8List> Function(PdfPageFormat) _stableBuildFor(Uint8List bytes) {
    if (!identical(_buildFnBytes, bytes) || _buildFn == null) {
      _buildFnBytes = bytes;
      _buildFn = (_) async => bytes;
    }
    return _buildFn!;
  }
}
