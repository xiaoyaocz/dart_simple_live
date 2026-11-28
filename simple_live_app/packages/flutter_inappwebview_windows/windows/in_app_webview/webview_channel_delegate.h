#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_WEBVIEW_CHANNEL_DELEGATE_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_WEBVIEW_CHANNEL_DELEGATE_H_

#include <flutter/method_channel.h>
#include <flutter/standard_message_codec.h>

#include "../types/base_callback_result.h"
#include "../types/channel_delegate.h"
#include "../types/create_window_action.h"
#include "../types/custom_scheme_response.h"
#include "../types/navigation_action.h"
#include "../types/permission_response.h"
#include "../types/web_resource_error.h"
#include "../types/web_resource_request.h"
#include "../types/web_resource_response.h"

namespace flutter_inappwebview_plugin
{
  class InAppWebView;

  enum NavigationActionPolicy { cancel = 0, allow = 1 };

  class WebViewChannelDelegate : public ChannelDelegate
  {
  public:
    InAppWebView* webView;

    class ShouldOverrideUrlLoadingCallback : public BaseCallbackResult<const NavigationActionPolicy> {
    public:
      ShouldOverrideUrlLoadingCallback();
      ~ShouldOverrideUrlLoadingCallback() = default;
    };

    class CallJsHandlerCallback : public BaseCallbackResult<const flutter::EncodableValue*> {
    public:
      CallJsHandlerCallback();
      ~CallJsHandlerCallback() = default;
    };

    class CreateWindowCallback : public BaseCallbackResult<const bool> {
    public:
      CreateWindowCallback();
      ~CreateWindowCallback() = default;
    };

    class PermissionRequestCallback : public BaseCallbackResult<const std::shared_ptr<PermissionResponse>> {
    public:
      PermissionRequestCallback();
      ~PermissionRequestCallback() = default;
    };

    class ShouldInterceptRequestCallback : public BaseCallbackResult<const std::shared_ptr<WebResourceResponse>> {
    public:
      ShouldInterceptRequestCallback();
      ~ShouldInterceptRequestCallback() = default;
    };

    class LoadResourceWithCustomSchemeCallback : public BaseCallbackResult<const std::shared_ptr<CustomSchemeResponse>> {
    public:
      LoadResourceWithCustomSchemeCallback();
      ~LoadResourceWithCustomSchemeCallback() = default;
    };

    WebViewChannelDelegate(InAppWebView* webView, flutter::BinaryMessenger* messenger);
    WebViewChannelDelegate(InAppWebView* webView, flutter::BinaryMessenger* messenger, const std::string& name);
    ~WebViewChannelDelegate();

    void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    void onLoadStart(const std::optional<std::string>& url) const;
    void onLoadStop(const std::optional<std::string>& url) const;
    void onProgressChanged(const int64_t& progress) const;
    void shouldOverrideUrlLoading(std::shared_ptr<NavigationAction> navigationAction, std::unique_ptr<ShouldOverrideUrlLoadingCallback> callback) const;
    void onReceivedError(std::shared_ptr<WebResourceRequest> request, std::shared_ptr<WebResourceError> error) const;
    void onReceivedHttpError(std::shared_ptr<WebResourceRequest> request, std::shared_ptr<WebResourceResponse> error) const;
    void onTitleChanged(const std::optional<std::string>& title) const;
    void onUpdateVisitedHistory(const std::optional<std::string>& url, const std::optional<bool>& isReload) const;
    void onCallJsHandler(const std::string& handlerName, const std::string& args, std::unique_ptr<CallJsHandlerCallback> callback) const;
    void onConsoleMessage(const std::string& message, const int64_t& messageLevel) const;
    void onDevToolsProtocolEventReceived(const std::string& eventName, const std::string& data) const;
    void onCreateWindow(std::shared_ptr<CreateWindowAction> createWindowAction, std::unique_ptr<CreateWindowCallback> callback) const;
    void onCloseWindow() const;
    void onPermissionRequest(const std::string& origin, const std::vector<int64_t>& resources, std::unique_ptr<PermissionRequestCallback> callback) const;
    void shouldInterceptRequest(std::shared_ptr<WebResourceRequest> request, std::unique_ptr<ShouldInterceptRequestCallback> callback) const;
    void onLoadResourceWithCustomScheme(std::shared_ptr<WebResourceRequest> request, std::unique_ptr<LoadResourceWithCustomSchemeCallback> callback) const;
  };
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_WEBVIEW_CHANNEL_DELEGATE_H_