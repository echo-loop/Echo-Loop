// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 提醒设置 Notifier
///
/// `build()` 优先同步读取已初始化的 SP，独立容器下异步回退加载。
/// 外部通过 [update] 更新设置，自动持久化并同步 state。

@ProviderFor(ReminderSettingsNotifier)
final reminderSettingsProvider = ReminderSettingsNotifierProvider._();

/// 提醒设置 Notifier
///
/// `build()` 优先同步读取已初始化的 SP，独立容器下异步回退加载。
/// 外部通过 [update] 更新设置，自动持久化并同步 state。
final class ReminderSettingsNotifierProvider
    extends $NotifierProvider<ReminderSettingsNotifier, ReminderSettings> {
  /// 提醒设置 Notifier
  ///
  /// `build()` 优先同步读取已初始化的 SP，独立容器下异步回退加载。
  /// 外部通过 [update] 更新设置，自动持久化并同步 state。
  ReminderSettingsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderSettingsNotifierHash();

  @$internal
  @override
  ReminderSettingsNotifier create() => ReminderSettingsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReminderSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReminderSettings>(value),
    );
  }
}

String _$reminderSettingsNotifierHash() =>
    r'a4c31476182c6bcf4017afa1613f838875e223ca';

/// 提醒设置 Notifier
///
/// `build()` 优先同步读取已初始化的 SP，独立容器下异步回退加载。
/// 外部通过 [update] 更新设置，自动持久化并同步 state。

abstract class _$ReminderSettingsNotifier extends $Notifier<ReminderSettings> {
  ReminderSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReminderSettings, ReminderSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReminderSettings, ReminderSettings>,
              ReminderSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
