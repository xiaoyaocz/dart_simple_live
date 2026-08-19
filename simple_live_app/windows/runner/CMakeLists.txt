cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_link_libraries(${BINARY_NAME} PRIVATE "shell32.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

set(NATIVE_ASSETS_DIR "${CMAKE_SOURCE_DIR}/../build/native_assets/windows")
set(DART_QUICKJS_DLL "${NATIVE_ASSETS_DIR}/dart_quickjs.dll")
if(NOT EXISTS "${DART_QUICKJS_DLL}")
  file(GLOB_RECURSE DART_QUICKJS_CANDIDATES
    "${CMAKE_SOURCE_DIR}/../.dart_tool/hooks_runner/shared/dart_quickjs/build/*/dart_quickjs.dll")
  list(LENGTH DART_QUICKJS_CANDIDATES DART_QUICKJS_CANDIDATE_COUNT)
  if(DART_QUICKJS_CANDIDATE_COUNT GREATER 0)
    list(GET DART_QUICKJS_CANDIDATES 0 DART_QUICKJS_DLL)
  endif()
endif()
if(EXISTS "${DART_QUICKJS_DLL}")
  add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      "${DART_QUICKJS_DLL}"
      "$<TARGET_FILE_DIR:${BINARY_NAME}>/dart_quickjs.dll"
    COMMENT "Copy required dart_quickjs native asset"
    VERBATIM)
else()
  message(WARNING "dart_quickjs.dll was not found during CMake configure")
endif()
