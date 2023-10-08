import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:url_launcher/url_launcher_string.dart';

class UserPage extends StatelessWidget {
  const UserPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Get.isDarkMode
          ? SystemUiOverlayStyle.light.copyWith(
              systemNavigationBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              systemNavigationBarColor: Colors.transparent,
            ),
      child: SafeArea(
        child: ListView(
          padding: AppStyle.edgeInsetsA4,
          children: [
            AppStyle.vGap12,
            ListTile(
              leading: Image.asset(
                'assets/images/logo.png',
                width: 56,
                height: 56,
              ),
              title: const Text(
                "Simple Live",
                style: TextStyle(height: 1.0),
              ),
              subtitle: const Text("简简单单看直播"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.dialog(AboutDialog(
                  applicationIcon: Image.asset(
                    'assets/images/logo.png',
                    width: 48,
                    height: 48,
                  ),
                  applicationName: "Simple Live",
                  applicationVersion: "简简单单看直播",
                  applicationLegalese: "Ver ${Utils.packageInfo.version}",
                ));
              },
            ),
            Divider(
              indent: 12,
              endIndent: 12,
              color: Colors.grey.withOpacity(.1),
            ),
            _buildCard(
              context,
              children: [
                ListTile(
                  leading: const Icon(Remix.history_line),
                  title: const Text("观看记录"),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Get.toNamed(RoutePath.kHistory);
                  },
                ),
              ],
            ),
            Divider(
              indent: 12,
              endIndent: 12,
              color: Colors.grey.withOpacity(.1),
            ),
            ListTile(
              leading: const Icon(Remix.link),
              title: const Text("链接解析"),
              trailing: const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
              onTap: () {
                Get.toNamed(RoutePath.kTools);
              },
            ),
            Divider(
              indent: 12,
              endIndent: 12,
              color: Colors.grey.withOpacity(.1),
            ),
            _buildCard(
              context,
              children: [
                ListTile(
                  leading:
                      Icon(Get.isDarkMode ? Remix.moon_line : Remix.sun_line),
                  title: const Text("显示主题"),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: Get.find<AppSettingsController>().changeTheme,
                ),
                ListTile(
                  leading: const Icon(Remix.home_2_line),
                  title: const Text("主页设置"),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Get.toNamed(RoutePath.kSettingsIndexed);
                  },
                ),
                ListTile(
                  leading: const Icon(Remix.play_circle_line),
                  title: const Text("播放设置"),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Get.toNamed(RoutePath.kSettingsPlay);
                  },
                ),
                ListTile(
                  leading: const Icon(Remix.text),
                  title: const Text("弹幕设置"),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Get.toNamed(RoutePath.kSettingsDanmu);
                  },
                ),
                ListTile(
                  leading: const Icon(Remix.timer_2_line),
                  title: const Text("定时关闭"),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Get.toNamed(RoutePath.kSettingsAutoExit);
                  },
                ),
              ],
            ),
            Divider(
              indent: 12,
              endIndent: 12,
              color: Colors.grey.withOpacity(.1),
            ),
            _buildCard(
              context,
              children: [
                const ListTile(
                  leading: Icon(Remix.error_warning_line),
                  title: Text("免责声明"),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: Utils.showStatement,
                ),
                ListTile(
                  leading: const Icon(Remix.github_line),
                  title: const Text("开源主页"),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    launchUrlString(
                      "https://github.com/xiaoyaocz/dart_simple_live",
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Remix.upload_2_line),
                  title: const Text("检查更新"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Ver ${Utils.packageInfo.version}"),
                      AppStyle.hGap4,
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  onTap: () {
                    Utils.checkUpdate(showMsg: true);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required List<Widget> children}) {
    return Theme(
      data: Theme.of(context).copyWith(
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(borderRadius: AppStyle.radius8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
