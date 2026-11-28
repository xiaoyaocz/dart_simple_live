#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_SSL_CERTIFICATE_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_SSL_CERTIFICATE_H_

#include <flutter/standard_method_codec.h>

namespace flutter_inappwebview_plugin
{
  class SslCertificate
  {
  public:
    const std::string x509Certificate;

    SslCertificate(std::string x509Certificate);
    ~SslCertificate() = default;

    flutter::EncodableMap toEncodableMap() const;
  };
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_SSL_CERTIFICATE_H_