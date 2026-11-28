#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_WEBVIEW_ENVIRONMENT_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_WEBVIEW_ENVIRONMENT_H_

#include <functional>
#include <WebView2.h>
#include <wil/com.h>

#include "../flutter_inappwebview_windows_plugin.h"
#include "webview_environment_channel_delegate.h"
#include "webview_environment_settings.h"

namespace flutter_inappwebview_plugin
{
  class WebViewEnvironment
  {
  public:
    static inline const wchar_t* CLASS_NAME = L"WebViewEnvironment";
    static inline const std::string METHOD_CHANNEL_NAME_PREFIX = "com.pichillilorenzo/flutter_webview_environment_";

    const FlutterInappwebviewWindowsPlugin* plugin;
    std::string id;

    std::unique_ptr<WebViewEnvironmentChannelDelegate> channelDelegate;

    WebViewEnvironment(const FlutterInappwebviewWindowsPlugin* plugin, const std::string& id);
    ~WebViewEnvironment();

    void create(const std::unique_ptr<WebViewEnvironmentSettings> settings, const std::function<void(HRESULT)> completionHandler);
    wil::com_ptr<ICoreWebView2Environment> getEnvironment()
    {
      return environment_;
    }
    wil::com_ptr<ICoreWebView2Controller> getWebViewController()
    {
      return webViewController_;
    }
    wil::com_ptr<ICoreWebView2> getWebView()
    {
      return webView_;
    }
  private:
    wil::com_ptr<ICoreWebView2Environment> environment_;
    wil::com_ptr<ICoreWebView2Controller> webViewController_;
    wil::com_ptr<ICoreWebView2> webView_;
    WNDCLASS windowClass_ = {};
  };
}
#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_WEBVIEW_ENVIRONMENT_H_