#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_CHANNEL_DELEGATE_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_CHANNEL_DELEGATE_H_

#include <flutter/method_channel.h>

namespace flutter_inappwebview_plugin
{
  class ChannelDelegate
  {
    using FlutterMethodChannel = std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>>;

  public:
    FlutterMethodChannel channel;
    flutter::BinaryMessenger* messenger;

    ChannelDelegate(flutter::BinaryMessenger* messenger, const std::string& name);
    virtual ~ChannelDelegate();

    virtual void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    void UnregisterMethodCallHandler() const;
  };
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_CHANNEL_DELEGATE_H_