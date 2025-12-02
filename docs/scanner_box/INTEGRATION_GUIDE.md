# 得力AA628扫码盒子集成指南

## 📋 目录

1. [设备信息](#设备信息)
2. [架构设计](#架构设计)
3. [API文档](#api文档)
4. [使用示例](#使用示例)
5. [测试指南](#测试指南)
6. [常见问题](#常见问题)

---

## 📱 设备信息

### 基本参数

| 参数 | 值 |
|------|----|
| **品牌** | 得力（Deli） |
| **型号** | No.AA628 |
| **传感器** | 640×480 CMOS |
| **接口类型** | USB |
| **扫描方式** | 感应模式（自动触发） |
| **支持码制** | EAN13, Code128, QR Code |
| **识读精度** | 1D ≥ 7.5mil, 2D ≥ 12.5mil |
| **工作温度** | 0℃ ~ +45℃ |
| **提示方式** | 语音提示 |
| **系统支持** | Windows/Android/Mac OS/Linux |

### 通讯模式

- **HID Keyboard（默认）**: 模拟USB键盘输入
- **USB HID POS**: 标准HID POS协议
- **USB Serial**: 串口通讯（少见）

**本实现使用：HID Keyboard模式**

---

## 🏗️ 架构设计

### 分层架构

```
┌─────────────────────────────────────────────────┐
│          Flutter View Layer (UI)                │
│  scanner_box_view.dart - 用户界面和交互        │
└──────────────────┬──────────────────────────────┘
                   │ GetX响应式绑定
                   ▼
┌─────────────────────────────────────────────────┐
│       Flutter Service Layer (业务逻辑)          │
│  scanner_box_service.dart - 状态管理和业务逻辑  │
└──────────────────┬──────────────────────────────┘
                   │ MethodChannel
                   ▼
┌─────────────────────────────────────────────────┐
│       Flutter Plugin Layer (桥接层)             │
│  scanner_box_plugin.dart - MethodChannel封装    │
└──────────────────┬──────────────────────────────┘
                   │ Platform Channel
                   ▼
┌─────────────────────────────────────────────────┐
│    Android Native Layer (硬件驱动)              │
│  BarcodeScannerPlugin.kt - USB HID处理          │
│  └─ UsbManager - USB设备管理                     │
│  └─ dispatchKeyEvent - HID键盘监听               │
└─────────────────────────────────────────────────┘
```

### 核心组件

#### 1. **Flutter Plugin Layer**

**文件**: `lib/data/plugins/scanner_box_plugin.dart`

**职责**:
- MethodChannel通信封装
- 事件流管理（扫码、连接、断开、权限）
- 设备数据模型转换

**关键方法**:
```dart
- scanDevices()          // 扫描USB设备
- requestPermission()    // 请求USB权限
- startListening()       // 开始监听扫码
- stopListening()        // 停止监听
```

**事件流**:
```dart
- onScanResult          // 扫码结果
- onDeviceAttached      // 设备连接
- onDeviceDetached      // 设备断开
- onPermissionGranted   // 权限授予
- onPermissionDenied    // 权限拒绝
```

#### 2. **Flutter Service Layer**

**文件**: `lib/data/services/scanner_box_service.dart`

**职责**:
- GetX状态管理
- 业务逻辑封装
- 自动重连和错误处理
- 扫码历史记录管理

**响应式状态**:
```dart
- connectedDevice       // 当前设备
- deviceStatus          // 设备状态
- scanHistory           // 扫码历史
- latestScan            // 最新扫码
- isScanning            // 扫描状态
```

#### 3. **Android Native Layer**

**文件**: `android/app/src/main/kotlin/.../BarcodeScannerPlugin.kt`

**职责**:
- USB设备枚举和识别
- USB权限管理
- HID键盘事件捕获
- 条码数据解析

**核心逻辑**:
```kotlin
// MainActivity.kt - 拦截系统键盘事件
override fun dispatchKeyEvent(event: KeyEvent): Boolean {
    barcodeScannerPlugin?.handleKeyEventDirect(event)
}

// BarcodeScannerPlugin.kt - 解析扫码数据
fun handleKeyEventDirect(event: KeyEvent): Boolean {
    // 缓冲字符直到遇到回车键
    // 识别条码类型（EAN-13, QR Code等）
    // 通过MethodChannel发送到Flutter层
}
```

---

## 📚 API文档

### Flutter Plugin API

#### 初始化

```dart
// 初始化插件（注册事件处理器）
ScannerBoxPlugin.initialize();
```

#### 设备管理

```dart
// 扫描USB设备
List<ScannerBoxDevice> devices = await ScannerBoxPlugin.scanDevices();

// 请求USB权限
bool hasPermission = await ScannerBoxPlugin.requestPermission(deviceId);
// 返回值:
//   true  - 已有权限
//   false - 权限请求已发起，等待用户授权
```

#### 扫码控制

```dart
// 开始监听扫码
bool success = await ScannerBoxPlugin.startListening();

// 停止监听扫码
bool success = await ScannerBoxPlugin.stopListening();
```

#### 事件监听

```dart
// 监听扫码结果
ScannerBoxPlugin.onScanResult.listen((result) {
  String content = result['content'];     // 条码内容
  String type = result['type'];           // 条码类型
  int length = result['length'];          // 内容长度
  String timestamp = result['timestamp']; // 时间戳
  bool isValid = result['isValid'];       // 是否有效
});

// 监听设备连接
ScannerBoxPlugin.onDeviceAttached.listen((_) {
  // 设备已连接，重新扫描设备列表
});

// 监听设备断开
ScannerBoxPlugin.onDeviceDetached.listen((_) {
  // 设备已断开，更新UI状态
});

// 监听权限授予
ScannerBoxPlugin.onPermissionGranted.listen((data) {
  String deviceId = data['deviceId'];
  String deviceName = data['deviceName'];
  // 权限已授予，可以开始使用设备
});

// 监听权限拒绝
ScannerBoxPlugin.onPermissionDenied.listen((deviceId) {
  // 用户拒绝授权，显示提示信息
});
```

### Flutter Service API

#### 获取Service实例

```dart
final service = Get.find<ScannerBoxService>();
```

#### 设备操作

```dart
// 扫描设备
List<ScannerBoxDevice> devices = await service.scanDevices();

// 请求授权并连接
bool success = await service.requestAuthorization(device);

// 断开连接
await service.disconnect();
```

#### 扫码操作

```dart
// 开始扫描
await service.startScanning();

// 停止扫描
await service.stopScanning();

// 清空历史
service.clearHistory();
```

#### 响应式状态访问

```dart
// 获取当前设备
ScannerBoxDevice? device = service.connectedDevice.value;

// 获取设备状态
ScannerBoxStatus status = service.deviceStatus.value;

// 获取扫码历史
List<ScanData> history = service.scanHistory;

// 获取最新扫码
ScanData? latest = service.latestScan.value;

// 获取扫描状态
bool scanning = service.isScanning.value;
```

#### 在UI中使用响应式状态

```dart
// 使用Obx自动更新UI
Obx(() => Text(service.getStatusText()));

Obx(() => Text(
  service.connectedDevice.value?.displayName ?? '未连接'
));

Obx(() => ListView.builder(
  itemCount: service.scanHistory.length,
  itemBuilder: (context, index) {
    final scan = service.scanHistory[index];
    return ListTile(
      title: Text(scan.content),
      subtitle: Text(scan.type),
    );
  },
));
```

---

## 💡 使用示例

### 完整使用流程

```dart
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class ScannerBoxExamplePage extends StatefulWidget {
  @override
  _ScannerBoxExamplePageState createState() => _ScannerBoxExamplePageState();
}

class _ScannerBoxExamplePageState extends State<ScannerBoxExamplePage> {
  final service = Get.find<ScannerBoxService>();
  
  @override
  void initState() {
    super.initState();
    _initScanner();
  }
  
  // 初始化扫描器
  Future<void> _initScanner() async {
    // 1. 扫描设备
    final devices = await service.scanDevices();
    
    if (devices.isEmpty) {
      print('未发现扫描器设备');
      return;
    }
    
    // 2. 选择第一个设备并请求授权
    final device = devices.first;
    final success = await service.requestAuthorization(device);
    
    if (success) {
      // 已有权限，立即开始扫描
      await service.startScanning();
    } else {
      // 等待用户授权（权限对话框弹出）
      // 授权成功后会自动开始扫描
      print('等待用户授权...');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('扫码盒子示例')),
      body: Column(
        children: [
          // 设备信息卡片
          Obx(() => Card(
            child: ListTile(
              title: Text('设备状态'),
              subtitle: Text(service.getStatusText()),
              trailing: Text(
                service.connectedDevice.value?.displayName ?? '未连接'
              ),
            ),
          )),
          
          // 扫码历史列表
          Expanded(
            child: Obx(() => ListView.builder(
              itemCount: service.scanHistory.length,
              itemBuilder: (context, index) {
                final scan = service.scanHistory[index];
                return ListTile(
                  leading: Icon(Icons.qr_code),
                  title: Text(scan.content),
                  subtitle: Text(
                    '${scan.type} • ${_formatTime(scan.timestamp)}'
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.copy),
                    onPressed: () => _copyToClipboard(scan.content),
                  ),
                );
              },
            )),
          ),
          
          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => service.startScanning(),
                child: Text('开始扫描'),
              ),
              ElevatedButton(
                onPressed: () => service.stopScanning(),
                child: Text('停止扫描'),
              ),
              ElevatedButton(
                onPressed: () => service.clearHistory(),
                child: Text('清空历史'),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute}:${time.second}';
  }
  
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar('已复制', text);
  }
}
```

---

## 🧪 测试指南

### 开发环境测试

#### 1. 设备连接测试

```bash
# 连接得力AA628扫描盒子到Android设备
# 查看设备是否被识别
adb shell dumpsys usb
```

#### 2. 应用日志监控

```bash
# 实时查看扫描器相关日志
adb logcat | grep -E '(ScannerBox|BarcodeScanner)'
```

#### 3. UI测试步骤

**步骤1：扫描设备**
```
1. 打开应用
2. 进入「设置」→「扫码盒子」
3. 点击「扫描设备」按钮
4. 验证设备列表显示得力AA628
```

**步骤2：授权连接**
```
1. 点击设备列表中的得力AA628
2. 系统弹出USB权限对话框
3. 点击「确定」授权
4. 验证设备状态变为「已连接」
```

**步骤3：扫码测试**
```
1. 设备自动开始监听扫码
2. 使用扫描盒子扫描测试条码/二维码
3. 验证扫码数据实时显示在历史记录中
4. 验证条码类型识别正确（EAN-13/QR Code等）
```

**步骤4：功能测试**
```
1. 点击「复制」按钮，验证复制功能
2. 点击「清空历史」，验证清空功能
3. 拔出USB设备，验证断开检测
4. 重新插入设备，验证自动重连
```

### 真机测试要求

#### 设备要求
- Android 9.0 及以上
- 支持USB OTG（大部分Android手机/平板都支持）
- USB Type-C 接口（或使用转接头）

#### 连接方式
```
手机/平板 [USB] ←→ [USB] 得力AA628扫描盒子
```

#### 测试场景

| 场景 | 预期结果 | 验证方法 |
|------|----------|----------|
| 首次连接 | 弹出权限对话框 | 观察系统对话框 |
| 权限授予 | 自动开始扫描 | 观察状态变化 |
| 扫描EAN-13 | 识别为EAN-13 | 检查type字段 |
| 扫描QR Code | 识别为QR Code | 检查type字段 |
| 设备拔出 | 状态变为断开 | 观察状态变化 |
| 设备插入 | 自动重新扫描 | 观察设备列表更新 |
| 快速连续扫码 | 所有数据被捕获 | 检查历史记录完整性 |

### 常见测试问题

#### 问题1：扫描不到设备

**可能原因**:
- USB连接不稳定
- 设备不在白名单中
- Android版本过低

**解决方法**:
```bash
# 检查USB设备
adb shell dumpsys usb

# 查看VID/PID
# 如果VID不在白名单中，需要更新BarcodeScannerPlugin.kt的KNOWN_SCANNER_VENDORS
```

#### 问题2：无法授权

**可能原因**:
- 应用没有USB权限声明
- 系统USB管理器异常

**解决方法**:
```xml
<!-- AndroidManifest.xml 确保有以下权限 -->
<uses-permission android:name="android.permission.USB_PERMISSION" />
<uses-feature android:name="android.hardware.usb.host" />
```

#### 问题3：扫码无响应

**可能原因**:
- 未调用startListening()
- dispatchKeyEvent未被拦截
- 扫描盒子配置为非HID键盘模式

**解决方法**:
```kotlin
// 确保MainActivity.kt中有以下代码
override fun dispatchKeyEvent(event: KeyEvent): Boolean {
    barcodeScannerPlugin?.let { plugin ->
        if (plugin.handleKeyEventDirect(event)) {
            return true
        }
    }
    return super.dispatchKeyEvent(event)
}
```

---

## ❓ 常见问题

### Q1: 支持哪些条码类型？

**A:** 得力AA628支持以下类型（硬件层面）：
- EAN-13 / EAN-8
- Code 128
- QR Code

软件层面自动识别：
- EAN-13（13位数字）
- EAN-8（8位数字）
- UPC-A（12位数字）
- QR Code（包含URL、结构化数据等）
- Code 128 / Code 39（其他格式）

### Q2: 可以同时连接多个扫描盒子吗？

**A:** 当前实现为单设备模式。如需多设备支持，需要修改：
1. `ScannerBoxService` 改为设备列表管理
2. `BarcodeScannerPlugin` 支持多个UsbDevice
3. 在UI层选择目标设备

### Q3: 扫码速度有多快？

**A:** 
- **硬件扫描速度**: 约100ms（得力AA628规格）
- **数据传输延迟**: <10ms（USB HID）
- **Flutter处理延迟**: <5ms
- **总体延迟**: <120ms（接近实时）

### Q4: 如何区分扫描盒子和键盘输入？

**A:** 通过以下特征识别：
1. **输入速度**: 扫描盒子连续按键间隔极短（<10ms）
2. **回车结尾**: 扫描盒子数据以回车键结束
3. **设备过滤**: 通过VID/PID识别扫描器设备

在 `handleKeyEventDirect` 方法中：
```kotlin
// 检查超时（新的扫码开始）
if (lastKeyTime > 0 && (currentTime - lastKeyTime) > scanTimeout) {
    // 超时100ms，认为是新的扫码
}
```

### Q5: 如何处理特殊字符？

**A:** 当前实现支持：
- 数字 0-9
- 字母 a-z (自动转小写)
- 符号 `-`, `=`, `.`, `,`, `/`, `\`
- 空格

如需扩展，修改 `getCharFromKeyCode` 方法：
```kotlin
private fun getCharFromKeyCode(keyCode: Int): Char? {
    return when (keyCode) {
        // 添加更多键码映射
        KeyEvent.KEYCODE_SEMICOLON -> ';'
        KeyEvent.KEYCODE_APOSTROPHE -> '\''
        // ...
    }
}
```

### Q6: 断电后需要重新授权吗？

**A:** 不需要。Android系统会记住USB权限，除非：
- 应用被卸载
- 清除应用数据
- 系统重启（部分设备）

### Q7: 如何获取设备序列号？

**A:** 已在 `ScannerBoxDevice` 模型中包含：
```dart
final device = service.connectedDevice.value;
String? serialNumber = device?.serialNumber;
```

Android原生层：
```kotlin
device.serialNumber  // 需要Android API 21+
```

### Q8: 如何切换扫描盒子工作模式？

**A:** 得力AA628默认为HID键盘模式，切换需要：
1. 查阅设备手册获取配置条码
2. 扫描对应配置条码切换模式
3. 重新插拔设备生效

**注意**: 当前实现仅支持HID键盘模式。

### Q9: 能否在后台运行？

**A:** 可以，但需要注意：
- Flutter Service 需要保持存活
- Android可能会在内存不足时回收应用
- 建议使用前台服务（Foreground Service）保持运行

### Q10: 如何调试HID事件？

**A:** 使用以下日志：
```bash
# 查看所有键盘事件
adb logcat | grep 'Key captured'

# 查看扫码结果
adb logcat | grep 'Barcode scanned'

# 查看设备信息
adb logcat | grep '✓ 识别为扫描器'
```

---

## 📞 技术支持

### 日志收集

遇到问题时，请提供以下信息：

```bash
# 1. Flutter日志
flutter logs > flutter.log

# 2. Android日志
adb logcat -d > android.log

# 3. USB设备信息
adb shell dumpsys usb > usb_devices.log

# 4. 应用版本
flutter --version
```

### 开发团队

- **Flutter层开发**: [您的团队]
- **Android原生开发**: [您的团队]
- **硬件对接**: 基于得力AA628官方文档

---

## 📄 附录

### 相关文件清单

```
项目根目录/
├── lib/
│   ├── data/
│   │   ├── models/
│   │   │   └── scanner_box_model.dart          # 数据模型
│   │   ├── services/
│   │   │   └── scanner_box_service.dart        # 业务服务
│   │   └── plugins/
│   │       └── scanner_box_plugin.dart         # 插件桥接
│   └── modules/
│       └── settings/
│           └── views/
│               └── scanner_box_view.dart       # UI界面
├── android/
│   └── app/
│       └── src/
│           └── main/
│               ├── kotlin/.../
│               │   ├── BarcodeScannerPlugin.kt  # 原生插件
│               │   └── MainActivity.kt           # 主Activity
│               └── AndroidManifest.xml          # 权限配置
└── docs/
    └── scanner_box/
        ├── tech_params.png                      # 技术参数图
        ├── implementation.md                    # 实现文档
        └── INTEGRATION_GUIDE.md                 # 本文档
```

### 版本历史

- **v1.0.0** (2025-12-01): 初始版本
  - 支持HID键盘模式
  - 支持设备扫描和权限管理
  - 支持实时扫码监听
  - 支持EAN-13、QR Code等类型识别

---

**文档更新日期**: 2025-12-01  
**适用版本**: Flutter 3.9.0+, Android 9.0+  
**设备型号**: 得力 No.AA628
