#include "rect.h"

namespace flutter_inappwebview_plugin
{
  Rect::Rect(const double& x, const double& y, const double& width, const double& height)
    : x(x), y(y), width(width), height(height)
  {}

  Rect::Rect(const flutter::EncodableMap& map)
    : x(get_fl_map_value<double>(map, "x")),
    y(get_fl_map_value<double>(map, "y")),
    width(get_fl_map_value<double>(map, "width")),
    height(get_fl_map_value<double>(map, "height"))
  {}

  flutter::EncodableMap Rect::toEncodableMap() const
  {
    return flutter::EncodableMap{
      {"x", x},
      {"y", y},
      {"width", width},
      {"height", height}
    };
  }
}