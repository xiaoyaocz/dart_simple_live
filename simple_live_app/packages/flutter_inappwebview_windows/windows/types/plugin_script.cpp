#include "plugin_script.h"

namespace flutter_inappwebview_plugin
{
  PluginScript::PluginScript(
    const std::optional<std::string>& groupName,
    const std::string& source,
    const UserScriptInjectionTime& injectionTime,
    const std::vector<std::string>& allowedOriginRules,
    std::shared_ptr<ContentWorld> contentWorld,
    const bool& requiredInAllContentWorlds
  ) : UserScript(groupName, source, injectionTime, allowedOriginRules, std::move(contentWorld)),
    requiredInAllContentWorlds_(requiredInAllContentWorlds)
  {}


  std::shared_ptr<PluginScript> PluginScript::copyAndSet(const std::shared_ptr<ContentWorld> cw) const
  {
    return std::make_unique<PluginScript>(
      this->groupName,
      this->source,
      this->injectionTime,
      this->allowedOriginRules,
      cw,
      this->requiredInAllContentWorlds_
    );
  }

  PluginScript::~PluginScript() {}
}