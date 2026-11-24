import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/services/background_playback_service.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

/// 移动端后台保活设置指引
class BackgroundKeepalivePage extends StatefulWidget {
  const BackgroundKeepalivePage({Key? key}) : super(key: key);

  @override
  State<BackgroundKeepalivePage> createState() =>
      _BackgroundKeepalivePageState();
}

class _BackgroundKeepalivePageState extends State<BackgroundKeepalivePage>
    with WidgetsBindingObserver {
  bool _batteryIgnored = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshBatteryStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshBatteryStatus();
    }
  }

  Future<void> _refreshBatteryStatus() async {
    final value =
        await BackgroundPlaybackService.instance.isBatteryOptimizationIgnored();
    if (!mounted) {
      return;
    }
    setState(() {
      _batteryIgnored = value;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("后台保活设置指引"),
      ),
      body: ListView(
        padding: AppStyle.pagePadding(),
        children: [
          if (Platform.isAndroid) ..._buildAndroid(context),
          if (Platform.isIOS) ..._buildIos(context),
          if (!Platform.isAndroid && !Platform.isIOS) ..._buildDesktop(context),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Android

  List<Widget> _buildAndroid(BuildContext context) {
    return [
      _sectionTitle("第一步：电池优化白名单"),
      SettingsCard(
        child: Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _loaded
                    ? (_batteryIgnored
                        ? "已加入电池优化白名单"
                        : "尚未加入电池优化白名单")
                    : "正在检查状态…",
                style: TextStyle(
                  color: _batteryIgnored ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppStyle.vGap8,
              const Text(
                "加入白名单后，系统 Doze 省电模式才不会在后台切断网络、暂停播放。",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              AppStyle.vGap12,
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.battery_saver, size: 18),
                      label: Text(_batteryIgnored ? "重新打开设置" : "一键申请白名单"),
                      onPressed: () async {
                        await BackgroundPlaybackService.instance
                            .requestIgnoreBatteryOptimizations();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      _sectionTitle("第二步：允许自启动（最关键）"),
      SettingsCard(
        child: Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "国产手机默认禁止应用自启动，长时间后台或划掉最近任务后，即使有前台通知也可能被整体清理。请按下面的品牌指引开启。",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              AppStyle.vGap12,
              FilledButton.icon(
                icon: const Icon(Icons.launch, size: 18),
                label: const Text("尝试打开自启动设置"),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final opened = await BackgroundPlaybackService.instance
                      .openAutoStartSettings();
                  if (!opened) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text("未找到自启动页面，请按下方指引手动查找")),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
      _sectionTitle("第三步：按品牌完成设置"),
      ..._brandGuides,
      _sectionTitle("第四步：锁定最近任务"),
      const SettingsCard(
        child: Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Text(
            "打开最近任务（多任务）界面，找到 Simple Live 的卡片，长按卡片或点击卡片上的锁图标将其锁定，避免一键清理时被划掉。",
            style: TextStyle(fontSize: 13),
          ),
        ),
      ),
    ];
  }

  List<Widget> get _brandGuides {
    final guides = <_BrandGuide>[
      const _BrandGuide(
        brand: "小米 MIUI / HyperOS",
        steps: [
          "设置 → 应用设置 → 应用管理 → Simple Live",
          "打开「自启动」",
          "「省电策略」选择「无限制」",
          "最近任务里长按 Simple Live 卡片，点击加锁",
        ],
      ),
      const _BrandGuide(
        brand: "华为 EMUI / HarmonyOS",
        steps: [
          "设置 → 应用和服务 → 应用启动管理 → Simple Live",
          "关闭「自动管理」",
          "手动允许「自启动」「关联启动」「后台活动」三项",
          "最近任务里给 Simple Live 卡片加锁",
        ],
      ),
      const _BrandGuide(
        brand: "OPPO ColorOS",
        steps: [
          "设置 → 应用 → 应用管理 → Simple Live",
          "打开「允许自启动」「允许后台运行」",
          "电池 → 关闭「省电」与「应用速冻」",
          "最近任务里给 Simple Live 卡片加锁",
        ],
      ),
      const _BrandGuide(
        brand: "vivo OriginOS / iQOO",
        steps: [
          "设置 → 应用与权限 → 权限管理 → 自启动 → 允许 Simple Live",
          "设置 → 电池 → 后台耗电管理 → Simple Live → 允许高耗电",
          "最近任务里给 Simple Live 卡片加锁",
        ],
      ),
      const _BrandGuide(
        brand: "三星 / 原生 Android",
        steps: [
          "完成第一步电池优化白名单即可",
          "三星：设置 → 应用程序 → Simple Live → 电池 → 不受限制",
        ],
      ),
    ];
    return guides
        .map(
          (guide) => Padding(
            padding: AppStyle.edgeInsetsB12,
            child: SettingsCard(
              child: Padding(
                padding: AppStyle.edgeInsetsA12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guide.brand,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    AppStyle.vGap8,
                    ...List.generate(guide.steps.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          "${index + 1}. ${guide.steps[index]}",
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  // -------------------------------------------------------------------- iOS

  List<Widget> _buildIos(BuildContext context) {
    return [
      _sectionTitle("后台播放说明"),
      const SettingsCard(
        child: Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Text(
            "App 已声明后台音频模式并配置了播放型音频会话，锁屏或切到其他 App 后会继续播放声音，无需额外开关。",
            style: TextStyle(fontSize: 13),
          ),
        ),
      ),
      _sectionTitle("中断与恢复"),
      const SettingsCard(
        child: Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Text(
            "1. 来电、Siri 等中断播放后，挂断/结束时会自动重新激活并恢复播放。\n"
            "2. 播放中拔出耳机，系统会自动暂停；插回后可在锁屏/控制中心点击播放继续。\n"
            "3. 若长时间没有声音，系统会挂起 App，回到 App 后会自动检测并重新连接直播间。",
            style: TextStyle(fontSize: 13),
          ),
        ),
      ),
      _sectionTitle("仍被暂停时的检查"),
      const SettingsCard(
        child: Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Text(
            "1. 确认没有在锁屏/控制中心手动暂停；\n"
            "2. 确认侧边静音开关与音量；\n"
            "3. 低电量模式下部分后台行为会被系统收紧，可在设置 → 电池中临时关闭测试。",
            style: TextStyle(fontSize: 13),
          ),
        ),
      ),
    ];
  }

  // ---------------------------------------------------------------- Desktop

  List<Widget> _buildDesktop(BuildContext context) {
    return [
      const SettingsCard(
        child: Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Text(
            "桌面端没有移动端的后台限制，无需进行保活设置。",
            style: TextStyle(fontSize: 13),
          ),
        ),
      ),
    ];
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: AppStyle.edgeInsetsA12.copyWith(top: 16),
      child: Text(
        text,
        style: Get.textTheme.titleSmall,
      ),
    );
  }
}

class _BrandGuide {
  final String brand;
  final List<String> steps;

  const _BrandGuide({
    required this.brand,
    required this.steps,
  });
}
