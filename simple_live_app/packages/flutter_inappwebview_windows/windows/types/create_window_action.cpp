#include "../utils/flutter.h"
#include "create_window_action.h"

namespace flutter_inappwebview_plugin
{
  CreateWindowAction::CreateWindowAction(std::shared_ptr<URLRequest> request, const int64_t& windowId,
    const bool& isForMainFrame, const std::optional<bool>& hasGesture, const std::optional<std::shared_ptr<WindowFeatures>> windowFeatures)
    : request(std::move(request)), windowId(windowId), isForMainFrame(isForMainFrame),
    hasGesture(hasGesture), windowFeatures(std::move(windowFeatures))
  {}

  flutter::EncodableMap CreateWindowAction::toEncodableMap() const
  {
    return flutter::EncodableMap{
      {"request", request->toEncodableMap()},
      {"isForMainFrame", isForMainFrame},
      {"windowId", windowId},
      {"hasGesture", make_fl_value(hasGesture)},
      {"windowFeatures", windowFeatures.has_value() ? windowFeatures.value()->toEncodableMap() : make_fl_value()}
    };
  }
}