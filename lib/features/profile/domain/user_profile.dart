/// 用户资料（昵称与头像）。资料的唯一来源是后端 `profiles` 表，客户端不从 JWT 读取。
class UserProfile {
  const UserProfile({
    required this.userId,
    required this.nickname,
    required this.avatarUrl,
    required this.updatedAt,
  });

  /// 解析后端 GET / PATCH `/api/v1/me/profile` 的响应体。
  ///
  /// 外部输入在此校验，结构不符时抛出 [FormatException]，不返回默认值掩盖问题。
  factory UserProfile.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('Profile response must be a JSON object');
    }
    final userId = json['userId'];
    final nickname = json['nickname'];
    final avatarUrl = json['avatarUrl'];
    final updatedAt = json['updatedAt'];
    if (userId is! String ||
        (nickname != null && nickname is! String) ||
        (avatarUrl != null && avatarUrl is! String) ||
        updatedAt is! String) {
      throw const FormatException('Profile response has an invalid shape');
    }
    return UserProfile(
      userId: userId,
      nickname: nickname as String?,
      avatarUrl: avatarUrl as String?,
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  final String userId;

  /// 历史数据可能为 null，UI 需要回退到占位文案。
  final String? nickname;

  /// 为 null 表示未设置头像。每次换头像后 URL 都会变化，可直接作为图片缓存键。
  final String? avatarUrl;

  final DateTime updatedAt;
}
