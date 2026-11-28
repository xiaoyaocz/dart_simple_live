#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_JAVASCRIPT_BRIDGE_JS_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_JAVASCRIPT_BRIDGE_JS_H_

#include <memory>
#include <string>

#include "../types/plugin_script.h"

namespace flutter_inappwebview_plugin
{
  const std::string JAVASCRIPT_BRIDGE_NAME = "flutter_inappwebview";
  const std::string JAVASCRIPT_BRIDGE_JS_SOURCE = "window." + JAVASCRIPT_BRIDGE_NAME + " = {}; \
  window." + JAVASCRIPT_BRIDGE_NAME + ".callHandler = function() { \
    var _callHandlerID = setTimeout(function() {}); \
    window.chrome.webview.postMessage({ 'name': 'callHandler', 'body': {'handlerName': arguments[0], '_callHandlerID' : _callHandlerID, 'args' : JSON.stringify(Array.prototype.slice.call(arguments, 1))} }); \
    return new Promise(function(resolve, reject) { \
      window." + JAVASCRIPT_BRIDGE_NAME + "[_callHandlerID] = { resolve: resolve, reject : reject };\
    });\
  };";
  const std::string JAVASCRIPT_BRIDGE_JS_PLUGIN_SCRIPT_GROUP_NAME = "IN_APP_WEBVIEW_JAVASCRIPT_BRIDGE_JS_PLUGIN_SCRIPT";
  const std::string PLATFORM_READY_JS_SOURCE = "(function() { \
     if ((window.top == null || window.top === window) && window." + JAVASCRIPT_BRIDGE_NAME + " != null && window." + JAVASCRIPT_BRIDGE_NAME + "._platformReady == null) { \
       window.dispatchEvent(new Event('flutterInAppWebViewPlatformReady')); \
       window." + JAVASCRIPT_BRIDGE_NAME + "._platformReady = true; \
     } \
   })();";

  std::unique_ptr<PluginScript> createJavaScriptBridgePluginScript();
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_JAVASCRIPT_BRIDGE_JS_H_