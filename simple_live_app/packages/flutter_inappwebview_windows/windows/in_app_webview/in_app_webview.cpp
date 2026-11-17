#include <cstring>
#include <WebView2EnvironmentOptions.h>
#include <filesystem>
#include <nlohmann/json.hpp>
#include <Shlwapi.h>
#include <wil/wrl.h>

#include "../custom_platform_view/util/composition.desktop.interop.h"
#include "../plugin_scripts_js/javascript_bridge_js.h"
#include "../types/create_window_action.h"
#include "../types/web_resource_error.h"
#include "../types/web_resource_request.h"
#include "../utils/base64.h"
#include "../utils/com_apartment.h"
#include "../utils/log.h"
#include "../utils/map.h"
#include "../utils/strconv.h"
#include "../utils/string.h"
#include "../webview_environment/webview_environment_manager.h"
#include "in_app_webview.h"
#include "in_app_webview_manager.h"

namespace flutter_inappwebview_plugin
{
  using namespace Microsoft::WRL;

  InAppWebView::InAppWebView(const FlutterInappwebviewWindowsPlugin* plugin, const InAppWebViewCreationParams& params, const HWND parentWindow, wil::com_ptr<ICoreWebView2Environment> webViewEnv,
    wil::com_ptr<ICoreWebView2Controller> webViewController,
    wil::com_ptr<ICoreWebView2CompositionController> webViewCompositionController)
    : plugin(plugin), id(params.id),
    webViewEnv(std::move(webViewEnv)), webViewController(std::move(webViewController)), webViewCompositionController(std::move(webViewCompositionController)),
    settings(params.initialSettings), userContentController(std::make_unique<UserContentController>(this))
  {
    if (failedAndLog(this->webViewController->get_CoreWebView2(webView.put()))) {
      std::cerr << "Cannot create CoreWebView2." << std::endl;
    }

    if (this->webViewCompositionController) {
      if (!createSurface(parentWindow, plugin->inAppWebViewManager->compositor())) {
        std::cerr << "Cannot create InAppWebView surface." << std::endl;
      }
      registerSurfaceEventHandlers();
    }
    else {
      this->webViewController->put_IsVisible(true);
      // Resize WebView to fit the bounds of the parent window
      RECT bounds;
      GetClientRect(parentWindow, &bounds);
      this->webViewController->put_Bounds(bounds);
    }

    prepare(params);
  }

  InAppWebView::InAppWebView(InAppBrowser* inAppBrowser, const FlutterInappwebviewWindowsPlugin* plugin, const InAppWebViewCreationParams& params, const HWND parentWindow, wil::com_ptr<ICoreWebView2Environment> webViewEnv,
    wil::com_ptr<ICoreWebView2Controller> webViewController,
    wil::com_ptr<ICoreWebView2CompositionController> webViewCompositionController)
    : InAppWebView(plugin, params, parentWindow, std::move(webViewEnv), std::move(webViewController), std::move(webViewCompositionController))
  {
    this->inAppBrowser = inAppBrowser;
  }

  void InAppWebView::createInAppWebViewEnv(const HWND parentWindow, const bool& willBeSurface, WebViewEnvironment* webViewEnvironment, const std::shared_ptr<InAppWebViewSettings> initialSettings, std::function<void(wil::com_ptr<ICoreWebView2Environment> webViewEnv,
    wil::com_ptr<ICoreWebView2Controller> webViewController,
    wil::com_ptr<ICoreWebView2CompositionController> webViewCompositionController)> completionHandler)
  {
    // This entry also creates views without an explicit Dart environment.
    // Establish the apartment on the actual calling thread before any COM API.
    if (failedAndLog(ensureWebViewComApartment())) {
      completionHandler(nullptr, nullptr, nullptr);
      return;
    }
    auto callback = [parentWindow, willBeSurface, completionHandler, initialSettings](HRESULT result, wil::com_ptr<ICoreWebView2Environment> env) -> HRESULT
      {
        if (failedAndLog(result) || !env) {
          completionHandler(nullptr, nullptr, nullptr);
          return E_FAIL;
        }

        wil::com_ptr<ICoreWebView2Environment3> webViewEnv3;
        wil::com_ptr<ICoreWebView2Environment10> webViewEnv10;
        wil::com_ptr<ICoreWebView2ControllerOptions> options;
        HRESULT controllerHr = E_FAIL;
        if (initialSettings && succeededOrLog(env->QueryInterface(IID_PPV_ARGS(&webViewEnv10))) && succeededOrLog(webViewEnv10->CreateCoreWebView2ControllerOptions(&options))) {
          options->put_IsInPrivateModeEnabled(initialSettings->incognito);
        }
        else {
          webViewEnv10 = nullptr;
          options = nullptr;
          failedLog(env->QueryInterface(IID_PPV_ARGS(&webViewEnv3)));
        }
        if (willBeSurface && (webViewEnv10 || webViewEnv3)) {
          if (webViewEnv10 && options) {
            controllerHr = webViewEnv10->CreateCoreWebView2CompositionControllerWithOptions(parentWindow, options.get(), Callback<ICoreWebView2CreateCoreWebView2CompositionControllerCompletedHandler>(
              [completionHandler, env](HRESULT result, wil::com_ptr<ICoreWebView2CompositionController> compositionController) -> HRESULT
              {
                wil::com_ptr<ICoreWebView2Controller3> webViewController = compositionController.try_query<ICoreWebView2Controller3>();

                if (failedAndLog(result) || !webViewController) {
                  completionHandler(nullptr, nullptr, nullptr);
                  return E_FAIL;
                }

                ICoreWebView2Controller3* webViewController3;
                if (succeededOrLog(webViewController->QueryInterface(IID_PPV_ARGS(&webViewController3)))) {
                  webViewController3->put_BoundsMode(COREWEBVIEW2_BOUNDS_MODE_USE_RAW_PIXELS);
                  webViewController3->put_ShouldDetectMonitorScaleChanges(FALSE);
                  webViewController3->put_RasterizationScale(1.0);
                }

                completionHandler(std::move(env), std::move(webViewController), std::move(compositionController));
                return S_OK;
              }
            ).Get());
          }
          else {
            controllerHr = webViewEnv3->CreateCoreWebView2CompositionController(parentWindow, Callback<ICoreWebView2CreateCoreWebView2CompositionControllerCompletedHandler>(
              [completionHandler, env](HRESULT result, wil::com_ptr<ICoreWebView2CompositionController> compositionController) -> HRESULT
              {
                wil::com_ptr<ICoreWebView2Controller3> webViewController = compositionController.try_query<ICoreWebView2Controller3>();

                if (failedAndLog(result) || !webViewController) {
                  completionHandler(nullptr, nullptr, nullptr);
                  return E_FAIL;
                }

                ICoreWebView2Controller3* webViewController3;
                if (succeededOrLog(webViewController->QueryInterface(IID_PPV_ARGS(&webViewController3)))) {
                  webViewController3->put_BoundsMode(COREWEBVIEW2_BOUNDS_MODE_USE_RAW_PIXELS);
                  webViewController3->put_ShouldDetectMonitorScaleChanges(FALSE);
                  webViewController3->put_RasterizationScale(1.0);
                }

                completionHandler(std::move(env), std::move(webViewController), std::move(compositionController));
                return S_OK;
              }
            ).Get());
          }
        }
        else {
          if (webViewEnv10 && options) {
            controllerHr = webViewEnv10->CreateCoreWebView2ControllerWithOptions(parentWindow, options.get(), Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
              [completionHandler, env](HRESULT result, wil::com_ptr<ICoreWebView2Controller> controller) -> HRESULT
              {
                if (failedAndLog(result) || !controller) {
                  completionHandler(nullptr, nullptr, nullptr);
                  return E_FAIL;
                }

                completionHandler(std::move(env), std::move(controller), nullptr);
                return S_OK;
              }).Get());
          }
          else {
            controllerHr = env->CreateCoreWebView2Controller(parentWindow, Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
              [completionHandler, env](HRESULT result, wil::com_ptr<ICoreWebView2Controller> controller) -> HRESULT
              {
                if (failedAndLog(result) || !controller) {
                  completionHandler(nullptr, nullptr, nullptr);
                  return E_FAIL;
                }

                completionHandler(std::move(env), std::move(controller), nullptr);
                return S_OK;
              }).Get());
          }
        }
        if (failedAndLog(controllerHr)) {
          // 同步失败时 WebView2 不会再触发回调，必须主动结束 Dart 的等待。
          completionHandler(nullptr, nullptr, nullptr);
        }
        return S_OK;
      };

    HRESULT hr;
    if (webViewEnvironment && webViewEnvironment->getEnvironment()) {
      hr = callback(S_OK, webViewEnvironment->getEnvironment());
    }
    else {
      // Account login/default views retain their original profile but route directly.
      auto options = Make<CoreWebView2EnvironmentOptions>();
      options->put_AdditionalBrowserArguments(L"--no-proxy-server");
      hr = CreateCoreWebView2EnvironmentWithOptions(
        nullptr, nullptr, options.Get(),
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(callback).Get());
    }

    if (failedAndLog(hr)) {
      completionHandler(nullptr, nullptr, nullptr);
    }
  }

  void InAppWebView::initChannel(const std::optional<std::variant<std::string, int64_t>> viewId, const std::optional<std::string> channelName)
  {
    if (viewId.has_value()) {
      id = viewId.value();
    }
    channelDelegate = channelName.has_value() ? std::make_unique<WebViewChannelDelegate>(this, plugin->registrar->messenger(), channelName.value()) :
      std::make_unique<WebViewChannelDelegate>(this, plugin->registrar->messenger());
  }

  void InAppWebView::prepare(const InAppWebViewCreationParams& params)
  {
    if (!webView) {
      return;
    }

    wil::com_ptr<ICoreWebView2Settings> webView2Settings;
    auto hrWebView2Settings = webView->get_Settings(&webView2Settings);
    if (succeededOrLog(hrWebView2Settings)) {
      webView2Settings->put_IsScriptEnabled(settings->javaScriptEnabled);
      webView2Settings->put_IsStatusBarEnabled(FALSE);
      webView2Settings->put_IsZoomControlEnabled(settings->supportZoom);
      webView2Settings->put_AreDevToolsEnabled(settings->isInspectable);
      webView2Settings->put_AreDefaultContextMenusEnabled(!settings->disableContextMenu);

      wil::com_ptr<ICoreWebView2Settings2> webView2Settings2;
      if (succeededOrLog(webView2Settings->QueryInterface(IID_PPV_ARGS(&webView2Settings2)))) {
        if (!settings->userAgent.empty()) {
          webView2Settings2->put_UserAgent(utf8_to_wide(settings->userAgent).c_str());
        }
      }
    }

    wil::com_ptr<ICoreWebView2Controller2> webViewController2;
    if (succeededOrLog(webViewController->QueryInterface(IID_PPV_ARGS(&webViewController2)))) {
      if (!settings->transparentBackground) {
        webViewController2->put_DefaultBackgroundColor({ 0, 255, 255, 255 });
      }
    }

    // required to make Runtime events work
    failedLog(webView->CallDevToolsProtocolMethod(L"Runtime.enable", L"{}", Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
      [this](HRESULT errorCode, LPCWSTR returnObjectAsJson)
      {
        failedLog(errorCode);
        return S_OK;
      }
    ).Get()));

    // required to make Page events work and to add User Scripts
    failedLog(webView->CallDevToolsProtocolMethod(L"Page.enable", L"{}", Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
      [this](HRESULT errorCode, LPCWSTR returnObjectAsJson)
      {
        failedLog(errorCode);
        return S_OK;
      }
    ).Get()));

    // required to use Network domain
    failedLog(webView->CallDevToolsProtocolMethod(L"Network.enable", L"{}", Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
      [this](HRESULT errorCode, LPCWSTR returnObjectAsJson)
      {
        failedLog(errorCode);
        return S_OK;
      }
    ).Get()));

    // required to use Fetch domain and implement the shouldOverrideUrlLoading event correctly
    failedLog(webView->CallDevToolsProtocolMethod(L"Fetch.enable", L"{\"patterns\": [{\"resourceType\": \"Document\", \"requestStage\": \"Request\"}]}", Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
      [this](HRESULT errorCode, LPCWSTR returnObjectAsJson)
      {
        failedLog(errorCode);
        return S_OK;
      }
    ).Get()));

    failedLog(webView->CallDevToolsProtocolMethod(L"Page.getFrameTree", L"{}", Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
      [this, lifetime = std::weak_ptr<int>(callbackLifetime_)](HRESULT errorCode, LPCWSTR returnObjectAsJson)
      {
        if (lifetime.expired()) return S_OK;
        if (succeededOrLog(errorCode)) {
          auto treeJson = nlohmann::json::parse(wide_to_utf8(returnObjectAsJson));
          pageFrameId_ = treeJson["frameTree"]["frame"]["id"].get<std::string>();
        }
        return S_OK;
      }
    ).Get()));

    if (userContentController) {
      userContentController->addPluginScript(std::move(createJavaScriptBridgePluginScript()));
      if (params.initialUserScripts.has_value()) {
        userContentController->addUserOnlyScripts(params.initialUserScripts.value());
      }
    }

    registerEventHandlers();
  }

  void InAppWebView::registerEventHandlers()
  {
    if (!webView) {
      return;
    }

    wil::com_ptr<ICoreWebView2DevToolsProtocolEventReceiver> fetchRequestPausedEventReceiver;

    if (succeededOrLog(webView->GetDevToolsProtocolEventReceiver(L"Fetch.requestPaused", &fetchRequestPausedEventReceiver))) {
      failedAndLog(fetchRequestPausedEventReceiver->add_DevToolsProtocolEventReceived(
        Callback<ICoreWebView2DevToolsProtocolEventReceivedEventHandler>(
          [this](
            ICoreWebView2* sender,
            ICoreWebView2DevToolsProtocolEventReceivedEventArgs* args) -> HRESULT
          {
            wil::unique_cotaskmem_string json;
            if (succeededOrLog(args->get_ParameterObjectAsJson(&json))) {
              auto requestPausedData = nlohmann::json::parse(wide_to_utf8(json.get()));

              auto requestId = requestPausedData.at("requestId").get<std::string>();
              auto resourceType = requestPausedData.at("resourceType").get<std::string>();
              auto isResponseStage = requestPausedData.contains("responseStatusCode");
              auto frameId = requestPausedData.at("frameId").get<std::string>();

              auto request = requestPausedData.at("request").get<nlohmann::json>();
              std::optional<std::string> url = request.at("url").is_string() ? request.at("url").get<std::string>() : std::optional<std::string>{};
              std::optional<std::string> urlFragment = request.contains("urlFragment") && request.at("urlFragment").is_string() ? request.at("urlFragment").get<std::string>() : std::optional<std::string>{};
              if (url.has_value() && urlFragment.has_value()) {
                url = url.value() + urlFragment.value();
              }
              auto isForMainFrame = pageFrameId_.empty() || string_equals(pageFrameId_, frameId);

              auto allowRequest = [this, requestId, url, isForMainFrame, lifetime = std::weak_ptr<int>(callbackLifetime_)]()
                {
                  // Dart may reply after navigation/reload has destroyed this view.
                  // Check the captured token before touching any member (including webView).
                  if (lifetime.expired()) return;
                  failedAndLog(webView->CallDevToolsProtocolMethod(L"Fetch.continueRequest",
                    utf8_to_wide("{\"requestId\":\"" + requestId + "\"}").c_str(),
                    Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
                      [this](HRESULT errorCode, LPCWSTR returnObjectAsJson)
                      {
                        failedLog(errorCode);
                        return S_OK;
                      }
                    ).Get()));

                  if (channelDelegate && isForMainFrame) {
                    // if shouldOverrideUrlLoading is used, then call onLoadStart and onProgressChanged here
                    // to match the behaviour of the other platforms
                    channelDelegate->onLoadStart(url);
                    channelDelegate->onProgressChanged(0);
                  }
                };

              auto cancelRequest = [this, requestId, lifetime = std::weak_ptr<int>(callbackLifetime_)]()
                {
                  if (lifetime.expired()) return;
                  failedAndLog(webView->CallDevToolsProtocolMethod(L"Fetch.failRequest",
                    utf8_to_wide("{\"requestId\":\"" + requestId + "\", \"errorReason\": \"Aborted\"}").c_str(),
                    Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
                      [this](HRESULT errorCode, LPCWSTR returnObjectAsJson)
                      {
                        failedLog(errorCode);
                        return S_OK;
                      }
                    ).Get()));
                };

              if (!isResponseStage && channelDelegate && settings->useShouldOverrideUrlLoading && string_equals(resourceType, "Document")) {
                std::optional<std::string> method = request.at("method").is_string() ? request.at("method").get<std::string>() : std::optional<std::string>{};
                std::optional<std::map<std::string, std::string>> headers = request.at("headers").is_object() ? request.at("headers").get<std::map<std::string, std::string>>() : std::optional<std::map<std::string, std::string>>{};
                std::optional<std::string> redirectedRequestId = request.contains("redirectedRequestId") && request.at("redirectedRequestId").is_string() ? request.at("redirectedRequestId").get<std::string>() : std::optional<std::string>{};

                std::optional<std::vector<uint8_t>> body = std::optional<std::vector<uint8_t>>{};
                auto hasPostData = request.contains("hasPostData") && request.at("hasPostData").is_boolean() && request.at("hasPostData").get<bool>()
                  && request.contains("postDataEntries") && request.at("postDataEntries").is_array();
                if (hasPostData) {
                  auto postDataEntries = request.at("postDataEntries").get<std::vector<nlohmann::json>>();

                  if (postDataEntries.size() > 0) {
                    body = std::vector<uint8_t>{};
                    for (auto const& entry : postDataEntries) {
                      if (entry.contains("bytes")) {
                        try {
                          auto entryData = base64_decode(entry.at("bytes").get<std::string>());
                          std::vector<uint8_t> bytes(entryData.begin(), entryData.end());
                          body->insert(body->end(), bytes.begin(), bytes.end());
                        }
                        catch (const std::exception& err) {
                          debugLog("Error decoding base64 data");
                          debugLog(err.what());
                          body = std::optional<std::vector<uint8_t>>{};
                          break;
                        }
                      }
                    }
                  }
                }

                BOOL isRedirect = redirectedRequestId.has_value() && !redirectedRequestId.value().empty();

                std::optional<NavigationActionType> navigationType = isRedirect ? NavigationActionType::other : std::optional<NavigationActionType>{};

                auto urlRequest = std::make_shared<URLRequest>(url, method, headers, body);
                auto navigationAction = std::make_shared<NavigationAction>(
                  urlRequest,
                  isForMainFrame,
                  isRedirect,
                  navigationType
                );

                auto callback = std::make_unique<WebViewChannelDelegate::ShouldOverrideUrlLoadingCallback>();
                callback->nonNullSuccess = [this, allowRequest, cancelRequest](const NavigationActionPolicy actionPolicy)
                  {
                    if (actionPolicy == NavigationActionPolicy::allow) {
                      allowRequest();
                    }
                    else {
                      cancelRequest();
                    }
                    return false;
                  };
                auto defaultBehaviour = [this, allowRequest](const std::optional<const NavigationActionPolicy> actionPolicy)
                  {
                    allowRequest();
                  };
                callback->defaultBehaviour = defaultBehaviour;
                callback->error = [defaultBehaviour](const std::string& error_code, const std::string& error_message, const flutter::EncodableValue* error_details)
                  {
                    debugLog(error_code + ", " + error_message);
                    defaultBehaviour(std::nullopt);
                  };
                channelDelegate->shouldOverrideUrlLoading(std::move(navigationAction), std::move(callback));
              }
              else {
                // check if a custom event listener is found and give back the opportunity to it to handle the request
                // through the Chrome Dev Protocol API
                if (!map_contains(devToolsProtocolEventListener_, std::string("Fetch.requestPaused"))) {
                  // if a custom event listener is not found, continue the request
                  allowRequest();
                }
              }
            }

            return S_OK;
          })
        .Get(), nullptr));
    }

    failedLog(webView->add_NavigationStarting(
      Callback<ICoreWebView2NavigationStartingEventHandler>(
        [this](ICoreWebView2* sender, ICoreWebView2NavigationStartingEventArgs* args)
        {
          isLoading_ = true;

          if (!channelDelegate) {
            args->put_Cancel(false);
            return S_OK;
          }

          wil::unique_cotaskmem_string uri = nullptr;
          std::optional<std::string> url = SUCCEEDED(args->get_Uri(&uri)) ? wide_to_utf8(uri.get()) : std::optional<std::string>{};

          wil::unique_cotaskmem_string requestMethod = nullptr;
          wil::com_ptr<ICoreWebView2HttpRequestHeaders> requestHeaders = nullptr;
          std::optional<std::map<std::string, std::string>> headers = std::optional<std::map<std::string, std::string>>{};
          if (SUCCEEDED(args->get_RequestHeaders(&requestHeaders))) {
            headers = std::make_optional<std::map<std::string, std::string>>({});
            wil::com_ptr<ICoreWebView2HttpHeadersCollectionIterator> iterator;
            requestHeaders->GetIterator(&iterator);
            BOOL hasCurrent = FALSE;
            while (SUCCEEDED(iterator->get_HasCurrentHeader(&hasCurrent)) && hasCurrent) {
              wil::unique_cotaskmem_string name;
              wil::unique_cotaskmem_string value;

              if (SUCCEEDED(iterator->GetCurrentHeader(&name, &value))) {
                headers->insert({ wide_to_utf8(name.get()), wide_to_utf8(value.get()) });
              }

              BOOL hasNext = FALSE;
              iterator->MoveNext(&hasNext);
            }

            requestHeaders->GetHeader(L"Flutter-InAppWebView-Request-Method", &requestMethod);
            requestHeaders->RemoveHeader(L"Flutter-InAppWebView-Request-Method");
          }

          std::optional<std::string> method = requestMethod ? wide_to_utf8(requestMethod.get()) : std::optional<std::string>{};

          BOOL isUserInitiated;
          if (FAILED(args->get_IsUserInitiated(&isUserInitiated))) {
            isUserInitiated = FALSE;
          }

          BOOL isRedirect;
          if (FAILED(args->get_IsRedirected(&isRedirect))) {
            isRedirect = FALSE;
          }

          std::optional<NavigationActionType> navigationType = std::nullopt;
          wil::com_ptr<ICoreWebView2NavigationStartingEventArgs3> args3;
          if (SUCCEEDED(args->QueryInterface(IID_PPV_ARGS(&args3)))) {
            COREWEBVIEW2_NAVIGATION_KIND navigationKind;
            if (SUCCEEDED(args3->get_NavigationKind(&navigationKind))) {
              switch (navigationKind) {
              case COREWEBVIEW2_NAVIGATION_KIND_RELOAD:
                navigationType = NavigationActionType::reload;
                break;
              case COREWEBVIEW2_NAVIGATION_KIND_BACK_OR_FORWARD:
                navigationType = NavigationActionType::backForward;
                break;
              case COREWEBVIEW2_NAVIGATION_KIND_NEW_DOCUMENT:
                if (isUserInitiated && !isRedirect) {
                  navigationType = NavigationActionType::linkActivated;
                }
                else {
                  navigationType = NavigationActionType::other;
                }
                break;
              default:
                navigationType = NavigationActionType::other;
              }
            }
          }

          auto urlRequest = std::make_shared<URLRequest>(url, method, headers, std::nullopt);
          auto navigationAction = std::make_shared<NavigationAction>(
            urlRequest,
            true,
            isRedirect,
            navigationType
          );

          lastNavigationAction_ = navigationAction;

          UINT64 navigationId;
          if (SUCCEEDED(args->get_NavigationId(&navigationId))) {
            navigationActions_.insert({ navigationId, navigationAction });
          }

          // if shouldOverrideUrlLoading is not used, then call onLoadStart and onProgressChanged here
          if (!settings->useShouldOverrideUrlLoading) {
            channelDelegate->onLoadStart(url);
            channelDelegate->onProgressChanged(0);
          }
          args->put_Cancel(false);

          return S_OK;
        }
      ).Get(), nullptr));

    failedLog(webView->add_ContentLoading(
      Callback<ICoreWebView2ContentLoadingEventHandler>(
        [this](ICoreWebView2* sender, ICoreWebView2ContentLoadingEventArgs* args)
        {
          if (channelDelegate) {
            channelDelegate->onProgressChanged(33);
          }
          return S_OK;
        }
      ).Get(), nullptr));

    failedLog(webView->add_NavigationCompleted(
      Callback<ICoreWebView2NavigationCompletedEventHandler>(
        [this](ICoreWebView2* sender, ICoreWebView2NavigationCompletedEventArgs* args)
        {
          isLoading_ = false;

          evaluateJavascript(PLATFORM_READY_JS_SOURCE, ContentWorld::page(), nullptr);

          std::shared_ptr<NavigationAction> navigationAction;
          UINT64 navigationId;
          if (SUCCEEDED(args->get_NavigationId(&navigationId))) {
            navigationAction = map_at_or_null(navigationActions_, navigationId);
            if (navigationAction) {
              navigationActions_.erase(navigationId);
            }
          }

          COREWEBVIEW2_WEB_ERROR_STATUS webErrorType = COREWEBVIEW2_WEB_ERROR_STATUS_UNKNOWN;
          args->get_WebErrorStatus(&webErrorType);

          BOOL isSuccess;
          args->get_IsSuccess(&isSuccess);

          if (channelDelegate) {
            wil::unique_cotaskmem_string uri;
            std::optional<std::string> url = SUCCEEDED(webView->get_Source(&uri)) ? wide_to_utf8(uri.get()) : std::optional<std::string>{};

            channelDelegate->onProgressChanged(100);
            if (isSuccess) {
              channelDelegate->onLoadStop(url);
            }
            else if (!InAppWebView::isSslError(webErrorType) && navigationAction) {
              auto webResourceRequest = std::make_unique<WebResourceRequest>(url, navigationAction->request->method, navigationAction->request->headers, navigationAction->isForMainFrame);
              int httpStatusCode = 0;
              wil::com_ptr<ICoreWebView2NavigationCompletedEventArgs2> args2;
              if (SUCCEEDED(args->QueryInterface(IID_PPV_ARGS(&args2))) && SUCCEEDED(args2->get_HttpStatusCode(&httpStatusCode)) && httpStatusCode >= 400) {
                auto webResourceResponse = std::make_unique<WebResourceResponse>(std::optional<std::string>{},
                  std::optional<std::string>{},
                  httpStatusCode,
                  std::optional<std::string>{},
                  std::optional<std::map<std::string, std::string>>{},
                  std::optional<std::vector<uint8_t>>{});
                channelDelegate->onReceivedHttpError(std::move(webResourceRequest), std::move(webResourceResponse));
              }
              else if (httpStatusCode < 400) {
                auto webResourceError = std::make_unique<WebResourceError>(WebErrorStatusDescription[webErrorType], webErrorType);
                channelDelegate->onReceivedError(std::move(webResourceRequest), std::move(webResourceError));
              }
            }
          }

          return S_OK;
        }
      ).Get(), nullptr));

    failedLog(webView->add_DocumentTitleChanged(Callback<ICoreWebView2DocumentTitleChangedEventHandler>(
      [this](ICoreWebView2* sender, IUnknown* args)
      {
        if (channelDelegate) {
          wil::unique_cotaskmem_string title;
          sender->get_DocumentTitle(&title);
          channelDelegate->onTitleChanged(title.is_valid() ? wide_to_utf8(title.get()) : std::optional<std::string>{});
        }
        return S_OK;
      }
    ).Get(), nullptr));

    failedLog(webView->add_HistoryChanged(Callback<ICoreWebView2HistoryChangedEventHandler>(
      [this](ICoreWebView2* sender, IUnknown* args)
      {
        if (channelDelegate) {
          std::optional<bool> isReload = std::nullopt;
          if (lastNavigationAction_ && lastNavigationAction_->navigationType.has_value()) {
            isReload = lastNavigationAction_->navigationType.value() == NavigationActionType::reload;
          }
          channelDelegate->onUpdateVisitedHistory(getUrl(), isReload);
        }
        return S_OK;
      }
    ).Get(), nullptr));

    failedLog(webView->add_WebMessageReceived(Callback<ICoreWebView2WebMessageReceivedEventHandler>(
      [this, lifetime = std::weak_ptr<int>(callbackLifetime_)](ICoreWebView2* sender, ICoreWebView2WebMessageReceivedEventArgs* args)
      {
        if (lifetime.expired()) return S_OK;
        if (!channelDelegate) {
          return S_OK;
        }

        wil::unique_cotaskmem_string json;
        if (succeededOrLog(args->get_WebMessageAsJson(&json))) {
          auto message = nlohmann::json::parse(wide_to_utf8(json.get()));

          if (message.is_object() && message.contains("name") && message.at("name").is_string() && message.contains("body") && message.at("body").is_object()) {
            auto name = message.at("name").get<std::string>();
            auto body = message.at("body").get<nlohmann::json>();

            if (name.compare("callHandler") == 0 && body.contains("handlerName") && body.at("handlerName").is_string()) {
              auto handlerName = body.at("handlerName").get<std::string>();
              auto callHandlerID = body.at("_callHandlerID").is_number_integer() ? body.at("_callHandlerID").get<int64_t>() : 0;
              std::string handlerArgs = body.at("args").is_string() ? body.at("args").get<std::string>() : "";

              auto callback = std::make_unique<WebViewChannelDelegate::CallJsHandlerCallback>();
              callback->defaultBehaviour = [this, callHandlerID, lifetime = std::weak_ptr<int>(callbackLifetime_)](const std::optional<const flutter::EncodableValue*> response)
                {
                  if (lifetime.expired()) return;
                  std::string json = "null";
                  // A successful Dart void/null handler is an engaged optional
                  // containing nullptr, not necessarily an empty optional.
                  if (response.has_value() && response.value() && !response.value()->IsNull()) {
                    json = std::get<std::string>(*(response.value()));
                  }

                  evaluateJavascript("if (window." + JAVASCRIPT_BRIDGE_NAME + "[" + std::to_string(callHandlerID) + "] != null) { \
                      window." + JAVASCRIPT_BRIDGE_NAME + "[" + std::to_string(callHandlerID) + "].resolve(" + json + "); \
                      delete window." + JAVASCRIPT_BRIDGE_NAME + "[" + std::to_string(callHandlerID) + "]; \
                    }", ContentWorld::page(), nullptr);
                };
              callback->error = [this, callHandlerID, lifetime = std::weak_ptr<int>(callbackLifetime_)](const std::string& error_code, const std::string& error_message, const flutter::EncodableValue* error_details)
                {
                  if (lifetime.expired()) return;
                  auto errorMessage = error_code + ", " + error_message;
                  debugLog(errorMessage);

                  evaluateJavascript("if (window." + JAVASCRIPT_BRIDGE_NAME + "[" + std::to_string(callHandlerID) + "] != null) { \
                      window." + JAVASCRIPT_BRIDGE_NAME + "[" + std::to_string(callHandlerID) + "].reject(new Error('" + replace_all_copy(errorMessage, "\'", "\\'") + "')); \
                      delete window." + JAVASCRIPT_BRIDGE_NAME + "[" + std::to_string(callHandlerID) + "]; \
                    }", ContentWorld::page(), nullptr);
                };
              channelDelegate->onCallJsHandler(handlerName, handlerArgs, std::move(callback));
            }
          }
        }

        return S_OK;
      }
    ).Get(), &webMessageToken_));

    wil::com_ptr<ICoreWebView2DevToolsProtocolEventReceiver> consoleMessageReceiver;
    if (succeededOrLog(webView->GetDevToolsProtocolEventReceiver(L"Runtime.consoleAPICalled", &consoleMessageReceiver))) {
      failedLog(consoleMessageReceiver->add_DevToolsProtocolEventReceived(
        Callback<ICoreWebView2DevToolsProtocolEventReceivedEventHandler>(
          [this](
            ICoreWebView2* sender,
            ICoreWebView2DevToolsProtocolEventReceivedEventArgs* args) -> HRESULT
          {

            if (!channelDelegate) {
              return S_OK;
            }

            wil::unique_cotaskmem_string json;
            if (succeededOrLog(args->get_ParameterObjectAsJson(&json))) {
              auto consoleMessageJson = nlohmann::json::parse(wide_to_utf8(json.get()));

              auto level = consoleMessageJson.at("type").get<std::string>();
              int64_t messageLevel = 1;
              if (string_equals(level, "log")) {
                messageLevel = 1;
              }
              else if (string_equals(level, "debug")) {
                messageLevel = 0;
              }
              else if (string_equals(level, "error")) {
                messageLevel = 3;
              }
              else if (string_equals(level, "info")) {
                messageLevel = 1;
              }
              else if (string_equals(level, "warn")) {
                messageLevel = 2;
              }

              auto consoleArgs = consoleMessageJson.at("args").get<std::vector<nlohmann::json>>();
              auto message = join(functional_map(consoleArgs, [](const nlohmann::json& json) { return json.contains("value") ? json.at("value").dump() : (json.contains("description") ? json.at("description").dump() : json.dump()); }), std::string{ " " });
              channelDelegate->onConsoleMessage(message, messageLevel);
            }

            return S_OK;
          })
        .Get(), nullptr));
    }

    failedLog(webView->add_NewWindowRequested(
      Callback<ICoreWebView2NewWindowRequestedEventHandler>(
        [this, lifetime = std::weak_ptr<int>(callbackLifetime_)](ICoreWebView2* sender, ICoreWebView2NewWindowRequestedEventArgs* args)
        {
          if (lifetime.expired()) return S_OK;
          wil::com_ptr<ICoreWebView2Deferral> deferral;
          if (channelDelegate && plugin && plugin->inAppWebViewManager && succeededOrLog(args->GetDeferral(&deferral))) {
            plugin->inAppWebViewManager->windowAutoincrementId++;
            int64_t windowId = plugin->inAppWebViewManager->windowAutoincrementId;
            wil::com_ptr<ICoreWebView2NewWindowRequestedEventArgs> retainedArgs = args;
            auto newWindowRequestedArgs = std::make_unique<NewWindowRequestedArgs>(retainedArgs, deferral);
            plugin->inAppWebViewManager->windowWebViews.insert({ windowId, std::move(newWindowRequestedArgs) });
            pendingWindowIds_.insert(windowId);

            wil::unique_cotaskmem_string uri = nullptr;
            std::optional<std::string> url = SUCCEEDED(args->get_Uri(&uri)) ? wide_to_utf8(uri.get()) : std::optional<std::string>{};

            BOOL hasGesture;
            if (FAILED(args->get_IsUserInitiated(&hasGesture))) {
              hasGesture = FALSE;
            }

            wil::com_ptr<ICoreWebView2WindowFeatures> webviewWindowFeatures;
            std::optional<std::unique_ptr<WindowFeatures>> windowFeatures;
            if (SUCCEEDED(args->get_WindowFeatures(&webviewWindowFeatures))) {
              windowFeatures = std::make_unique<WindowFeatures>(webviewWindowFeatures);
            }

            auto urlRequest = std::make_shared<URLRequest>(url, "GET", std::nullopt, std::nullopt);
            auto createWindowAction = std::make_shared<CreateWindowAction>(
              urlRequest,
              windowId,
              true,
              hasGesture,
              std::move(windowFeatures));

            auto callback = std::make_unique<WebViewChannelDelegate::CreateWindowCallback>();
            auto defaultBehaviour = [this, windowId, urlRequest, deferral, retainedArgs, lifetime = std::weak_ptr<int>(callbackLifetime_)](const std::optional<const bool> handledByClient)
              {
                if (lifetime.expired()) return;
                if (plugin && plugin->inAppWebViewManager && map_contains(plugin->inAppWebViewManager->windowWebViews, windowId)) {
                  plugin->inAppWebViewManager->windowWebViews.erase(windowId);
                }
                pendingWindowIds_.erase(windowId);
                failedLog(retainedArgs->put_Handled(TRUE));
                failedLog(deferral->Complete());
                loadUrl(urlRequest);
              };
            callback->nonNullSuccess = [](const bool handledByClient)
              {
                return !handledByClient;
              };
            callback->defaultBehaviour = defaultBehaviour;
            callback->error = [defaultBehaviour](const std::string& error_code, const std::string& error_message, const flutter::EncodableValue* error_details)
              {
                debugLog(error_code + ", " + error_message);
                defaultBehaviour(std::nullopt);
              };
            channelDelegate->onCreateWindow(std::move(createWindowAction), std::move(callback));
          }
          return S_OK;
        }
      ).Get(), &newWindowToken_));

    failedLog(webView->add_WindowCloseRequested(Callback<ICoreWebView2WindowCloseRequestedEventHandler>(
      [this](ICoreWebView2* sender, IUnknown* args)
      {
        if (channelDelegate) {
          channelDelegate->onCloseWindow();
        }
        return S_OK;
      }
    ).Get(), nullptr));

    failedLog(webView->add_PermissionRequested(Callback<ICoreWebView2PermissionRequestedEventHandler>(
      [this](ICoreWebView2* sender, ICoreWebView2PermissionRequestedEventArgs* args)
      {
        wil::com_ptr<ICoreWebView2Deferral> deferral;
        if (channelDelegate && succeededOrLog(args->GetDeferral(&deferral))) {
          wil::unique_cotaskmem_string uri;
          std::string url = SUCCEEDED(args->get_Uri(&uri)) ? wide_to_utf8(uri.get()) : "";

          COREWEBVIEW2_PERMISSION_KIND resource = COREWEBVIEW2_PERMISSION_KIND_UNKNOWN_PERMISSION;
          failedAndLog(args->get_PermissionKind(&resource));

          auto callback = std::make_unique<WebViewChannelDelegate::PermissionRequestCallback>();
          auto defaultBehaviour = [this, deferral, args](const std::optional<const std::shared_ptr<PermissionResponse>> permissionResponse)
            {
              failedLog(args->put_State(COREWEBVIEW2_PERMISSION_STATE_DENY));
              failedLog(deferral->Complete());
            };
          callback->nonNullSuccess = [this, deferral, args](const std::shared_ptr<PermissionResponse> permissionResponse)
            {
              auto action = permissionResponse->action;
              if (action.has_value()) {
                switch (action.value()) {
                case PermissionResponseActionType::grant:
                  failedLog(args->put_State(COREWEBVIEW2_PERMISSION_STATE_ALLOW));
                  break;
                case PermissionResponseActionType::prompt:
                  failedLog(args->put_State(COREWEBVIEW2_PERMISSION_STATE_DEFAULT));
                  break;
                default:
                  failedLog(args->put_State(COREWEBVIEW2_PERMISSION_STATE_DENY));
                  break;
                }
                failedLog(deferral->Complete());
                return false;
              }
              return true;
            };
          callback->defaultBehaviour = defaultBehaviour;
          callback->error = [this, defaultBehaviour](const std::string& error_code, const std::string& error_message, const flutter::EncodableValue* error_details)
            {
              debugLog(error_code + ", " + error_message);
              defaultBehaviour(std::nullopt);
            };
          channelDelegate->onPermissionRequest(url, { resource }, std::move(callback));
        }
        return S_OK;
      }
    ).Get(), nullptr));

    failedLog(webView->AddWebResourceRequestedFilter(L"*", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL));
    failedLog(webView->add_WebResourceRequested(
      Callback<ICoreWebView2WebResourceRequestedEventHandler>(
        [this](
          ICoreWebView2* sender, ICoreWebView2WebResourceRequestedEventArgs* args)
        {
          wil::com_ptr<ICoreWebView2Deferral> deferral;
          wil::com_ptr<ICoreWebView2WebResourceRequest> webResourceRequest;
          if (channelDelegate && succeededOrLog(args->get_Request(&webResourceRequest)) && succeededOrLog(args->GetDeferral(&deferral))) {
            auto request = std::make_shared<WebResourceRequest>(webResourceRequest);

            // The add_WebResourceRequested event is by default raised for file, http, and https URI schemes.
            // This is also raised for registered custom URI schemes.
            // https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.2792.45#add_webresourcerequested
            auto url = request->url.has_value() ? request->url.value() : "";
            auto isCustomScheme = !url.empty() && !starts_with(url, std::string{ "file://" }) && !starts_with(url, std::string{ "http://" }) && !starts_with(url, std::string{ "https://" });

            auto onLoadResourceWithCustomSchemeCallback = [this, deferral, request, args]()
              {
                if (channelDelegate) {
                  auto callback = std::make_unique<WebViewChannelDelegate::LoadResourceWithCustomSchemeCallback>();
                  auto defaultBehaviour = [this, deferral, args](const std::optional<std::shared_ptr<CustomSchemeResponse>> response)
                    {
                      failedLog(deferral->Complete());
                    };
                  callback->nonNullSuccess = [this, deferral, args](const std::shared_ptr<CustomSchemeResponse> response)
                    {
                      args->put_Response(response->toWebView2Response(webViewEnv));
                      failedLog(deferral->Complete());
                      return false;
                    };
                  callback->defaultBehaviour = defaultBehaviour;
                  callback->error = [this, defaultBehaviour](const std::string& error_code, const std::string& error_message, const flutter::EncodableValue* error_details)
                    {
                      debugLog(error_code + ", " + error_message);
                      defaultBehaviour(std::nullopt);
                    };
                  channelDelegate->onLoadResourceWithCustomScheme(request, std::move(callback));
                }
                else {
                  failedLog(deferral->Complete());
                }
              };

            if (settings->useShouldInterceptRequest) {
              auto callback = std::make_unique<WebViewChannelDelegate::ShouldInterceptRequestCallback>();
              auto defaultBehaviour = [this, deferral, args](const std::optional<std::shared_ptr<WebResourceResponse>> response)
                {
                  failedLog(deferral->Complete());
                };
              callback->nonNullSuccess = [this, deferral, args](const std::shared_ptr<WebResourceResponse> response)
                {
                  args->put_Response(response->toWebView2Response(webViewEnv));
                  failedLog(deferral->Complete());
                  return false;
                };
              callback->nullSuccess = [this, deferral, args, isCustomScheme, onLoadResourceWithCustomSchemeCallback]()
                {
                  if (isCustomScheme) {
                    onLoadResourceWithCustomSchemeCallback();
                  }
                  else {
                    failedLog(deferral->Complete());
                  }
                  return false;
                };
              callback->defaultBehaviour = defaultBehaviour;
              callback->error = [this, defaultBehaviour](const std::string& error_code, const std::string& error_message, const flutter::EncodableValue* error_details)
                {
                  debugLog(error_code + ", " + error_message);
                  defaultBehaviour(std::nullopt);
                };
              channelDelegate->shouldInterceptRequest(request, std::move(callback));
            }
            else if (isCustomScheme) {
              onLoadResourceWithCustomSchemeCallback();
            }
            else {
              failedLog(deferral->Complete());
            }
          }
          return S_OK;
        }
      ).Get(), nullptr));

    wil::com_ptr<ICoreWebView2_2> webView2;
    if (SUCCEEDED(webView->QueryInterface(IID_PPV_ARGS(&webView2)))) {
      failedLog(webView2->add_DOMContentLoaded(
        Callback<ICoreWebView2DOMContentLoadedEventHandler>(
          [this](ICoreWebView2* sender, ICoreWebView2DOMContentLoadedEventArgs* args)
          {
            if (channelDelegate) {
              channelDelegate->onProgressChanged(66);
            }
            return S_OK;
          }
        ).Get(), nullptr));
    }

    /*
    wil::com_ptr<ICoreWebView2_14> webView14;
    if (SUCCEEDED(webView->QueryInterface(IID_PPV_ARGS(&webView14)))) {
      failedLog(webView14->add_ServerCertificateErrorDetected(
        Callback<ICoreWebView2ServerCertificateErrorDetectedEventHandler>(
          [this](ICoreWebView2* sender, ICoreWebView2ServerCertificateErrorDetectedEventArgs* args)
          {
            debugLog("add_ServerCertificateErrorDetected");
            wil::com_ptr<ICoreWebView2Certificate> certificate = nullptr;
            if (SUCCEEDED(args->get_ServerCertificate(&certificate))) {
              wil::unique_cotaskmem_string displayName = nullptr;
              std::optional<std::string> url = SUCCEEDED(certificate->get_DisplayName(&displayName)) ? wide_to_utf8(displayName.get()) : std::optional<std::string>{};
              debugLog(displayName.get());
            }
            return S_OK;
          }
        ).Get(), nullptr));
    }*/

    if (userContentController) {
      userContentController->registerEventHandlers();
    }
  }

  void InAppWebView::registerSurfaceEventHandlers()
  {
    if (!webViewCompositionController) {
      return;
    }

    failedLog(webViewCompositionController->add_CursorChanged(
      Callback<ICoreWebView2CursorChangedEventHandler>(
        [this](ICoreWebView2CompositionController* sender,
          IUnknown* args) -> HRESULT
        {
          HCURSOR cursor;
          if (cursorChangedCallback_ &&
            sender->get_Cursor(&cursor) == S_OK) {
            cursorChangedCallback_(cursor);
          }
          return S_OK;
        })
      .Get(), nullptr));
  }

  std::optional<std::string> InAppWebView::getUrl() const
  {
    wil::unique_cotaskmem_string uri;
    return webView && succeededOrLog(webView->get_Source(&uri)) ? wide_to_utf8(uri.get()) : std::optional<std::string>{};
  }

  std::optional<std::string> InAppWebView::getTitle() const
  {
    wil::unique_cotaskmem_string title;
    return webView && succeededOrLog(webView->get_DocumentTitle(&title)) ? wide_to_utf8(title.get()) : std::optional<std::string>{};
  }

  void InAppWebView::loadUrl(const std::shared_ptr<URLRequest> urlRequest) const
  {
    if (!webView || !urlRequest->url.has_value()) {
      return;
    }

    std::wstring url = utf8_to_wide(urlRequest->url.value());

    wil::com_ptr<ICoreWebView2Environment2> webViewEnv2;
    wil::com_ptr<ICoreWebView2_2> webView2;
    if (SUCCEEDED(webViewEnv->QueryInterface(IID_PPV_ARGS(&webViewEnv2))) && SUCCEEDED(webView->QueryInterface(IID_PPV_ARGS(&webView2)))) {
      wil::com_ptr<ICoreWebView2WebResourceRequest> webResourceRequest;
      std::wstring method = urlRequest->method.has_value() ? utf8_to_wide(urlRequest->method.value()) : L"GET";

      wil::com_ptr<IStream> postDataStream = nullptr;
      if (urlRequest->body.has_value()) {
        auto postData = std::string(urlRequest->body->begin(), urlRequest->body->end());
        postDataStream = SHCreateMemStream(
          reinterpret_cast<const BYTE*>(postData.data()), static_cast<UINT>(postData.length()));
      }
      if (succeededOrLog(webViewEnv2->CreateWebResourceRequest(
        url.c_str(),
        method.c_str(),
        postDataStream.get(),
        L"",
        &webResourceRequest
      ))) {
        wil::com_ptr<ICoreWebView2HttpRequestHeaders> requestHeaders;
        if (SUCCEEDED(webResourceRequest->get_Headers(&requestHeaders))) {
          if (method.compare(L"GET") != 0) {
            requestHeaders->SetHeader(L"Flutter-InAppWebView-Request-Method", method.c_str());
          }
          if (urlRequest->headers.has_value()) {
            auto& headers = urlRequest->headers.value();
            for (auto const& [key, val] : headers) {
              requestHeaders->SetHeader(utf8_to_wide(key).c_str(), utf8_to_wide(val).c_str());
            }
          }
        }
        failedLog(webView2->NavigateWithWebResourceRequest(webResourceRequest.get()));
      }
      return;
    }
    failedLog(webView->Navigate(url.c_str()));
  }


  void InAppWebView::loadFile(const std::string& assetFilePath) const
  {
    if (!webView) {
      return;
    }

    WCHAR* buf = new WCHAR[32768];
    GetModuleFileName(NULL, buf, 32768);
    std::filesystem::path exeAbsPath = std::wstring(buf);
    delete[] buf;

    std::filesystem::path flutterAssetPath("data/flutter_assets/" + assetFilePath);
    auto absAssetFilePath = exeAbsPath.parent_path() / flutterAssetPath;

    if (!std::filesystem::exists(absAssetFilePath)) {
      debugLog(absAssetFilePath.native() + L" asset file cannot be found!");
      return;
    }
    failedLog(webView->Navigate(absAssetFilePath.c_str()));
  }

  void InAppWebView::loadData(const std::string& data) const
  {
    if (!webView) {
      return;
    }

    failedLog(webView->NavigateToString(utf8_to_wide(data).c_str()));
  }

  void InAppWebView::reload() const
  {
    if (!webView) {
      return;
    }

    failedLog(webView->Reload());
  }

  void InAppWebView::goBack()
  {
    if (!webView) {
      return;
    }

    failedLog(webView->GoBack());
  }

  bool InAppWebView::canGoBack() const
  {
    BOOL canGoBack_;
    return webView && succeededOrLog(webView->get_CanGoBack(&canGoBack_)) ? canGoBack_ : false;
  }

  void InAppWebView::goForward()
  {
    if (!webView) {
      return;
    }

    failedLog(webView->GoForward());
  }

  bool InAppWebView::canGoForward() const
  {
    BOOL canGoForward_;
    return webView && succeededOrLog(webView->get_CanGoForward(&canGoForward_)) ? canGoForward_ : false;
  }

  void InAppWebView::goBackOrForward(const int64_t& steps)
  {
    getCopyBackForwardList(
      [this, steps](std::unique_ptr<WebHistory> webHistory)
      {
        if (webHistory && webHistory->currentIndex.has_value() && webHistory->list.has_value()) {
          auto currentIndex = webHistory->currentIndex.value();
          auto items = &webHistory->list.value();
          auto nextIndex = currentIndex + steps;
          int64_t size = items->size();
          if (nextIndex >= 0 && nextIndex < size) {
            auto entryId = items->at(nextIndex)->entryId;
            if (entryId.has_value()) {
              failedAndLog(webView->CallDevToolsProtocolMethod(L"Page.navigateToHistoryEntry", utf8_to_wide("{\"entryId\": " + std::to_string(entryId.value()) + "}").c_str(), Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
                [this](HRESULT errorCode, LPCWSTR returnObjectAsJson)
                {
                  failedLog(errorCode);
                  return S_OK;
                }
              ).Get()));
            }
          }
        }
      }
    );
  }

  void InAppWebView::canGoBackOrForward(const int64_t& steps, std::function<void(bool)> completionHandler) const
  {
    getCopyBackForwardList(
      [steps, completionHandler](std::unique_ptr<WebHistory> webHistory)
      {
        auto canGoBackOrForward_ = false;
        if (webHistory && webHistory->currentIndex.has_value() && webHistory->list.has_value()) {
          auto currentIndex = webHistory->currentIndex.value();
          auto items = &webHistory->list.value();
          auto nextIndex = currentIndex + steps;
          int64_t size = items->size();
          canGoBackOrForward_ = nextIndex >= 0 && nextIndex < size;
        }

        if (completionHandler) {
          completionHandler(canGoBackOrForward_);
        }
      }
    );
  }

  void InAppWebView::stopLoading() const
  {
    if (!webView) {
      return;
    }

    failedLog(webView->Stop());
  }

  void InAppWebView::getCopyBackForwardList(const std::function<void(std::unique_ptr<WebHistory>)> completionHandler) const
  {
    if (!webView) {
      if (completionHandler) {
        completionHandler(std::make_unique<WebHistory>(std::nullopt, std::nullopt));
      }
      return;
    }

    failedLog(webView->CallDevToolsProtocolMethod(L"Page.getNavigationHistory", L"{}", Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
      [completionHandler](HRESULT errorCode, LPCWSTR returnObjectAsJson)
      {
        if (!completionHandler) {
          return S_OK;
        }

        if (errorCode == S_OK) {
          auto historyJson = nlohmann::json::parse(wide_to_utf8(returnObjectAsJson));

          int64_t currentIndex = historyJson.at("currentIndex").is_number_unsigned() ? historyJson.at("currentIndex").get<int64_t>() : 0;
          std::vector<nlohmann::json> entries = historyJson.at("entries").is_array() ? historyJson.at("entries").get<std::vector<nlohmann::json>>() : std::vector<nlohmann::json>{};

          std::vector<std::shared_ptr<WebHistoryItem>> webHistoryItems;
          webHistoryItems.reserve(entries.size());
          int64_t i = 0;
          for (auto const& entry : entries) {
            int64_t offset = i - currentIndex;
            webHistoryItems.push_back(std::make_shared<WebHistoryItem>(
              entry.at("id").is_number_integer() ? entry.at("id").get<int64_t>() : std::optional<int64_t>{},
              i,
              offset,
              entry.at("userTypedURL").is_string() ? entry.at("userTypedURL").get<std::string>() : std::optional<std::string>{},
              entry.at("title").is_string() ? entry.at("title").get<std::string>() : std::optional<std::string>{},
              entry.at("url").is_string() ? entry.at("url").get<std::string>() : std::optional<std::string>{}
            ));
            i++;
          }

          completionHandler(std::make_unique<WebHistory>(currentIndex, webHistoryItems));
        }
        else {
          debugLog(errorCode);
          completionHandler(std::make_unique<WebHistory>(std::nullopt, std::nullopt));
        }

        return S_OK;
      }
    ).Get()));
  }

  void InAppWebView::evaluateJavascript(const std::string& source, const std::shared_ptr<ContentWorld> contentWorld, const std::function<void(std::string)> completionHandler) const
  {
    if (!webView || !userContentController) {
      if (completionHandler) {
        completionHandler("null");
      }
      return;
    }

    userContentController->createContentWorld(contentWorld,
      [=](const int& contextId)
      {
        nlohmann::json parameters = {
          {"expression", source},
          { "returnByValue", true }
        };

        if (contextId >= 0) {
          parameters["contextId"] = contextId;
        }

        auto hr = webView->CallDevToolsProtocolMethod(L"Runtime.evaluate", utf8_to_wide(parameters.dump()).c_str(), Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
        [this, completionHandler, lifetime = std::weak_ptr<int>(callbackLifetime_)](HRESULT errorCode, LPCWSTR returnObjectAsJson)
          {
            if (lifetime.expired()) return S_OK;
            nlohmann::json result;
            if (succeededOrLog(errorCode)) {
              nlohmann::json json = nlohmann::json::parse(wide_to_utf8(returnObjectAsJson));
              result = json["result"].contains("value") ? json["result"]["value"] : nlohmann::json{};
              if (json.contains("exceptionDetails")) {
                nlohmann::json exceptionDetails = json["exceptionDetails"];
                auto errorMessage = exceptionDetails.contains("exception") && exceptionDetails["exception"].contains("value")
                  ? exceptionDetails["exception"]["value"].dump() :
                  (result["value"].is_null() ? exceptionDetails["text"].get<std::string>() : result["value"].dump());
                result = nlohmann::json{};
                debugLog(exceptionDetails.dump());
                if (channelDelegate) {
                  channelDelegate->onConsoleMessage(errorMessage, 3);
                }
              }
            }
            if (completionHandler) {
              completionHandler(result.dump());
            }
            return S_OK;
          }
        ).Get());

        if (failedAndLog(hr) && completionHandler) {
          completionHandler("null");
        }
      });
  }

  void InAppWebView::callAsyncJavaScript(const std::string& functionBody, const std::string& argumentsAsJson, const std::shared_ptr<ContentWorld> contentWorld, const std::function<void(std::string)> completionHandler) const
  {
    if (!webView || !userContentController) {
      if (completionHandler) {
        completionHandler("null");
      }
      return;
    }

    userContentController->createContentWorld(contentWorld,
      [=](const int& contextId)
      {
        std::vector<std::string> functionArgumentNamesList;
        std::vector<std::string> functionArgumentValuesList;

        auto jsonVal = nlohmann::json::parse(argumentsAsJson);
        for (auto const& [key, val] : jsonVal.items()) {
          functionArgumentNamesList.push_back(key);
          functionArgumentValuesList.push_back(val.dump());
        }

        auto source = replace_all_copy(CALL_ASYNC_JAVASCRIPT_WRAPPER_JS, VAR_FUNCTION_ARGUMENT_NAMES, join(functionArgumentNamesList, ", "));
        replace_all(source, VAR_FUNCTION_ARGUMENT_VALUES, join(functionArgumentValuesList, ", "));
        replace_all(source, VAR_FUNCTION_BODY, functionBody);

        nlohmann::json parameters = {
          {"expression", source},
          {"awaitPromise", true},
          { "returnByValue", true }
        };

        if (contextId >= 0) {
          parameters["contextId"] = contextId;
        }

        auto hr = webView->CallDevToolsProtocolMethod(L"Runtime.evaluate", utf8_to_wide(parameters.dump()).c_str(), Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
          [this, completionHandler](HRESULT errorCode, LPCWSTR returnObjectAsJson)
          {
            nlohmann::json result = {
              {"value", nlohmann::json{}},
              {"error", nlohmann::json{}}
            };
            if (succeededOrLog(errorCode)) {
              nlohmann::json json = nlohmann::json::parse(wide_to_utf8(returnObjectAsJson));
              result["value"] = json["result"].contains("value") ? json["result"]["value"] : nlohmann::json{};
              if (json.contains("exceptionDetails")) {
                nlohmann::json exceptionDetails = json["exceptionDetails"];
                auto errorMessage = exceptionDetails.contains("exception") && exceptionDetails["exception"].contains("value")
                  ? exceptionDetails["exception"]["value"].dump() :
                  (result["value"].is_null() ? exceptionDetails["text"].get<std::string>() : result["value"].dump());
                result["value"] = nlohmann::json{};
                result["error"] = errorMessage;
                debugLog(exceptionDetails.dump());
                if (channelDelegate) {
                  channelDelegate->onConsoleMessage(errorMessage, 3);
                }
              }
            }
            if (completionHandler) {
              completionHandler(result.dump());
            }
            return S_OK;
          }
        ).Get());

        if (failedAndLog(hr) && completionHandler) {
          completionHandler("null");
        }
      });
  }

  void InAppWebView::addUserScript(const std::shared_ptr<UserScript> userScript) const
  {
    if (!userContentController) {
      return;
    }

    userContentController->addUserOnlyScript(userScript);
  }

  void InAppWebView::removeUserScript(const int64_t index, const std::shared_ptr<UserScript> userScript) const
  {
    if (!userContentController) {
      return;
    }

    userContentController->removeUserOnlyScriptAt(index, userScript->injectionTime);
  }

  void InAppWebView::removeUserScriptsByGroupName(const std::string& groupName) const
  {
    if (!userContentController) {
      return;
    }

    userContentController->removeUserOnlyScriptsByGroupName(groupName);
  }

  void InAppWebView::removeAllUserScripts() const
  {
    if (!userContentController) {
      return;
    }

    userContentController->removeAllUserOnlyScripts();
  }

  void InAppWebView::takeScreenshot(const std::optional<std::shared_ptr<ScreenshotConfiguration>> screenshotConfiguration, const std::function<void(const std::optional<std::string>)> completionHandler) const
  {
    if (!webView) {
      if (completionHandler) {
        completionHandler(std::nullopt);
      }
      return;
    }

    nlohmann::json parameters = {};
    if (screenshotConfiguration.has_value()) {
      auto& scp = screenshotConfiguration.value();
      parameters["format"] = to_lowercase_copy(CompressFormatToString(scp->compressFormat));
      if (scp->compressFormat == CompressFormat::jpeg) {
        parameters["quality"] = scp->quality;
      }
      if (scp->rect.has_value()) {
        auto& rect = scp->rect.value();
        parameters["clip"] = {
          {"x", rect->x},
          {"y", rect->y},
          {"width", rect->width},
          {"height", rect->height},
          {"scale", scaleFactor_}
        };
      }
    }

    auto hr = webView->CallDevToolsProtocolMethod(L"Page.captureScreenshot", utf8_to_wide(parameters.dump()).c_str(), Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
      [this, completionHandler](HRESULT errorCode, LPCWSTR returnObjectAsJson)
      {
        std::optional<std::string> result = std::nullopt;
        if (succeededOrLog(errorCode)) {
          nlohmann::json json = nlohmann::json::parse(wide_to_utf8(returnObjectAsJson));
          result = json["data"].get<std::string>();
        }
        if (completionHandler) {
          completionHandler(result);
        }
        return S_OK;
      }
    ).Get());
    if (failedAndLog(hr) && completionHandler) {
      completionHandler(std::nullopt);
    }
  }

  void InAppWebView::setSettings(const std::shared_ptr<InAppWebViewSettings> newSettings, const flutter::EncodableMap& newSettingsMap)
  {
    wil::com_ptr<ICoreWebView2Settings> webView2Settings;
    if (succeededOrLog(webView->get_Settings(&webView2Settings))) {
      if (fl_map_contains_not_null(newSettingsMap, "javaScriptEnabled") && settings->javaScriptEnabled != newSettings->javaScriptEnabled) {
        webView2Settings->put_IsScriptEnabled(newSettings->javaScriptEnabled);
      }

      if (fl_map_contains_not_null(newSettingsMap, "supportZoom") && settings->supportZoom != newSettings->supportZoom) {
        webView2Settings->put_IsZoomControlEnabled(newSettings->supportZoom);
      }

      if (fl_map_contains_not_null(newSettingsMap, "isInspectable") && settings->isInspectable != newSettings->isInspectable) {
        webView2Settings->put_AreDevToolsEnabled(newSettings->isInspectable);
      }

      if (fl_map_contains_not_null(newSettingsMap, "disableContextMenu") && settings->disableContextMenu != newSettings->disableContextMenu) {
        webView2Settings->put_AreDefaultContextMenusEnabled(!newSettings->disableContextMenu);
      }

      wil::com_ptr<ICoreWebView2Settings2> webView2Settings2;
      if (succeededOrLog(webView2Settings->QueryInterface(IID_PPV_ARGS(&webView2Settings2)))) {
        if (fl_map_contains_not_null(newSettingsMap, "userAgent") && !string_equals(settings->userAgent, newSettings->userAgent)) {
          webView2Settings2->put_UserAgent(utf8_to_wide(newSettings->userAgent).c_str());
        }
      }
    }

    wil::com_ptr<ICoreWebView2Controller2> webViewController2;
    if (succeededOrLog(webViewController->QueryInterface(IID_PPV_ARGS(&webViewController2)))) {
      if (fl_map_contains_not_null(newSettingsMap, "transparentBackground") && settings->transparentBackground != newSettings->transparentBackground) {
        BYTE alpha = newSettings->transparentBackground ? 0 : 255;
        webViewController2->put_DefaultBackgroundColor({ alpha, 255, 255, 255 });
      }
    }

    settings = newSettings;
  }

  flutter::EncodableValue InAppWebView::getSettings() const
  {
    if (!settings || !webView) {
      return make_fl_value();
    }

    return settings->getRealSettings(this);
  }

  void InAppWebView::openDevTools() const
  {
    if (!webView) {
      return;
    }

    failedLog(webView->OpenDevToolsWindow());
  }

  void InAppWebView::callDevToolsProtocolMethod(const std::string& methodName, const std::optional<std::string>& parametersAsJson, const std::function<void(const HRESULT& errorCode, const std::optional<std::string>&)> completionHandler) const
  {
    if (!webView) {
      if (completionHandler) {
        completionHandler(S_OK, std::nullopt);
      }
      return;
    }

    auto hr = webView->CallDevToolsProtocolMethod(
      utf8_to_wide(methodName).c_str(),
      !parametersAsJson.has_value() || parametersAsJson.value().empty() ? L"{}" : utf8_to_wide(parametersAsJson.value()).c_str(),
      Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
        [completionHandler](HRESULT errorCode, LPCWSTR returnObjectAsJson)
        {
          failedLog(errorCode);
          if (completionHandler) {
            completionHandler(errorCode, wide_to_utf8(returnObjectAsJson));
          }
          return S_OK;
        }
      ).Get());

    if (failedAndLog(hr) && completionHandler) {
      completionHandler(hr, std::nullopt);
    }
  }

  void InAppWebView::addDevToolsProtocolEventListener(const std::string& eventName)
  {
    if (map_contains(devToolsProtocolEventListener_, eventName)) {
      return;
    }

    wil::com_ptr<ICoreWebView2DevToolsProtocolEventReceiver> eventReceiver;
    if (succeededOrLog(webView->GetDevToolsProtocolEventReceiver(utf8_to_wide(eventName).c_str(), &eventReceiver))) {
      EventRegistrationToken token = {};
      auto hr = eventReceiver->add_DevToolsProtocolEventReceived(
        Callback<ICoreWebView2DevToolsProtocolEventReceivedEventHandler>(
          [this, eventName](
            ICoreWebView2* sender,
            ICoreWebView2DevToolsProtocolEventReceivedEventArgs* args) -> HRESULT
          {
            if (!channelDelegate) {
              return S_OK;
            }

            wil::unique_cotaskmem_string json;
            failedLog(args->get_ParameterObjectAsJson(&json));
            channelDelegate->onDevToolsProtocolEventReceived(eventName, wide_to_utf8(json.get()));

            return S_OK;
          })
        .Get(), &token);
      if (succeededOrLog(hr)) {
        devToolsProtocolEventListener_.insert({ eventName, std::make_pair(std::move(eventReceiver), token) });
      }
    }
  }

  void InAppWebView::removeDevToolsProtocolEventListener(const std::string& eventName)
  {
    if (map_contains(devToolsProtocolEventListener_, eventName)) {
      auto eventReceiver = devToolsProtocolEventListener_.at(eventName).first;
      auto token = devToolsProtocolEventListener_.at(eventName).second;
      eventReceiver->remove_DevToolsProtocolEventReceived(token);
      devToolsProtocolEventListener_.erase(eventName);
    }
  }


  void InAppWebView::pause() const
  {
    wil::com_ptr<ICoreWebView2_3> webView3;
    if (SUCCEEDED(webView->QueryInterface(IID_PPV_ARGS(&webView3))) && succeededOrLog(webViewController->put_IsVisible(false))) {
      failedLog(webView3->TrySuspend(Callback<ICoreWebView2TrySuspendCompletedHandler>(
        [this](HRESULT errorCode, BOOL isSuccessful) -> HRESULT
        {
          failedLog(errorCode);
          return S_OK;
        })
        .Get()));
    }
  }

  void InAppWebView::resume() const
  {
    wil::com_ptr<ICoreWebView2_3> webView3;
    if (SUCCEEDED(webView->QueryInterface(IID_PPV_ARGS(&webView3))) && succeededOrLog(webViewController->put_IsVisible(true))) {
      failedLog(webView3->Resume());
    }
  }

  bool InAppWebView::requestFocus() const
  {
    return webViewController && succeededOrLog(
      webViewController->MoveFocus(COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC));
  }


  void InAppWebView::getCertificate(const std::function<void(const std::optional<std::unique_ptr<SslCertificate>>)> completionHandler) const
  {
    auto url = getUrl();
    if (!webView || !url.has_value()) {
      if (completionHandler) {
        completionHandler(std::nullopt);
      }
      return;
    }

    nlohmann::json parameters = {
      {"origin", url.value()}
    };

    auto hr = webView->CallDevToolsProtocolMethod(L"Network.getCertificate", utf8_to_wide(parameters.dump()).c_str(), Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
      [this, completionHandler](HRESULT errorCode, LPCWSTR returnObjectAsJson)
      {
        std::optional<std::unique_ptr<SslCertificate>> result = std::nullopt;
        if (succeededOrLog(errorCode)) {
          nlohmann::json json = nlohmann::json::parse(wide_to_utf8(returnObjectAsJson));
          if (json.at("tableNames").is_array()) {
            auto tableNames = json.at("tableNames").get<std::vector<std::string>>();
            if (tableNames.size() > 0) {
              result = std::make_unique<SslCertificate>(tableNames.at(0));
            }
          }
        }
        if (completionHandler) {
          completionHandler(std::move(result));
        }
        return S_OK;
      }
    ).Get());
    if (failedAndLog(hr) && completionHandler) {
      completionHandler(std::nullopt);
    }
  }

  // flutter_view
  void InAppWebView::setSurfaceSize(size_t width, size_t height, float scale_factor)
  {
    if (!webViewController) {
      return;
    }

    if (surface_ && width > 0 && height > 0) {
      scaleFactor_ = scale_factor;
      auto scaled_width = width * scale_factor;
      auto scaled_height = height * scale_factor;

      RECT bounds;
      bounds.left = 0;
      bounds.top = 0;
      bounds.right = static_cast<LONG>(scaled_width);
      bounds.bottom = static_cast<LONG>(scaled_height);

      surface_->put_Size({ scaled_width, scaled_height });

      wil::com_ptr<ICoreWebView2Controller3> webViewController3;
      if (SUCCEEDED(webViewController->QueryInterface(IID_PPV_ARGS(&webViewController3)))) {
        webViewController3->put_RasterizationScale(scale_factor);
      }

      if (webViewController->put_Bounds(bounds) != S_OK) {
        std::cerr << "Setting webview bounds failed." << std::endl;
      }

      if (surfaceSizeChangedCallback_) {
        surfaceSizeChangedCallback_(width, height);
      }
    }
  }


  void InAppWebView::setPosition(size_t x, size_t y, float scale_factor)
  {
    if (!webViewController || !plugin || !plugin->registrar) {
      return;
    }

    if (x >= 0 && y >= 0) {
      scaleFactor_ = scale_factor;
      auto scaled_x = static_cast<int>(x * scale_factor);
      auto scaled_y = static_cast<int>(y * scale_factor);

      auto titleBarHeight = ((GetSystemMetrics(SM_CYCAPTION) + GetSystemMetrics(SM_CYFRAME)) * scale_factor) + GetSystemMetrics(SM_CXPADDEDBORDER);
      auto borderWidth = (GetSystemMetrics(SM_CXBORDER) + GetSystemMetrics(SM_CXPADDEDBORDER)) * scale_factor;

      RECT flutterWindowRect;
      HWND flutterWindowHWnd = plugin->registrar->GetView()->GetNativeWindow();
      GetWindowRect(flutterWindowHWnd, &flutterWindowRect);

      HWND webViewHWnd;
      if (succeededOrLog(webViewController->get_ParentWindow(&webViewHWnd))) {
        ::SetWindowPos(webViewHWnd,
          nullptr,
          static_cast<int>(flutterWindowRect.left + scaled_x - borderWidth),
          static_cast<int>(flutterWindowRect.top + scaled_y - titleBarHeight),
          0, 0,
          SWP_NOZORDER | SWP_NOSIZE | SWP_NOACTIVATE);
      }
    }
  }


  void InAppWebView::setCursorPos(double x, double y)
  {
    if (!webViewCompositionController) {
      return;
    }

    POINT point;
    point.x = static_cast<LONG>(x * scaleFactor_);
    point.y = static_cast<LONG>(y * scaleFactor_);
    lastCursorPos_ = point;

    // https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.774.44
    webViewCompositionController->SendMouseInput(
      COREWEBVIEW2_MOUSE_EVENT_KIND::COREWEBVIEW2_MOUSE_EVENT_KIND_MOVE,
      virtualKeys_.state(), 0, point);
  }

  void InAppWebView::setPointerUpdate(int32_t pointer,
    InAppWebViewPointerEventKind eventKind, double x,
    double y, double size, double pressure)
  {
    if (!webViewEnv || !webViewCompositionController) {
      return;
    }

    COREWEBVIEW2_POINTER_EVENT_KIND event =
      COREWEBVIEW2_POINTER_EVENT_KIND_UPDATE;
    UINT32 pointerFlags = POINTER_FLAG_NONE;
    switch (eventKind) {
    case InAppWebViewPointerEventKind::Activate:
      event = COREWEBVIEW2_POINTER_EVENT_KIND_ACTIVATE;
      break;
    case InAppWebViewPointerEventKind::Down:
      event = COREWEBVIEW2_POINTER_EVENT_KIND_DOWN;
      pointerFlags =
        POINTER_FLAG_DOWN | POINTER_FLAG_INRANGE | POINTER_FLAG_INCONTACT;
      break;
    case InAppWebViewPointerEventKind::Enter:
      event = COREWEBVIEW2_POINTER_EVENT_KIND_ENTER;
      break;
    case InAppWebViewPointerEventKind::Leave:
      event = COREWEBVIEW2_POINTER_EVENT_KIND_LEAVE;
      break;
    case InAppWebViewPointerEventKind::Up:
      event = COREWEBVIEW2_POINTER_EVENT_KIND_UP;
      pointerFlags = POINTER_FLAG_UP;
      break;
    case InAppWebViewPointerEventKind::Update:
      event = COREWEBVIEW2_POINTER_EVENT_KIND_UPDATE;
      pointerFlags =
        POINTER_FLAG_UPDATE | POINTER_FLAG_INRANGE | POINTER_FLAG_INCONTACT;
      break;
    }

    POINT point;
    point.x = static_cast<LONG>(x * scaleFactor_);
    point.y = static_cast<LONG>(y * scaleFactor_);

    RECT rect;
    rect.left = point.x - 2;
    rect.right = point.x + 2;
    rect.top = point.y - 2;
    rect.bottom = point.y + 2;

    wil::com_ptr<ICoreWebView2Environment3> webViewEnv3;
    if (SUCCEEDED(webViewEnv->QueryInterface(IID_PPV_ARGS(&webViewEnv3)))) {
      wil::com_ptr<ICoreWebView2PointerInfo> pInfo;
      if (SUCCEEDED(webViewEnv3->CreateCoreWebView2PointerInfo(&pInfo))) {
        if (pInfo) {
          pInfo->put_PointerId(pointer);
          pInfo->put_PointerKind(PT_TOUCH);
          pInfo->put_PointerFlags(pointerFlags);
          pInfo->put_TouchFlags(TOUCH_FLAG_NONE);
          pInfo->put_TouchMask(TOUCH_MASK_CONTACTAREA | TOUCH_MASK_PRESSURE);
          pInfo->put_TouchPressure(
            std::clamp((UINT32)(pressure == 0.0 ? 1024 : 1024 * pressure),
              (UINT32)0, (UINT32)1024));
          pInfo->put_PixelLocationRaw(point);
          pInfo->put_TouchContactRaw(rect);
          webViewCompositionController->SendPointerInput(event, pInfo.get());
        }
      }
    }
  }

  void InAppWebView::setPointerButtonState(InAppWebViewPointerButton button, bool is_down)
  {
    if (!webViewCompositionController) {
      return;
    }

    COREWEBVIEW2_MOUSE_EVENT_KIND kind;
    switch (button) {
    case InAppWebViewPointerButton::Primary:
      virtualKeys_.setIsLeftButtonDown(is_down);
      kind = is_down ? COREWEBVIEW2_MOUSE_EVENT_KIND_LEFT_BUTTON_DOWN
        : COREWEBVIEW2_MOUSE_EVENT_KIND_LEFT_BUTTON_UP;
      break;
    case InAppWebViewPointerButton::Secondary:
      virtualKeys_.setIsRightButtonDown(is_down);
      kind = is_down ? COREWEBVIEW2_MOUSE_EVENT_KIND_RIGHT_BUTTON_DOWN
        : COREWEBVIEW2_MOUSE_EVENT_KIND_RIGHT_BUTTON_UP;
      break;
    case InAppWebViewPointerButton::Tertiary:
      virtualKeys_.setIsMiddleButtonDown(is_down);
      kind = is_down ? COREWEBVIEW2_MOUSE_EVENT_KIND_MIDDLE_BUTTON_DOWN
        : COREWEBVIEW2_MOUSE_EVENT_KIND_MIDDLE_BUTTON_UP;
      break;
    default:
      kind = static_cast<COREWEBVIEW2_MOUSE_EVENT_KIND>(0);
    }

    webViewCompositionController->SendMouseInput(kind, virtualKeys_.state(), 0,
      lastCursorPos_);
  }

  void InAppWebView::sendScroll(double delta, bool horizontal)
  {
    if (!webViewCompositionController) {
      return;
    }

    // delta * 6 gives me a multiple of WHEEL_DELTA (120)
    constexpr auto kScrollMultiplier = 6;

    auto offset = static_cast<short>(delta * kScrollMultiplier);

    if (horizontal) {
      webViewCompositionController->SendMouseInput(
        COREWEBVIEW2_MOUSE_EVENT_KIND_HORIZONTAL_WHEEL, virtualKeys_.state(),
        offset, lastCursorPos_);
    }
    else {
      webViewCompositionController->SendMouseInput(COREWEBVIEW2_MOUSE_EVENT_KIND_WHEEL,
        virtualKeys_.state(), offset,
        lastCursorPos_);
    }
  }

  void InAppWebView::setScrollDelta(double delta_x, double delta_y)
  {
    if (!webViewCompositionController) {
      return;
    }

    if (delta_x != 0.0) {
      sendScroll(delta_x, true);
    }
    if (delta_y != 0.0) {
      sendScroll(delta_y, false);
    }
  }

  bool InAppWebView::createSurface(const HWND parentWindow,
    winrt::com_ptr<ABI::Windows::UI::Composition::ICompositor> compositor)
  {
    if (!webViewCompositionController || !webViewController) {
      return false;
    }

    winrt::com_ptr<ABI::Windows::UI::Composition::IContainerVisual> root;
    if (FAILED(compositor->CreateContainerVisual(root.put()))) {
      return false;
    }
    surface_ = root.try_as<ABI::Windows::UI::Composition::IVisual>();
    assert(surface_);

    // initial size. doesn't matter as we resize the surface anyway.
    surface_->put_Size({ 1280, 720 });
    surface_->put_IsVisible(true);

    winrt::com_ptr<ABI::Windows::UI::Composition::IVisual> webview_visual;
    compositor->CreateContainerVisual(
      reinterpret_cast<ABI::Windows::UI::Composition::IContainerVisual**>(
        webview_visual.put()));

    auto webview_visual2 =
      webview_visual.try_as<ABI::Windows::UI::Composition::IVisual2>();
    if (webview_visual2) {
      webview_visual2->put_RelativeSizeAdjustment({ 1.0f, 1.0f });
    }

    winrt::com_ptr<ABI::Windows::UI::Composition::IVisualCollection> children;
    root->get_Children(children.put());
    children->InsertAtTop(webview_visual.get());
    webViewCompositionController->put_RootVisualTarget(webview_visual2.get());

    webViewController->put_IsVisible(true);

    return true;
  }

  bool InAppWebView::isSslError(const COREWEBVIEW2_WEB_ERROR_STATUS& webErrorStatus)
  {
    return webErrorStatus >= COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_COMMON_NAME_IS_INCORRECT && webErrorStatus <= COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_IS_INVALID;
  }

  InAppWebView::~InAppWebView()
  {
    debugLog("dealloc InAppWebView");
    callbackLifetime_.reset();
    if (channelDelegate && plugin && plugin->isEngineAvailable()) {
      channelDelegate->UnregisterMethodCallHandler();
    }
    if (plugin && plugin->inAppWebViewManager) {
      auto& requests = plugin->inAppWebViewManager->windowWebViews;
      for (const auto windowId : pendingWindowIds_) {
        auto request = requests.find(windowId);
        if (request != requests.end()) {
          failedLog(request->second->args->put_Handled(TRUE));
          failedLog(request->second->deferral->Complete());
          requests.erase(request);
        }
      }
    }
    pendingWindowIds_.clear();
    userContentController = nullptr;
    if (webView) {
      failedLog(webView->remove_WebMessageReceived(webMessageToken_));
      failedLog(webView->remove_NewWindowRequested(newWindowToken_));
      failedLog(webView->Stop());
    }
    HWND parentWindow = nullptr;
    if (webViewCompositionController && webViewController && succeededOrLog(webViewController->get_ParentWindow(&parentWindow))) {
      // if it's an InAppWebView (so webViewCompositionController will be not a nullptr!),
      // then destroy the Window created with it
      failedLog(webViewController->Close());
      DestroyWindow(parentWindow);
    }
    else if (webViewController) {
      failedLog(webViewController->Close());
    }
    navigationActions_.clear();
    inAppBrowser = nullptr;
    plugin = nullptr;
  }
}
