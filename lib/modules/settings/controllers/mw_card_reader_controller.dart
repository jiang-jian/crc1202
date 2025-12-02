import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/widgets/debug_log_window.dart';

/// MW读卡器控制器
class MwCardReaderController extends GetxController {
  static const platform = MethodChannel('com.holox.ailand_pos/mw_card_reader');
  static const String debugTag = 'mw_card_reader';

  // 连接状态
  final isConnected = false.obs;

  // 设备信息
  final hardwareVersion = ''.obs;
  final serialNumber = ''.obs;

  // 卡片信息（仅用于调试日志显示）
  final cardUid = ''.obs;
  final cardType = ''.obs;
  final cardDetected = false.obs;

  // 自动检测状态
  final isAutoDetecting = false.obs;

  @override
  void onInit() {
    super.onInit();
    _setupMethodCallHandler();
    DebugLogger.info(debugTag, 'MW读卡器初始化完成');
  }

  @override
  void onClose() {
    stopCardDetection();
    closeReader();
    super.onClose();
  }

  /// 设置方法调用处理器(接收来自Android的事件)
  void _setupMethodCallHandler() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onEvent') {
        final event = call.arguments['event'] as String?;
        final data = call.arguments['data'] as Map?;

        switch (event) {
          case 'connected':
            isConnected.value = true;
            DebugLogger.success(debugTag, data?['message'] ?? '读卡器已连接');
            // 连接后获取设备信息
            _getDeviceInfo();
            break;
          case 'permission_denied':
            DebugLogger.error(debugTag, data?['message'] ?? 'USB权限被拒绝');
            break;
          case 'card_detected':
            // 自动检测到卡片
            final uid = data?['uid'] as String?;
            final type = data?['type'] as String?;
            if (uid != null) {
              cardUid.value = uid;
              cardType.value = type ?? 'Unknown';
              cardDetected.value = true;
              DebugLogger.success(
                debugTag,
                '✅ 自动检测到卡片 - Type: $type, UID: $uid',
              );
              await beep();
            }
            break;
          case 'error':
            DebugLogger.error(debugTag, data?['message'] ?? '发生错误');
            break;
        }
      }
    });
  }

  /// 清空日志
  void clearLogs() {
    DebugLogger.clear(debugTag);
  }

  /// 打开USB读卡器
  Future<bool> openReaderUSB() async {
    try {
      DebugLogger.info(debugTag, '正在打开USB读卡器...');

      final result = await platform.invokeMethod('openReaderUSB');

      if (result == true) {
        return true;
      } else if (result == null) {
        DebugLogger.info(debugTag, '等待USB权限授权...');
        return false;
      }
      return false;
    } catch (e) {
      DebugLogger.error(debugTag, '打开读卡器失败: $e');
      return false;
    }
  }

  /// 关闭读卡器
  Future<bool> closeReader() async {
    try {
      if (!isConnected.value) {
        return true;
      }

      // 停止自动检测
      await stopCardDetection();

      DebugLogger.info(debugTag, '正在关闭读卡器...');

      await platform.invokeMethod('closeReader');
      isConnected.value = false;
      hardwareVersion.value = '';
      serialNumber.value = '';
      cardUid.value = '';
      cardType.value = '';
      cardDetected.value = false;
      DebugLogger.success(debugTag, '读卡器已关闭');
      return true;
    } catch (e) {
      DebugLogger.error(debugTag, '关闭读卡器失败: $e');
      return false;
    }
  }

  /// 获取设备信息
  Future<void> _getDeviceInfo() async {
    try {
      final hwVer = await platform.invokeMethod('getHardwareVer');
      final sn = await platform.invokeMethod('getSerialNumber');

      hardwareVersion.value = hwVer ?? '';
      serialNumber.value = sn ?? '';

      DebugLogger.info(debugTag, '硬件版本: $hwVer');
      DebugLogger.info(debugTag, '序列号: $sn');

      // 连接成功后蜂鸣
      await beep();
    } catch (e) {
      DebugLogger.error(debugTag, '获取设备信息失败: $e');
    }
  }

  /// 蜂鸣器
  Future<void> beep({int times = 1, int duration = 1, int interval = 2}) async {
    try {
      await platform.invokeMethod('beep', {
        'times': times,
        'duration': duration,
        'interval': interval,
      });
    } catch (e) {
      DebugLogger.error(debugTag, '蜂鸣失败: $e');
    }
  }

  /// 检查是否已连接
  Future<bool> checkConnection() async {
    try {
      final result = await platform.invokeMethod('isConnected');
      isConnected.value = result ?? false;
      return isConnected.value;
    } catch (e) {
      isConnected.value = false;
      return false;
    }
  }

  // ==================== M1 卡操作方法 ====================

  /// 启动卡片自动检测
  Future<bool> startCardDetection() async {
    try {
      if (!isConnected.value) {
        DebugLogger.error(debugTag, '读卡器未连接');
        return false;
      }

      if (isAutoDetecting.value) {
        DebugLogger.info(debugTag, '卡片检测已在运行中');
        return true;
      }

      DebugLogger.info(debugTag, '启动卡片自动检测...');
      await platform.invokeMethod('startCardDetection');
      isAutoDetecting.value = true;
      DebugLogger.success(debugTag, '卡片自动检测已启动');
      return true;
    } catch (e) {
      DebugLogger.error(debugTag, '启动卡片检测失败: $e');
      return false;
    }
  }

  /// 停止卡片自动检测
  Future<void> stopCardDetection() async {
    try {
      if (!isAutoDetecting.value) return;

      await platform.invokeMethod('stopCardDetection');
      isAutoDetecting.value = false;
      DebugLogger.info(debugTag, '卡片自动检测已停止');
    } catch (e) {
      DebugLogger.error(debugTag, '停止卡片检测失败: $e');
    }
  }

  /// 打开M1卡 (单次检测)
  /// [mode] 0=TypeA, 1=TypeB
  /// 返回: 卡片UID
  Future<String?> openCard({int mode = 0}) async {
    try {
      if (!isConnected.value) {
        DebugLogger.error(debugTag, '读卡器未连接');
        return null;
      }

      DebugLogger.info(debugTag, '正在打开卡片...');

      final result = await platform.invokeMethod('openCard', {'mode': mode});

      if (result != null && result is Map) {
        final uid = result['uid'] as String?;
        if (uid != null && uid.isNotEmpty) {
          cardUid.value = uid;
          cardType.value = 'MIFARE Classic';
          cardDetected.value = true;
          DebugLogger.success(debugTag, '✅ 卡片已打开 - UID: $uid');
          await beep();
          return uid;
        }
      }

      DebugLogger.error(debugTag, '未检测到卡片');
      return null;
    } catch (e) {
      DebugLogger.error(debugTag, '打开卡片失败: $e');
      return null;
    }
  }

  /// M1卡密码验证
  /// [mode] 0=KeyA, 1=KeyB
  /// [sector] 扇区号 (0-15 for S50, 0-39 for S70)
  /// [pwd] 密码 (12位十六进制,默认: FFFFFFFFFFFF)
  Future<bool> mifareAuth({
    required int mode,
    required int sector,
    String pwd = 'FFFFFFFFFFFF',
  }) async {
    try {
      if (!isConnected.value) {
        DebugLogger.error(debugTag, '读卡器未连接');
        return false;
      }

      if (!cardDetected.value) {
        DebugLogger.error(debugTag, '请先打开卡片');
        return false;
      }

      DebugLogger.info(
        debugTag,
        '验证密码 - 扇区: $sector, 模式: ${mode == 0 ? 'KeyA' : 'KeyB'}',
      );

      await platform.invokeMethod('mifareAuth', {
        'mode': mode,
        'sector': sector,
        'pwd': pwd,
      });

      DebugLogger.success(debugTag, '密码验证成功');
      return true;
    } catch (e) {
      DebugLogger.error(debugTag, '密码验证失败: $e');
      return false;
    }
  }

  /// 读M1卡块数据
  /// [block] 块号 (0-63 for S50, 0-255 for S70)
  /// 返回: 32位十六进制字符串
  Future<String?> mifareRead(int block) async {
    try {
      if (!isConnected.value) {
        DebugLogger.error(debugTag, '读卡器未连接');
        return null;
      }

      if (!cardDetected.value) {
        DebugLogger.error(debugTag, '请先打开卡片');
        return null;
      }

      DebugLogger.info(debugTag, '读取块 $block...');

      final data = await platform.invokeMethod('mifareRead', {'block': block});

      if (data != null && data is String) {
        DebugLogger.success(debugTag, '读取成功 - 块$block: $data');
        return data;
      }

      DebugLogger.error(debugTag, '读取失败');
      return null;
    } catch (e) {
      DebugLogger.error(debugTag, '读取块失败: $e');
      return null;
    }
  }

  /// 写M1卡块数据
  /// [block] 块号
  /// [data] 32位十六进制字符串
  Future<bool> mifareWrite(int block, String data) async {
    try {
      if (!isConnected.value) {
        DebugLogger.error(debugTag, '读卡器未连接');
        return false;
      }

      if (!cardDetected.value) {
        DebugLogger.error(debugTag, '请先打开卡片');
        return false;
      }

      if (data.length != 32) {
        DebugLogger.error(debugTag, '数据必须是32位十六进制字符串');
        return false;
      }

      DebugLogger.info(debugTag, '写入块 $block...');

      await platform.invokeMethod('mifareWrite', {
        'block': block,
        'data': data,
      });

      DebugLogger.success(debugTag, '写入成功 - 块$block: $data');
      return true;
    } catch (e) {
      DebugLogger.error(debugTag, '写入块失败: $e');
      return false;
    }
  }

  /// 初始化值块
  /// [block] 块号
  /// [value] 初始值
  Future<bool> mifareInitVal(int block, int value) async {
    try {
      if (!isConnected.value) {
        DebugLogger.error(debugTag, '读卡器未连接');
        return false;
      }

      if (!cardDetected.value) {
        DebugLogger.error(debugTag, '请先打开卡片');
        return false;
      }

      DebugLogger.info(debugTag, '初始化值块 $block = $value...');

      await platform.invokeMethod('mifareInitVal', {
        'block': block,
        'value': value,
      });

      DebugLogger.success(debugTag, '初始化值成功');
      return true;
    } catch (e) {
      DebugLogger.error(debugTag, '初始化值失败: $e');
      return false;
    }
  }

  /// 读取值块
  /// [block] 块号
  /// 返回: 值
  Future<int?> mifareReadVal(int block) async {
    try {
      if (!isConnected.value) {
        DebugLogger.error(debugTag, '读卡器未连接');
        return null;
      }

      if (!cardDetected.value) {
        DebugLogger.error(debugTag, '请先打开卡片');
        return null;
      }

      DebugLogger.info(debugTag, '读取值块 $block...');

      final value = await platform.invokeMethod('mifareReadVal', {
        'block': block,
      });

      if (value != null) {
        DebugLogger.success(debugTag, '读取值成功 - 块$block: $value');
        return value as int;
      }

      DebugLogger.error(debugTag, '读取值失败');
      return null;
    } catch (e) {
      DebugLogger.error(debugTag, '读取值失败: $e');
      return null;
    }
  }

  /// 值块增值
  /// [block] 块号
  /// [value] 增加的值
  Future<bool> mifareIncrement(int block, int value) async {
    try {
      if (!isConnected.value) {
        DebugLogger.error(debugTag, '读卡器未连接');
        return false;
      }

      if (!cardDetected.value) {
        DebugLogger.error(debugTag, '请先打开卡片');
        return false;
      }

      DebugLogger.info(debugTag, '块$block 增值 $value...');

      await platform.invokeMethod('mifareIncrement', {
        'block': block,
        'value': value,
      });

      DebugLogger.success(debugTag, '增值成功');
      return true;
    } catch (e) {
      DebugLogger.error(debugTag, '增值失败: $e');
      return false;
    }
  }

  /// 值块减值
  /// [block] 块号
  /// [value] 减少的值
  Future<bool> mifareDecrement(int block, int value) async {
    try {
      if (!isConnected.value) {
        DebugLogger.error(debugTag, '读卡器未连接');
        return false;
      }

      if (!cardDetected.value) {
        DebugLogger.error(debugTag, '请先打开卡片');
        return false;
      }

      DebugLogger.info(debugTag, '块$block 减值 $value...');

      await platform.invokeMethod('mifareDecrement', {
        'block': block,
        'value': value,
      });

      DebugLogger.success(debugTag, '减值成功');
      return true;
    } catch (e) {
      DebugLogger.error(debugTag, '减值失败: $e');
      return false;
    }
  }

  /// 关闭卡片
  Future<bool> halt() async {
    try {
      if (!isConnected.value) {
        return false;
      }

      await platform.invokeMethod('halt');
      cardDetected.value = false;
      cardUid.value = '';
      cardType.value = '';
      DebugLogger.info(debugTag, '卡片已关闭');
      return true;
    } catch (e) {
      DebugLogger.error(debugTag, '关闭卡片失败: $e');
      return false;
    }
  }

  /// 完整的读卡流程示例
  /// [sector] 扇区号
  /// [block] 块号
  /// [pwd] 密码
  Future<String?> readCardComplete({
    required int sector,
    required int block,
    String pwd = 'FFFFFFFFFFFF',
  }) async {
    try {
      // 1. 打开卡片
      final uid = await openCard();
      if (uid == null) return null;

      // 2. 验证密码
      final authSuccess = await mifareAuth(mode: 0, sector: sector, pwd: pwd);
      if (!authSuccess) return null;

      // 3. 读取数据
      final data = await mifareRead(block);

      // 4. 关闭卡片
      await halt();

      return data;
    } catch (e) {
      DebugLogger.error(debugTag, '读卡流程失败: $e');
      return null;
    }
  }

  /// 完整的写卡流程示例
  Future<bool> writeCardComplete({
    required int sector,
    required int block,
    required String data,
    String pwd = 'FFFFFFFFFFFF',
  }) async {
    try {
      // 1. 打开卡片
      final uid = await openCard();
      if (uid == null) return false;

      // 2. 验证密码
      final authSuccess = await mifareAuth(mode: 0, sector: sector, pwd: pwd);
      if (!authSuccess) return false;

      // 3. 写入数据
      final writeSuccess = await mifareWrite(block, data);

      // 4. 关闭卡片
      await halt();

      return writeSuccess;
    } catch (e) {
      DebugLogger.error(debugTag, '写卡流程失败: $e');
      return false;
    }
  }
}
