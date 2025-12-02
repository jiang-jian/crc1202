/// CardScannerWidget
/// 独立的卡片识别组件 - 包含 UI 和 Controller
/// 可在任何位置复用，提供卡片识别功能
/// 作者：AI 自动生成
/// 更新时间：2025-11-20

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../app/theme/app_theme.dart';

/// 卡片识别结果
class CardScanResult {
  final String uid;
  final String type;

  CardScanResult({required this.uid, required this.type});
}

/// 卡片识别组件控制器
class CardScannerController extends GetxController {
  static const platform = MethodChannel('com.holox.ailand_pos/mw_card_reader');

  // 🎭 模拟模式开关 - 自动根据编译模式判断
  late final bool isSimulationMode;

  // 识别状态
  final isScanning = false.obs;
  final isSuccess = false.obs;

  // 卡片信息
  final cardUid = ''.obs;
  final cardType = ''.obs;

  // 回调
  final Function(CardScanResult)? onSuccess;
  final VoidCallback? onError;

  CardScannerController({this.onSuccess, this.onError}) {
    // Debug/Profile 模式自动开启模拟模式，Release 模式关闭
    isSimulationMode = kDebugMode || kProfileMode;
  }

  @override
  void onInit() {
    super.onInit();
    // 自动开始扫描
    startScanning();
  }

  @override
  void onClose() {
    stopScanning();
    super.onClose();
  }

  /// 开始扫描
  void startScanning() {
    if (isScanning.value) return;

    isScanning.value = true;
    isSuccess.value = false;
    cardUid.value = '';
    cardType.value = '';

    _scanCard();
  }

  /// 停止扫描
  void stopScanning() {
    isScanning.value = false;
  }

  /// 重置状态
  void reset() {
    isSuccess.value = false;
    cardUid.value = '';
    cardType.value = '';
    startScanning();
  }

  /// 扫描卡片
  Future<void> _scanCard() async {
    // 模拟模式：直接返回模拟数据
    if (isSimulationMode) {
      await Future.delayed(const Duration(seconds: 2));
      if (isScanning.value) {
        _onCardDetected(
          '04${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase().padLeft(12, '0').substring(0, 12)}',
          'MIFARE Classic 1K',
        );
      }
      return;
    }

    // 真实模式：调用原生方法
    while (isScanning.value) {
      try {
        final result = await platform.invokeMethod('detectCard');

        if (result != null) {
          final uid = result['uid'];
          final type = result['type'];

          if (uid != null && uid.isNotEmpty) {
            _onCardDetected(uid, type ?? 'Unknown');
            return;
          }
        }

        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        await Future.delayed(const Duration(milliseconds: 1000));
        // 如果持续失败，触发错误回调
        if (isScanning.value && onError != null) {
          onError!();
          stopScanning();
        }
      }
    }
  }

  /// 卡片检测成功
  void _onCardDetected(String uid, String type) {
    cardUid.value = uid;
    cardType.value = type;
    isSuccess.value = true;
    isScanning.value = false;

    // 触发成功回调
    if (onSuccess != null) {
      onSuccess!(CardScanResult(uid: uid, type: type));
    }
    _beep();
  }

  /// 蜂鸣器
  Future<void> _beep() async {
    try {
      await platform.invokeMethod('beep', {
        'times': 1,
        'duration': 1,
        'interval': 2,
      });
    } catch (e) {
      // 忽略蜂鸣错误
    }
  }
}

/// 卡片识别组件 UI
class CardScannerWidget extends StatefulWidget {
  /// 识别成功回调
  final Function(CardScanResult)? onSuccess;

  /// 识别失败回调
  final VoidCallback? onError;

  /// 显示详细信息
  final bool showDetails;

  /// 自定义提示文本
  final String? hintText;

  /// 自定义子提示文本
  final String? subHintText;

  const CardScannerWidget({
    super.key,
    this.onSuccess,
    this.onError,
    this.showDetails = true,
    this.hintText,
    this.subHintText,
  });

  @override
  State<CardScannerWidget> createState() => _CardScannerWidgetState();
}

class _CardScannerWidgetState extends State<CardScannerWidget> {
  late String _controllerTag;
  CardScannerController? _controller;

  @override
  void initState() {
    super.initState();
    _controllerTag = 'card_scanner_${DateTime.now().millisecondsSinceEpoch}';
    _controller = Get.put(
      CardScannerController(
        onSuccess: widget.onSuccess,
        onError: widget.onError,
      ),
      tag: _controllerTag,
    );
  }

  @override
  void dispose() {
    // 清理 Controller
    if (Get.isRegistered<CardScannerController>(tag: _controllerTag)) {
      Get.delete<CardScannerController>(tag: _controllerTag, force: true);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      if (_controller!.isSuccess.value) {
        return _buildSuccessView();
      }
      return _buildScanningView();
    });
  }

  /// 扫描中视图
  Widget _buildScanningView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildScanAnimation(),
        SizedBox(height: AppTheme.spacingXL),
        Text(
          widget.hintText ?? '请刷卡',
          style: AppTheme.textHeading.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppTheme.spacingS),
        Text(
          widget.subHintText ?? '将卡片靠近读卡器',
          style: AppTheme.textBody.copyWith(color: AppTheme.textTertiary),
        ),
      ],
    );
  }

  /// 识别成功视图
  Widget _buildSuccessView() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final clampedOpacity = value.clamp(0.0, 1.0);
        return Transform.scale(
          scale: value,
          child: Opacity(opacity: clampedOpacity, child: child),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(AppTheme.spacingDefault),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withAlpha((0.1 * 255).toInt()),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 60.sp,
              color: AppTheme.successColor,
            ),
          ),
          SizedBox(height: AppTheme.spacingL),
          Text(
            '识别成功',
            style: AppTheme.textHeading.copyWith(
              color: AppTheme.successColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.showDetails) ...[
            SizedBox(height: AppTheme.spacingL),
            _buildInfoRow('卡片类型', _controller!.cardType.value),
            SizedBox(height: AppTheme.spacingM),
            _buildInfoRow('卡片UID', _controller!.cardUid.value),
          ],
        ],
      ),
    );
  }

  /// 扫描动画
  Widget _buildScanAnimation() {
    return const _ScanAnimationWidget();
  }

  /// 信息行
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$label: ', style: AppTheme.textCaption),
        Text(
          value.isEmpty ? '-' : value,
          style: AppTheme.textBody.copyWith(
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

/// 循环扫描动画组件
class _ScanAnimationWidget extends StatefulWidget {
  const _ScanAnimationWidget();

  @override
  State<_ScanAnimationWidget> createState() => _ScanAnimationWidgetState();
}

class _ScanAnimationWidgetState extends State<_ScanAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value;
        return SizedBox(
          width: 120.w,
          height: 120.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 外圈脉动
              Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryColor.withAlpha(
                      ((0.3 * (1 - value)) * 255).toInt(),
                    ),
                    width: 2.w,
                  ),
                ),
              ),
              Container(
                width: 120.w * (0.7 + 0.3 * value),
                height: 120.w * (0.7 + 0.3 * value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryColor.withAlpha(
                      ((0.5 * (1 - value)) * 255).toInt(),
                    ),
                    width: 2.w,
                  ),
                ),
              ),
              // 中心图标
              Container(
                width: 80.w,
                height: 80.w,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha((0.1 * 255).toInt()),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.nfc,
                  size: 40.sp,
                  color: AppTheme.primaryColor,
                ),
              ),
              // 扫描线
              Positioned(
                top: 20.w + (80.w * value),
                child: Container(
                  width: 80.w,
                  height: 2.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withAlpha(0),
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withAlpha(0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
