import 'package:ailand_pos/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../data/services/external_printer_service.dart';
import '../../../data/models/external_printer_model.dart';
import '../../../core/widgets/toast.dart';

/// 外置打印机配置页面（优化版）
/// 移除边框，垂直分3块：扫描、信息、测试
class ExternalPrinterView extends StatelessWidget {
  const ExternalPrinterView({super.key});

  @override
  Widget build(BuildContext context) {
    // 确保服务已注册
    ExternalPrinterService service;
    try {
      service = Get.find<ExternalPrinterService>();
    } catch (e) {
      return _buildErrorState();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          SizedBox(height: 32.h),
          Expanded(child: _buildContent(service)),
        ],
      ),
    );
  }

  /// 错误状态
  Widget _buildErrorState() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingL),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
            SizedBox(height: 24.h),
            Text(
              '外置打印机服务未初始化',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              '请在main.dart中添加服务初始化',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  /// 页面头部
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          ),
          child: Icon(Icons.usb, size: 32.sp, color: Colors.white),
        ),
        SizedBox(width: AppTheme.spacingDefault),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '外置打印机配置',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2C3E50),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              '管理USB外接打印机设备',
              style: TextStyle(fontSize: 16.sp, color: const Color(0xFF7F8C8D)),
            ),
          ],
        ),
      ],
    );
  }

  /// 主内容区域（无边框版）
  Widget _buildContent(ExternalPrinterService service) {
    return Obx(() {
      // 扫描中状态
      if (service.isScanning.value) {
        return _buildScanningState();
      }

      // 未检测到设备
      if (service.detectedPrinters.isEmpty) {
        return Column(
          children: [
            _buildScanButton(service),
            SizedBox(height: 32.h),
            Expanded(child: _buildEmptyState()),
          ],
        );
      }

      // 有设备，显示3块布局
      final selectedDevice = service.selectedPrinter.value;
      if (selectedDevice != null) {
        return _buildThreeColumnLayout(selectedDevice, service);
      }

      // 有设备但未选择，显示扫描按钮和设备列表
      return Column(
        children: [
          _buildScanButton(service),
          SizedBox(height: 32.h),
          Expanded(child: _buildDeviceList(service)),
        ],
      );
    });
  }

  /// 三列布局（扫描、信息、测试）- 紧凑版
  Widget _buildThreeColumnLayout(
    ExternalPrinterDevice device,
    ExternalPrinterService service,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 第1块：扫描USB设备按钮
          _buildScanButton(service),

          SizedBox(height: 24.h), // 压缩间距
          // 第2块：打印机基础信息（固定高度，避免Expanded导致的空白）
          _buildPrinterInfo(device),

          SizedBox(height: 24.h), // 压缩间距
          // 第3块：测试打印按钮和状态显示区域（固定高度）
          _buildTestSection(device, service),
        ],
      ),
    );
  }

  /// 扫描按钮
  Widget _buildScanButton(ExternalPrinterService service) {
    return Obx(
      () => SizedBox(
        height: 50.h,
        width: 400.w,
        child: ElevatedButton.icon(
          onPressed: service.isScanning.value
              ? null
              : () => service.scanUsbPrinters(),
          icon: service.isScanning.value
              ? SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(Icons.refresh, size: 22.sp),
          label: Text(
            service.isScanning.value ? '扫描中...' : '扫描USB设备',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  /// 打印机基础信息卡片
  Widget _buildPrinterInfo(ExternalPrinterDevice device) {
    return Container(
      constraints: BoxConstraints(maxWidth: 500.w),
      padding: EdgeInsets.all(AppTheme.spacingDefault), // 压缩内边距
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: const Color(0xFF9C27B0), width: 2.w),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 打印机名称和状态
          Row(
            children: [
              Icon(Icons.print, size: 28.sp, color: const Color(0xFF9C27B0)),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Text(
                  device.displayName,
                  style: TextStyle(
                    fontSize: 22.sp, // 增大打印机名称字号
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50), // 绿色高亮
                  borderRadius: BorderRadius.circular(
                    AppTheme.borderRadiusMedium,
                  ),
                ),
                child: Text(
                  '已连接',
                  style: TextStyle(
                    fontSize: 14.sp, // 增大字号
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h), // 压缩标题和信息之间的间距
          // 设备信息
          _buildInfoRow('厂商', device.manufacturer),
          SizedBox(height: 8.h), // 压缩信息行间距
          _buildInfoRow('USB ID', device.usbIdentifier),
          if (device.serialNumber != null) ...[
            SizedBox(height: 8.h), // 压缩信息行间距
            _buildInfoRow('序列号', device.serialNumber!),
          ],
        ],
      ),
    );
  }

  /// 信息行
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80.w,
          child: Text(
            '$label：',
            style: TextStyle(
              fontSize: 16.sp, // 增大标签字号
              color: AppTheme.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16.sp, // 增大值字号
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 测试区域（按钮 + 状态显示区域）- 固定高度避免位移
  Widget _buildTestSection(
    ExternalPrinterDevice device,
    ExternalPrinterService service,
  ) {
    return Obx(() {
      final isPrinting = service.isPrinting.value;
      final testPassed = service.testPrintSuccess.value;

      return Column(
        mainAxisSize: MainAxisSize.min, // 使用最小尺寸
        children: [
          // 测试打印按钮
          SizedBox(
            width: 400.w,
            height: 50.h,
            child: ElevatedButton.icon(
              onPressed: isPrinting ? null : () => _testPrint(device, service),
              icon: isPrinting
                  ? SizedBox(
                      width: 18.w,
                      height: 18.h,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.print, size: 22.sp),
              label: Text(
                isPrinting ? '打印中...' : '测试打印',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // 状态显示区域（固定高度60.h，避免出现时导致位移）
          SizedBox(
            height: 60.h, // 固定高度
            child: testPassed
                ? Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 24.w,
                          height: 24.h,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 16.sp,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          '测试通过',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(), // 未测试时显示空白但保持高度
          ),
        ],
      );
    });
  }

  /// 扫描中状态
  Widget _buildScanningState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 50.w,
            height: 50.h,
            child: CircularProgressIndicator(
              strokeWidth: 4.w,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF9C27B0),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            '正在扫描USB设备...',
            style: TextStyle(
              fontSize: 17.sp,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.usb_off, size: 64.sp, color: const Color(0xFFCCCCCC)),
          SizedBox(height: 24.h),
          Text(
            '未检测到USB打印机',
            style: TextStyle(
              fontSize: 18.sp,
              color: AppTheme.textTertiary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            '请连接USB打印机后点击扫描',
            style: TextStyle(fontSize: 15.sp, color: const Color(0xFFCCCCCC)),
          ),
          SizedBox(height: 8.h),
          Text(
            '支持：Epson、芯烨、佳博等品牌',
            style: TextStyle(
              fontSize: 13.sp,
              color: const Color(0xFFCCCCCC),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// 设备列表（未选择设备时显示）
  Widget _buildDeviceList(ExternalPrinterService service) {
    return ListView.separated(
      padding: EdgeInsets.only(bottom: 20.h),
      itemCount: service.detectedPrinters.length,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final device = service.detectedPrinters[index];
        return _buildDeviceCard(device, service);
      },
    );
  }

  /// 设备卡片（用于设备选择）
  Widget _buildDeviceCard(
    ExternalPrinterDevice device,
    ExternalPrinterService service,
  ) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingDefault),
      decoration: BoxDecoration(
        color: device.isConnected
            ? const Color(0xFFF3E5F5)
            : AppTheme.backgroundGrey,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(
          color: device.isConnected
              ? const Color(0xFF9C27B0)
              : AppTheme.borderColor,
          width: 2.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 设备名称和状态
          Row(
            children: [
              Icon(
                Icons.print,
                size: 24.sp,
                color: device.isConnected
                    ? const Color(0xFF9C27B0)
                    : AppTheme.textTertiary,
              ),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Text(
                  device.displayName,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: device.isConnected
                      ? const Color(0xFF9C27B0)
                      : AppTheme.textTertiary,
                  borderRadius: BorderRadius.circular(
                    AppTheme.borderRadiusMedium,
                  ),
                ),
                child: Text(
                  device.isConnected ? '已连接' : '未连接',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 14.h),

          // 设备信息
          _buildDeviceInfo('厂商', device.manufacturer),
          SizedBox(height: 8.h),
          _buildDeviceInfo('USB ID', device.usbIdentifier),
          if (device.serialNumber != null) ...[
            SizedBox(height: 8.h),
            _buildDeviceInfo('序列号', device.serialNumber!),
          ],

          SizedBox(height: 16.h),

          // 授权按钮
          SizedBox(
            width: double.infinity,
            height: 44.h,
            child: ElevatedButton.icon(
              onPressed: device.isConnected
                  ? () => service.requestPermission(device)
                  : null,
              icon: Icon(Icons.check_circle_outline, size: 20.sp),
              label: Text(
                '授权使用',
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 设备信息行
  Widget _buildDeviceInfo(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 75.w,
          child: Text(
            '$label：',
            style: TextStyle(
              fontSize: 14.sp,
              color: AppTheme.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 检查是否为同一设备（基于硬件标识）
  bool _isSameDevice(ExternalPrinterDevice d1, ExternalPrinterDevice d2) {
    // 必须 vendorId 和 productId 匹配（硬件型号）
    if (d1.vendorId != d2.vendorId || d1.productId != d2.productId) {
      return false;
    }

    // 如果有序列号，必须序列号也匹配（区分同型号设备）
    if (d1.serialNumber != null && d1.serialNumber!.isNotEmpty) {
      return d1.serialNumber == d2.serialNumber;
    }

    // 没有序列号，vendorId + productId 匹配即可
    return true;
  }

  /// 测试打印
  Future<void> _testPrint(
    ExternalPrinterDevice device,
    ExternalPrinterService service,
  ) async {
    // 防止重复点击
    if (service.isPrinting.value) {
      print('[ExternalPrinter] 测试打印正在进行中，忽略重复点击');
      return;
    }

    service.isPrinting.value = true;
    print('[ExternalPrinter] 开始测试打印，设备: ${device.displayName}');

    try {
      // 🎯 智能缓存：如果已有授权的同一设备，跳过扫描直接打印
      if (service.selectedPrinter.value != null &&
          _isSameDevice(service.selectedPrinter.value!, device) &&
          service.printerStatus.value == ExternalPrinterStatus.ready) {
        // ✅ 优化：信任 selectedPrinter 作为授权状态的来源
        // selectedPrinter 只有在 requestPermission 返回 true 时才会被设置
        // 因此 selectedPrinter != null 本身就意味着设备已授权
        // 无需再调用 hasPermission（避免 deviceId 不稳定问题）
        print('[ExternalPrinter] 检测到已授权缓存设备，直接打印');
        
        final result = await service.testPrint(service.selectedPrinter.value!);
        print('[ExternalPrinter] 打印结果: ${result.success}, 消息: ${result.message}');

        if (result.success) {
          service.testPrintSuccess.value = true;
        } else {
          Toast.error(message: '打印失败: ${result.message}');
        }
        return;
      }
      
      // 未命中智能缓存，执行完整流程（扫描→请求权限→打印）
      print('[ExternalPrinter] 未命中智能缓存，执行完整流程');

      // 重新扫描确认设备仍然连接
      print('[ExternalPrinter] 重新扫描设备...');
      await service.scanUsbPrinters();

      // 检查设备是否还在列表中
      // 🔧 FIX: 使用 vendorId + productId + serialNumber 匹配（稳定的硬件标识）
      // deviceId 在拔插后会变化，不能用于匹配
      final currentDevice = service.detectedPrinters.firstWhereOrNull(
        (d) {
          // 必须vendorId和productId匹配（硬件型号）
          if (d.vendorId != device.vendorId || 
              d.productId != device.productId) {
            return false;
          }
          
          // 如果原设备有序列号，必须序列号也匹配（区分同型号设备）
          if (device.serialNumber != null && 
              device.serialNumber!.isNotEmpty) {
            return d.serialNumber == device.serialNumber;
          }
          
          // 没有序列号，vendorId+productId匹配即可
          return true;
        },
      );

      if (currentDevice == null) {
        print('[ExternalPrinter] 设备已断开');
        Toast.error(message: '设备已断开，请重新扫描');
        return;
      }

      // 检查是否已有权限
      final alreadyHasPermission = await service.hasPermission(currentDevice);
      print('[ExternalPrinter] 权限检查结果: $alreadyHasPermission');

      if (!alreadyHasPermission) {
        // 请求USB设备权限（弹出系统对话框）
        print('[ExternalPrinter] 请求USB权限...');
        final hasPermission = await service.requestPermission(currentDevice);
        print('[ExternalPrinter] 权限请求结果: $hasPermission');
        
        if (!hasPermission) {
          // 用户拒绝授权，静默返回（不显示Toast，避免干扰用户）
          return;
        }
      }

      // 使用最新的设备信息进行打印
      print('[ExternalPrinter] 发送打印指令...');
      final result = await service.testPrint(currentDevice);
      print('[ExternalPrinter] 打印结果: ${result.success}, 消息: ${result.message}');

      if (result.success) {
        // 成功时不显示toast，只显示测试通过状态
        service.testPrintSuccess.value = true;
      } else {
        // 失败时显示错误信息
        Toast.error(message: '打印失败: ${result.message}');
      }
    } catch (e, stackTrace) {
      print('[ExternalPrinter] 测试打印异常: $e');
      print('[ExternalPrinter] 堆栈跟踪: $stackTrace');
      Toast.error(message: '打印失败: $e');
    } finally {
      service.isPrinting.value = false;
      print('[ExternalPrinter] 测试打印流程结束');
    }
  }
}
