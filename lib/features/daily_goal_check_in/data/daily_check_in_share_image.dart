import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/app_logger.dart';

import '../domain/share_card_template.dart';
import 'daily_share_decoded_image_cache.dart';

class DailyCheckInShareData {
  const DailyCheckInShareData({
    required this.date,
    required this.totalSeconds,
    required this.inputSeconds,
    required this.outputSeconds,
    required this.streak,
    required this.isChinese,
    required this.nativeLanguage,
    this.nickname,
  });

  final DateTime date;
  final int totalSeconds;
  final int inputSeconds;
  final int outputSeconds;
  final int streak;
  final bool isChinese;
  final String nativeLanguage;
  final String? nickname;
}

class DailyCheckInShareAssets {
  const DailyCheckInShareAssets({
    required this.background,
    required this.logo,
    required this.qrCode,
    this.avatar,
  });
  final Uint8List background;
  final Uint8List logo;
  final Uint8List qrCode;
  final Uint8List? avatar;
}

/// PNG 与已栅格化的预览共享同一结果；克隆让弹窗拥有独立的图像生命周期。
class GeneratedDailyCheckInShareImage {
  const GeneratedDailyCheckInShareImage(this.pngBytes, this.preview);
  final Uint8List pngBytes;
  final ui.Image preview;

  GeneratedDailyCheckInShareImage clone() =>
      GeneratedDailyCheckInShareImage(pngBytes, preview.clone());
  void dispose() => preview.dispose();
}

/// 缓存比较与卡片绘制共用分钟口径，避免秒数变化触发无效重绘。
int dailyShareDisplayMinutes(int seconds) => (math.max(0, seconds) / 60).ceil();

String dailyShareQrAsset(bool isChinaUser) =>
    'assets/qr/www.echo-loop.${isChinaUser ? 'cn' : 'top'}.png';

/// 字体加载由资源边界负责，避免每次换卡都重新注册字体。
class DailyShareFontLoader {
  Future<void>? _loading;
  Future<void> load() =>
      _loading ??= _load().catchError((Object error, StackTrace stackTrace) {
        _loading = null;
        Error.throwWithStackTrace(error, stackTrace);
      });

  Future<void> _load() async {
    await Future.wait([
      (FontLoader('DailyShareSans')
            ..addFont(rootBundle.load('assets/fonts/pdf/NotoSans-Regular.ttf')))
          .load(),
      (FontLoader(
        'DailyShareBold',
      )..addFont(rootBundle.load('assets/fonts/pdf/NotoSans-Bold.ttf'))).load(),
      (FontLoader('DailyShareChinese')..addFont(
            rootBundle.load('assets/fonts/pdf/NotoSansSC-Regular.ttf'),
          ))
          .load(),
    ]);
  }
}

/// 唯一的分享图片合成入口。输入均已下载，成功后预览无需再次解码或等待首帧截图。
Future<GeneratedDailyCheckInShareImage> generateDailyCheckInShareImage({
  required ShareCardTemplate template,
  required DailyCheckInShareData data,
  required DailyCheckInShareAssets assets,
  DailyShareDecodedImageCache? decodedImageCache,
}) async {
  final cache = decodedImageCache ?? DailyShareDecodedImageCache();
  final totalWatch = Stopwatch()..start();
  final decoded = <ui.Image>[];
  ui.Picture? picture;
  ui.Image? rendered;
  Future<ui.Image> decode(DailyShareImageRole role, Uint8List bytes) async {
    final image = await cache.acquire(role, bytes);
    decoded.add(image);
    return image;
  }

  try {
    final background = await decode(
      DailyShareImageRole.background,
      assets.background,
    );
    final logo = await decode(DailyShareImageRole.logo, assets.logo);
    final qr = await decode(DailyShareImageRole.qrCode, assets.qrCode);
    ui.Image? avatar;
    if (assets.avatar != null) {
      try {
        avatar = await decode(DailyShareImageRole.avatar, assets.avatar!);
      } on Exception catch (error) {
        AppLogger.log('DailyShare', '头像解码失败，使用昵称首字: $error');
      }
    }
    final paintWatch = Stopwatch()..start();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(1.08);
    // 导出图保持方形、不裁圆角；圆角只在界面预览的父组件里处理。
    const bounds = Rect.fromLTWH(0, 0, 1000, 4000 / 3);
    paintImage(
      canvas: canvas,
      rect: bounds,
      image: background,
      fit: BoxFit.cover,
    );

    TextStyle style(double size, Color color, [bool bold = false]) => TextStyle(
      fontFamily: bold ? 'DailyShareBold' : 'DailyShareSans',
      fontFamilyFallback: const ['DailyShareChinese'],
      fontSize: size,
      color: color,
      height: 1.22,
    );

    void text(
      String value,
      Rect rect,
      double size,
      Color color, {
      bool bold = false,
      TextAlign align = TextAlign.left,
    }) {
      _paintFittedText(
        canvas,
        TextSpan(text: value, style: style(size, color, bold)),
        rect,
        align,
      );
    }

    final top = template.topColor;
    final bottom = template.bottomColor;
    text(
      _cardDate(data.date),
      const Rect.fromLTWH(74, 70, 400, 40),
      26,
      top,
      bold: true,
    );
    final nickname = data.nickname?.trim() ?? '';
    text(
      nickname,
      const Rect.fromLTWH(530, 70, 330, 36),
      26,
      top,
      bold: true,
      align: TextAlign.right,
    );
    const avatarRect = Rect.fromLTWH(876, 64, 50, 50);
    canvas.save();
    canvas.clipPath(Path()..addOval(avatarRect));
    if (avatar != null) {
      paintImage(
        canvas: canvas,
        rect: avatarRect,
        image: avatar,
        fit: BoxFit.cover,
      );
    } else {
      canvas.drawOval(avatarRect, Paint()..color = top.withValues(alpha: 0.1));
      text(
        nickname.isEmpty
            ? ''
            : String.fromCharCode(nickname.runes.first).toUpperCase(),
        avatarRect.deflate(6),
        25,
        top,
        bold: true,
        align: TextAlign.center,
      );
    }
    canvas.restore();

    final content = template.content;
    // 英语界面只展示原文；母语设置不能让英文卡片回退显示中文译文。
    final translation = data.isChinese
        ? content.translationFor(data.nativeLanguage)
        : '';
    if (content is ShareCardWord) {
      _paintFittedText(
        canvas,
        TextSpan(
          children: [
            TextSpan(text: content.english, style: style(100, top, true)),
            if (content.phonetic.isNotEmpty)
              TextSpan(text: '\n${content.phonetic}', style: style(32, top)),
          ],
        ),
        const Rect.fromLTWH(74, 180, 852, 180),
        TextAlign.left,
      );
      if (translation.isNotEmpty) {
        text(translation, const Rect.fromLTWH(74, 370, 852, 80), 30, top);
      }
    } else {
      _paintFittedText(
        canvas,
        TextSpan(
          children: [
            TextSpan(text: content.english, style: style(62, top, true)),
            if (translation.isNotEmpty)
              TextSpan(text: '\n$translation', style: style(30, top)),
          ],
        ),
        const Rect.fromLTWH(74, 180, 852, 270),
        TextAlign.left,
      );
    }

    final total = dailyShareDisplayMinutes(data.totalSeconds);
    final input = dailyShareDisplayMinutes(
      math.min(data.inputSeconds, data.totalSeconds),
    );
    final output = dailyShareDisplayMinutes(
      math.min(data.outputSeconds, data.totalSeconds),
    );
    _paintFittedText(
      canvas,
      TextSpan(
        children: [
          TextSpan(text: '$total ', style: style(56, bottom, true)),
          TextSpan(
            text: data.isChinese
                ? '分钟  (听 $input · 说 $output)'
                : 'min  (listen $input · speak $output)',
            style: style(22, bottom),
          ),
        ],
      ),
      const Rect.fromLTWH(74, 940, 600, 74),
      TextAlign.left,
    );
    text(
      data.isChinese ? '今日练习' : 'Today’s practice',
      const Rect.fromLTWH(74, 1030, 560, 44),
      24,
      bottom,
    );
    _paintFittedText(
      canvas,
      TextSpan(
        children: [
          TextSpan(text: '${data.streak} ', style: style(56, bottom, true)),
          TextSpan(
            text: data.isChinese ? '天' : 'days',
            style: style(22, bottom),
          ),
        ],
      ),
      const Rect.fromLTWH(700, 940, 226, 74),
      TextAlign.right,
    );
    text(
      data.isChinese ? '连续学习' : 'Learning streak',
      const Rect.fromLTWH(680, 1030, 246, 44),
      24,
      bottom,
      align: TextAlign.right,
    );

    paintImage(
      canvas: canvas,
      rect: const Rect.fromLTWH(74, 1166, 74, 74),
      image: logo,
      fit: BoxFit.contain,
    );
    text(
      'Echo Loop',
      const Rect.fromLTWH(168, 1160, 570, 43),
      30,
      bottom,
      bold: true,
    );
    text(
      data.isChinese ? '英语听说 E 筋经' : 'Listen. Speak. Grow.',
      const Rect.fromLTWH(168, 1210, 570, 34),
      22,
      bottom,
    );
    paintImage(
      canvas: canvas,
      rect: const Rect.fromLTWH(828, 1146, 98, 98),
      image: qr,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
    );

    picture = recorder.endRecording();
    AppLogger.log(
      'DailyShare',
      'Canvas 绘制完成 耗时=${paintWatch.elapsedMilliseconds}ms',
    );
    final rasterWatch = Stopwatch()..start();
    rendered = await picture.toImage(1080, 1440);
    AppLogger.log(
      'DailyShare',
      '卡片栅格化完成 耗时=${rasterWatch.elapsedMilliseconds}ms 尺寸=1080x1440',
    );
    final pngWatch = Stopwatch()..start();
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('分享图片编码失败');
    AppLogger.log(
      'DailyShare',
      'PNG 编码完成 耗时=${pngWatch.elapsedMilliseconds}ms 合成总耗时=${totalWatch.elapsedMilliseconds}ms',
    );
    final result = GeneratedDailyCheckInShareImage(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      rendered,
    );
    rendered = null;
    return result;
  } finally {
    if (decodedImageCache == null) cache.dispose();
    rendered?.dispose();
    picture?.dispose();
    for (final image in decoded) {
      image.dispose();
    }
  }
}

/// 日期格式与 Web 固定英文月份一致，不依赖应用本地化初始化顺序。
String _cardDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}. ${date.year}';
}

/// 根据完整段落的实际布局缩小字号，避免长单词、音标或译文被裁掉。
void _paintFittedText(
  Canvas canvas,
  TextSpan span,
  Rect rect,
  TextAlign align,
) {
  final painter = TextPainter(
    textDirection: ui.TextDirection.ltr,
    textAlign: align,
  );
  try {
    var scale = 1.0;
    for (var attempt = 0; attempt < 100; attempt++) {
      painter.text = span;
      painter.textScaler = TextScaler.linear(scale);
      painter.layout(minWidth: rect.width, maxWidth: rect.width);
      if (painter.height <= rect.height) break;
      scale *= 0.95;
    }
    painter.paint(canvas, rect.topLeft);
  } finally {
    painter.dispose();
  }
}
