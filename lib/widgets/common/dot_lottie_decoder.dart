import 'package:lottie/lottie.dart';

/// 从 dotLottie 压缩包中选取第一个动画 JSON，供纯 Dart Lottie 播放器解析。
///
/// 作为 `Lottie.asset(decoder: ...)` 使用，避免每个页面各自复制一份解码逻辑。
Future<LottieComposition?> decodeDotLottieAnimation(List<int> bytes) {
  return LottieComposition.decodeZip(
    bytes,
    filePicker: (files) {
      for (final file in files) {
        if (file.name.startsWith('animations/') &&
            file.name.endsWith('.json')) {
          return file;
        }
      }
      return null;
    },
  );
}
