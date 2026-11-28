#include "../utils/flutter.h"
#include "../utils/log.h"
#include "../utils/string.h"
#include "in_app_browser_settings.h"

#include "in_app_browser.h"

namespace flutter_inappwebview_plugin
{
  namespace
  {
    InAppBrowserWindowType inAppBrowserWindowTypeFromString(const std::string& s)
    {
      if (string_equals(s, "CHILD")) {
        return InAppBrowserWindowType::child;
      }
      return InAppBrowserWindowType::window;
    }

    std::string inAppBrowserWindowTypeToString(const InAppBrowserWindowType& t)
    {
      switch (t) {
      case InAppBrowserWindowType::child:
        return "CHILD";
      default:
        return "WINDOW";
      }
    }
  }

  InAppBrowserSettings::InAppBrowserSettings() {};

  InAppBrowserSettings::InAppBrowserSettings(const flutter::EncodableMap& encodableMap)
  {
    hidden = get_fl_map_value(encodableMap, "hidden", hidden);
    windowType = inAppBrowserWindowTypeFromString(get_fl_map_value<std::string>(encodableMap, "windowType", inAppBrowserWindowTypeToString(InAppBrowserWindowType::window)));
    toolbarTopFixedTitle = get_fl_map_value(encodableMap, "toolbarTopFixedTitle", toolbarTopFixedTitle);
    windowAlphaValue = get_fl_map_value(encodableMap, "windowAlphaValue", windowAlphaValue);
    auto windowFrameMap = get_optional_fl_map_value<flutter::EncodableMap>(encodableMap, "windowFrame");
    if (windowFrameMap.has_value()) {
      windowFrame = std::make_shared<Rect>(windowFrameMap.value());
    }
  }

  flutter::EncodableMap InAppBrowserSettings::toEncodableMap() const
  {
    return flutter::EncodableMap{
      {"hidden", hidden},
      {"windowType", inAppBrowserWindowTypeToString(windowType)},
      {"toolbarTopFixedTitle", toolbarTopFixedTitle},
      {"windowAlphaValue", windowAlphaValue},
      {"windowFrame", windowFrame ? windowFrame->toEncodableMap() : make_fl_value()},
    };
  }

  flutter::EncodableMap InAppBrowserSettings::getRealSettings(const InAppBrowser* inAppBrowser) const
  {
    auto settingsMap = toEncodableMap();
    settingsMap["hidden"] = inAppBrowser->isHidden();

    BYTE alphaValue = 0;
    GetLayeredWindowAttributes(inAppBrowser->getHWND(), nullptr, &alphaValue, nullptr);
    settingsMap["windowAlphaValue"] = (double)alphaValue;

    RECT position;
    GetWindowRect(inAppBrowser->getHWND(), &position);
    settingsMap["windowFrame"] = std::make_unique<Rect>(position.left, position.top, position.right - position.left, position.bottom - position.top)->toEncodableMap();

    return settingsMap;
  }

  InAppBrowserSettings::~InAppBrowserSettings()
  {
    debugLog("dealloc InAppBrowserSettings");
  };
}
