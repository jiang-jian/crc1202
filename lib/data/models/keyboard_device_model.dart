/// 键盘设备数据模型
/// 用于表示USB外置键盘设备信息
class KeyboardDevice {
  /// 设备ID（系统分配的唯一标识）
  final String deviceId;

  /// 设备名称
  final String deviceName;

  /// 制造商名称
  final String? manufacturer;

  /// 产品名称
  final String? productName;

  /// 设备型号
  final String? model;

  /// 设备规格描述
  final String? specifications;

  /// 厂商ID
  final int vendorId;

  /// 产品ID
  final int productId;

  /// 是否已连接（已授权）
  final bool isConnected;

  /// 序列号
  final String? serialNumber;

  /// USB路径
  final String? usbPath;

  /// 键盘类型：numeric（数字键盘）、full（全键盘）、unknown（未知）
  final String keyboardType;

  /// 按键数量
  final int? keyCount;

  KeyboardDevice({
    required this.deviceId,
    required this.deviceName,
    this.manufacturer,
    this.productName,
    this.model,
    this.specifications,
    required this.vendorId,
    required this.productId,
    required this.isConnected,
    this.serialNumber,
    this.usbPath,
    this.keyboardType = 'unknown',
    this.keyCount,
  });

  /// 从JSON创建对象
  factory KeyboardDevice.fromJson(Map<String, dynamic> json) {
    return KeyboardDevice(
      deviceId: json['deviceId']?.toString() ?? '',
      deviceName: json['deviceName']?.toString() ?? 'Unknown Keyboard',
      manufacturer: json['manufacturer']?.toString(),
      productName: json['productName']?.toString(),
      model: json['model']?.toString(),
      specifications: json['specifications']?.toString(),
      vendorId: json['vendorId'] as int? ?? 0,
      productId: json['productId'] as int? ?? 0,
      isConnected: json['isConnected'] as bool? ?? false,
      serialNumber: json['serialNumber']?.toString(),
      usbPath: json['usbPath']?.toString(),
      keyboardType: json['keyboardType']?.toString() ?? 'unknown',
      keyCount: json['keyCount'] as int?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'manufacturer': manufacturer,
      'productName': productName,
      'model': model,
      'specifications': specifications,
      'vendorId': vendorId,
      'productId': productId,
      'isConnected': isConnected,
      'serialNumber': serialNumber,
      'usbPath': usbPath,
      'keyboardType': keyboardType,
      'keyCount': keyCount,
    };
  }

  /// 复制对象并更新部分字段
  KeyboardDevice copyWith({
    String? deviceId,
    String? deviceName,
    String? manufacturer,
    String? productName,
    String? model,
    String? specifications,
    int? vendorId,
    int? productId,
    bool? isConnected,
    String? serialNumber,
    String? usbPath,
    String? keyboardType,
    int? keyCount,
  }) {
    return KeyboardDevice(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      manufacturer: manufacturer ?? this.manufacturer,
      productName: productName ?? this.productName,
      model: model ?? this.model,
      specifications: specifications ?? this.specifications,
      vendorId: vendorId ?? this.vendorId,
      productId: productId ?? this.productId,
      isConnected: isConnected ?? this.isConnected,
      serialNumber: serialNumber ?? this.serialNumber,
      usbPath: usbPath ?? this.usbPath,
      keyboardType: keyboardType ?? this.keyboardType,
      keyCount: keyCount ?? this.keyCount,
    );
  }

  @override
  String toString() {
    return 'KeyboardDevice(deviceId: $deviceId, deviceName: $deviceName, '
        'manufacturer: $manufacturer, vendorId: 0x${vendorId.toRadixString(16)}, '
        'productId: 0x${productId.toRadixString(16)}, isConnected: $isConnected, '
        'keyboardType: $keyboardType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is KeyboardDevice &&
        other.deviceId == deviceId &&
        other.vendorId == vendorId &&
        other.productId == productId &&
        other.serialNumber == serialNumber;
  }

  @override
  int get hashCode {
    return deviceId.hashCode ^
        vendorId.hashCode ^
        productId.hashCode ^
        serialNumber.hashCode;
  }
}
