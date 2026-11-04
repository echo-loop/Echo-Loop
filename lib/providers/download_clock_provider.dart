import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 下载速度统计使用的时间来源；测试中可替换为可控时钟。
final downloadClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
