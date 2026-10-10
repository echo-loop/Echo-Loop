/// 通用网页词典视图
///
/// 在内置 WebView 中显示某个网页词典（Cambridge / Oxford / Longman 等）的词条页。
/// 标准用法：以 `initialUrlRequest` 在组件创建时加载，加载期间用不透明遮罩盖住
/// 直到 onLoadStop 揭示；注入 CSS/JS 收敛页面 chrome 并自动接受 cookie。
/// 切源由父级以 `ValueKey(sourceId)` 触发整组件重建（全新 native view），
/// 故无旧页残留、无需手动 loadUrl/保活/启发式揭示。
/// 不支持 WebView 的平台（linux/windows）降级为「在浏览器中打开」。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../services/app_logger.dart';
import '../../theme/app_theme.dart';

/// 移动端 User-Agent：强制各词典站返回移动版页面（布局更紧凑、适合弹窗窄屏）。
/// 用 iPhone Safari UA，跨平台统一即可让响应式站点走移动布局。
const _mobileUserAgent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) '
    'Version/17.0 Mobile/15E148 Safari/604.1';

/// 默认通用注入：隐藏页眉/广告/cookie 横幅，并自动点掉 cookie 同意（OneTrust 等）
const _defaultTidyCss = '''
  header, nav, .hfl-h, #onetrust-consent-sdk, .cookie-banner,
  .ad_*, [id^="google_ads"], .bb, .footer, footer { display: none !important; }
  body { padding-top: 0 !important; }
''';
const _defaultAcceptCookieJs = '''
  (function(){
    var b = document.querySelector('#onetrust-accept-btn-handler')
         || document.querySelector('.cookie-accept');
    if (b) b.click();
  })();
''';

/// 网页词典 WebView 容器
class WebDictionaryView extends StatefulWidget {
  /// 来源源 id（仅用于错误兜底文案/语义；切源由父级 key 触发重建）
  final String sourceId;

  /// 待加载网页
  final Uri url;

  /// 可选：站点专用收敛 CSS（为 null 用通用默认）
  final String? tidyCss;

  /// 可选：站点专用 cookie 接受 JS（为 null 用通用默认）
  final String? acceptCookieJs;

  /// 可选：网页广告过滤器生成的原生规则。
  final List<ContentBlocker> contentBlockers;

  const WebDictionaryView({
    super.key,
    required this.sourceId,
    required this.url,
    this.tidyCss,
    this.acceptCookieJs,
    this.contentBlockers = const [],
  });

  @override
  State<WebDictionaryView> createState() => _WebDictionaryViewState();
}

class _WebDictionaryViewState extends State<WebDictionaryView> {
  InAppWebViewController? _controller;
  bool _loading = true;
  bool _error = false;

  /// 加载超时计时器（onLoadStop/onReceivedError 到达即取消）
  Timer? _timeoutTimer;

  /// 加载超时阈值：超时未完成即视作失败，展示重试
  static const _loadTimeout = Duration(seconds: 20);

  bool get _webViewSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    // initialUrlRequest 在组件创建时即开始加载，这里同步起超时兜底。
    _armTimeout();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _armTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_loadTimeout, () {
      if (mounted && _loading) {
        AppLogger.log(
          'WebDictionary',
          'load timeout source=${widget.sourceId} host=${widget.url.host}',
        );
        _onError();
      }
    });
  }

  /// 揭示页面（撤遮罩）：仅在 onLoadStop（页面真正完成、新页已绘制）调用，幂等。
  void _onReady() {
    // WebView 回调经 method channel 异步到达，弹窗关闭后仍可能触发，先校验 mounted。
    if (!mounted || !_loading) return;
    _timeoutTimer?.cancel();
    setState(() => _loading = false);
  }

  /// 标记加载失败：展示错误重试。
  void _onError() {
    if (!mounted) return;
    _timeoutTimer?.cancel();
    setState(() {
      _loading = false;
      _error = true;
    });
  }

  /// 重试：复位 loading 态、绕过缓存重新加载（失败响应可能被缓存）。
  /// iOS/macOS 用 cachePolicy 绕缓存，Android 先清缓存。
  Future<void> _retry() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    _armTimeout();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await InAppWebViewController.clearAllCache();
      if (!mounted) return;
    }
    await controller.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(widget.url.toString()),
        cachePolicy: URLRequestCachePolicy.RELOAD_IGNORING_LOCAL_CACHE_DATA,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_webViewSupported) return _unsupportedFallback(context);

    // 填满父级（词典弹窗内容区）给出的约束，随弹窗上拉一起放大。父级保证高度有界。
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.expand(
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url.toString())),
              // WebView 处在可拖拽的 modal 弹窗内：默认情况下竖向拖拽会被弹窗的
              // 拖拽手势（drag-to-dismiss）赢走，导致网页无法滚动、一拉就把弹窗拉走。
              // 显式给 WebView 注册竖向拖拽识别器，让其在手势竞技场中赢得竖向拖拽，
              // 网页内部滚动恢复正常。
              gestureRecognizers: {
                Factory<VerticalDragGestureRecognizer>(
                  VerticalDragGestureRecognizer.new,
                ),
              },
              initialSettings: InAppWebViewSettings(
                cacheEnabled: true,
                transparentBackground: true,
                contentBlockers: widget.contentBlockers,
                // 优先移动端布局：preferredContentMode 在 macOS 默认桌面、
                // 且部分词典站只按 UA 判定，故再显式注入移动端 UA 双保险。
                preferredContentMode: UserPreferredContentMode.MOBILE,
                userAgent: _mobileUserAgent,
              ),
              onWebViewCreated: (controller) => _controller = controller,
              onLoadStop: (controller, _) async {
                // 先注入收敛 CSS/接受 cookie，再揭示——撤遮罩时已是干净的新页。
                try {
                  await controller.injectCSSCode(
                    source: widget.tidyCss ?? _defaultTidyCss,
                  );
                  await controller.evaluateJavascript(
                    source: widget.acceptCookieJs ?? _defaultAcceptCookieJs,
                  );
                } catch (_) {
                  // 美化注入失败不影响阅读，忽略
                }
                _onReady();
              },
              // 仅首屏加载中、主框架、非「取消」类错误才算失败。
              // 已揭示（_loading=false）后忽略后台请求被取消/被新导航超越上报的
              // 主框架错误（常见 -999 cancelled），避免把已显示好的页面冲成失败。
              onReceivedError: (_, request, error) {
                if (!_loading) return;
                if (request.isForMainFrame != true) return;
                if (error.type == WebResourceErrorType.CANCELLED) return;
                AppLogger.log(
                  'WebDictionary',
                  'load error source=${widget.sourceId} '
                      'type=${error.type} host=${request.url.host} '
                      'description=${error.description}',
                );
                _onError();
              },
              onReceivedHttpError: (_, request, errorResponse) {
                if (request.isForMainFrame != true) return;
                AppLogger.log(
                  'WebDictionary',
                  'HTTP error source=${widget.sourceId} '
                      'status=${errorResponse.statusCode} '
                      'host=${request.url.host}',
                );
              },
            ),
            // 加载期间不透明遮罩 + 居中转圈：盖住未绘制的空白/上一帧，
            // onLoadStop 揭示时页面已绘制完成，无闪烁。
            if (_loading) _loadingOverlay(context),
            if (_error) _errorOverlay(context),
          ],
        ),
      ),
    );
  }

  /// 加载遮罩：不透明底 + 居中转圈 + 顶部细进度条
  Widget _loadingOverlay(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
              ),
            ),
            const Center(child: CircularProgressIndicator.adaptive()),
          ],
        ),
      ),
    );
  }

  Widget _errorOverlay(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Positioned.fill(
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error),
              const SizedBox(height: AppSpacing.s),
              Text(l10n.aiLoadFailed, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.s),
              TextButton(onPressed: _retry, child: Text(l10n.aiRetry)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unsupportedFallback(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
      child: Center(
        child: FilledButton.tonalIcon(
          onPressed: () =>
              launchUrl(widget.url, mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.open_in_browser),
          label: Text(l10n.dictCambridgeOpenInBrowser),
        ),
      ),
    );
  }
}
