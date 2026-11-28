#include <vector>

#include "javascript_bridge_js.h"

namespace flutter_inappwebview_plugin
{
  std::unique_ptr<PluginScript> createJavaScriptBridgePluginScript()
  {
    const std::vector<std::string> allowedOriginRules = { "*" };
    return std::make_unique<PluginScript>(
      JAVASCRIPT_BRIDGE_JS_PLUGIN_SCRIPT_GROUP_NAME,
      JAVASCRIPT_BRIDGE_JS_SOURCE,
      UserScriptInjectionTime::atDocumentStart,
      allowedOriginRules,
      nullptr,
      true
    );
  }
}