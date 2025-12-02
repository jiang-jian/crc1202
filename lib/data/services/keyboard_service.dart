import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../models/keyboard_device_model.dart';

/// 键盘设备服务
/// 负责USB键盘设备的扫描、连接、权限管理等操作
class KeyboardService extends GetxService {
  // ========== 通信通道 ==========
  static const MethodChannel _channel =
      MethodChannel('com.holox.ailand_pos/keyboard');

  static const EventChannel _eventChannel =
      EventChannel('com.holox.ailand_pos/keyboard_events');

  static const EventChannel _debugLogChannel =
      EventChannel('com.holox.ailand_pos/keyboard_debug_logs');

  // ========== 响应式状态 ==========
  /// 检测到的键盘设备列表
  final RxList<KeyboardDevice> detectedKeyboards = <KeyboardDevice>[].obs;

  /// 当前选中的键盘设备
  final Rx<KeyboardDevice?> selectedKeyboard = Rx<KeyboardDevice?>(null);

  /// 是否正在扫描设备
  final RxBool isScanning = false.obs;

  /// 是否正在监听键盘事件
  final RxBool isListening = false.obs;

  /// 最后一次按键数据
  final RxMap<String, dynamic> lastKeyData = <String, dynamic>{}.obs;

  /// 最后一个错误信息
  final RxString lastError = ''.obs;

  /// 调试日志列表
  final RxList<String> debugLogs = <String>[].obs;

  // ========== 事件监听 ==========
  /// 键盘事件订阅
  Stream<dynamic>? _keyboardEventStream;

  /// 调试日志事件订阅
  Stream<dynamic>? _debugLogStream;

  /// 初始化服务
  Future<KeyboardService> init() async {
    _setupEventChannel();
    _addLog('🔌 键盘服务初始化完成');
    return this;
  }

  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onClose() {
    stopListening();
    _addLog('🔌 键盘服务已关闭');
    super.onClose();
  }

  /// 设置事件通道
  void _setupEventChannel() {
    // 键盘事件通道
    _keyboardEventStream = _eventChannel.receiveBroadcastStream();
    _keyboardEventStream?.listen(
      _handleKeyboardEvent,
      onError: (error) {
        _addLog('❌ 事件通道错误: $error');
        lastError.value = error.toString();
      },
    );

    // 调试日志通道
    _debugLogStream = _debugLogChannel.receiveBroadcastStream();
    _debugLogStream?.listen(
      _handleDebugLog,
      onError: (error) {
        _addLog('❌ 调试日志通道错误: $error');
      },
    );
  }

  /// 处理键盘事件
  void _handleKeyboardEvent(dynamic event) {
    if (event is Map) {
      final eventType = event['type'] as String?;

      switch (eventType) {
        case 'keyPress':
          _handleKeyPress(event);
          break;
        case 'deviceAttached':
          _handleDeviceAttached(event);
          break;
        case 'deviceDetached':
          _handleDeviceDetached(event);
          break;
        case 'permissionGranted':
          _handlePermissionGranted(event);
          break;
        default:
          _addLog('⚠️ 未知事件类型: $eventType');
      }
    }
  }

  /// 处理调试日志
  void _handleDebugLog(dynamic event) {
    if (event is Map) {
      final timestamp = event['timestamp'] as int?;
      final layer = event['layer'] as String? ?? '未知';
      final message = event['message'] as String? ?? '';
      final level = event['level'] as String? ?? 'info';
      final deviceInfo = event['deviceInfo'] as Map?;

      // 格式化日志
      String logIcon;
      switch (level) {
        case 'success':
          logIcon = '✅';
          break;
        case 'error':
          logIcon = '❌';
          break;
        case 'warning':
          logIcon = '⚠️';
          break;
        default:
          logIcon = 'ℹ️';
      }

      String logMessage = '$logIcon [$layer] $message';

      // 如果有设备信息，添加到日志
      if (deviceInfo != null) {
        final deviceName = deviceInfo['product'] ?? deviceInfo['deviceName'] ?? 'Unknown';
        final vid = deviceInfo['vendorId'] ?? 'N/A';
        final pid = deviceInfo['productId'] ?? 'N/A';
        logMessage += '\n   📱 设备: $deviceName (VID: $vid, PID: $pid)';

        // 如果有接口信息，显示接口数量
        if (deviceInfo['interfaces'] is List) {
          final interfaces = deviceInfo['interfaces'] as List;
          logMessage += '\n   🔌 接口数: ${interfaces.length}';
        }
      }

      _addLog(logMessage);
    }
  }

  /// 处理按键事件
  void _handleKeyPress(Map event) {
    final keyCode = event['keyCode'];
    final keyChar = event['keyChar'];
    final timestamp = DateTime.now();

    lastKeyData.value = {
      'keyCode': keyCode,
      'keyChar': keyChar,
      'timestamp': timestamp,
    };

    _addLog('⌨️ 按键: $keyChar (Code: $keyCode)');
  }

  /// 处理设备连接事件
  void _handleDeviceAttached(Map event) {
    _addLog('🔌 设备已连接');
    scanUsbKeyboards();
  }

  /// 处理设备断开事件
  void _handleDeviceDetached(Map event) {
    _addLog('🔌 设备已断开');
    scanUsbKeyboards();
  }

  /// 处理权限授予事件
  void _handlePermissionGranted(Map event) {
    _addLog('✓ 设备权限已授予');
    scanUsbKeyboards();
  }

  // ========== 设备扫描 ==========
  /// 扫描USB键盘设备
  Future<void> scanUsbKeyboards() async {
    try {
      isScanning.value = true;
      _addLog('🔍 开始扫描USB键盘设备...');

      final result = await _channel.invokeMethod('scanUsbKeyboards');

      if (result is List) {
        detectedKeyboards.value = result
            .map((device) =>
                KeyboardDevice.fromJson(Map<String, dynamic>.from(device)))
            .toList();

        _addLog('✓ 找到 ${detectedKeyboards.length} 个键盘设备');

        // 打印设备详情
        for (var device in detectedKeyboards) {
          _addLog(
              '  📱 ${device.deviceName} (${device.keyboardType}) - ${device.isConnected ? "已连接" : "未连接"}');
        }
      } else {
        _addLog('⚠️ 未检测到键盘设备');
        detectedKeyboards.clear();
      }
    } catch (e) {
      _addLog('❌ 扫描失败: $e');
      lastError.value = e.toString();
      detectedKeyboards.clear();
    } finally {
      isScanning.value = false;
    }
  }

  // ========== 权限管理 ==========
  /// 请求设备权限
  Future<bool> requestPermission(String deviceId) async {
    try {
      _addLog('🔐 请求设备权限: $deviceId');

      final result = await _channel.invokeMethod('requestPermission', {
        'deviceId': deviceId,
      });

      if (result == true) {
        _addLog('✓ 权限请求已发起');
        return true;
      } else {
        _addLog('❌ 权限请求失败');
        return false;
      }
    } catch (e) {
      _addLog('❌ 权限请求异常: $e');
      lastError.value = e.toString();
      return false;
    }
  }

  // ========== 设备监听 ==========
  /// 开始监听键盘事件
  Future<void> startListening() async {
    if (selectedKeyboard.value == null) {
      _addLog('⚠️ 请先选择键盘设备');
      return;
    }

    try {
      _addLog('🎧 开始监听键盘事件...');

      final result = await _channel.invokeMethod('startListening', {
        'deviceId': selectedKeyboard.value!.deviceId,
      });

      if (result == true) {
        isListening.value = true;
        _addLog('✓ 监听已启动');
      } else {
        _addLog('❌ 监听启动失败');
      }
    } catch (e) {
      _addLog('❌ 监听启动异常: $e');
      lastError.value = e.toString();
    }
  }

  /// 停止监听键盘事件
  Future<void> stopListening() async {
    try {
      await _channel.invokeMethod('stopListening');
      isListening.value = false;
      _addLog('🔇 监听已停止');
    } catch (e) {
      _addLog('❌ 停止监听失败: $e');
    }
  }

  // ========== 日志管理 ==========
  /// 添加日志
  void _addLog(String message) {
    final timestamp = DateTime.now();
    final formattedTime =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    debugLogs.insert(0, '[$formattedTime] $message');

    // 限制日志数量
    if (debugLogs.length > 100) {
      debugLogs.removeRange(100, debugLogs.length);
    }
  }

  /// 清空日志
  void clearLogs() {
    debugLogs.clear();
    _addLog('🗑️ 日志已清空');
  }

  /// 清空按键数据
  void clearKeyData() {
    lastKeyData.clear();
    lastError.value = '';
  }
}
