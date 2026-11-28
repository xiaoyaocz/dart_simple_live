#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_HEADLESS_WEBVIEW_CHANNEL_DELEGATE_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_HEADLESS_WEBVIEW_CHANNEL_DELEGATE_H_

#include "../types/channel_delegate.h"
#include <flutter/method_channel.h>

namespace flutter_inappwebview_plugin
{
  class HeadlessInAppWebView;

  class HeadlessWebViewChannelDelegate : public ChannelDelegate
  {
  public:
    HeadlessInAppWebView* webView;

    HeadlessWebViewChannelDelegate(HeadlessInAppWebView* webView, flutter::BinaryMessenger* messenger);
    ~HeadlessWebViewChannelDelegate();

    void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    void onWebViewCreated() const;
  };
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_HEADLESS_WEBVIEW_CHANNEL_DELEGATE_H_