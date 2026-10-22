import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/app_logger.dart';
import 'onboarding_survey_storage.dart';
import 'user_onboarding_api.dart';

abstract interface class OnboardingSync {
  /// 更新当前是否存在登录会话，并在登录时检查待上传答案。
  Future<void> onSessionChanged({required bool isSignedIn});

  /// 本地问卷保存完成后检查是否可以立即上传。
  Future<void> onLocalAnswersChanged();

  /// 应用回到前台时重试尚未成功的上传。
  Future<void> onAppResumed();
}

/// 只在本机记录是否已成功上传，避免切换账号后重复传送相同问卷。
class UserOnboardingSyncService implements OnboardingSync {
  UserOnboardingSyncService({
    required UserOnboardingRemoteDataSource remote,
    required OnboardingSurveyStorage storage,
    required SharedPreferences preferences,
  }) : _remote = remote,
       _storage = storage,
       _preferences = preferences;

  static const uploadedKey = OnboardingSurveyKeys.uploaded;

  final UserOnboardingRemoteDataSource _remote;
  final OnboardingSurveyStorage _storage;
  final SharedPreferences _preferences;

  bool _isSignedIn = false;
  bool _isUploading = false;
  bool _syncAgain = false;
  bool _disposed = false;

  @override
  Future<void> onSessionChanged({required bool isSignedIn}) async {
    _isSignedIn = isSignedIn;
    if (isSignedIn) await _synchronize();
  }

  @override
  Future<void> onLocalAnswersChanged() => _synchronize();

  @override
  Future<void> onAppResumed() => _synchronize();

  /// 登录且尚未成功上传时读取已保存答案并发送到服务端。
  ///
  /// 仅在服务端保存成功后写入本机标记；失败时保留待同步状态，供后续登录、
  /// 应用恢复或问卷保存事件重试。
  Future<void> _synchronize() async {
    if (_disposed || !_isSignedIn || _hasUploaded) return;
    if (_isUploading) {
      _syncAgain = true;
      return;
    }

    _isUploading = true;
    try {
      do {
        _syncAgain = false;
        if (_disposed || !_isSignedIn || _hasUploaded) break;

        final answers = _storage.loadAnswersForSync();
        if (answers == null) {
          AppLogger.log('UserOnboardingSync', '没有有效的已保存答案，跳过上传');
          break;
        }

        try {
          AppLogger.log('UserOnboardingSync', '开始上传已完成问卷');
          await _remote.saveAnswers(answers.toJson());
          final saved = await _preferences.setBool(uploadedKey, true);
          if (!saved) {
            AppLogger.log(
              'UserOnboardingSync',
              '服务端已保存答案，但本机成功标记未能持久化；后续会安全重试',
            );
          } else {
            AppLogger.log('UserOnboardingSync', '问卷上传成功并已记录本机状态');
          }
        } on Object catch (error, stackTrace) {
          AppLogger.log(
            'UserOnboardingSync',
            '上传失败，保留待重试状态 errorType=${error.runtimeType} '
                'stack=$stackTrace',
          );
        }
      } while (_syncAgain && _isSignedIn && !_hasUploaded);
    } on Object catch (error, stackTrace) {
      AppLogger.log(
        'UserOnboardingSync',
        '同步准备失败 errorType=${error.runtimeType} stack=$stackTrace',
      );
    } finally {
      _isUploading = false;
    }
  }

  bool get _hasUploaded => _preferences.getBool(uploadedKey) == true;

  void dispose() {
    _disposed = true;
  }
}
