import 'package:get/get.dart';
import '../../../data/models/barcode_scanner_model.dart';
import '../../../data/services/barcode_scanner_service.dart';

/// 扫描器工具类
/// 提供常用的扫描器操作方法
class ScannerUtils {
  ScannerUtils._(); // 私有构造函数，禁止实例化
  
  /// 获取扫描器服务实例
  static BarcodeScannerService get service => Get.find<BarcodeScannerService>();
  
  /// 快速启动扫描监听
  /// 
  /// [onScan] 扫描成功回调
  /// [onError] 扫描错误回调（可选）
  /// [autoSelectDevice] 是否自动选择第一个已连接设备（默认true）
  /// 
  /// 返回值：是否成功启动
  static Future<bool> quickStart({
    required Function(ScanResult) onScan,
    Function(String)? onError,
    bool autoSelectDevice = true,
  }) async {
    try {
      // 如果没有选择设备，先扫描设备
      if (service.selectedScanner.value == null) {
        await service.scanUsbScanners();
        
        if (autoSelectDevice && service.detectedScanners.isNotEmpty) {
          // 选择第一个已连接的设备
          final connectedDevice = service.detectedScanners
              .firstWhereOrNull((d) => d.isConnected);
          if (connectedDevice != null) {
            service.selectedScanner.value = connectedDevice;
          }
        }
      }
      
      // 启动监听
      if (service.selectedScanner.value != null) {
        await service.startListening();
        
        // 监听扫描结果
        _setupScanListener(onScan, onError);
        
        return true;
      } else {
        if (onError != null) {
          onError('未找到可用的扫描器设备');
        }
        return false;
      }
    } catch (e) {
      if (onError != null) {
        onError('启动扫描失败: $e');
      }
      return false;
    }
  }
  
  /// 设置扫描监听器
  static Worker? _scanWorker;
  
  static void _setupScanListener(
    Function(ScanResult) onScan,
    Function(String)? onError,
  ) {
    // 清除旧监听器
    _scanWorker?.dispose();
    
    // 监听扫描结果
    _scanWorker = ever(
      service.scanData,
      (ScanResult? result) {
        if (result != null) {
          onScan(result);
        }
      },
    );
    
    // 监听错误（如果提供了错误回调）
    if (onError != null) {
      ever(
        service.lastError,
        (String? error) {
          if (error != null) {
            onError(error);
          }
        },
      );
    }
  }
  
  /// 停止扫描并清理监听器
  static Future<void> stop() async {
    _scanWorker?.dispose();
    _scanWorker = null;
    await service.stopListening();
  }
  
  /// 一次性扫描（扫描后自动停止）
  /// 
  /// [onScan] 扫描成功回调
  /// [onError] 扫描错误回调（可选）
  /// [timeout] 超时时间（默认30秒）
  static Future<void> scanOnce({
    required Function(ScanResult) onScan,
    Function(String)? onError,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    Worker? worker;
    bool completed = false;
    
    try {
      // 启动扫描
      final started = await quickStart(
        onScan: (result) {
          if (!completed) {
            completed = true;
            onScan(result);
            // 自动停止
            stop();
          }
        },
        onError: onError,
      );
      
      if (!started) {
        return;
      }
      
      // 设置超时
      Future.delayed(timeout, () {
        if (!completed) {
          completed = true;
          worker?.dispose();
          stop();
          if (onError != null) {
            onError('扫描超时');
          }
        }
      });
    } catch (e) {
      if (onError != null) {
        onError('扫描失败: $e');
      }
    }
  }
  
  /// 验证扫描结果是否为商品条码
  /// 
  /// [result] 扫描结果
  /// 返回值：是否为有效的商品条码
  static bool isValidProductBarcode(ScanResult result) {
    // 检查类型
    if (result.type != 'BARCODE' && result.type != 'QR_CODE') {
      return false;
    }
    
    // 检查长度（一般商品条码为8-14位）
    final content = result.content.trim();
    if (content.length < 8 || content.length > 14) {
      return false;
    }
    
    // 检查是否为纯数字
    return RegExp(r'^\d+$').hasMatch(content);
  }
  
  /// 格式化条码内容（去除空格和特殊字符）
  static String formatBarcode(String barcode) {
    return barcode.trim().replaceAll(RegExp(r'[\s\-]'), '');
  }
  
  /// 检查扫描器是否就绪
  static bool get isReady {
    return service.isListening.value && 
           service.selectedScanner.value != null &&
           service.selectedScanner.value!.isConnected;
  }
  
  /// 获取当前扫描器设备名称
  static String? get currentDeviceName {
    return service.selectedScanner.value?.deviceName;
  }
}
