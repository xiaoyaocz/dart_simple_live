#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_IN_APP_WEBVIEW_SETTINGS_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_IN_APP_WEBVIEW_SETTINGS_H_

#include <string>

namespace flutter_inappwebview_plugin
{
  class InAppWebView;

  class InAppWebViewSettings
  {
  public:
    bool useShouldOverrideUrlLoading = false;
    bool useOnLoadResource = false;
    bool useOnDownloadStart = false;
    bool useShouldInterceptRequest = false;
    std::string userAgent;
    bool javaScriptEnabled = true;
    bool transparentBackground = false;
    bool supportZoom = true;
    bool isInspectable = true;
    bool disableContextMenu = false;
    bool incognito = false;

    InAppWebViewSettings();
    InAppWebViewSettings(const flutter::EncodableMap& encodableMap);
    ~InAppWebViewSettings();

    flutter::EncodableMap toEncodableMap() const;
    flutter::EncodableMap getRealSettings(const InAppWebView* inAppWebView) const;
  };
}
#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_IN_APP_WEBVIEW_SETTINGS_H_