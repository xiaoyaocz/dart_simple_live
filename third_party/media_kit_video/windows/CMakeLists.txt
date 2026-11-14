# This file is a part of media_kit (https://github.com/media-kit/media-kit).
#
# Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
# All rights reserved.
# Use of this source code is governed by MIT license that can be found in the LICENSE file.

cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "media_kit_video")
set(CMAKE_CXX_STANDARD 17)
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "media_kit_video_plugin")

# This is shipped as part of package:media_kit_libs_*** package(s).
# Must be built before this target.
set(LIBMPV_SRC "${CMAKE_BINARY_DIR}/libmpv")
set(ANGLE_SRC "${CMAKE_BINARY_DIR}/ANGLE")

# Deal with MSVC incompatiblity
add_compile_definitions(_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR)

if(MEDIA_KIT_LIBS_AVAILABLE)
  include_directories(
    "${LIBMPV_SRC}/include"
    "${ANGLE_SRC}/include"
  )

  add_library(
    ${PLUGIN_NAME} SHARED
    "angle_surface_manager.cc"
    "media_kit_video_plugin_c_api.cc"
    "media_kit_video_plugin.cc"
    "video_output_manager.cc"
    "video_output.cc"
    "utils.cc"
    ${PLUGIN_SOURCES}
  )

  apply_standard_settings(${PLUGIN_NAME})

  set_target_properties(
    ${PLUGIN_NAME} PROPERTIES
    CXX_VISIBILITY_PRESET hidden
  )
  target_compile_definitions(
    ${PLUGIN_NAME} PRIVATE
    FLUTTER_PLUGIN_IMPL
  )

  target_include_directories(
    ${PLUGIN_NAME} INTERFACE
    "${CMAKE_CURRENT_SOURCE_DIR}/include"
  )

  target_link_libraries(
    ${PLUGIN_NAME} PRIVATE
    flutter
    flutter_wrapper_plugin

    # Link to libmpv & ANGLE.
    "${LIBMPV_SRC}/libmpv.dll.a"
    "${ANGLE_SRC}/lib/libEGL.dll.lib"
    "${ANGLE_SRC}/lib/libGLESv2.dll.lib"
  )
else()
  message(NOTICE "media_kit: WARNING: package:media_kit_libs_*** not found.")

  add_library(
    ${PLUGIN_NAME} SHARED
    "media_kit_video_plugin_c_api.cc"
    ${PLUGIN_SOURCES}
  )

  apply_standard_settings(${PLUGIN_NAME})

  set_target_properties(
    ${PLUGIN_NAME} PROPERTIES
    CXX_VISIBILITY_PRESET hidden
  )

  target_compile_definitions(
    ${PLUGIN_NAME} PRIVATE
    FLUTTER_PLUGIN_IMPL

    # Add macro to indicate that libmpv & ANGLE from package:media_kit_libs_*** are not found.
    "MEDIA_KIT_LIBS_NOT_FOUND=1"
  )

  target_include_directories(
    ${PLUGIN_NAME} INTERFACE
    "${CMAKE_CURRENT_SOURCE_DIR}/include"
  )

  target_link_libraries(
    ${PLUGIN_NAME} PRIVATE
    flutter
    flutter_wrapper_plugin
  )
endif()

set(
  media_kit_video_bundled_libraries
  ""
  PARENT_SCOPE
)
