import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_style.dart';

typedef TextValidate = bool Function(String text);

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
        shape: RoundedRectangleBorder(
          borderRadius: AppStyle.radius16,
        ),
        titlePadding: AppStyle.edgeInsetsA24.copyWith(left: 48.w, right: 48.w),
        contentPadding:
            AppStyle.edgeInsetsA24.copyWith(left: 48.w, right: 48.w),
        insetPadding: AppStyle.edgeInsetsA16,
        actionsPadding: AppStyle.edgeInsetsA16,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Get.theme.cardColor,
        title: Text(
          title,
          style: AppStyle.titleStyleWhite,
        ),
        content: Padding(
          padding: AppStyle.edgeInsetsV12,
          child: selectable
              ? SelectableText(
                  content,
                  style: AppStyle.textStyleWhite,
                )
              : Text(
                  content,
                  style: AppStyle.textStyleWhite,
                ),
        ),
        actions: [
          TextButton(
            onPressed: (() => Get.back(result: false)),
            child: Text(
              cancel.isEmpty ? "取消" : cancel,
              style: AppStyle.textStyleWhite,
            ),
          ),
          TextButton(
            autofocus: true,
            onPressed: (() => Get.back(result: true)),
            child: Text(
              confirm.isEmpty ? "确定" : confirm,
              style: AppStyle.textStyleWhite,
            ),
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
  static Future<String?> showEditTextDialog(
    String content, {
    String title = '',
    String? hintText,
    String confirm = '',
    String cancel = '',
    TextValidate? validate,
  }) async {
    final textEditingController = TextEditingController(text: content);
    var result = await Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppStyle.radius16,
        ),
        titlePadding: AppStyle.edgeInsetsA24.copyWith(left: 48.w, right: 48.w),
        contentPadding:
            AppStyle.edgeInsetsA24.copyWith(left: 48.w, right: 48.w),
        insetPadding: AppStyle.edgeInsetsA16,
        actionsPadding: AppStyle.edgeInsetsA16,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Get.theme.cardColor,
        title: Text(
          title,
          style: AppStyle.titleStyleWhite,
        ),
        content: Padding(
          padding: AppStyle.edgeInsetsV12,
          child: SizedBox(
            width: 560.w,
            child: TextField(
              controller: textEditingController,
              autofocus: true,
              style: AppStyle.textStyleWhite,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                contentPadding: AppStyle.edgeInsetsA12,
                hintText: hintText ?? title,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              cancel.isEmpty ? "取消" : cancel,
              style: AppStyle.textStyleWhite,
            ),
          ),
          TextButton(
            onPressed: () {
              if (validate != null && !validate(textEditingController.text)) {
                return;
              }
              Get.back(result: textEditingController.text);
            },
            child: Text(
              confirm.isEmpty ? "确定" : confirm,
              style: AppStyle.textStyleWhite,
            ),
          ),
        ],
      ),
    );
    return result;
  }

  static Future<T?> showOptionDialog<T>(
    List<T> contents,
    T value, {
    String title = '',
    Widget Function(T value)? titleBuilder,
    Widget Function(T value)? subtitleBuilder,
  }) async {
    var result = await Get.dialog(
      AlertDialog(
        title: Text(title),
        content: RadioGroup(
          onChanged: (e) => Get.back(result: e),
          groupValue: value,
          child: Column(
            children: contents
                .map(
                  (e) => RadioListTile<T>(
                    title: titleBuilder?.call(e) ?? Text(e.toString()),
                    subtitle: subtitleBuilder?.call(e),
                    value: e,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    return result;
  }

  static Future<T?> showMapOptionDialog<T>(
    Map<T, String> contents,
    T value, {
    String title = '',
  }) async {
    var result = await Get.dialog(
      AlertDialog(
        title: Text(title),
        content: RadioGroup(
          onChanged: (e) => Get.back(result: e),
          groupValue: value,
          child: Column(
            children: contents.keys
                .map(
                  (e) => RadioListTile<T>(
                    title: Text((contents[e] ?? '-').tr),
                    value: e,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    return result;
  }

  static bool isRegexFormat(String keyword) {
    return keyword.startsWith('/') &&
        keyword.endsWith('/') &&
        keyword.length > 2;
  }

  static String removeRegexFormat(String keyword) {
    return keyword.substring(1, keyword.length - 1);
  }

  static void showRightDialog({
    Function()? onDismiss,
    required Widget child,
    double width = 320,
    bool useSystem = false,
  }) {
    SmartDialog.show(
      alignment: Alignment.topRight,
      animationBuilder: (controller, child, animationParam) {
        //从右到左
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(controller.view),
          child: child,
        );
      },
      useSystem: useSystem,
      maskColor: Colors.transparent,
      animationTime: const Duration(milliseconds: 200),
      builder: (context) => Container(
        width: width,
        decoration: BoxDecoration(
          color: Get.theme.cardColor,
        ),
        child: child,
      ),
    );
  }

  static Future<void> showSystemRightDialog({
    Function()? onDismiss,
    required Widget child,
    double width = 320,
  }) {
    return Get.dialog(
      Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: Align(
          alignment: Alignment.topRight,
          child: Container(
            width: width,
            decoration: BoxDecoration(
              color: Get.theme.cardColor,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  static void hideRightDialog() {
    SmartDialog.dismiss(status: SmartStatus.allCustom);
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
}
