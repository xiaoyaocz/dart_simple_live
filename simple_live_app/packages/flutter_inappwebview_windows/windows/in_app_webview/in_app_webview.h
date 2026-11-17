#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_IN_APP_WEBVIEW_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_IN_APP_WEBVIEW_H_

#include <functional>
#include <set>
#include <WebView2.h>
#include <wil/com.h>
#include <windows.ui.composition.desktop.h>
#include <windows.ui.composition.h>
#include <winrt/base.h>

#include "../flutter_inappwebview_windows_plugin.h"
#include "../plugin_scripts_js/plugin_scripts_util.h"
#include "../types/content_world.h"
#include "../types/navigation_action.h"
#include "../types/screenshot_configuration.h"
#include "../types/ssl_certificate.h"
#include "../types/url_request.h"
#include "../types/web_history.h"
#include "../webview_environment/webview_environment.h"
#include "in_app_webview_settings.h"
#include "user_content_controller.h"
#include "webview_channel_delegate.h"

#include <WebView2EnvironmentOptions.h>

namespace flutter_inappwebview_plugin
{
  class InAppBrowser;

  using namespace Microsoft::WRL;

  // custom_platform_view
  enum class InAppWebViewPointerButton { None, Primary, Secondary, Tertiary };
  enum class InAppWebViewPointerEventKind { Activate, Down, Enter, Leave, Up, Update };
  typedef std::function<void(size_t width, size_t height)>
    SurfaceSizeChangedCallback;
  typedef std::function<void(const HCURSOR)> CursorChangedCallback;
  struct VirtualKeyState {
  public:
    inline void setIsLeftButtonDown(bool is_down)
    {
      set(COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS::
        COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS_LEFT_BUTTON,
        is_down);
    }

    inline void setIsRightButtonDown(bool is_down)
    {
      set(COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS::
        COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS_RIGHT_BUTTON,
        is_down);
    }

    inline void setIsMiddleButtonDown(bool is_down)
    {
      set(COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS::
        COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS_MIDDLE_BUTTON,
        is_down);
    }

    inline COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS state() const { return state_; }

  private:
    COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS state_ =
      COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS::
      COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS_NONE;

    inline void set(COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS key, bool flag)
    {
      if (flag) {
        state_ |= key;
      }
      else {
        state_ &= ~key;
      }
    }
  };

  const std::string CALL_ASYNC_JAVASCRIPT_WRAPPER_JS = "(async function(" + VAR_FUNCTION_ARGUMENT_NAMES + ") { \
        " + VAR_FUNCTION_BODY + " \
    })(" + VAR_FUNCTION_ARGUMENT_VALUES + ");";

  struct InAppWebViewCreationParams {
    const std::variant<std::string, int64_t> id;
    const std::shared_ptr<InAppWebViewSettings> initialSettings;
    const std::optional<std::vector<std::shared_ptr<UserScript>>> initialUserScripts;
  };

  class InAppWebView
  {
  public:
    static inline const std::string METHOD_CHANNEL_NAME_PREFIX = "com.pichillilorenzo/flutter_inappwebview_";

    const FlutterInappwebviewWindowsPlugin* plugin;
    std::variant<std::string, int64_t> id;
    wil::com_ptr<ICoreWebView2Environment> webViewEnv;
    wil::com_ptr<ICoreWebView2Controller> webViewController;
    wil::com_ptr<ICoreWebView2CompositionController> webViewCompositionController;
    wil::com_ptr<ICoreWebView2> webView;
    std::unique_ptr<WebViewChannelDelegate> channelDelegate;
    std::shared_ptr<InAppWebViewSettings> settings;
    InAppBrowser* inAppBrowser = nullptr;
    std::unique_ptr<UserContentController> userContentController;

    InAppWebView(const FlutterInappwebviewWindowsPlugin* plugin, const InAppWebViewCreationParams& params, const HWND parentWindow,
      wil::com_ptr<ICoreWebView2Environment> webViewEnv,
      wil::com_ptr<ICoreWebView2Controller> webViewController,
      wil::com_ptr<ICoreWebView2CompositionController> webViewCompositionController);
    InAppWebView(InAppBrowser* inAppBrowser, const FlutterInappwebviewWindowsPlugin* plugin, const InAppWebViewCreationParams& params, const HWND parentWindow,
      wil::com_ptr<ICoreWebView2Environment> webViewEnv,
      wil::com_ptr<ICoreWebView2Controller> webViewController,
      wil::com_ptr<ICoreWebView2CompositionController> webViewCompositionController);
    ~InAppWebView();

    static void createInAppWebViewEnv(const HWND parentWindow, const bool& willBeSurface, WebViewEnvironment* webViewEnvironment, const std::shared_ptr<InAppWebViewSettings> initialSettings, std::function<void(wil::com_ptr<ICoreWebView2Environment> webViewEnv,
      wil::com_ptr<ICoreWebView2Controller> webViewController,
      wil::com_ptr<ICoreWebView2CompositionController> webViewCompositionController)> completionHandler);

    // custom_platform_view
    ABI::Windows::UI::Composition::IVisual* const surface()
    {
      return surface_.get();
    }
    void setSurfaceSize(size_t width, size_t height, float scale_factor);
    void setPosition(size_t x, size_t y, float scale_factor);
    void setCursorPos(double x, double y);
    void setPointerUpdate(int32_t pointer, InAppWebViewPointerEventKind eventKind,
      double x, double y, double size, double pressure);
    void setPointerButtonState(InAppWebViewPointerButton button, bool isDown);
    void sendScroll(double offset, bool horizontal);
    void setScrollDelta(double delta_x, double delta_y);
    void onSurfaceSizeChanged(SurfaceSizeChangedCallback callback)
    {
      surfaceSizeChangedCallback_ = std::move(callback);
    }
    void onCursorChanged(CursorChangedCallback callback)
    {
      cursorChangedCallback_ = std::move(callback);
    }
    bool createSurface(const HWND parentWindow,
      winrt::com_ptr<ABI::Windows::UI::Composition::ICompositor> compositor);

    void initChannel(const std::optional<std::variant<std::string, int64_t>> viewId, const std::optional<std::string> channelName);
    void prepare(const InAppWebViewCreationParams& params);
    std::optional<std::string> getUrl() const;
    std::optional<std::string> getTitle() const;
    void loadUrl(const std::shared_ptr<URLRequest> urlRequest) const;
    void loadFile(const std::string& assetFilePath) const;
    void loadData(const std::string& data) const;
    void reload() const;
    void goBack();
    bool canGoBack() const;
    void goForward();
    bool canGoForward() const;
    void goBackOrForward(const int64_t& steps);
    void canGoBackOrForward(const int64_t& steps, std::function<void(bool)> completionHandler) const;
    bool isLoading() const
    {
      return isLoading_;
    }
    void stopLoading() const;
    void evaluateJavascript(const std::string& source, const std::shared_ptr<ContentWorld> contentWorld, const std::function<void(std::string)> completionHandler) const;
    void callAsyncJavaScript(const std::string& functionBody, const std::string& argumentsAsJson, const std::shared_ptr<ContentWorld> contentWorld, const std::function<void(std::string)> completionHandler) const;
    void getCopyBackForwardList(const std::function<void(std::unique_ptr<WebHistory>)> completionHandler) const;
    void addUserScript(const std::shared_ptr<UserScript> userScript) const;
    void removeUserScript(const int64_t index, const std::shared_ptr<UserScript> userScript) const;
    void removeUserScriptsByGroupName(const std::string& groupName) const;
    void removeAllUserScripts() const;
    void takeScreenshot(const std::optional<std::shared_ptr<ScreenshotConfiguration>> screenshotConfiguration, const std::function<void(const std::optional<std::string>)> completionHandler) const;
    void setSettings(const std::shared_ptr<InAppWebViewSettings> newSettings, const flutter::EncodableMap& newSettingsMap);
    flutter::EncodableValue getSettings() const;
    void openDevTools() const;
    void callDevToolsProtocolMethod(const std::string& methodName, const std::optional<std::string>& parametersAsJson, const std::function<void(const HRESULT& errorCode, const std::optional<std::string>&)> completionHandler) const;
    void addDevToolsProtocolEventListener(const std::string& eventName);
    void removeDevToolsProtocolEventListener(const std::string& eventName);
    void pause() const;
    void resume() const;
    bool requestFocus() const;
    void getCertificate(const std::function<void(const std::optional<std::unique_ptr<SslCertificate>>)> completionHandler) const;

    std::string pageFrameId() const
    {
      return pageFrameId_;
    }

    static bool isSslError(const COREWEBVIEW2_WEB_ERROR_STATUS& webErrorStatus);
  private:
    // custom_platform_view
    // 跨 Dart 的异步回调不得延长原生窗口寿命，也不得访问已释放窗口。
    std::shared_ptr<int> callbackLifetime_ = std::make_shared<int>(0);
    std::set<int64_t> pendingWindowIds_;
    EventRegistrationToken webMessageToken_ = {};
    EventRegistrationToken newWindowToken_ = {};
    winrt::com_ptr<ABI::Windows::UI::Composition::IVisual> surface_;
    SurfaceSizeChangedCallback surfaceSizeChangedCallback_;
    CursorChangedCallback cursorChangedCallback_;
    float scaleFactor_ = 1.0;
    POINT lastCursorPos_ = { 0, 0 };
    VirtualKeyState virtualKeys_;

    std::map<UINT64, std::shared_ptr<NavigationAction>> navigationActions_ = {};
    std::shared_ptr<NavigationAction> lastNavigationAction_;
    bool isLoading_ = false;
    std::string pageFrameId_;
    std::map<std::string, std::pair<wil::com_ptr<ICoreWebView2DevToolsProtocolEventReceiver>, EventRegistrationToken>> devToolsProtocolEventListener_ = {};

    void registerEventHandlers();
    void registerSurfaceEventHandlers();
  };
}
#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_IN_APP_WEBVIEW_H_
