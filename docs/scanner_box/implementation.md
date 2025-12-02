# 得力扫描盒子 AA628 对接开发文档（Flutter + Android 9+）

设备是得力制造；设备型号是No.AA628;
## 1. 文档目标

本对接文档指导 Flutter 应用接入得力 AA628 扫描盒子，实现以下能力： -
获取设备元数据信息（厂商、型号、VID/PID、序列号等） - 获取扫码数据（支持
HID 键盘与 USB HID）

## 2. 设备通讯方式

得力 AA628 常见以下模式： - HID Keyboard（默认） - USB HID POS - USB
Serial（少见）

## 3. 获取设备信息卡片内容

Android 使用 UsbManager 枚举设备并读取：

    device.manufacturerName
    device.productName
    device.serialNumber
    device.vendorId
    device.productId

## 4. 获取扫码数据

### HID 键盘模式

在 Activity.dispatchKeyEvent 捕获 KeyEvent，回车符号代表扫码结束。

### USB HID 模式

使用 connection.bulkTransfer 读取 HID 报文并解析。

## 5. Flutter Plugin API 设计

-   ScannerManager.init()
-   ScannerManager.onDeviceInfo
-   ScannerManager.onScan
-   ScannerManager.getCurrentDevice()

## 6. JSON 数据结构

### 设备信息

    {
      "manufacturer": "Deli",
      "productName": "AA628",
      "serialNumber": "xxx",
      "vid": 1234,
      "pid": 5678,
      "connectionType": "HID-Keyboard"
    }

### 扫码数据

    {
      "barcode": "6901234567890",
      "timestamp": 1732271000000
    }

## 7. 测试项

-   设备插入能检测
-   正确获取 VID/PID/型号/厂商
-   HID 扫码稳定
-   USB HID 扫码正常（可选）
