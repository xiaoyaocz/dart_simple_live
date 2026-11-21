# Keep the Windows-only patch in the build tree. The pub cache and other
# platforms still use the pinned upstream sources.
function(simplelive_patch_media_kit_video)
  if(NOT TARGET media_kit_video_plugin)
    return()
  endif()
  get_target_property(source_dir media_kit_video_plugin SOURCE_DIR)
  get_target_property(sources media_kit_video_plugin SOURCES)
  if(NOT "angle_surface_manager.cc" IN_LIST sources)
    return()
  endif()
  file(STRINGS "${source_dir}/../pubspec.yaml" version REGEX "^version:")
  if(NOT version STREQUAL "version: 2.0.1")
    message(FATAL_ERROR "Revalidate the Simple Live ANGLE patch for ${version}")
  endif()
  set(overlay "${CMAKE_CURRENT_BINARY_DIR}/simplelive_media_kit_video")
  file(MAKE_DIRECTORY "${overlay}")
  file(GLOB windows_files CONFIGURE_DEPENDS "${source_dir}/*.cc" "${source_dir}/*.h")
  foreach(input IN LISTS windows_files)
    get_filename_component(name "${input}" NAME)
    if(NOT name MATCHES "^angle_surface_manager\\.")
      configure_file("${input}" "${overlay}/${name}" COPYONLY)
    endif()
  endforeach()

  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${source_dir}/angle_surface_manager.cc" "${source_dir}/angle_surface_manager.h")
  file(READ "${source_dir}/angle_surface_manager.h" angle_header)
  file(READ "${source_dir}/angle_surface_manager.cc" angle_source)
  string(REPLACE "void Read();" "bool Read();" angle_header "${angle_header}")
  string(REPLACE "HANDLE mutex_ = nullptr;"
    "std::mutex mutex_;\n  bool frame_pending_ = true;" angle_header "${angle_header}")
  string(REPLACE "#include <functional>" "#include <functional>\n#include <mutex>"
    angle_header "${angle_header}")
  string(REPLACE "  mutex_ = ::CreateMutex(NULL, FALSE, NULL);\n" "" angle_source "${angle_source}")
  string(REPLACE "  ::ReleaseMutex(mutex_);\n" "" angle_source "${angle_source}")
  string(REPLACE "  ::CloseHandle(mutex_);\n" "" angle_source "${angle_source}")
  string(REPLACE "  ::WaitForSingleObject(mutex_, INFINITE);"
    "  const std::lock_guard<std::mutex> lock(mutex_);" angle_source "${angle_source}")
  string(REPLACE "void ANGLESurfaceManager::SetSize(int32_t width, int32_t height) {"
    "void ANGLESurfaceManager::SetSize(int32_t width, int32_t height) {\n  const std::lock_guard<std::mutex> lock(mutex_);"
    angle_source "${angle_source}")
  string(REPLACE "  SwapBuffers();\n  MakeCurrent(false);"
    "  SwapBuffers();\n  MakeCurrent(false);\n  frame_pending_ = true;" angle_source "${angle_source}")
  string(REPLACE "void ANGLESurfaceManager::Read() {" "bool ANGLESurfaceManager::Read() {" angle_source "${angle_source}")
  string(REPLACE "  if (d3d_11_device_context_ != nullptr) {\n    d3d_11_device_context_->CopyResource"
    "  if (frame_pending_ && d3d_11_device_context_ && d3d_11_texture_2D_ && internal_d3d_11_texture_2D_) {\n    d3d_11_device_context_->CopyResource"
    angle_source "${angle_source}")
  string(REPLACE "    d3d_11_device_context_->Flush();\n  }\n}"
    "    d3d_11_device_context_->Flush();\n    frame_pending_ = false;\n    return true;\n  }\n  return false;\n}"
    angle_source "${angle_source}")
  string(REPLACE "  CleanUp(false);\n  if (!CreateD3DTexture())"
    "  CleanUp(false);\n  frame_pending_ = true;\n  if (!CreateD3DTexture())" angle_source "${angle_source}")
  # ComPtr already releases the reference when cleared.
  string(REPLACE "    internal_d3d_11_texture_2D_->Release();\n" "" angle_source "${angle_source}")
  string(REPLACE "    d3d_11_texture_2D_->Release();\n" "" angle_source "${angle_source}")
  if(angle_source MATCHES "WaitForSingleObject\\(mutex_|::ReleaseMutex\\(mutex_|texture_2D_->Release"
      OR NOT angle_source MATCHES "frame_pending_ = false;")
    message(FATAL_ERROR "Simple Live could not safely apply the pinned ANGLE patch")
  endif()
  file(CONFIGURE OUTPUT "${overlay}/angle_surface_manager.h" CONTENT "${angle_header}" @ONLY)
  file(CONFIGURE OUTPUT "${overlay}/angle_surface_manager.cc" CONTENT "${angle_source}" @ONLY)

  set(patched_sources)
  foreach(source IN LISTS sources)
    if(EXISTS "${source_dir}/${source}")
      list(APPEND patched_sources "${overlay}/${source}")
    else()
      list(APPEND patched_sources "${source}")
    endif()
  endforeach()
  set_property(TARGET media_kit_video_plugin PROPERTY SOURCES "${patched_sources}")
  target_include_directories(media_kit_video_plugin PRIVATE "${source_dir}")
endfunction()
