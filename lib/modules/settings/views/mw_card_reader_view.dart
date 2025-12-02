import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/debug_log_window.dart';
import '../controllers/mw_card_reader_controller.dart';

/// MW读卡器管理界面
class MwCardReaderView extends GetView<MwCardReaderController> {
  const MwCardReaderView({super.key});

  static const String debugTag = 'mw_card_reader';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                SizedBox(height: AppTheme.spacingL),
                Expanded(child: _buildControlPanel()),
              ],
            ),
          ),
          // 调试日志窗口
          DebugLogWindow(
            tag: debugTag,
            width: 500.w,
            height: 600.h,
            collapsedHeight: 40.h,
          ),
        ],
      ),
    );
  }

  /// 顶部标题栏
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingL,
        vertical: AppTheme.spacingDefault,
      ),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Icon(Icons.nfc, size: 28.sp, color: AppTheme.primaryColor),
          SizedBox(width: AppTheme.spacingM),
          Text(
            'MW读卡器',
            style: AppTheme.textHeading.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          Obx(
            () => Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingDefault,
                vertical: AppTheme.spacingS,
              ),
              decoration: BoxDecoration(
                color: controller.isConnected.value
                    ? AppTheme.successColor.withAlpha((0.1 * 255).toInt())
                    : AppTheme.backgroundDisabled,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusRound),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: BoxDecoration(
                      color: controller.isConnected.value
                          ? AppTheme.successColor
                          : AppTheme.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacingS),
                  Text(
                    controller.isConnected.value ? '已连接' : '未连接',
                    style: AppTheme.textBody.copyWith(
                      color: controller.isConnected.value
                          ? AppTheme.successColor
                          : AppTheme.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 控制面板
  Widget _buildControlPanel() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：设备管理
              Expanded(flex: 1, child: _buildDeviceSection()),
              SizedBox(width: AppTheme.spacingL),
              // 右侧：卡片信息
              Expanded(flex: 1, child: _buildCardInfoSection()),
            ],
          ),
          SizedBox(height: AppTheme.spacingL),
          // M1 卡操作区域
          _buildM1CardSection(),
        ],
      ),
    );
  }

  /// 设备管理区域
  Widget _buildDeviceSection() {
    return _buildCard(
      title: '设备管理',
      icon: Icons.settings_input_hdmi,
      iconColor: AppTheme.primaryColor,
      child: Column(
        children: [
          Obx(
            () => !controller.isConnected.value
                ? _buildButton(
                    text: '打开USB读卡器',
                    icon: Icons.usb,
                    color: AppTheme.primaryColor,
                    onPressed: controller.openReaderUSB,
                  )
                : Column(
                    children: [
                      _buildInfoRow('硬件版本', controller.hardwareVersion.value),
                      SizedBox(height: AppTheme.spacingS),
                      _buildInfoRow('序列号', controller.serialNumber.value),
                      SizedBox(height: AppTheme.spacingM),
                      Row(
                        children: [
                          Expanded(
                            child: _buildButton(
                              text: '蜂鸣测试',
                              icon: Icons.volume_up,
                              color: AppTheme.warningColor,
                              onPressed: controller.beep,
                            ),
                          ),
                          SizedBox(width: AppTheme.spacingM),
                          Expanded(
                            child: _buildButton(
                              text: '关闭设备',
                              icon: Icons.power_settings_new,
                              color: AppTheme.errorColor,
                              onPressed: controller.closeReader,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 卡片信息区域
  Widget _buildCardInfoSection() {
    return _buildCard(
      title: '卡片信息',
      icon: Icons.credit_card,
      iconColor: AppTheme.successColor,
      child: Obx(() {
        if (!controller.isConnected.value) {
          return _buildEmptyState('设备未连接', Icons.link_off);
        }

        return Column(
          children: [
            // 自动检测开关
            Row(
              children: [
                Text('自动检测:', style: AppTheme.textBody),
                const Spacer(),
                Switch(
                  value: controller.isAutoDetecting.value,
                  onChanged: (value) async {
                    if (value) {
                      await controller.startCardDetection();
                    } else {
                      await controller.stopCardDetection();
                    }
                  },
                  activeColor: AppTheme.successColor,
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacingM),
            // 手动检测按钮
            if (!controller.isAutoDetecting.value)
              _buildButton(
                text: '检测卡片',
                icon: Icons.nfc,
                color: AppTheme.primaryColor,
                onPressed: controller.openCard,
              ),
            SizedBox(height: AppTheme.spacingM),
            // 卡片信息显示
            if (controller.cardDetected.value) ...[
              Container(
                padding: EdgeInsets.all(AppTheme.spacingDefault),
                decoration: AppTheme.greyContainerDecoration(),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.successColor,
                          size: 20.sp,
                        ),
                        SizedBox(width: AppTheme.spacingS),
                        Text(
                          '已检测到卡片',
                          style: AppTheme.textBody.copyWith(
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppTheme.spacingM),
                    _buildInfoRow('类型', controller.cardType.value),
                    SizedBox(height: AppTheme.spacingS),
                    _buildInfoRow('UID', controller.cardUid.value),
                  ],
                ),
              ),
            ] else
              _buildEmptyState('未检测到卡片', Icons.credit_card_outlined),
          ],
        );
      }),
    );
  }

  /// M1 卡操作区域
  Widget _buildM1CardSection() {
    return _buildCard(
      title: 'M1 卡操作测试',
      icon: Icons.developer_board,
      iconColor: AppTheme.primaryColor,
      child: Obx(() {
        if (!controller.isConnected.value) {
          return _buildEmptyState('请先连接读卡器', Icons.link_off);
        }

        if (!controller.cardDetected.value) {
          return _buildEmptyState('请先检测卡片', Icons.credit_card_outlined);
        }

        return _M1CardOperationWidget(controller: controller);
      }),
    );
  }

  /// 空状态提示
  Widget _buildEmptyState(String message, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: AppTheme.spacingL),
        Center(
          child: Icon(icon, size: 60.sp, color: AppTheme.textTertiary),
        ),
        SizedBox(height: AppTheme.spacingM),
        Center(
          child: Text(
            message,
            style: AppTheme.textBody.copyWith(color: AppTheme.textTertiary),
          ),
        ),
        SizedBox(height: AppTheme.spacingL),
      ],
    );
  }

  /// 通用卡片容器
  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
    Color? iconColor,
    Widget? action,
  }) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingDefault),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20.sp,
                color: iconColor ?? AppTheme.primaryColor,
              ),
              SizedBox(width: AppTheme.spacingS),
              Text(
                title,
                style: AppTheme.textSubtitle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (action != null) const Spacer(),
              if (action != null) action,
            ],
          ),
          SizedBox(height: AppTheme.spacingM),
          child,
        ],
      ),
    );
  }

  /// 通用按钮
  Widget _buildButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool enabled = true,
  }) {
    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 18.sp),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingDefault,
          vertical: AppTheme.spacingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusDefault),
        ),
      ),
    );
  }

  /// 信息行
  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text('$label: ', style: AppTheme.textCaption),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: AppTheme.textBody.copyWith(
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

/// M1 卡操作组件
class _M1CardOperationWidget extends StatefulWidget {
  final MwCardReaderController controller;

  const _M1CardOperationWidget({required this.controller});

  @override
  State<_M1CardOperationWidget> createState() => _M1CardOperationWidgetState();
}

class _M1CardOperationWidgetState extends State<_M1CardOperationWidget> {
  final _sectorController = TextEditingController(text: '1');
  final _blockController = TextEditingController(text: '4');
  final _pwdController = TextEditingController(text: 'FFFFFFFFFFFF');
  final _dataController = TextEditingController();
  final _valueController = TextEditingController(text: '100');

  int _selectedAuthMode = 0; // 0=KeyA, 1=KeyB

  @override
  void dispose() {
    _sectorController.dispose();
    _blockController.dispose();
    _pwdController.dispose();
    _dataController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 密码验证
        _buildSection('1. 密码验证', [
          Row(
            children: [
              Expanded(child: _buildTextField('扇区号', _sectorController)),
              SizedBox(width: AppTheme.spacingM),
              Expanded(child: _buildTextField('密码(12位)', _pwdController)),
            ],
          ),
          SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Text('密码类型:', style: AppTheme.textBody),
              SizedBox(width: AppTheme.spacingM),
              Radio<int>(
                value: 0,
                groupValue: _selectedAuthMode,
                onChanged: (value) =>
                    setState(() => _selectedAuthMode = value!),
              ),
              Text('KeyA', style: AppTheme.textBody),
              SizedBox(width: AppTheme.spacingM),
              Radio<int>(
                value: 1,
                groupValue: _selectedAuthMode,
                onChanged: (value) =>
                    setState(() => _selectedAuthMode = value!),
              ),
              Text('KeyB', style: AppTheme.textBody),
            ],
          ),
          SizedBox(height: AppTheme.spacingM),
          ElevatedButton(
            onPressed: _onAuthClick,
            child: const Text('验证密码'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ]),

        SizedBox(height: AppTheme.spacingL),

        // 读写操作
        _buildSection('2. 读写操作', [
          _buildTextField('块号', _blockController),
          SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _onReadClick,
                  child: const Text('读取块'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.controller.halt,
                  child: const Text('关闭卡片'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingM),
          _buildTextField('数据(32位十六进制)', _dataController),
          SizedBox(height: AppTheme.spacingM),
          ElevatedButton(
            onPressed: _onWriteClick,
            child: const Text('写入块'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
            ),
          ),
        ]),

        SizedBox(height: AppTheme.spacingL),

        // 值操作
        _buildSection('3. 值操作', [
          _buildTextField('值', _valueController),
          SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _onInitValueClick,
                  child: const Text('初始化值'),
                ),
              ),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: ElevatedButton(
                  onPressed: _onReadValueClick,
                  child: const Text('读取值'),
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _onIncrementClick,
                  child: const Text('增值'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: ElevatedButton(
                  onPressed: _onDecrementClick,
                  child: const Text('减值'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ]),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingDefault),
      decoration: AppTheme.greyContainerDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.textSubtitle.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: AppTheme.spacingM),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusDefault),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
      ),
      style: AppTheme.textBody,
    );
  }

  // 事件处理
  void _onAuthClick() async {
    final sector = int.tryParse(_sectorController.text) ?? 0;
    final pwd = _pwdController.text;
    await widget.controller.mifareAuth(
      mode: _selectedAuthMode,
      sector: sector,
      pwd: pwd,
    );
  }

  void _onReadClick() async {
    final block = int.tryParse(_blockController.text) ?? 0;
    final data = await widget.controller.mifareRead(block);
    if (data != null) {
      _dataController.text = data;
    }
  }

  void _onWriteClick() async {
    final block = int.tryParse(_blockController.text) ?? 0;
    final data = _dataController.text.toUpperCase();
    await widget.controller.mifareWrite(block, data);
  }

  void _onInitValueClick() async {
    final block = int.tryParse(_blockController.text) ?? 0;
    final value = int.tryParse(_valueController.text) ?? 0;
    await widget.controller.mifareInitVal(block, value);
  }

  void _onReadValueClick() async {
    final block = int.tryParse(_blockController.text) ?? 0;
    final value = await widget.controller.mifareReadVal(block);
    if (value != null) {
      _valueController.text = value.toString();
    }
  }

  void _onIncrementClick() async {
    final block = int.tryParse(_blockController.text) ?? 0;
    final value = int.tryParse(_valueController.text) ?? 0;
    await widget.controller.mifareIncrement(block, value);
  }

  void _onDecrementClick() async {
    final block = int.tryParse(_blockController.text) ?? 0;
    final value = int.tryParse(_valueController.text) ?? 0;
    await widget.controller.mifareDecrement(block, value);
  }
}
