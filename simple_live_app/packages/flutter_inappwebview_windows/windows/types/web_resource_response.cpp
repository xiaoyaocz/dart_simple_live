#include "../utils/flutter.h"
#include "../utils/strconv.h"
#include "web_resource_response.h"

#include <Shlwapi.h>

namespace flutter_inappwebview_plugin
{
  WebResourceResponse::WebResourceResponse(const std::optional<std::string>& contentType,
    const std::optional<std::string>& contentEncoding,
    const std::optional<int64_t>& statusCode,
    const std::optional<std::string>& reasonPhrase,
    const std::optional<std::map<std::string, std::string>>& headers,
    const std::optional<std::vector<uint8_t>>& data)
    : contentType(contentType), contentEncoding(contentEncoding), statusCode(statusCode),
    reasonPhrase(reasonPhrase), headers(headers), data(data)
  {}

  WebResourceResponse::WebResourceResponse(const flutter::EncodableMap& map)
    : contentType(get_optional_fl_map_value<std::string>(map, "contentType")),
    contentEncoding(get_optional_fl_map_value<std::string>(map, "contentEncoding")),
    statusCode(get_optional_fl_map_value<int64_t>(map, "statusCode")),
    reasonPhrase(get_optional_fl_map_value<std::string>(map, "reasonPhrase")),
    headers(get_optional_fl_map_value<std::map<std::string, std::string>>(map, "headers")),
    data(get_optional_fl_map_value<std::vector<uint8_t>>(map, "data"))
  {}

  flutter::EncodableMap WebResourceResponse::toEncodableMap() const
  {
    return flutter::EncodableMap{
    {"contentEncoding", make_fl_value(contentEncoding)},
    {"contentType", make_fl_value(contentType)},
    {"statusCode", make_fl_value(statusCode)},
    {"reasonPhrase", make_fl_value(reasonPhrase)},
    {"headers", make_fl_value(headers)},
    {"data", make_fl_value(data)}
    };
  }

  ICoreWebView2WebResourceResponse* WebResourceResponse::toWebView2Response(const wil::com_ptr<ICoreWebView2Environment> webViewEnvironment) const
  {
    wil::com_ptr<ICoreWebView2WebResourceResponse> webResourceResponse;

    if (webViewEnvironment) {
      wil::com_ptr<IStream> postDataStream = nullptr;
      if (data.has_value()) {
        auto postData = std::string(data.value().begin(), data.value().end());
        postDataStream = SHCreateMemStream(
          reinterpret_cast<const BYTE*>(postData.data()), static_cast<UINT>(postData.length()));
      }

      webViewEnvironment->CreateWebResourceResponse(
        postDataStream.get(),
        statusCode.value_or(200), // Default to 200 if statusCode is not set
        reasonPhrase.has_value() ? utf8_to_wide(reasonPhrase.value()).c_str() : L"OK", // Default to "OK" if reasonPhrase is not set
        nullptr,
        &webResourceResponse);

      wil::com_ptr<ICoreWebView2HttpResponseHeaders> responseHeaders;
      if (SUCCEEDED(webResourceResponse->get_Headers(&responseHeaders))) {
        // Set the headers
        if (headers.has_value()) {
          for (auto const& [key, val] : headers.value()) {
            responseHeaders->AppendHeader(utf8_to_wide(key).c_str(), utf8_to_wide(val).c_str());
          }
        }
        if (contentType.has_value() && !contentType.value().empty()) {
          responseHeaders->AppendHeader(L"Content-Type", utf8_to_wide(contentType.value()).c_str());
        }
        if (contentEncoding.has_value() && !contentEncoding.value().empty()) {
          responseHeaders->AppendHeader(L"Content-Encoding", utf8_to_wide(contentEncoding.value()).c_str());
        }
      }

      webResourceResponse->AddRef();
    }

    return webResourceResponse.get();
  }
}
