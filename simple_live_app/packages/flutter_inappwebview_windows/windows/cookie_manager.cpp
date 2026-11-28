#include <ctime>
#include <nlohmann/json.hpp>
#include <Shlwapi.h>
#include <winrt/base.h>
#include <wrl/event.h>

#include "cookie_manager.h"
#include "types/callbacks_complete.h"
#include "utils/flutter.h"
#include "utils/log.h"

namespace flutter_inappwebview_plugin
{
  using namespace Microsoft::WRL;

  CookieManager::CookieManager(const FlutterInappwebviewWindowsPlugin* plugin)
    : plugin(plugin), ChannelDelegate(plugin->registrar->messenger(), CookieManager::METHOD_CHANNEL_NAME_PREFIX)
  {}

  void CookieManager::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    auto& arguments = std::get<flutter::EncodableMap>(*method_call.arguments());
    auto& methodName = method_call.method_name();

    auto webViewEnvironmentId = get_optional_fl_map_value<std::string>(arguments, "webViewEnvironmentId");

    auto webViewEnvironment = plugin && webViewEnvironmentId.has_value() && map_contains(plugin->webViewEnvironmentManager->webViewEnvironments, webViewEnvironmentId.value())
      ? plugin->webViewEnvironmentManager->webViewEnvironments.at(webViewEnvironmentId.value()).get() : nullptr;

    auto result_ = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));
    auto callback = [this, result_, methodName, arguments](WebViewEnvironment* webViewEnvironment)
      {
        if (!webViewEnvironment) {
          result_->Error("0", "Cannot obtain the WebViewEnvironment!");
          return;
        }

        if (string_equals(methodName, "setCookie")) {
          setCookie(webViewEnvironment, arguments, [result_](const bool& created)
            {
              result_->Success(created);
            });
        }
        else if (string_equals(methodName, "getCookie")) {
          auto url = get_fl_map_value<std::string>(arguments, "url");
          auto name = get_fl_map_value<std::string>(arguments, "name");
          getCookie(webViewEnvironment, url, name, [result_](const flutter::EncodableValue& cookie)
            {
              result_->Success(cookie);
            });
        }
        else if (string_equals(methodName, "getCookies")) {
          auto url = get_fl_map_value<std::string>(arguments, "url");
          getCookies(webViewEnvironment, url, [result_](const flutter::EncodableList& cookies)
            {
              result_->Success(cookies);
            });
        }
        else if (string_equals(methodName, "deleteCookie")) {
          auto url = get_fl_map_value<std::string>(arguments, "url");
          auto name = get_fl_map_value<std::string>(arguments, "name");
          auto path = get_fl_map_value<std::string>(arguments, "path");
          auto domain = get_optional_fl_map_value<std::string>(arguments, "domain");
          deleteCookie(webViewEnvironment, url, name, path, domain, [result_](const bool& deleted)
            {
              result_->Success(deleted);
            });
        }
        else if (string_equals(methodName, "deleteCookies")) {
          auto url = get_fl_map_value<std::string>(arguments, "url");
          auto path = get_fl_map_value<std::string>(arguments, "path");
          auto domain = get_optional_fl_map_value<std::string>(arguments, "domain");
          deleteCookies(webViewEnvironment, url, path, domain, [result_](const bool& deleted)
            {
              result_->Success(deleted);
            });
        }
        else if (string_equals(methodName, "deleteAllCookies")) {
          deleteAllCookies(webViewEnvironment, [result_](const bool& deleted)
            {
              result_->Success(deleted);
            });
        }
        else {
          result_->NotImplemented();
        }
      };

    if (webViewEnvironment) {
      callback(webViewEnvironment);
    }
    else {
      plugin->webViewEnvironmentManager->createOrGetDefaultWebViewEnvironment([callback](WebViewEnvironment* webViewEnvironment)
        {
          callback(webViewEnvironment);
        });
    }
  }

  void CookieManager::setCookie(WebViewEnvironment* webViewEnvironment, const flutter::EncodableMap& map, std::function<void(const bool&)> completionHandler) const
  {
    if (!plugin || !plugin->webViewEnvironmentManager) {
      if (completionHandler) {
        completionHandler(false);
      }
      return;
    }

    auto url = get_fl_map_value<std::string>(map, "url");
    auto name = get_fl_map_value<std::string>(map, "name");
    auto value = get_fl_map_value<std::string>(map, "value");
    auto path = get_fl_map_value<std::string>(map, "path");
    auto domain = get_optional_fl_map_value<std::string>(map, "domain");
    auto expiresDate = get_optional_fl_map_value<int64_t>(map, "expiresDate");
    auto maxAge = get_optional_fl_map_value<int64_t>(map, "maxAge");
    auto isSecure = get_optional_fl_map_value<bool>(map, "isSecure");
    auto isHttpOnly = get_optional_fl_map_value<bool>(map, "isHttpOnly");
    auto sameSite = get_optional_fl_map_value<std::string>(map, "sameSite");

    nlohmann::json parameters = {
      {"url", url},
      {"name", name},
      {"value", value},
      {"path", path}
    };
    if (domain.has_value()) {
      parameters["domain"] = domain.value();
    }
    if (expiresDate.has_value()) {
      parameters["expires"] = expiresDate.value() / 1000;
    }
    if (maxAge.has_value()) {
      // time(NULL) represents the current unix timestamp in seconds
      parameters["expires"] = time(NULL) + maxAge.value();
    }
    if (isSecure.has_value()) {
      parameters["secure"] = isSecure.value();
    }
    if (isHttpOnly.has_value()) {
      parameters["httpOnly"] = isHttpOnly.value();
    }
    if (sameSite.has_value()) {
      parameters["sameSite"] = sameSite.value();
    }

    auto hr = webViewEnvironment->getWebView()->CallDevToolsProtocolMethod(L"Network.setCookie", utf8_to_wide(parameters.dump()).c_str(), Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
      [completionHandler](HRESULT errorCode, LPCWSTR returnObjectAsJson)
      {
        if (completionHandler) {
          completionHandler(succeededOrLog(errorCode));
        }
        return S_OK;
      }
    ).Get());

    if (failedAndLog(hr) && completionHandler) {
      completionHandler(false);
    }
  }

  void CookieManager::getCookie(WebViewEnvironment* webViewEnvironment, const std::string& url, const std::string& name, std::function<void(const flutter::EncodableValue&)> completionHandler) const
  {
    if (!plugin || !plugin->webViewEnvironmentManager) {
      if (completionHandler) {
        completionHandler(make_fl_value());
      }
      return;
    }

    nlohmann::json parameters = {
      {"urls", std::vector<std::string>{url}}
    };

    auto hr = webViewEnvironment->getWebView()->CallDevToolsProtocolMethod(L"Network.getCookies", utf8_to_wide(parameters.dump()).c_str(), Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
      [completionHandler, name](HRESULT errorCode, LPCWSTR returnObjectAsJson)
      {
        if (succeededOrLog(errorCode)) {
          nlohmann::json json = nlohmann::json::parse(wide_to_utf8(returnObjectAsJson));
          auto jsonCookies = json["cookies"].get<std::vector<nlohmann::json>>();
          for (auto& jsonCookie : jsonCookies) {
            auto cookieName = jsonCookie["name"].get<std::string>();
            if (string_equals(name, cookieName)) {
              completionHandler(flutter::EncodableMap{
                {"name", cookieName},
                {"value", jsonCookie["value"].get<std::string>()},
                {"domain", jsonCookie["domain"].get<std::string>()},
                {"path", jsonCookie["path"].get<std::string>()},
                {"expiresDate", jsonCookie["expires"].get<int64_t>()},
                {"isHttpOnly", jsonCookie["httpOnly"].get<bool>()},
                {"isSecure", jsonCookie["secure"].get<bool>()},
                {"isSessionOnly", jsonCookie["session"].get<bool>()},
                {"sameSite", jsonCookie.contains("sameSite") ? jsonCookie["sameSite"].get<std::string>() : make_fl_value()}
                });
              return S_OK;
            }
          }
        }
        if (completionHandler) {
          completionHandler(make_fl_value());
        }
        return S_OK;
      }
    ).Get());

    if (failedAndLog(hr) && completionHandler) {
      completionHandler(make_fl_value());
    }
  }

  void CookieManager::getCookies(WebViewEnvironment* webViewEnvironment, const std::string& url, std::function<void(const flutter::EncodableList&)> completionHandler) const
  {
    if (!plugin || !plugin->webViewEnvironmentManager) {
      if (completionHandler) {
        completionHandler({});
      }
      return;
    }

    nlohmann::json parameters = {
      {"urls", std::vector<std::string>{url}}
    };

    auto hr = webViewEnvironment->getWebView()->CallDevToolsProtocolMethod(L"Network.getCookies", utf8_to_wide(parameters.dump()).c_str(), Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
      [completionHandler](HRESULT errorCode, LPCWSTR returnObjectAsJson)
      {
        std::vector<flutter::EncodableValue> cookies = {};
        if (succeededOrLog(errorCode)) {
          nlohmann::json json = nlohmann::json::parse(wide_to_utf8(returnObjectAsJson));
          auto jsonCookies = json["cookies"].get<std::vector<nlohmann::json>>();
          for (auto& jsonCookie : jsonCookies) {
            cookies.push_back(flutter::EncodableMap{
              {"name", jsonCookie["name"].get<std::string>()},
              {"value", jsonCookie["value"].get<std::string>()},
              {"domain", jsonCookie["domain"].get<std::string>()},
              {"path", jsonCookie["path"].get<std::string>()},
              {"expiresDate", jsonCookie["expires"].get<int64_t>()},
              {"isHttpOnly", jsonCookie["httpOnly"].get<bool>()},
              {"isSecure", jsonCookie["secure"].get<bool>()},
              {"isSessionOnly", jsonCookie["session"].get<bool>()},
              {"sameSite", jsonCookie.contains("sameSite") ? jsonCookie["sameSite"].get<std::string>() : make_fl_value()}
              });
          }
        }
        if (completionHandler) {
          completionHandler(cookies);
        }
        return S_OK;
      }
    ).Get());

    if (failedAndLog(hr) && completionHandler) {
      completionHandler({});
    }
  }

  void CookieManager::deleteCookie(WebViewEnvironment* webViewEnvironment, const std::string& url, const std::string& name, const std::string& path, const std::optional<std::string>& domain, std::function<void(const bool&)> completionHandler) const
  {
    if (!plugin || !plugin->webViewEnvironmentManager) {
      if (completionHandler) {
        completionHandler(false);
      }
      return;
    }

    nlohmann::json parameters = {
      {"url", url},
      {"name", name},
      {"path", path}
    };
    if (domain.has_value()) {
      parameters["domain"] = domain.value();
    }

    auto hr = webViewEnvironment->getWebView()->CallDevToolsProtocolMethod(L"Network.deleteCookies", utf8_to_wide(parameters.dump()).c_str(), Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
      [completionHandler](HRESULT errorCode, LPCWSTR returnObjectAsJson)
      {
        if (completionHandler) {
          completionHandler(succeededOrLog(errorCode));
        }
        return S_OK;
      }
    ).Get());

    if (failedAndLog(hr) && completionHandler) {
      completionHandler(false);
    }
  }

  void CookieManager::deleteCookies(WebViewEnvironment* webViewEnvironment, const std::string& url, const std::string& path, const std::optional<std::string>& domain, std::function<void(const bool&)> completionHandler) const
  {
    if (!plugin || !plugin->webViewEnvironmentManager) {
      if (completionHandler) {
        completionHandler(false);
      }
      return;
    }

    getCookies(webViewEnvironment, url, [this, webViewEnvironment, url, path, domain, completionHandler](const flutter::EncodableList& cookies)
      {
        auto callbacksComplete = std::make_shared<CallbacksComplete<bool>>(
          [completionHandler](const std::vector<bool>& values)
          {
            if (completionHandler) {
              completionHandler(true);
            }
          });

        for (auto& cookie : cookies) {
          auto cookieMap = std::get<flutter::EncodableMap>(cookie);
          auto name = get_fl_map_value<std::string>(cookieMap, "name");
          deleteCookie(webViewEnvironment, url, name, path, domain, [callbacksComplete](const bool& deleted)
            {
              callbacksComplete->addValue(deleted);
            });
        }
      });
  }

  void CookieManager::deleteAllCookies(WebViewEnvironment* webViewEnvironment, std::function<void(const bool&)> completionHandler) const
  {
    if (!plugin || !plugin->webViewEnvironmentManager) {
      if (completionHandler) {
        completionHandler(false);
      }
      return;
    }

    auto hr = webViewEnvironment->getWebView()->CallDevToolsProtocolMethod(L"Network.clearBrowserCookies", L"{}", Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
      [completionHandler](HRESULT errorCode, LPCWSTR returnObjectAsJson)
      {
        if (completionHandler) {
          completionHandler(succeededOrLog(errorCode));
        }
        return S_OK;
      }
    ).Get());

    if (failedAndLog(hr) && completionHandler) {
      completionHandler(false);
    }
  }

  CookieManager::~CookieManager()
  {
    debugLog("dealloc CookieManager");
    plugin = nullptr;
  }
}
