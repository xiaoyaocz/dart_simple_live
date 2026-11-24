// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.
#include "include/media_kit_video/media_kit_video_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#ifndef MEDIA_KIT_LIBS_NOT_FOUND

#include "media_kit_video_plugin.h"

void MediaKitVideoPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  media_kit_video::MediaKitVideoPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

#else

#include <iostream>

void MediaKitVideoPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  std::cout << "media_kit: WARNING: package:media_kit_libs_*** not found."
            << std::endl;
}

#endif
