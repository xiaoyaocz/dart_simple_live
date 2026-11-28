#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_UTIL_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_UTIL_H_

#include <optional>
#include <string>
#include <variant>
#include <Windows.h>

namespace flutter_inappwebview_plugin
{
  template<typename T>
  static inline std::optional<T> make_pointer_optional(const T* value)
  {
    return value == nullptr ? std::nullopt : std::make_optional<T>(*value);
  }

  static inline std::string variant_to_string(const std::variant<std::string, int64_t>& var)
  {
    return std::visit([](auto&& arg)
      {
        using T = std::decay_t<decltype(arg)>;
        if constexpr (std::is_same_v<T, std::string>)
          return arg;
        else if constexpr (std::is_arithmetic_v<T>)
          return std::to_string(arg);
        else
          static_assert(always_false_v<T>, "non-exhaustive visitor!");
      }, var);
  }

  static inline float get_current_scale_factor(HWND hwnd)
  {
    auto dpi = GetDpiForWindow(hwnd);
    return dpi > 0 ? dpi / 96.0f : 1.0f;
  }
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_UTIL_H_