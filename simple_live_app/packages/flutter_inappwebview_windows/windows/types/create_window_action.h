#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_CREATE_WINDOW_ACTION_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_CREATE_WINDOW_ACTION_H_

#include <flutter/standard_method_codec.h>
#include <optional>

#include "url_request.h"
#include "window_features.h"

namespace flutter_inappwebview_plugin
{
  class CreateWindowAction
  {
  public:
    const std::shared_ptr<URLRequest> request;
    const int64_t windowId;
    const bool isForMainFrame;
    const std::optional<bool> hasGesture;
    const std::optional<std::shared_ptr<WindowFeatures>> windowFeatures;

    CreateWindowAction(std::shared_ptr<URLRequest> request, const int64_t& windowId, const bool& isForMainFrame, const std::optional<bool>& hasGesture, const std::optional<std::shared_ptr<WindowFeatures>> windowFeatures);
    ~CreateWindowAction() = default;

    flutter::EncodableMap toEncodableMap() const;
  };
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_CREATE_WINDOW_ACTION_H_