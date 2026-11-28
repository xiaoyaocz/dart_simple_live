#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_UTIL_STRING_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_UTIL_STRING_H_

#include <algorithm>
#include <numeric>
#include <optional>
#include <string>
#include <vector>

#include "strconv.h"

namespace flutter_inappwebview_plugin
{
  template <typename T>
  struct is_string
    : std::false_type
  {};

  // Partial specialization - parameters used to qualify the specialization
  template <typename CharT, typename TraitsT, typename AllocT>
  struct is_string<std::basic_string<CharT, TraitsT, AllocT>>
    : std::true_type
  {};

  template <typename T>
  using is_basic_string = is_string<std::remove_cv_t<T>>;

  template <typename T>
  static inline bool string_equals(const std::basic_string<T>& s1, const std::basic_string<T>& s2)
  {
    return s1.compare(s2) == 0;
  }

  template <typename T>
  static inline bool string_equals(const std::basic_string<T>& s1, const char* s2)
  {
    return s1.compare(s2) == 0;
  }

  template <typename T>
  static inline bool string_equals(const char* s1, const std::basic_string<T>& s2)
  {
    return s2.compare(s1) == 0;
  }

  static inline bool string_equals(const std::string& s1, const std::wstring& s2)
  {
    return string_equals(s1, wide_to_utf8(s2));
  }

  static inline bool string_equals(const std::wstring& s1, const std::string& s2)
  {
    return string_equals(wide_to_utf8(s1), s2);
  }

  template <typename T>
  static inline bool string_equals(const std::optional<std::basic_string<T>>& s1, const std::basic_string<T>& s2)
  {
    return s1.has_value() ? string_equals(s1.value(), s2) : false;
  }

  template <typename T>
  static inline bool string_equals(const std::basic_string<T>& s1, const std::optional<std::basic_string<T>>& s2)
  {
    return s2.has_value() ? string_equals(s1, s2.value()) : false;
  }

  template <typename T>
  static inline bool string_equals(const std::optional<std::basic_string<T>>& s1, const std::optional<std::basic_string<T>>& s2)
  {
    return s1.has_value() && s2.has_value() ? string_equals(s1.value(), s2.value()) : true;
  }

  static inline void replace_all(std::string& source, const std::string& from, const std::string& to)
  {
    std::string newString;
    newString.reserve(source.length());  // avoids a few memory allocations

    std::string::size_type lastPos = 0;
    std::string::size_type findPos;

    while (std::string::npos != (findPos = source.find(from, lastPos))) {
      newString.append(source, lastPos, findPos - lastPos);
      newString += to;
      lastPos = findPos + from.length();
    }

    // Care for the rest after last occurrence
    newString += source.substr(lastPos);

    source.swap(newString);
  }

  static inline std::string replace_all_copy(const std::string& source, const std::string& from, const std::string& to)
  {
    std::string newString;
    newString.reserve(source.length());  // avoids a few memory allocations

    std::string::size_type lastPos = 0;
    std::string::size_type findPos;

    while (std::string::npos != (findPos = source.find(from, lastPos))) {
      newString.append(source, lastPos, findPos - lastPos);
      newString += to;
      lastPos = findPos + from.length();
    }

    // Care for the rest after last occurrence
    newString += source.substr(lastPos);

    return newString;
  }

  template <typename T>
  static inline std::basic_string<T> join(const std::vector<std::basic_string<T>>& vec, const std::basic_string<T>& delim)
  {
    return vec.empty() ? std::basic_string<T>{ "" } : /* leave early if there are no items in the list */
      std::accumulate( /* otherwise, accumulate */
        ++vec.begin(), vec.end(), /* the range 2nd to after-last */
        *vec.begin(), /* and start accumulating with the first item */
        [delim](auto& a, auto& b) { return a + delim + b; });
  }

  template <typename T>
  static inline std::basic_string<T> join(const std::vector<std::basic_string<T>>& vec, const char* delim)
  {
    return join(vec, std::basic_string<T>{ delim });
  }

  template <typename T>
  static inline std::vector<std::basic_string<T>> split(const std::basic_string<T>& s, std::basic_string<T> delimiter)
  {
    size_t pos_start = 0, pos_end, delim_len = delimiter.length();
    std::basic_string<T> token;
    std::vector<std::basic_string<T>> res;

    while ((pos_end = s.find(delimiter, pos_start)) != std::basic_string<T>::npos) {
      token = s.substr(pos_start, pos_end - pos_start);
      pos_start = pos_end + delim_len;
      res.push_back(token);
    }

    res.push_back(s.substr(pos_start));
    return res;
  }

  template <typename T>
  void to_lowercase(const std::basic_string<T>& s)
  {
    std::transform(s.begin(), s.end(), s.begin(),
      [](const T v) { return static_cast<T>(std::tolower(v)); });
  }

  template <typename T>
  std::basic_string<T> to_lowercase_copy(const std::basic_string<T>& s)
  {
    std::basic_string<T> s2 = s;
    std::transform(s2.begin(), s2.end(), s2.begin(),
      [](const T v) { return static_cast<T>(std::tolower(v)); });
    return s2;
  }

  template <typename T>
  void to_uppercase(const std::basic_string<T>& s)
  {
    std::transform(s.begin(), s.end(), s.begin(),
      [](const T v) { return static_cast<T>(std::toupper(v)); });
    return s2;
  }

  template <typename T>
  std::basic_string<T> to_uppercase_copy(const std::basic_string<T>& s)
  {
    std::basic_string<T> s2 = s;
    std::transform(s2.begin(), s2.end(), s2.begin(),
      [](const T v) { return static_cast<T>(std::toupper(v)); });
    return s2;
  }

  template <typename T>
  bool starts_with(const std::basic_string<T>& str, const std::basic_string<T>& prefix)
  {
    return str.size() >= prefix.size() && str.compare(0, prefix.size(), prefix) == 0;
  }

  template <typename T>
  bool ends_with(const std::basic_string<T>& str, const std::basic_string<T>& suffix)
  {
    return str.size() >= suffix.size() && str.compare(str.size() - suffix.size(), suffix.size(), suffix) == 0;
  }
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_UTIL_STRING_H_