# 扫描器组件库

> **统一的USB扫描器集成方案，简化开发流程**

## 📚 目录

- [组件架构](#组件架构)
- [快速开始](#快速开始)
- [组件详解](#组件详解)
- [使用场景](#使用场景)
- [API参考](#api参考)
- [最佳实践](#最佳实践)
- [常见问题](#常见问题)

---

## 🏗️ 组件架构

### 核心组件

```
scanner_components/
├── scanner_controller_mixin.dart   # Controller混入（自动生命周期管理）
├── scanner_indicator_widget.dart   # UI指示器组件（状态可视化）
├── scanner_utils.dart              # 工具类（便捷方法）
├── scanner_components.dart         # 统一导出
└── scanner_usage_example.dart      # 完整示例
```

### 依赖关系

```
BarcodeScannerService (全局单例)
        ↓
    ┌───┴────┐
    ↓        ↓
Mixin    Utils → 各业务页面
    ↓        ↓
  Widget ────┘
```

---

## 🚀 快速开始

### 方法 1: 使用 Mixin（推荐用于复杂页面）

**适用场景**: 商品搜索、收银台、库存盘点等需要复杂业务逻辑的页面

```dart
import 'package:ailand_pos/shared/components/scanner/scanner_components.dart';

// 1. Controller中混入ScannerControllerMixin
class ProductSearchController extends GetxController with ScannerControllerMixin {
  @override
  void onScanSuccess(ScanResult result) {
    // 处理扫描结果
    if (ScannerUtils.isValidProductBarcode(result)) {
      final barcode = ScannerUtils.formatBarcode(result.content);
      print('扫到商品: $barcode');
      // 调用API查询商品...
    }
  }
}

// 2. View中使用指示器组件
class ProductSearchPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProductSearchController());
    
    return Scaffold(
      body: Column(
        children: [
          ScannerIndicatorWidget(),  // 显示扫描器状态
          // 其他UI...
        ],
      ),
    );
  }
}
```

**✅ 自动完成**:
- ✓ 页面加载时自动启动扫描监听
- ✓ 页面销毁时自动停止监听
- ✓ 自动选择第一个已连接设备
- ✓ 无需手动管理生命周期

---

### 方法 2: 使用 Utils 工具类（推荐用于简单场景）

**适用场景**: 快速原型、简单扫码功能、一次性扫码

```dart
import 'package:ailand_pos/shared/components/scanner/scanner_components.dart';

class SimpleScanPage extends StatefulWidget {
  @override
  State<SimpleScanPage> createState() => _SimpleScanPageState();
}

class _SimpleScanPageState extends State<SimpleScanPage> {
  @override
  void initState() {
    super.initState();
    
    // 快速启动连续扫描
    ScannerUtils.quickStart(
      onScan: (result) {
        print('扫码内容: ${result.content}');
      },
      onError: (error) {
        print('扫描错误: $error');
      },
    );
  }
  
  @override
  void dispose() {
    ScannerUtils.stop();  // 停止扫描
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ScannerIndicatorWidget(),
      ),
    );
  }
}
```

**一次性扫码示例**:

```dart
// 扫描一次后自动停止
await ScannerUtils.scanOnce(
  onScan: (result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('扫码结果'),
        content: Text(result.content),
      ),
    );
  },
  timeout: Duration(seconds: 10),  // 10秒超时
);
```

---

## 📦 组件详解

### 1️⃣ ScannerControllerMixin

**功能**: 提供扫描器生命周期自动管理

**核心方法**:

| 方法 | 说明 | 必需重写 |
|------|------|----------|
| `onScanSuccess(result)` | 扫描成功回调 | ✅ 必需 |
| `onScanError(error)` | 扫描错误回调 | ❌ 可选 |
| `startScanning()` | 手动启动扫描 | ❌ 自动 |
| `stopScanning()` | 手动停止扫描 | ❌ 自动 |

**配置属性**:

```dart
class MyController extends GetxController with ScannerControllerMixin {
  // 是否自动启动监听（默认true）
  @override
  bool get autoStartListening => true;
  
  // 是否在销毁时自动停止（默认true）
  @override
  bool get autoStopOnDispose => true;
  
  @override
  void onScanSuccess(ScanResult result) {
    // 处理扫描结果
  }
}
```

---

### 2️⃣ ScannerIndicatorWidget

**功能**: 可视化显示扫描器状态

**参数**:

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `size` | `double?` | `120` | 指示器大小 |
| `showLabel` | `bool` | `true` | 是否显示文字标签 |
| `customLabel` | `String?` | `null` | 自定义标签文本 |
| `onTap` | `VoidCallback?` | `null` | 点击回调 |
| `enablePulse` | `bool` | `true` | 是否启用脉冲动画 |

**使用示例**:

```dart
// 默认样式
ScannerIndicatorWidget()

// 小尺寸（AppBar中使用）
ScannerIndicatorWidget(
  size: 40,
  showLabel: false,
)

// 自定义样式
ScannerIndicatorWidget(
  size: 150,
  customLabel: '请扫描商品条码',
  enablePulse: false,
  onTap: () => print('点击了指示器'),
)
```

**状态显示**:

| 状态 | 图标 | 颜色 | 动画 |
|------|------|------|------|
| 监听中 | `qr_code_scanner` | 绿色 | 脉冲 |
| 未就绪 | `qr_code_2` | 灰色 | 无 |
| 错误 | `error_outline` | 红色 | 无 |

---

### 3️⃣ ScannerUtils

**功能**: 提供便捷的扫描器操作方法

**常用方法**:

#### `quickStart()`
快速启动连续扫描

```dart
await ScannerUtils.quickStart(
  onScan: (result) {
    // 处理每次扫描结果
  },
  onError: (error) {
    // 处理错误
  },
  autoSelectDevice: true,  // 自动选择第一个已连接设备
);
```

#### `scanOnce()`
一次性扫描（扫描后自动停止）

```dart
await ScannerUtils.scanOnce(
  onScan: (result) {
    // 处理结果
  },
  onError: (error) {
    // 处理错误或超时
  },
  timeout: Duration(seconds: 30),
);
```

#### `stop()`
停止扫描并清理监听器

```dart
ScannerUtils.stop();
```

#### `isValidProductBarcode(result)`
验证是否为有效的商品条码

```dart
if (ScannerUtils.isValidProductBarcode(result)) {
  // 是有效的商品条码（8-14位数字）
}
```

#### `formatBarcode(barcode)`
格式化条码（去除空格和特殊字符）

```dart
final clean = ScannerUtils.formatBarcode('1234-5678-90');
// 结果: "123456789
```

#### 状态查询

```dart
// 检查扫描器是否就绪
if (ScannerUtils.isReady) {
  print('扫描器已就绪');
}

// 获取当前设备名称
final deviceName = ScannerUtils.currentDeviceName;
print('当前设备: $deviceName');
```

---

## 🎯 使用场景

### 场景 1: 商品搜索页面

```dart
class ProductSearchController extends GetxController with ScannerControllerMixin {
  final RxList<Product> searchResults = <Product>[].obs;
  
  @override
  void onScanSuccess(ScanResult result) {
    if (ScannerUtils.isValidProductBarcode(result)) {
      _searchProductByBarcode(result.content);
    } else {
      Get.snackbar('提示', '请扫描有效的商品条码');
    }
  }
  
  Future<void> _searchProductByBarcode(String barcode) async {
    final products = await productRepository.searchByBarcode(barcode);
    searchResults.value = products;
  }
}
```

### 场景 2: 收银台

```dart
class CheckoutController extends GetxController with ScannerControllerMixin {
  final RxList<CartItem> cartItems = <CartItem>[].obs;
  final RxDouble totalAmount = 0.0.obs;
  
  @override
  void onScanSuccess(ScanResult result) {
    if (ScannerUtils.isValidProductBarcode(result)) {
      _addToCart(result.content);
    }
  }
  
  Future<void> _addToCart(String barcode) async {
    final product = await productRepository.getByBarcode(barcode);
    if (product != null) {
      cartItems.add(CartItem.fromProduct(product));
      totalAmount.value += product.price;
      
      // 播放提示音
      AudioService.playBeep();
    }
  }
}
```

### 场景 3: 库存盘点

```dart
class InventoryController extends GetxController with ScannerControllerMixin {
  final RxMap<String, int> scannedItems = <String, int>{}.obs;
  
  @override
  void onScanSuccess(ScanResult result) {
    final barcode = ScannerUtils.formatBarcode(result.content);
    
    // 累计扫描次数
    scannedItems[barcode] = (scannedItems[barcode] ?? 0) + 1;
    
    // 显示提示
    Get.snackbar(
      '盘点',
      '商品: $barcode, 数量: ${scannedItems[barcode]}',
      duration: Duration(seconds: 1),
    );
  }
}
```

---

## 📖 API 参考

### ScanResult 数据模型

```dart
class ScanResult {
  final String content;       // 扫描内容
  final String type;          // 类型: BARCODE | QR_CODE
  final int length;           // 内容长度
  final DateTime timestamp;   // 扫描时间
  final bool isValid;         // 是否有效
  final String? rawData;      // 原始数据
}
```

### BarcodeScannerService 服务

**响应式状态**:

```dart
final service = Get.find<BarcodeScannerService>();

// 监听扫描结果
service.scanData.listen((result) {
  if (result != null) {
    print('扫码: ${result.content}');
  }
});

// 监听监听状态
service.isListening.listen((listening) {
  print('监听状态: $listening');
});

// 监听错误
service.lastError.listen((error) {
  if (error != null) {
    print('错误: $error');
  }
});
```

---

## 💡 最佳实践

### 1. 选择合适的集成方式

| 场景 | 推荐方式 | 原因 |
|------|----------|------|
| 复杂业务页面 | Mixin | 自动生命周期管理，代码清晰 |
| 简单扫码功能 | Utils | 代码简洁，快速集成 |
| 一次性扫码 | `scanOnce()` | 自动停止，防止重复触发 |
| 多页面共享 | 全局Service | 统一管理，状态同步 |

### 2. 错误处理

```dart
@override
void onScanSuccess(ScanResult result) {
  try {
    // 1. 验证条码格式
    if (!ScannerUtils.isValidProductBarcode(result)) {
      onScanError('无效的商品条码');
      return;
    }
    
    // 2. 格式化条码
    final barcode = ScannerUtils.formatBarcode(result.content);
    
    // 3. 处理业务逻辑
    _processBarcode(barcode);
  } catch (e) {
    onScanError('处理扫码结果失败: $e');
  }
}

@override
void onScanError(String error) {
  // 统一的错误提示
  Get.snackbar(
    '扫描错误',
    error,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: Colors.red.withOpacity(0.8),
    colorText: Colors.white,
  );
}
```

### 3. 性能优化

```dart
class ProductSearchController extends GetxController with ScannerControllerMixin {
  // 防抖：避免短时间内重复扫描
  Timer? _debounceTimer;
  String? _lastBarcode;
  
  @override
  void onScanSuccess(ScanResult result) {
    final barcode = result.content;
    
    // 如果是相同条码且在500ms内，忽略
    if (barcode == _lastBarcode && _debounceTimer != null) {
      return;
    }
    
    _lastBarcode = barcode;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 500), () {
      _lastBarcode = null;
    });
    
    // 处理扫码
    _processBarcode(barcode);
  }
  
  @override
  void onClose() {
    _debounceTimer?.cancel();
    super.onClose();
  }
}
```

### 4. UI反馈

```dart
// 在AppBar中显示小型指示器
AppBar(
  title: Text('收银台'),
  actions: [
    Center(
      child: Padding(
        padding: EdgeInsets.only(right: 16),
        child: ScannerIndicatorWidget(
          size: 40,
          showLabel: false,
          onTap: () {
            // 点击查看扫描器详情
            Get.toNamed('/scanner-settings');
          },
        ),
      ),
    ),
  ],
)
```

---

## ❓ 常见问题

### Q1: 扫描器无响应？

**检查清单**:
1. ✅ 是否调用了 `scanUsbScanners()` 或 `quickStart()`
2. ✅ 设备是否已授予USB权限
3. ✅ `isListening` 状态是否为 `true`
4. ✅ 检查 `lastError` 是否有错误信息

**调试代码**:
```dart
final service = Get.find<BarcodeScannerService>();
print('监听状态: ${service.isListening.value}');
print('选中设备: ${service.selectedScanner.value?.deviceName}');
print('最后错误: ${service.lastError.value}');
```

### Q2: 如何在多个页面共享扫描器？

扫描器服务是全局单例，所有页面共享同一个实例：

```dart
// 页面A启动监听
class PageA extends GetxController with ScannerControllerMixin {
  @override
  void onScanSuccess(ScanResult result) {
    print('PageA收到: ${result.content}');
  }
}

// 页面B也能收到扫描结果
class PageB extends GetxController with ScannerControllerMixin {
  @override
  void onScanSuccess(ScanResult result) {
    print('PageB收到: ${result.content}');
  }
}
```

**注意**: 两个页面都会收到扫描结果，需要根据页面路由判断是否处理。

### Q3: 如何测试扫描功能？

**方法1**: 使用模拟扫描器（开发环境）

```dart
// 在开发环境注入模拟数据
if (kDebugMode) {
  // 模拟扫描结果
  service.scanData.value = ScanResult(
    content: '1234567890',
    type: 'BARCODE',
    length: 10,
    timestamp: DateTime.now(),
    isValid: true,
  );
}
```

**方法2**: 使用键盘模拟扫描器

USB扫描器本质是HID键盘，可以用键盘模拟：
1. 输入商品条码（如：`1234567890`）
2. 按回车键
3. 应该触发扫描回调

### Q4: 扫描速度太快导致重复？

使用防抖机制（见[性能优化](#3-性能优化)章节）。

### Q5: 如何自定义扫描器设备选择？

```dart
class MyController extends GetxController with ScannerControllerMixin {
  @override
  bool get autoStartListening => false;  // 禁用自动启动
  
  @override
  void onInit() {
    super.onInit();
    _customDeviceSelection();
  }
  
  Future<void> _customDeviceSelection() async {
    // 扫描设备
    await scannerService.scanUsbScanners();
    
    // 显示设备选择对话框
    final selectedDevice = await showDeviceSelectionDialog();
    
    if (selectedDevice != null) {
      scannerService.selectedScanner.value = selectedDevice;
      await startScanning();
    }
  }
}
```

---

## 🔄 从旧代码迁移

### 旧代码模式

```dart
// ❌ 旧方式：手动管理生命周期
class OldController extends GetxController {
  final BarcodeScannerService _scanner = Get.find();
  Worker? _worker;
  
  @override
  void onInit() {
    super.onInit();
    _worker = ever(_scanner.scanData, (result) {
      if (result != null) {
        // 处理结果
      }
    });
    _scanner.startListening();
  }
  
  @override
  void onClose() {
    _worker?.dispose();
    _scanner.stopListening();
    super.onClose();
  }
}
```

### 新代码模式

```dart
// ✅ 新方式：使用Mixin自动管理
class NewController extends GetxController with ScannerControllerMixin {
  @override
  void onScanSuccess(ScanResult result) {
    // 处理结果（自动管理生命周期）
  }
}
```

**迁移步骤**:
1. ✅ 添加 `with ScannerControllerMixin`
2. ✅ 实现 `onScanSuccess()` 方法
3. ✅ 删除手动的监听器和生命周期代码
4. ✅ （可选）重写 `onScanError()` 自定义错误处理

---

## 📝 总结

**核心优势**:
- ✅ **零样板代码**: 一行Mixin解决生命周期
- ✅ **类型安全**: 完整的TypeScript式类型定义
- ✅ **响应式**: 基于GetX的响应式状态管理
- ✅ **可复用**: UI组件和工具类高度可复用
- ✅ **易测试**: 清晰的接口便于单元测试
- ✅ **自动化**: 设备选择、生命周期全自动

**快速参考**:

| 需求 | 使用方案 |
|------|----------|
| 复杂页面 | `ScannerControllerMixin` |
| 简单功能 | `ScannerUtils.quickStart()` |
| 单次扫码 | `ScannerUtils.scanOnce()` |
| UI指示器 | `ScannerIndicatorWidget` |
| 验证条码 | `ScannerUtils.isValidProductBarcode()` |
| 格式化 | `ScannerUtils.formatBarcode()` |

---

**版本**: 1.0.0  
**更新日期**: 2025-01-18  
**维护者**: AI Development Team
