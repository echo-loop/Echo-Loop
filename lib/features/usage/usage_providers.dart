import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/provider_override_error.dart';

import '../../analytics/analytics_providers.dart';
import '../onboarding_survey/providers/onboarding_survey_provider.dart';
import 'usage_counters.dart';
import 'usage_counter_store.dart';
import 'usage_tracker.dart';

final usageCounterStoreProvider = Provider<UsageCounterStore>((ref) {
  try {
    return UsageCounterStore(ref.watch(sharedPreferencesProvider));
  } catch (error) {
    if (!isProviderNotOverriddenError(error)) rethrow;
    return UsageCounterStore.memory();
  }
});

final usageTrackerProvider = Provider<UsageTracker>((ref) {
  return UsageTracker(
    store: ref.watch(usageCounterStoreProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
});

/// 只读当前累计使用计数（含 AI 成功次数）。
///
/// 供日后评价弹窗 / 付费提醒等按阈值判断读取。本次不接任何 UI。
/// 计数在 [usageTrackerProvider].record 时写盘，读取方需要最新值时可
/// `ref.invalidate(usageCountersProvider)` 后重读。
final usageCountersProvider = FutureProvider<UsageCounters>((ref) async {
  return ref.watch(usageTrackerProvider).loadCounters();
});
