import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/remote_sync_webdav_controller.dart';
import 'package:simple_live_app/widgets/none_border_circular_textfield.dart';

class RemoteSyncWebDAVConfigPage extends StatefulWidget {
  const RemoteSyncWebDAVConfigPage({super.key});

  @override
  State<RemoteSyncWebDAVConfigPage> createState() =>
      _RemoteSyncWebDAVConfigPageState();
}

class _RemoteSyncWebDAVConfigPageState
    extends State<RemoteSyncWebDAVConfigPage> {
  late TextEditingController _urlController;
  late TextEditingController _userNameController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    _urlController = TextEditingController();
    _userNameController = TextEditingController();
    _passwordController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("WebDAV账号配置"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Utils.showInformationHelpDialog(
                content: [
                  const Text("此功能可以将您的数据备份到 WebDAV 服务器中或者进行数据恢复.\n"),
                  const Text(
                      "WebDAV 服务器地址请以 http:// 或 https:// 开头，如坚果云(点击复制)："),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: InkWell(
                      onTap: () {
                        Clipboard.setData(const ClipboardData(
                            text: "https://dav.jianguoyun.com/dav/"));
                        SmartDialog.showToast("复制成功");
                      },
                      child: const Text("https://dav.jianguoyun.com/dav/"),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: GetX<RemoteSyncWebDAVController>(
        builder: (controller) {
          return SingleChildScrollView(
            child: Padding(
              padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NoneBorderCircularTextField(
                    editingController: _urlController,
                    labelText: "WebDAV服务器地址",
                    hintText: "请以http:// 或 http:// 开头",
                    prefixIcon: const Icon(Icons.public),
                    trailing: InkWell(
                      child: const Icon(
                        Icons.cancel,
                        size: 20,
                      ),
                      onTap: () => _urlController.clear(),
                    ),
                  ),
                  NoneBorderCircularTextField(
                    editingController: _userNameController,
                    labelText: "账号",
                    prefixIcon: const Icon(Icons.account_circle),
                    trailing: InkWell(
                        child: const Icon(
                          Icons.cancel,
                          size: 20,
                        ),
                        onTap: () => _userNameController.clear()),
                  ),
                  NoneBorderCircularTextField(
                    editingController: _passwordController,
                    labelText: "密码",
                    prefixIcon: const Icon(Icons.lock),
                    obscureText: controller.passwordVisible.value,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          child: const Icon(
                            Icons.cancel,
                            size: 20,
                          ),
                          onTap: () => _passwordController.clear(),
                        ),
                        AppStyle.hGap12,
                        InkWell(
                          child: controller.passwordVisible.value
                              ? const Icon(Icons.visibility_off)
                              : const Icon(Icons.visibility),
                          onTap: () {
                            controller.changePasswordVisible();
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 5, bottom: 15),
                    child: MaterialButton(
                      minWidth: double.infinity,
                      color: Theme.of(context).primaryColor,
                      focusElevation: 0,
                      elevation: 0,
                      highlightElevation: 4,
                      height: 40,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8.0)),
                      ),
                      child: const Text(
                        "登录",
                        style: TextStyle(color: Colors.white),
                      ),
                      onPressed: () {
                        controller.doWebDAVLogin(
                          _urlController.text,
                          _userNameController.text,
                          _passwordController.text,
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
