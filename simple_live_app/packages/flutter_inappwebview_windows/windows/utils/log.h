#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_LOG_UTIL_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_LOG_UTIL_H_

#include <comdef.h>
#include <iostream>
#include <string>
#include <type_traits>

#include "strconv.h"
#include "string.h"

namespace flutter_inappwebview_plugin
{
  template <typename T>
  static inline void debugLog(const std::basic_string<T>& msg, const bool& isError = false, const std::string& filename = "", const int& line = 0)
  {
#ifndef NDEBUG
    std::basic_string<T> debugMsg = msg;
    if (!filename.empty() && line > 0) {
      auto filenameSplit = split(filename, std::string{ "\\flutter_inappwebview_windows\\" });
      std::string reduceFilenamePath = filenameSplit.size() > 0 ? "flutter_inappwebview_windows\\" + filenameSplit.back() : filename;
      debugMsg = reduceFilenamePath + "(" + std::to_string(line) + "): " + debugMsg;
    }
    if (isError) {
      std::cerr << debugMsg << std::endl;
    }
    else {
      std::cout << debugMsg << std::endl;
    }
    OutputDebugString(utf8_to_wide("\n" + debugMsg + "\n").c_str());
#endif
  }

  static inline void debugLog(const char* msg, const bool& isError = false, const std::string& filename = "", const int& line = 0)
  {
    debugLog(std::string(msg), isError, filename, line);
  }

  static inline void debugLog(const std::wstring& msg, const bool& isError = false, const std::string& filename = "", const int& line = 0)
  {
    debugLog(wide_to_utf8(msg), isError, filename, line);
  }

  static inline void debugLog(const bool& value, const bool& isError = false, const std::string& filename = "", const int& line = 0)
  {
    debugLog(value ? "true" : "false", isError, filename, line);
  }

  template<
    typename T,
    typename = typename std::enable_if<std::is_arithmetic<T>::value, T>::type
  >
  static inline void debugLog(const T& value, const bool& isError = false, const std::string& filename = "", const int& line = 0)
  {
    debugLog(std::to_string(value), isError);
  }

  static inline std::string getHRMessage(const HRESULT& error)
  {
    return wide_to_utf8(_com_error(error).ErrorMessage());
  }

  static inline void debugLog(const HRESULT& hr, const std::string& filename = "", const int& line = 0)
  {
    auto isError = hr != S_OK;
    auto errorCode = std::to_string(hr);
    debugLog((isError ? "Error " + errorCode + ": " : "Message: ") + getHRMessage(hr), isError, filename, line);
  }

  static inline bool succeededOrLog(const HRESULT& hr, const std::string& filename = "", const int& line = 0)
  {
    if (SUCCEEDED(hr)) {
      return true;
    }
    debugLog(hr, filename, line);
    return false;
  }

  static inline bool failedAndLog(const HRESULT& hr, const std::string& filename = "", const int& line = 0)
  {
    if (FAILED(hr)) {
      debugLog(hr, filename, line);
      return true;
    }
    return false;
  }

  static inline void failedLog(const HRESULT& hr, const std::string& filename = "", const int& line = 0)
  {
    if (FAILED(hr)) {
      debugLog(hr, filename, line);
    }
  }
}

#ifndef NDEBUG
#define debugLog(value) debugLog(value, false, __FILE__, __LINE__)
#define succeededOrLog(value) succeededOrLog(value, __FILE__, __LINE__)
#define failedAndLog(value) failedAndLog(value, __FILE__, __LINE__)
#define failedLog(value) failedLog(value, __FILE__, __LINE__)
#endif

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_LOG_UTIL_H_