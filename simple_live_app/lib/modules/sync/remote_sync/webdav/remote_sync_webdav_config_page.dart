import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/remote_sync_webdav_controller.dart';
import 'package:simple_live_app/widgets/none_border_circular_textfield.dart';
import 'package:simple_live_app/widgets/ui/after_post_frame.dart';

class RemoteSyncWebDAVConfigPage extends StatefulWidget {
  const RemoteSyncWebDAVConfigPage({super.key});

  @override
  State<RemoteSyncWebDAVConfigPage> createState() =>
      _RemoteSyncWebDAVConfigPageState();
}

class _RemoteSyncWebDAVConfigPageState extends State<RemoteSyncWebDAVConfigPage>
    with AfterFirstFrameMixin {
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
            icon: Icon(Icons.help_outline),
            onPressed: () {},
          )
        ],
      ),
      body: GetX<RemoteSyncWebDAVController>(builder: (controller) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 30,
              right: 30,
              bottom: 32,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NoneBorderCircularTextField(
                  editingController: _urlController,
                  labelText: "WebDAV服务器地址",
                  hintText: "请以http:// 或 http:// 开头",
                  trailing: InkWell(
                    child: Icon(
                      Icons.cancel,
                      size: 20,
                    ),
                    onTap: () => afterFirstFrame(() {
                      _urlController.clear();
                    }),
                  ),
                ),
                NoneBorderCircularTextField(
                  editingController: _userNameController,
                  labelText: "账号",
                  trailing: InkWell(
                    child: Icon(
                      Icons.cancel,
                      size: 20,
                    ),
                    onTap: () => afterFirstFrame(() {
                      _userNameController.clear();
                    }),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: NoneBorderCircularTextField(
                        editingController: _passwordController,
                        labelText: "密码",
                        obscureText: controller.passwordVisible.value,
                        trailing: InkWell(
                          child: Icon(
                            Icons.cancel,
                            size: 20,
                          ),
                          onTap: () => afterFirstFrame(() {
                            _passwordController.clear();
                          }),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 20),
                      child: InkWell(
                        child: controller.passwordVisible.value
                            ? Icon(Icons.visibility_off)
                            : Icon(Icons.visibility),
                        onTap: () {
                          controller.changePasswordVisible();
                        },
                      ),
                    )
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(top: 5, bottom: 15),
                  child: MaterialButton(
                    minWidth: double.infinity,
                    color: Theme.of(context).primaryColor,
                    focusElevation: 0,
                    elevation: 0,
                    highlightElevation: 4,
                    height: 40,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          const BorderRadius.all(Radius.circular(8.0)),
                    ),
                    child: Text(
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
      }),
    );
  }
}
