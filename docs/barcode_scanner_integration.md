# 得力No.14952W条码扫描器集成文档

## 📋 概述

本文档详细说明如何使用得力No.14952W条码扫描器（USB HID模式）进行条码/二维码扫描。

### 支持的扫描器类型
- **得力No.14952W** - 无线2.4G条码扫描器
- **工作模式**：USB HID键盘模拟模式
- **连接方式**：USB接收器（2.4G无线）

### 核心原理

扫描器作为USB HID键盘设备工作：
1. 插入USB接收器后，Android系统识别为键盘设备
2. 扫描条码时，扫描器将数据作为键盘输入发送
3. 应用监听键盘事件，解析条码数据
4. 支持多种条码格式：EAN-13、UPC、Code128、QR Code等

---

## 🏗️ 架构设计

### 三层架构

```
┌─────────────────────────────────────────────────────────┐
│  UI Layer (Flutter)                                     │
│  ├─ QrScannerConfigView                                 │
│  │  ├─ 设备列表展示                                       │
│  │  ├─ 扫描状态动画                                       │
│  │  └─ 数据结果显示                                       │
│  └─ RawKeyboardListener (键盘事件监听)                    │
└─────────────────────────────────────────────────────────┘
                         ↓ ↑
┌─────────────────────────────────────────────────────────┐
│  Service Layer (Dart)                                   │
│  ├─ BarcodeScannerService (GetX Service)                │
│  │  ├─ 设备扫描管理                                       │
│  │  ├─ 权限请求处理                                       │
│  │  ├─ 监听状态控制                                       │
│  │  └─ 数据流管理                                         │
│  └─ Models                                              │
│     ├─ BarcodeScannerDevice (设备信息)                   │
│     └─ ScanResult (扫描结果)                             │
└─────────────────────────────────────────────────────────┘
                         ↓ ↑
┌─────────────────────────────────────────────────────────┐
│  Native Layer (Kotlin)                                  │
│  ├─ BarcodeScannerPlugin                                │
│  │  ├─ USB设备检测                                        │
│  │  ├─ 权限管理                                           │
│  │  ├─ 键盘输入处理                                       │
│  │  └─ 条码类型识别                                       │
│  └─ USB Manager (Android System)                        │
└─────────────────────────────────────────────────────────┘
```

---

## 📁 文件结构

```
lib/
├─ data/
│  ├─ models/
│  │  └─ barcode_scanner_model.dart          # 数据模型
│  └─ services/
│     └─ barcode_scanner_service.dart        # 服务层
├─ modules/
│  └─ settings/
│     └─ views/
│        └─ qr_scanner_config_view.dart      # UI页面
└─ main.dart                                 # 服务注册

android/
└─ app/src/main/kotlin/com/holox/ailand_pos/
   ├─ BarcodeScannerPlugin.kt               # 原生插件
   └─ MainActivity.kt                        # 插件注册
```

---

## 🔧 核心功能实现

### 1. USB设备检测

**原生层 (BarcodeScannerPlugin.kt)**

```kotlin
private fun scanUsbScanners(result: Result) {
    val deviceList = usbManager?.deviceList ?: emptyMap()
    
    val scanners = deviceList.values
        .filter { device -> isScannerDevice(device) }
        .map { device -> getDeviceInfo(device) }
    
    result.success(scanners)
}

private fun isScannerDevice(device: UsbDevice): Boolean {
    // 1. 检查HID接口
    for (i in 0 until device.interfaceCount) {
        if (device.getInterface(i).interfaceClass == USB_CLASS_HID) {
            return true
        }
    }
    
    // 2. 检查已知厂商ID
    if (device.vendorId in KNOWN_SCANNER_VENDORS) {
        return true
    }
    
    return false
}
```

**Dart层 (BarcodeScannerService.dart)**

```dart
Future<void> scanUsbScanners() async {
  isScanning.value = true;
  
  final List<dynamic> devices = 
      await _channel.invokeMethod('scanUsbScanners');
  
  detectedScanners.value = 
      devices.map((d) => BarcodeScannerDevice.fromMap(d)).toList();
  
  // 自动选择已连接设备
  final connectedDevice = detectedScanners
      .firstWhereOrNull((device) => device.isConnected);
  
  if (connectedDevice != null) {
    selectedScanner.value = connectedDevice;
    await startListening();
  }
  
  isScanning.value = false;
}
```

### 2. USB权限请求

**流程**：
1. 用户点击未连接的设备
2. 应用请求USB权限
3. 系统弹出权限对话框
4. 用户授权后自动重新扫描

**Dart层**

```dart
Future<bool> requestPermission(String deviceId) async {
  final bool granted = await _channel.invokeMethod(
    'requestPermission',
    {'deviceId': deviceId},
  );
  
  if (granted) {
    await scanUsbScanners(); // 重新扫描更新状态
  }
  
  return granted;
}
```

**原生层**

```kotlin
private fun requestPermission(call: MethodCall, result: Result) {
    val deviceId = call.argument<String>("deviceId")
    val device = findDeviceById(deviceId)
    
    if (usbManager?.hasPermission(device) == true) {
        result.success(true)
        return
    }
    
    val permissionIntent = PendingIntent.getBroadcast(
        context, 0, Intent(ACTION_USB_PERMISSION),
        PendingIntent.FLAG_MUTABLE
    )
    
    usbManager?.requestPermission(device, permissionIntent)
    result.success(false) // 权限请求已发起
}
```

### 3. 键盘事件监听

**UI层 (qr_scanner_config_view.dart)**

```dart
@override
Widget build(BuildContext context) {
  return RawKeyboardListener(
    focusNode: _keyboardFocusNode,
    autofocus: true,
    onKey: _handleKeyEvent,
    child: Container(...),
  );
}

void _handleKeyEvent(RawKeyEvent event) {
  if (event is RawKeyDownEvent) {
    final keyCode = event.logicalKey.keyId;
    _scannerService.channel.invokeMethod('handleKeyEvent', {
      'keyCode': keyCode,
      'action': 0, // ACTION_DOWN
    });
  }
}
```

**原生层**

```kotlin
private fun handleKeyEvent(call: MethodCall, result: Result) {
    if (!isListening) return
    
    val keyCode = call.argument<Int>("keyCode") ?: 0
    val currentTime = System.currentTimeMillis()
    
    // 超时检测（新的扫码开始）
    if (lastKeyTime > 0 && (currentTime - lastKeyTime) > scanTimeout) {
        if (scanBuffer.isNotEmpty()) {
            processScanData()
        }
        scanBuffer.clear()
    }
    
    lastKeyTime = currentTime
    
    when (keyCode) {
        KeyEvent.KEYCODE_ENTER -> {
            // 回车键 = 扫码结束
            if (scanBuffer.isNotEmpty()) {
                processScanData()
                scanBuffer.clear()
            }
        }
        else -> {
            // 添加字符到缓冲区
            val char = getCharFromKeyCode(keyCode)
            if (char != null) {
                scanBuffer.append(char)
            }
        }
    }
}
```

### 4. 条码类型识别

**原生层**

```kotlin
private fun recognizeBarcodeType(data: String): String {
    return when {
        data.length == 13 && data.all { it.isDigit() } -> "EAN-13"
        data.length == 8 && data.all { it.isDigit() } -> "EAN-8"
        data.length == 12 && data.all { it.isDigit() } -> "UPC-A"
        data.startsWith("http://") || data.startsWith("https://") -> "QR Code (URL)"
        data.contains(":") || data.contains(";") -> "QR Code"
        data.all { it.isDigit() } -> "Numeric Barcode"
        else -> "Code 128 / Code 39"
    }
}

private fun processScanData() {
    val barcodeData = scanBuffer.toString().trim()
    val barcodeType = recognizeBarcodeType(barcodeData)
    
    val scanResult = hashMapOf(
        "type" to barcodeType,
        "content" to barcodeData,
        "length" to barcodeData.length,
        "timestamp" to Instant.now().toString(),
        "isValid" to true
    )
    
    channel.invokeMethod("onScanResult", scanResult)
}
```

---

## 🎯 使用流程

### 步骤1：连接扫描器

1. 将USB接收器插入Android设备
2. 打开扫描器电源开关
3. 等待扫描器与接收器配对（LED指示灯）

### 步骤2：扫描设备

1. 进入"设置 → 二维码扫描器"页面
2. 点击"扫描USB设备"按钮
3. 系统自动检测USB HID设备
4. 在左侧列表中显示检测到的扫描器

### 步骤3：授予权限

1. 点击设备列表中显示"未连接"的设备
2. 系统弹出USB权限请求对话框
3. 点击"确定"授予权限
4. 设备状态自动更新为"已连接"

### 步骤4：开始扫描

1. 选中的设备会自动开始监听
2. 中间区域显示"准备就绪，请扫描条码..."
3. 将条码对准扫描器感应区
4. 听到"哔"声后，扫描数据显示在右侧

### 步骤5：查看结果

右侧数据区域显示：
- **数据类型**：EAN-13、QR Code等
- **扫描内容**：条码数据
- **数据长度**：字符数
- **扫描时间**：精确到秒

---

## 🔍 故障排查

### 问题1：未检测到扫描器

**可能原因**：
- USB接收器未插好
- 扫描器未开机
- 扫描器与接收器未配对

**解决方法**：
1. 重新插拔USB接收器
2. 关闭扫描器电源，等待3秒后重新开启
3. 查看扫描器LED指示灯是否常亮（配对成功）
4. 点击"扫描USB设备"重新检测

### 问题2：检测到设备但无法连接

**可能原因**：
- USB权限未授予
- 系统USB服务异常

**解决方法**：
1. 点击设备卡片，系统会弹出权限请求
2. 如果没有弹出，尝试重启应用
3. 检查系统设置 → 应用 → ailand_pos → 权限

### 问题3：扫描无反应

**可能原因**：
- 扫描器未进入键盘模式
- 页面失去焦点
- 条码质量差或格式不支持

**解决方法**：
1. 确认扫描器工作在HID键盘模式（查阅说明书设置）
2. 点击页面任意位置，确保页面获得焦点
3. 尝试扫描其他条码测试
4. 检查中间区域是否显示"准备就绪"

### 问题4：扫描数据错误

**可能原因**：
- 扫描速度过快
- 条码损坏或模糊
- 扫描器设置问题

**解决方法**：
1. 扫描时保持稳定，等待"哔"声后再移开
2. 确保条码清晰可见，无遮挡
3. 调整扫描器灵敏度设置（参考说明书）

---

## ⚙️ 高级配置

### 扫描器工作模式

得力No.14952W支持多种扫描模式，通过扫描配置条码切换：

1. **HID键盘模式**（当前使用）
   - 扫描器模拟键盘输入
   - 兼容性最好
   - 无需驱动

2. **串口模式**
   - 通过串口通信
   - 需要串口驱动
   - 高级应用场景

**切换方法**：
1. 参考扫描器说明书附录的配置条码
2. 依次扫描：复位条码 → HID键盘模式条码 → 保存设置条码

### 支持的条码格式

得力No.14952W支持以下格式：

**一维码**：
- EAN-13 / EAN-8
- UPC-A / UPC-E
- Code 128 / Code 39
- Codabar
- Interleaved 2 of 5

**二维码**：
- QR Code
- Data Matrix
- PDF417

### 性能优化

**提高扫描速度**：
1. 只启用需要的条码格式（扫描配置条码）
2. 调整扫描灵敏度为"高速模式"
3. 保持条码清晰无损

**减少误读**：
1. 启用校验位验证
2. 设置最小/最大码长限制
3. 使用"双扫描确认"模式（扫描配置条码）

---

## 📊 技术细节

### USB HID协议

扫描器作为HID键盘设备，遵循以下规范：
- **USB Class**: 0x03 (HID)
- **Interface Class**: 0x03 (HID)
- **Interface SubClass**: 0x01 (Boot Interface)
- **Interface Protocol**: 0x01 (Keyboard)

### 键盘输入处理

**数据流**：
```
扫描器 → USB接收器 → Android系统 → KeyEvent → Flutter
```

**时序控制**：
- **扫码间隔**：100ms
- **字符间隔**：10-50ms（由扫描器控制）
- **结束标识**：回车键（KeyEvent.KEYCODE_ENTER）

### 设备识别逻辑

```kotlin
// 1. 检查USB接口类
if (usbInterface.interfaceClass == USB_CLASS_HID) {
    return true
}

// 2. 检查厂商ID
if (device.vendorId in KNOWN_SCANNER_VENDORS) {
    return true
}

// 3. 检查产品名称
if (productName.contains("scanner") || 
    productName.contains("barcode")) {
    return true
}
```

---

## 🔗 相关资源

### 官方文档
- [得力官网](https://www.deli-office.com/)
- [产品手册](https://www.deli-office.com/products/scanner/14952W)

### Android开发文档
- [USB Host API](https://developer.android.com/guide/topics/connectivity/usb/host)
- [KeyEvent Reference](https://developer.android.com/reference/android/view/KeyEvent)

### 项目代码
- `lib/data/services/barcode_scanner_service.dart` - 服务层
- `android/app/src/main/kotlin/.../BarcodeScannerPlugin.kt` - 原生层
- `lib/modules/settings/views/qr_scanner_config_view.dart` - UI层

---

## 📝 开发注意事项

### 1. 权限声明

确保 `AndroidManifest.xml` 中已声明USB权限：

```xml
<uses-feature android:name="android.hardware.usb.host" />
<uses-permission android:name="android.permission.USB_PERMISSION" />
```

### 2. 焦点管理

UI必须持有键盘焦点才能接收事件：

```dart
RawKeyboardListener(
  focusNode: _keyboardFocusNode,
  autofocus: true,  // 自动获取焦点
  onKey: _handleKeyEvent,
  child: ...,
)
```

### 3. 生命周期

服务需要正确初始化和清理：

```dart
@override
void onInit() {
  super.onInit();
  _setupMethodCallHandler();
}

@override
void onClose() {
  stopListening();
  super.onClose();
}
```

### 4. 错误处理

所有异步操作都应捕获异常：

```dart
try {
  await _channel.invokeMethod('scanUsbScanners');
} catch (e) {
  lastError.value = '扫描失败: $e';
  _addLog('✗ 扫描失败: $e');
}
```

---

## 🎓 扩展功能

### 未来可实现的功能

1. **扫描历史记录**
   - 存储最近100条扫描记录
   - 支持导出为CSV/Excel
   - 统计分析功能

2. **条码验证**
   - EAN-13/UPC校验位验证
   - 自定义规则验证
   - 重复扫描检测

3. **多设备支持**
   - 同时连接多个扫描器
   - 设备标识和区分
   - 多通道数据流

4. **音效和震动反馈**
   - 扫描成功提示音
   - 错误警告音
   - 震动反馈

---

## 📞 技术支持

如有问题，请联系开发团队或参考：
- 项目仓库：[GitHub链接]
- 问题反馈：[Issues链接]
- 技术文档：[文档链接]

---

**文档版本**: v1.0  
**最后更新**: 2025-11-18  
**维护者**: 开发团队
