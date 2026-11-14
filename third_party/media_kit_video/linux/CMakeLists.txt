# This file is a part of media_kit (https://github.com/media-kit/media-kit).
#
# Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
# All rights reserved.
# Use of this source code is governed by MIT license that can be found in the LICENSE file.

cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "media_kit_video")
set(CMAKE_CXX_STANDARD 17)
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "media_kit_video_plugin")

if(MEDIA_KIT_LIBS_AVAILABLE)
  add_library(
    ${PLUGIN_NAME} SHARED
    "media_kit_video_plugin.cc"
    "texture_gl.cc"
    "texture_sw.cc"
    "video_output_manager.cc"
    "video_output.cc"
    "utils.cc"
  )

  apply_standard_settings(${PLUGIN_NAME})

  # Check for libmpv & epoxy headers & libraries.
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(mpv IMPORTED_TARGET mpv)
  pkg_check_modules(epoxy IMPORTED_TARGET epoxy)

  set_target_properties(
    ${PLUGIN_NAME} PROPERTIES
    CXX_VISIBILITY_PRESET hidden
  )

  target_compile_definitions(
    ${PLUGIN_NAME} PRIVATE
    FLUTTER_PLUGIN_IMPL
  )
  
  target_compile_options(${PLUGIN_NAME} PRIVATE "${mpv_CFLAGS_OTHER}")
  target_compile_options(${PLUGIN_NAME} PRIVATE "${epoxy_CFLAGS_OTHER}")

  target_include_directories(
    ${PLUGIN_NAME} INTERFACE
    "${CMAKE_CURRENT_SOURCE_DIR}/include"
    "${mpv_INCLUDE_DIRS}"
    "${epoxy_INCLUDE_DIRS}"
  )

  target_link_libraries(
    ${PLUGIN_NAME} PRIVATE
    flutter
    PkgConfig::GTK
    PkgConfig::mpv
    PkgConfig::epoxy
  )
else()
  message(NOTICE "media_kit: WARNING: package:media_kit_libs_*** not found.")

  add_library(
    ${PLUGIN_NAME} SHARED
    "media_kit_video_plugin.cc"
  )

  apply_standard_settings(${PLUGIN_NAME})

  set_target_properties(
    ${PLUGIN_NAME} PROPERTIES
    CXX_VISIBILITY_PRESET hidden
  )

  target_compile_definitions(
    ${PLUGIN_NAME} PRIVATE
    FLUTTER_PLUGIN_IMPL

    # Add macro to indicate that package:media_kit_libs_*** is not available.
    "MEDIA_KIT_LIBS_NOT_FOUND=1"
  )

  target_include_directories(
    ${PLUGIN_NAME} INTERFACE
    "${CMAKE_CURRENT_SOURCE_DIR}/include"
  )

  target_link_libraries(
    ${PLUGIN_NAME} PRIVATE
    flutter
    PkgConfig::GTK
  )
endif()

set(
  media_kit_video_bundled_libraries
  ""
  PARENT_SCOPE
)
