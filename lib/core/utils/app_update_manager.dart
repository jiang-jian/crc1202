import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

/// 应用更新管理器
///
/// 功能：
/// 1. 下载APK文件
/// 2. 自动安装APK（使用open_filex，无需手动请求权限）
/// 3. 显示下载进度
class AppUpdateManager {
  static AppUpdateManager? _instance;
  final Dio _dio = Dio();
  CancelToken? _cancelToken;
  bool _isCancelled = false;

  AppUpdateManager._();

  /// 获取单例实例
  factory AppUpdateManager() {
    _instance ??= AppUpdateManager._();
    return _instance!;
  }

  /// 下载并安装APK
  ///
  /// [url] - APK下载地址
  /// [onProgress] - 下载进度回调 (0-100)
  /// [onSuccess] - 下载成功回调
  /// [onError] - 错误回调
  Future<void> downloadAndInstall({
    required String url,
    required Function(int progress) onProgress,
    required Function() onSuccess,
    required Function(String error) onError,
  }) async {
    try {
      // 重置取消标志
      _isCancelled = false;
      _cancelToken = CancelToken();

      // 获取下载目录
      final downloadDir = await _getDownloadDirectory();
      final fileName = _getFileNameFromUrl(url);
      final filePath = '${downloadDir.path}/$fileName';

      // 删除旧文件（如果存在）
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // 下载文件
      await _downloadFile(
        url: url,
        savePath: filePath,
        onProgress: onProgress,
        onError: onError,
      );

      // 如果已取消，不继续安装
      if (_isCancelled) {
        return;
      }

      // 验证文件已下载
      if (!await file.exists()) {
        onError('文件下载失败');
        return;
      }

      // 下载完成后安装
      await _installApk(filePath);
      onSuccess();
    } catch (e) {
      if (!_isCancelled) {
        onError('下载或安装失败: $e');
      }
    }
  }

  /// 下载文件
  Future<void> _downloadFile({
    required String url,
    required String savePath,
    required Function(int progress) onProgress,
    required Function(String error) onError,
  }) async {
    try {
      await _dio.download(
        url,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1 && !_isCancelled) {
            onProgress(((received / total) * 100).toInt());
          }
        },
      );
    } catch (e) {
      if (_isCancelled ||
          (e is DioException && e.type == DioExceptionType.cancel)) {
        onError('下载已取消');
      } else {
        onError('下载失败: $e');
      }
    }
  }

  /// 安装APK（使用 open_filex，自动处理权限）
  Future<void> _installApk(String filePath) async {
    if (Platform.isAndroid) {
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done) {
        throw Exception('打开安装程序失败: ${result.message}');
      }
    }
  }

  /// 获取下载目录
  Future<Directory> _getDownloadDirectory() async {
    // 使用应用缓存目录（无需存储权限）
    return await getTemporaryDirectory();
  }

  /// 从URL获取文件名
  String _getFileNameFromUrl(String url) {
    try {
      final pathSegments = Uri.parse(url).pathSegments;
      if (pathSegments.isNotEmpty) return pathSegments.last;
    } catch (_) {}
    return 'app_update_${DateTime.now().millisecondsSinceEpoch}.apk';
  }

  /// 取消下载
  void cancelDownload() {
    _isCancelled = true;
    try {
      if (_cancelToken != null && !_cancelToken!.isCancelled) {
        _cancelToken!.cancel();
      }
    } catch (_) {}
  }

  /// 比较版本号，返回 true 表示 latestVersion > currentVersion
  static bool isNewerVersion(String currentVersion, String latestVersion) {
    try {
      final currentParts = currentVersion.split('.').map(int.parse).toList();
      final latestParts = latestVersion.split('.').map(int.parse).toList();

      final maxLength = currentParts.length > latestParts.length
          ? currentParts.length
          : latestParts.length;

      for (int i = 0; i < maxLength; i++) {
        final current = i < currentParts.length ? currentParts[i] : 0;
        final latest = i < latestParts.length ? latestParts[i] : 0;

        if (latest > current) return true;
        if (latest < current) return false;
      }

      return false; // 版本相同
    } catch (e) {
      return false; // 解析失败，认为不需要更新
    }
  }
}
