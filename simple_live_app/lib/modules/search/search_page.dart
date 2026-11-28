import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils/listen_fourth_button.dart';
import 'package:simple_live_app/modules/search/search_controller.dart';
import 'package:simple_live_app/modules/search/search_room_url.dart';
import 'package:simple_live_app/modules/search/search_web_navigation.dart';
import 'package:simple_live_app/routes/route_path.dart';

class SearchPage extends GetView<AppSearchController> {
  const SearchPage({super.key});

  /// 按平台生成搜索页 WebView 配置；移动端启用电脑版网页、缩放与性能优化。
  static InAppWebViewSettings buildWebViewSettings({
    required bool preferDesktopWeb,
  }) {
    if (!preferDesktopWeb) {
      return InAppWebViewSettings(
        javaScriptCanOpenWindowsAutomatically: true,
        supportMultipleWindows: true,
        useShouldOverrideUrlLoading: true,
      );
    }
    return InAppWebViewSettings(
      userAgent: SearchRoomUrl.desktopUserAgent,
      preferredContentMode: UserPreferredContentMode.DESKTOP,
      javaScriptCanOpenWindowsAutomatically: true,
      // 移动端关闭多窗口，使桌面网页 target="_blank" / window.open 直接在当前页打开。
      supportMultipleWindows: false,
      useShouldOverrideUrlLoading: true,
      mediaPlaybackRequiresUserGesture: true,
      useWideViewPort: true,
      loadWithOverviewMode: true,
      layoutAlgorithm: LayoutAlgorithm.NORMAL,
      textZoom: 100,
      supportZoom: true,
      builtInZoomControls: true,
      displayZoomControls: false,
      domStorageEnabled: true,
      databaseEnabled: true,
      thirdPartyCookiesEnabled: true,
      hardwareAcceleration: true,
      safeBrowsingEnabled: false,
      cacheMode: CacheMode.LOAD_DEFAULT,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
      overScrollMode: OverScrollMode.NEVER,
      transparentBackground: false,
      useHybridComposition: true,
    );
  }

  /// 生成搜索页注入脚本；移动端额外对所有 iframe 注入桌面指纹，保证四平台登录/验证码 iframe 指纹一致。
  static List<UserScript> buildUserScripts({
    required bool preferDesktopWeb,
    required double viewWidth,
  }) {
    return [
      UserScript(
        source: SearchWebNavigation.script,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: true,
      ),
      if (preferDesktopWeb) ...[
        UserScript(
          source: SearchWebNavigation.androidDesktopFingerprintScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
        UserScript(
          source: SearchWebNavigation.buildAndroidDesktopScript(viewWidth),
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: true,
        ),
      ],
    ];
  }

  bool get _isDesktopHost =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(
        leading: Obx(
          () => IconButton(
            tooltip: controller.selectedSite.value == null ? '返回' : '选择平台',
            onPressed: controller.selectedSite.value == null
                ? Get.back
                : controller.reset,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        title: Obx(
          () => Text(
            controller.selectedSite.value?.name ?? '搜索直播',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          Obx(() {
            if (controller.selectedSite.value == null) {
              return const SizedBox.shrink();
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.roomId.value != null &&
                    controller.webViewVisible.value)
                  TextButton.icon(
                    onPressed: controller.openCurrentRoom,
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text('打开播放器'),
                  ),
                IconButton(
                  tooltip: '网页后退（后侧键；双击回首页）',
                  visualDensity: VisualDensity.compact,
                  onPressed: controller.goBackInWebView,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: '刷新网页',
                  visualDensity: VisualDensity.compact,
                  onPressed: controller.reloadWebView,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            );
          }),
        ],
      ),
      body: Obx(() {
        final site = controller.selectedSite.value;
        if (site == null) return _platformPicker(context);
        final revision = controller.webViewRevision.value;
        bool isCurrentView() =>
            controller.selectedSite.value == site &&
            controller.webViewRevision.value == revision &&
            !controller.isClosed;
        return FutureBuilder<WebViewEnvironment?>(
          key: ValueKey(revision),
          future: controller.webViewEnvironment,
          builder: (context, snapshot) {
            if (snapshot.hasError ||
                snapshot.connectionState != ConnectionState.done) {
              return _webViewStatus(initializing: true);
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final viewWidth = constraints.maxWidth.isFinite &&
                        constraints.maxWidth > 0
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width;
                if (controller.preferDesktopWeb &&
                    controller.webViewController != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (isCurrentView()) {
                      controller.syncDesktopViewport(viewWidth);
                    }
                  });
                }
                final userScripts = buildUserScripts(
                  preferDesktopWeb: controller.preferDesktopWeb,
                  viewWidth: viewWidth,
                );
                return Stack(
                  children: [
                    Offstage(
                      offstage: !controller.webViewVisible.value,
                      child: InAppWebView(
                        key: ValueKey('${site.id}:$revision'),
                        webViewEnvironment: snapshot.data,
                        initialUrlRequest: URLRequest(
                          url: WebUri(controller.webViewUrl.toString()),
                        ),
                        initialSettings: buildWebViewSettings(
                          preferDesktopWeb: controller.preferDesktopWeb,
                        ),
                        initialUserScripts: UnmodifiableListView(userScripts),
                        onWebViewCreated: (webViewController) {
                          if (!isCurrentView()) return;
                          controller.webViewController = webViewController;
                          webViewController.addJavaScriptHandler(
                            handlerName: SearchWebNavigation.handlerName,
                            callback: (args) {
                              if (isCurrentView() &&
                                  controller.isCurrentWebView(
                                      webViewController, revision) &&
                                  args.isNotEmpty &&
                                  args.first is String) {
                                final uri = Uri.tryParse(args.first as String);
                                if (uri != null &&
                                    SearchRoomUrl.roomIdFor(site.id, uri) !=
                                        null) {
                                  controller.updateUrl(uri);
                                }
                              }
                            },
                          );
                        },
                        shouldOverrideUrlLoading: (view, action) async {
                          if (!isCurrentView() ||
                              !controller.isCurrentWebView(view, revision)) {
                            return NavigationActionPolicy.CANCEL;
                          }
                          return controller.handleNavigation(action);
                        },
                        onLoadStart: (view, uri) {
                          if (!isCurrentView() ||
                              !controller.isCurrentWebView(view, revision)) {
                            return;
                          }
                          controller.startLoading(uri);
                          controller.updateUrl(uri);
                        },
                        onLoadStop: (view, uri) {
                          if (!isCurrentView() ||
                              !controller.isCurrentWebView(view, revision)) {
                            return;
                          }
                          if (controller.finishLoading(uri)) {
                            controller.updateUrl(uri);
                          } else if (uri != null &&
                              SearchRoomUrl.roomIdFor(site.id, uri) != null) {
                            controller.updateUrl(uri);
                          }
                          if (controller.preferDesktopWeb) {
                            controller.syncDesktopViewport(
                              viewWidth,
                              force: true,
                            );
                            controller.persistMobileWebSession();
                          }
                        },
                        onProgressChanged: (_, progress) {
                          if (isCurrentView()) {
                            controller.updateLoadProgress(progress);
                          }
                        },
                        onReceivedError: (_, request, error) {
                          if (!isCurrentView()) return;
                          controller.handleLoadError(request, error);
                        },
                        onReceivedHttpError: (view, request, response) {
                          if (isCurrentView() &&
                              controller.isCurrentWebView(view, revision)) {
                            controller.handleHttpError(request, response);
                          }
                        },
                        onUpdateVisitedHistory: (_, uri, __) {
                          if (isCurrentView()) {
                            controller.updateUrl(uri);
                            if (controller.preferDesktopWeb) {
                              controller.persistMobileWebSession();
                            }
                          }
                        },
                        onCreateWindow: (view, action) => isCurrentView() &&
                                controller.isCurrentWebView(view, revision)
                            ? controller.openPopup(action)
                            : Future.value(false),
                      ),
                    ),
                    _webViewStatus(),
                    _roomPromptBanner(context),
                  ],
                );
              },
            );
          },
        );
      }),
    );

    if (_isDesktopHost) {
      return RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        // 页面内优先消费后侧键，避免全局返回把整个搜索页关闭。
        gestures: {
          FourthButtonTapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                  FourthButtonTapGestureRecognizer>(
            FourthButtonTapGestureRecognizer.new,
            (recognizer) {
              recognizer.onTap = controller.goBackInWebView;
              recognizer.onDoubleTap = () => Get.until((route) =>
                  route.settings.name == RoutePath.kIndex || route.isFirst);
            },
          ),
          ForwardButtonTapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                  ForwardButtonTapGestureRecognizer>(
            ForwardButtonTapGestureRecognizer.new,
            (recognizer) => recognizer.onTap = () async {
              await controller.openCurrentRoom();
            },
          ),
        },
        child: scaffold,
      );
    }

    return Obx(
      () => PopScope(
        canPop: controller.selectedSite.value == null,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final shouldPop = await controller.handleBackPress();
          if (shouldPop && context.mounted) {
            Get.back();
          }
        },
        child: scaffold,
      ),
    );
  }

  Widget _roomPromptBanner(BuildContext context) {
    if (!controller.preferDesktopWeb) return const SizedBox.shrink();
    return Obx(() {
      if (!controller.showRoomPrompt) return const SizedBox.shrink();
      final site = controller.selectedSite.value;
      final id = controller.roomId.value;
      if (site == null || id == null) return const SizedBox.shrink();
      final theme = Theme.of(context);
      return Positioned(
        left: 12,
        right: 12,
        bottom: 16,
        child: SafeArea(
          top: false,
          child: Material(
            elevation: 8,
            borderRadius: AppStyle.radius12,
            color: theme.colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Image.asset(site.logo, width: 28, height: 28),
                  AppStyle.hGap8,
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '检测到直播间 #$id',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '点击使用原生播放器流畅观看',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppStyle.hGap8,
                  FilledButton.icon(
                    onPressed: controller.openCurrentRoom,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('进入直播间'),
                  ),
                  IconButton(
                    tooltip: '暂时收起',
                    visualDensity: VisualDensity.compact,
                    onPressed: controller.dismissRoomPrompt,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _webViewStatus({bool initializing = false}) => Obx(() {
        if (!controller.webViewVisible.value) return const SizedBox.shrink();
        final error = controller.webViewError.value;
        if (error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: controller.reloadWebView,
                  child: const Text('重新加载'),
                ),
              ],
            ),
          );
        }
        if (initializing) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!controller.webViewLoading.value) {
          return const SizedBox.shrink();
        }
        final progress = controller.loadProgress.value;
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: LinearProgressIndicator(
              minHeight: 3,
              value: progress > 0 && progress < 100 ? progress / 100.0 : null,
            ),
          ),
        );
      });

  Widget _platformPicker(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: AppStyle.edgeInsetsA12,
          children: [
            Padding(
              padding: AppStyle.edgeInsetsA12,
              child: Text(
                '选择平台，在网页中搜索并进入直播间',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...Sites.supportSites.map(
              (site) => Card(
                child: ListTile(
                  leading: Image.asset(site.logo, width: 32, height: 32),
                  title: Text(site.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => controller.selectSite(site),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
