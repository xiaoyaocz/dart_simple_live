#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_WEBVIEW_ENVIRONMENT_MANAGER_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_WEBVIEW_ENVIRONMENT_MANAGER_H_

#include <flutter/method_channel.h>
#include <map>
#include <string>
#include <winrt/base.h>

#include "../flutter_inappwebview_windows_plugin.h"
#include "../types/channel_delegate.h"
#include "webview_environment.h"

namespace flutter_inappwebview_plugin
{
  class WebViewEnvironmentManager : public ChannelDelegate
  {
  public:
    static inline const wchar_t* CLASS_NAME = L"WebViewEnvironmentManager";
    static inline const std::string METHOD_CHANNEL_NAME = "com.pichillilorenzo/flutter_webview_environment";

    const FlutterInappwebviewWindowsPlugin* plugin;
    std::map<std::string, std::unique_ptr<WebViewEnvironment>> webViewEnvironments;

    WebViewEnvironmentManager(const FlutterInappwebviewWindowsPlugin* plugin);
    ~WebViewEnvironmentManager();

    void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    void createWebViewEnvironment(const std::string& id, std::unique_ptr<WebViewEnvironmentSettings> settings, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    void createOrGetDefaultWebViewEnvironment(const std::function<void(WebViewEnvironment*)> completionHandler);
    HWND getHWND()
    {
      return hwnd_;
    }

    static std::optional<std::string> getAvailableVersion(std::optional<std::string> browserExecutableFolder);
    static std::optional<int> compareBrowserVersions(std::string version1, std::string version2);
  private:
    std::unique_ptr<WebViewEnvironment> defaultEnvironment_;
    WNDCLASS windowClass_ = {};
    HWND hwnd_ = nullptr;
  };
}
#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_WEBVIEW_ENVIRONMENT_MANAGER_H_