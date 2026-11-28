#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_WEBVIEW_ENVIRONMENT_CHANNEL_DELEGATE_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_WEBVIEW_ENVIRONMENT_CHANNEL_DELEGATE_H_

#include "../types/channel_delegate.h"
#include <flutter/method_channel.h>

namespace flutter_inappwebview_plugin
{
  class WebViewEnvironment;

  class WebViewEnvironmentChannelDelegate : public ChannelDelegate
  {
  public:
    WebViewEnvironment* webViewEnvironment;

    WebViewEnvironmentChannelDelegate(WebViewEnvironment* webViewEnv, flutter::BinaryMessenger* messenger);
    ~WebViewEnvironmentChannelDelegate();

    void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  };
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_WEBVIEW_ENVIRONMENT_CHANNEL_DELEGATE_H_