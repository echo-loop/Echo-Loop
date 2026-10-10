/// 网页词典使用的常见广告拦截规则。
library;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 广告网络候选域名，尽量只列广告服务主机，不拦截百度、阿里、Google 等整站。
const _adDomains = <String>[
  // Google 广告
  'doubleclick.net',
  'googlesyndication.com',
  'googleadservices.com',
  'adservice.google.com',
  'admob.com',
  'imasdk.googleapis.com',

  // 国际广告网络
  'adnxs.com',
  'adsrvr.org',
  'adform.net',
  'pubmatic.com',
  'rubiconproject.com',
  'openx.net',
  'casalemedia.com',
  'contextweb.com',
  'bidswitch.net',
  'smartadserver.com',
  'lijit.com',
  'sovrn.com',
  'triplelift.com',
  'sharethrough.com',
  'indexww.com',
  'yieldmo.com',
  '33across.com',
  'media.net',
  'criteo.com',
  'criteo.net',
  'taboola.com',
  'outbrain.com',
  'teads.tv',
  'zedo.com',
  'adsafeprotected.com',
  'quantserve.com',
  'adroll.com',
  'serving-sys.com',
  'advertising.com',
  'revcontent.com',
  'mgid.com',
  'propellerads.com',
  'popads.net',
  'exoclick.com',

  // 百度广告专用子域名
  'cb.baidu.com',
  'cbjs.baidu.com',
  'cpro.baidu.com',
  'cpro.baidustatic.com',
  'drmcmm.baidu.com',
  'mobads.baidu.com',
  'pos.baidu.com',
  'spcode.baidu.com',
  'eclick.baidu.com',
  'dup.baidustatic.com',
  'hmma.baidu.com',

  // 阿里及中国常见广告服务
  'tanx.com',
  'atanx.alicdn.com',
  'alimama.alicdn.com',
  'adsage.com',
  'mediav.com',
  'dlads.cn',
  'pagechoice.net',
  'allyes.com',
  'allyes.cn',
  'admaster.com.cn',
  'miaozhen.com',
  'ipinyou.com',
  'adwo.com',
  'domob.cn',
  'youmi.net',
  'inmobi.cn',
  'adview.cn',
];

/// 仅匹配明确的广告路径，并限制在第三方资源请求上。
const _thirdPartyAdPaths = <String>[
  r'/pagead/',
  r'/gampad/',
  r'/adsbygoogle\.js(?:[?#]|$)',
  r'/show_ads\.js(?:[?#]|$)',
  r'/adserver/',
  r'/adserving/',
  r'/ad-delivery/',
];

/// 广告请求可能是脚本、图片、视频或无明确类型的 fetch 请求。
const _adResourceTypes = <ContentBlockerTriggerResourceType>[
  ContentBlockerTriggerResourceType.SCRIPT,
  ContentBlockerTriggerResourceType.IMAGE,
  ContentBlockerTriggerResourceType.STYLE_SHEET,
  ContentBlockerTriggerResourceType.MEDIA,
  ContentBlockerTriggerResourceType.RAW,
];

/// 只隐藏具有明确广告语义的页面元素，避免使用 `.ad`、`.banner` 等宽泛规则。
const _adSelectors = <String>[
  // 标准广告类名
  '.adsbygoogle',
  '.adsense',
  '.ad-banner',
  '.ad-container',
  '.ad-wrapper',
  '.ad-slot',
  '.ad-unit',
  '.ad-box',
  '.ad-placeholder',
  '.ad-placement',
  '.ad-widget',
  '.ad-block',
  '.ad-holder',
  '.ad-frame',
  '.ad-label',
  '.ad-content',
  '.ad-area',
  '.ad-section',
  '.ad-sidebar',

  // 常见广告类名格式
  '[class^="ad_"]',
  '[class^="ads_"]',
  '[class^="ad-"]',
  '[class^="ads-"]',
  '[class*=" ad-"]',
  '[class*=" ads-"]',
  '[class*=" ad_"]',
  '[class*=" ads_"]',
  '[class*="advertisement"]',
  '[class*="ad-container"]',
  '[class*="ad-slot"]',
  '[class*="ad-banner"]',
  '[class*="adsense"]',

  // 常见广告 ID
  '#ads',
  '#ad-container',
  '#ad-banner',
  '#ad-wrapper',
  '#ad-slot',
  '#google_ads',
  '[id^="google_ads_"]',
  '[id^="div-gpt-ad"]',
  '[id^="ad_"]',
  '[id^="ads_"]',
  '[id^="ad-"]',
  '[id^="ads-"]',
  '[id*="ad-container"]',
  '[id*="ad-banner"]',

  // Google 等广告 iframe
  'iframe[id^="google_ads_iframe"]',
  'iframe[title="3rd party ad content"]',
  'iframe[src*="doubleclick.net"]',
  'iframe[src*="googlesyndication.com"]',

  // 赞助与推广广告
  '.sponsored-ad',
  '.sponsored-ads',
  '.sponsored-banner',
  '.sponsored-content',
  '.sponsored-widget',
  '.sponsor-ad',
  '.sponsor-banner',
  '.sponsor-content',
  '.promotion-ad',
  '.promotion-banner',
  '.promotion-content',
  '.promoted-ad',
  '.promoted-content',
  '[class*="sponsored-ad"]',
  '[class*="sponsor-ad"]',
  '[class*="promotion-ad"]',
  '[class*="promoted-ad"]',

  // 中文广告容器
  '.guanggao',
  '.guanggao-box',
  '.gg-banner',
  '.gg-box',
  '.gg-container',
  '.gg-ad',
  '.baidu-ad',
  '.baidu-ads',
  '.bd-ad',
  '.bd-ads',
  '.cpro-ad',
  '.cpro-ads',
  '[class*="guanggao"]',
  '[id*="guanggao"]',

  // 广告区域语义标记
  '[data-ad-slot]',
  '[data-ad-client]',
  '[data-ad-unit]',
  '[data-advertisement]',
  '[aria-label="Advertisement"]',
  '[aria-label="广告"]',
];

/// 将广告域名转换为完整 URL 正则，并检查主机名边界。
String _domainUrlPattern(String domain) {
  final escapedDomain = RegExp.escape(domain);
  return r'^https?://([a-z0-9-]+\.)*' +
      escapedDomain +
      r'(?::[0-9]+)?(?:[/?#].*)?$';
}

/// URL 正则需要覆盖完整请求地址，因此将资源路径包在通配前后。
String _thirdPartyPathUrlPattern(String pathPattern) => '.*$pathPattern.*';

/// WebView 可直接使用的三层通用广告过滤规则。
final List<ContentBlocker> webDictionaryCommonAdBlockers =
    List<ContentBlocker>.unmodifiable([
      // 第一层：拦截已知广告域名。
      for (final domain in _adDomains)
        ContentBlocker(
          trigger: ContentBlockerTrigger(urlFilter: _domainUrlPattern(domain)),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ),

      // 第二层：拦截第三方广告资源路径，不处理主文档。
      for (final pathPattern in _thirdPartyAdPaths)
        ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter: _thirdPartyPathUrlPattern(pathPattern),
            loadType: [ContentBlockerTriggerLoadType.THIRD_PARTY],
            resourceType: _adResourceTypes,
          ),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ),

      // 第三层：隐藏页面中可通过语义识别的广告容器。
      ContentBlocker(
        trigger: ContentBlockerTrigger(urlFilter: '.*'),
        action: ContentBlockerAction(
          type: ContentBlockerActionType.CSS_DISPLAY_NONE,
          selector: _adSelectors.join(', '),
        ),
      ),
    ]);
