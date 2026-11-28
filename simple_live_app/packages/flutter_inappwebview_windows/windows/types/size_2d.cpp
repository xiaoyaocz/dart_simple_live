#include "size_2d.h"

namespace flutter_inappwebview_plugin
{
    Size2D::Size2D(const double& width, const double& height)
    : width(width), height(height)
  {}

    Size2D::Size2D(const flutter::EncodableMap& map)
    : width(get_fl_map_value<double>(map, "width")),
      height(get_fl_map_value<double>(map, "height"))
  {}

  flutter::EncodableMap Size2D::toEncodableMap() const
  {
    return flutter::EncodableMap{
      {"width", width},
      {"height", height}
    };
  }
}