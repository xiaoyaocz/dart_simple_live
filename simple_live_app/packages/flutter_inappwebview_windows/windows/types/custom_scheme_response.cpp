#include "../utils/flutter.h"
#include "../utils/string.h"
#include "custom_scheme_response.h"

#include <Shlwapi.h>

namespace flutter_inappwebview_plugin
{
  CustomSchemeResponse::CustomSchemeResponse(const std::vector<uint8_t>& data, const std::string& contentType, const std::string& contentEncoding)
    : data(data), contentType(contentType), contentEncoding(contentEncoding)
  {}

  CustomSchemeResponse::CustomSchemeResponse(const flutter::EncodableMap& map)
    : data(get_fl_map_value<std::vector<uint8_t>>(map, "data")),
    contentType(get_fl_map_value<std::string>(map, "contentType")),
    contentEncoding(get_fl_map_value<std::string>(map, "contentEncoding"))
  {}

  flutter::EncodableMap CustomSchemeResponse::toEncodableMap() const
  {
    return flutter::EncodableMap{
      {"data", make_fl_value(data)},
      {"contentType", make_fl_value(contentType)},
      {"contentEncoding", make_fl_value(contentEncoding)}
    };
  }

  ICoreWebView2WebResourceResponse* CustomSchemeResponse::toWebView2Response(const wil::com_ptr<ICoreWebView2Environment> webViewEnvironment) const
  {
    wil::com_ptr<ICoreWebView2WebResourceResponse> webResourceResponse;

    if (webViewEnvironment) {
      wil::com_ptr<IStream> postDataStream = nullptr;
      if (!data.empty()) {
        auto postData = std::string(data.begin(), data.end());
        postDataStream = SHCreateMemStream(
          reinterpret_cast<const BYTE*>(postData.data()), static_cast<UINT>(postData.length()));
      }

      webViewEnvironment->CreateWebResourceResponse(
        postDataStream.get(),
        200, // Default to 200
        L"OK", // Default to "OK"
        nullptr,
        &webResourceResponse);

      wil::com_ptr<ICoreWebView2HttpResponseHeaders> responseHeaders;
      if (SUCCEEDED(webResourceResponse->get_Headers(&responseHeaders))) {
        if (!contentType.empty()) {
          responseHeaders->AppendHeader(L"Content-Type", utf8_to_wide(contentType).c_str());
        }
        if (!contentEncoding.empty()) {
          responseHeaders->AppendHeader(L"Content-Encoding", utf8_to_wide(contentEncoding).c_str());
        }
      }

      webResourceResponse->AddRef();
    }

    return webResourceResponse.get();
  }
}
