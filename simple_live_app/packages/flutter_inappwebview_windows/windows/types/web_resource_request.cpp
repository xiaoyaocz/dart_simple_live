#include "../utils/flutter.h"
#include "../utils/log.h"
#include "web_resource_request.h"

namespace flutter_inappwebview_plugin
{
  WebResourceRequest::WebResourceRequest(const std::optional<std::string>& url, const std::optional<std::string>& method,
    const std::optional<std::map<std::string, std::string>>& headers, const std::optional<bool>& isForMainFrame)
    : url(url), method(method), headers(headers), isForMainFrame(isForMainFrame)
  {}

  WebResourceRequest::WebResourceRequest(const flutter::EncodableMap& map)
    : url(get_optional_fl_map_value<std::string>(map, "url")),
    method(get_optional_fl_map_value<std::string>(map, "method")),
    headers(get_optional_fl_map_value<std::map<std::string, std::string>>(map, "headers")),
    isForMainFrame(get_optional_fl_map_value<bool>(map, "isForMainFrame"))
  {}

  WebResourceRequest::WebResourceRequest(wil::com_ptr<ICoreWebView2WebResourceRequest> webResourceRequest)
  {
    wil::unique_cotaskmem_string uri;
    url = SUCCEEDED(webResourceRequest->get_Uri(&uri)) ? wide_to_utf8(uri.get()) : std::optional<std::string>{};

    wil::unique_cotaskmem_string methodStr;
    method = SUCCEEDED(webResourceRequest->get_Method(&methodStr)) ? wide_to_utf8(methodStr.get()) : std::optional<std::string>{};

    // Get the headers
    wil::com_ptr<ICoreWebView2HttpRequestHeaders> requestHeaders;
    if (SUCCEEDED(webResourceRequest->get_Headers(&requestHeaders))) {
      std::map<std::string, std::string> headersMap;
      wil::com_ptr<ICoreWebView2HttpHeadersCollectionIterator> iterator;
      if (SUCCEEDED(requestHeaders->GetIterator(&iterator))) {
        BOOL hasCurrent = FALSE;
        iterator->get_HasCurrentHeader(&hasCurrent);
        while (hasCurrent) {
          wil::unique_cotaskmem_string name, value;
          iterator->GetCurrentHeader(&name, &value);
          headersMap.emplace(wide_to_utf8(name.get()), wide_to_utf8(value.get()));
          iterator->MoveNext(&hasCurrent);
        }
        if (!headersMap.empty()) {
          headers = headersMap;
        }
      }
    }

    isForMainFrame = true;
  }

  flutter::EncodableMap WebResourceRequest::toEncodableMap() const
  {
    return flutter::EncodableMap{
      {"url", make_fl_value(url)},
      {"method", make_fl_value(method)},
      {"headers", make_fl_value(headers)},
      {"isForMainFrame", make_fl_value(isForMainFrame)}
    };
  }
}