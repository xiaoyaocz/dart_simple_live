#include <DispatcherQueue.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <shlobj.h>
#include <windows.graphics.capture.h>

#include "../in_app_webview/in_app_webview_settings.h"
#include "../types/size_2d.h"
#include "../types/url_request.h"
#include "../types/user_script.h"
#include "../utils/flutter.h"
#include "../utils/log.h"
#include "../utils/map.h"
#include "../utils/string.h"
#include "../utils/vector.h"
#include "../webview_environment/webview_environment_manager.h"
#include "headless_in_app_webview_manager.h"

namespace flutter_inappwebview_plugin
{
  HeadlessInAppWebViewManager::HeadlessInAppWebViewManager(const FlutterInappwebviewWindowsPlugin* plugin)
    : plugin(plugin),
    ChannelDelegate(plugin->registrar->messenger(), HeadlessInAppWebViewManager::METHOD_CHANNEL_NAME)
  {
    windowClass_.lpszClassName = HeadlessInAppWebView::CLASS_NAME;
    windowClass_.lpfnWndProc = &DefWindowProc;

    RegisterClass(&windowClass_);
  }

  void HeadlessInAppWebViewManager::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    auto& methodName = method_call.method_name();

    if (string_equals(methodName, "run")) {
      run(arguments, std::move(result));
    }
    else {
      result->NotImplemented();
    }
  }

  void HeadlessInAppWebViewManager::run(const flutter::EncodableMap* arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    auto result_ = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));

    if (!plugin) {
      result_->Error("0", "Cannot create the HeadlessInAppWebView instance!");
      return;
    }

    auto id = get_fl_map_value<std::string>(*arguments, "id");
    auto params = get_fl_map_value<flutter::EncodableMap>(*arguments, "params");

    auto initialSize = std::make_shared<Size2D>(get_fl_map_value<flutter::EncodableMap>(params, "initialSize"));

    auto settingsMap = get_fl_map_value<flutter::EncodableMap>(params, "initialSettings");
    auto urlRequestMap = get_optional_fl_map_value<flutter::EncodableMap>(params, "initialUrlRequest");
    auto initialFile = get_optional_fl_map_value<std::string>(params, "initialFile");
    auto initialDataMap = get_optional_fl_map_value<flutter::EncodableMap>(params, "initialData");
    auto initialUserScriptList = get_optional_fl_map_value<flutter::EncodableList>(params, "initialUserScripts");
    auto webViewEnvironmentId = get_optional_fl_map_value<std::string>(params, "webViewEnvironmentId");

    RECT bounds;
    GetClientRect(plugin->registrar->GetView()->GetNativeWindow(), &bounds);

    auto initialWidth = initialSize->width >= 0 ? initialSize->width : bounds.right - bounds.left;
    auto initialHeight = initialSize->height >= 0 ? initialSize->height : bounds.bottom - bounds.top;

    auto hwnd = CreateWindowEx(0, windowClass_.lpszClassName, L"", 0, 0,
      0, (int)initialWidth, (int)initialHeight,
      plugin->registrar->GetView()->GetNativeWindow(),
      nullptr,
      windowClass_.hInstance, nullptr);

    auto webViewEnvironment = webViewEnvironmentId.has_value() && map_contains(plugin->webViewEnvironmentManager->webViewEnvironments, webViewEnvironmentId.value())
      ? plugin->webViewEnvironmentManager->webViewEnvironments.at(webViewEnvironmentId.value()).get() : nullptr;

    auto initialSettings = std::make_shared<InAppWebViewSettings>(settingsMap);

    InAppWebView::createInAppWebViewEnv(hwnd, false, webViewEnvironment, initialSettings,
      [=](wil::com_ptr<ICoreWebView2Environment> webViewEnv,
        wil::com_ptr<ICoreWebView2Controller> webViewController,
        wil::com_ptr<ICoreWebView2CompositionController> webViewCompositionController)
      {
        if (plugin && webViewEnv && webViewController) {
          std::optional<std::vector<std::shared_ptr<UserScript>>> initialUserScripts = initialUserScriptList.has_value() ?
            functional_map(initialUserScriptList.value(), [](const flutter::EncodableValue& map) { return std::make_shared<UserScript>(std::get<flutter::EncodableMap>(map)); }) :
            std::optional<std::vector<std::shared_ptr<UserScript>>>{};

          InAppWebViewCreationParams params = {
            id,
            std::move(initialSettings),
            initialUserScripts
          };

          auto inAppWebView = std::make_unique<InAppWebView>(plugin, params, hwnd,
            std::move(webViewEnv), std::move(webViewController), nullptr
          );

          HeadlessInAppWebViewCreationParams headlessParams = {
            id,
            std::move(initialSize)
          };

          auto headlessInAppWebView = std::make_unique<HeadlessInAppWebView>(plugin,
            headlessParams,
            hwnd,
            std::move(inAppWebView));

          headlessInAppWebView->webView->initChannel(std::nullopt, std::nullopt);

          if (headlessInAppWebView->channelDelegate) {
            headlessInAppWebView->channelDelegate->onWebViewCreated();
          }

          std::optional<std::shared_ptr<URLRequest>> urlRequest = urlRequestMap.has_value() ? std::make_shared<URLRequest>(urlRequestMap.value()) : std::optional<std::shared_ptr<URLRequest>>{};
          if (urlRequest.has_value()) {
            headlessInAppWebView->webView->loadUrl(urlRequest.value());
          }
          else if (initialFile.has_value()) {
            headlessInAppWebView->webView->loadFile(initialFile.value());
          }
          else if (initialDataMap.has_value()) {
            headlessInAppWebView->webView->loadData(get_fl_map_value<std::string>(initialDataMap.value(), "data"));
          }

          webViews.insert({ id, std::move(headlessInAppWebView) });

          result_->Success(true);
        }
        else {
          result_->Error("0", "Cannot create the HeadlessInAppWebView instance!");
        }
      }
    );
  }

  HeadlessInAppWebViewManager::~HeadlessInAppWebViewManager()
  {
    debugLog("dealloc HeadlessInAppWebViewManager");
    webViews.clear();
    UnregisterClass(windowClass_.lpszClassName, nullptr);
    plugin = nullptr;
  }
}