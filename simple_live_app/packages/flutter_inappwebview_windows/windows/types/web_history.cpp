#include "../utils/vector.h"
#include "web_history.h"

namespace flutter_inappwebview_plugin
{
  WebHistory::WebHistory(const std::optional<int64_t> currentIndex, const std::optional<std::vector<std::shared_ptr<WebHistoryItem>>>& list)
    : currentIndex(currentIndex), list(list)
  {}

  WebHistory::WebHistory(const flutter::EncodableMap& map)
    : currentIndex(get_optional_fl_map_value<int64_t>(map, "currentIndex")),
    list(functional_map(get_optional_fl_map_value<flutter::EncodableList>(map, "list"), [](const flutter::EncodableValue& m) { return std::make_shared<WebHistoryItem>(std::get<flutter::EncodableMap>(m)); }))
  {}

  flutter::EncodableMap WebHistory::toEncodableMap() const
  {
    return flutter::EncodableMap{
      {"currentIndex", make_fl_value(currentIndex)},
      {"list", make_fl_value(functional_map(list, [](const std::shared_ptr<WebHistoryItem>& item) { return item->toEncodableMap(); }))}
    };
  }
}