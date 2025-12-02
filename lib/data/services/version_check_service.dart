import '../../core/network/api_client.dart';
import '../models/version_check/version_check_request.dart';
import '../models/version_check/version_check_response.dart';

/// 版本检查服务 - 处理版本更新检查相关的 API 请求
class VersionCheckService {
  final ApiClient _apiClient = ApiClient();

  /// 是否使用模拟数据（开发测试用）
  static bool useMockData = true;

  /// 检查版本更新
  Future<VersionCheckResponse> checkVersion(VersionCheckRequest request) async {
    try {
      // 如果启用模拟数据，直接返回模拟响应
      if (useMockData) {
        return _getMockResponse(request);
      }

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/midst-auth/vws/check-version',
        data: request.toJson(),
      );

      if (response.isSuccess && response.data != null) {
        return VersionCheckResponse.fromJson(response.data!);
      } else {
        throw Exception(response.msg);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 获取模拟数据响应
  ///
  /// 模拟场景：
  /// - 如果当前版本是 1.0.0，返回有新版本 1.0.1
  /// - 其他版本返回已是最新版本
  Future<VersionCheckResponse> _getMockResponse(
    VersionCheckRequest request,
  ) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(seconds: 1));

    final currentVersion = request.currentVersion;

    // 模拟场景：版本 1.0.0 有新版本可更新
    if (currentVersion == '1.0.0') {
      return VersionCheckResponse(
        latestVersion: '1.0.1',
        updateUrl:
            'https://mirrors.ustc.edu.cn/videolan-ftp/vlc-android/3.6.3/VLC-Android-3.6.3-arm64-v8a.apk',
        updateDescription: '修复已知问题，优化性能\n- 修复登录界面显示问题\n- 优化列表加载速度\n- 改进用户体验',
        forceUpdate: false,
      );
    }

    // 其他版本返回已是最新版本
    return VersionCheckResponse(
      latestVersion: currentVersion,
      updateUrl: '',
      updateDescription: '',
      forceUpdate: false,
    );
  }
}
