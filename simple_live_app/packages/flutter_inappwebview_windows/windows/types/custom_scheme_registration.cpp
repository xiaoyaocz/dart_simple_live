#include "../utils/flutter.h"
#include "../utils/strconv.h"
#include "custom_scheme_registration.h"

namespace flutter_inappwebview_plugin
{
  CustomSchemeRegistration::CustomSchemeRegistration(const std::string& scheme, const std::optional<std::vector<std::string>>& allowedOrigins,
    const std::optional<bool>& treatAsSecure, const std::optional<bool>& hasAuthorityComponent)
    : scheme(scheme), allowedOrigins(allowedOrigins), treatAsSecure(treatAsSecure), hasAuthorityComponent(hasAuthorityComponent)
  {}

  CustomSchemeRegistration::CustomSchemeRegistration(const flutter::EncodableMap& map)
    : scheme(get_fl_map_value<std::string>(map, "scheme")),
    allowedOrigins(get_optional_fl_map_value<std::vector<std::string>>(map, "allowedOrigins")),
    treatAsSecure(get_optional_fl_map_value<bool>(map, "treatAsSecure")),
    hasAuthorityComponent(get_optional_fl_map_value<bool>(map, "hasAuthorityComponent"))
  {}

  flutter::EncodableMap CustomSchemeRegistration::toEncodableMap() const
  {
    return flutter::EncodableMap{
      {"scheme", make_fl_value(scheme)},
      {"allowedOrigins", make_fl_value(allowedOrigins)},
      {"treatAsSecure", make_fl_value(treatAsSecure)},
      {"hasAuthorityComponent", make_fl_value(hasAuthorityComponent)}
    };
  }

  CoreWebView2CustomSchemeRegistration* CustomSchemeRegistration::toWebView2CustomSchemeRegistration() const
  {
    auto customSchemeRegistration = Microsoft::WRL::Make<CoreWebView2CustomSchemeRegistration>(utf8_to_wide(scheme).c_str());

    if (allowedOrigins.has_value()) {
      std::vector<const WCHAR*> wideAllowedOrigins;
      for (const auto& origin : allowedOrigins.value()) {
        wideAllowedOrigins.push_back(utf8_to_wide(origin).c_str());
      }
      customSchemeRegistration->SetAllowedOrigins(
        static_cast<UINT32>(wideAllowedOrigins.size()),
        wideAllowedOrigins.data());
    }

    if (treatAsSecure.has_value()) {
      customSchemeRegistration->put_TreatAsSecure(treatAsSecure.value());
    }

    if (hasAuthorityComponent.has_value()) {
      customSchemeRegistration->put_HasAuthorityComponent(hasAuthorityComponent.value());
    }

    customSchemeRegistration->AddRef();
    return customSchemeRegistration.Get();
  }

}