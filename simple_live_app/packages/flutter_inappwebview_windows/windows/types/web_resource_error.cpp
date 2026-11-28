#include "../utils/flutter.h"
#include "web_resource_error.h"

namespace flutter_inappwebview_plugin
{
  WebResourceError::WebResourceError(const std::string& description, const int64_t type)
    : description(description), type(type)
  {}

  WebResourceError::WebResourceError(const flutter::EncodableMap& map)
    : description(get_fl_map_value<std::string>(map, "description")),
    type(get_fl_map_value<int>(map, "type"))
  {}

  flutter::EncodableMap WebResourceError::toEncodableMap() const
  {
    return flutter::EncodableMap{
      {"description", make_fl_value(description)},
      {"type", make_fl_value(type)}
    };
  }
}