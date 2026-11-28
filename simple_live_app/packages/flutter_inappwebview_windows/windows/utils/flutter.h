#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_UTIL_FLUTTER_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_UTIL_FLUTTER_H_

#include <flutter/encodable_value.h>

#include "map.h"
#include "util.h"
#include "vector.h"

namespace flutter_inappwebview_plugin
{
  static inline flutter::EncodableValue make_fl_value()
  {
    return flutter::EncodableValue();
  }

  template<typename T>
  static inline flutter::EncodableValue make_fl_value(const T& val)
  {
    return flutter::EncodableValue(val);
  }

  template<typename T>
  static inline flutter::EncodableValue make_fl_value(const T* val)
  {
    return val == nullptr ? make_fl_value() : flutter::EncodableValue(val);
  }

  template<typename T>
  static inline flutter::EncodableValue make_fl_value(const std::vector<T>& vec)
  {
    auto encodableList = flutter::EncodableList{};
    for (auto const& val : vec) {
      encodableList.push_back(make_fl_value(val));
    }
    return encodableList;
  }

  template<typename K, typename T>
  static inline flutter::EncodableValue make_fl_value(const std::map<K, T>& map)
  {
    auto encodableMap = flutter::EncodableMap{};
    for (auto const& [key, val] : map) {
      encodableMap.insert({ make_fl_value(key), make_fl_value(val) });
    }
    return encodableMap;
  }

  template<typename T>
  static inline flutter::EncodableValue make_fl_value(const std::optional<T>& optional)
  {
    return optional.has_value() ? make_fl_value(optional.value()) : make_fl_value();
  }

  template<typename T>
  static inline flutter::EncodableValue make_fl_value(const std::optional<std::vector<T>>& optional)
  {
    if (!optional.has_value()) {
      return make_fl_value();
    }
    auto& vecValue = optional.value();
    auto encodableList = flutter::EncodableList{};
    for (auto const& val : vecValue) {
      encodableList.push_back(make_fl_value(val));
    }
    return encodableList;
  }

  template<typename K, typename T>
  static inline flutter::EncodableValue make_fl_value(const std::optional<std::map<K, T>>& optional)
  {
    if (!optional.has_value()) {
      return make_fl_value();
    }
    auto& mapValue = optional.value();
    auto encodableMap = flutter::EncodableMap{};
    for (auto const& [key, val] : mapValue) {
      encodableMap.insert({ make_fl_value(key), make_fl_value(val) });
    }
    return encodableMap;
  }

  static inline bool fl_map_contains(const flutter::EncodableMap& map, const char* key)
  {
    return map_contains(map, make_fl_value(key));
  }

  static inline bool fl_map_contains_not_null(const flutter::EncodableMap& map, const char* key)
  {
    return fl_map_contains(map, key) && !map.at(make_fl_value(key)).IsNull();
  }

  template<typename T, typename std::enable_if<(!std::is_same<T, int32_t>::value && !std::is_same<T, int64_t>::value), bool>::type* = nullptr>
  static inline T get_fl_map_value(const flutter::EncodableMap& map, const char* key)
  {
    return std::get<T>(map.at(make_fl_value(key)));
  }

  template<typename T, typename std::enable_if<std::is_same<T, int32_t>::value, bool>::type* = nullptr>
  static inline int64_t get_fl_map_value(const flutter::EncodableMap& map, const char* key)
  {
    return map.at(make_fl_value(key)).LongValue();
  }

  template<typename T, typename std::enable_if<std::is_same<T, int64_t>::value, bool>::type* = nullptr>
  static inline int64_t get_fl_map_value(const flutter::EncodableMap& map, const char* key)
  {
    return map.at(make_fl_value(key)).LongValue();
  }

  template<typename T, typename std::enable_if<((!is_mappish<T>::value && !is_vector<T>::value && !std::is_same<T, int32_t>::value && !std::is_same<T, int64_t>::value) ||
    std::is_same<T, flutter::EncodableMap>::value || std::is_same<T, flutter::EncodableList>::value), int>::type* = nullptr>
  static inline std::optional<T> get_optional_fl_map_value(const flutter::EncodableMap& map, const char* key)
  {
    if (fl_map_contains_not_null(map, key)) {
      auto fl_key = make_fl_value(key);
      return make_pointer_optional<T>(std::get_if<T>(&map.at(fl_key)));
    }
    return std::nullopt;
  }

  template<typename T, typename std::enable_if<std::is_same<T, int32_t>::value, bool>::type* = nullptr>
  static inline std::optional<int64_t> get_optional_fl_map_value(const flutter::EncodableMap& map, const char* key)
  {
    if (fl_map_contains_not_null(map, key)) {
      auto fl_key = make_fl_value(key);
      return std::make_optional<int64_t>(map.at(fl_key).LongValue());
    }
    return std::nullopt;
  }

  template<typename T, typename std::enable_if<std::is_same<T, int64_t>::value, bool>::type* = nullptr>
  static inline std::optional<int64_t> get_optional_fl_map_value(const flutter::EncodableMap& map, const char* key)
  {
    if (fl_map_contains_not_null(map, key)) {
      auto fl_key = make_fl_value(key);
      return std::make_optional<int64_t>(map.at(fl_key).LongValue());
    }
    return std::nullopt;
  }

  template<typename T>
  static inline T get_fl_map_value(const flutter::EncodableMap& map, const char* key, const T& defaultValue)
  {
    auto optional = get_optional_fl_map_value<T>(map, key);
    return !optional.has_value() ? defaultValue : optional.value();
  }

  template<typename T, typename std::enable_if<(is_mappish<T>::value && !std::is_same<T, flutter::EncodableMap>::value)>::type* = nullptr>
  static inline std::optional<T> get_optional_fl_map_value(const flutter::EncodableMap& map, const char* key)
  {
    using K = typename T::key_type;
    using V = typename T::mapped_type;

    auto flMap = std::get_if<flutter::EncodableMap>(&map.at(make_fl_value(key)));
    if (flMap) {
      T mapValue = {};
      for (auto itr = flMap->begin(); itr != flMap->end(); itr++) {
        mapValue.insert({ std::get<K>(itr->first),  std::get<V>(itr->second) });
      }
      return make_pointer_optional<T>(&mapValue);
    }
    return std::nullopt;
  }

  template<typename K, typename T>
  static inline std::map<K, T> get_fl_map_value(const flutter::EncodableMap& map, const char* key, const std::map<K, T>& defaultValue)
  {
    auto optional = get_optional_fl_map_value<std::map<K, T>>(map, key);
    return !optional.has_value() ? defaultValue : optional.value();
  }

  template<typename T, typename std::enable_if<(is_vector<T>::value && !std::is_same<T, flutter::EncodableList>::value), bool>::type* = nullptr>
  static inline std::optional<T> get_optional_fl_map_value(const flutter::EncodableMap& map, const char* key)
  {
    using V = typename T::value_type;

    auto flList = std::get_if<flutter::EncodableList>(&map.at(make_fl_value(key)));
    if (flList) {
      T vecValue(flList->size());
      for (auto itr = flList->begin(); itr != flList->end(); itr++) {
        vecValue.push_back(std::get<V>(*itr));
      }
      return make_pointer_optional<T>(&vecValue);
    }
    return std::nullopt;
  }

  template<typename T>
  static inline std::vector<T> get_fl_map_value(const flutter::EncodableMap& map, const char* key, const std::vector<T>& defaultValue)
  {
    auto optional = get_optional_fl_map_value<std::vector<T>>(map, key);
    return !optional.has_value() ? defaultValue : optional.value();
  }
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_UTIL_FLUTTER_H_