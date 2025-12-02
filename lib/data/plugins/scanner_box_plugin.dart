import 'dart:async';
import 'package:flutter/services.dart';
import '../models/scanner_box_model.dart';

/// 扫码盒子硬件插件
/// 桥接Android原生BarcodeScannerPlugin
class ScannerBoxPlugin {
  static const MethodChannel _channel = MethodChannel(
    'com.holox.ailand_pos/barcode_scanner',
  );

  // ==================== 事件流 ====================

  /// 扫码结果事件流
  static final StreamController<Map<String, dynamic>> _scanResultController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 设备连接事件流
  static final StreamController<void> _deviceAttachedController =
      StreamController<void>.broadcast();

  /// 设备断开事件流
  static final StreamController<void> _deviceDetachedController =
      StreamController<void>.broadcast();

  /// 权限授予事件流
  static final StreamController<Map<String, dynamic>>
  _permissionGrantedController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 权限拒绝事件流
  static final StreamController<String?> _permissionDeniedController =
      StreamController<String?>.broadcast();

  // ==================== 公开的Stream ====================

  /// 获取扫码结果流
  static Stream<Map<String, dynamic>> get onScanResult =>
      _scanResultController.stream;

  /// 获取设备连接流
  static Stream<void> get onDeviceAttached => _deviceAttachedController.stream;

  /// 获取设备断开流
  static Stream<void> get onDeviceDetached => _deviceDetachedController.stream;

  /// 获取权限授予流
  static Stream<Map<String, dynamic>> get onPermissionGranted =>
      _permissionGrantedController.stream;

  /// 获取权限拒绝流
  static Stream<String?> get onPermissionDenied =>
      _permissionDeniedController.stream;

  // ==================== 初始化 ====================

  /// 初始化插件（注册方法调用处理器）
  static void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// 处理来自原生层的方法调用
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onScanResult':
        // 扫码结果
        final Map<String, dynamic> result = Map<String, dynamic>.from(
          call.arguments as Map,
        );
        _scanResultController.add(result);
        break;

      case 'onDeviceAttached':
        // 设备连接
        _deviceAttachedController.add(null);
        break;

      case 'onDeviceDetached':
        // 设备断开
        _deviceDetachedController.add(null);
        break;

      case 'onPermissionGranted':
        // 权限授予
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          call.arguments as Map,
        );
        _permissionGrantedController.add(data);
        break;

      case 'onPermissionDenied':
        // 权限拒绝
        final String? deviceId = call.arguments['deviceId'] as String?;
        _permissionDeniedController.add(deviceId);
        break;

      default:
        print('[ScannerBoxPlugin] 未处理的方法调用: ${call.method}');
    }
  }

  // ==================== 设备管理 ====================

  /// 扫描USB扫描器设备
  /// 返回设备列表
  static Future<List<ScannerBoxDevice>> scanDevices() async {
    try {
      final List<dynamic>? result = await _channel.invokeMethod(
        'scanUsbScanners',
      );

      if (result == null) return [];

      return result.map((deviceData) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          deviceData as Map,
        );
        return ScannerBoxDevice(
          deviceId: data['deviceId']?.toString() ?? '',
          deviceName: data['deviceName']?.toString() ?? 'Unknown Device',
          vendorId: data['vendorId'] as int? ?? 0,
          productId: data['productId'] as int? ?? 0,
          serialNumber: data['serialNumber']?.toString(),
          manufacturer: data['manufacturer']?.toString() ?? 'Unknown',
          productName: data['productName']?.toString() ?? 'Barcode Scanner',
          isConnected: data['isConnected'] as bool? ?? false,
          isAuthorized: data['isConnected'] as bool? ?? false,
        );
      }).toList();
    } catch (e) {
      print('[ScannerBoxPlugin] 扫描设备失败: $e');
      return [];
    }
  }

  /// 请求USB设备权限
  /// [deviceId] 设备ID
  /// 返回是否已有权限（true）或权限请求已发起（false）
  static Future<bool> requestPermission(String deviceId) async {
    try {
      final bool? result = await _channel.invokeMethod('requestPermission', {
        'deviceId': deviceId,
      });
      return result ?? false;
    } catch (e) {
      print('[ScannerBoxPlugin] 请求权限失败: $e');
      return false;
    }
  }

  // ==================== 扫码控制 ====================

  /// 开始监听扫码
  static Future<bool> startListening() async {
    try {
      final bool? result = await _channel.invokeMethod('startListening');
      return result ?? false;
    } catch (e) {
      print('[ScannerBoxPlugin] 开始监听失败: $e');
      return false;
    }
  }

  /// 停止监听扫码
  static Future<bool> stopListening() async {
    try {
      final bool? result = await _channel.invokeMethod('stopListening');
      return result ?? false;
    } catch (e) {
      print('[ScannerBoxPlugin] 停止监听失败: $e');
      return false;
    }
  }

  // ==================== 清理 ====================

  /// 释放资源
  static void dispose() {
    _scanResultController.close();
    _deviceAttachedController.close();
    _deviceDetachedController.close();
    _permissionGrantedController.close();
    _permissionDeniedController.close();
  }
}
