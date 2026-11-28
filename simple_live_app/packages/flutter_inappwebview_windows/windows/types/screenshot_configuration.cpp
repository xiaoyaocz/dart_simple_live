#include "../utils/flutter.h"
#include "../utils/map.h"
#include "screenshot_configuration.h"

namespace flutter_inappwebview_plugin
{
  CompressFormat CompressFormatFromString(const std::string& compressFormat)
  {
    if (string_equals(compressFormat, "PNG")) {
      return CompressFormat::png;
    }
    else if (string_equals(compressFormat, "JPEG")) {
      return CompressFormat::jpeg;
    }
    else if (string_equals(compressFormat, "WEBP")) {
      return CompressFormat::webp;
    }
    return CompressFormat::png;
  }

  std::string CompressFormatToString(const CompressFormat& compressFormat)
  {
    switch (compressFormat) {
    case CompressFormat::jpeg:
      return "JPEG";
    case CompressFormat::webp:
      return "WEBP";
    case CompressFormat::png:
    default:
      return "PNG";
    }
  }

  ScreenshotConfiguration::ScreenshotConfiguration(
    const CompressFormat& compressFormat,
    const int64_t& quality,
    const std::optional<std::shared_ptr<Rect>> rect
  ) : compressFormat(compressFormat), quality(quality), rect(rect)
  {}

  ScreenshotConfiguration::ScreenshotConfiguration(const flutter::EncodableMap& map)
    : compressFormat(CompressFormatFromString(get_fl_map_value<std::string>(map, "compressFormat"))),
    quality(get_fl_map_value<int>(map, "quality")),
    rect(fl_map_contains_not_null(map, "rect") ? std::make_shared<Rect>(get_fl_map_value<flutter::EncodableMap>(map, "rect")) : std::optional<std::shared_ptr<Rect>>{})
  {}

  ScreenshotConfiguration::~ScreenshotConfiguration() {}
}