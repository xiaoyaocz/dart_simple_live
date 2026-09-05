import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/routes/app_navigation.dart';
import 'package:simple_live_tv_app/services/bilibili_account_service.dart';
import 'package:simple_live_tv_app/services/douyin_account_service.dart';
import 'package:simple_live_tv_app/services/kuaishou_account_service.dart';
import 'package:simple_live_tv_app/services/signalr_service.dart';

class SettingsController extends BaseController
    with GetTickerProviderStateMixin {
  late TabController tabController;
  var tabIndex = 0.obs;

  SettingsController() {
    tabController = TabController(length: 5, vsync: this);
    tabController.animation?.addListener(() {
      var currentIndex = (tabController.animation?.value ?? 0).round();
      if (tabIndex.value == currentIndex) {
        return;
      }
      tabIndex.value = currentIndex;
      if (tabIndex.value == 0) {
        hardwareDecodeFocusNode.requestFocus();
      }
      if (tabIndex.value == 1) {
        danmakuFoucsNode.requestFocus();
      }
      if (tabIndex.value == 2) {
        autoUpdateFollowEnableFocusNode.requestFocus();
      }
      if (tabIndex.value == 3) {
        bilibiliFoucsNode.requestFocus();
      }
      if (tabIndex.value == 4) {
        versionFocusNode.requestFocus();
      }
    });
  }
  var hardwareDecodeFocusNode = AppFocusNode()..isFoucsed.value = true;
  var compatibleModeFocusNode = AppFocusNode();
  var mpvProfileFocusNode = AppFocusNode();
  var scaleFoucsNode = AppFocusNode();
  var defaultQualityFocusNode = AppFocusNode();
  var danmakuFoucsNode = AppFocusNode();
  var danmakuSizeFoucsNode = AppFocusNode();
  var danmakuEmojiFoucsNode = AppFocusNode();
  var danmakuSpeedFoucsNode = AppFocusNode();
  var danmakuAreaFoucsNode = AppFocusNode();
  var danmakuOpacityFoucsNode = AppFocusNode();
  var danmakuStorkeFoucsNode = AppFocusNode();
  var liveEventFlowFoucsNode = AppFocusNode();
  var liveEventFlowOverlayFoucsNode = AppFocusNode();
  var liveEventFlowWindowFoucsNode = AppFocusNode();
  var liveEventFlowDisplayFoucsNode = AppFocusNode();
  var liveEventFlowMinCountFoucsNode = AppFocusNode();
  var danmakuDedupeFoucsNode = AppFocusNode();
  var danmakuDedupeModeFoucsNode = AppFocusNode();
  var danmakuDedupeWindowFoucsNode = AppFocusNode();
  var danmakuDedupeStepFoucsNode = AppFocusNode();

  var autoUpdateFollowEnableFocusNode = AppFocusNode();
  var autoUpdateFollowDurationFocusNode = AppFocusNode();
  var updateFollowThreadFocusNode = AppFocusNode();
  var followPageSizeFocusNode = AppFocusNode();
  var bilibiliFoucsNode = AppFocusNode();
  var versionFocusNode = AppFocusNode();

  void editSyncServerUrl() async {
    final customUrl = SignalRService.configuredServerOption ==
            SignalRService.kCustomServerOption
        ? SignalRService.configuredUrl
        : "";
    final optionUrls = <String, String>{
      SignalRService.kDefaultServerOption: SignalRService.kDefaultUrl,
      SignalRService.kCloudflareServerOption: SignalRService.kCloudflareUrl,
      SignalRService.kCustomServerOption: customUrl,
    };
    final probeResults = <String, ValueNotifier<SyncServerProbeResult?>>{
      for (final entry in optionUrls.entries)
        entry.key: ValueNotifier(
          entry.value.isEmpty
              ? const SyncServerProbeResult.notConfigured()
              : null,
        ),
    };
    for (final entry in optionUrls.entries) {
      if (entry.value.isEmpty) {
        continue;
      }
      SignalRService.probeServer(
        entry.value,
      ).then((result) => probeResults[entry.key]!.value = result);
    }

    final option = await Utils.showOptionDialog<String>(
      SignalRService.kServerOptions,
      SignalRService.configuredServerOption,
      title: "选择同步服务",
      titleBuilder: (value) => _buildSyncServerOptionTitle(
        value,
        probeResults[value]!,
      ),
      subtitleBuilder: (value) => Text(
        _syncServerOptionDescription(value, optionUrls[value]!),
      ),
    );
    if (option == null) {
      return;
    }
    if (option == SignalRService.kDefaultServerOption) {
      await SignalRService.setConfiguredUrl("");
      SmartDialog.showToast("已切换到自建服务器");
    } else if (option == SignalRService.kCloudflareServerOption) {
      await SignalRService.setConfiguredUrl(SignalRService.kCloudflareUrl);
      SmartDialog.showToast("已切换到 Cloudflare Worker");
    } else {
      final saved = await _editCustomSyncServerUrl();
      if (!saved) {
        return;
      }
    }
    update();
  }

  Widget _buildSyncServerOptionTitle(
    String option,
    ValueNotifier<SyncServerProbeResult?> probeResult,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            option,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<SyncServerProbeResult?>(
          valueListenable: probeResult,
          builder: (context, result, _) {
            if (result == null) {
              return const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 6),
                  Text("检测中"),
                ],
              );
            }
            final color = result.isReachable
                ? Colors.green
                : result.label == "未配置"
                    ? Theme.of(context).textTheme.bodySmall?.color
                    : Colors.red;
            return Text(
              result.label,
              style: TextStyle(color: color),
            );
          },
        ),
      ],
    );
  }

  String _syncServerOptionDescription(String option, String url) {
    if (option == SignalRService.kDefaultServerOption) {
      return "$url\n默认直连；设置代理后使用代理";
    }
    if (option == SignalRService.kCloudflareServerOption) {
      return "$url\n备用服务，部分网络需要代理";
    }
    final address = url.isEmpty ? "选择后填写 ws:// 或 wss:// 地址" : url;
    return "$address\n按当前同步代理设置检测";
  }

  Future<bool> _editCustomSyncServerUrl() async {
    final current = SignalRService.configuredServerOption ==
            SignalRService.kCustomServerOption
        ? SignalRService.configuredUrl
        : "";
    final value = await Utils.showEditTextDialog(
      current,
      title: "自定义同步服务",
      hintText: "wss://example.com/sync",
      validate: (text) {
        if (!SignalRService.isValidServerUrl(text)) {
          SmartDialog.showToast("请输入 ws:// 或 wss:// 开头的同步服务地址");
          return false;
        }
        return true;
      },
    );
    if (value == null) {
      return false;
    }
    await SignalRService.setConfiguredUrl(value);
    SmartDialog.showToast("已保存自定义同步服务");
    return true;
  }

  void editSyncProxyUrl() async {
    var value = await Utils.showEditTextDialog(
      SignalRService.configuredProxyUrl,
      title: "同步代理地址",
      hintText: "留空直连，例如 192.168.1.2:51888",
      validate: (text) {
        final value = text.trim();
        if (!SignalRService.isValidProxyConfig(value)) {
          SmartDialog.showToast(
            "请输入 host:port、http://host:port，或 direct 直连",
          );
          return false;
        }
        return true;
      },
    );
    if (value == null) {
      return;
    }
    await SignalRService.setConfiguredProxyUrl(value);
    SmartDialog.showToast(value.trim().isEmpty ? "已切换为直连" : "已保存");
    update();
  }

  void bilibiliTap() async {
    if (BiliBiliAccountService.instance.logined.value) {
      var result = await Utils.showAlertDialog("确定要退出哔哩哔哩账号吗？", title: "退出登录");
      if (result) {
        BiliBiliAccountService.instance.logout();
      }
    } else {
      AppNavigator.toBiliBiliLogin();
    }
  }

  void douyinTap() async {
    final hasCookie = DouyinAccountService.instance.hasCookie.value;
    final action = await Utils.showOptionDialog<String>(
      [
        "编辑或导入 Cookie",
        if (hasCookie) "查看当前 Cookie",
        if (hasCookie) "导出到剪贴板",
        if (hasCookie) "清除 Cookie",
      ],
      "编辑或导入 Cookie",
      title: "抖音账号",
    );
    switch (action) {
      case "编辑或导入 Cookie":
        await _editDouyinCookie();
        break;
      case "查看当前 Cookie":
        await _showCurrentDouyinCookie();
        break;
      case "导出到剪贴板":
        await _exportDouyinCookieToClipboard();
        break;
      case "清除 Cookie":
        await _clearDouyinCookie();
        break;
      default:
        break;
    }
  }

  Future<void> _editDouyinCookie() async {
    final current = DouyinAccountService.instance.cookie;
    final value = await Utils.showEditTextDialog(
      current,
      title: "抖音 Cookie",
      hintText: "粘贴完整 Cookie，留空则恢复默认 ttwid",
    );
    if (value == null) {
      return;
    }
    final input = value.trim();
    if (input.isEmpty) {
      DouyinAccountService.instance.clearCookie();
      SmartDialog.showToast("已清除自定义抖音 Cookie");
      update();
      return;
    }
    final cookie = DouyinCookieHelper.normalizeInput(input);
    DouyinAccountService.instance.setCookie(cookie);
    SmartDialog.showToast(
      DouyinCookieHelper.hasFullCookie(cookie) ? "抖音 Cookie 已保存" : "已保存 ttwid",
    );
    update();
  }

  Future<void> _showCurrentDouyinCookie() async {
    final cookie = DouyinAccountService.instance.cookie;
    if (cookie.isEmpty) {
      SmartDialog.showToast("当前没有自定义抖音 Cookie");
      return;
    }
    await Utils.showMessageDialog(
      cookie,
      title: "当前抖音 Cookie",
      selectable: true,
    );
  }

  Future<void> _exportDouyinCookieToClipboard() async {
    final cookie = DouyinAccountService.instance.cookie;
    if (cookie.isEmpty) {
      SmartDialog.showToast("当前没有自定义抖音 Cookie");
      return;
    }
    await Clipboard.setData(ClipboardData(text: cookie));
    SmartDialog.showToast("已复制当前抖音 Cookie");
  }

  Future<void> _clearDouyinCookie() async {
    final confirmed = await Utils.showAlertDialog(
      "确定要清除自定义抖音 Cookie 吗？",
      title: "清除配置",
    );
    if (!confirmed) {
      return;
    }
    DouyinAccountService.instance.clearCookie();
    SmartDialog.showToast("已清除自定义抖音 Cookie");
    update();
  }

  Future<void> kuaishouTap() async {
    final account = KuaishouAccountService.instance;
    final action = await Utils.showOptionDialog<String>(
      [
        "编辑或导入 Cookie",
        if (account.hasCookie.value) "查看当前 Cookie",
        if (account.hasCookie.value) "导出到剪贴板",
        if (account.hasCookie.value) "清除 Cookie",
      ],
      "编辑或导入 Cookie",
      title: "快手账号",
    );
    switch (action) {
      case "编辑或导入 Cookie":
        await _editKuaishouCookie();
        break;
      case "查看当前 Cookie":
        await _showKuaishouCookie();
        break;
      case "导出到剪贴板":
        await _exportKuaishouCookie();
        break;
      case "清除 Cookie":
        await _clearKuaishouCookie();
        break;
      default:
        break;
    }
  }

  Future<void> _editKuaishouCookie() async {
    final account = KuaishouAccountService.instance;
    final value = await Utils.showEditTextDialog(
      account.cookie,
      title: "快手 Cookie",
      hintText: "粘贴 live.kuaishou.com 完整 Cookie，可另附 kwfv1/kww",
    );
    if (value == null) {
      return;
    }
    final input = value.trim();
    if (input.isEmpty) {
      account.clearCookie();
      SmartDialog.showToast("已清除自定义快手 Cookie");
      update();
      return;
    }
    final cookie = _normalizeKuaishouCookie(input);
    if (cookie.isEmpty) {
      SmartDialog.showToast("未识别到有效快手 Cookie");
      return;
    }
    final kww = _extractKuaishouKww(input);
    account.setCookie(cookie, kww: kww.isEmpty ? null : kww);
    SmartDialog.showToast(
      kww.isNotEmpty || cookie.contains("kwfv1=")
          ? "快手 Cookie 已保存"
          : "Cookie 已保存，但缺少 kwfv1，弹幕可能受限",
    );
    update();
  }

  Future<void> _showKuaishouCookie() async {
    final account = KuaishouAccountService.instance;
    if (account.cookie.isEmpty) {
      SmartDialog.showToast("当前没有自定义快手 Cookie");
      return;
    }
    await Utils.showMessageDialog(
      "Cookie: ${account.cookie}\n"
      "kww: ${account.kww}",
      title: "当前快手凭证",
      selectable: true,
    );
  }

  Future<void> _exportKuaishouCookie() async {
    final account = KuaishouAccountService.instance;
    if (account.cookie.isEmpty) {
      SmartDialog.showToast("当前没有自定义快手 Cookie");
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: "Cookie: ${account.cookie}\nkww: ${account.kww}"),
    );
    SmartDialog.showToast("已复制当前快手凭证");
  }

  Future<void> _clearKuaishouCookie() async {
    final confirmed = await Utils.showAlertDialog(
      "确定要清除自定义快手 Cookie 吗？",
      title: "清除配置",
    );
    if (!confirmed) {
      return;
    }
    KuaishouAccountService.instance.clearCookie();
    SmartDialog.showToast("已清除自定义快手 Cookie");
    update();
  }

  String _normalizeKuaishouCookie(String input) {
    final lines = input.split(RegExp(r"\r?\n"));
    for (final line in lines) {
      var value = line.trim();
      if (value.toLowerCase().startsWith("cookie:")) {
        value = value.substring("cookie:".length).trim();
      }
      if (value.contains("=") &&
          (value.contains(";passToken=") ||
              value.contains(";kuaishou.live") ||
              value.contains(";kwfv1="))) {
        return value.replaceAll(RegExp(r";+$"), "");
      }
    }
    return input
        .replaceFirst(RegExp(r"^cookie:\s*", caseSensitive: false), "")
        .split(RegExp(r"\r?\n"))
        .first
        .trim()
        .replaceAll(RegExp(r";+$"), "");
  }

  String _extractKuaishouKww(String input) {
    for (final line in input.split(RegExp(r"\r?\n"))) {
      final value = line.trim();
      final match =
          RegExp(r"^(?:kww|kwfv1)\s*[:=]\s*(.+)$", caseSensitive: false)
              .firstMatch(value);
      if (match != null) {
        return match.group(1)!.trim();
      }
    }
    final cookieMatch = RegExp(r"(?:^|;)\s*kwfv1=([^;]+)").firstMatch(input);
    return cookieMatch?.group(1)?.trim() ?? "";
  }
}
