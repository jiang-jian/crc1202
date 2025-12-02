/// DebugLogWindow
/// 功能：全局可拖拽、可展开折叠的调试日志窗口
/// 作者：AI 自动生成
/// 更新时间：2025-11-20

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../app/theme/app_theme.dart';

/// 调试日志窗口控制器
class DebugLogWindowController extends GetxController {
  // 日志列表
  final logs = <String>[].obs;
  final maxLogs = 500;

  // 窗口状态
  final isExpanded = true.obs;
  final position = Rx<Offset?>(null);

  // 过滤选项
  final showInfo = true.obs;
  final showSuccess = true.obs;
  final showError = true.obs;

  /// 添加日志
  void addLog(String message, {String type = 'info'}) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final icon = type == 'success'
        ? '✓'
        : type == 'error'
        ? '✗'
        : '•';
    logs.insert(0, '[$timestamp] $icon $message');

    if (logs.length > maxLogs) {
      logs.removeRange(maxLogs, logs.length);
    }
  }

  /// 清空日志
  void clearLogs() {
    logs.clear();
    addLog('日志已清空');
  }

  /// 切换展开/折叠
  void toggleExpanded() {
    isExpanded.value = !isExpanded.value;
  }

  /// 更新位置
  void updatePosition(Offset newPosition) {
    position.value = newPosition;
  }

  /// 过滤后的日志
  List<String> get filteredLogs {
    return logs.where((log) {
      if (!showInfo.value && log.contains('•')) return false;
      if (!showSuccess.value && log.contains('✓')) return false;
      if (!showError.value && log.contains('✗')) return false;
      return true;
    }).toList();
  }
}

/// 调试日志窗口组件
class DebugLogWindow extends StatefulWidget {
  final String tag;
  final double? width;
  final double? height;
  final double? collapsedHeight;

  const DebugLogWindow({
    super.key,
    required this.tag,
    this.width,
    this.height,
    this.collapsedHeight,
  });

  @override
  State<DebugLogWindow> createState() => _DebugLogWindowState();
}

class _DebugLogWindowState extends State<DebugLogWindow> {
  late DebugLogWindowController controller;

  @override
  void initState() {
    super.initState();
    // 确保控制器已注册
    if (!Get.isRegistered<DebugLogWindowController>(tag: widget.tag)) {
      Get.put(DebugLogWindowController(), tag: widget.tag);
    }
    controller = Get.find<DebugLogWindowController>(tag: widget.tag);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 动态计算当前窗口高度
      final currentHeight = controller.isExpanded.value
          ? (widget.height ?? 500.h)
          : 50.h;

      // 初始化默认位置为右下角
      if (controller.position.value == null) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final windowWidth = widget.width ?? 400.w;
        controller.position.value = Offset(
          screenWidth - windowWidth - 240.w,
          screenHeight - currentHeight - 120.h,
        );
      }

      return Positioned(
        left: controller.position.value!.dx,
        top: controller.position.value!.dy,
        child: GestureDetector(
          onPanUpdate: (details) {
            final newPosition = controller.position.value! + details.delta;
            // 限制在屏幕范围内
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            final windowWidth = widget.width ?? 400.w;

            final clampedPosition = Offset(
              newPosition.dx.clamp(0, screenWidth - windowWidth),
              newPosition.dy.clamp(0, screenHeight - currentHeight),
            );
            controller.updatePosition(clampedPosition);
          },
          child: _buildWindow(),
        ),
      );
    });
  }

  Widget _buildWindow() {
    final expandedHeight = widget.height ?? 500.h;
    final collapsedHeight = 50.h;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: widget.width ?? 400.w,
      height: controller.isExpanded.value ? expandedHeight : collapsedHeight,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusDefault),
        border: Border.all(color: AppTheme.borderColor, width: 1.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusDefault),
        child: Column(
          children: [
            _buildHeader(),
            if (controller.isExpanded.value) ...[
              _buildFilterBar(),
              Expanded(child: _buildLogList()),
            ],
          ],
        ),
      ),
    );
  }

  /// 顶部标题栏
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: AppTheme.backgroundGrey,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.borderRadiusDefault),
          topRight: Radius.circular(AppTheme.borderRadiusDefault),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.terminal, size: 18.sp, color: AppTheme.infoColor),
          SizedBox(width: AppTheme.spacingS),
          Text(
            '调试日志',
            style: AppTheme.textBody.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(width: AppTheme.spacingS),
          Obx(
            () => Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingS,
                vertical: 2.h,
              ),
              decoration: BoxDecoration(
                color: AppTheme.infoBgColor,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusRound),
              ),
              child: Text(
                '${controller.filteredLogs.length}',
                style: AppTheme.textCaption.copyWith(
                  color: AppTheme.infoColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Spacer(),
          // 清空按钮
          _buildHeaderButton(
            icon: Icons.clear_all,
            tooltip: '清空日志',
            onTap: controller.clearLogs,
          ),
          SizedBox(width: AppTheme.spacingS),
          // 展开/折叠按钮
          Obx(
            () => _buildHeaderButton(
              icon: controller.isExpanded.value
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_up,
              tooltip: controller.isExpanded.value ? '折叠' : '展开',
              onTap: controller.toggleExpanded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusRound),
        child: Container(
          padding: EdgeInsets.all(4.w),
          child: Icon(icon, size: 16.sp, color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  /// 过滤栏
  Widget _buildFilterBar() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 1.w),
        ),
      ),
      child: Row(
        children: [
          Text('过滤: ', style: AppTheme.textCaption),
          SizedBox(width: AppTheme.spacingS),
          _buildFilterChip(
            label: '信息',
            icon: '•',
            color: AppTheme.textSecondary,
            value: controller.showInfo.value,
            onChanged: (value) => controller.showInfo.value = value,
          ),
          SizedBox(width: AppTheme.spacingS),
          _buildFilterChip(
            label: '成功',
            icon: '✓',
            color: AppTheme.successColor,
            value: controller.showSuccess.value,
            onChanged: (value) => controller.showSuccess.value = value,
          ),
          SizedBox(width: AppTheme.spacingS),
          _buildFilterChip(
            label: '错误',
            icon: '✗',
            color: AppTheme.errorColor,
            value: controller.showError.value,
            onChanged: (value) => controller.showError.value = value,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String icon,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusRound),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingS,
          vertical: 4.h,
        ),
        decoration: BoxDecoration(
          color: value ? color.withValues(alpha: 0.1) : AppTheme.backgroundGrey,
          border: Border.all(
            color: value ? color : AppTheme.borderColor,
            width: 1.w,
          ),
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusRound),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              icon,
              style: AppTheme.textCaption.copyWith(
                color: value ? color : AppTheme.textTertiary,
              ),
            ),
            SizedBox(width: 4.w),
            Text(
              label,
              style: AppTheme.textCaption.copyWith(
                color: value ? color : AppTheme.textTertiary,
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 日志列表
  Widget _buildLogList() {
    return Obx(() {
      final filteredLogs = controller.filteredLogs;
      if (filteredLogs.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox, size: 48.sp, color: AppTheme.textTertiary),
              SizedBox(height: AppTheme.spacingS),
              Text('暂无日志', style: AppTheme.textCaption),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.all(AppTheme.spacingM),
        reverse: false,
        itemCount: filteredLogs.length,
        itemBuilder: (context, index) {
          final log = filteredLogs[index];
          final isSuccess = log.contains('✓');
          final isError = log.contains('✗');

          return Container(
            margin: EdgeInsets.only(bottom: AppTheme.spacingXS),
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingS,
              vertical: 6.h,
            ),
            decoration: BoxDecoration(
              color: isSuccess
                  ? AppTheme.successBgColor
                  : isError
                  ? AppTheme.errorBgColor
                  : AppTheme.backgroundGrey,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
            ),
            child: Text(
              log,
              style: AppTheme.textMini.copyWith(
                color: isSuccess
                    ? AppTheme.successColor
                    : isError
                    ? AppTheme.errorColor
                    : AppTheme.textPrimary,
              ),
            ),
          );
        },
      );
    });
  }
}

/// 全局日志工具类
class DebugLogger {
  static void log(String tag, String message, {String type = 'info'}) {
    if (!Get.isRegistered<DebugLogWindowController>(tag: tag)) {
      Get.put(DebugLogWindowController(), tag: tag);
    }
    final controller = Get.find<DebugLogWindowController>(tag: tag);
    controller.addLog(message, type: type);
  }

  static void info(String tag, String message) {
    log(tag, message, type: 'info');
  }

  static void success(String tag, String message) {
    log(tag, message, type: 'success');
  }

  static void error(String tag, String message) {
    log(tag, message, type: 'error');
  }

  static void clear(String tag) {
    if (Get.isRegistered<DebugLogWindowController>(tag: tag)) {
      final controller = Get.find<DebugLogWindowController>(tag: tag);
      controller.clearLogs();
    }
  }
}
