#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_PERMISSION_RESPONSE_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_PERMISSION_RESPONSE_H_

#include <flutter/standard_method_codec.h>
#include <WebView2.h>

#include "../utils/flutter.h"

namespace flutter_inappwebview_plugin
{
  enum PermissionResponseActionType {
    deny = 0,
    grant,
    prompt
  };

  inline PermissionResponseActionType PermissionResponseActionTypeFromInteger(const std::optional<int64_t>& action)
  {
    if (!action.has_value()) {
      return PermissionResponseActionType::prompt;
    }
    switch (action.value()) {
    case 0:
      return PermissionResponseActionType::deny;
    case 1:
      return PermissionResponseActionType::grant;
    case 2:
    default:
      return PermissionResponseActionType::prompt;
    }
  }

  class PermissionResponse
  {
  public:
    const std::optional<std::vector<int64_t>> resources;
    const std::optional<PermissionResponseActionType> action;

    PermissionResponse(const  std::optional<std::vector<int64_t>>& resources, const std::optional<PermissionResponseActionType>& action);
    PermissionResponse(const flutter::EncodableMap& map);
    ~PermissionResponse() = default;

    bool PermissionResponse::operator==(const PermissionResponse& other)
    {
      return resources == other.resources && action == other.action;
    }
    bool PermissionResponse::operator!=(const PermissionResponse& other)
    {
      return !(*this == other);
    }

    flutter::EncodableMap toEncodableMap() const;
  };
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_PERMISSION_RESPONSE_H_