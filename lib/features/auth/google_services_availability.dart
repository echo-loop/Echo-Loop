import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../services/app_logger.dart';

/// 检测当前设备是否能提供 Google 登录所需的 Google Play services。
///
/// 只在 Android 上调用原生 `GoogleApiAvailability`；其他平台直接返回 false，
/// 因为当前产品策略只在 Android 暴露 Google 登录入口。
abstract class GoogleServicesAvailability {
  Future<bool> isAvailable();
}

class MethodChannelGoogleServicesAvailability
    implements GoogleServicesAvailability {
  const MethodChannelGoogleServicesAvailability();

  static const _channel = MethodChannel('top.echo-loop/google_services');

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      AppLogger.log(
        'AuthGMS',
        'skip availability check platform=$defaultTargetPlatform web=$kIsWeb',
      );
      return false;
    }

    try {
      AppLogger.log('AuthGMS', 'checking Google Play services availability');
      final result = await _channel.invokeMethod<bool>(
        'isGooglePlayServicesAvailable',
      );
      final isAvailable = result ?? false;
      AppLogger.log('AuthGMS', 'availability result=$isAvailable');
      return isAvailable;
    } on PlatformException catch (error) {
      AppLogger.log(
        'AuthGMS',
        'availability check failed code=${error.code} message=${error.message}',
      );
      return false;
    } on MissingPluginException catch (error) {
      AppLogger.log('AuthGMS', 'availability check missing plugin: $error');
      return false;
    }
  }
}
