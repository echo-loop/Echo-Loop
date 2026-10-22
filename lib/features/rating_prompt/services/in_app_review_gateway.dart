import 'package:in_app_review/in_app_review.dart';

/// 对系统原生评分弹窗的隔离接口。
abstract interface class InAppReviewGateway {
  /// 请求系统展示原生评分界面。
  Future<void> requestReview();
}

/// `in_app_review` 插件的生产适配器。
class PluginInAppReviewGateway implements InAppReviewGateway {
  PluginInAppReviewGateway({InAppReview? review})
    : _review = review ?? InAppReview.instance;

  final InAppReview _review;

  @override
  Future<void> requestReview() => _review.requestReview();
}
