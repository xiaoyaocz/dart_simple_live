#include "../utils/flutter.h"
#include "window_features.h"

namespace flutter_inappwebview_plugin
{
  WindowFeatures::WindowFeatures(const std::optional<double>& width,
    const std::optional<double>& height,
    const std::optional<double>& x,
    const std::optional<double>& y,
    const std::optional<bool>& menuBarVisibility,
    const std::optional<bool>& statusBarVisibility,
    const std::optional<bool>& toolbarsVisibility)
    : width(width), height(height), x(x), y(y),
    menuBarVisibility(menuBarVisibility), statusBarVisibility(statusBarVisibility),
    toolbarsVisibility(toolbarsVisibility)
  {}

  WindowFeatures::WindowFeatures(const wil::com_ptr<ICoreWebView2WindowFeatures> features)
  {
    UINT32 _x = 0;
    UINT32 _y = 0;
    UINT32 _height = 0;
    UINT32 _width = 0;
    BOOL _menuBarVisibility = FALSE;
    BOOL _statusBarVisibility = FALSE;
    BOOL _toolbarsVisibility = FALSE;

    if (SUCCEEDED(features->get_Left(&_x))) {
      x = static_cast<double>(_x);
    }
    if (SUCCEEDED(features->get_Top(&_y))) {
      y = static_cast<double>(_y);
    }
    if (SUCCEEDED(features->get_Height(&_height))) {
      height = static_cast<double>(_height);
    }
    if (SUCCEEDED(features->get_Width(&_width))) {
      width = static_cast<double>(_width);
    }
    if (SUCCEEDED(features->get_ShouldDisplayMenuBar(&_menuBarVisibility))) {
      menuBarVisibility = static_cast<bool>(_menuBarVisibility);
    }
    if (SUCCEEDED(features->get_ShouldDisplayStatus(&_statusBarVisibility))) {
      statusBarVisibility = static_cast<bool>(_statusBarVisibility);
    }
    if (SUCCEEDED(features->get_ShouldDisplayToolbar(&_toolbarsVisibility))) {
      toolbarsVisibility = static_cast<bool>(_toolbarsVisibility);
    }
  }

  flutter::EncodableMap WindowFeatures::toEncodableMap() const
  {
    return flutter::EncodableMap{
      {"width", make_fl_value(width)},
      {"height", make_fl_value(height)},
      {"x", make_fl_value(x)},
      {"y", make_fl_value(y)},
      {"menuBarVisibility", make_fl_value(menuBarVisibility)},
      {"statusBarVisibility", make_fl_value(statusBarVisibility)},
      {"toolbarsVisibility", make_fl_value(toolbarsVisibility)}
    };
  }
}