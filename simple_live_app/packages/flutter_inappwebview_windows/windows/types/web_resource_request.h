#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_WEB_RESOURCE_REQUEST_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_WEB_RESOURCE_REQUEST_H_

#include <flutter/standard_method_codec.h>
#include <optional>
#include <WebView2.h>
#include <wil/com.h>

namespace flutter_inappwebview_plugin
{
  class WebResourceRequest
  {
  public:
    std::optional<std::string> url;
    std::optional<std::string> method;
    std::optional<std::map<std::string, std::string>> headers;
    std::optional<bool> isForMainFrame;

    WebResourceRequest(const std::optional<std::string>& url, const std::optional<std::string>& method,
      const std::optional<std::map<std::string, std::string>>& headers, const std::optional<bool>& isForMainFrame);
    WebResourceRequest(const flutter::EncodableMap& map);
    WebResourceRequest(wil::com_ptr<ICoreWebView2WebResourceRequest> webResourceRequest);
    ~WebResourceRequest() = default;

    flutter::EncodableMap toEncodableMap() const;
  };
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_WEB_RESOURCE_REQUEST_H_