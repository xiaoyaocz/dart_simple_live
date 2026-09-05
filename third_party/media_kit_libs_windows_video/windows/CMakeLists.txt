# This file is a part of media_kit (https://github.com/media-kit/media-kit).
#
# Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
# All rights reserved.
# Use of this source code is governed by MIT license that can be found in the LICENSE file.

cmake_minimum_required(VERSION 3.14)

cmake_policy(VERSION 3.14...3.25)

# This option is read by the other packages which are part of package:media_kit.
option(MEDIA_KIT_LIBS_AVAILABLE "package:media_kit libraries are available." ON)

set(PROJECT_NAME "media_kit_libs_windows_video")
project(${PROJECT_NAME} LANGUAGES CXX)

# Deal with MSVC incompatiblity
add_compile_definitions(_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR)

# ------------------------------------------------------------------------------
function(download_and_verify url md5 locationForArchive)
  # Check if the archive exists.
  if(EXISTS "${locationForArchive}")
    file(MD5 "${locationForArchive}" ARCHIVE_MD5)

    # If MD5 doesn't match, delete the archive to download again.
    if(NOT md5 STREQUAL ARCHIVE_MD5)
      file(REMOVE "${locationForArchive}")
      message(STATUS "MD5 mismatch. File deleted.")
    endif()
  endif()

  # Download the archive if it doesn't exist.
  if(NOT EXISTS "${locationForArchive}")
    message(STATUS "Downloading archive from ${url}...")
    file(DOWNLOAD "${url}" "${locationForArchive}")
    message(STATUS "Downloaded archive to ${locationForArchive}.")

    # Verify MD5 of the newly downloaded file.
    file(MD5 "${locationForArchive}" ARCHIVE_MD5)

    if(md5 STREQUAL ARCHIVE_MD5)
      message(STATUS "${locationForArchive} Verification successful.")
    else()
      message(FATAL_ERROR "${locationForArchive} Integrity check failed, please try to re-build project again.")
    endif()
  endif()
endfunction()

function(download_and_verify_sha256 url sha256 locationForArchive)
  if(EXISTS "${locationForArchive}")
    file(SHA256 "${locationForArchive}" ARCHIVE_SHA256)
    if(NOT "${sha256}" STREQUAL "${ARCHIVE_SHA256}")
      file(REMOVE "${locationForArchive}")
      message(STATUS "SHA-256 mismatch. File deleted.")
    endif()
  endif()

  if(NOT EXISTS "${locationForArchive}")
    message(STATUS "Downloading archive from ${url}...")
    file(
      DOWNLOAD
      "${url}"
      "${locationForArchive}"
      EXPECTED_HASH "SHA256=${sha256}"
      STATUS DOWNLOAD_STATUS
      TLS_VERIFY ON
      TIMEOUT 300
      INACTIVITY_TIMEOUT 30
    )
    list(GET DOWNLOAD_STATUS 0 DOWNLOAD_STATUS_CODE)
    list(GET DOWNLOAD_STATUS 1 DOWNLOAD_STATUS_MESSAGE)
    if(NOT DOWNLOAD_STATUS_CODE EQUAL 0)
      file(REMOVE "${locationForArchive}")
      message(
        FATAL_ERROR
        "Failed to download ${url}: ${DOWNLOAD_STATUS_MESSAGE}"
      )
    endif()
  endif()

  file(SHA256 "${locationForArchive}" ARCHIVE_SHA256)
  if(NOT "${sha256}" STREQUAL "${ARCHIVE_SHA256}")
    message(
      FATAL_ERROR
      "${locationForArchive} SHA-256 verification failed."
    )
  endif()
endfunction()

find_program(SEVENZ_EXECUTABLE NAMES 7z 7za)

function(check_directory_exists_and_not_empty dir result_var)
  # Check if the directory exists
  if(EXISTS "${dir}")
    # Check if the directory is not empty
    file(GLOB dir_contents "${dir}/*")

    if(dir_contents)
      set(${result_var} TRUE PARENT_SCOPE)
    else()
      set(${result_var} FALSE PARENT_SCOPE)
      message(STATUS "Directory ${dir} exists but is empty!")
    endif()
  else()
    set(${result_var} FALSE PARENT_SCOPE)
    message(STATUS "Directory ${dir} does not exist!")
  endif()
endfunction()

# libmpv archive containing the pre-built shared libraries & headers.
# Keep the generic x86_64 build so older Windows CPUs do not require AVX2.
set(LIBMPV_RELEASE "20260828")
set(LIBMPV_REVISION "182fa6ca49")
set(LIBMPV "mpv-dev-x86_64-${LIBMPV_RELEASE}-git-${LIBMPV_REVISION}.7z")

# Download URL & SHA-256 hash of the libmpv archive.
set(LIBMPV_URL "https://github.com/shinchiro/mpv-winbuild-cmake/releases/download/${LIBMPV_RELEASE}/${LIBMPV}")
set(LIBMPV_SHA256 "9efd04d351e09eca350d01da1b8b0c406537c037537111ba65ab43c91905635b")

# Download location of the libmpv archive.
set(LIBMPV_ARCHIVE "${CMAKE_BINARY_DIR}/${LIBMPV}")
set(LIBMPV_SRC "${CMAKE_BINARY_DIR}/libmpv")
set(LIBMPV_MARKER "${LIBMPV_SRC}/.simplelive-${LIBMPV_RELEASE}-${LIBMPV_REVISION}")
if(DEFINED SIMPLE_LIVE_LIBMPV_ARCHIVE)
  set(LIBMPV_SHARED_ARCHIVE "${SIMPLE_LIVE_LIBMPV_ARCHIVE}")
else()
  set(LIBMPV_SHARED_ARCHIVE "${CMAKE_CURRENT_LIST_DIR}/../../${LIBMPV}")
endif()

# Developers and release builders may prefetch this archive once under
# third_party. Reuse it only after the same checksum validation used for the
# build directory copy.
if(EXISTS "${LIBMPV_SHARED_ARCHIVE}")
  file(SHA256 "${LIBMPV_SHARED_ARCHIVE}" LIBMPV_SHARED_ARCHIVE_SHA256)
  if(NOT "${LIBMPV_SHARED_ARCHIVE_SHA256}" STREQUAL "${LIBMPV_SHA256}")
    message(
      FATAL_ERROR
      "${LIBMPV_SHARED_ARCHIVE} SHA-256 verification failed."
    )
  endif()
  set(LIBMPV_BUILD_ARCHIVE_SHA256 "")
  if(EXISTS "${LIBMPV_ARCHIVE}")
    file(SHA256 "${LIBMPV_ARCHIVE}" LIBMPV_BUILD_ARCHIVE_SHA256)
  endif()
  if(NOT "${LIBMPV_BUILD_ARCHIVE_SHA256}" STREQUAL "${LIBMPV_SHA256}")
    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${LIBMPV_SHARED_ARCHIVE}"
        "${LIBMPV_ARCHIVE}"
      RESULT_VARIABLE LIBMPV_COPY_RESULT
    )
    if(NOT LIBMPV_COPY_RESULT EQUAL 0)
      message(FATAL_ERROR "Failed to copy ${LIBMPV_SHARED_ARCHIVE}.")
    endif()
  endif()
endif()

download_and_verify_sha256(
  ${LIBMPV_URL}
  ${LIBMPV_SHA256}
  ${LIBMPV_ARCHIVE}
)

set(LIBMPV_REQUIRED_FILES
  "${LIBMPV_SRC}/include/client.h"
  "${LIBMPV_SRC}/include/render.h"
  "${LIBMPV_SRC}/include/render_gl.h"
  "${LIBMPV_SRC}/include/stream_cb.h"
  "${LIBMPV_SRC}/libmpv.dll.a"
  "${LIBMPV_SRC}/libmpv-2.dll"
)

set(LIBMPV_SRC_VALID TRUE)
if(NOT EXISTS "${LIBMPV_MARKER}")
  set(LIBMPV_SRC_VALID FALSE)
endif()
foreach(LIBMPV_REQUIRED_FILE IN LISTS LIBMPV_REQUIRED_FILES)
  if(NOT EXISTS "${LIBMPV_REQUIRED_FILE}")
    set(LIBMPV_SRC_VALID FALSE)
  endif()
endforeach()

# Extract the libmpv archive at configure time so media_kit_video can link
# against the refreshed import library in the same CMake generation.
if(NOT LIBMPV_SRC_VALID)
  message(STATUS "Extracting ${LIBMPV}...")
  file(REMOVE_RECURSE "${LIBMPV_SRC}")
  file(MAKE_DIRECTORY "${LIBMPV_SRC}")
  if(SEVENZ_EXECUTABLE)
    execute_process(
      COMMAND "${SEVENZ_EXECUTABLE}" x -y "${LIBMPV_ARCHIVE}"
      WORKING_DIRECTORY "${LIBMPV_SRC}"
      RESULT_VARIABLE LIBMPV_EXTRACT_RESULT
      OUTPUT_VARIABLE LIBMPV_EXTRACT_OUTPUT
      ERROR_VARIABLE LIBMPV_EXTRACT_ERROR
    )
  else()
    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E tar xvf "${LIBMPV_ARCHIVE}"
      WORKING_DIRECTORY "${LIBMPV_SRC}"
      RESULT_VARIABLE LIBMPV_EXTRACT_RESULT
      OUTPUT_VARIABLE LIBMPV_EXTRACT_OUTPUT
      ERROR_VARIABLE LIBMPV_EXTRACT_ERROR
    )
  endif()
  if(NOT LIBMPV_EXTRACT_RESULT EQUAL 0)
    file(REMOVE_RECURSE "${LIBMPV_SRC}")
    message(
      FATAL_ERROR
      "Failed to extract ${LIBMPV_ARCHIVE}:\n"
      "${LIBMPV_EXTRACT_OUTPUT}\n${LIBMPV_EXTRACT_ERROR}"
    )
  endif()

  if(EXISTS "${LIBMPV_SRC}/include/mpv")
    file(COPY "${LIBMPV_SRC}/include/mpv/" DESTINATION "${LIBMPV_SRC}/include")
    file(REMOVE_RECURSE "${LIBMPV_SRC}/include/mpv")
  endif()

  foreach(LIBMPV_REQUIRED_FILE IN LISTS LIBMPV_REQUIRED_FILES)
    if(NOT EXISTS "${LIBMPV_REQUIRED_FILE}")
      file(REMOVE_RECURSE "${LIBMPV_SRC}")
      message(
        FATAL_ERROR
        "libmpv archive is missing required file: ${LIBMPV_REQUIRED_FILE}"
      )
    endif()
  endforeach()
  file(WRITE "${LIBMPV_MARKER}" "${LIBMPV}\n")
endif()

# ------------------------------------------------------------------------------

# ANGLE archive containing the pre-built shared libraries & headers.
set(ANGLE "ANGLE.7z")

# Download URL & MD5 hash of the ANGLE archive.
set(ANGLE_URL "https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z")
set(ANGLE_MD5 "e866f13e8d552348058afaafe869b1ed")

# Download location of the ANGLE archive.
set(ANGLE_ARCHIVE "${CMAKE_BINARY_DIR}/${ANGLE}")
set(ANGLE_SRC "${CMAKE_BINARY_DIR}/ANGLE")

download_and_verify(
  ${ANGLE_URL}
  ${ANGLE_MD5}
  ${ANGLE_ARCHIVE}
)

check_directory_exists_and_not_empty(${ANGLE_SRC} ANGLE_SRC_VALID)

# Extract the ANGLE archive.
if(NOT ANGLE_SRC_VALID)
  message(STATUS "Extracting ${ANGLE}...")
  make_directory("${ANGLE_SRC}")
  add_custom_target("${PROJECT_NAME}_ANGLE_EXTRACT" ALL)
  add_custom_command(
    TARGET "${PROJECT_NAME}_ANGLE_EXTRACT"
    POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E tar xzf "\"${ANGLE_ARCHIVE}\""
    WORKING_DIRECTORY "${ANGLE_SRC}"
  )
endif()

# ------------------------------------------------------------------------------
set(PLUGIN_NAME "media_kit_libs_windows_video_plugin")

add_library(
  ${PLUGIN_NAME} SHARED
  "include/media_kit_libs_windows_video/media_kit_libs_windows_video_plugin_c_api.h"
  "media_kit_libs_windows_video_plugin_c_api.cpp"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(
  ${PLUGIN_NAME}
  PROPERTIES
  CXX_VISIBILITY_PRESET
  hidden
)
target_compile_definitions(
  ${PLUGIN_NAME}
  PRIVATE
  FLUTTER_PLUGIN_IMPL
)

target_include_directories(
  ${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
target_link_libraries(
  ${PLUGIN_NAME}
  PRIVATE
  flutter
  flutter_wrapper_plugin
)

set(
  media_kit_libs_windows_video_bundled_libraries
  "${LIBMPV_SRC}/libmpv-2.dll"
  "${ANGLE_SRC}/d3dcompiler_47.dll"
  "${ANGLE_SRC}/libEGL.dll"
  "${ANGLE_SRC}/libGLESv2.dll"
  "${ANGLE_SRC}/vk_swiftshader.dll"
  "${ANGLE_SRC}/vulkan-1.dll"
  "${ANGLE_SRC}/zlib.dll"
  PARENT_SCOPE
)
