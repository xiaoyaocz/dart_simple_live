#include "web_history_item.h"

namespace flutter_inappwebview_plugin
{
  WebHistoryItem::WebHistoryItem(const std::optional<int64_t>& entryId, const std::optional<int64_t>& index, const std::optional<int64_t>& offset,
    const std::optional<std::string>& originalUrl, const std::optional<std::string>& title,
    const std::optional<std::string>& url)
    : entryId(entryId), index(index), offset(offset), originalUrl(originalUrl), title(title), url(url)
  {}

  WebHistoryItem::WebHistoryItem(const flutter::EncodableMap& map)
    : entryId(get_optional_fl_map_value<int64_t>(map, "entryId")),
    index(get_optional_fl_map_value<int64_t>(map, "index")),
    offset(get_optional_fl_map_value<int64_t>(map, "offset")),
    originalUrl(get_optional_fl_map_value<std::string>(map, "originalUrl")),
    title(get_optional_fl_map_value<std::string>(map, "title")),
    url(get_optional_fl_map_value<std::string>(map, "url"))
  {}

  flutter::EncodableMap WebHistoryItem::toEncodableMap() const
  {
    return flutter::EncodableMap{
      {"entryId", make_fl_value(entryId)},
      {"index", make_fl_value(index)},
      {"offset", make_fl_value(offset)},
      {"originalUrl", make_fl_value(originalUrl)},
      {"title", make_fl_value(title)},
      {"url", make_fl_value(url)}
    };
  }
}