#include "../utils/flutter.h"
#include "../utils/log.h"
#include "../utils/strconv.h"
#include "../utils/string.h"
#include "headless_in_app_webview.h"
#include "headless_webview_channel_delegate.h"

#include "headless_in_app_webview_manager.h"

namespace flutter_inappwebview_plugin
{
  HeadlessWebViewChannelDelegate::HeadlessWebViewChannelDelegate(HeadlessInAppWebView* webView, flutter::BinaryMessenger* messenger)
    : webView(webView), ChannelDelegate(messenger, HeadlessInAppWebView::METHOD_CHANNEL_NAME_PREFIX + variant_to_string(webView->id))
  {}

  void HeadlessWebViewChannelDelegate::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    if (!webView) {
      result->Success();
      return;
    }

    // auto& arguments = std::get<flutter::EncodableMap>(*method_call.arguments());
    auto& methodName = method_call.method_name();

    if (string_equals(methodName, "dispose")) {
      if (webView->plugin && webView->plugin->headlessInAppWebViewManager) {
        std::map<std::string, std::unique_ptr<HeadlessInAppWebView>>& webViews = webView->plugin->headlessInAppWebViewManager->webViews;
        auto& id = webView->id;
        if (map_contains(webViews, id)) {
          if (webView->channelDelegate && webView->plugin->isEngineAvailable()) {
            webView->channelDelegate->UnregisterMethodCallHandler();
            if (webView->webView && webView->webView->channelDelegate) {
              webView->webView->channelDelegate->UnregisterMethodCallHandler();
            }
          }
          webViews.erase(id);
        }
      }
      result->Success();
    }
    else {
      result->NotImplemented();
    }
  }

  void HeadlessWebViewChannelDelegate::onWebViewCreated() const
  {
    if (!channel) {
      return;
    }

    channel->InvokeMethod("onWebViewCreated", nullptr);
  }

  HeadlessWebViewChannelDelegate::~HeadlessWebViewChannelDelegate()
  {
    debugLog("dealloc HeadlessWebViewChannelDelegate");
    webView = nullptr;
  }
}
