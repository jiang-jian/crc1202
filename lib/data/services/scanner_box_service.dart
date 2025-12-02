import 'dart:async';
import 'package:get/get.dart';
import '../models/scanner_box_model.dart';
import 'barcode_scanner_service.dart';

/// 扫码盒子服务（复用BarcodeScannerService，避免MethodChannel冲突）
/// 
/// 🔧 架构修复说明：
/// 扫码盒子本质上就是USB HID扫描器，与普通扫描器使用相同的硬件协议。
/// 原先的实现通过独立的ScannerBoxPlugin注册MethodCallHandler，导致覆盖了
/// BarcodeScannerService的handler，造成两者无法同时工作的问题。
/// 
/// 修复方案：
/// - 移除独立的ScannerBoxPlugin
/// - 直接依赖和监听BarcodeScannerService的事件
/// - 两个服务共享同一个原生通信层，互不干扰
class ScannerBoxService extends GetxService {
  // ==================== 依赖注入 ====================
  
  /// 复用扫描器服务（共享原生通信层）
  late final BarcodeScannerService _scannerService;

  // ==================== 事件订阅 ====================

  StreamSubscription? _scanResultSubscription;
  StreamSubscription? _deviceStatusSubscription;

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
    
    // 获取扫描器服务实例
    _scannerService = Get.find<BarcodeScannerService>();
    
    // 监听扫描器服务的事件
    _initEventListeners();
    
    // 加载模拟数据（仅用于开发测试）
    _initMockData();
  }

  /// 初始化事件监听器（监听BarcodeScannerService的事件）
  void _initEventListeners() {
    print('[ScannerBox] 初始化事件监听器');

    // 监听扫码结果
    _scanResultSubscription = _scannerService.scanData.listen((scanResult) {
      if (scanResult != null && isScanning.value) {
        _handleScanResult(scanResult);
      }
    });

    // 监听设备状态变化
    _deviceStatusSubscription = _scannerService.isListening.listen((listening) {
      if (listening && connectedDevice.value != null) {
        deviceStatus.value = ScannerBoxStatus.scanning;
        isScanning.value = true;
      } else if (connectedDevice.value != null) {
        deviceStatus.value = ScannerBoxStatus.connected;
        isScanning.value = false;
      }
    });

    print('[ScannerBox] 事件监听器初始化完成');
  }

  /// 处理扫码结果（来自BarcodeScannerService）
  void _handleScanResult(dynamic scanResult) {
    print('[ScannerBox] 收到扫码结果: ${scanResult.content}');

    final scanData = ScanData(
      timestamp: scanResult.timestamp ?? DateTime.now(),
      content: scanResult.content ?? '',
      type: scanResult.type ?? 'Unknown',
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

  /// 扫描USB设备（复用BarcodeScannerService）
  Future<List<ScannerBoxDevice>> scanDevices() async {
    print('[ScannerBox] 开始扫描设备...');

    try {
      // 调用扫描器服务扫描设备
      await _scannerService.scanUsbScanners();
      
      // 转换为ScannerBoxDevice格式
      final devices = _scannerService.detectedScanners
          .map((scanner) => ScannerBoxDevice(
                deviceId: scanner.deviceId,
                deviceName: scanner.deviceName,
                vendorId: scanner.vendorId,
                productId: scanner.productId,
                serialNumber: scanner.serialNumber,
                manufacturer: scanner.manufacturer,
                productName: scanner.productName,
                isConnected: scanner.isConnected,
                isAuthorized: scanner.isConnected,
              ))
          .toList();
      
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

  /// 请求设备授权（复用BarcodeScannerService）
  Future<bool> requestAuthorization(ScannerBoxDevice device) async {
    print('[ScannerBox] 请求授权设备: ${device.displayName}');

    try {
      // 调用扫描器服务请求权限
      final hasPermission = await _scannerService.requestPermission(
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

    // 停止扫描器服务的监听
    await _scannerService.stopListening();

    print('[ScannerBox] 已断开连接');
  }

  // ==================== 扫码功能 ====================

  /// 开始监听扫码数据（复用BarcodeScannerService）
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
      // 调用扫描器服务开始监听
      await _scannerService.startListening();
      
      isScanning.value = true;
      deviceStatus.value = ScannerBoxStatus.scanning;
      print('[ScannerBox] 扫码监听已启动');
    } catch (e) {
      print('[ScannerBox] 启动扫码监听异常: $e');
      deviceStatus.value = ScannerBoxStatus.error;
    }
  }

  /// 停止监听扫码数据（复用BarcodeScannerService）
  Future<void> stopScanning() async {
    if (!isScanning.value) {
      print('[ScannerBox] 未在扫描中，无需停止');
      return;
    }

    print('[ScannerBox] 停止监听扫码数据');

    try {
      // 调用扫描器服务停止监听
      await _scannerService.stopListening();
      
      isScanning.value = false;
      deviceStatus.value = ScannerBoxStatus.connected;
      print('[ScannerBox] 扫码监听已停止');
    } catch (e) {
      print('[ScannerBox] 停止扫码监听异常: $e');
      isScanning.value = false;
      deviceStatus.value = ScannerBoxStatus.connected;
    }
  }

  /// 添加扫码数据
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
    _deviceStatusSubscription?.cancel();

    // 停止扫描并断开连接
    if (isScanning.value) {
      stopScanning();
    }
    disconnect();

    super.onClose();
  }
}
