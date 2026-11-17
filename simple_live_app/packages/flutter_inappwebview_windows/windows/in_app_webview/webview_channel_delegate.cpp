#include "../in_app_browser/in_app_browser.h"
#include "../types/base_callback_result.h"
#include "../types/content_world.h"
#include "../utils/flutter.h"
#include "../utils/log.h"
#include "../utils/strconv.h"
#include "../utils/string.h"
#include "in_app_webview.h"
#include "webview_channel_delegate.h"

namespace flutter_inappwebview_plugin
{
  WebViewChannelDelegate::WebViewChannelDelegate(InAppWebView* webView, flutter::BinaryMessenger* messenger)
    : webView(webView), ChannelDelegate(messenger, InAppWebView::METHOD_CHANNEL_NAME_PREFIX + variant_to_string(webView->id))
  {}

  WebViewChannelDelegate::WebViewChannelDelegate(InAppWebView* webView, flutter::BinaryMessenger* messenger, const std::string& name)
    : webView(webView), ChannelDelegate(messenger, name)
  {}

  WebViewChannelDelegate::ShouldOverrideUrlLoadingCallback::ShouldOverrideUrlLoadingCallback()
  {
    decodeResult = [](const flutter::EncodableValue* value)
      {
        if (!value || value->IsNull()) {
          return NavigationActionPolicy::cancel;
        }
        auto navigationPolicy = std::get<int>(*value);
        return static_cast<NavigationActionPolicy>(navigationPolicy);
      };
  }

  WebViewChannelDelegate::CallJsHandlerCallback::CallJsHandlerCallback()
  {
    decodeResult = [](const flutter::EncodableValue* value)
      {
        return value;
      };
  }

  WebViewChannelDelegate::CreateWindowCallback::CreateWindowCallback()
  {
    decodeResult = [](const flutter::EncodableValue* value)
      {
        if (!value || value->IsNull()) {
          return false;
        }
        auto handledByClient = std::get<bool>(*value);
        return handledByClient;
      };
  }

  WebViewChannelDelegate::PermissionRequestCallback::PermissionRequestCallback()
  {
    decodeResult = [](const flutter::EncodableValue* value)
      {
        return std::make_shared<PermissionResponse>(std::get<flutter::EncodableMap>(*value));
      };
  }

  WebViewChannelDelegate::ShouldInterceptRequestCallback::ShouldInterceptRequestCallback()
  {
    decodeResult = [](const flutter::EncodableValue* value)
      {
        return value == nullptr || value->IsNull() ? std::optional<std::shared_ptr<WebResourceResponse>>{} : std::make_shared<WebResourceResponse>(std::get<flutter::EncodableMap>(*value));
      };
  }

  WebViewChannelDelegate::LoadResourceWithCustomSchemeCallback::LoadResourceWithCustomSchemeCallback()
  {
    decodeResult = [](const flutter::EncodableValue* value)
      {
        return value == nullptr || value->IsNull() ? std::optional<std::shared_ptr<CustomSchemeResponse>>{} : std::make_shared<CustomSchemeResponse>(std::get<flutter::EncodableMap>(*value));
      };
  }

  void WebViewChannelDelegate::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    if (!webView) {
      result->Success();
      return;
    }

    auto& arguments = std::get<flutter::EncodableMap>(*method_call.arguments());
    auto& methodName = method_call.method_name();

    if (string_equals(methodName, "getUrl")) {
      result->Success(make_fl_value(webView->getUrl()));
    }
    else if (string_equals(methodName, "getTitle")) {
      result->Success(make_fl_value(webView->getUrl()));
    }
    else if (string_equals(methodName, "loadUrl")) {
      auto urlRequest = std::make_unique<URLRequest>(get_fl_map_value<flutter::EncodableMap>(arguments, "urlRequest"));
      webView->loadUrl(std::move(urlRequest));
      result->Success(true);
    }
    else if (string_equals(methodName, "loadFile")) {
      auto assetFilePath = get_fl_map_value<std::string>(arguments, "assetFilePath");
      webView->loadFile(assetFilePath);
      result->Success(true);
    }
    else if (string_equals(methodName, "loadData")) {
      auto data = get_fl_map_value<std::string>(arguments, "data");
      webView->loadData(data);
      result->Success(true);
    }
    else if (string_equals(methodName, "reload")) {
      webView->reload();
      result->Success(true);
    }
    else if (string_equals(methodName, "goBack")) {
      webView->goBack();
      result->Success(true);
    }
    else if (string_equals(methodName, "canGoBack")) {
      result->Success(webView->canGoBack());
    }
    else if (string_equals(methodName, "goForward")) {
      webView->goForward();
      result->Success(true);
    }
    else if (string_equals(methodName, "canGoForward")) {
      result->Success(webView->canGoForward());
    }
    else if (string_equals(methodName, "goBackOrForward")) {
      auto steps = get_fl_map_value<int>(arguments, "steps");
      webView->goBackOrForward(steps);
      result->Success(true);
    }
    else if (string_equals(methodName, "canGoBackOrForward")) {
      auto result_ = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));

      auto steps = get_fl_map_value<int>(arguments, "steps");
      webView->canGoBackOrForward(steps, [result_ = std::move(result_)](const bool& value)
        {
          result_->Success(value);
        });
    }
    else if (string_equals(methodName, "isLoading")) {
      result->Success(webView->isLoading());
    }
    else if (string_equals(methodName, "stopLoading")) {
      webView->stopLoading();
      result->Success(true);
    }
    else if (string_equals(methodName, "evaluateJavascript")) {
      auto result_ = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));

      auto source = get_fl_map_value<std::string>(arguments, "source");
      auto contentWorldMap = get_optional_fl_map_value<flutter::EncodableMap>(arguments, "contentWorld");
      std::shared_ptr<ContentWorld> contentWorld = contentWorldMap.has_value() ? std::make_shared<ContentWorld>(contentWorldMap.value()) : ContentWorld::page();
      webView->evaluateJavascript(source, std::move(contentWorld), [result_ = std::move(result_)](const std::string& value)
        {
          result_->Success(value);
        });
    }
    else if (string_equals(methodName, "callAsyncJavaScript")) {
      auto result_ = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));

      auto functionBody = get_fl_map_value<std::string>(arguments, "functionBody");
      auto argumentsAsJson = get_fl_map_value<std::string>(arguments, "arguments");
      auto contentWorldMap = get_optional_fl_map_value<flutter::EncodableMap>(arguments, "contentWorld");
      std::shared_ptr<ContentWorld> contentWorld = contentWorldMap.has_value() ? std::make_shared<ContentWorld>(contentWorldMap.value()) : ContentWorld::page();
      webView->callAsyncJavaScript(functionBody, argumentsAsJson, std::move(contentWorld), [result_ = std::move(result_)](const std::string& value)
        {
          result_->Success(value);
        });
    }
    else if (string_equals(methodName, "getCopyBackForwardList")) {
      auto result_ = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));
      webView->getCopyBackForwardList([result_ = std::move(result_)](const std::unique_ptr<WebHistory> value)
        {
          result_->Success(value->toEncodableMap());
        });
    }
    else if (string_equals(methodName, "addUserScript")) {
      auto userScript = std::make_unique<UserScript>(get_fl_map_value<flutter::EncodableMap>(arguments, "userScript"));
      webView->addUserScript(std::move(userScript));
      result->Success(true);
    }
    else if (string_equals(methodName, "removeUserScript")) {
      auto index = get_fl_map_value<int>(arguments, "index");
      auto userScript = std::make_unique<UserScript>(get_fl_map_value<flutter::EncodableMap>(arguments, "userScript"));
      webView->removeUserScript(index, std::move(userScript));
      result->Success(true);
    }
    else if (string_equals(methodName, "removeUserScriptsByGroupName")) {
      auto groupName = get_fl_map_value<std::string>(arguments, "groupName");
      webView->removeUserScriptsByGroupName(groupName);
      result->Success(true);
    }
    else if (string_equals(methodName, "removeAllUserScripts")) {
      webView->removeAllUserScripts();
      result->Success(true);
    }
    else if (string_equals(methodName, "takeScreenshot")) {
      auto result_ = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));
      auto screenshotConfigurationMap = get_optional_fl_map_value<flutter::EncodableMap>(arguments, "screenshotConfiguration");
      std::optional<std::unique_ptr<ScreenshotConfiguration>> screenshotConfiguration =
        screenshotConfigurationMap.has_value() ? std::make_unique<ScreenshotConfiguration>(screenshotConfigurationMap.value()) : std::optional<std::unique_ptr<ScreenshotConfiguration>>{};
      webView->takeScreenshot(std::move(screenshotConfiguration), [result_ = std::move(result_)](const std::optional<std::string> data)
        {
          result_->Success(make_fl_value(data));
        });
    }
    else if (string_equals(methodName, "setSettings")) {
      if (webView->inAppBrowser) {
        auto settingsMap = get_fl_map_value<flutter::EncodableMap>(arguments, "settings");
        auto settings = std::make_unique<InAppBrowserSettings>(settingsMap);
        webView->inAppBrowser->setSettings(std::move(settings), settingsMap);
      }
      else {
        auto settingsMap = get_fl_map_value<flutter::EncodableMap>(arguments, "settings");
        auto settings = std::make_unique<InAppWebViewSettings>(settingsMap);
        webView->setSettings(std::move(settings), settingsMap);
      }
      result->Success(true);
    }
    else if (string_equals(methodName, "getSettings")) {
      if (webView->inAppBrowser) {
        result->Success(webView->inAppBrowser->getSettings());
      }
      else {
        result->Success(webView->getSettings());
      }
    }
    else if (string_equals(methodName, "openDevTools")) {
      webView->openDevTools();
      result->Success(true);
    }
    else if (string_equals(methodName, "callDevToolsProtocolMethod")) {
      auto result_ = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));
      auto cdpMethodName = get_fl_map_value<std::string>(arguments, "methodName");
      auto parametersAsJson = get_optional_fl_map_value<std::string>(arguments, "parametersAsJson");
      webView->callDevToolsProtocolMethod(cdpMethodName, parametersAsJson, [result_ = std::move(result_)](const HRESULT& errorCode, const std::optional<std::string>& data)
        {
          if (SUCCEEDED(errorCode)) {
            result_->Success(make_fl_value(data));
          }
          else {
            result_->Error(std::to_string(errorCode), getHRMessage(errorCode));
          }
        });
    }
    else if (string_equals(methodName, "addDevToolsProtocolEventListener")) {
      auto eventName = get_fl_map_value<std::string>(arguments, "eventName");
      webView->addDevToolsProtocolEventListener(eventName);
      result->Success(true);
    }
    else if (string_equals(methodName, "removeDevToolsProtocolEventListener")) {
      auto eventName = get_fl_map_value<std::string>(arguments, "eventName");
      webView->removeDevToolsProtocolEventListener(eventName);
      result->Success(true);
    }
    else if (string_equals(methodName, "pause")) {
      webView->pause();
      result->Success(true);
    }
    else if (string_equals(methodName, "resume")) {
      webView->resume();
      result->Success(true);
    }
    else if (string_equals(methodName, "requestFocus")) {
      result->Success(webView->requestFocus());
    }
    else if (string_equals(methodName, "getCertificate")) {
      auto result_ = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));
      webView->getCertificate([result_ = std::move(result_)](const std::optional<std::unique_ptr<SslCertificate>> data)
        {
          result_->Success(data.has_value() ? data.value()->toEncodableMap() : make_fl_value());
        });
    }
    // for inAppBrowser
    else if (webView->inAppBrowser && string_equals(methodName, "show")) {
      webView->inAppBrowser->show();
      result->Success(true);
    }
    else if (webView->inAppBrowser && string_equals(methodName, "hide")) {
      webView->inAppBrowser->hide();
      result->Success(true);
    }
    else if (webView->inAppBrowser && string_equals(methodName, "close")) {
      webView->inAppBrowser->close();
      result->Success(true);
    }
    else {
      result->NotImplemented();
    }
  }

  void WebViewChannelDelegate::onLoadStart(const std::optional<std::string>& url) const
  {
    if (!channel) {
      return;
    }

    auto arguments = std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
      {"url", make_fl_value(url)},
      });
    channel->InvokeMethod("onLoadStart", std::move(arguments));
  }

  void WebViewChannelDelegate::onLoadStop(const std::optional<std::string>& url) const
  {
    if (!channel) {
      return;
    }

    auto arguments = std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
      {"url", make_fl_value(url)},
      });
    channel->InvokeMethod("onLoadStop", std::move(arguments));
  }

  void WebViewChannelDelegate::shouldOverrideUrlLoading(std::shared_ptr<NavigationAction> navigationAction, std::unique_ptr<ShouldOverrideUrlLoadingCallback> callback) const
  {
    if (!channel) {
      callback->defaultBehaviour(std::nullopt);
      return;
    }

    auto arguments = std::make_unique<flutter::EncodableValue>(navigationAction->toEncodableMap());
    channel->InvokeMethod("shouldOverrideUrlLoading", std::move(arguments), std::move(callback));
  }

  void WebViewChannelDelegate::onReceivedError(std::shared_ptr<WebResourceRequest> request, std::shared_ptr<WebResourceError> error) const
  {
    if (!channel) {
      return;
    }

    auto arguments = std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
      {"request", request->toEncodableMap()},
      {"error", error->toEncodableMap()},
      });
    channel->InvokeMethod("onReceivedError", std::move(arguments));
  }

  void WebViewChannelDelegate::onReceivedHttpError(std::shared_ptr<WebResourceRequest> request, std::shared_ptr<WebResourceResponse> errorResponse) const
  {
    if (!channel) {
      return;
    }

    auto arguments = std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
      {"request", request->toEncodableMap()},
      {"errorResponse", errorResponse->toEncodableMap()},
      });
    channel->InvokeMethod("onReceivedHttpError", std::move(arguments));
  }

  void WebViewChannelDelegate::onTitleChanged(const std::optional<std::string>& title) const
  {
    if (!channel) {
      return;
    }

    auto arguments = std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
      {"title", make_fl_value(title)}
      });
    channel->InvokeMethod("onTitleChanged", std::move(arguments));

    if (webView && webView->inAppBrowser) {
      webView->inAppBrowser->didChangeTitle(title);
    }
  }

  void WebViewChannelDelegate::onUpdateVisitedHistory(const std::optional<std::string>& url, const std::optional<bool>& isReload) const
  {
    if (!channel) {
      return;
    }

    auto arguments = std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
      {"url", make_fl_value(url)},
      {"isReload", make_fl_value(isReload)}
      });
    channel->InvokeMethod("onUpdateVisitedHistory", std::move(arguments));
  }

  void WebViewChannelDelegate::onCallJsHandler(const std::string& handlerName, const std::string& args, std::unique_ptr<CallJsHandlerCallback> callback) const
  {
    if (!channel) {
      callback->defaultBehaviour(std::nullopt);
      return;
    }

    auto arguments = std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
      {"handlerName", handlerName},
      {"args", args}
      });
    channel->InvokeMethod("onCallJsHandler", std::move(arguments), std::move(callback));
  }

  void WebViewChannelDelegate::onConsoleMessage(const std::string& message, const int64_t& messageLevel) const
  {
    if (!channel) {
      return;
    }

    auto arguments = std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
      {"message", message},
      {"messageLevel", messageLevel}
      });
    channel->InvokeMethod("onConsoleMessage", std::move(arguments));
  }

  void WebViewChannelDelegate::onDevToolsProtocolEventReceived(const std::string& eventName, const std::string& data) const
  {
    if (!channel) {
      return;
    }

    auto arguments = std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
      {"eventName", eventName},
      {"data", data}
      });
    channel->InvokeMethod("onDevToolsProtocolEventReceived", std::move(arguments));
  }

  void WebViewChannelDelegate::onProgressChanged(const int64_t& progress) const
  {
    if (!channel) {
      return;
    }

    auto arguments = std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
      {"progress", progress}
      });
    channel->InvokeMethod("onProgressChanged", std::move(arguments));
  }

  void WebViewChannelDelegate::onCreateWindow(std::shared_ptr<CreateWindowAction> createWindowAction, std::unique_ptr<CreateWindowCallback> callback) const
  {
    if (!channel) {
      callback->defaultBehaviour(std::nullopt);
      return;
    }

    auto arguments = std::make_unique<flutter::EncodableValue>(createWindowAction->toEncodableMap());
    channel->InvokeMethod("onCreateWindow", std::move(arguments), std::move(callback));
  }

  void WebViewChannelDelegate::onCloseWindow() const
  {
    if (!channel) {
      return;
    }

    auto arguments = std::make_unique<flutter::EncodableValue>();
    channel->InvokeMethod("onCloseWindow", std::move(arguments));
  }

  void WebViewChannelDelegate::onPermissionRequest(const std::string& origin, const std::vector<int64_t>& resources, std::unique_ptr<PermissionRequestCallback> callback) const
  {
    if (!channel) {
      callback->defaultBehaviour(std::nullopt);
      return;
    }

    auto arguments = std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
      {"origin", origin},
      {"resources", make_fl_value(resources)}
      });
    channel->InvokeMethod("onPermissionRequest", std::move(arguments), std::move(callback));
  }

  void WebViewChannelDelegate::shouldInterceptRequest(std::shared_ptr<WebResourceRequest> request, std::unique_ptr<ShouldInterceptRequestCallback> callback) const
  {
    if (!channel) {
      callback->defaultBehaviour(std::nullopt);
      return;
    }

    auto arguments = std::make_unique<flutter::EncodableValue>(make_fl_value(request->toEncodableMap()));
    channel->InvokeMethod("shouldInterceptRequest", std::move(arguments), std::move(callback));
  }

  void WebViewChannelDelegate::onLoadResourceWithCustomScheme(std::shared_ptr<WebResourceRequest> request, std::unique_ptr<LoadResourceWithCustomSchemeCallback> callback) const
  {
    if (!channel) {
      callback->defaultBehaviour(std::nullopt);
      return;
    }

    auto arguments = std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
      {"request", request->toEncodableMap()},
      });
    channel->InvokeMethod("onLoadResourceWithCustomScheme", std::move(arguments), std::move(callback));
  }

  WebViewChannelDelegate::~WebViewChannelDelegate()
  {
    debugLog("dealloc WebViewChannelDelegate");
    webView = nullptr;
  }
}
