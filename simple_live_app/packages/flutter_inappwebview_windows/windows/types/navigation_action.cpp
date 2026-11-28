#include "../utils/flutter.h"
#include "navigation_action.h"

namespace flutter_inappwebview_plugin
{
  NavigationAction::NavigationAction(std::shared_ptr<URLRequest> request, const bool& isForMainFrame,
    const std::optional<bool>& isRedirect, const std::optional<NavigationActionType>& navigationType)
    : request(std::move(request)), isForMainFrame(isForMainFrame),
    isRedirect(isRedirect), navigationType(navigationType)
  {}

  flutter::EncodableMap NavigationAction::toEncodableMap() const
  {
    return flutter::EncodableMap{
      {"request", request->toEncodableMap()},
      {"isForMainFrame", isForMainFrame},
      {"isRedirect", make_fl_value(isRedirect)},
      {"navigationType", make_fl_value(navigationType)}
    };
  }
}