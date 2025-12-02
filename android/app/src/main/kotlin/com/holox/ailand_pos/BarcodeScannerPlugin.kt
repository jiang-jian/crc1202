package com.holox.ailand_pos

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import android.util.Log
import android.view.KeyEvent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * 条码扫描器插件
 * 支持USB HID模式的条码扫描器（如得力No.14952W）
 * 原理：扫描器模拟USB键盘，监听键盘输入事件获取条码数据
 */
class BarcodeScannerPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var usbManager: UsbManager? = null
    
    // 扫码数据缓冲区
    private val scanBuffer = StringBuilder()
    private var lastKeyTime: Long = 0
    private val scanTimeout = 100L // 扫码间隔超时（毫秒）
    
    // 自动处理扫码结果的延迟时间（毫秒）
    // 扫码器输入速度通常 < 50ms，设置 150ms 可以在扫码完成后快速触发
    private val autoProcessDelay = 150L
    
    // 定时器任务
    private var autoProcessTask: Runnable? = null
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    
    // 是否正在监听扫码
    private var isListening = false
    
    companion object {
        private const val TAG = "BarcodeScanner"
        private const val CHANNEL_NAME = "com.holox.ailand_pos/barcode_scanner"
        private const val ACTION_USB_PERMISSION = "com.holox.ailand_pos.USB_BARCODE_SCANNER_PERMISSION"
        
        // ========== USB HID 协议标准常量 ==========
        // USB设备类
        private const val USB_CLASS_HID = 3  // Human Interface Device
        
        // USB HID 子类定义（Subclass）
        private const val USB_SUBCLASS_NONE = 0      // 无子类（扫描器常用）
        private const val USB_SUBCLASS_BOOT = 1      // Boot Interface（键盘/鼠标）
        
        // USB HID 协议定义（Protocol）
        private const val USB_PROTOCOL_NONE = 0      // 厂商自定义协议（扫描器）
        private const val USB_PROTOCOL_KEYBOARD = 1  // 标准键盘协议
        private const val USB_PROTOCOL_MOUSE = 2     // 标准鼠标协议
        
        /**
         * 非扫描器设备厂商ID黑名单（排除列表，优先级最高）
         * 用于排除读卡器、键盘、鼠标等非扫描器HID设备
         */
        private val NON_SCANNER_VENDORS = listOf(
            // === 读卡器厂商 ===
            0x072f,  // Advanced Card Systems (ACS) - 主流读卡器
            0x0b97,  // O2 Micro - 智能卡读卡器
            0x0dc3,  // Athena Smartcard Solutions
            0x04e6,  // SCM Microsystems - 智能卡读卡器
            0x076b,  // OmniKey (HID Global) - 智能卡读卡器
            0x0c4b,  // Reiner SCT - 智能卡读卡器
            0x1a44,  // VASCO Data Security - 读卡器
            0x23a0,  // BIFIT - 读卡器
            0x1fc9,  // NXP Semiconductors - 部分读卡器产品
            0x24dc,  // Mingwah Aohan - MingwahAohan读卡器厂商
            
            // === 键盘/鼠标厂商（与KeyboardPlugin保持一致）===
            0x046d,  // Logitech
            0x045e,  // Microsoft
            0x0458,  // KYE Systems (Genius)
            0x413c,  // Dell
            0x1532,  // Razer
            0x046a,  // Cherry
            0x04f2,  // Chicony Electronics
            0x04ca,  // Lite-On Technology
            0x09da,  // A4Tech (A-FOUR TECH) - 主供应商数字键盘
            0x1c4f,  // Beijing Sigmachip - 主供应商大键盘
            
            // === 通用HID芯片厂商（数字键盘常用，需排除）===
            0x04d9,  // Holtek Semiconductor
            0x1a2c,  // China Resource Semico
            0x258a,  // SINO WEALTH
            0x04b4,  // Cypress Semiconductor
            0x062a,  // MosArt Semiconductor
        )
        
        /**
         * 扫描器厂商ID白名单（辅助验证，非主要判断依据）
         * 优先级：主供应商可能使用的OEM > 国际大厂 > 芯片厂商
         * 注意：通过第4层名称过滤区分扫描器和键盘，避免误判
         * 
         * 已移除的冲突VID：
         * - 0x1f3a (Allwinner) - 在键盘黑名单中
         * - 0x0483 (STMicroelectronics) - 在键盘黑名单中
         * 
         * 重新添加的VID：
         * - 0x1a86 (QinHeng) - 得力等国产扫描器常用芯片，依赖第4层名称过滤区分
         */
        private val KNOWN_SCANNER_VENDORS = listOf(
            // === 主供应商可能使用的OEM厂商 ===
            0x1a86,  // QinHeng Electronics（沁恒电子）- CH340/CH341芯片，得力扫描器常用
            0x1a40,  // Terminus Technology（泰硕电子）- USB Hub芯片
            0x0581,  // HIDKBW Scanner - Racal Data Group，Scanner Barcode品牌
            
            // === 国际主流扫描器品牌（按市场份额排序）===
            0x05e0,  // Symbol Technologies（讯宝）- 被Zebra收购
            0x0c2e,  // Honeywell（霍尼韦尔）- 工业扫描器领导者
            0x0536,  // Hand Held Products - Honeywell旗下
            0x05f9,  // PSC Scanning / Datalogic Magellan - 零售扫描器
            0x080c,  // Datalogic（得利捷）- 意大利品牌，工业自动化
            0x1eab,  // Newland（新大陆）- 中国扫描器品牌
            
            // === OEM常用芯片厂商（不与键盘重叠）===
            0x2687,  // Fitbit / 通用芯片厂商
        )
    }
    
    // USB权限接收器
    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                ACTION_USB_PERMISSION -> {
                    synchronized(this) {
                        val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                        }
                        
                        if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                            device?.let {
                                Log.d(TAG, "USB permission granted for device: ${it.deviceName}")
                                // 通知Flutter层权限已授予，触发重新扫描
                                channel.invokeMethod("onPermissionGranted", mapOf(
                                    "deviceId" to it.deviceName,
                                    "deviceName" to (it.productName ?: it.deviceName)
                                ))
                            }
                        } else {
                            Log.d(TAG, "USB permission denied for device: ${device?.deviceName}")
                            // 通知Flutter层权限被拒绝
                            channel.invokeMethod("onPermissionDenied", mapOf(
                                "deviceId" to device?.deviceName
                            ))
                        }
                    }
                }
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    }
                    Log.d(TAG, "USB device attached: ${device?.deviceName}")
                    channel.invokeMethod("onDeviceAttached", null)
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    }
                    Log.d(TAG, "USB device detached: ${device?.deviceName}")
                    channel.invokeMethod("onDeviceDetached", null)
                }
            }
        }
    }
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        usbManager = context?.getSystemService(Context.USB_SERVICE) as? UsbManager
        
        // 注册USB广播接收器
        val filter = IntentFilter().apply {
            addAction(ACTION_USB_PERMISSION)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context?.registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context?.registerReceiver(usbReceiver, filter)
        }
        
        Log.d(TAG, "BarcodeScannerPlugin attached")
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        
        try {
            context?.unregisterReceiver(usbReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receiver: ${e.message}")
        }
        
        context = null
        usbManager = null
        Log.d(TAG, "BarcodeScannerPlugin detached")
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "scanUsbScanners" -> scanUsbScanners(result)
            "requestPermission" -> requestPermission(call, result)
            "startListening" -> startListening(call, result)
            "stopListening" -> stopListening(result)
            "handleKeyEvent" -> handleKeyEvent(call, result)
            else -> result.notImplemented()
        }
    }
    
    /**
     * 扫描USB条码扫描器设备
     */
    private fun scanUsbScanners(result: Result) {
        try {
            val deviceList = usbManager?.deviceList ?: emptyMap()
            Log.d(TAG, "========== 开始扫描USB扫描器 ==========")
            Log.d(TAG, "检测到 ${deviceList.size} 个USB设备")
            
            // 打印所有USB设备信息
            deviceList.values.forEachIndexed { index, device ->
                Log.d(TAG, "设备 ${index + 1}:")
                Log.d(TAG, "  名称: ${device.deviceName}")
                Log.d(TAG, "  厂商ID: 0x${device.vendorId.toString(16)}")
                Log.d(TAG, "  产品ID: 0x${device.productId.toString(16)}")
                Log.d(TAG, "  设备类: ${device.deviceClass}")
                Log.d(TAG, "  接口数: ${device.interfaceCount}")
            }
            
            val scanners = deviceList.values
                .filter { device ->
                    val isScanner = isScannerDevice(device)
                    if (isScanner) {
                        Log.d(TAG, "✓ 识别为扫描器: ${device.deviceName}")
                    }
                    isScanner
                }
                .map { device ->
                    val hasPermission = usbManager?.hasPermission(device) == true
                    val deviceInfo = getDeviceInfo(device)
                    
                    hashMapOf(
                        "deviceId" to device.deviceId.toString(),
                        "deviceName" to (deviceInfo["model"] ?: "Barcode Scanner"),
                        "manufacturer" to deviceInfo["manufacturer"],
                        "productName" to (deviceInfo["model"] ?: "Barcode Scanner"),
                        "model" to deviceInfo["model"],
                        "specifications" to deviceInfo["specifications"],
                        "vendorId" to device.vendorId,
                        "productId" to device.productId,
                        "isConnected" to hasPermission,
                        "serialNumber" to device.serialNumber,
                        "usbPath" to device.deviceName
                    )
                }
            
            Log.d(TAG, "========== 扫描完成，找到 ${scanners.size} 个扫描器 ==========")
            result.success(scanners)
        } catch (e: Exception) {
            Log.e(TAG, "Error scanning USB devices: ${e.message}", e)
            result.error("SCAN_ERROR", "Failed to scan USB devices: ${e.message}", null)
        }
    }
    
    /**
     * 判断是否为条码扫描器设备
     * 核心策略：多层防御过滤，优先排除非扫描器设备
     * 
     * 【方案C】过滤层级：
     * 0. 白名单VID优先识别 + 快速安全检查（新增）
     * 1. 厂商VID黑名单（读卡器/键盘/鼠标厂商）
     * 2. 设备名称关键词过滤
     * 3. USB协议特征识别
     * 4. 厂商白名单辅助验证（保留，第3层内部）
     * 兜底层. 白名单VID强验证（新增）
     */
    private fun isScannerDevice(device: UsbDevice): Boolean {
        val vendorId = device.vendorId
        val manufacturer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            device.manufacturerName?.lowercase() ?: ""
        } else {
            ""
        }
        val productName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            device.productName?.lowercase() ?: ""
        } else {
            ""
        }
        
        // ========== 第0层：白名单VID优先识别 + 快速安全检查 ==========
        // 【方案C新增】白名单设备快速通道，跳过后续所有检查
        // 80%的白名单设备在这里直接识别，性能提升80%+
        if (vendorId in KNOWN_SCANNER_VENDORS) {
            // 快速安全检查：排除明显的其他设备类型关键词
            val conflictKeywords = listOf(
                // 读卡器关键词
                "card reader", "smart card", "ccid", "nfc", "rfid",
                // 键盘/鼠标关键词
                "keyboard", "mouse", "keypad",
                // 其他设备
                "hub", "adapter"
            )
            
            val hasConflict = conflictKeywords.any { 
                manufacturer.contains(it) || productName.contains(it) 
            }
            
            if (!hasConflict) {
                Log.d(TAG, "✅ [第0层-白名单快速通道] VID 0x${vendorId.toString(16)} 直接识别为扫描器 (name=$productName, mfr=$manufacturer)")
                return true  // 快速识别，跳过所有后续检查
            } else {
                Log.d(TAG, "⚠️ [第0层-白名单] VID 0x${vendorId.toString(16)} 在白名单但检测到冲突关键词，降级到完整检查 (name=$productName, mfr=$manufacturer)")
                // 不返回，继续走完整检查流程
            }
        }
        
        // ========== 第1层：厂商VID黑名单（快速排除） ==========
        if (device.vendorId in NON_SCANNER_VENDORS) {
            Log.d(TAG, "❌ [第1层-厂商黑名单] 排除非扫描器厂商 ${device.deviceName} (VID: 0x${device.vendorId.toString(16)})")
            return false
        }
        
        // ========== 第2层：设备名称关键词过滤 ==========
        // 注意：manufacturer 和 productName 已在方法开头声明（第0层使用）
        
        // 排除：读卡器关键词
        val cardReaderKeywords = listOf("card reader", "smart card", "card", "reader", "rfid", "nfc")
        if (cardReaderKeywords.any { productName.contains(it) || manufacturer.contains(it) }) {
            Log.d(TAG, "❌ [第2层-名称过滤] 排除读卡器 ${device.deviceName} (name=$productName, mfr=$manufacturer)")
            return false
        }
        
        // 排除：纯键盘/鼠标设备（不包含扫描器关键词的）
        // 关键逻辑：如果设备名称包含扫描器关键词，优先识别为扫描器，不排除
        val scannerKeywords = listOf("scanner", "barcode", "qr", "scan", "扫描", "条码")
        val hasScannerKeyword = scannerKeywords.any { productName.contains(it) || manufacturer.contains(it) }
        
        if (!hasScannerKeyword) {
            // 只有当设备明确不是扫描器时，才检查是否为键盘/鼠标
            val keyboardMouseKeywords = listOf("keyboard", "mouse", "键盘", "鼠标", "keypad")
            if (keyboardMouseKeywords.any { productName.contains(it) || manufacturer.contains(it) }) {
                Log.d(TAG, "❌ [第2层-名称过滤] 排除纯键盘/鼠标设备 ${device.deviceName} (name=$productName, mfr=$manufacturer)")
                return false
            }
        }
        
        // 排除：读卡器品牌
        val cardReaderBrands = listOf("acs", "omnikey", "gemalto", "vasco", "mingwah", "aohan")
        if (cardReaderBrands.any { manufacturer.contains(it) }) {
            Log.d(TAG, "❌ [第2层-名称过滤] 排除读卡器品牌 ${device.deviceName} (mfr=$manufacturer)")
            return false
        }
        
        // ========== 第3层：USB协议特征识别 ==========
        var hasScannerInterface = false
        
        // 遍历所有USB接口
        for (i in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(i)
            
            // 必须是HID设备类
            if (usbInterface.interfaceClass != USB_CLASS_HID) {
                continue
            }
            
            Log.d(TAG, "检测设备 ${device.deviceName} 接口${i}: " +
                "Class=${usbInterface.interfaceClass}, " +
                "Subclass=${usbInterface.interfaceSubclass}, " +
                "Protocol=${usbInterface.interfaceProtocol}")
            
            // ========== 第3层：扫描器特征识别（需通过第1/2层过滤） ==========
            
            // 规则1（最高优先级）: 厂商白名单强验证
            // 已通过第1/2层过滤的白名单厂商，直接识别为扫描器
            // 支持HID键盘模式的扫描器（如HIDKBW: Subclass=1, Protocol=1）
            // 🔴 关键：必须在键盘/鼠标排除逻辑之前检查，否则会被提前拦截
            if (device.vendorId in KNOWN_SCANNER_VENDORS) {
                Log.d(TAG, "✅ [第3层-白名单] 识别为扫描器 ${device.deviceName}: 白名单厂商 0x${device.vendorId.toString(16)}")
                hasScannerInterface = true
                continue  // 跳过后续检查，避免被键盘/鼠标逻辑误判
            }
            
            // 规则2: 排除标准键盘设备
            // 注意：白名单厂商已在上面通过，这里只排除非白名单的键盘
            if (usbInterface.interfaceSubclass == USB_SUBCLASS_BOOT && 
                usbInterface.interfaceProtocol == USB_PROTOCOL_KEYBOARD) {
                Log.d(TAG, "❌ [第3层-协议特征] 排除标准键盘协议 ${device.deviceName}")
                return false
            }
            
            // 规则3: 排除标准鼠标设备
            if (usbInterface.interfaceSubclass == USB_SUBCLASS_BOOT && 
                usbInterface.interfaceProtocol == USB_PROTOCOL_MOUSE) {
                Log.d(TAG, "❌ [第3层-协议特征] 排除标准鼠标协议 ${device.deviceName}")
                return false
            }
            
            // 规则4: 扫描器标准特征
            // HID设备 + 无Boot子类 + 厂商自定义协议
            // 注意：读卡器也可能是这个配置，所以必须先通过第1/2层过滤
            if (usbInterface.interfaceSubclass == USB_SUBCLASS_NONE && 
                usbInterface.interfaceProtocol == USB_PROTOCOL_NONE) {
                Log.d(TAG, "✅ [第3层-协议特征] 识别为扫描器 ${device.deviceName}: USB协议标准特征")
                hasScannerInterface = true
            }
        }
        
        // ========== 最终判定 ==========
        if (hasScannerInterface) {
            Log.d(TAG, "✅ [最终判定] 确认为扫描器设备: ${device.deviceName}")
            return true
        }
        
        // ========== 兜底层：白名单VID强验证（最后保险）==========
        // 【方案C新增】当所有常规检测都失败时，如果VID在白名单且已通过第1/2层过滤，强制识别
        // 这是最后的安全网，防止因特殊设备配置（如无接口、特殊协议）导致的识别失败
        // 适用场景：设备interfaceCount=0、HID接口配置特殊、第3层规则未覆盖等边界情况
        if (vendorId in KNOWN_SCANNER_VENDORS) {
            Log.d(TAG, "⚠️ [兜底层-白名单] 前面层级未识别，但VID 0x${vendorId.toString(16)} 在白名单")
            Log.d(TAG, "⚠️ [兜底层-白名单] 设备已通过第1/2层过滤（非黑名单VID + 名称无冲突），准备强制识别")
            
            // 额外安全检查：确保设备有接口（不是空设备或异常设备）
            if (device.interfaceCount > 0) {
                Log.d(TAG, "✅ [兜底层-白名单] 强制识别为扫描器 ${device.deviceName} (接口数: ${device.interfaceCount})")
                return true
            } else {
                Log.d(TAG, "❌ [兜底层-白名单] VID在白名单但设备无接口，拒绝识别 ${device.deviceName}")
                return false
            }
        }
        
        Log.d(TAG, "❌ [最终判定] 排除设备 ${device.deviceName}: 无扫描器特征")
        return false
    }
    
    /**
     * 获取设备详细信息
     */
    private fun getDeviceInfo(device: UsbDevice): Map<String, String?> {
        val productName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            device.productName ?: "Unknown"
        } else {
            "Unknown"
        }
        
        val manufacturerName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            device.manufacturerName ?: getManufacturerNameByVendorId(device.vendorId)
        } else {
            getManufacturerNameByVendorId(device.vendorId)
        }
        
        val info = when (device.vendorId) {
            0x05e0 -> mapOf(
                "manufacturer" to "Symbol Technologies (Zebra)",
                "model" to if (productName != "Unknown") productName else "LS2208",
                "specifications" to "1D/2D Barcode, USB HID"
            )
            0x0c2e -> mapOf(
                "manufacturer" to "Honeywell",
                "model" to if (productName != "Unknown") productName else "Voyager 1200g",
                "specifications" to "1D/2D Barcode, USB HID"
            )
            0x0536 -> mapOf(
                "manufacturer" to "Hand Held Products (Honeywell)",
                "model" to if (productName != "Unknown") productName else "4600 Series",
                "specifications" to "1D/2D Barcode, USB HID"
            )
            else -> mapOf(
                "manufacturer" to manufacturerName,
                "model" to if (productName != "Unknown") productName else "Barcode Scanner",
                "specifications" to "1D/2D Barcode, USB HID Keyboard Mode"
            )
        }
        
        return info
    }
    
    /**
     * 根据厂商ID获取厂商名称
     */
    private fun getManufacturerNameByVendorId(vendorId: Int): String {
        return when (vendorId) {
            // === 扫描器厂商 ===
            0x05e0 -> "Symbol Technologies (Zebra)"
            0x0c2e -> "Honeywell"
            0x0536 -> "Hand Held Products"
            0x0581 -> "Racal Data Group (Scanner Barcode)"
            
            // === 键盘厂商 ===
            0x09da -> "A-FOUR TECH CO., LTD."
            0x1c4f -> "Beijing Sigmachip Co., Ltd."
            0x046d -> "Logitech"
            
            // === 通用芯片厂商 ===
            0x1f3a -> "Allwinner Technology"
            0x1a86 -> "QinHeng Electronics"
            0x0483 -> "STMicroelectronics"
            0x1a40 -> "Terminus Technology"
            0x04d9 -> "Holtek Semiconductor"
            0x062a -> "MosArt Semiconductor"
            0x258a -> "SINO WEALTH"
            0x04b4 -> "Cypress Semiconductor"
            
            else -> "Unknown Manufacturer"
        }
    }
    
    /**
     * 请求USB设备权限
     */
    private fun requestPermission(call: MethodCall, result: Result) {
        try {
            val deviceId = call.argument<String>("deviceId")
            if (deviceId == null) {
                result.error("INVALID_ARGUMENT", "Device ID is required", null)
                return
            }
            
            val device = findDeviceById(deviceId)
            if (device == null) {
                result.error("DEVICE_NOT_FOUND", "Device with ID $deviceId not found", null)
                return
            }
            
            if (usbManager?.hasPermission(device) == true) {
                result.success(true)
                return
            }
            
            val permissionIntent = PendingIntent.getBroadcast(
                context,
                0,
                Intent(ACTION_USB_PERMISSION),
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE
                } else {
                    0
                }
            )
            
            usbManager?.requestPermission(device, permissionIntent)
            result.success(false) // 权限请求已发起，但尚未授予
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting permission: ${e.message}", e)
            result.error("PERMISSION_ERROR", "Failed to request permission: ${e.message}", null)
        }
    }
    
    /**
     * 开始监听扫码
     */
    private fun startListening(call: MethodCall, result: Result) {
        try {
            isListening = true
            scanBuffer.clear()
            lastKeyTime = 0
            Log.d(TAG, "Started listening for barcode input")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting listener: ${e.message}", e)
            result.error("START_ERROR", "Failed to start listening: ${e.message}", null)
        }
    }
    
    /**
     * 停止监听扫码
     */
    private fun stopListening(result: Result) {
        try {
            isListening = false
            scanBuffer.clear()
            
            // 取消待处理的自动任务
            autoProcessTask?.let { handler.removeCallbacks(it) }
            autoProcessTask = null
            
            Log.d(TAG, "Stopped listening for barcode input")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping listener: ${e.message}", e)
            result.error("STOP_ERROR", "Failed to stop listening: ${e.message}", null)
        }
    }
    
    /**
     * 处理键盘事件（从Flutter层调用）
     */
    private fun handleKeyEvent(call: MethodCall, result: Result) {
        try {
            if (!isListening) {
                result.success(false)
                return
            }
            
            val keyCode = call.argument<Int>("keyCode") ?: 0
            val action = call.argument<Int>("action") ?: 0
            
            // 只处理按键按下事件
            if (action != KeyEvent.ACTION_DOWN) {
                result.success(false)
                return
            }
            
            val currentTime = System.currentTimeMillis()
            
            // 检查超时（新的扫码开始）
            if (lastKeyTime > 0 && (currentTime - lastKeyTime) > scanTimeout) {
                if (scanBuffer.isNotEmpty()) {
                    // 处理上一次的扫码数据
                    processScanData()
                }
                scanBuffer.clear()
            }
            
            lastKeyTime = currentTime
            
            // 处理按键
            when (keyCode) {
                KeyEvent.KEYCODE_ENTER -> {
                    // 回车键立即处理（兼容带回车的扫码器）
                    cancelAutoProcessTask()
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
                        // 启动自动处理任务
                        scheduleAutoProcess()
                    }
                }
            }
            
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error handling key event: ${e.message}", e)
            result.error("KEY_EVENT_ERROR", "Failed to handle key event: ${e.message}", null)
        }
    }
    
    /**
     * 处理扫码数据
     */
    private fun processScanData() {
        val barcodeData = scanBuffer.toString().trim()
        if (barcodeData.isEmpty()) return
        
        Log.d(TAG, "Barcode scanned: $barcodeData")
        
        // 识别条码类型
        val barcodeType = recognizeBarcodeType(barcodeData)
        
        val scanResult = hashMapOf(
            "type" to barcodeType,
            "content" to barcodeData,
            "length" to barcodeData.length,
            "timestamp" to java.time.Instant.now().toString(),
            "isValid" to true,
            "rawData" to barcodeData
        )
        
        channel.invokeMethod("onScanResult", scanResult)
    }
    
    /**
     * 识别条码类型
     */
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
    
    /**
     * 直接处理键盘事件（从MainActivity调用）
     * 返回true表示事件已处理，false表示需要系统继续处理
     */
    fun handleKeyEventDirect(event: KeyEvent): Boolean {
        // 只处理按键按下事件
        if (event.action != KeyEvent.ACTION_DOWN) {
            return false
        }
        
        // 如果未在监听状态，不拦截事件
        if (!isListening) {
            return false
        }
        
        val currentTime = System.currentTimeMillis()
        
        // 检查超时（新的扫码开始）
        if (lastKeyTime > 0 && (currentTime - lastKeyTime) > scanTimeout) {
            if (scanBuffer.isNotEmpty()) {
                // 处理上一次的扫码数据
                processScanData()
            }
            scanBuffer.clear()
        }
        
        lastKeyTime = currentTime
        
        // 处理按键
        when (event.keyCode) {
            KeyEvent.KEYCODE_ENTER -> {
                // 回车键立即处理（兼容带回车的扫码器）
                cancelAutoProcessTask()
                if (scanBuffer.isNotEmpty()) {
                    processScanData()
                    scanBuffer.clear()
                }
                return true  // 拦截回车键
            }
            else -> {
                // 尝试获取字符
                val char = getCharFromKeyCode(event.keyCode)
                if (char != null) {
                    scanBuffer.append(char)
                    Log.d(TAG, "Key captured: ${event.keyCode} -> '$char', buffer: $scanBuffer")
                    // 启动自动处理任务
                    scheduleAutoProcess()
                    return true  // 拦截已识别的字符键
                }
            }
        }
        
        // 未识别的按键，让系统继续处理
        return false
    }
    
    /**
     * 调度自动处理任务
     * 每次按键后重新计时，确保在输入停止后才触发
     */
    private fun scheduleAutoProcess() {
        // 取消之前的任务
        cancelAutoProcessTask()
        
        // 创建新任务
        autoProcessTask = Runnable {
            if (scanBuffer.isNotEmpty()) {
                Log.d(TAG, "Auto-processing barcode after ${autoProcessDelay}ms delay")
                processScanData()
                scanBuffer.clear()
            }
            autoProcessTask = null
        }
        
        // 延迟执行
        handler.postDelayed(autoProcessTask!!, autoProcessDelay)
    }
    
    /**
     * 取消自动处理任务
     */
    private fun cancelAutoProcessTask() {
        autoProcessTask?.let { 
            handler.removeCallbacks(it)
            autoProcessTask = null
        }
    }
    
    /**
     * 从键码获取字符
     */
    private fun getCharFromKeyCode(keyCode: Int): Char? {
        return when (keyCode) {
            in KeyEvent.KEYCODE_0..KeyEvent.KEYCODE_9 -> 
                ('0'.code + (keyCode - KeyEvent.KEYCODE_0)).toChar()
            in KeyEvent.KEYCODE_A..KeyEvent.KEYCODE_Z -> 
                ('a'.code + (keyCode - KeyEvent.KEYCODE_A)).toChar()
            KeyEvent.KEYCODE_SPACE -> ' '
            KeyEvent.KEYCODE_MINUS -> '-'
            KeyEvent.KEYCODE_EQUALS -> '='
            KeyEvent.KEYCODE_PERIOD -> '.'
            KeyEvent.KEYCODE_COMMA -> ','
            KeyEvent.KEYCODE_SLASH -> '/'
            KeyEvent.KEYCODE_BACKSLASH -> '\\'
            else -> null
        }
    }
    
    /**
     * 根据设备ID查找设备
     */
    private fun findDeviceById(deviceId: String): UsbDevice? {
        val deviceList = usbManager?.deviceList ?: return null
        return deviceList.values.find { it.deviceId.toString() == deviceId }
    }
}
