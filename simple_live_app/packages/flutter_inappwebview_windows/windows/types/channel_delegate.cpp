#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "../utils/util.h"
#include "channel_delegate.h"

namespace flutter_inappwebview_plugin
{
  ChannelDelegate::ChannelDelegate(flutter::BinaryMessenger* messenger, const std::string& name) : messenger(messenger)
  {
    channel = std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
      this->messenger, name,
      &flutter::StandardMethodCodec::GetInstance()
    );
    channel->SetMethodCallHandler(
      [this](const auto& call, auto result)
      {
        this->HandleMethodCall(call, std::move(result));
      });
  }

  void ChannelDelegate::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {}

  void ChannelDelegate::UnregisterMethodCallHandler() const
  {
    if (channel) {
      channel->SetMethodCallHandler(nullptr);
    }
  }

  ChannelDelegate::~ChannelDelegate()
  {
    messenger = nullptr;
    channel.reset();
  }
}