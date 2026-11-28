# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

set(WIL_VERSION "1.0.231216.1")
set(WEBVIEW_VERSION "1.0.2792.45")
set(NLOHMANN_JSON "3.11.2")

message(VERBOSE "CMake system version is ${CMAKE_SYSTEM_VERSION} (using SDK ${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION})")

# Project-level configuration.
set(PROJECT_NAME "flutter_inappwebview_windows")
project(${PROJECT_NAME} LANGUAGES CXX)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "flutter_inappwebview_windows_plugin")

find_program(NUGET nuget)
if(NOT NUGET)
  message(NOTICE "Nuget is not installed! The flutter_inappwebview_windows plugin requires it. Check https://inappwebview.dev/docs/intro#setup-windows")
endif()

add_custom_target(${PROJECT_NAME}_DEPENDENCIES_DOWNLOAD ALL)
add_custom_command(
  TARGET ${PROJECT_NAME}_DEPENDENCIES_DOWNLOAD PRE_BUILD
  COMMAND ${NUGET} install Microsoft.Windows.ImplementationLibrary -Version ${WIL_VERSION} -ExcludeVersion -OutputDirectory ${CMAKE_BINARY_DIR}/packages
  COMMAND ${NUGET} install Microsoft.Web.WebView2 -Version ${WEBVIEW_VERSION} -ExcludeVersion -OutputDirectory ${CMAKE_BINARY_DIR}/packages
  COMMAND ${NUGET} install nlohmann.json -Version ${NLOHMANN_JSON} -ExcludeVersion -OutputDirectory ${CMAKE_BINARY_DIR}/packages
  DEPENDS ${NUGET}
)

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "flutter_inappwebview_windows_plugin.cpp"
  "flutter_inappwebview_windows_plugin.h"
  "utils/log.h"
  "utils/com_apartment.h"
  "utils/strconv.h"
  "utils/map.h"
  "utils/vector.h"
  "utils/string.h"
  "utils/util.h"
  "utils/flutter.h"
  "utils/base64.cpp"
  "utils/base64.h"
  "types/channel_delegate.cpp"
  "types/channel_delegate.h"
  "types/base_callback_result.h"
  "types/url_request.cpp"
  "types/url_request.h"
  "types/navigation_action.cpp"
  "types/navigation_action.h"
  "types/web_resource_error.cpp"
  "types/web_resource_error.h"
  "types/web_resource_request.cpp"
  "types/web_resource_request.h"
  "types/web_resource_response.cpp"
  "types/web_resource_response.h"
  "types/web_history.cpp"
  "types/web_history.h"
  "types/web_history_item.cpp"
  "types/web_history_item.h"
  "types/content_world.cpp"
  "types/content_world.h"
  "types/user_script.cpp"
  "types/user_script.h"
  "types/plugin_script.cpp"
  "types/plugin_script.h"
  "types/size_2d.cpp"
  "types/size_2d.h"
  "types/rect.cpp"
  "types/rect.h"
  "types/callbacks_complete.h"
  "types/screenshot_configuration.cpp"
  "types/screenshot_configuration.h"
  "types/create_window_action.cpp"
  "types/create_window_action.h"
  "types/new_window_requested_args.cpp"
  "types/new_window_requested_args.h"
  "types/window_features.cpp"
  "types/window_features.h"
  "types/ssl_certificate.cpp"
  "types/ssl_certificate.h"
  "types/permission_response.cpp"
  "types/permission_response.h"
  "types/custom_scheme_response.cpp"
  "types/custom_scheme_response.h"
  "types/custom_scheme_registration.cpp"
  "types/custom_scheme_registration.h"
  "custom_platform_view/custom_platform_view.cc"
  "custom_platform_view/custom_platform_view.h"
  "custom_platform_view/texture_bridge.cc"
  "custom_platform_view/texture_bridge.h"
  "custom_platform_view/capture_event_handler.h"
  "custom_platform_view/graphics_context.cc"
  "custom_platform_view/graphics_context.h"
  "custom_platform_view/util/direct3d11.interop.cc"
  "custom_platform_view/util/direct3d11.interop.h"
  "custom_platform_view/util/rohelper.cc"
  "custom_platform_view/util/rohelper.h"
  "custom_platform_view/util/string_converter.cc"
  "custom_platform_view/util/string_converter.h"
  "custom_platform_view/util/swizzle.h"
  "plugin_scripts_js/plugin_scripts_util.h"
  "plugin_scripts_js/javascript_bridge_js.cpp"
  "plugin_scripts_js/javascript_bridge_js.h"
  "webview_environment/webview_environment_settings.cpp"
  "webview_environment/webview_environment_settings.h"
  "webview_environment/webview_environment.cpp"
  "webview_environment/webview_environment.h"
  "webview_environment/webview_environment_manager.cpp"
  "webview_environment/webview_environment_manager.h"
  "webview_environment/webview_environment_channel_delegate.cpp"
  "webview_environment/webview_environment_channel_delegate.h"
  "in_app_webview/user_content_controller.cpp"
  "in_app_webview/user_content_controller.h"
  "in_app_webview/in_app_webview_settings.cpp"
  "in_app_webview/in_app_webview_settings.h"
  "in_app_webview/in_app_webview.cpp"
  "in_app_webview/in_app_webview.h"
  "in_app_webview/in_app_webview_manager.cpp"
  "in_app_webview/in_app_webview_manager.h"
  "in_app_webview/webview_channel_delegate.cpp"
  "in_app_webview/webview_channel_delegate.h"
  "headless_in_app_webview/headless_in_app_webview.cpp"
  "headless_in_app_webview/headless_in_app_webview.h"
  "headless_in_app_webview/headless_in_app_webview_manager.cpp"
  "headless_in_app_webview/headless_in_app_webview_manager.h"
  "headless_in_app_webview/headless_webview_channel_delegate.cpp"
  "headless_in_app_webview/headless_webview_channel_delegate.h"
  "in_app_browser/in_app_browser_settings.cpp"
  "in_app_browser/in_app_browser_settings.h"
  "in_app_browser/in_app_browser_manager.cpp"
  "in_app_browser/in_app_browser_manager.h"
  "in_app_browser/in_app_browser.cpp"
  "in_app_browser/in_app_browser.h"
  "in_app_browser/in_app_browser_channel_delegate.cpp"
  "in_app_browser/in_app_browser_channel_delegate.h"
  "cookie_manager.cpp"
  "cookie_manager.h"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/flutter_inappwebview_windows/flutter_inappwebview_windows_plugin_c_api.h"
  "flutter_inappwebview_windows_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

if(NOT FLUTTER_WEBVIEW_WINDOWS_USE_TEXTURE_FALLBACK)
  message(STATUS "Building with D3D texture support.")
  target_compile_definitions("${PLUGIN_NAME}" PRIVATE
    HAVE_FLUTTER_D3D_TEXTURE
  )
  target_sources("${PLUGIN_NAME}" PRIVATE
    "custom_platform_view/texture_bridge_gpu.cc"
    "custom_platform_view/texture_bridge_gpu.h"
  )
else()
  message(STATUS "Building with fallback PixelBuffer texture.")
  target_sources("${PLUGIN_NAME}" PRIVATE
    "custom_platform_view/texture_bridge_fallback.cc"
    "custom_platform_view/texture_bridge_fallback.h"
    "custom_platform_view/util/cpuid/cpuinfo.cc"
    "custom_platform_view/util/cpuid/cpuinfo.h"
  )
  # Enable AVX2 for pixel buffer conversions
  if(MSVC)
    target_compile_options(${PLUGIN_NAME} PRIVATE "/arch:AVX2")
  endif()
endif()

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
# apply_standard_settings(${PLUGIN_NAME})
#
# IMPORTANT: The apply_standard_settings function is not used here because it
# is causing the plugin to fail to compile because of the usage of /WX flag.
# So, creating here a custom function to apply the standard settings without the /WX flag.
function(FLUTTER_INAPPWEBVIEW_WINDOWS_APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  # The pinned WIL version still includes experimental/coroutine. VS 2026
  # requires explicit opt-in until WIL is migrated to the C++20 implementation.
  target_compile_definitions(${TARGET} PRIVATE _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)
  target_compile_options(${TARGET} PRIVATE /utf-8)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()
flutter_inappwebview_windows_apply_standard_settings(${PLUGIN_NAME})

target_link_libraries(${PLUGIN_NAME} PRIVATE ${CMAKE_BINARY_DIR}/packages/Microsoft.Web.WebView2/build/native/Microsoft.Web.WebView2.targets)
target_link_libraries(${PLUGIN_NAME} PRIVATE ${CMAKE_BINARY_DIR}/packages/Microsoft.Windows.ImplementationLibrary/build/native/Microsoft.Windows.ImplementationLibrary.targets)
target_link_libraries(${PLUGIN_NAME} PRIVATE ${CMAKE_BINARY_DIR}/packages/nlohmann.json/build/native/nlohmann.json.targets)

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(flutter_inappwebview_windows_bundled_libraries
  PARENT_SCOPE
)

# === Tests ===
# These unit tests can be run from a terminal after building the example, or
# from Visual Studio after opening the generated solution file.

# Only enable test builds when building the example (which sets this variable)
# so that plugin clients aren't building the tests.
if (${include_${PROJECT_NAME}_tests})
set(TEST_RUNNER "${PROJECT_NAME}_test")
enable_testing()

# Add the Google Test dependency.
include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/release-1.11.0.zip
)
# Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
# Disable install commands for gtest so it doesn't end up in the bundle.
set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
FetchContent_MakeAvailable(googletest)

# The plugin's C API is not very useful for unit testing, so build the sources
# directly into the test binary rather than using the DLL.
add_executable(${TEST_RUNNER}
  test/flutter_inappwebview_windows_plugin_test.cpp
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${TEST_RUNNER})
target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(${TEST_RUNNER} PRIVATE flutter_wrapper_plugin)
target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)
# flutter_wrapper_plugin has link dependencies on the Flutter DLL.
add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
)

# Enable automatic test discovery.
include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER})
endif()
