#ifndef FLUTTER_PLUGIN_FLUTTER_INAPPWEBVIEW_PLUGIN_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_INAPPWEBVIEW_PLUGIN_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter_messenger.h>

namespace flutter_inappwebview_plugin
{
  class WebViewEnvironmentManager;
  class InAppWebViewManager;
  class InAppBrowserManager;
  class HeadlessInAppWebViewManager;
  class CookieManager;

  class FlutterInappwebviewWindowsPlugin : public flutter::Plugin {
  public:
    flutter::PluginRegistrarWindows* registrar;
    std::unique_ptr<WebViewEnvironmentManager> webViewEnvironmentManager;
    std::unique_ptr<InAppWebViewManager> inAppWebViewManager;
    std::unique_ptr<InAppBrowserManager> inAppBrowserManager;
    std::unique_ptr<HeadlessInAppWebViewManager> headlessInAppWebViewManager;
    std::unique_ptr<CookieManager> cookieManager;

    static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar,
      FlutterDesktopMessengerRef messenger);

    FlutterInappwebviewWindowsPlugin(flutter::PluginRegistrarWindows* registrar,
      FlutterDesktopMessengerRef messenger);

    bool isEngineAvailable() const { return FlutterDesktopMessengerIsAvailable(messenger_); }

    virtual ~FlutterInappwebviewWindowsPlugin();

    // Disallow copy and assign.
    FlutterInappwebviewWindowsPlugin(const FlutterInappwebviewWindowsPlugin&) = delete;
    FlutterInappwebviewWindowsPlugin& operator=(const FlutterInappwebviewWindowsPlugin&) = delete;
  private:
    FlutterDesktopMessengerRef messenger_;
  };
}
#endif  // FLUTTER_PLUGIN_FLUTTER_INAPPWEBVIEW_PLUGIN_PLUGIN_H_
