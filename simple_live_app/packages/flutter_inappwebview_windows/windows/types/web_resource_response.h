#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_WEB_RESOURCE_RESPONSE_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_WEB_RESOURCE_RESPONSE_H_

#include <flutter/standard_method_codec.h>
#include <optional>
#include <WebView2.h>
#include <wil/com.h>

namespace flutter_inappwebview_plugin
{
  class WebResourceResponse
  {
  public:
    const std::optional<std::string> contentType;
    const std::optional<std::string> contentEncoding;
    const std::optional<int64_t> statusCode;
    const std::optional<std::string> reasonPhrase;
    const std::optional<std::map<std::string, std::string>> headers;
    const std::optional<std::vector<uint8_t>> data;

    WebResourceResponse(const std::optional<std::string>& contentType,
      const std::optional<std::string>& contentEncoding,
      const std::optional<int64_t>& statusCode,
      const std::optional<std::string>& reasonPhrase,
      const std::optional<std::map<std::string, std::string>>& headers,
      const std::optional<std::vector<uint8_t>>& data);
    WebResourceResponse(const flutter::EncodableMap& map);
    ~WebResourceResponse() = default;

    flutter::EncodableMap toEncodableMap() const;
    ICoreWebView2WebResourceResponse* WebResourceResponse::toWebView2Response(const wil::com_ptr<ICoreWebView2Environment> webViewEnvironment) const;
  };
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_WEB_RESOURCE_RESPONSE_H_