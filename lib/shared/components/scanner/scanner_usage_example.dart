// ═══════════════════════════════════════════════════════════════
// 扫描器组件使用示例
// ═══════════════════════════════════════════════════════════════
//
// 本文件展示了三种使用扫描器组件的方法：
// 1. 使用 ScannerControllerMixin（推荐用于复杂页面）
// 2. 使用 ScannerUtils 工具类（推荐用于简单场景）
// 3. 使用 ScannerIndicatorWidget UI组件
//
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../data/models/barcode_scanner_model.dart';
import 'scanner_controller_mixin.dart';
import 'scanner_indicator_widget.dart';
import 'scanner_utils.dart';

// ═══════════════════════════════════════════════════════════════
// 方法 1: 使用 ScannerControllerMixin（推荐用于复杂业务）
// ═══════════════════════════════════════════════════════════════
//
// 适用场景：
// - 商品搜索页面
// - 收银台扫码
// - 库存盘点
// - 需要复杂业务逻辑的页面
//
// 优点：
// - 自动管理扫描器生命周期
// - 代码结构清晰
// - 易于测试和维护
// ═══════════════════════════════════════════════════════════════

class ProductSearchController extends GetxController with ScannerControllerMixin {
  // 商品列表
  final RxList<String> scannedProducts = <String>[].obs;
  
  @override
  void onScanSuccess(ScanResult result) {
    // 验证是否为有效的商品条码
    if (ScannerUtils.isValidProductBarcode(result)) {
      final barcode = ScannerUtils.formatBarcode(result.content);
      
      // 调用API查询商品信息
      _fetchProductByBarcode(barcode);
    } else {
      Get.snackbar(
        '无效条码',
        '扫描的不是有效的商品条码',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  
  Future<void> _fetchProductByBarcode(String barcode) async {
    // TODO: 调用实际的API
    // final product = await productRepository.getByBarcode(barcode);
    
    // 模拟API调用
    await Future.delayed(const Duration(milliseconds: 500));
    scannedProducts.add('商品-$barcode');
    
    Get.snackbar(
      '扫码成功',
      '已添加商品: $barcode',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
    );
  }
}

class ProductSearchPage extends StatelessWidget {
  const ProductSearchPage({super.key});
  
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProductSearchController());
    
    return Scaffold(
      appBar: AppBar(title: const Text('商品搜索')),
      body: Column(
        children: [
          // 扫描器状态指示器
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: ScannerIndicatorWidget(),
          ),
          
          // 已扫描的商品列表
          Expanded(
            child: Obx(() => ListView.builder(
              itemCount: controller.scannedProducts.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(controller.scannedProducts[index]),
                );
              },
            )),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 方法 2: 使用 ScannerUtils 工具类（推荐用于简单场景）
// ═══════════════════════════════════════════════════════════════
//
// 适用场景：
// - 快速原型开发
// - 简单的扫码功能
// - 无需复杂状态管理
// - 一次性扫码
//
// 优点：
// - 代码量少
// - 快速集成
// - 灵活度高
// ═══════════════════════════════════════════════════════════════

class QuickScanPage extends StatefulWidget {
  const QuickScanPage({super.key});
  
  @override
  State<QuickScanPage> createState() => _QuickScanPageState();
}

class _QuickScanPageState extends State<QuickScanPage> {
  String? lastScannedCode;
  
  @override
  void initState() {
    super.initState();
    _startScanning();
  }
  
  @override
  void dispose() {
    ScannerUtils.stop();
    super.dispose();
  }
  
  // 启动连续扫描
  Future<void> _startScanning() async {
    await ScannerUtils.quickStart(
      onScan: (result) {
        setState(() {
          lastScannedCode = result.content;
        });
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      },
    );
  }
  
  // 一次性扫描示例
  Future<void> _scanOnce() async {
    await ScannerUtils.scanOnce(
      onScan: (result) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('扫码结果'),
            content: Text(result.content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      },
      timeout: const Duration(seconds: 10),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('快速扫码')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 使用扫描器指示器组件
            const ScannerIndicatorWidget(
              showLabel: true,
              enablePulse: true,
            ),
            
            SizedBox(height: 40.h),
            
            if (lastScannedCode != null)
              Text(
                '最后扫码: $lastScannedCode',
                style: TextStyle(fontSize: 16.sp),
              ),
            
            SizedBox(height: 40.h),
            
            ElevatedButton(
              onPressed: _scanOnce,
              child: const Text('单次扫码'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 方法 3: 收银台场景示例（结合Mixin + Widget）
// ═══════════════════════════════════════════════════════════════

class CheckoutController extends GetxController with ScannerControllerMixin {
  final RxList<Map<String, dynamic>> cartItems = <Map<String, dynamic>>[].obs;
  final RxDouble totalAmount = 0.0.obs;
  
  @override
  void onScanSuccess(ScanResult result) {
    if (ScannerUtils.isValidProductBarcode(result)) {
      _addProductToCart(result.content);
    }
  }
  
  void _addProductToCart(String barcode) {
    // 模拟商品数据
    final product = {
      'barcode': barcode,
      'name': '商品-${barcode.substring(0, 6)}',
      'price': 29.90,
    };
    
    cartItems.add(product);
    totalAmount.value += product['price'] as double;
    
    Get.snackbar(
      '已添加',
      product['name'] as String,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
    );
  }
  
  void removeItem(int index) {
    final item = cartItems[index];
    totalAmount.value -= item['price'] as double;
    cartItems.removeAt(index);
  }
  
  void clearCart() {
    cartItems.clear();
    totalAmount.value = 0.0;
  }
}

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});
  
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CheckoutController());
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('收银台'),
        actions: [
          // 扫描器状态指示器（小尺寸）
          Center(
            child: Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: const ScannerIndicatorWidget(
                size: 40,
                showLabel: false,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 购物车列表
          Expanded(
            child: Obx(() => ListView.builder(
              itemCount: controller.cartItems.length,
              itemBuilder: (context, index) {
                final item = controller.cartItems[index];
                return ListTile(
                  title: Text(item['name'] as String),
                  subtitle: Text('条码: ${item['barcode']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '¥${(item['price'] as double).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => controller.removeItem(index),
                      ),
                    ],
                  ),
                );
              },
            )),
          ),
          
          // 底部合计栏
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Obx(() => Text(
                  '合计: ¥${controller.totalAmount.value.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                )),
                ElevatedButton(
                  onPressed: () {
                    // TODO: 结账逻辑
                    controller.clearCart();
                  },
                  child: const Text('结账'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
