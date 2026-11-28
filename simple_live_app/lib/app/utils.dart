import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/log.dart';

typedef TextValidate = bool Function(String text);

class Utils {
  static late PackageInfo packageInfo;
  static DateFormat dateFormat = DateFormat("MM-dd HH:mm");
  static DateFormat dateFormatWithYear = DateFormat("yyyy-MM-dd HH:mm");
  static DateFormat timeFormat = DateFormat("HH:mm:ss");

  static String playbackQualityLabel(String requested, String? actual) =>
      actual == null || actual.isEmpty || actual == requested
          ? requested
          : '$requested（实播$actual）';

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
    BoxConstraints? constraints,
    double maxContentHeight = 400,
    bool doubleTapConfirm = false,
  }) async {
    PointerDownEvent? pointerDown;
    PointerUpEvent? previousTap;
    var confirmed = false;
    void resetTaps(PointerEvent event) {
      pointerDown = null;
      previousTap = null;
    }

    final dialog = AlertDialog(
      constraints: constraints,
      title: Text(title),
      content: Container(
        constraints: BoxConstraints(maxHeight: maxContentHeight),
        child: SingleChildScrollView(
          child: Padding(
            padding: AppStyle.edgeInsetsV12,
            child: selectable ? SelectableText(content) : Text(content),
          ),
        ),
      ),
      actions:
          [
                ...?actions,
                TextButton(
                  onPressed: (() => Get.back(result: false)),
                  child: Text(cancel.isEmpty ? "取消" : cancel),
                ),
                TextButton(
                  onPressed: (() => Get.back(result: true)),
                  child: Text(confirm.isEmpty ? "确定" : confirm),
                ),
              ]
              .map(
                (action) => doubleTapConfirm
                    ? Listener(onPointerUp: resetTaps, child: action)
                    : action,
              )
              .toList(),
    );
    var result = await Get.dialog(
      doubleTapConfirm
          // 使用原始指针事件，避免链接文字的双击选择手势抢走双击。
          // deferToChild 保证仅弹窗卡片命中，遮罩不触发确认。
          ? Listener(
              onPointerDown: (event) {
                if (event.buttons != kPrimaryButton) {
                  resetTaps(event);
                  return;
                }
                pointerDown = event;
              },
              onPointerMove: (event) {
                if (pointerDown != null &&
                    (event.position - pointerDown!.position).distance >
                        kTouchSlop) {
                  resetTaps(event);
                }
              },
              onPointerCancel: resetTaps,
              onPointerUp: (event) {
                final down = pointerDown;
                pointerDown = null;
                if (confirmed ||
                    down == null ||
                    down.pointer != event.pointer ||
                    event.timeStamp - down.timeStamp > kLongPressTimeout) {
                  previousTap = null;
                  return;
                }
                final previous = previousTap;
                previousTap = event;
                if (previous != null &&
                    down.timeStamp - previous.timeStamp <= kDoubleTapTimeout &&
                    (event.position - previous.position).distance <=
                        kDoubleTapSlop) {
                  confirmed = true;
                  Get.back(result: true);
                }
              },
              child: dialog,
            )
          : dialog,
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

  static void showRightDialog({
    required String title,
    Function()? onDismiss,
    required Widget child,
    double width = 320,
    bool useSystem = false,
  }) {
    showSideDialog(
      title: title,
      onDismiss: onDismiss,
      child: child,
      width: width,
      useSystem: useSystem,
    );
  }

  static void showSideDialog({
    String? title,
    Function()? onDismiss,
    required Widget child,
    double width = 320,
    double Function(BuildContext context)? widthBuilder,
    bool fromLeft = false,
    bool useSystem = false,
    bool showHeader = true,
    Color? maskColor,
    double borderRadius = 4,
    int? surfaceAlpha,
  }) {
    SmartDialog.show(
      alignment: fromLeft ? Alignment.topLeft : Alignment.topRight,
      animationBuilder: (controller, child, animationParam) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: fromLeft ? const Offset(-1, 0) : const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: controller.view,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
      useSystem: useSystem,
      maskColor: maskColor ?? Colors.transparent,
      onDismiss: onDismiss,
      animationTime: const Duration(milliseconds: 200),
      builder: (context) {
        final mediaPadding = MediaQuery.paddingOf(context);
        final edgeInset = fromLeft ? mediaPadding.left : mediaPadding.right;
        final contentWidth = widthBuilder?.call(context) ?? width;
        final theme = Theme.of(context);
        final borderSide = BorderSide(
          color: theme.dividerColor.withAlpha(36),
          width: 0.8,
        );
        final cardSurface = surfaceAlpha != null
            ? theme.cardColor.withAlpha(surfaceAlpha)
            : theme.cardColor;
        return Container(
          width: contentWidth + edgeInset,
          padding: EdgeInsets.only(
            left: fromLeft ? edgeInset : 0,
            right: fromLeft ? 0 : edgeInset,
          ),
          decoration: BoxDecoration(
            color: cardSurface,
            border: fromLeft
                ? Border(right: borderSide)
                : Border(left: borderSide),
            borderRadius: BorderRadius.only(
              topLeft: fromLeft ? Radius.zero : Radius.circular(borderRadius),
              bottomLeft:
                  fromLeft ? Radius.zero : Radius.circular(borderRadius),
              topRight: fromLeft ? Radius.circular(borderRadius) : Radius.zero,
              bottomRight:
                  fromLeft ? Radius.circular(borderRadius) : Radius.zero,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              left: false,
              right: false,
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                removeLeft: true,
                removeRight: true,
                child: showHeader
                    ? Column(
                        children: [
                          ListTile(
                            visualDensity: VisualDensity.compact,
                            contentPadding: EdgeInsets.zero,
                            leading: IconButton(
                              onPressed: () {
                                SmartDialog.dismiss(status: SmartStatus.allCustom);
                              },
                              icon: const Icon(Icons.arrow_back),
                            ),
                            title: Text(
                              title ?? '',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: Colors.grey.withAlpha(25),
                          ),
                          Expanded(child: child),
                        ],
                      )
                    : child,
              ),
            ),
          ),
        );
      },
    );
  }

  static void hideRightDialog() {
    SmartDialog.dismiss(status: SmartStatus.allCustom);
  }

  static Future showBottomSheet({
    required String title,
    required Widget child,
    double maxWidth = 600,
  }) async {
    var result = await showModalBottomSheet(
      context: Get.context!,
      constraints: BoxConstraints(
        maxWidth: maxWidth,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      builder: (_) => Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.only(
              left: 12,
            ),
            title: Text(title),
            trailing: IconButton(
              onPressed: Get.back,
              icon: const Icon(Remix.close_line),
            ),
          ),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
    return result;
  }

  /// 文本编辑的弹窗
  /// - `content` 编辑框默认的内容
  /// - `title` 弹窗标题
  /// - `confirm` 确认按钮内容
  /// - `cancel` 取消按钮内容
  static Future<String?> showEditTextDialog(
    String content, {
    String title = '',
    String? hintText,
    String confirm = '',
    String cancel = '',
    TextValidate? validate,
  }) async {
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
              if (validate != null && !validate(textEditingController.text)) {
                return;
              }

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
      RadioGroup(
        groupValue: value,
        onChanged: (e) {
          Get.back(result: e);
        },
        child: SimpleDialog(
          title: Text(title),
          children: contents
              .map(
                (e) => RadioListTile<T>(
                  title: Text(e.toString()),
                  value: e,
                ),
              )
              .toList(),
        ),
      ),
    );
    return result;
  }

  /// 多段指引用户内容的弹窗
  /// - `content` 内容：可滚动
  /// - `title` 顶部弹窗标题
  /// - `actions` 底部按钮
  static Future<T?> showInformationHelpDialog<T>({
    required List<Widget> content,
    Widget? title,
    List<Widget>? actions,
  }) async {
    var result = await Get.dialog(
      AlertDialog(
        title: title ?? const Text("帮助"),
        scrollable: true,
        content: SingleChildScrollView(child: ListBody(children: content)),
        actions: actions ??
            [
              TextButton(
                onPressed: Get.back,
                child: const Text("确定"),
              ),
            ],
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
      RadioGroup(
        groupValue: value,
        onChanged: (e) {
          Get.back(result: e);
        },
        child: SimpleDialog(
          title: Text(title),
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
    );
    return result;
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
      if (!Platform.isIOS) {
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

  static final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  /// 检查文件权限
  static Future<bool> checkStorgePermission() async {
    try {
      if (!Platform.isAndroid) {
        return true;
      }
      Permission permission = Permission.storage;
      var androidIndo = await deviceInfo.androidInfo;
      if (androidIndo.version.sdkInt >= 33) {
        permission = Permission.manageExternalStorage;
      }

      var status = await permission.status;
      if (status == PermissionStatus.granted) {
        return true;
      }
      status = await permission.request();
      if (status.isGranted) {
        return true;
      } else {
        SmartDialog.showToast(
          "请授予文件访问权限",
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

  /// 复制内容到剪贴板
  static void copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      SmartDialog.showToast("已复制到剪贴板");
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("复制到剪贴板失败: $e");
    }
  }

  /// 获取剪贴板内容
  static Future<String?> getClipboard() async {
    try {
      var content = await Clipboard.getData(Clipboard.kTextPlain);
      if (content == null) {
        SmartDialog.showToast("无法读取剪贴板内容");
        return null;
      }
      return content.text;
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("读取剪切板内容失败：$e");
    }
    return null;
  }

  static bool isRegexFormat(String keyword) {
    return keyword.startsWith('/') &&
        keyword.endsWith('/') &&
        keyword.length > 2;
  }

  static String removeRegexFormat(String keyword) {
    return keyword.substring(1, keyword.length - 1);
  }

  static String parseFileSize(int size) {
    if (size < 1024) {
      return "$size B";
    }
    if (size < 1024 * 1024) {
      return "${(size / 1024).toStringAsFixed(2)} KB";
    }
    if (size < 1024 * 1024 * 1024) {
      return "${(size / 1024 / 1024).toStringAsFixed(2)} MB";
    }
    return "${(size / 1024 / 1024 / 1024).toStringAsFixed(2)} GB";
  }
}
