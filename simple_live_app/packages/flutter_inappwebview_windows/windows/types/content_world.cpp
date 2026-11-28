#include "content_world.h"

namespace flutter_inappwebview_plugin
{
  namespace {
    const std::shared_ptr<ContentWorld> ContentWorldPage = std::make_shared<ContentWorld>("page");
    const std::shared_ptr<ContentWorld> ContentWorldDefaultClient = std::make_shared<ContentWorld>("defaultClient");
  }

  ContentWorld::ContentWorld(const std::string& name)
    : name(name)
  {}

  ContentWorld::ContentWorld(const flutter::EncodableMap& map)
    : name(get_fl_map_value<std::string>(map, "name"))
  {}

  bool ContentWorld::isSame(const ContentWorld& contentWorld) const
  {
    return name == contentWorld.name;
  }

  bool ContentWorld::isSame(const std::shared_ptr<ContentWorld> contentWorld) const
  {
    return contentWorld && name == contentWorld->name;
  }

  const std::shared_ptr<ContentWorld> ContentWorld::page()
  {
    return ContentWorldPage;
  }

  const std::shared_ptr<ContentWorld> ContentWorld::defaultClient()
  {
    return ContentWorldDefaultClient;
  }

  bool ContentWorld::isPage(const ContentWorld& contentWorld)
  {
    return contentWorld.isSame(*ContentWorld::page());
  }

  bool ContentWorld::isPage(const std::shared_ptr<ContentWorld> contentWorld)
  {
    return ContentWorld::page()->isSame(contentWorld);
  }

  bool ContentWorld::isDefaultClient(const ContentWorld& contentWorld)
  {
    return contentWorld.isSame(*ContentWorld::defaultClient());
  }

  bool ContentWorld::isDefaultClient(const std::shared_ptr<ContentWorld> contentWorld)
  {
    return ContentWorld::defaultClient()->isSame(contentWorld);
  }

  ContentWorld::~ContentWorld()
  {}
}