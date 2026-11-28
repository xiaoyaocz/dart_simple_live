#include "permission_response.h"

namespace flutter_inappwebview_plugin
{
  PermissionResponse::PermissionResponse(const std::optional<std::vector<int64_t>>& resources, const std::optional<PermissionResponseActionType>& action)
    : resources(resources), action(action)
  {}

  PermissionResponse::PermissionResponse(const flutter::EncodableMap& map)
    : resources(get_optional_fl_map_value<std::vector<int64_t>>(map, "resources")),
    action(PermissionResponseActionTypeFromInteger(get_optional_fl_map_value<int64_t>(map, "action")))
  {}

  flutter::EncodableMap PermissionResponse::toEncodableMap() const
  {
    return flutter::EncodableMap{
      {"resources", make_fl_value(resources)},
      {"action", make_fl_value(action)},
    };
  }
}