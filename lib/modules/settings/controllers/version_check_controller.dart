import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/utils/device_id_manager.dart';
import '../../../core/utils/app_update_manager.dart';
import '../../../core/widgets/toast.dart';
import '../../../data/services/version_check_service.dart';
import '../../../data/models/version_check/version_check_request.dart';
import '../../../data/models/version_check/version_check_response.dart';

class VersionCheckController extends GetxController {
  final VersionCheckService _versionCheckService = VersionCheckService();
  final DeviceIdManager _deviceIdManager = DeviceIdManager();

  final deviceId = RxString('');
  final versionInfo = RxString('');
  final updateTime = RxString('');
  final isChecking = RxBool(false);
  final downloadProgress = RxDouble(0.0);

  AppUpdateManager? _currentAppUpdateManager;
  VersionCheckResponse? latestVersionInfo;

  @override
  void onInit() {
    super.onInit();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      // 获取设备ID（使用设备ID管理器）
      deviceId.value = await _deviceIdManager.getDeviceId();

      // 获取应用版本信息
      final packageInfo = await PackageInfo.fromPlatform();
      versionInfo.value = '${packageInfo.version}+${packageInfo.buildNumber}';

      // 获取更新时间（优先使用 updateTime，如果为空则使用 installTime）
      final updateDateTime = packageInfo.updateTime ?? packageInfo.installTime;
      if (updateDateTime != null) {
        updateTime.value = _formatDateTime(updateDateTime);
      } else {
        updateTime.value = '未知';
      }
    } catch (e) {
      Toast.error(message: '加载设备信息失败: $e');
    }
  }

  /// 格式化日期时间为年月日格式
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  /// 检查更新
  Future<bool> checkUpdate({bool showToast = true}) async {
    if (isChecking.value) return false;

    try {
      isChecking.value = true;

      // 确保设备ID已加载
      String currentDeviceId = deviceId.value;
      if (currentDeviceId.isEmpty) {
        currentDeviceId = await _deviceIdManager.getDeviceId();
      }

      // 获取当前版本信息
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 构建请求
      final request = VersionCheckRequest(
        deviceId: currentDeviceId,
        currentVersion: currentVersion,
      );

      // 调用版本检查接口
      final response = await _versionCheckService.checkVersion(request);
      latestVersionInfo = response;

      // 使用版本号对比判断是否需要更新
      final latestVersion = response.latestVersion;
      if (latestVersion != null &&
          AppUpdateManager.isNewerVersion(currentVersion, latestVersion)) {
        return true; // 需要更新
      } else {
        if (showToast) {
          Toast.success(message: '当前已是最新版本');
        }
        return false;
      }
    } catch (e) {
      if (showToast) {
        Toast.error(message: '检查更新失败: $e');
      }
      return false;
    } finally {
      isChecking.value = false;
    }
  }

  /// 开始下载更新
  Future<void> startDownload(String url) async {
    _currentAppUpdateManager = AppUpdateManager();
    downloadProgress.value = 0.0;

    await _currentAppUpdateManager!.downloadAndInstall(
      url: url,
      onProgress: (progress) => downloadProgress.value = progress.toDouble(),
      onSuccess: () async {
        await _loadDeviceInfo();
        Toast.success(message: '下载完成，正在安装...');
      },
      onError: (error) => Toast.error(message: error),
    );
  }

  /// 取消下载
  void cancelDownload() {
    _currentAppUpdateManager?.cancelDownload();
    _currentAppUpdateManager = null;
  }

  /// 启动时检查更新（静态方法，用于应用启动时调用）
  static Future<void> checkUpdateOnStartup(BuildContext context) async {
    try {
      // 延迟3秒后检查，避免影响启动速度
      await Future.delayed(const Duration(seconds: 3));

      // 获取或创建 Controller
      VersionCheckController controller;
      if (Get.isRegistered<VersionCheckController>()) {
        controller = Get.find<VersionCheckController>();
      } else {
        controller = Get.put(VersionCheckController());
      }

      // 复用 checkUpdate 方法，静默检查
      final needUpdate = await controller.checkUpdate(showToast: false);

      // 如果需要强制更新，直接弹窗
      if (needUpdate &&
          (controller.latestVersionInfo?.forceUpdate ?? false) &&
          context.mounted) {
        controller.showUpdateDialog(context);
      }
    } catch (e) {
      // 静默失败，不影响用户使用
    }
  }

  /// 显示更新对话框
  void showUpdateDialog(BuildContext context) {
    if (latestVersionInfo == null) return;

    final latestVersion = latestVersionInfo!.latestVersion ?? '未知版本';
    final updateDescription = latestVersionInfo!.updateDescription ?? '有新版本可更新';
    final updateUrl = latestVersionInfo!.updateUrl ?? '';
    final forceUpdate = latestVersionInfo!.forceUpdate ?? false;

    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (dialogContext) => PopScope(
        canPop: !forceUpdate,
        child: AlertDialog(
          title: const Text('发现新版本'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (forceUpdate)
                  const Text(
                    '检测到新版本，需要立即更新',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                if (forceUpdate) const SizedBox(height: 10),
                Text('最新版本: $latestVersion'),
                const SizedBox(height: 10),
                Text('更新说明:\n$updateDescription'),
              ],
            ),
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('稍后更新'),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                if (updateUrl.isNotEmpty) {
                  showDownloadDialog(context, updateUrl, forceUpdate);
                }
              },
              child: const Text('立即更新'),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示下载进度对话框
  void showDownloadDialog(BuildContext context, String url, bool forceUpdate) {
    BuildContext? dialogContext;
    bool isDialogClosed = false;

    void closeDialog() {
      if (!isDialogClosed && dialogContext != null && dialogContext!.mounted) {
        isDialogClosed = true;
        Navigator.pop(dialogContext!);
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return Obx(
          () => AlertDialog(
            title: const Text('下载更新'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: downloadProgress.value / 100.0,
                  backgroundColor: Colors.grey[200],
                  minHeight: 8,
                ),
                const SizedBox(height: 16),
                Text('${downloadProgress.value.toInt()}%'),
              ],
            ),
            actions: [
              if (!forceUpdate)
                TextButton(
                  onPressed: () {
                    cancelDownload();
                    closeDialog();
                  },
                  child: const Text('取消'),
                ),
            ],
          ),
        );
      },
    );

    // 开始下载
    startDownload(url)
        .then((_) {
          closeDialog();
        })
        .catchError((e) {
          closeDialog();
        });
  }
}
