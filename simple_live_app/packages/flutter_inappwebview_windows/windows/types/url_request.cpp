#include "../utils/flutter.h"
#include "url_request.h"

namespace flutter_inappwebview_plugin
{
  URLRequest::URLRequest(const std::optional<std::string>& url, const std::optional<std::string>& method,
    const std::optional<std::map<std::string, std::string>>& headers, const std::optional<std::vector<uint8_t>>& body)
    : url(url), method(method), headers(headers), body(body)
  {}

  URLRequest::URLRequest(const flutter::EncodableMap& map)
    : url(get_optional_fl_map_value<std::string>(map, "url")),
    method(get_optional_fl_map_value<std::string>(map, "method")),
    headers(get_optional_fl_map_value<std::map<std::string, std::string>>(map, "headers")),
    body(get_optional_fl_map_value<std::vector<uint8_t>>(map, "body"))
  {}

  flutter::EncodableMap URLRequest::toEncodableMap() const
  {
    return flutter::EncodableMap{
      {"url", make_fl_value(url)},
      {"method", make_fl_value(method)},
      {"headers", make_fl_value(headers)},
      {"body", make_fl_value(body)}
    };
  }
}