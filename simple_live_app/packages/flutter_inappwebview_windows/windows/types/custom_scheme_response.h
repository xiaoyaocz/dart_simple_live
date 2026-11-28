#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_CUSTOM_SCHEME_RESPONSE_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_CUSTOM_SCHEME_RESPONSE_H_

#include <flutter/standard_method_codec.h>
#include <WebView2.h>
#include <wil/com.h>

namespace flutter_inappwebview_plugin
{
  class CustomSchemeResponse
  {
  public:
    const std::vector<uint8_t> data;
    const std::string contentType;
    const std::string contentEncoding;

    CustomSchemeResponse(const std::vector<uint8_t>& data, const std::string& contentType, const std::string& contentEncoding);
    CustomSchemeResponse(const flutter::EncodableMap& map);
    ~CustomSchemeResponse() = default;

    flutter::EncodableMap toEncodableMap() const;
    ICoreWebView2WebResourceResponse* toWebView2Response(const wil::com_ptr<ICoreWebView2Environment> webViewEnvironment) const;
  };
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_CUSTOM_SCHEME_RESPONSE_H_