import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/modules/sync/webdav/webdav_controller.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';

class WebDavConfigPage extends StatefulWidget {
  const WebDavConfigPage({super.key});

  @override
  State<WebDavConfigPage> createState() => _WebDavConfigPageState();
}

class _WebDavConfigPageState extends State<WebDavConfigPage> {
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<WebDavController>();
    return AppScaffold(
      child: Column(
        children: [
          AppStyle.vGap32,
          Row(
            children: [
              AppStyle.hGap48,
              HighlightButton(
                focusNode: AppFocusNode(),
                autofocus: true,
                iconData: Icons.arrow_back,
                text: "返回",
                onTap: Get.back,
              ),
              AppStyle.hGap32,
              Text(
                "WebDAV账号配置",
                style: AppStyle.titleStyleWhite.copyWith(
                  fontSize: 36.w,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 820.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(
                      controller: _urlController,
                      label: "WebDAV服务器地址",
                      hint: "https://dav.jianguoyun.com/dav/",
                    ),
                    AppStyle.vGap24,
                    _buildTextField(
                      controller: _userController,
                      label: "账号",
                    ),
                    AppStyle.vGap24,
                    Obx(
                      () => _buildTextField(
                        controller: _passwordController,
                        label: "密码",
                        obscureText: controller.passwordVisible.value,
                        suffix: IconButton(
                          icon: Icon(
                            controller.passwordVisible.value
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: controller.changePasswordVisible,
                        ),
                      ),
                    ),
                    AppStyle.vGap32,
                    HighlightButton(
                      focusNode: AppFocusNode(),
                      iconData: Icons.login,
                      text: "登录",
                      onTap: () {
                        controller.doWebDAVLogin(
                          _urlController.text.trim(),
                          _userController.text.trim(),
                          _passwordController.text,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: AppStyle.textStyleWhite.copyWith(fontSize: 28.w),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.w),
        ),
      ),
    );
  }
}
