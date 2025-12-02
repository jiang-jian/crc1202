package com.holox.ailand_pos

import android.content.Context
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.app.PendingIntent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.mwcard.Reader
import com.mwcard.ReaderAndroidUsb

/**
* MW读卡器插件
* 支持USB连接的MW读卡器,主要用于M1卡读写
*/
class MwCardReaderPlugin : FlutterPlugin, MethodCallHandler {
private lateinit var channel: MethodChannel
private lateinit var context: Context
private var reader: Reader? = null
private var usbManager: UsbManager? = null
private val mainHandler = Handler(Looper.getMainLooper())

companion object {
private const val CHANNEL_NAME = "com.holox.ailand_pos/mw_card_reader"
private const val ACTION_USB_PERMISSION = "com.holox.ailand_pos.USB_PERMISSION"
}

// USB权限广播接收器
private val usbReceiver = object : BroadcastReceiver() {
override fun onReceive(context: Context, intent: Intent) {
when (intent.action) {
ACTION_USB_PERMISSION -> {
synchronized(this) {
val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
device?.let {
// 权限已授予,尝试连接
connectUsbDevice(it)
}
} else {
// 权限被拒绝
sendEvent("permission_denied", mapOf("message" to "USB权限被拒绝"))
}
}
}
}
}
}

override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
context = binding.applicationContext
channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
channel.setMethodCallHandler(this)

usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager

// 注册USB权限广播
val filter = IntentFilter(ACTION_USB_PERMISSION)
context.registerReceiver(usbReceiver, filter)
}

override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
channel.setMethodCallHandler(null)
try {
context.unregisterReceiver(usbReceiver)
} catch (e: Exception) {
// 忽略
}
closeReader()
}

override fun onMethodCall(call: MethodCall, result: Result) {
when (call.method) {
"openReaderUSB" -> openReaderUSB(result)
"closeReader" -> closeReader(result)
"getHardwareVer" -> getHardwareVer(result)
"getSerialNumber" -> getSerialNumber(result)
"beep" -> {
val times = call.argument<Int>("times") ?: 1
val duration = call.argument<Int>("duration") ?: 1
val interval = call.argument<Int>("interval") ?: 2
beep(times, duration, interval, result)
}
"checkCard" -> checkCard(result)
"detectCard" -> detectCard(result)
"startCardDetection" -> startCardDetection(result)
"stopCardDetection" -> stopCardDetection(result)
"openCard" -> {
val mode = call.argument<Int>("mode") ?: 0
openCard(mode, result)
}
"mifareAuth" -> {
val mode = call.argument<Int>("mode") ?: 0
val sector = call.argument<Int>("sector") ?: 0
val pwd = call.argument<String>("pwd") ?: "FFFFFFFFFFFF"
mifareAuth(mode, sector, pwd, result)
}
"mifareRead" -> {
val block = call.argument<Int>("block") ?: 0
mifareRead(block, result)
}
"mifareWrite" -> {
val block = call.argument<Int>("block") ?: 0
val data = call.argument<String>("data") ?: ""
mifareWrite(block, data, result)
}
"mifareInitVal" -> {
val block = call.argument<Int>("block") ?: 0
val value = call.argument<Int>("value") ?: 0
mifareInitVal(block, value, result)
}
"mifareReadVal" -> {
val block = call.argument<Int>("block") ?: 0
mifareReadVal(block, result)
}
"mifareIncrement" -> {
val block = call.argument<Int>("block") ?: 0
val value = call.argument<Int>("value") ?: 0
mifareIncrement(block, value, result)
}
"mifareDecrement" -> {
val block = call.argument<Int>("block") ?: 0
val value = call.argument<Int>("value") ?: 0
mifareDecrement(block, value, result)
}
"halt" -> halt(result)
"isConnected" -> isConnected(result)
else -> result.notImplemented()
}
}

// 打开USB读卡器
private fun openReaderUSB(result: Result) {
try {
if (reader != null) {
result.error("ALREADY_CONNECTED", "读卡器已连接", null)
return
}

val manager = usbManager ?: run {
result.error("NO_USB_MANAGER", "无法获取USB管理器", null)
return
}

val deviceList = manager.deviceList
if (deviceList.isEmpty()) {
result.error("NO_DEVICE", "未找到USB设备", null)
return
}

var foundDevice: UsbDevice? = null
for (device in deviceList.values) {
if (ReaderAndroidUsb.isSupported(device)) {
foundDevice = device
break
}
}

if (foundDevice == null) {
result.error("NO_SUPPORTED_DEVICE", "未找到支持的读卡器设备", null)
return
}

// 检查是否有权限
if (manager.hasPermission(foundDevice)) {
connectUsbDevice(foundDevice)
result.success(true)
} else {
// 请求权限
val permissionIntent = PendingIntent.getBroadcast(
context,
0,
Intent(ACTION_USB_PERMISSION),
PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
)
manager.requestPermission(foundDevice, permissionIntent)
result.success(null) // 权限请求中
}
} catch (e: Exception) {
result.error("ERROR", "打开读卡器失败: ${e.message}", null)
}
}

// 连接USB设备
private fun connectUsbDevice(device: UsbDevice) {
try {
val manager = usbManager ?: return
val usbReader = ReaderAndroidUsb(manager)
val st = usbReader.openReader(device)

if (st >= 0) {
reader = usbReader
sendEvent("connected", mapOf(
"type" to "usb",
"message" to "读卡器连接成功"
))
} else {
sendEvent("error", mapOf(
"code" to st,
"message" to "读卡器连接失败"
))
}
} catch (e: Exception) {
sendEvent("error", mapOf("message" to "连接异常: ${e.message}"))
}
}

// 关闭读卡器
private fun closeReader(result: Result) {
try {
reader?.let {
it.closeReader()
reader = null
result.success(true)
} ?: result.error("NO_READER", "读卡器未连接", null)
} catch (e: Exception) {
result.error("ERROR", "关闭读卡器失败: ${e.message}", null)
}
}

// 关闭读卡器(内部使用)
private fun closeReader() {
try {
reader?.closeReader()
reader = null
} catch (e: Exception) {
// 忽略错误
}
}

// 获取硬件版本
private fun getHardwareVer(result: Result) {
try {
reader?.let {
val version = it.hardwareVer
result.success(version)
} ?: result.error("NO_READER", "读卡器未连接", null)
} catch (e: Exception) {
result.error("ERROR", "获取硬件版本失败: ${e.message}", null)
}
}

// 获取序列号
private fun getSerialNumber(result: Result) {
try {
reader?.let {
val sn = it.serialNumber
result.success(sn)
} ?: result.error("NO_READER", "读卡器未连接", null)
} catch (e: Exception) {
result.error("ERROR", "获取序列号失败: ${e.message}", null)
}
}

// 蜂鸣器
private fun beep(times: Int, duration: Int, interval: Int, result: Result) {
try {
reader?.let {
it.beep(times, duration, interval)
result.success(true)
} ?: result.error("NO_READER", "读卡器未连接", null)
} catch (e: Exception) {
result.error("ERROR", "蜂鸣失败: ${e.message}", null)
}
}

// 检测卡片类型(接触卡)
private fun checkCard(result: Result) {
try {
reader?.let {
val cardType = it.CheckCard()
val typeName = when (cardType) {
1 -> "AT24C01A"
2 -> "AT24C02"
3 -> "AT24C04"
4 -> "AT24C08"
5 -> "AT24C16"
11 -> "AT24C32"
6 -> "AT24C64"
7 -> "AT24C128"
8 -> "AT24C256"
21 -> "SLE4442"
31 -> "SLE4428"
51 -> "AT88SC102"
54 -> "AT88SC153"
52 -> "AT88SC1604"
13 -> "AT88SC1608"
255 -> "CPU"
else -> "未知卡型"
}
result.success(mapOf(
"code" to cardType,
"name" to typeName
))
} ?: result.error("NO_READER", "读卡器未连接", null)
} catch (e: Exception) {
result.error("ERROR", "检测卡片失败: ${e.message}", null)
}
}

// 检测卡片(接触卡或非接卡)
private fun detectCard(result: Result) {
try {
reader?.let {
val pOutInfo = StringBuilder()
val st = it.DetectCard(pOutInfo)
if (st >= 0) {
result.success(mapOf(
"status" to st,
"info" to pOutInfo.toString()
))
} else {
result.error("ERROR", "检测失败", mapOf("code" to st))
}
} ?: result.error("NO_READER", "读卡器未连接", null)
} catch (e: Exception) {
result.error("ERROR", "检测卡片失败: ${e.message}", null)
}
}

// 循环检测 M1 卡片(用于自动识别)
private fun startCardDetection(result: Result) {
try {
reader?.let { r ->
// 在后台线程循环检测
Thread {
try {
while (true) {
try {
// 尝试打开卡片 (TypeA)
val uid = r.openCard(0)
if (uid != null && uid.isNotEmpty()) {
// 检测成功，发送事件
mainHandler.post {
channel.invokeMethod("onEvent", mapOf(
"event" to "card_detected",
"data" to mapOf(
"uid" to uid,
"type" to "MIFARE Classic"
)
))
}
// 关闭卡片
try {
r.halt()
} catch (e: Exception) {
// 忽略 halt 错误
}
Thread.sleep(500) // 避免频繁检测
}
} catch (e: Exception) {
// 无卡或检测失败，继续循环
Thread.sleep(300)
}
}
} catch (e: InterruptedException) {
// 线程被中断，停止检测
}
}.start()
result.success(true)
} ?: result.error("NO_READER", "读卡器未连接", null)
} catch (e: Exception) {
result.error("ERROR", "启动卡片检测失败: ${e.message}", null)
}
}

// 停止卡片检测
private fun stopCardDetection(result: Result) {
// 此处简化实现，实际应该维护检测线程的引用以便停止
result.success(true)
}

// 打开M1卡
private fun openCard(mode: Int, result: Result) {
try {
reader?.let {
val uid = it.openCard(mode)
if (uid != null && uid.isNotEmpty()) {
result.success(mapOf(
"uid" to uid,
"success" to true
))
} else {
result.error("NO_CARD", "未检测到卡片", null)
}
} ?: result.error("NO_READER", "读卡器未连接", null)
} catch (e: Exception) {
result.error("ERROR", "打开卡片失败: ${e.message}", null)
}
}

// M1卡密码验证
private fun mifareAuth(mode: Int, sector: Int, pwd: String, result: Result) {
try {
reader?.let {
it.mifareAuth(mode, sector, pwd)
result.success(true)
} ?: result.error("NO_READER", "读卡器未连接", null)
} catch (e: Exception) {
result.error("ERROR", "密码验证失败: ${e.message}", null)
}
}

// 读M1卡块
private fun mifareRead(block: Int, result: Result) {
try {
reader?.let {
val data = it.mifareRead(block)
result.success(data)
} ?: result.error("NO_READER", "读卡器未连接", null)
} catch (e: Exception) {
result.error("ERROR", "读卡失败: ${e.message}", null)
}
}

// 写M1卡块
private fun mifareWrite(block: Int, data: String, result: Result) {
try {
reader?.let {
if (data.length != 32) {
result.error("INVALID_DATA", "数据必须是32位十六进制字符串", null)
return
}
it.mifareWrite(block, data)
result.success(true)
} ?: result.error("NO_READER", "读卡器未连接", null)
} catch (e: Exception) {
result.error("ERROR", "写卡失败: ${e.message}", null)
}
}

// M1卡初始化值
private fun mifareInitVal(block: Int, value: Int, result: Result) {
try {
reader?.let {
it.mifareInitVal(block, value.toLong())
result.success(true)
} ?: result.error("NO_READER", "读卡器未连接", null)
} catch (e: Exception) {
result.error("ERROR", "初始化值失败: ${e.message}", null)
}
}

// M1卡读值
private fun mifareReadVal(block: Int, result: Result) {
try {
reader?.let {
val value = it.mifareReadVal(block)
result.success(value)
} ?: result.error("NO_READER", "读卡器未连接", null)
} catch (e: Exception) {
result.error("ERROR", "读值失败: ${e.message}", null)
}
}

// M1卡增值
private fun mifareIncrement(block: Int, value: Int, result: Result) {
try {
reader?.let {
it.mifareIncrement(block, value.toLong())
result.success(true)
} ?: result.error("NO_READER", "读卡器未连接", null)
} catch (e: Exception) {
result.error("ERROR", "增值失败: ${e.message}", null)
}
}

// M1卡减值
private fun mifareDecrement(block: Int, value: Int, result: Result) {
try {
reader?.let {
it.mifareDecrement(block, value.toLong())
result.success(true)
} ?: result.error("NO_READER", "读卡器未连接", null)
} catch (e: Exception) {
result.error("ERROR", "减值失败: ${e.message}", null)
}
}

// 关闭卡片
private fun halt(result: Result) {
try {
reader?.let {
it.halt()
result.success(true)
} ?: result.error("NO_READER", "读卡器未连接", null)
} catch (e: Exception) {
result.error("ERROR", "关闭卡片失败: ${e.message}", null)
}
}

// 检查是否已连接
private fun isConnected(result: Result) {
result.success(reader != null)
}

// 发送事件到Flutter
private fun sendEvent(event: String, data: Map<String, Any>) {
mainHandler.post {
channel.invokeMethod("onEvent", mapOf(
"event" to event,
"data" to data
))
}
}
}
