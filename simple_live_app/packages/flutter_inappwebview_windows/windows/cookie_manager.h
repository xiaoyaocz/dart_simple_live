#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_COOKIE_MANAGER_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_COOKIE_MANAGER_H_

#include <flutter/method_channel.h>
#include <flutter/standard_message_codec.h>
#include <functional>
#include <optional>

#include "flutter_inappwebview_windows_plugin.h"
#include "types/channel_delegate.h"
#include "webview_environment/webview_environment_manager.h"

namespace flutter_inappwebview_plugin
{
  class CookieManager : public ChannelDelegate
  {
  public:
    static inline const std::string METHOD_CHANNEL_NAME_PREFIX = "com.pichillilorenzo/flutter_inappwebview_cookiemanager";

    const FlutterInappwebviewWindowsPlugin* plugin;

    CookieManager(const FlutterInappwebviewWindowsPlugin* plugin);
    ~CookieManager();

    void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    void setCookie(WebViewEnvironment* webViewEnvironment, const flutter::EncodableMap& map, std::function<void(const bool&)> completionHandler) const;
    void getCookie(WebViewEnvironment* webViewEnvironment, const std::string& url, const std::string& name, std::function<void(const flutter::EncodableValue&)> completionHandler) const;
    void getCookies(WebViewEnvironment* webViewEnvironment, const std::string& url, std::function<void(const flutter::EncodableList&)> completionHandler) const;
    void deleteCookie(WebViewEnvironment* webViewEnvironment, const std::string& url, const std::string& name, const std::string& path, const std::optional<std::string>& domain, std::function<void(const bool&)> completionHandler) const;
    void deleteCookies(WebViewEnvironment* webViewEnvironment, const std::string& url, const std::string& path, const std::optional<std::string>& domain, std::function<void(const bool&)> completionHandler) const;
    void deleteAllCookies(WebViewEnvironment* webViewEnvironment, std::function<void(const bool&)> completionHandler) const;
  };
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_COOKIE_MANAGER_H_