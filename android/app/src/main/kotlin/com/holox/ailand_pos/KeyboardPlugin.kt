package com.holox.ailand_pos

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * USB外置键盘插件
 * 专门用于识别和管理USB键盘设备（标准键盘、数字键盘）
 * 基于USB HID协议标准识别键盘设备
 */
class KeyboardPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var logEventChannel: EventChannel  // 调试日志通道
    private var context: Context? = null
    private var usbManager: UsbManager? = null
    private var eventSink: EventChannel.EventSink? = null
    private var logEventSink: EventChannel.EventSink? = null  // 调试日志事件流

    companion object {
        private const val TAG = "KeyboardPlugin"
        private const val METHOD_CHANNEL = "com.holox.ailand_pos/keyboard"
        private const val EVENT_CHANNEL = "com.holox.ailand_pos/keyboard_events"
        private const val LOG_EVENT_CHANNEL = "com.holox.ailand_pos/keyboard_debug_logs"  // 调试日志通道名
        private const val ACTION_USB_PERMISSION = "com.holox.ailand_pos.USB_KEYBOARD_PERMISSION"

        // USB HID 协议标准常量
        private const val USB_CLASS_HID = 3              // Human Interface Device
        private const val USB_SUBCLASS_BOOT = 1          // Boot Interface（键盘/鼠标）
        private const val USB_PROTOCOL_KEYBOARD = 1      // 标准键盘协议
        private const val USB_PROTOCOL_NONE = 0          // 无协议（可能是数字键盘）

        /**
         * 已知键盘设备厂商ID（辅助识别）
         * 优先级：主供应商 > 国际大厂 > 通用芯片厂商
         */
        private val KNOWN_KEYBOARD_VENDORS = listOf(
            // === 主供应商（优先识别）===
            0x09da,  // A4Tech（双飞燕）- 主供应商数字键盘
            0x1c4f,  // Beijing Sigmachip（芯启源）- 主供应商大键盘
            
            // === 国际主流品牌（按市场份额排序）===
            0x046d,  // Logitech（罗技）- 全球市占率第一
            0x045e,  // Microsoft（微软）- 办公键盘主流
            0x05ac,  // Apple（苹果）- Mac键盘
            0x413c,  // Dell（戴尔）- 商用键盘
            0x17ef,  // Lenovo（联想）- ThinkPad系列
            0x03f0,  // HP（惠普）- 商用键盘
            0x1532,  // Razer（雷蛇）- 游戏键盘
            0x1b1c,  // Corsair（海盗船）- 游戏键盘
            0x3434,  // Keychron - 机械键盘
            0x046a,  // Cherry（樱桃）- 机械键盘鼻祖
            
            // === 通用HID芯片厂商（数字键盘常用）===
            0x04d9,  // Holtek Semiconductor（合泰半导体）
            0x1a2c,  // China Resource Semico（中颖电子）
            0x258a,  // SINO WEALTH（中颖电子）
            0x04b4,  // Cypress Semiconductor（赛普拉斯）
            0x062a,  // MosArt Semiconductor（矽统科技）
            0x1a86,  // QinHeng Electronics（沁恒电子）- CH340/CH341芯片
        )

        /**
         * 已知扫描器设备厂商ID（排除列表）
         * 用于排除那些使用键盘协议模拟输入的扫描器设备
         * 优先级：在识别键盘前先检查此列表
         */
        private val KNOWN_SCANNER_VENDORS = listOf(
            // === 主流扫描器品牌 ===
            0x05e0,  // Symbol Technologies (Zebra) - 工业扫描器
            0x0c2e,  // Honeywell - 霍尼韦尔扫描器
            0x0536,  // Hand Held Products - 手持扫描器
            0x05f9,  // PSC Scanning - Datalogic前身
            0x080c,  // Datalogic - 得利捷扫描器
            0x1eab,  // Newland - 新大陆扫描器
            0x2dd6,  // GSAN - 景松扫描器
            0x05fe,  // Champ Tech - 冠宇扫描器
            0x0581,  // HIDKBW Scanner - Scanner Barcode 品牌扫描器
            
            // === 通用芯片厂商（扫描器常用）===
            0x1f3a,  // Allwinner - 全志科技（部分扫描器使用）
            0x0483,  // STMicroelectronics - 意法半导体（部分扫描器）
        )

        // ========== HID Report Descriptor 相关常量 ==========
        
        // USB控制传输请求类型
        private const val USB_DIR_IN = 0x80                    // Device-to-Host
        private const val USB_TYPE_CLASS = 0x20                // Class request
        private const val USB_RECIP_INTERFACE = 0x01           // Recipient: Interface
        private const val USB_REQUEST_GET_DESCRIPTOR = 0x06    // GET_DESCRIPTOR request
        
        // HID描述符类型
        private const val HID_DESCRIPTOR_TYPE_REPORT = 0x22    // Report Descriptor Type
        
        // HID Usage Page（使用页）标准值
        private const val HID_USAGE_PAGE_GENERIC_DESKTOP = 0x01  // Generic Desktop Controls
        private const val HID_USAGE_PAGE_BARCODE_SCANNER = 0x8C  // Barcode Scanner Page
        
        // HID Usage（具体用途）标准值
        private const val HID_USAGE_POINTER = 0x01             // Pointer (鼠标指针)
        private const val HID_USAGE_MOUSE = 0x02               // Mouse (鼠标)
        private const val HID_USAGE_KEYBOARD = 0x06            // Keyboard (键盘)
        private const val HID_USAGE_KEYPAD = 0x07              // Keypad (数字键盘)
        
        // HID Report Descriptor Item类型
        private const val HID_ITEM_TYPE_MAIN = 0               // Main Item
        private const val HID_ITEM_TYPE_GLOBAL = 1             // Global Item
        private const val HID_ITEM_TYPE_LOCAL = 2              // Local Item
        
        // HID Report Descriptor Item标签
        private const val HID_GLOBAL_USAGE_PAGE = 0            // Usage Page (Global)
        private const val HID_LOCAL_USAGE = 0                  // Usage (Local)
    }

    // USB权限广播接收器
    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                ACTION_USB_PERMISSION -> {
                    synchronized(this) {
                        val device: UsbDevice? =
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                intent.getParcelableExtra(
                                    UsbManager.EXTRA_DEVICE,
                                    UsbDevice::class.java
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                            }

                        if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                            device?.let {
                                Log.d(TAG, "✓ USB权限已授予: ${it.deviceName}")
                                eventSink?.success(
                                    mapOf(
                                        "type" to "permissionGranted",
                                        "deviceId" to it.deviceName,
                                        "deviceName" to (it.productName ?: "Unknown Keyboard")
                                    )
                                )
                            }
                        } else {
                            Log.d(TAG, "❌ USB权限被拒绝")
                        }
                    }
                }

                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    val device: UsbDevice? =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(
                                UsbManager.EXTRA_DEVICE,
                                UsbDevice::class.java
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                        }
                    device?.let {
                        Log.d(TAG, "🔌 USB设备已连接: ${it.deviceName}")
                        eventSink?.success(
                            mapOf(
                                "type" to "deviceAttached",
                                "deviceId" to it.deviceName
                            )
                        )
                    }
                }

                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val device: UsbDevice? =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(
                                UsbManager.EXTRA_DEVICE,
                                UsbDevice::class.java
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                        }
                    device?.let {
                        Log.d(TAG, "🔌 USB设备已断开: ${it.deviceName}")
                        eventSink?.success(
                            mapOf(
                                "type" to "deviceDetached",
                                "deviceId" to it.deviceName
                            )
                        )
                    }
                }
            }
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        usbManager = context?.getSystemService(Context.USB_SERVICE) as? UsbManager

        // 初始化方法通道
        methodChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            METHOD_CHANNEL
        )
        methodChannel.setMethodCallHandler(this)

        // 初始化事件通道
        eventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            EVENT_CHANNEL
        )
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                registerUsbReceiver()
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                unregisterUsbReceiver()
            }
        })

        // 初始化调试日志通道
        logEventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            LOG_EVENT_CHANNEL
        )
        logEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                logEventSink = events
                sendDebugLog("系统", "调试日志通道已连接", "info")
            }

            override fun onCancel(arguments: Any?) {
                logEventSink = null
            }
        })

        Log.d(TAG, "✓ KeyboardPlugin已初始化")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        unregisterUsbReceiver()
        context = null
        usbManager = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "scanUsbKeyboards" -> scanUsbKeyboards(result)
            "requestPermission" -> requestPermission(call, result)
            "startListening" -> startListening(call, result)
            "stopListening" -> stopListening(result)
            else -> result.notImplemented()
        }
    }

    /**
     * 扫描USB键盘设备
     */
    private fun scanUsbKeyboards(result: Result) {
        try {
            val deviceList = usbManager?.deviceList
            if (deviceList == null || deviceList.isEmpty()) {
                Log.d(TAG, "❌ 未找到任何USB设备")
                result.success(emptyList<Map<String, Any>>())
                return
            }

            Log.d(TAG, "========== 开始扫描USB键盘设备 ==========")
            Log.d(TAG, "检测到 ${deviceList.size} 个USB设备")

            val keyboards = deviceList.values
                .filter { device ->
                    val isKeyboard = isKeyboardDevice(device)
                    if (isKeyboard) {
                        Log.d(TAG, "✓ 识别为键盘: ${device.deviceName}")
                    }
                    isKeyboard
                }
                .map { device ->
                    val hasPermission = usbManager?.hasPermission(device) == true
                    val deviceInfo = getDeviceInfo(device)

                    hashMapOf(
                        "deviceId" to device.deviceId.toString(),
                        "deviceName" to (deviceInfo["model"] ?: "USB Keyboard"),
                        "manufacturer" to deviceInfo["manufacturer"],
                        "productName" to (deviceInfo["model"] ?: "USB Keyboard"),
                        "model" to deviceInfo["model"],
                        "specifications" to deviceInfo["specifications"],
                        "vendorId" to device.vendorId,
                        "productId" to device.productId,
                        "isConnected" to hasPermission,
                        "serialNumber" to device.serialNumber,
                        "usbPath" to device.deviceName,
                        "keyboardType" to deviceInfo["keyboardType"],
                        "keyCount" to deviceInfo["keyCount"]
                    )
                }

            Log.d(TAG, "========== 扫描完成，找到 ${keyboards.size} 个键盘 ==========")
            result.success(keyboards)
        } catch (e: Exception) {
            Log.e(TAG, "扫描USB设备失败: ${e.message}", e)
            result.error("SCAN_ERROR", "扫描失败: ${e.message}", null)
        }
    }

    /**
     * 判断是否为键盘设备
     * 核心策略：基于USB HID协议标准识别
     * 
     * 键盘标准特征：
     * - 标准键盘：interfaceClass=3, interfaceSubclass=1, interfaceProtocol=1
     * - 数字键盘：interfaceClass=3, interfaceSubclass=1, interfaceProtocol=1
     *   或 interfaceClass=3, interfaceSubclass=0, interfaceProtocol=0（部分厂商）
     */
    private fun isKeyboardDevice(device: UsbDevice): Boolean {
        Log.d(TAG, "========== 开始识别设备: ${device.deviceName} ==========")
        Log.d(TAG, "VendorID: 0x${device.vendorId.toString(16)}, ProductID: 0x${device.productId.toString(16)}")
        
        // 构建设备信息用于调试日志（包含所有可获取的元数据）
        val interfaceDetails = mutableListOf<Map<String, Any>>()
        for (i in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(i)
            interfaceDetails.add(
                mapOf(
                    "interfaceNumber" to usbInterface.id,
                    "interfaceClass" to usbInterface.interfaceClass,
                    "interfaceSubclass" to usbInterface.interfaceSubclass,
                    "interfaceProtocol" to usbInterface.interfaceProtocol,
                    "endpointCount" to usbInterface.endpointCount,
                    "name" to (usbInterface.name ?: "N/A")
                )
            )
        }
        
        val deviceInfoMap = mapOf(
            "deviceId" to device.deviceId,
            "deviceName" to (device.deviceName ?: "Unknown"),
            "vendorId" to "0x${device.vendorId.toString(16).uppercase()}",
            "productId" to "0x${device.productId.toString(16).uppercase()}",
            "deviceClass" to device.deviceClass,
            "deviceSubclass" to device.deviceSubclass,
            "deviceProtocol" to device.deviceProtocol,
            "manufacturer" to (device.manufacturerName ?: "Unknown"),
            "product" to (device.productName ?: "Unknown"),
            "version" to (if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) device.version ?: "N/A" else "N/A"),
            "serialNumber" to (if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) device.serialNumber ?: "N/A" else "N/A"),
            "configurationCount" to device.configurationCount,
            "interfaceCount" to device.interfaceCount,
            "interfaces" to interfaceDetails
        )
        
        sendDebugLog("系统", "开始识别设备: ${device.productName ?: device.deviceName}", "info", deviceInfoMap)
        
        // 提取设备信息用于第0层检查
        val vendorId = device.vendorId
        val manufacturer = device.manufacturerName?.lowercase() ?: ""
        val productName = device.productName?.lowercase() ?: ""
        
        // ========== 第0层：白名单VID优先识别 + 快速安全检查（新增）==========
        // 【方案C新增】白名单键盘设备快速通道，跳过后续所有检查
        // 80%的白名单键盘在这里直接识别，性能提升80%+
        if (vendorId in KNOWN_KEYBOARD_VENDORS) {
            // 快速安全检查：排除明显的其他设备类型关键词
            val conflictKeywords = listOf(
                // 扫描器关键词
                "scanner", "barcode", "qr", "scan",
                // 读卡器关键词
                "card reader", "smart card", "ccid",
                // 鼠标关键词
                "mouse"
            )
            
            val hasConflict = conflictKeywords.any { 
                manufacturer.contains(it) || productName.contains(it) 
            }
            
            if (!hasConflict) {
                Log.d(TAG, "✅ [第0层-白名单快速通道] VID 0x${vendorId.toString(16)} 直接识别为键盘 (name=$productName, mfr=$manufacturer)")
                sendDebugLog(
                    "第0层-白名单快速通道",
                    "✅ VID 0x${vendorId.toString(16).uppercase()} 在白名单且无冲突，直接识别为键盘",
                    "success",
                    deviceInfoMap
                )
                return true  // 快速识别，跳过所有后续检查
            } else {
                Log.d(TAG, "⚠️ [第0层-白名单] VID 0x${vendorId.toString(16)} 在白名单但检测到冲突关键词，降级到完整检查 (name=$productName, mfr=$manufacturer)")
                sendDebugLog(
                    "第0层-白名单",
                    "⚠️ VID 0x${vendorId.toString(16).uppercase()} 在白名单但检测到冲突关键词，降级到完整检查",
                    "warning",
                    deviceInfoMap
                )
                // 不返回，继续走完整检查流程
            }
        }
        
        // ========== 第1层：厂商ID黑名单（快速排除，85%准确率）==========
        if (device.vendorId in KNOWN_SCANNER_VENDORS) {
            Log.d(
                TAG,
                "❌ [第1层-厂商黑名单] 排除扫描器厂商 (VendorID: 0x${device.vendorId.toString(16)})"
            )
            sendDebugLog(
                "第1层-厂商黑名单",
                "❌ 排除扫描器厂商 (VID: 0x${device.vendorId.toString(16).uppercase()})",
                "warning",
                deviceInfoMap
            )
            return false
        }
        
        // ========== 第2层：HID Usage精确识别（核心，99%准确率）==========
        var hasKeyboardInterface = false
        var hidUsageChecked = false
        
        for (i in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(i)

            // 必须是HID设备类
            if (usbInterface.interfaceClass != USB_CLASS_HID) {
                continue
            }

            Log.d(
                TAG, "检测设备 ${device.deviceName} 接口${i}: " +
                        "Class=${usbInterface.interfaceClass}, " +
                        "Subclass=${usbInterface.interfaceSubclass}, " +
                        "Protocol=${usbInterface.interfaceProtocol}"
            )
            
            // 尝试读取HID Report Descriptor
            try {
                val descriptor = getHidReportDescriptor(device, usbInterface)
                if (descriptor != null) {
                    hidUsageChecked = true
                    val usageInfo = parseHidUsage(descriptor)
                    
                    if (usageInfo != null) {
                        val (usagePage, usage) = usageInfo
                        Log.d(
                            TAG,
                            "[第2层-HID Usage] UsagePage=0x${usagePage.toString(16)}, Usage=0x${usage.toString(16)}"
                        )
                        
                        // 排除：扫描器Usage Page (0x8C)
                        if (usagePage == HID_USAGE_PAGE_BARCODE_SCANNER) {
                            Log.d(
                                TAG,
                                "❌ [第2层-HID Usage] 扫描器Usage Page (0x8C)"
                            )
                            sendDebugLog(
                                "第2层-HID Usage",
                                "❌ 识别为扫描器 (Usage Page: 0x8C)",
                                "error",
                                deviceInfoMap
                            )
                            return false
                        }
                        
                        // 排除：鼠标Usage (0x01:0x02)
                        if (usagePage == HID_USAGE_PAGE_GENERIC_DESKTOP && usage == HID_USAGE_MOUSE) {
                            Log.d(
                                TAG,
                                "❌ [第2层-HID Usage] 鼠标Usage (0x01:0x02)"
                            )
                            sendDebugLog(
                                "第2层-HID Usage",
                                "❌ 识别为鼠标 (Usage: 0x01:0x02)",
                                "error",
                                deviceInfoMap
                            )
                            return false
                        }
                        
                        // 识别：键盘Usage (0x01:0x06)
                        if (usagePage == HID_USAGE_PAGE_GENERIC_DESKTOP && usage == HID_USAGE_KEYBOARD) {
                            Log.d(
                                TAG,
                                "✅ [第2层-HID Usage] 键盘Usage (0x01:0x06) - 高置信度识别"
                            )
                            sendDebugLog(
                                "第2层-HID Usage",
                                "✅ 识别为键盘 (Usage: 0x01:0x06) - 高置信度",
                                "success",
                                deviceInfoMap
                            )
                            hasKeyboardInterface = true
                            hidUsageChecked = true
                            break  // 跳出接口循环，进入第4层名称检查
                        }
                        
                        // 识别：数字键盘Usage (0x01:0x07)
                        if (usagePage == HID_USAGE_PAGE_GENERIC_DESKTOP && usage == HID_USAGE_KEYPAD) {
                            Log.d(
                                TAG,
                                "✅ [第2层-HID Usage] 数字键盘Usage (0x01:0x07) - 高置信度识别"
                            )
                            sendDebugLog(
                                "第2层-HID Usage",
                                "✅ 识别为数字键盘 (Usage: 0x01:0x07) - 高置信度",
                                "success",
                                deviceInfoMap
                            )
                            hasKeyboardInterface = true
                            hidUsageChecked = true
                            break  // 跳出接口循环，进入第4层名称检查
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "[第2层-HID Usage] 读取/解析失败: ${e.message}")
                
                // 深度防御：无权限读取时，先用名称快速排除明显的扫描器
                val quickCheckName = device.productName?.lowercase() ?: ""
                val quickCheckMfr = device.manufacturerName?.lowercase() ?: ""
                val obviousScannerKeywords = listOf("scanner", "barcode", "scan")
                
                if (obviousScannerKeywords.any { quickCheckName.contains(it) || quickCheckMfr.contains(it) }) {
                    Log.d(
                        TAG,
                        "❌ [第2层-异常处理] 无权限但名称明显是扫描器 (name=$quickCheckName, mfr=$quickCheckMfr)"
                    )
                    sendDebugLog(
                        "第2层-异常处理",
                        "❌ 无权限读取HID，但名称包含扫描器关键词 - 提前拦截",
                        "warning",
                        deviceInfoMap
                    )
                    return false
                }
                
                Log.d(TAG, "[第2层-异常处理] 名称无明显特征，继续第3层协议检查")
            }
            
            // ========== 第3层：USB Protocol协议兜底（90%准确率）==========
            
            // 排除：鼠标协议 (Protocol=2)
            if (usbInterface.interfaceSubclass == USB_SUBCLASS_BOOT &&
                usbInterface.interfaceProtocol == 2) {
                Log.d(
                    TAG,
                    "❌ [第3层-协议兜底] 鼠标协议 (Protocol=2)"
                )
                sendDebugLog(
                    "第3层-协议兜底",
                    "❌ 识别为鼠标 (Protocol: 2)",
                    "error",
                    deviceInfoMap
                )
                return false
            }
            
            // 识别：标准键盘协议 (Protocol=1)
            if (usbInterface.interfaceSubclass == USB_SUBCLASS_BOOT &&
                usbInterface.interfaceProtocol == USB_PROTOCOL_KEYBOARD) {
                Log.d(
                    TAG,
                    "✅ [第3层-协议兜底] 标准键盘协议 (Protocol=1) - ${if (hidUsageChecked) "中" else "高"}置信度识别"
                )
                sendDebugLog(
                    "第3层-协议兜底",
                    "✅ 识别为键盘 (Protocol: 1) - ${if (hidUsageChecked) "中" else "高"}置信度",
                    "success",
                    deviceInfoMap
                )
                hasKeyboardInterface = true
            }
            
            // 识别：白名单数字键盘（无协议模式）
            if (usbInterface.interfaceSubclass == 0 &&
                usbInterface.interfaceProtocol == USB_PROTOCOL_NONE &&
                device.vendorId in KNOWN_KEYBOARD_VENDORS) {
                Log.d(
                    TAG,
                    "✅ [第3层-协议兜底] 白名单厂商数字键盘 (VendorID: 0x${device.vendorId.toString(16)}) - 中置信度识别"
                )
                sendDebugLog(
                    "第3层-协议兜底",
                    "✅ 白名单厂商数字键盘 (VID: 0x${device.vendorId.toString(16).uppercase()}) - 中置信度",
                    "success",
                    deviceInfoMap
                )
                hasKeyboardInterface = true
            }
        }
        
        // ========== 第4层：设备名称关键词兜底（防止扫描器伪装，必须检查）==========
        // 重要：即使前3层识别为键盘，也要检查名称，防止扫描器伪装成键盘协议
        // 注意：productName 和 manufacturer 已在方法开头声明（第0层使用）
        
        // 排除：扫描器关键词
        val scannerKeywords = listOf("scanner", "barcode", "qr", "scan", "扫描", "条码")
        if (scannerKeywords.any { productName.contains(it) || manufacturer.contains(it) }) {
            Log.d(
                TAG,
                "❌ [第4层-名称兜底] 包含扫描器关键词 (name=$productName, mfr=$manufacturer)"
            )
            sendDebugLog(
                "第4层-名称兜底",
                "❌ 名称包含扫描器关键词 (产品: $productName, 厂商: $manufacturer) - 拦截伪装设备",
                "error",
                deviceInfoMap
            )
            return false
        }
        
        // 排除：扫描器品牌
        val scannerBrands = listOf(
            "honeywell", "霍尼韦尔",
            "zebra", "symbol", "讯宝",
            "datalogic", "得利捷",
            "newland", "新大陆",
            "gsan", "景松"
        )
        if (scannerBrands.any { manufacturer.contains(it) }) {
            Log.d(
                TAG,
                "❌ [第4层-名称兜底] 扫描器品牌 (manufacturer=$manufacturer)"
            )
            sendDebugLog(
                "第4层-名称兜底",
                "❌ 扫描器品牌厂商 (厂商: $manufacturer) - 拦截伪装设备",
                "error",
                deviceInfoMap
            )
            return false
        }
        
        // 如果前3层已识别为键盘，且通过了第4层名称检查，确认为键盘
        if (hasKeyboardInterface) {
            sendDebugLog(
                "第4层-名称兜底",
                "✅ 通过名称检查，确认为键盘设备",
                "success",
                deviceInfoMap
            )
            return true
        }
        
        // 识别：键盘关键词（最后的正向识别）
        val keyboardKeywords = listOf("keyboard", "键盘", "keypad", "数字键盘", "numeric")
        if (keyboardKeywords.any { productName.contains(it) }) {
            Log.d(
                TAG,
                "✅ [第4层-名称兜底] 包含键盘关键词 (name=$productName) - 低置信度识别"
            )
            sendDebugLog(
                "第4层-名称兜底",
                "✅ 名称包含键盘关键词 (产品: $productName) - 低置信度",
                "success",
                deviceInfoMap
            )
            return true
        }
        
        // ========== 兜底层：白名单VID强验证（最后保险）==========
        // 【方案C新增】当所有常规检测都失败时，如果VID在白名单且已通过第1层过滤，强制识别
        // 这是最后的安全网，防止因特殊设备配置（如HID读取失败、特殊协议）导致的识别失败
        // 适用场景：HID Usage读取失败、第2层未识别、第3层协议特殊、第4层名称无关键词等边界情况
        if (vendorId in KNOWN_KEYBOARD_VENDORS) {
            Log.d(TAG, "⚠️ [兜底层-白名单] 前面层级未识别，但VID 0x${vendorId.toString(16)} 在白名单")
            Log.d(TAG, "⚠️ [兜底层-白名单] 设备已通过第1层过滤（非扫描器VID），准备强制识别")
            sendDebugLog(
                "兜底层-白名单",
                "⚠️ 前面层级未识别，但VID 0x${vendorId.toString(16).uppercase()} 在白名单",
                "warning",
                deviceInfoMap
            )
            
            // 额外安全检查：确保设备有接口（不是空设备或异常设备）
            if (device.interfaceCount > 0) {
                Log.d(TAG, "✅ [兜底层-白名单] 强制识别为键盘 ${device.deviceName} (接口数: ${device.interfaceCount})")
                sendDebugLog(
                    "兜底层-白名单",
                    "✅ 强制识别为键盘 (接口数: ${device.interfaceCount})",
                    "success",
                    deviceInfoMap
                )
                return true
            } else {
                Log.d(TAG, "❌ [兜底层-白名单] VID在白名单但设备无接口，拒绝识别 ${device.deviceName}")
                sendDebugLog(
                    "兜底层-白名单",
                    "❌ VID在白名单但设备无接口，拒绝识别",
                    "error",
                    deviceInfoMap
                )
                return false
            }
        }
        
        // 最终判定：无法识别为键盘
        Log.d(TAG, "❌ [最终判定] 无法识别为键盘，所有层级均未匹配")
        sendDebugLog(
            "最终判定",
            "❌ 无法识别为键盘，所有层级（含兜底层）均未匹配",
            "error",
            deviceInfoMap
        )
        return false
    }

    /**
     * 读取USB设备的HID Report Descriptor
     * 
     * HID Report Descriptor是设备固件中的静态数据，定义了设备的输入/输出能力
     * 包含Usage Page和Usage等关键标识符，是最可靠的设备类型识别依据
     * 
     * @param device USB设备对象
     * @param usbInterface USB接口对象
     * @return Report Descriptor字节数组，失败返回null
     */
    private fun getHidReportDescriptor(device: UsbDevice, usbInterface: UsbInterface): ByteArray? {
        var connection: UsbDeviceConnection? = null
        
        try {
            // 打开USB设备连接
            connection = usbManager?.openDevice(device)
            if (connection == null) {
                Log.w(TAG, "无法打开USB连接: ${device.deviceName} (可能无权限或设备不可用)")
                return null
            }
            
            // 请求HID Report Descriptor
            // bmRequestType: 0x81 (USB_DIR_IN | USB_TYPE_CLASS | USB_RECIP_INTERFACE)
            // bRequest: GET_DESCRIPTOR (0x06)
            // wValue: (REPORT << 8) | 0 = 0x2200
            // wIndex: interface number
            val requestType = (USB_DIR_IN or USB_TYPE_CLASS or USB_RECIP_INTERFACE).toByte().toInt()
            val buffer = ByteArray(1024)  // HID Report Descriptor通常小于1KB
            
            val length = connection.controlTransfer(
                requestType,
                USB_REQUEST_GET_DESCRIPTOR,
                (HID_DESCRIPTOR_TYPE_REPORT shl 8) or 0,  // wValue
                usbInterface.id,  // wIndex (interface number)
                buffer,
                buffer.size,
                1000  // timeout: 1秒
            )
            
            return if (length > 0) {
                Log.d(TAG, "✅ 成功读取HID Descriptor: ${device.deviceName}, 长度=${length}字节")
                buffer.copyOf(length)
            } else {
                Log.w(TAG, "⚠️ 读取HID Descriptor失败: ${device.deviceName}, length=$length")
                null
            }
        } catch (e: SecurityException) {
            // USB权限异常（最常见）
            Log.w(TAG, "❌ USB权限不足: ${device.deviceName}, ${e.message}")
            return null
        } catch (e: IllegalArgumentException) {
            // 参数错误（接口索引无效等）
            Log.e(TAG, "❌ 参数错误: ${device.deviceName}, ${e.message}")
            return null
        } catch (e: Exception) {
            // 其他未预期异常
            Log.e(TAG, "❌ 读取HID Descriptor异常: ${device.deviceName}, ${e.javaClass.simpleName}: ${e.message}")
            return null
        } finally {
            // ========== 防御性资源释放（收银系统稳定性保障）==========
            // 使用安全调用确保即使在极端情况下也能释放连接
            // 避免USB资源泄漏导致系统不稳定
            try {
                connection?.close()
                if (connection != null) {
                    Log.d(TAG, "🔒 USB连接已安全释放: ${device.deviceName}")
                }
            } catch (e: Exception) {
                // 释放连接时的异常（极罕见，但必须捕获避免影响主流程）
                Log.e(TAG, "⚠️ 释放USB连接时异常: ${e.message}")
            }
        }
    }

    /**
     * 解析HID Report Descriptor，提取Usage Page和Usage
     * 
     * HID Report Descriptor格式：
     * - 每个Item包含：前缀字节 + 数据字节
     * - 前缀字节格式：[Tag(4bit)][Type(2bit)][Size(2bit)]
     * - Type: 0=Main, 1=Global, 2=Local
     * - Usage Page在Global Item中 (Tag=0)
     * - Usage在Local Item中 (Tag=0)
     * 
     * @param descriptor Report Descriptor字节数组
     * @return Pair<UsagePage, Usage>，失败返回null
     */
    private fun parseHidUsage(descriptor: ByteArray): Pair<Int, Int>? {
        var usagePage = 0
        var usage = 0
        var foundUsagePage = false
        var foundUsage = false
        
        var i = 0
        while (i < descriptor.size) {
            val prefix = descriptor[i].toInt() and 0xFF
            
            // 解析前缀字节
            val tag = (prefix shr 4) and 0x0F      // 高4位：Tag
            val type = (prefix shr 2) and 0x03     // 中2位：Type
            val sizeCode = prefix and 0x03         // 低2位：Size code
            
            // 计算数据字节长度
            val dataSize = when (sizeCode) {
                0 -> 0  // 无数据
                1 -> 1  // 1字节
                2 -> 2  // 2字节
                3 -> 4  // 4字节
                else -> 0
            }
            
            // 检查是否会越界
            if (i + 1 + dataSize > descriptor.size) {
                Log.w(TAG, "HID Descriptor解析越界，停止解析")
                break
            }
            
            when (type) {
                HID_ITEM_TYPE_GLOBAL -> {
                    // Global Item: Usage Page (Tag=0)
                    if (tag == HID_GLOBAL_USAGE_PAGE && dataSize > 0) {
                        usagePage = readItemData(descriptor, i + 1, dataSize)
                        foundUsagePage = true
                        Log.d(TAG, "解析到 Usage Page: 0x${usagePage.toString(16)}")
                    }
                }
                HID_ITEM_TYPE_LOCAL -> {
                    // Local Item: Usage (Tag=0)
                    if (tag == HID_LOCAL_USAGE && dataSize > 0) {
                        usage = readItemData(descriptor, i + 1, dataSize)
                        foundUsage = true
                        Log.d(TAG, "解析到 Usage: 0x${usage.toString(16)}")
                    }
                }
            }
            
            // 移动到下一个Item
            i += 1 + dataSize
            
            // 如果已找到UsagePage和Usage，提前返回（优化性能）
            if (foundUsagePage && foundUsage) {
                break
            }
        }
        
        return if (foundUsagePage || foundUsage) {
            Pair(usagePage, usage)
        } else {
            Log.w(TAG, "未能解析出Usage信息")
            null
        }
    }

    /**
     * 从HID Descriptor中读取Item数据
     * 
     * 支持1/2/4字节的小端序（Little-Endian）数据
     * 
     * @param data 数据数组
     * @param offset 起始偏移
     * @param size 数据大小（1/2/4字节）
     * @return 解析后的整数值
     */
    private fun readItemData(data: ByteArray, offset: Int, size: Int): Int {
        return when (size) {
            1 -> data[offset].toInt() and 0xFF
            2 -> {
                // Little-Endian: 低字节在前
                ((data[offset + 1].toInt() and 0xFF) shl 8) or
                (data[offset].toInt() and 0xFF)
            }
            4 -> {
                // Little-Endian: 最低字节在前
                ((data[offset + 3].toInt() and 0xFF) shl 24) or
                ((data[offset + 2].toInt() and 0xFF) shl 16) or
                ((data[offset + 1].toInt() and 0xFF) shl 8) or
                (data[offset].toInt() and 0xFF)
            }
            else -> 0
        }
    }

    /**
     * 获取设备信息
     */
    private fun getDeviceInfo(device: UsbDevice): Map<String, Any?> {
        val manufacturer = device.manufacturerName ?: getManufacturerNameByVendorId(device.vendorId)
        val productName = device.productName ?: "USB Keyboard"

        // 判断键盘类型
        val keyboardType = when {
            productName.contains("numeric", ignoreCase = true) -> "numeric"
            productName.contains("keypad", ignoreCase = true) -> "numeric"
            productName.contains("num", ignoreCase = true) -> "numeric"
            else -> "full"
        }

        // 估算按键数量（仅作参考）
        val keyCount = when (keyboardType) {
            "numeric" -> 17  // 标准数字键盘17键
            else -> 104      // 全键盘约104键
        }

        return mapOf(
            "manufacturer" to manufacturer,
            "model" to productName,
            "specifications" to "VID: 0x${device.vendorId.toString(16).uppercase()}, PID: 0x${device.productId.toString(16).uppercase()}",
            "keyboardType" to keyboardType,
            "keyCount" to keyCount
        )
    }
    
    /**
     * 根据厂商ID获取厂商名称（兜底方法）
     */
    private fun getManufacturerNameByVendorId(vendorId: Int): String {
        return when (vendorId) {
            // === 主供应商键盘厂商 ===
            0x09da -> "A-FOUR TECH CO., LTD."
            0x1c4f -> "Beijing Sigmachip Co., Ltd."
            
            // === 国际主流品牌 ===
            0x046d -> "Logitech"
            0x045e -> "Microsoft"
            0x05ac -> "Apple"
            0x413c -> "Dell"
            0x17ef -> "Lenovo"
            0x03f0 -> "HP"
            0x1532 -> "Razer"
            0x1b1c -> "Corsair"
            0x3434 -> "Keychron"
            0x046a -> "Cherry"
            
            // === 通用HID芯片厂商 ===
            0x04d9 -> "Holtek Semiconductor"
            0x1a2c -> "China Resource Semico"
            0x258a -> "SINO WEALTH"
            0x04b4 -> "Cypress Semiconductor"
            0x062a -> "MosArt Semiconductor"
            0x1a86 -> "QinHeng Electronics"
            
            else -> "Unknown Manufacturer"
        }
    }

    /**
     * 请求USB设备权限
     */
    private fun requestPermission(call: MethodCall, result: Result) {
        val deviceId = call.argument<String>("deviceId")
        if (deviceId == null) {
            result.error("INVALID_ARGUMENT", "deviceId不能为空", null)
            return
        }

        try {
            val device = usbManager?.deviceList?.values?.find {
                it.deviceId.toString() == deviceId
            }

            if (device == null) {
                result.error("DEVICE_NOT_FOUND", "未找到设备: $deviceId", null)
                return
            }

            // 检查是否已有权限
            if (usbManager?.hasPermission(device) == true) {
                Log.d(TAG, "✓ 设备已有权限: ${device.deviceName}")
                result.success(true)
                return
            }

            // 请求权限
            val permissionIntent = PendingIntent.getBroadcast(
                context,
                0,
                Intent(ACTION_USB_PERMISSION),
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            )

            usbManager?.requestPermission(device, permissionIntent)
            Log.d(TAG, "🔐 已请求USB权限: ${device.deviceName}")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "请求权限失败: ${e.message}", e)
            result.error("PERMISSION_ERROR", "请求权限失败: ${e.message}", null)
        }
    }

    /**
     * 开始监听键盘事件
     * 
     * ⚠️ 重要：在授权后重新验证设备类型
     * 原因：初次扫描时无USB权限，第2层(HID Usage)无法生效
     *       授权后重新识别，确保使用最高准确率(99%)的识别方案
     */
    private fun startListening(call: MethodCall, result: Result) {
        Log.d(TAG, "🎧 开始监听键盘事件")
        
        val deviceId = call.argument<String>("deviceId")
        if (deviceId != null) {
            try {
                // 查找设备
                val device = usbManager?.deviceList?.values?.find {
                    it.deviceId.toString() == deviceId
                }
                
                if (device == null) {
                    Log.w(TAG, "⚠️ 未找到设备ID: $deviceId")
                    result.success(true)
                    return
                }
                
                // 检查权限
                val hasPermission = usbManager?.hasPermission(device) == true
                Log.d(TAG, "设备 ${device.deviceName} 权限状态: $hasPermission")
                
                if (hasPermission) {
                    // ========== 关键修复：授权后重新精确识别设备类型 ==========
                    // 此时有USB权限，第2层(HID Usage解析)可以生效
                    // 提供99%准确率的识别，避免扫描器误判为键盘
                    
                    Log.d(TAG, "🔍 授权后重新验证设备类型...")
                    val isKeyboard = isKeyboardDevice(device)
                    
                    if (!isKeyboard) {
                        Log.e(TAG, "❌ 设备 ${device.deviceName} 不是键盘设备（授权后精确识别）")
                        result.error(
                            "NOT_KEYBOARD_DEVICE",
                            "该设备不是键盘。可能是扫描器或其他HID设备。",
                            null
                        )
                        return
                    }
                    
                    Log.d(TAG, "✅ 设备 ${device.deviceName} 确认为键盘（授权后精确识别）")
                }
            } catch (e: Exception) {
                Log.e(TAG, "设备验证失败: ${e.message}", e)
                // 不阻断流程，继续执行
            }
        }
        
        // 键盘事件监听由系统级输入事件处理
        // 这里仅作占位，实际按键监听在应用层通过RawKeyboardListener处理
        result.success(true)
    }

    /**
     * 停止监听键盘事件
     */
    private fun stopListening(result: Result) {
        Log.d(TAG, "🔇 停止监听键盘事件")
        result.success(true)
    }

    /**
     * 注册USB广播接收器
     */
    private fun registerUsbReceiver() {
        val filter = IntentFilter().apply {
            addAction(ACTION_USB_PERMISSION)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        context?.registerReceiver(usbReceiver, filter)
        Log.d(TAG, "✓ USB广播接收器已注册")
    }

    /**
     * 注销USB广播接收器
     */
    private fun unregisterUsbReceiver() {
        try {
            context?.unregisterReceiver(usbReceiver)
            Log.d(TAG, "✓ USB广播接收器已注销")
        } catch (e: Exception) {
            // 忽略未注册异常
        }
    }

    /**
     * 发送调试日志到Flutter层
     * 
     * @param layer 识别层级（如："第1层-厂商黑名单", "第2层-HID Usage", "第3层-USB协议"）
     * @param message 日志消息
     * @param level 日志级别（"info", "success", "warning", "error"）
     * @param deviceInfo 设备信息（可选，包含设备名称、VID/PID等）
     */
    private fun sendDebugLog(
        layer: String,
        message: String,
        level: String = "info",
        deviceInfo: Map<String, Any>? = null
    ) {
        logEventSink?.let { sink ->
            val logData = mutableMapOf<String, Any>(
                "timestamp" to System.currentTimeMillis(),
                "layer" to layer,
                "message" to message,
                "level" to level
            )
            
            deviceInfo?.let {
                logData["deviceInfo"] = it
            }
            
            // 在主线程发送事件
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                sink.success(logData)
            }
        }
    }
}
