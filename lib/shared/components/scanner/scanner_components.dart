// ═══════════════════════════════════════════════════════════════
// 扫描器组件库
// ═══════════════════════════════════════════════════════════════
//
// 统一导出文件，简化导入语句
//
// 使用方法：
// ```dart
// import 'package:ailand_pos/shared/components/scanner/scanner_components.dart';
// ```
//
// ═══════════════════════════════════════════════════════════════

library scanner_components;

// 核心组件
export 'scanner_controller_mixin.dart';
export 'scanner_indicator_widget.dart';
export 'scanner_utils.dart';

// 数据模型（从service导入）
export '../../../data/models/barcode_scanner_model.dart';
export '../../../data/services/barcode_scanner_service.dart';
