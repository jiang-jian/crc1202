import 'package:get/get.dart';
import '../../network_check/controllers/network_check_controller.dart';
import '../../../data/services/external_card_reader_service.dart';
import '../../../core/widgets/debug_log_window.dart';
import 'version_check_controller.dart';
import 'mw_card_reader_controller.dart';

class SettingsController extends GetxController {
  final selectedMenu = RxString('external_card_reader');

  void selectMenu(String menu) {
    selectedMenu.value = menu;
  }

  @override
  void onClose() {
    print('onclose settings');
    _cleanupNetworkCheckController();
    _cleanupVersionCheckController();
    _cleanupExternalCardReaderService();
    _cleanupMwCardReaderController();
    super.onClose();
  }

  /// 清理 NetworkCheckController
  void _cleanupNetworkCheckController() {
    if (Get.isRegistered<NetworkCheckController>()) {
      Get.delete<NetworkCheckController>(force: true);
      print('✓ 清理 NetworkCheckController（设置页）');
    }
  }

  /// 清理 VersionCheckController
  void _cleanupVersionCheckController() {
    if (Get.isRegistered<VersionCheckController>()) {
      Get.delete<VersionCheckController>(force: true);
      print('✓ 清理 VersionCheckController（设置页）');
    }
  }

  /// 清理 ExternalCardReaderService
  void _cleanupExternalCardReaderService() {
    if (Get.isRegistered<ExternalCardReaderService>()) {
      final service = Get.find<ExternalCardReaderService>();
      service.onClose();
    }
  }

  /// 清理 MwCardReaderController
  void _cleanupMwCardReaderController() {
    // 清理 MW 读卡器控制器
    if (Get.isRegistered<MwCardReaderController>()) {
      Get.delete<MwCardReaderController>(force: true);
      print('✓ 清理 MwCardReaderController（设置页）');
    }

    // 清理 MW 调试日志窗口控制器
    const String debugTag = 'mw_card_reader';
    if (Get.isRegistered<DebugLogWindowController>(tag: debugTag)) {
      Get.delete<DebugLogWindowController>(tag: debugTag, force: true);
      print('✓ 清理 MwCardReader DebugLogWindowController（设置页）');
    }
  }
}
