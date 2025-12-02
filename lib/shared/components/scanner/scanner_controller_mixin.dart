import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/barcode_scanner_model.dart';
import '../../../data/services/barcode_scanner_service.dart';

/// 扫描器控制器 Mixin
/// 提供扫描器功能的快速集成，自动管理生命周期
/// 
/// 使用方法：
/// ```dart
/// class MyController extends GetxController with ScannerControllerMixin {
///   @override
///   void onScanSuccess(ScanResult result) {
///     // 处理扫描结果
///     print('扫码内容: ${result.content}');
///   }
/// }
/// ```
mixin ScannerControllerMixin on GetxController {
  // 获取全局扫描器服务
  final BarcodeScannerService _scannerService = Get.find<BarcodeScannerService>();
  
  /// 扫描器服务访问器
  BarcodeScannerService get scannerService => _scannerService;
  
  /// 是否自动启动监听（默认true）
  bool get autoStartListening => true;
  
  /// 是否在销毁时自动停止监听（默认true）
  bool get autoStopOnDispose => true;
  
  /// 扫描结果监听器（子类可选择性监听）
  Worker? _scanResultWorker;
  
  @override
  void onInit() {
    super.onInit();
    _setupScanListener();
    
    // 自动启动监听
    if (autoStartListening) {
      _autoStartListening();
    }
  }
  
  @override
  void onClose() {
    // 清理监听器
    _scanResultWorker?.dispose();
    
    // 自动停止监听
    if (autoStopOnDispose && _scannerService.isListening.value) {
      _scannerService.stopListening();
    }
    
    super.onClose();
  }
  
  /// 设置扫描结果监听
  void _setupScanListener() {
    _scanResultWorker = ever(
      _scannerService.scanData,
      (ScanResult? result) {
        if (result != null) {
          onScanSuccess(result);
        }
      },
    );
  }
  
  /// 自动启动监听
  Future<void> _autoStartListening() async {
    // 等待服务就绪
    await Future.delayed(const Duration(milliseconds: 100));
    
    // 如果已经在监听或已选择设备，直接启动
    if (_scannerService.selectedScanner.value != null) {
      await startScanning();
    } else {
      // 否则先扫描设备
      await _scannerService.scanUsbScanners();
      // scanUsbScanners会自动选择并启动第一个已连接设备
    }
  }
  
  /// 启动扫描（子类或手动调用）
  Future<void> startScanning() async {
    if (!_scannerService.isListening.value) {
      await _scannerService.startListening();
    }
  }
  
  /// 停止扫描（子类或手动调用）
  Future<void> stopScanning() async {
    if (_scannerService.isListening.value) {
      await _scannerService.stopListening();
    }
  }
  
  /// 扫描成功回调（子类必须实现）
  /// [result] 扫描结果数据
  void onScanSuccess(ScanResult result);
  
  /// 扫描错误回调（可选重写）
  /// [error] 错误信息
  void onScanError(String error) {
    // 默认实现：显示错误提示
    Get.snackbar(
      '扫描错误',
      error,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.withOpacity(0.8),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }
}
