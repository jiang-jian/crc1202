import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 设备ID管理器
///
/// 优先级策略：
/// 1. 优先使用 Android ID（设备唯一标识）
/// 2. 若 Android ID 为空，使用 SharedPreferences 中的 UUID
/// 3. 若都不存在，生成新的 UUID 并持久化
class DeviceIdManager {
  static const String _prefKey = 'device_unique_id';
  static String? _cachedDeviceId;

  /// 获取设备唯一ID
  Future<String> getDeviceId() async {
    // 如果已缓存，直接返回
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    try {
      // 1. 尝试获取 Android ID
      final androidId = await _getAndroidId();
      if (androidId != null && androidId.isNotEmpty) {
        _cachedDeviceId = androidId;
        return androidId;
      }

      // 2. 尝试从 SharedPreferences 读取
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_prefKey);
      if (savedId != null && savedId.isNotEmpty) {
        _cachedDeviceId = savedId;
        return savedId;
      }

      // 3. 生成新的 UUID 并持久化
      final newId = const Uuid().v4();
      await prefs.setString(_prefKey, newId);
      _cachedDeviceId = newId;
      return newId;
    } catch (_) {
      // 异常时生成临时ID
      _cachedDeviceId ??= 'temp_${const Uuid().v4()}';
      return _cachedDeviceId!;
    }
  }

  /// 获取 Android ID
  Future<String?> _getAndroidId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        return androidInfo.id;
      }
    } catch (_) {}
    return null;
  }
}
