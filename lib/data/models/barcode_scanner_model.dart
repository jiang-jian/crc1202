/// 条码扫描器设备模型
class BarcodeScannerDevice {
  /// 设备ID（系统生成的唯一标识）
  final String deviceId;

  /// 设备名称（USB设备名称）
  final String deviceName;

  /// 制造商名称
  final String? manufacturer;

  /// 产品名称
  final String? productName;

  /// 设备型号
  final String? model;

  /// 设备规格/支持的标准
  final String? specifications;

  /// USB厂商ID
  final int vendorId;

  /// USB产品ID
  final int productId;

  /// 是否已连接（拥有权限）
  final bool isConnected;

  /// 序列号
  final String? serialNumber;

  /// USB路径（用于调试）
  final String? usbPath;

  BarcodeScannerDevice({
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
  });

  /// 从Map创建设备对象
  factory BarcodeScannerDevice.fromMap(Map<dynamic, dynamic> map) {
    return BarcodeScannerDevice(
      deviceId: map['deviceId']?.toString() ?? '',
      deviceName: map['deviceName']?.toString() ?? 'Unknown Device',
      manufacturer: map['manufacturer']?.toString(),
      productName: map['productName']?.toString(),
      model: map['model']?.toString(),
      specifications: map['specifications']?.toString(),
      vendorId: map['vendorId'] as int? ?? 0,
      productId: map['productId'] as int? ?? 0,
      isConnected: map['isConnected'] as bool? ?? false,
      serialNumber: map['serialNumber']?.toString(),
      usbPath: map['usbPath']?.toString(),
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
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
    };
  }

  /// 复制并修改部分字段
  BarcodeScannerDevice copyWith({
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
  }) {
    return BarcodeScannerDevice(
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
    );
  }
}

/// 扫码结果模型
class ScanResult {
  /// 扫码数据类型（QR Code / Barcode / EAN-13 等）
  final String type;

  /// 扫描的内容
  final String content;

  /// 数据长度
  final int length;

  /// 扫描时间戳
  final DateTime timestamp;

  /// 是否有效
  final bool isValid;

  /// 原始数据（用于调试）
  final String? rawData;

  ScanResult({
    required this.type,
    required this.content,
    required this.length,
    required this.timestamp,
    this.isValid = true,
    this.rawData,
  });

  /// 从Map创建扫码结果
  factory ScanResult.fromMap(Map<dynamic, dynamic> map) {
    return ScanResult(
      type: map['type']?.toString() ?? 'Unknown',
      content: map['content']?.toString() ?? '',
      length: map['length'] as int? ?? 0,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'].toString())
          : DateTime.now(),
      isValid: map['isValid'] as bool? ?? true,
      rawData: map['rawData']?.toString(),
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'content': content,
      'length': length,
      'timestamp': timestamp.toIso8601String(),
      'isValid': isValid,
      'rawData': rawData,
    };
  }
}
