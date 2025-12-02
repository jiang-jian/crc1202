/// 扫码盒子设备模型
class ScannerBoxDevice {
  /// 设备ID
  final String deviceId;

  /// 设备名称
  final String deviceName;

  /// 供应商ID
  final int vendorId;

  /// 产品ID
  final int productId;

  /// 序列号
  final String? serialNumber;

  /// 制造商
  final String? manufacturer;

  /// 产品描述
  final String? productName;

  /// 连接状态
  final bool isConnected;

  /// 是否已授权
  final bool isAuthorized;

  ScannerBoxDevice({
    required this.deviceId,
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    this.serialNumber,
    this.manufacturer,
    this.productName,
    this.isConnected = false,
    this.isAuthorized = false,
  });

  /// 显示名称
  String get displayName {
    if (manufacturer != null && productName != null) {
      return '$manufacturer $productName';
    }
    if (productName != null) {
      return productName!;
    }
    return deviceName;
  }

  /// 从Map创建
  factory ScannerBoxDevice.fromMap(Map<String, dynamic> map) {
    return ScannerBoxDevice(
      deviceId: map['deviceId'] as String,
      deviceName: map['deviceName'] as String,
      vendorId: map['vendorId'] as int,
      productId: map['productId'] as int,
      serialNumber: map['serialNumber'] as String?,
      manufacturer: map['manufacturer'] as String?,
      productName: map['productName'] as String?,
      isConnected: map['isConnected'] as bool? ?? false,
      isAuthorized: map['isAuthorized'] as bool? ?? false,
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'vendorId': vendorId,
      'productId': productId,
      'serialNumber': serialNumber,
      'manufacturer': manufacturer,
      'productName': productName,
      'isConnected': isConnected,
      'isAuthorized': isAuthorized,
    };
  }

  /// 复制并修改
  ScannerBoxDevice copyWith({
    String? deviceId,
    String? deviceName,
    int? vendorId,
    int? productId,
    String? serialNumber,
    String? manufacturer,
    String? productName,
    bool? isConnected,
    bool? isAuthorized,
  }) {
    return ScannerBoxDevice(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      vendorId: vendorId ?? this.vendorId,
      productId: productId ?? this.productId,
      serialNumber: serialNumber ?? this.serialNumber,
      manufacturer: manufacturer ?? this.manufacturer,
      productName: productName ?? this.productName,
      isConnected: isConnected ?? this.isConnected,
      isAuthorized: isAuthorized ?? this.isAuthorized,
    );
  }
}

/// 扫码数据模型
class ScanData {
  /// 扫码时间
  final DateTime timestamp;

  /// 扫码内容
  final String content;

  /// 数据类型（QR / Barcode）
  final String type;

  ScanData({
    required this.timestamp,
    required this.content,
    this.type = 'QR',
  });

  /// 格式化时间
  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// 从Map创建
  factory ScanData.fromMap(Map<String, dynamic> map) {
    return ScanData(
      timestamp: DateTime.parse(map['timestamp'] as String),
      content: map['content'] as String,
      type: map['type'] as String? ?? 'QR',
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'content': content,
      'type': type,
    };
  }
}

/// 扫码盒子状态枚举
enum ScannerBoxStatus {
  /// 未连接
  disconnected,

  /// 已连接
  connected,

  /// 扫描中
  scanning,

  /// 错误
  error,
}
