#include "../utils/log.h"
#include "in_app_browser.h"
#include "in_app_browser_channel_delegate.h"

namespace flutter_inappwebview_plugin
{
  InAppBrowserChannelDelegate::InAppBrowserChannelDelegate(const std::string& id, flutter::BinaryMessenger* messenger)
    : ChannelDelegate(messenger, InAppBrowser::METHOD_CHANNEL_NAME_PREFIX + id)
  {}

  void InAppBrowserChannelDelegate::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    result->NotImplemented();
  }

  void InAppBrowserChannelDelegate::onBrowserCreated() const
  {
    if (!channel) {
      return;
    }
    channel->InvokeMethod("onBrowserCreated", nullptr);
  }

  void InAppBrowserChannelDelegate::onExit() const
  {
    if (!channel) {
      return;
    }
    channel->InvokeMethod("onExit", nullptr);
  }

  InAppBrowserChannelDelegate::~InAppBrowserChannelDelegate()
  {
    debugLog("dealloc InAppBrowserChannelDelegate");
  }
}