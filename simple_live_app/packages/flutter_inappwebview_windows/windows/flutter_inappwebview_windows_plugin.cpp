#include "flutter_inappwebview_windows_plugin.h"

#include <flutter/plugin_registrar_windows.h>

#include "cookie_manager.h"
#include "headless_in_app_webview/headless_in_app_webview_manager.h"
#include "in_app_browser/in_app_browser_manager.h"
#include "in_app_webview/in_app_webview_manager.h"
#include "webview_environment/webview_environment_manager.h"

#pragma comment(lib, "Shlwapi.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")

namespace flutter_inappwebview_plugin
{
  // static
  void FlutterInappwebviewWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar, FlutterDesktopMessengerRef messenger)
  {
    auto plugin = std::make_unique<FlutterInappwebviewWindowsPlugin>(registrar, messenger);
    registrar->AddPlugin(std::move(plugin));
  }

  FlutterInappwebviewWindowsPlugin::FlutterInappwebviewWindowsPlugin(flutter::PluginRegistrarWindows* registrar,
    FlutterDesktopMessengerRef messenger)
    : registrar(registrar), messenger_(FlutterDesktopMessengerAddRef(messenger))
  {
    webViewEnvironmentManager = std::make_unique<WebViewEnvironmentManager>(this);
    inAppWebViewManager = std::make_unique<InAppWebViewManager>(this);
    inAppBrowserManager = std::make_unique<InAppBrowserManager>(this);
    headlessInAppWebViewManager = std::make_unique<HeadlessInAppWebViewManager>(this);
    cookieManager = std::make_unique<CookieManager>(this);
  }

  FlutterInappwebviewWindowsPlugin::~FlutterInappwebviewWindowsPlugin()
  {
    webViewEnvironmentManager = nullptr;
    inAppWebViewManager = nullptr;
    inAppBrowserManager = nullptr;
    headlessInAppWebViewManager = nullptr;
    cookieManager = nullptr;
    FlutterDesktopMessengerRelease(messenger_);
  }
}
