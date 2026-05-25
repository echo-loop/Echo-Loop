/// 录音权限抽象层。
///
/// 统一封装 [permission_handler] 包，让 dialog 通过 Riverpod provider
/// 注入服务实例，便于测试 mock。生产环境用 [PermissionHandlerSpeechPermissionService]。
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:url_launcher/url_launcher.dart';

import '../models/speech_practice_models.dart';
import 'app_logger.dart';
import 'speech_practice_platform.dart';

/// 录音权限服务接口。
abstract class SpeechPermissionService {
  /// 当前平台是否支持录音流程（Web / Linux 上 false）。
  bool get isSupported;

  /// 读取麦克风 + 平台语音识别的当前权限状态。
  Future<SpeechPracticePermissionState> getStatus();

  /// 请求权限。
  ///
  /// - `onlyMic = true`：仅请求麦克风（用于关闭 ASR 或 Echo Loop 离线后端场景）。
  /// - `onlyMic = false`：同时请求麦克风 + 语音识别（iOS 平台 ASR 场景）。
  Future<SpeechPracticePermissionState> request({required bool onlyMic});

  /// 跳转到本应用在系统设置中的"应用详情/隐私"页。
  Future<void> openAppSettings();
}

/// 默认实现：iOS / Android 走 [permission_handler]；macOS 走仓库自建的
/// [SpeechPracticePlatform] 原生桥。
///
/// 为何 macOS 单独处理：`permission_handler_apple` 包 pubspec 只声明 iOS 平台，
/// macOS engine 不会注册其插件，所有方法调用都会抛 `MissingPluginException`。
/// 仓库已有 `MacSpeechPracticeHandler` 直接调 `AVAudioSession` /
/// `SFSpeechRecognizer`，权限读取/请求/状态映射逻辑完整，复用即可。
class PermissionHandlerSpeechPermissionService
    implements SpeechPermissionService {
  const PermissionHandlerSpeechPermissionService();

  @override
  bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS || Platform.isAndroid);

  @override
  Future<SpeechPracticePermissionState> getStatus() async {
    if (Platform.isMacOS) {
      return _macStatus();
    }
    final mic = await _safeStatus(ph.Permission.microphone, 'microphone');
    final speech = await _safeStatus(ph.Permission.speech, 'speech');
    AppLogger.log(
      'SpeechPerm',
      '● getStatus: mic=${mic.name} speech=${speech.name}',
    );
    return SpeechPracticePermissionState(microphone: mic, speech: speech);
  }

  @override
  Future<SpeechPracticePermissionState> request({required bool onlyMic}) async {
    AppLogger.log('SpeechPerm', '┌ request onlyMic=$onlyMic');
    if (Platform.isMacOS) {
      return _macRequest(onlyMic: onlyMic);
    }
    final mic = await _safeRequest(ph.Permission.microphone, 'microphone');
    final speech = onlyMic
        ? SpeechPracticePermissionStatus.granted
        : await _safeRequest(ph.Permission.speech, 'speech');
    AppLogger.log(
      'SpeechPerm',
      '└ request done: mic=${mic.name} speech=${speech.name}',
    );
    return SpeechPracticePermissionState(microphone: mic, speech: speech);
  }

  @override
  Future<void> openAppSettings() async {
    if (Platform.isMacOS) {
      try {
        final ok = await launchUrl(
          Uri.parse(
            'x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone',
          ),
        );
        AppLogger.log('SpeechPerm', '● openAppSettings macOS launchUrl ok=$ok');
      } catch (e) {
        AppLogger.log('SpeechPerm', '⚠ openAppSettings macOS error: $e');
      }
      return;
    }
    try {
      final ok = await ph.openAppSettings();
      AppLogger.log('SpeechPerm', '● openAppSettings ok=$ok');
    } catch (e) {
      AppLogger.log('SpeechPerm', '● openAppSettings error: $e');
    }
  }

  // ---------- macOS：复用项目自建的 SpeechPracticePlatform 原生桥 ----------

  Future<SpeechPracticePermissionState> _macStatus() async {
    try {
      final state = await SpeechPracticePlatform.instance.getPermissionStatus();
      AppLogger.log(
        'SpeechPerm',
        '● macOS native getStatus: mic=${state.microphone.name} speech=${state.speech.name}',
      );
      return state;
    } catch (e) {
      AppLogger.log(
        'SpeechPerm',
        '⚠ macOS native getStatus failed: $e → notDetermined',
      );
      // 查询失败保守视为 notDetermined，让 dialog 走「需要授权」路径
      // 用户点 Grant 时再次尝试触发系统弹窗
      return const SpeechPracticePermissionState();
    }
  }

  Future<SpeechPracticePermissionState> _macRequest({
    required bool onlyMic,
  }) async {
    try {
      final state = await SpeechPracticePlatform.instance.requestPermissions(
        onlyMic: onlyMic,
      );
      AppLogger.log(
        'SpeechPerm',
        '└ macOS native request: mic=${state.microphone.name} speech=${state.speech.name}',
      );
      return state;
    } catch (e) {
      AppLogger.log('SpeechPerm', '⚠ macOS native request failed: $e → denied');
      // 请求失败视为 denied，dialog 切到「前往设置」入口让用户手动开启
      return const SpeechPracticePermissionState(
        microphone: SpeechPracticePermissionStatus.denied,
        speech: SpeechPracticePermissionStatus.denied,
      );
    }
  }

  /// 单个权限的 status 查询，异常时回退为 `notDetermined` 让 dialog
  /// 走「需要授权」分支再尝试。
  ///
  /// 不能映射为 granted——会让 dialog 直接放行进入页面，到真正录音瞬间再
  /// 失败，用户只看到通用错误且没有恢复路径。映射为 notDetermined 至少
  /// 给用户一次 request 机会；request 也失败的话由调用方降级到 denied。
  Future<SpeechPracticePermissionStatus> _safeStatus(
    ph.Permission p,
    String label,
  ) async {
    try {
      return _convert(await p.status);
    } catch (e) {
      AppLogger.log(
        'SpeechPerm',
        '⚠ status($label) failed: $e → notDetermined',
      );
      return SpeechPracticePermissionStatus.notDetermined;
    }
  }

  Future<SpeechPracticePermissionStatus> _safeRequest(
    ph.Permission p,
    String label,
  ) async {
    try {
      return _convert(await p.request());
    } catch (e) {
      AppLogger.log('SpeechPerm', '⚠ request($label) failed: $e → denied');
      // request 都失败说明平台不可用，引导用户去系统设置自查
      return SpeechPracticePermissionStatus.denied;
    }
  }

  /// 把 [permission_handler] 的状态枚举映射到本项目内枚举。
  ///
  /// 关键映射：
  /// - `isPermanentlyDenied` → 本项目 `denied`（必须去系统设置）
  /// - `isDenied`（非永久）→ **`notDetermined`**（仍可通过 `request()` 触发系统弹窗）
  ///
  /// 为何 `isDenied` 不映射为 `denied`：
  /// - **iOS**：permission_handler 把 `AVAudioSession.recordPermission.undetermined`
  ///   （即从未询问过的首次状态）映射为 `PermissionStatus.denied`。如果 dialog
  ///   直接当成"永久拒绝"显示「前往设置」，用户在系统设置里根本看不到对应权限的
  ///   开关——因为系统从未注册过本应用的权限请求。
  /// - **Android**：`denied`（非永久）表示"已拒绝但仍可再次询问"，本质等同于
  ///   "未决定"，先 `request()` 让系统再次弹窗才是正确动作。
  ///
  /// 因此两端都把 `isDenied` 当成"先尝试请求"。请求后若返回 `isPermanentlyDenied`
  /// 才转为本项目 `denied`，dialog 自动切到「前往设置」。
  static SpeechPracticePermissionStatus _convert(ph.PermissionStatus status) {
    if (status.isGranted) return SpeechPracticePermissionStatus.granted;
    if (status.isRestricted) return SpeechPracticePermissionStatus.restricted;
    if (status.isPermanentlyDenied) {
      return SpeechPracticePermissionStatus.denied;
    }
    return SpeechPracticePermissionStatus.notDetermined;
  }
}

/// Riverpod provider — 测试中通过 `overrideWith` 注入 fake。
final speechPermissionServiceProvider = Provider<SpeechPermissionService>(
  (ref) => const PermissionHandlerSpeechPermissionService(),
);
