#include "../utils/flutter.h"
#include "ssl_certificate.h"

namespace flutter_inappwebview_plugin
{
  SslCertificate::SslCertificate(std::string x509Certificate)
    : x509Certificate(x509Certificate)
  {}

  flutter::EncodableMap SslCertificate::toEncodableMap() const
  {
    return flutter::EncodableMap{
      {"x509Certificate", make_fl_value(x509Certificate)}
    };
  }
}