/// CardScanDialog
/// 通用刷卡对话框组件
/// 可配置标题、提示文本、超时时间等
/// 作者：AI 自动生成
/// 更新时间：2025-11-20

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../app/theme/app_theme.dart';
import 'dialog.dart';
import 'card_scanner_widget.dart';

class CardScanDialog {
  /// 显示刷卡对话框
  /// [title] 对话框标题
  /// [hint] 提示文本
  /// [subHint] 子提示文本
  /// [onRegister] 注册会员回调
  static Future<CardScanResult?> show({
    required BuildContext context,
    String title = '会员登录',
    String hint = '请刷会员卡',
    String subHint = '请将会员卡靠近读卡器',
    VoidCallback? onRegister,
  }) async {
    final completer = Completer<CardScanResult?>();

    AppDialog.custom(
      title: title,
      content: CardScannerWidget(
        showDetails: false,
        hintText: hint,
        subHintText: subHint,
        onSuccess: (result) {
          if (!completer.isCompleted) {
            AppDialog.hide();
            completer.complete(result);
          }
        },
        onError: () {
          if (!completer.isCompleted) {
            AppDialog.hide();
            completer.complete(null);
          }
        },
      ),
      confirmText: '注册会员',
      cancelText: '取消',
      width: 500.w,
      barrierDismissible: false,
      onConfirm: () {
        AppDialog.hide(false);
        if (onRegister != null) {
          onRegister();
        }
      },
      onCancel: () {
        completer.complete(null);
      },
    );

    return completer.future;
  }
}
