#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_UTIL_MAP_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_UTIL_MAP_H_

#include <algorithm>
#include <iterator>
#include <map>
#include <optional>

namespace flutter_inappwebview_plugin
{
  template<typename T, typename U = void>
  struct is_mappish_impl : std::false_type { };

  template<typename T>
  struct is_mappish_impl<T, std::void_t<typename T::key_type,
    typename T::mapped_type,
    decltype(std::declval<T&>()[std::declval<const typename T::key_type&>()])>>
    : std::true_type { };

  template<typename T>
  struct is_mappish : is_mappish_impl<T>::type { };

  template<typename K, typename T>
  static inline bool map_contains(const std::map<K, T>& map, const K& key)
  {
    return map.find(key) != map.end();
  }

  template<typename K, typename T>
  static inline T map_at_or_null(const std::map<K, T>& map, const K& key)
  {
    auto itr = map.find(key);
    return itr != map.end() ? itr->second : nullptr;
  }
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_UTIL_MAP_H_