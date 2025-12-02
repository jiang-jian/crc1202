package com.holox.ailand_pos

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.os.Bundle
import android.view.WindowManager
import android.view.KeyEvent
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var barcodeScannerPlugin: BarcodeScannerPlugin? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 设置窗口为全屏模式（隐藏状态栏和导航栏）
        window.setFlags(
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 注册 Sunmi Customer API Plugin（内置打印机）
        flutterEngine.plugins.add(SunmiCustomerApiPlugin())
        
        // 注册 External Printer Plugin（外接USB打印机）
        flutterEngine.plugins.add(ExternalPrinterPlugin())
        
        // 注册 External Card Reader Plugin（外接USB读卡器）
        flutterEngine.plugins.add(ExternalCardReaderPlugin())
        
        // 注册 MW Card Reader Plugin（MW读卡器）
        flutterEngine.plugins.add(MwCardReaderPlugin())
        
        // 注册 Barcode Scanner Plugin（USB条码扫描器）
        barcodeScannerPlugin = BarcodeScannerPlugin()
        flutterEngine.plugins.add(barcodeScannerPlugin!!)
        
        // 注册 Keyboard Plugin（USB外置键盘）
        flutterEngine.plugins.add(KeyboardPlugin())
    }
    
    /**
     * 拦截系统键盘事件，转发给条码扫描器插件
     * 这样USB扫描器模拟的键盘输入就能被正确捕获
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // 先尝试让条码扫描器插件处理
        barcodeScannerPlugin?.let { plugin ->
            if (plugin.handleKeyEventDirect(event)) {
                return true  // 事件已被扫描器处理，拦截
            }
        }
        
        // 否则让系统正常处理
        return super.dispatchKeyEvent(event)
    }
}
