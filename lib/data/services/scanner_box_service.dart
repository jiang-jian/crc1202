import 'dart:async';
import 'package:get/get.dart';
import '../models/scanner_box_model.dart';
import '../plugins/scanner_box_plugin.dart';

/// 扫码盒子服务（已集成真实硬件接口）
class ScannerBoxService extends GetxService {
  // ==================== 事件订阅 ====================

  StreamSubscription? _scanResultSubscription;
  StreamSubscription? _deviceAttachedSubscription;
  StreamSubscription? _deviceDetachedSubscription;
  StreamSubscription? _permissionGrantedSubscription;
  StreamSubscription? _permissionDeniedSubscription;
  // ==================== 响应式状态 ====================

  /// 当前连接的设备
  final Rx<ScannerBoxDevice?> connectedDevice = Rx<ScannerBoxDevice?>(null);

  /// 设备状态
  final Rx<ScannerBoxStatus> deviceStatus = ScannerBoxStatus.disconnected.obs;

  /// 扫码历史记录
  final RxList<ScanData> scanHistory = <ScanData>[].obs;

  /// 最新扫码数据
  final Rx<ScanData?> latestScan = Rx<ScanData?>(null);

  /// 是否正在扫描
  final RxBool isScanning = false.obs;

  // ==================== 初始化 ====================

  @override
  void onInit() {
    super.onInit();
    print('[ScannerBox] 服务初始化');
    _initPlugin();
    _initMockData(); // 保留模拟数据用于开发测试
  }

  /// 初始化硬件插件
  void _initPlugin() {
    print('[ScannerBox] 初始化硬件插件');
    ScannerBoxPlugin.initialize();

    // 监听扫码结果
    _scanResultSubscription = ScannerBoxPlugin.onScanResult.listen((result) {
      _handleScanResult(result);
    });

    // 监听设备连接
    _deviceAttachedSubscription = ScannerBoxPlugin.onDeviceAttached.listen((_) {
      print('[ScannerBox] 检测到设备连接');
      // 自动重新扫描设备
      scanDevices();
    });

    // 监听设备断开
    _deviceDetachedSubscription = ScannerBoxPlugin.onDeviceDetached.listen((_) {
      print('[ScannerBox] 检测到设备断开');
      if (connectedDevice.value != null) {
        disconnect();
      }
    });

    // 监听权限授予
    _permissionGrantedSubscription = ScannerBoxPlugin.onPermissionGranted
        .listen((data) {
          print('[ScannerBox] USB权限已授予: ${data["deviceName"]}');
          // 自动开始监听扫码
          startScanning();
        });

    // 监听权限拒绝
    _permissionDeniedSubscription = ScannerBoxPlugin.onPermissionDenied.listen((
      deviceId,
    ) {
      print('[ScannerBox] USB权限被拒绝: $deviceId');
      deviceStatus.value = ScannerBoxStatus.error;
    });
  }

  /// 处理扫码结果
  void _handleScanResult(Map<String, dynamic> result) {
    print('[ScannerBox] 收到扫码结果: $result');

    final scanData = ScanData(
      timestamp: DateTime.now(),
      content: result['content']?.toString() ?? '',
      type: result['type']?.toString() ?? 'Unknown',
    );

    addScanData(scanData);
  }

  /// 初始化模拟数据（测试用）
  void _initMockData() {
    // 模拟一个已连接的设备
    connectedDevice.value = ScannerBoxDevice(
      deviceId: 'mock_scanner_001',
      deviceName: 'USB扫码盒子',
      vendorId: 1234,
      productId: 5678,
      serialNumber: 'SN20250101001',
      manufacturer: '虚拟厂商',
      productName: '高速扫码盒子 Pro',
      isConnected: true,
      isAuthorized: true,
    );
    deviceStatus.value = ScannerBoxStatus.connected;

    // 添加一些模拟扫码记录
    scanHistory.addAll([
      ScanData(
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        content: 'https://example.com/product/12345',
        type: 'QR',
      ),
      ScanData(
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
        content: '9787115123456',
        type: 'Barcode',
      ),
    ]);

    print('[ScannerBox] 模拟数据加载完成');
  }

  // ==================== 设备管理 ====================

  /// 扫描USB设备（调用真实硬件接口）
  Future<List<ScannerBoxDevice>> scanDevices() async {
    print('[ScannerBox] 开始扫描设备...');

    try {
      // 调用真实硬件插件扫描设备
      final devices = await ScannerBoxPlugin.scanDevices();
      print('[ScannerBox] 扫描完成，发现 ${devices.length} 个设备');
      return devices;
    } catch (e) {
      print('[ScannerBox] 扫描设备失败: $e');
      // 降级到模拟数据
      return _getMockDevices();
    }
  }

  /// 获取模拟设备列表（开发测试用）
  List<ScannerBoxDevice> _getMockDevices() {
    return [
      ScannerBoxDevice(
        deviceId: 'mock_scanner_001',
        deviceName: 'USB扫码盒子（模拟）',
        vendorId: 1234,
        productId: 5678,
        serialNumber: 'SN20250101001',
        manufacturer: '虚拟厂商',
        productName: '高速扫码盒子 Pro',
        isConnected: false,
        isAuthorized: false,
      ),
    ];
  }

  /// 请求设备授权（调用真实硬件接口）
  Future<bool> requestAuthorization(ScannerBoxDevice device) async {
    print('[ScannerBox] 请求授权设备: ${device.displayName}');

    try {
      // 调用真实硬件插件请求USB权限
      final hasPermission = await ScannerBoxPlugin.requestPermission(
        device.deviceId,
      );

      if (hasPermission) {
        // 已有权限，立即连接
        connectedDevice.value = device.copyWith(
          isConnected: true,
          isAuthorized: true,
        );
        deviceStatus.value = ScannerBoxStatus.connected;
        print('[ScannerBox] 设备已有权限，直接连接');

        // 自动开始监听扫码
        await startScanning();
        return true;
      } else {
        // 权限请求已发起，等待用户授权
        // 结果将通过 onPermissionGranted 或 onPermissionDenied 回调返回
        print('[ScannerBox] 权限请求已发起，等待用户授权...');
        return false;
      }
    } catch (e) {
      print('[ScannerBox] 请求授权失败: $e');
      deviceStatus.value = ScannerBoxStatus.error;
      return false;
    }
  }

  /// 断开设备连接
  Future<void> disconnect() async {
    print('[ScannerBox] 断开设备连接');
    await Future.delayed(const Duration(milliseconds: 500));

    connectedDevice.value = null;
    deviceStatus.value = ScannerBoxStatus.disconnected;
    isScanning.value = false;

    print('[ScannerBox] 已断开连接');
  }

  // ==================== 扫码功能 ====================

  /// 开始监听扫码数据（调用真实硬件接口）
  Future<void> startScanning() async {
    if (connectedDevice.value == null) {
      print('[ScannerBox] 错误：未连接设备');
      return;
    }

    if (isScanning.value) {
      print('[ScannerBox] 已经在扫描中');
      return;
    }

    print('[ScannerBox] 开始监听扫码数据');

    try {
      // 调用真实硬件插件开始监听
      final success = await ScannerBoxPlugin.startListening();

      if (success) {
        isScanning.value = true;
        deviceStatus.value = ScannerBoxStatus.scanning;
        print('[ScannerBox] 扫码监听已启动');
      } else {
        print('[ScannerBox] 启动扫码监听失败');
        deviceStatus.value = ScannerBoxStatus.error;
      }
    } catch (e) {
      print('[ScannerBox] 启动扫码监听异常: $e');
      deviceStatus.value = ScannerBoxStatus.error;
    }
  }

  /// 停止监听扫码数据（调用真实硬件接口）
  Future<void> stopScanning() async {
    if (!isScanning.value) {
      print('[ScannerBox] 未在扫描中，无需停止');
      return;
    }

    print('[ScannerBox] 停止监听扫码数据');

    try {
      // 调用真实硬件插件停止监听
      await ScannerBoxPlugin.stopListening();
      isScanning.value = false;
      deviceStatus.value = ScannerBoxStatus.connected;
      print('[ScannerBox] 扫码监听已停止');
    } catch (e) {
      print('[ScannerBox] 停止扫码监听异常: $e');
      isScanning.value = false;
      deviceStatus.value = ScannerBoxStatus.connected;
    }
  }

  /// 添加扫码数据（供底层调用）
  void addScanData(ScanData data) {
    print('[ScannerBox] 收到扫码数据: ${data.content}');
    print('[ScannerBox] 当前历史记录数量: ${scanHistory.length}');

    latestScan.value = data;
    scanHistory.insert(0, data); // 最新的在前面

    print('[ScannerBox] 添加后历史记录数量: ${scanHistory.length}');

    // 限制历史记录数量（最多保留100条）
    if (scanHistory.length > 100) {
      scanHistory.removeRange(100, scanHistory.length);
    }

    // 强制刷新UI
    scanHistory.refresh();
  }

  /// 清空扫码历史
  void clearHistory() {
    print('[ScannerBox] 清空扫码历史');
    scanHistory.clear();
    latestScan.value = null;
  }

  // ==================== 工具方法 ====================

  /// 获取设备状态文本
  String getStatusText() {
    switch (deviceStatus.value) {
      case ScannerBoxStatus.disconnected:
        return '未连接';
      case ScannerBoxStatus.connected:
        return '已连接';
      case ScannerBoxStatus.scanning:
        return '扫描中';
      case ScannerBoxStatus.error:
        return '错误';
    }
  }

  @override
  void onClose() {
    print('[ScannerBox] 服务销毁');

    // 取消所有事件订阅
    _scanResultSubscription?.cancel();
    _deviceAttachedSubscription?.cancel();
    _deviceDetachedSubscription?.cancel();
    _permissionGrantedSubscription?.cancel();
    _permissionDeniedSubscription?.cancel();

    // 停止扫描并断开连接
    if (isScanning.value) {
      stopScanning();
    }
    disconnect();

    super.onClose();
  }
}
