/// 社区合集发现功能的路由路径。
abstract final class CommunityCollectionRoutes {
  static const discoverSegment = 'discover';
  static const discoverResources = '/collections/$discoverSegment';
  static const legacyDiscover = '/discover';

  /// 发现资源中的公开合集详情页路径。
  static String discoverCollection(String remoteId) =>
      '$discoverResources/$remoteId';
}
