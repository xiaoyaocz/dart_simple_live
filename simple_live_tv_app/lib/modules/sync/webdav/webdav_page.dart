import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/modules/sync/webdav/webdav_controller.dart';
import 'package:simple_live_tv_app/routes/route_path.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_list_tile.dart';

class WebDavPage extends GetView<WebDavController> {
  const WebDavPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                "WebDAV",
                style: AppStyle.titleStyleWhite.copyWith(
                  fontSize: 36.w,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          AppStyle.vGap48,
          Expanded(
            child: SizedBox(
              width: 900.w,
              child: Obx(
                () => ListView(
                  padding: AppStyle.edgeInsetsA24,
                  children: controller.notLogin.value
                      ? [
                          HighlightListTile(
                            focusNode: AppFocusNode(),
                            title: "登录 WebDAV",
                            subtitle: "配置服务器地址、账号和密码",
                            leading: const Icon(Icons.login),
                            onTap: () {
                              Get.toNamed(RoutePath.kWebDAVConfig);
                            },
                          ),
                        ]
                      : [
                          HighlightListTile(
                            focusNode: AppFocusNode(),
                            title: "已登录",
                            subtitle: controller.user.value,
                            leading: const Icon(Icons.cloud_done_outlined),
                            trailing: const Icon(Icons.logout),
                            onTap: controller.onLogout,
                          ),
                          AppStyle.vGap16,
                          HighlightListTile(
                            focusNode: AppFocusNode(),
                            title: "上传完整备份",
                            subtitle: "上次上传：${controller.lastUploadTime.value}",
                            leading: const Icon(Icons.cloud_upload_outlined),
                            onTap: controller.doWebDAVUpload,
                          ),
                          AppStyle.vGap16,
                          HighlightListTile(
                            focusNode: AppFocusNode(),
                            title: "恢复完整备份",
                            subtitle:
                                "上次恢复：${controller.lastRecoverTime.value}",
                            leading: const Icon(Icons.cloud_download_outlined),
                            onTap: controller.doWebDAVRecovery,
                          ),
                          AppStyle.vGap32,
                          Text(
                            "恢复项目",
                            style: AppStyle.titleStyleWhite
                                .copyWith(fontSize: 28.w),
                          ),
                          AppStyle.vGap16,
                          _SwitchTile(
                            title: "关注列表",
                            icon: Icons.favorite_border,
                            value: controller.isSyncFollows,
                            onTap: controller.changeIsSyncFollows,
                          ),
                          _SwitchTile(
                            title: "观看历史",
                            icon: Icons.history,
                            value: controller.isSyncHistories,
                            onTap: controller.changeIsSyncHistories,
                          ),
                          _SwitchTile(
                            title: "屏蔽词",
                            icon: Icons.shield_outlined,
                            value: controller.isSyncBlockWord,
                            onTap: controller.changeIsSyncBlockWord,
                          ),
                          _SwitchTile(
                            title: "哔哩哔哩账号",
                            icon: Icons.account_circle_outlined,
                            value: controller.isSyncBilibiliAccount,
                            onTap: controller.changeIsSyncBilibiliAccount,
                          ),
                          _SwitchTile(
                            title: "抖音账号",
                            icon: Icons.account_circle,
                            value: controller.isSyncDouyinAccount,
                            onTap: controller.changeIsSyncDouyinAccount,
                          ),
                          _SwitchTile(
                            title: "快手账号",
                            icon: Icons.account_circle_outlined,
                            value: controller.isSyncKuaishouAccount,
                            onTap: controller.changeIsSyncKuaishouAccount,
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
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final RxBool value;
  final VoidCallback onTap;

  const _SwitchTile({
    required this.title,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppStyle.edgeInsetsV8,
      child: Obx(
        () => HighlightListTile(
          focusNode: AppFocusNode(),
          title: title,
          leading: Icon(icon),
          trailing:
              Icon(value.value ? Icons.check_circle : Icons.circle_outlined),
          onTap: onTap,
        ),
      ),
    );
  }
}
