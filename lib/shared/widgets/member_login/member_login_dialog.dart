/// MemberLoginDialog
/// 会员登录对话框，使用通用 CardScanDialog 组件
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/widgets/card_scan_dialog.dart';
import 'member_login_controller.dart';
import 'member_registration_dialog.dart';

class MemberLoginDialog {
  /// 显示登录对话框(带注册会员按钮)
  static Future<void> show(BuildContext context) async {
    final controller = Get.find<MemberLoginController>();

    final result = await CardScanDialog.show(
      context: context,
      onRegister: () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const MemberRegistrationDialog(),
        );
      },
    );

    if (result != null) {
      // 刷卡成功,使用卡号登录（真实业务逻辑）
      controller.cardNumber.value = result.uid;
      controller.memberName.value = '张三'; // TODO: 调用后端接口获取会员信息
      controller.memberPhone.value = '138****5678';
      controller.isLoggedIn.value = true;
    }
  }

  /// 快速登录对话框(自动关闭,无注册按钮)
  /// 返回登录是否成功
  static Future<bool> showQuick(BuildContext context) async {
    final memberController = Get.isRegistered<MemberLoginController>()
        ? Get.find<MemberLoginController>()
        : Get.put(MemberLoginController());

    if (memberController.isLoggedIn.value) {
      return true;
    }

    final result = await CardScanDialog.show(context: context);

    if (result != null) {
      // 刷卡成功,使用卡号登录（真实业务逻辑）
      memberController.cardNumber.value = result.uid;
      memberController.memberName.value = '张三'; // TODO: 调用后端接口获取会员信息
      memberController.memberPhone.value = '138****5678';
      memberController.isLoggedIn.value = true;
    }

    return result != null && memberController.isLoggedIn.value;
  }
}
