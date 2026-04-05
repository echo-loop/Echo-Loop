/// 相对时间格式化工具
///
/// 基于 timeago 库，支持中英文自动切换。
library;

import 'package:flutter/widgets.dart';
import 'package:timeago/timeago.dart' as timeago;

/// 初始化 timeago 中文 locale（在 main() 中调用一次）
void initTimeago() {
  timeago.setLocaleMessages('zh', _ZhCnMessages());
}

/// 将 [dateTime] 格式化为相对时间（如"5分钟前"/"5 minutes ago"）
///
/// 自动根据当前 locale 切换语言。
String formatTimeAgo(BuildContext context, DateTime dateTime) {
  return timeago.format(
    dateTime,
    locale: Localizations.localeOf(context).languageCode,
  );
}

/// 简体中文 timeago 消息
class _ZhCnMessages implements timeago.LookupMessages {
  @override
  String prefixAgo() => '';
  @override
  String prefixFromNow() => '';
  @override
  String suffixAgo() => '';
  @override
  String suffixFromNow() => '';
  @override
  String lessThanOneMinute(int seconds) => '刚刚';
  @override
  String aboutAMinute(int minutes) => '1分钟前';
  @override
  String minutes(int minutes) => '$minutes分钟前';
  @override
  String aboutAnHour(int minutes) => '1小时前';
  @override
  String hours(int hours) => '$hours小时前';
  @override
  String aDay(int hours) => '1天前';
  @override
  String days(int days) => '$days天前';
  @override
  String aboutAMonth(int days) => '1个月前';
  @override
  String months(int months) => '$months个月前';
  @override
  String aboutAYear(int year) => '1年前';
  @override
  String years(int years) => '$years年前';
  @override
  String wordSeparator() => '';
}
