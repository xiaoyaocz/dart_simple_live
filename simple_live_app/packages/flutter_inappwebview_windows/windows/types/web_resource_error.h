#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_WEB_RESOURCE_ERROR_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_WEB_RESOURCE_ERROR_H_

#include <flutter/standard_method_codec.h>
#include <optional>

namespace flutter_inappwebview_plugin
{
  static const std::string WebErrorStatusDescription[] =
  {
      "Indicates that an unknown error occurred.",
      "Indicates that the SSL certificate common name does not match the web address.",
      "Indicates that the SSL certificate has expired.",
      "Indicates that the SSL client certificate contains errors.",
      "Indicates that the SSL certificate has been revoked.",
      "Indicates that the SSL certificate is not valid.",
      "Indicates that the host is unreachable.",
      "Indicates that the connection has timed out.",
      "Indicates that the server returned an invalid or unrecognized response.",
      "Indicates that the connection was stopped.",
      "Indicates that the connection was reset.",
      "Indicates that the Internet connection has been lost.",
      "Indicates that a connection to the destination was not established.",
      "Indicates that the provided host name was not able to be resolved.",
      "Indicates that the operation was canceled.",
      "Indicates that the request redirect failed.",
      "Indicates that an unexpected error occurred.",
      "Indicates that user is prompted with a login, waiting on user action.",
      "Indicates that user lacks proper authentication credentials for a proxy server.",
  };

  class WebResourceError
  {
  public:
    const std::string description;
    const int64_t type;

    WebResourceError(const std::string& description, const int64_t type);
    WebResourceError(const flutter::EncodableMap& map);
    ~WebResourceError() = default;

    flutter::EncodableMap toEncodableMap() const;
  };
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_WEB_RESOURCE_ERROR_H_