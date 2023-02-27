import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/requests/common_request.dart';
import 'package:url_launcher/url_launcher_string.dart';

class Utils {
  static late PackageInfo packageInfo;
  static DateFormat dateFormat = DateFormat("MM-dd HH:mm");
  static DateFormat dateFormatWithYear = DateFormat("yyyy-MM-dd HH:mm");

  /// 处理时间
  static String parseTime(DateTime? dt) {
    if (dt == null) {
      return "";
    }

    var dtNow = DateTime.now();
    if (dt.year == dtNow.year &&
        dt.month == dtNow.month &&
        dt.day == dtNow.day) {
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }

    if (dt.year == dtNow.year) {
      return dateFormat.format(dt);
    }

    return dateFormatWithYear.format(dt);
  }

  /// 提示弹窗
  /// - `content` 内容
  /// - `title` 弹窗标题
  /// - `confirm` 确认按钮内容，留空为确定
  /// - `cancel` 取消按钮内容，留空为取消
  static Future<bool> showAlertDialog(
    String content, {
    String title = '',
    String confirm = '',
    String cancel = '',
    bool selectable = false,
    List<Widget>? actions,
  }) async {
    var result = await Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Container(
          constraints: const BoxConstraints(
            maxHeight: 400,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: AppStyle.edgeInsetsV12,
              child: selectable ? SelectableText(content) : Text(content),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: (() => Get.back(result: false)),
            child: Text(cancel.isEmpty ? "取消" : cancel),
          ),
          TextButton(
            onPressed: (() => Get.back(result: true)),
            child: Text(confirm.isEmpty ? "确定" : confirm),
          ),
          ...?actions,
        ],
      ),
    );
    return result ?? false;
  }

  /// 提示弹窗
  /// - `content` 内容
  /// - `title` 弹窗标题
  /// - `confirm` 确认按钮内容，留空为确定
  static Future<bool> showMessageDialog(String content,
      {String title = '', String confirm = '', bool selectable = false}) async {
    var result = await Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Padding(
          padding: AppStyle.edgeInsetsV12,
          child: selectable ? SelectableText(content) : Text(content),
        ),
        actions: [
          TextButton(
            onPressed: (() => Get.back(result: true)),
            child: Text(confirm.isEmpty ? "确定" : confirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 文本编辑的弹窗
  /// - `content` 编辑框默认的内容
  /// - `title` 弹窗标题
  /// - `confirm` 确认按钮内容
  /// - `cancel` 取消按钮内容
  static Future<String?> showEditTextDialog(String content,
      {String title = '',
      String? hintText,
      String confirm = '',
      String cancel = ''}) async {
    final TextEditingController textEditingController =
        TextEditingController(text: content);
    var result = await Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Padding(
          padding: AppStyle.edgeInsetsT12,
          child: TextField(
            controller: textEditingController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              //prefixText: title,
              contentPadding: AppStyle.edgeInsetsA12,
              hintText: hintText ?? title,
            ),
            // style: TextStyle(
            //     height: 1.0,
            //     color: Get.isDarkMode ? Colors.white : Colors.black),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              Get.back(result: textEditingController.text);
            },
            child: const Text("确定"),
          ),
        ],
      ),
      // barrierColor:
      //     Get.isDarkMode ? Colors.grey.withOpacity(.3) : Colors.black38,
    );
    return result;
  }

  static Future<T?> showOptionDialog<T>(
    List<T> contents,
    T value, {
    String title = '',
  }) async {
    var result = await Get.dialog(
      SimpleDialog(
        title: Text(title),
        children: contents
            .map(
              (e) => RadioListTile<T>(
                title: Text(e.toString()),
                value: e,
                groupValue: value,
                onChanged: (e) {
                  Get.back(result: e);
                },
              ),
            )
            .toList(),
      ),
    );
    return result;
  }

  static Future showStatement() async {
    var text = await rootBundle.loadString("assets/statement.txt");

    var result = await showAlertDialog(
      text,
      selectable: true,
      title: "免责声明",
      confirm: "已阅读并同意",
      cancel: "退出",
    );
    if (!result) {
      exit(0);
    }
  }

  static Future<T?> showMapOptionDialog<T>(
    Map<T, String> contents,
    T value, {
    String title = '',
  }) async {
    var result = await Get.dialog(
      SimpleDialog(
        title: Text(title),
        children: contents.keys
            .map(
              (e) => RadioListTile<T>(
                title: Text((contents[e] ?? '-').tr),
                value: e,
                groupValue: value,
                onChanged: (e) {
                  Get.back(result: e);
                },
              ),
            )
            .toList(),
      ),
    );
    return result;
  }

  static void checkUpdate({bool showMsg = false}) async {
    try {
      int currentVer = Utils.parseVersion(packageInfo.version);
      CommonRequest request = CommonRequest();
      var versionInfo = await request.checkUpdate();
      if (versionInfo.versionNum > currentVer) {
        Get.dialog(
          AlertDialog(
            title: Text(
              "发现新版本 ${versionInfo.version}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            content: Text(
              versionInfo.versionDesc,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            actionsPadding: AppStyle.edgeInsetsH12,
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Get.back();
                      },
                      child: const Text("取消"),
                    ),
                  ),
                  AppStyle.hGap12,
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                      ),
                      onPressed: () {
                        launchUrlString(
                          versionInfo.downloadUrl,
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      child: const Text("更新"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      } else {
        if (showMsg) {
          SmartDialog.showToast("当前已经是最新版本了");
        }
      }
    } catch (e) {
      Log.logPrint(e);
      if (showMsg) {
        SmartDialog.showToast("检查更新失败");
      }
    }
  }

  static int parseVersion(String version) {
    var sp = version.split('.');
    var num = "";
    for (var item in sp) {
      num = num + item.padLeft(2, '0');
    }
    return int.parse(num);
  }

  static String onlineToString(int num) {
    if (num >= 10000) {
      return "${(num / 10000.0).toStringAsFixed(1)}万";
    }
    return num.toString();
  }

  /// 检查相册权限
  static Future<bool> checkPhotoPermission() async {
    try {
      if (Platform.isAndroid) {
        return true;
      }
      var status = await Permission.photos.status;
      if (status == PermissionStatus.granted) {
        return true;
      }
      status = await Permission.photos.request();
      if (status.isGranted) {
        return true;
      } else {
        SmartDialog.showToast(
          "请授予相册访问权限",
        );
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  ///16进制颜色转换
  static Color convertHexColor(String hexColor) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 4) {
      hexColor = "00$hexColor";
    }

    if (hexColor.length == 6) {
      var R = int.parse(hexColor.substring(0, 2), radix: 16);
      var G = int.parse(hexColor.substring(2, 4), radix: 16);
      var B = int.parse(hexColor.substring(4, 6), radix: 16);
      return Color.fromARGB(255, R, G, B);
    }
    if (hexColor.length == 8) {
      var A = int.parse(hexColor.substring(0, 2), radix: 16);
      var R = int.parse(hexColor.substring(2, 4), radix: 16);
      var G = int.parse(hexColor.substring(4, 6), radix: 16);
      var B = int.parse(hexColor.substring(6, 8), radix: 16);

      return Color.fromARGB(A, R, G, B);
    }

    return Colors.white;
  }
}
