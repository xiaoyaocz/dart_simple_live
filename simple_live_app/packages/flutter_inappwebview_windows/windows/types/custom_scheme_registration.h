#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_CUSTOM_SCHEME_REGISTRATION_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_CUSTOM_SCHEME_REGISTRATION_H_

#include <flutter/standard_method_codec.h>
#include <optional>
#include <WebView2EnvironmentOptions.h>

namespace flutter_inappwebview_plugin
{
  class CustomSchemeRegistration
  {
  public:
    const std::string scheme;
    const std::optional<std::vector<std::string>> allowedOrigins;
    const std::optional<bool> treatAsSecure;
    const std::optional<bool> hasAuthorityComponent;

    CustomSchemeRegistration(const std::string& scheme, const std::optional<std::vector<std::string>>& allowedOrigins, const std::optional<bool>& treatAsSecure, const std::optional<bool>& hasAuthorityComponent);
    CustomSchemeRegistration(const flutter::EncodableMap& map);
    ~CustomSchemeRegistration() = default;

    flutter::EncodableMap toEncodableMap() const;
    CoreWebView2CustomSchemeRegistration* toWebView2CustomSchemeRegistration() const;
  };
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_CUSTOM_SCHEME_REGISTRATION_H_