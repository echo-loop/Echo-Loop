/// 基于系统 Region 判断用户是否使用中国区服务。
library;

/// 系统 Region 国家码为 CN 时使用中国区服务，其余情况使用全球服务。
bool isChinaSystemRegion(String? countryCode) {
  return countryCode?.trim().toUpperCase() == 'CN';
}
