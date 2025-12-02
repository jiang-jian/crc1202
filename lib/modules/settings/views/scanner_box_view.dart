import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_theme.dart';
import '../../../data/services/scanner_box_service.dart';
import '../../../data/models/scanner_box_model.dart';
import '../../../core/widgets/toast.dart';

/// 扫码盒子配置页面
class ScannerBoxView extends StatelessWidget {
  const ScannerBoxView({super.key});

  @override
  Widget build(BuildContext context) {
    // 确保服务已注册（使用permanent确保不会被销毁）
    final service = Get.put(ScannerBoxService(), permanent: true);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.spacingL),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧：设备信息卡片
          SizedBox(
            width: 400.w,
            child: _buildDeviceInfoCard(service),
          ),
          SizedBox(width: 24.w),
          // 右侧：扫码数据展示区
          Expanded(
            child: _buildScanDataArea(service),
          ),
        ],
      ),
    );
  }

  /// 左侧：设备信息卡片
  Widget _buildDeviceInfoCard(ScannerBoxService service) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 20.w,
              vertical: 16.h,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.r),
                topRight: Radius.circular(12.r),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  size: 24.sp,
                  color: AppTheme.primaryColor,
                ),
                SizedBox(width: 12.w),
                Text(
                  '扫码盒子设备',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // 设备信息内容
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Obx(() {
              final device = service.connectedDevice.value;
              final status = service.deviceStatus.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 设备状态
                  _buildStatusRow(status, service),
                  SizedBox(height: 20.h),
                  // 设备信息
                  if (device != null) ..._buildDeviceDetails(device),
                  if (device == null) _buildNoDeviceHint(),
                  SizedBox(height: 24.h),
                  // 操作按钮
                  _buildActionButtons(service, device),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 设备状态行
  Widget _buildStatusRow(ScannerBoxStatus status, ScannerBoxService service) {
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case ScannerBoxStatus.connected:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case ScannerBoxStatus.scanning:
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        break;
      case ScannerBoxStatus.disconnected:
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        break;
      case ScannerBoxStatus.error:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20.sp),
          SizedBox(width: 8.w),
          Text(
            '状态：${service.getStatusText()}',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 设备详细信息
  List<Widget> _buildDeviceDetails(ScannerBoxDevice device) {
    return [
      _buildInfoRow('设备名称', device.displayName),
      SizedBox(height: 12.h),
      _buildInfoRow('序列号', device.serialNumber ?? '未知'),
      SizedBox(height: 12.h),
      _buildInfoRow('供应商ID', '0x${device.vendorId.toRadixString(16).toUpperCase()}'),
      SizedBox(height: 12.h),
      _buildInfoRow('产品ID', '0x${device.productId.toRadixString(16).toUpperCase()}'),
      SizedBox(height: 12.h),
      _buildInfoRow(
        '授权状态',
        device.isAuthorized ? '已授权' : '未授权',
        valueColor: device.isAuthorized ? Colors.green : Colors.orange,
      ),
    ];
  }

  /// 信息行
  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80.w,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              color: valueColor ?? AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// 无设备提示
  Widget _buildNoDeviceHint() {
    return Container(
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: [
          Icon(
            Icons.usb_off,
            size: 48.sp,
            color: Colors.grey[400],
          ),
          SizedBox(height: 12.h),
          Text(
            '未检测到扫码盒子',
            style: TextStyle(
              fontSize: 14.sp,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '请连接设备后点击扫描按钮',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  /// 操作按钮
  Widget _buildActionButtons(ScannerBoxService service, ScannerBoxDevice? device) {
    return Column(
      children: [
        // 扫描/授权按钮
        if (device == null || !device.isAuthorized)
          SizedBox(
            width: double.infinity,
            height: 44.h,
            child: ElevatedButton.icon(
              onPressed: () => _handleScanOrAuthorize(service, device),
              icon: Icon(device == null ? Icons.search : Icons.vpn_key, size: 18.sp),
              label: Text(
                device == null ? '扫描设备' : '请求授权',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ),
        // 断开连接按钮
        if (device != null && device.isAuthorized) ...[
          SizedBox(
            width: double.infinity,
            height: 44.h,
            child: ElevatedButton.icon(
              onPressed: () => _handleDisconnect(service),
              icon: Icon(Icons.power_settings_new, size: 18.sp),
              label: Text(
                '断开连接',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 右侧：扫码数据展示区
  Widget _buildScanDataArea(ScannerBoxService service) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 20.w,
              vertical: 16.h,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.r),
                topRight: Radius.circular(12.r),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 24.sp,
                  color: AppTheme.primaryColor,
                ),
                SizedBox(width: 12.w),
                Text(
                  '扫码记录',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                // 清空按钮
                Builder(
                  builder: (context) => Obx(() {
                    if (service.scanHistory.isEmpty) return const SizedBox.shrink();
                    return TextButton.icon(
                      onPressed: () => _handleClearHistory(service, context),
                      icon: Icon(Icons.delete_outline, size: 16.sp),
                      label: Text('清空', style: TextStyle(fontSize: 13.sp)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red[400],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          // 扫码记录列表
          Expanded(
            child: Obx(() {
              final history = service.scanHistory;

              if (history.isEmpty) {
                return _buildEmptyScanHint();
              }

              return ListView.separated(
                padding: EdgeInsets.all(20.w),
                itemCount: history.length,
                separatorBuilder: (context, index) => Divider(height: 24.h),
                itemBuilder: (context, index) {
                  final scan = history[index];
                  return _buildScanItem(scan, index);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 空扫码提示
  Widget _buildEmptyScanHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_2_outlined,
            size: 64.sp,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16.h),
          Text(
            '暂无扫码记录',
            style: TextStyle(
              fontSize: 16.sp,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '使用扫码盒子扫描二维码后，数据将显示在这里',
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  /// 扫码记录项
  Widget _buildScanItem(ScanData scan, int index) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: index == 0 ? AppTheme.primaryColor.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: index == 0 ? AppTheme.primaryColor.withOpacity(0.2) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间和类型
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: scan.type == 'QR' ? Colors.blue[100] : Colors.green[100],
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  scan.type,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: scan.type == 'QR' ? Colors.blue[700] : Colors.green[700],
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                scan.formattedTime,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              if (index == 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    '最新',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          // 扫码内容
          Row(
            children: [
              Expanded(
                child: Text(
                  scan.content,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              // 复制按钮
              IconButton(
                onPressed: () => _handleCopy(scan.content),
                icon: Icon(Icons.copy, size: 18.sp),
                color: AppTheme.primaryColor,
                tooltip: '复制',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== 事件处理 ====================

  /// 扫描或授权设备
  Future<void> _handleScanOrAuthorize(ScannerBoxService service, ScannerBoxDevice? device) async {
    if (device == null) {
      // 扫描设备
      Toast.info(message: '正在扫描设备...');
      final devices = await service.scanDevices();

      if (devices.isEmpty) {
        Toast.error(message: '未检测到扫码盒子，请检查设备连接');
        return;
      }

      // 自动请求授权第一个设备
      await service.requestAuthorization(devices.first);
      Toast.success(message: '设备授权成功');

      // 自动开始扫描
      await service.startScanning();
    } else {
      // 请求授权
      Toast.info(message: '正在请求授权...');
      final success = await service.requestAuthorization(device);

      if (success) {
        Toast.success(message: '授权成功');
        // 自动开始扫描
        await service.startScanning();
      } else {
        Toast.error(message: '授权失败');
      }
    }
  }

  /// 断开连接
  Future<void> _handleDisconnect(ScannerBoxService service) async {
    await service.disconnect();
    Toast.success(message: '已断开设备连接');
  }

  /// 清空历史记录
  void _handleClearHistory(ScannerBoxService service, BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有扫码记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              service.clearHistory();
              Navigator.pop(dialogContext);
              Toast.success(message: '已清空扫码记录');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 复制到剪贴板
  void _handleCopy(String content) {
    Clipboard.setData(ClipboardData(text: content));
    Toast.success(message: '已复制到剪贴板');
  }
}
