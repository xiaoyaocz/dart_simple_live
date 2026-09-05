import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_app/services/kuaishou_account_service.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AccountController extends GetxController {
  static const _douyinHomeUrl = "https://www.douyin.com/";
  static const _kuaishouHomeUrl = "https://live.kuaishou.com/";

  final douyinCookieCountdownTick = 0.obs;
  Timer? _douyinCookieCountdownTimer;

  @override
  void onInit() {
    super.onInit();
    _douyinCookieCountdownTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => douyinCookieCountdownTick.value++,
    );
  }

  @override
  void onClose() {
    _douyinCookieCountdownTimer?.cancel();
    super.onClose();
  }

  void bilibiliTap() async {
    if (BiliBiliAccountService.instance.logined.value) {
      var result = await Utils.showAlertDialog("确定要退出哔哩哔哩账号吗？", title: "退出登录");
      if (result) {
        BiliBiliAccountService.instance.logout();
      }
    } else {
      //AppNavigator.toBiliBiliLogin();
      bilibiliLogin();
    }
  }

  void bilibiliLogin() {
    Utils.showBottomSheet(
      title: "登录哔哩哔哩",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Visibility(
            visible: Platform.isAndroid || Platform.isIOS,
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text("Web登录"),
              subtitle: const Text("填写用户名密码登录"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                Get.toNamed(RoutePath.kBiliBiliWebLogin);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text("扫码登录"),
            subtitle: const Text("使用哔哩哔哩APP扫描二维码登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              Get.toNamed(RoutePath.kBiliBiliQRLogin);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("Cookie登录"),
            subtitle: const Text("手动输入Cookie登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              doBiliBiliCookieLogin();
            },
          ),
        ],
      ),
    );
  }

  void doBiliBiliCookieLogin() async {
    var cookie = await Utils.showEditTextDialog(
      "",
      title: "请输入Cookie",
      hintText: "请输入Cookie",
    );
    if (cookie == null || cookie.isEmpty) {
      return;
    }
    BiliBiliAccountService.instance.setCookie(cookie);
    await BiliBiliAccountService.instance.loadUserInfo();
  }

  void douyinTap() async {
    douyinLogin();
  }

  void kuaishouTap() async {
    kuaishouLogin();
  }

  void douyinLogin() {
    final hasCookie = DouyinAccountService.instance.hasCookie.value;
    Utils.showBottomSheet(
      title: "抖音账号",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!Platform.isAndroid && !Platform.isIOS)
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text("浏览器登录后粘贴 Cookie"),
              subtitle: const Text("使用系统浏览器打开抖音，登录后回到这里粘贴完整 Cookie"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Get.back();
                await openDouyinInBrowserThenConfigCookie();
              },
            ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("Cookie登录"),
            subtitle: const Text("手动粘贴自己的 www.douyin.com 完整 Cookie"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              doDouyinCookieConfig();
            },
          ),
          if (hasCookie)
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text("查看当前 Cookie"),
              subtitle: const Text("可直接查看当前保存内容"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                showCurrentDouyinCookie();
              },
            ),
          if (hasCookie)
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text("导出到剪贴板"),
              subtitle: const Text("复制当前 Cookie 文本"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                exportDouyinCookieToClipboard();
              },
            ),
          if (Platform.isAndroid || Platform.isIOS)
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: const Text("从文件导入 Cookie"),
              subtitle: const Text("选择电脑传到手机上的 txt/cookie 文件"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Get.back();
                await importDouyinCookieFromFile();
              },
            ),
          if (DouyinAccountService.instance.hasCookie.value)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text("清除 Cookie"),
              subtitle: const Text("清除后恢复默认 ttwid"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Get.back();
                await clearDouyinCookie();
              },
            ),
        ],
      ),
    );
  }

  Future<void> clearDouyinCookie() async {
    if (DouyinAccountService.instance.hasCookie.value) {
      var result =
          await Utils.showAlertDialog("确定要清除自定义抖音 Cookie 吗？", title: "清除配置");
      if (result) {
        DouyinAccountService.instance.clearCookie();
        douyinCookieCountdownTick.value++;
        SmartDialog.showToast("已清除自定义 Cookie，将使用默认 ttwid");
      }
    }
  }

  void kuaishouLogin() {
    final hasCookie = KuaishouAccountService.instance.hasCookie.value;
    Utils.showBottomSheet(
      title: "快手账号",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (Platform.isAndroid || Platform.isIOS)
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text("Web登录"),
              subtitle: const Text("登录快手网页后自动读取 Cookie"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                kuaishouWebLogin();
              },
            ),
          if (!Platform.isAndroid && !Platform.isIOS)
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text("浏览器登录后粘贴 Cookie"),
              subtitle: const Text("使用系统浏览器打开快手直播，登录后回到这里粘贴完整 Cookie"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Get.back();
                await openKuaishouInBrowserThenConfigCookie();
              },
            ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("Cookie登录"),
            subtitle: const Text("手动粘贴 live.kuaishou.com 完整 Cookie"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              doKuaishouCookieConfig();
            },
          ),
          if (hasCookie)
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text("查看当前 Cookie"),
              subtitle: const Text("可直接查看当前保存内容"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                showCurrentKuaishouCookie();
              },
            ),
          if (hasCookie)
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text("导出到剪贴板"),
              subtitle: const Text("复制当前 Cookie 文本"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                exportKuaishouCookieToClipboard();
              },
            ),
          if (Platform.isAndroid || Platform.isIOS)
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: const Text("从文件导入 Cookie"),
              subtitle: const Text("选择电脑传到手机上的 txt/cookie 文件"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Get.back();
                await importKuaishouCookieFromFile();
              },
            ),
          if (hasCookie)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text("清除 Cookie"),
              subtitle: const Text("清除后快手搜索和弹幕可能受限"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Get.back();
                await clearKuaishouCookie();
              },
            ),
        ],
      ),
    );
  }

  bool get canUseKuaishouWebLogin => Platform.isAndroid || Platform.isIOS;

  void kuaishouWebLogin() {
    Get.toNamed(RoutePath.kKuaishouWebLogin);
  }

  Future<void> clearKuaishouCookie() async {
    if (KuaishouAccountService.instance.hasCookie.value) {
      var result =
          await Utils.showAlertDialog("确定要清除自定义快手 Cookie 吗？", title: "清除配置");
      if (result) {
        KuaishouAccountService.instance.clearCookie();
        SmartDialog.showToast("已清除快手 Cookie");
      }
    }
  }

  void doKuaishouCookieConfig() {
    final account = KuaishouAccountService.instance;
    final cookieController = TextEditingController(text: account.cookie);
    Get.dialog(
      AlertDialog(
        title: const Text("配置快手 Cookie"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "只需粘贴完整 Cookie 或 Request Headers，不需要填写 Kww。应用会优先使用 Cookie 中的 kwfv1 自动生成弹幕签名。",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cookieController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: "Cookie",
                  hintText: "粘贴 live.kuaishou.com 的完整 Cookie",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("取消")),
          TextButton(
            onPressed: () {
              final rawInput = cookieController.text;
              final cookie = _normalizeCookieInput(rawInput);
              final pastedKww = _extractKuaishouKww(rawInput);
              Get.back();
              if (cookie.isEmpty) {
                account.clearCookie();
                SmartDialog.showToast("已清除快手 Cookie");
              } else {
                account.setCookie(cookie, kww: pastedKww);
                final hasKwfv1 = _parseCookieMap(cookie).containsKey("kwfv1");
                SmartDialog.showToast(
                  hasKwfv1 || pastedKww.isNotEmpty
                      ? "快手 Cookie 已保存"
                      : "Cookie 已保存，但缺少 kwfv1，弹幕可能需要重新网页登录",
                );
              }
            },
            child: const Text("确定"),
          ),
        ],
      ),
    ).whenComplete(cookieController.dispose);
  }

  void showCurrentKuaishouCookie() {
    final credentials = _currentKuaishouCredentialsText();
    if (credentials.isEmpty) {
      SmartDialog.showToast("当前没有快手弹幕凭证");
      return;
    }
    Get.dialog(
      AlertDialog(
        title: const Text("当前快手弹幕凭证"),
        content: SingleChildScrollView(child: SelectableText(credentials)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("关闭")),
          TextButton(
            onPressed: () {
              Utils.copyToClipboard(credentials);
              Get.back();
            },
            child: const Text("复制"),
          ),
        ],
      ),
    );
  }

  void exportKuaishouCookieToClipboard() {
    final credentials = _currentKuaishouCredentialsText();
    if (credentials.isEmpty) {
      SmartDialog.showToast("当前没有快手弹幕凭证");
      return;
    }
    Utils.copyToClipboard(credentials);
  }

  Future<void> openKuaishouInBrowserThenConfigCookie() async {
    try {
      final opened = await launchUrlString(
        _kuaishouHomeUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        SmartDialog.showToast("无法打开系统浏览器，请手动打开 live.kuaishou.com 后粘贴 Cookie");
      }
    } catch (_) {
      SmartDialog.showToast("无法打开系统浏览器，请手动打开 live.kuaishou.com 后粘贴 Cookie");
    }
    doKuaishouCookieConfig();
  }

  Future<void> importKuaishouCookieFromFile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        return;
      }
      final file = picked.files.single;
      String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (file.path != null && file.path!.isNotEmpty) {
        content = await File(file.path!).readAsString();
      } else {
        SmartDialog.showToast("无法读取所选文件");
        return;
      }
      final cookie = _normalizeCookieInput(content);
      if (cookie.isEmpty) {
        SmartDialog.showToast("Cookie 文件内容为空");
        return;
      }
      final kww = _extractKuaishouKww(content);
      KuaishouAccountService.instance.setCookie(cookie, kww: kww);
      SmartDialog.showToast("已从文件导入快手 Cookie");
    } catch (e) {
      SmartDialog.showToast("导入 Cookie 失败：$e");
    }
  }

  void showCurrentDouyinCookie() {
    final cookie = DouyinAccountService.instance.cookie;
    if (cookie.isEmpty) {
      SmartDialog.showToast("当前没有自定义抖音 Cookie");
      return;
    }
    Get.dialog(
      AlertDialog(
        title: const Text("当前抖音 Cookie"),
        content: SingleChildScrollView(
          child: SelectableText(cookie),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("关闭"),
          ),
          TextButton(
            onPressed: () {
              Utils.copyToClipboard(cookie);
              Get.back();
            },
            child: const Text("复制"),
          ),
        ],
      ),
    );
  }

  void exportDouyinCookieToClipboard() {
    final cookie = DouyinAccountService.instance.cookie;
    if (cookie.isEmpty) {
      SmartDialog.showToast("当前没有自定义抖音 Cookie");
      return;
    }
    Utils.copyToClipboard(cookie);
  }

  Future<void> openDouyinInBrowserThenConfigCookie() async {
    try {
      final opened = await launchUrlString(
        _douyinHomeUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        SmartDialog.showToast("无法打开系统浏览器，请手动打开 www.douyin.com 后粘贴 Cookie");
      }
    } catch (_) {
      SmartDialog.showToast("无法打开系统浏览器，请手动打开 www.douyin.com 后粘贴 Cookie");
    }
    doDouyinCookieConfig();
  }

  Future<void> importDouyinCookieFromFile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        return;
      }
      final file = picked.files.single;
      String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (file.path != null && file.path!.isNotEmpty) {
        content = await File(file.path!).readAsString();
      } else {
        SmartDialog.showToast("无法读取所选文件");
        return;
      }
      final input = content.trim();
      if (input.isEmpty) {
        SmartDialog.showToast("Cookie 文件内容为空");
        return;
      }
      final cookie = DouyinCookieHelper.normalizeInput(input);
      DouyinAccountService.instance.setCookie(cookie);
      douyinCookieCountdownTick.value++;
      if (DouyinCookieHelper.isOnlyTtwid(cookie)) {
        SmartDialog.showToast("已导入 ttwid；搜索仍可能需要完整登录 Cookie");
      } else {
        SmartDialog.showToast("已从文件导入抖音 Cookie");
      }
    } catch (e) {
      SmartDialog.showToast("导入 Cookie 失败：$e");
    }
  }

  void doDouyinCookieConfig() {
    // 兼容旧版只保存 ttwid 的配置。
    var savedCookie = DouyinAccountService.instance.cookie;
    var displayText = savedCookie;
    if (savedCookie.startsWith('ttwid=') && !savedCookie.contains(";")) {
      displayText = savedCookie.substring(6);
    }
    var controller = TextEditingController(text: displayText);
    final expiryText = ValueNotifier(_getDouyinCookieExpiryText(displayText));
    void updateExpiryText() {
      expiryText.value = _getDouyinCookieExpiryText(controller.text);
    }

    controller.addListener(updateExpiryText);
    final timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => updateExpiryText(),
    );

    Get.dialog(
      AlertDialog(
        title: const Text("配置抖音 Cookie"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "默认内置 ttwid 可用于播放；房间名/主播名搜索被要求登录时，不能只填 ttwid，需要粘贴登录后的完整 www.douyin.com Cookie。",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              const Text(
                "电脑端获取方式：F12 打开开发者工具，在 Network 里点 www.douyin.com 或 live.douyin.com 的请求，复制 Request Headers 里的 Cookie 整行；也可以粘贴请求标头整段，应用会自动提取 Cookie。",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "搜索请粘贴完整 Cookie；只填 ttwid 只能作为播放兜底",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<String>(
                valueListenable: expiryText,
                builder: (context, value, child) {
                  return Text(
                    value,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  );
                },
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  var defaultValue = DouyinSite.kDefaultCookie;
                  if (defaultValue.startsWith('ttwid=')) {
                    defaultValue = defaultValue.substring(6);
                  }
                  controller.text = defaultValue;
                  updateExpiryText();
                },
                icon: const Icon(Icons.restore),
                label: const Text("恢复默认 ttwid"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              var input = controller.text.trim();
              Get.back();
              if (input.isEmpty) {
                DouyinAccountService.instance.clearCookie();
                douyinCookieCountdownTick.value++;
                SmartDialog.showToast("已清除自定义 Cookie，将使用默认 ttwid");
              } else {
                var cookie = DouyinCookieHelper.normalizeInput(input);
                DouyinAccountService.instance.setCookie(cookie);
                douyinCookieCountdownTick.value++;
                if (DouyinCookieHelper.isOnlyTtwid(cookie)) {
                  SmartDialog.showToast("已保存 ttwid；搜索仍可能需要完整登录 Cookie");
                } else {
                  SmartDialog.showToast("抖音 Cookie 已保存");
                }
              }
            },
            child: const Text("确定"),
          ),
        ],
      ),
    ).whenComplete(() {
      timer.cancel();
      controller.removeListener(updateExpiryText);
      controller.dispose();
      expiryText.dispose();
    });
  }

  String getDouyinCookieSummaryText() {
    douyinCookieCountdownTick.value;
    DouyinAccountService.instance.hasCookie.value;
    final cookie = DouyinAccountService.instance.cookie;
    if (cookie.isEmpty) {
      return "使用默认 ttwid，搜索受限时可配置完整 Cookie";
    }
    final expiry = _parseDouyinCookieExpiry(cookie);
    if (expiry == null) {
      return "已自定义（${cookie.length} 字符），有效期无法判断";
    }
    final remain = expiry.difference(DateTime.now());
    if (remain.isNegative) {
      return "已自定义（${cookie.length} 字符），可解析有效期已过";
    }
    return "已自定义（${cookie.length} 字符），预计剩余 ${_formatDurationShort(remain)}";
  }

  String _getDouyinCookieExpiryText(String input) {
    final cookie =
        (DouyinCookieHelper.extractCookieFromHeaderText(input) ?? input).trim();
    if (cookie.isEmpty) {
      return "当前使用默认 ttwid，无法判断搜索登录态有效期。";
    }
    if (DouyinCookieHelper.isOnlyTtwid(
        DouyinCookieHelper.normalizeInput(cookie))) {
      return "当前仅为 ttwid，无法判断搜索登录态有效期；主播 / 房间搜索仍可能需要完整 Cookie。";
    }

    final expiry = _parseDouyinCookieExpiry(cookie);
    if (expiry == null) {
      return "未从 Cookie 中解析到到期时间；Request Headers 不包含标准 Expires，实际有效期以抖音服务端为准。";
    }

    final remain = expiry.difference(DateTime.now());
    final expireAt = _formatDateTimeMinute(expiry);
    if (remain.isNegative) {
      return "可解析到期时间已过：$expireAt；如果搜索失败，请重新获取 Cookie。";
    }
    return "Cookie 预计剩余 ${_formatDurationShort(remain)}，到期时间 $expireAt；退出登录、改密或风控可能提前失效。";
  }

  DateTime? _parseDouyinCookieExpiry(String input) {
    final cookie =
        (DouyinCookieHelper.extractCookieFromHeaderText(input) ?? input).trim();
    final cookieMap = _parseCookieMap(cookie);
    final sidGuard = cookieMap["sid_guard"];
    if (sidGuard == null || sidGuard.isEmpty) {
      return null;
    }

    final decoded = _decodeCookieComponent(sidGuard);
    final parts = decoded.split("|");
    if (parts.length >= 3) {
      final loginTime = int.tryParse(parts[1]);
      final maxAgeSeconds = int.tryParse(parts[2]);
      if (loginTime != null && maxAgeSeconds != null) {
        final loginAt = loginTime > 1000000000000
            ? DateTime.fromMillisecondsSinceEpoch(loginTime, isUtc: true)
            : DateTime.fromMillisecondsSinceEpoch(
                loginTime * 1000,
                isUtc: true,
              );
        return loginAt.add(Duration(seconds: maxAgeSeconds)).toLocal();
      }
    }

    if (parts.length >= 4) {
      return _tryParseCookieDate(parts[3]);
    }

    return null;
  }

  Map<String, String> _parseCookieMap(String cookie) {
    final result = <String, String>{};
    for (final part in cookie.split(";")) {
      final item = part.trim();
      if (item.isEmpty) {
        continue;
      }
      final separatorIndex = item.indexOf("=");
      if (separatorIndex <= 0) {
        continue;
      }
      final key = item.substring(0, separatorIndex).trim();
      final value = item.substring(separatorIndex + 1).trim();
      if (key.isNotEmpty) {
        result[key] = value;
      }
    }
    return result;
  }

  String getKuaishouCookieSummaryText() {
    douyinCookieCountdownTick.value;
    final account = KuaishouAccountService.instance;
    account.hasCookie.value;
    final cookie = account.cookie;
    if (cookie.isEmpty) {
      return "建议配置 Cookie，用于搜索和弹幕";
    }
    final expiry = account.cookieExpiresAt;
    if (expiry == null) {
      return "已配置 Cookie（${cookie.length} 字符），有效期无法判断";
    }
    final remain = expiry.difference(DateTime.now());
    if (remain.isNegative) {
      return "已配置 Cookie（${cookie.length} 字符），预计有效期已过";
    }
    return "已配置 Cookie（${cookie.length} 字符），预计剩余 ${_formatDurationShort(remain)}";
  }

  String _currentKuaishouCredentialsText() {
    final cookie = KuaishouAccountService.instance.cookie;
    return cookie.isEmpty ? "" : "Cookie: $cookie";
  }

  String _extractKuaishouKww(String input) {
    for (final line in input.trim().split(RegExp(r'\r?\n'))) {
      final item = line.trim();
      final lower = item.toLowerCase();
      for (final name in const ["kww", "kwfv1"]) {
        if (lower.startsWith("$name:") || lower.startsWith("$name=")) {
          return item.substring(name.length + 1).trim();
        }
      }
    }
    return "";
  }

  String _normalizeCookieInput(String input) {
    final text = input.trim();
    if (text.isEmpty) {
      return "";
    }
    final lines = text.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      final item = line.trim();
      final lower = item.toLowerCase();
      if (lower.startsWith("cookie:")) {
        return item.substring(item.indexOf(":") + 1).trim();
      }
    }
    return text;
  }

  String _decodeCookieComponent(String value) {
    try {
      return Uri.decodeQueryComponent(value);
    } catch (_) {
      try {
        return Uri.decodeComponent(value);
      } catch (_) {
        return value;
      }
    }
  }

  DateTime? _tryParseCookieDate(String value) {
    final normalized = value.replaceAll("+", " ").replaceAll("-", " ");
    try {
      return HttpDate.parse(normalized).toLocal();
    } catch (_) {
      return DateTime.tryParse(normalized)?.toLocal();
    }
  }

  String _formatDurationShort(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    if (days > 0) {
      return "$days 天 $hours 小时";
    }
    if (hours > 0) {
      return "$hours 小时 $minutes 分钟";
    }
    return "${duration.inMinutes} 分钟";
  }

  String _formatDateTimeMinute(DateTime dateTime) {
    String twoDigits(int value) => value.toString().padLeft(2, "0");
    return "${dateTime.year}-${twoDigits(dateTime.month)}-${twoDigits(dateTime.day)} "
        "${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}";
  }
}
