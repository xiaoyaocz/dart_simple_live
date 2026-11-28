#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_UTIL_VECTOR_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_UTIL_VECTOR_H_

#include <algorithm>
#include <functional>
#include <iterator>
#include <optional>
#include <string>
#include <vector>

namespace flutter_inappwebview_plugin
{
  template<typename T = void, typename = void>
  struct is_vector_impl : std::false_type { };

  template<typename T>
  struct is_vector_impl<T, std::enable_if_t<
    std::is_same<T, typename std::vector<std::string>>::value>
  > : std::true_type { };

  template<typename T>
  struct is_vector_impl<T, std::enable_if_t<
    std::is_same<T, typename std::vector<typename std::iterator_traits<T>::value_type>::iterator>::value>
  > : std::true_type { };

  template<typename T>
  struct is_vector : is_vector_impl<T>::type { };

  template <typename T>
  static inline void vector_remove(std::vector<T>& vec, const T& el)
  {
    std::remove(vec.begin(), vec.end(), el);
  }

  template <typename T, typename UnaryPredicate>
  static inline void vector_remove_if(std::vector<T>& vec, UnaryPredicate&& predicate)
  {
    std::remove_if(vec.begin(), vec.end(), std::forward<UnaryPredicate>(predicate));
  }

  template <typename T>
  static inline void vector_remove_erase(std::vector<T>& vec, const T& el)
  {
    vec.erase(std::remove(vec.begin(), vec.end(), el), vec.end());
  }

  template <typename T, typename UnaryPredicate>
  static inline void vector_remove_erase_if(std::vector<T>& vec, UnaryPredicate&& predicate)
  {
    vec.erase(std::remove_if(vec.begin(), vec.end(), std::forward<UnaryPredicate>(predicate)), vec.end());
  }

  template <typename T>
  static inline bool vector_contains(const std::vector<T>& vec, const T& value)
  {
    return std::find(vec.begin(), vec.end(), value) != vec.end();
  }

  template <typename T, typename UnaryPredicate>
  static inline bool vector_contains_if(const std::vector<T>& vec, UnaryPredicate&& predicate)
  {
    return std::find_if(vec.begin(), vec.end(), std::forward<UnaryPredicate>(predicate)) != vec.end();
  }

  template <typename Iterator, typename Func>
  static inline auto functional_map(Iterator begin, Iterator end, Func&& func) ->
    std::vector<decltype(func(std::declval<typename Iterator::value_type>()))>
  {
    using value_type = decltype(func(std::declval<typename Iterator::value_type>()));

    std::vector<value_type> out_vector;
    out_vector.reserve(std::distance(begin, end));

    std::transform(begin, end, std::back_inserter(out_vector),
      std::forward<Func>(func));

    return out_vector;
  }

  template <typename T, typename Func>
  static inline auto functional_map(const T& iterable, Func&& func) ->
    std::vector<decltype(func(std::declval<typename T::value_type>()))>
  {
    return functional_map(std::begin(iterable), std::end(iterable),
      std::forward<Func>(func));
  }

  template <typename T, typename Func>
  static inline auto functional_map(const std::optional<T>& iterable, Func&& func) ->
    std::vector<decltype(func(std::declval<typename T::value_type>()))>
  {
    if (!iterable.has_value()) {
      return {};
    }
    return functional_map(iterable.value(), std::forward<Func>(func));
  }
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_UTIL_VECTOR_H_