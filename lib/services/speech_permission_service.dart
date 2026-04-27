/// 录音权限抽象层。
///
/// 统一封装 [permission_handler] 包，让 dialog 通过 Riverpod provider
/// 注入服务实例，便于测试 mock。生产环境用 [PermissionHandlerSpeechPermissionService]。
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../models/speech_practice_models.dart';

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

/// 默认实现：基于 [permission_handler] 包。
class PermissionHandlerSpeechPermissionService
    implements SpeechPermissionService {
  const PermissionHandlerSpeechPermissionService();

  @override
  bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS || Platform.isAndroid);

  @override
  Future<SpeechPracticePermissionState> getStatus() async {
    final mic = await ph.Permission.microphone.status;
    final speech = await ph.Permission.speech.status;
    return SpeechPracticePermissionState(
      microphone: _convert(mic),
      speech: _convert(speech),
    );
  }

  @override
  Future<SpeechPracticePermissionState> request({
    required bool onlyMic,
  }) async {
    final permissions = <ph.Permission>[
      ph.Permission.microphone,
      if (!onlyMic) ph.Permission.speech,
    ];
    final results = await permissions.request();
    final mic = results[ph.Permission.microphone] ?? ph.PermissionStatus.denied;
    final speech = onlyMic
        ? ph.PermissionStatus.granted
        : (results[ph.Permission.speech] ?? ph.PermissionStatus.denied);
    return SpeechPracticePermissionState(
      microphone: _convert(mic),
      speech: _convert(speech),
    );
  }

  @override
  Future<void> openAppSettings() => ph.openAppSettings();

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
