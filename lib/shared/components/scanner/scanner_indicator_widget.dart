import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../data/services/barcode_scanner_service.dart';

/// 扫描器状态指示器组件
/// 显示扫描器的连接状态和扫描动画
///
/// 使用方法：
/// ```dart
/// ScannerIndicatorWidget(
///   size: 120,
///   onTap: () => print('点击扫描器指示器'),
/// )
/// ```
class ScannerIndicatorWidget extends StatelessWidget {
  /// 指示器大小
  final double? size;

  /// 是否显示文字提示
  final bool showLabel;

  /// 自定义标签文本
  final String? customLabel;

  /// 点击回调
  final VoidCallback? onTap;

  /// 是否启用脉冲动画
  final bool enablePulse;

  const ScannerIndicatorWidget({
    super.key,
    this.size,
    this.showLabel = true,
    this.customLabel,
    this.onTap,
    this.enablePulse = true,
  });

  @override
  Widget build(BuildContext context) {
    final scannerService = Get.find<BarcodeScannerService>();
    final indicatorSize = size ?? 120.w;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 扫描器图标/动画
          Obx(() {
            final isListening = scannerService.isListening.value;
            final hasError = scannerService.lastError.value != null;

            return _buildIndicator(
              size: indicatorSize,
              isListening: isListening,
              hasError: hasError,
              enablePulse: enablePulse,
            );
          }),

          // 文字标签
          if (showLabel) ...[
            SizedBox(height: 12.h),
            Obx(() {
              final isListening = scannerService.isListening.value;
              final hasError = scannerService.lastError.value != null;

              String labelText;
              Color labelColor;

              if (customLabel != null) {
                labelText = customLabel!;
                labelColor = Colors.black87;
              } else if (hasError) {
                labelText = '扫描器错误';
                labelColor = Colors.red;
              } else if (isListening) {
                labelText = '等待扫码...';
                labelColor = Colors.green;
              } else {
                labelText = '扫描器未就绪';
                labelColor = Colors.grey;
              }

              return Text(
                labelText,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: labelColor,
                  fontWeight: FontWeight.w500,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// 构建指示器
  Widget _buildIndicator({
    required double size,
    required bool isListening,
    required bool hasError,
    required bool enablePulse,
  }) {
    // 确定颜色
    Color indicatorColor;
    IconData iconData;

    if (hasError) {
      indicatorColor = Colors.red;
      iconData = Icons.error_outline;
    } else if (isListening) {
      indicatorColor = Colors.green;
      iconData = Icons.qr_code_scanner;
    } else {
      indicatorColor = Colors.grey;
      iconData = Icons.qr_code_2;
    }

    Widget indicator = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: indicatorColor.withOpacity(0.3), width: 2),
      ),
      child: Icon(iconData, size: size * 0.5, color: indicatorColor),
    );

    // 添加脉冲动画（仅在监听时）
    if (enablePulse && isListening) {
      indicator = _PulsingIndicator(color: indicatorColor, child: indicator);
    }

    return indicator;
  }
}

/// 脉冲动画指示器
class _PulsingIndicator extends StatefulWidget {
  final Widget child;
  final Color color;

  const _PulsingIndicator({required this.child, required this.color});

  @override
  State<_PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<_PulsingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // 外层脉冲圆环
            Container(
              width: 120.w * _animation.value,
              height: 120.w * _animation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color.withOpacity(
                    0.3 * (1 - (_animation.value - 0.8) / 0.4),
                  ),
                  width: 2,
                ),
              ),
            ),
            // 内层指示器
            widget.child,
          ],
        );
      },
    );
  }
}
