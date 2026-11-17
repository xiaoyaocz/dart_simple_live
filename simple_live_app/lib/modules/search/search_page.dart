import 'dart:collection';

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

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      // 页面内优先消费后侧键，避免全局返回把整个搜索页关闭。
      gestures: {
        FourthButtonTapGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            FourthButtonTapGestureRecognizer>(
          FourthButtonTapGestureRecognizer.new,
          (recognizer) {
            recognizer.onTap = controller.goBackInWebView;
            recognizer.onDoubleTap = () => Get.until((route) =>
                route.settings.name == RoutePath.kIndex || route.isFirst);
          },
        ),
        ForwardButtonTapGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            ForwardButtonTapGestureRecognizer>(
          ForwardButtonTapGestureRecognizer.new,
          (recognizer) => recognizer.onTap = () async {
            await controller.openCurrentRoom();
          },
        ),
      },
      child: Scaffold(
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
            () => Text(controller.selectedSite.value?.name ?? '搜索直播',
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          actions: [
            Obx(() {
              if (controller.selectedSite.value == null) {
                return const SizedBox.shrink();
              }
              return Row(
                children: [
                  if (controller.roomId.value != null &&
                      controller.webViewVisible.value)
                    TextButton.icon(
                      onPressed: controller.openCurrentRoom,
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('打开播放器'),
                    ),
                  IconButton(
                    tooltip: '网页后退（后侧键；双击回首页）',
                    onPressed: controller.goBackInWebView,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: '刷新网页',
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
                      initialSettings: InAppWebViewSettings(
                        javaScriptCanOpenWindowsAutomatically: true,
                        supportMultipleWindows: true,
                        useShouldOverrideUrlLoading: true,
                      ),
                      initialUserScripts: UnmodifiableListView([
                        UserScript(
                          source: SearchWebNavigation.script,
                          injectionTime:
                              UserScriptInjectionTime.AT_DOCUMENT_START,
                          forMainFrameOnly: true,
                        ),
                      ]),
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
                        if (isCurrentView()) controller.updateUrl(uri);
                      },
                      onCreateWindow: (view, action) => isCurrentView() &&
                              controller.isCurrentWebView(view, revision)
                          ? controller.openPopup(action)
                          : Future.value(false),
                    ),
                  ),
                  _webViewStatus(),
                ],
              );
            },
          );
        }),
      ),
    );
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
        return controller.webViewLoading.value || initializing
            ? const Center(child: CircularProgressIndicator())
            : const SizedBox.shrink();
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
