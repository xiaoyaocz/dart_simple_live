#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_WINDOW_FEATURES_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_WINDOW_FEATURES_H_

#include <flutter/standard_method_codec.h>
#include <optional>
#include <WebView2.h>
#include <wil/com.h>

namespace flutter_inappwebview_plugin
{
  class WindowFeatures
  {
  public:
    std::optional<double> width;
    std::optional<double> height;
    std::optional<double> x;
    std::optional<double> y;
    std::optional<bool> menuBarVisibility;
    std::optional<bool> statusBarVisibility;
    std::optional<bool> toolbarsVisibility;

    WindowFeatures(const std::optional<double>& width,
      const std::optional<double>& height,
      const std::optional<double>& x,
      const std::optional<double>& y,
      const std::optional<bool>& menuBarVisibility,
      const std::optional<bool>& statusBarVisibility,
      const std::optional<bool>& toolbarsVisibility);

    WindowFeatures(wil::com_ptr<ICoreWebView2WindowFeatures> features);

    ~WindowFeatures() = default;

    flutter::EncodableMap toEncodableMap() const;
  };
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_WINDOW_FEATURES_H_