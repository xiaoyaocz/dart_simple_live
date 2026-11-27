# Keep the Windows-only patches in the build tree. The pub cache and other
# platforms still use the pinned upstream sources.

function(_simplelive_replace var needle replacement file_label)
  string(FIND "${${var}}" "${needle}" _pos)
  if(_pos EQUAL -1)
    message(FATAL_ERROR "Simple Live patch failed for ${file_label}: missing snippet:\n${needle}")
  endif()
  string(REPLACE "${needle}" "${replacement}" _updated "${${var}}")
  set(${var} "${_updated}" PARENT_SCOPE)
endfunction()

function(simplelive_configure_libmpv out_dll out_lib out_inc)
  set(_archive_name "mpv-dev-x86_64-20261111-git-bcde6b93cc.7z")
  set(_archive_url "https://github.com/shinchiro/mpv-winbuild-cmake/releases/download/20261111/${_archive_name}")
  set(_archive_sha256 "273c079b11ea5575822f972756f4c9a71149a5c10130353abeb8586738938452")

  set(_root "${CMAKE_BINARY_DIR}/simplelive_libmpv")
  set(_archive "${_root}/${_archive_name}")
  set(_extracted "${_root}/extracted")
  set(_stamp "${_extracted}/.simplelive_sha256")
  file(MAKE_DIRECTORY "${_root}")

  set(_need_download TRUE)
  if(EXISTS "${_archive}")
    file(SHA256 "${_archive}" _actual_sha256)
    string(TOLOWER "${_actual_sha256}" _actual_sha256)
    if(_actual_sha256 STREQUAL "${_archive_sha256}")
      set(_need_download FALSE)
    else()
      file(REMOVE "${_archive}")
    endif()
  endif()

  if(_need_download)
    message(STATUS "Simple Live: downloading ${_archive_name}...")
    file(DOWNLOAD
      "${_archive_url}"
      "${_archive}"
      EXPECTED_HASH "SHA256=${_archive_sha256}"
      STATUS _dl_status
      TLS_VERIFY ON
    )
    list(GET _dl_status 0 _dl_code)
    if(NOT _dl_code EQUAL 0)
      file(REMOVE "${_archive}")
      message(FATAL_ERROR "Simple Live failed to download ${_archive_url}: ${_dl_status}")
    endif()
  endif()

  set(_need_extract TRUE)
  if(EXISTS "${_stamp}"
      AND EXISTS "${_extracted}/libmpv-2.dll"
      AND EXISTS "${_extracted}/libmpv.dll.a"
      AND EXISTS "${_extracted}/include/mpv/client.h")
    file(READ "${_stamp}" _stamp_val)
    string(STRIP "${_stamp_val}" _stamp_val)
    if(_stamp_val STREQUAL "${_archive_sha256}")
      set(_need_extract FALSE)
    endif()
  endif()

  if(_need_extract)
    file(REMOVE_RECURSE "${_extracted}")
    file(MAKE_DIRECTORY "${_extracted}")
    message(STATUS "Simple Live: extracting ${_archive_name}...")
    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E tar xf "${_archive}"
      WORKING_DIRECTORY "${_extracted}"
      RESULT_VARIABLE _tar_res
    )
    if(NOT _tar_res EQUAL 0)
      message(FATAL_ERROR "Simple Live failed to extract ${_archive}: ${_tar_res}")
    endif()
    file(WRITE "${_stamp}" "${_archive_sha256}\n")
  endif()

  foreach(_required IN ITEMS
      "${_extracted}/libmpv-2.dll"
      "${_extracted}/libmpv.dll.a"
      "${_extracted}/include/mpv/client.h"
      "${_extracted}/include/mpv/render.h"
      "${_extracted}/include/mpv/render_gl.h")
    if(NOT EXISTS "${_required}")
      message(FATAL_ERROR "Simple Live missing extracted libmpv asset: ${_required}")
    endif()
  endforeach()

  set(${out_dll} "${_extracted}/libmpv-2.dll" PARENT_SCOPE)
  set(${out_lib} "${_extracted}/libmpv.dll.a" PARENT_SCOPE)
  set(${out_inc} "${_extracted}/include/mpv" PARENT_SCOPE)
endfunction()

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

  simplelive_configure_libmpv(_mpv_dll _mpv_lib _mpv_inc)

  # Swap bundled libmpv-2.dll from legacy v0.36.0 to v0.42.0+.
  set(_patched_bundled)
  set(_swapped_dll FALSE)
  foreach(_entry IN LISTS PLUGIN_BUNDLED_LIBRARIES)
    if(_entry MATCHES "/libmpv-2\\.dll$" OR _entry MATCHES "\\\\libmpv-2\\.dll$")
      list(APPEND _patched_bundled "${_mpv_dll}")
      set(_swapped_dll TRUE)
    else()
      list(APPEND _patched_bundled "${_entry}")
    endif()
  endforeach()
  if(NOT _swapped_dll)
    message(FATAL_ERROR "Simple Live could not replace bundled libmpv-2.dll in PLUGIN_BUNDLED_LIBRARIES")
  endif()
  set(PLUGIN_BUNDLED_LIBRARIES "${_patched_bundled}" PARENT_SCOPE)

  # Swap linked import library on media_kit_video_plugin to match v0.42.0 headers.
  get_target_property(_link_libs media_kit_video_plugin LINK_LIBRARIES)
  set(_patched_links)
  set(_swapped_lib FALSE)
  foreach(_lib IN LISTS _link_libs)
    if(_lib MATCHES "libmpv\\.dll\\.a$")
      list(APPEND _patched_links "${_mpv_lib}")
      set(_swapped_lib TRUE)
    else()
      list(APPEND _patched_links "${_lib}")
    endif()
  endforeach()
  if(NOT _swapped_lib)
    message(FATAL_ERROR "Simple Live could not replace libmpv.dll.a in media_kit_video_plugin LINK_LIBRARIES")
  endif()
  set_target_properties(media_kit_video_plugin PROPERTIES LINK_LIBRARIES "${_patched_links}")

  set(overlay "${CMAKE_CURRENT_BINARY_DIR}/simplelive_media_kit_video")
  file(MAKE_DIRECTORY "${overlay}")
  file(GLOB windows_files CONFIGURE_DEPENDS "${source_dir}/*.cc" "${source_dir}/*.h")
  foreach(input IN LISTS windows_files)
    get_filename_component(name "${input}" NAME)
    if(NOT name MATCHES "^(angle_surface_manager|video_output|video_output_manager)\\."
        AND NOT name STREQUAL "media_kit_video_plugin.cc")
      configure_file("${input}" "${overlay}/${name}" COPYONLY)
    endif()
  endforeach()

  foreach(_dep IN ITEMS
      "angle_surface_manager.h"
      "angle_surface_manager.cc"
      "video_output.h"
      "video_output.cc"
      "video_output_manager.h"
      "video_output_manager.cc"
      "media_kit_video_plugin.cc")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${source_dir}/${_dep}")
  endforeach()

  # --- 1. Patch angle_surface_manager.h ---
  file(READ "${source_dir}/angle_surface_manager.h" angle_header)
  _simplelive_replace(angle_header
    "#include <cstdint>"
    "#include <cstdint>\n#include <mutex>"
    "angle_surface_manager.h (include mutex)")
  _simplelive_replace(angle_header
    "  const HANDLE handle() const { return handle_; }"
    "  const HANDLE handle() const { return handle_; }\n  bool is_d3d11() const { return is_d3d11_; }"
    "angle_surface_manager.h (is_d3d11)")
  _simplelive_replace(angle_header
    "  void Read();"
    "  bool Read();"
    "angle_surface_manager.h (Read)")
  _simplelive_replace(angle_header
    "  // Sync |Draw| & |Read| calls.\n  HANDLE mutex_ = nullptr;"
    "  // Sync |Draw| & |Read| calls.\n  std::mutex mutex_;\n  bool frame_pending_ = true;\n  bool is_d3d11_ = false;\n  GLuint gl_texture_ = 0;"
    "angle_surface_manager.h (fields)")
  _simplelive_replace(angle_header
    "  static constexpr EGLint kEGLContextAttributes[] = {\n      EGL_CONTEXT_CLIENT_VERSION,\n      2,\n      EGL_NONE,\n  };"
    "  static constexpr EGLint kEGL3ContextAttributes[] = {\n      EGL_CONTEXT_CLIENT_VERSION,\n      3,\n      EGL_NONE,\n  };\n  static constexpr EGLint kEGLContextAttributes[] = {\n      EGL_CONTEXT_CLIENT_VERSION,\n      2,\n      EGL_NONE,\n  };"
    "angle_surface_manager.h (ES3 attributes)")

  # --- 2. Patch angle_surface_manager.cc ---
  file(READ "${source_dir}/angle_surface_manager.cc" angle_source)
  _simplelive_replace(angle_source
    "  mutex_ = ::CreateMutex(NULL, FALSE, NULL);\n"
    ""
    "angle_surface_manager.cc (CreateMutex)")
  _simplelive_replace(angle_source
    "void ANGLESurfaceManager::SetSize(int32_t width, int32_t height) {"
    "void ANGLESurfaceManager::SetSize(int32_t width, int32_t height) {\n  const std::lock_guard<std::mutex> lock(mutex_);"
    "angle_surface_manager.cc (SetSize lock)")
  _simplelive_replace(angle_source
    "void ANGLESurfaceManager::Draw(std::function<void()> callback) {\n  ::WaitForSingleObject(mutex_, INFINITE);\n  MakeCurrent(true);\n  callback();\n  SwapBuffers();\n  MakeCurrent(false);\n  ::ReleaseMutex(mutex_);\n}"
    "void ANGLESurfaceManager::Draw(std::function<void()> callback) {\n  const std::lock_guard<std::mutex> lock(mutex_);\n  MakeCurrent(true);\n  callback();\n  SwapBuffers();\n  MakeCurrent(false);\n  frame_pending_ = true;\n}"
    "angle_surface_manager.cc (Draw)")
  _simplelive_replace(angle_source
    "void ANGLESurfaceManager::Read() {\n  ::WaitForSingleObject(mutex_, INFINITE);\n  if (d3d_11_device_context_ != nullptr) {\n    d3d_11_device_context_->CopyResource(d3d_11_texture_2D_.Get(),\n                                         internal_d3d_11_texture_2D_.Get());\n    d3d_11_device_context_->Flush();\n  }\n  ::ReleaseMutex(mutex_);\n}"
    "bool ANGLESurfaceManager::Read() {\n  const std::lock_guard<std::mutex> lock(mutex_);\n  if (frame_pending_ && d3d_11_device_context_ && d3d_11_texture_2D_ &&\n      internal_d3d_11_texture_2D_) {\n    d3d_11_device_context_->CopyResource(d3d_11_texture_2D_.Get(),\n                                         internal_d3d_11_texture_2D_.Get());\n    d3d_11_device_context_->Flush();\n    frame_pending_ = false;\n    return true;\n  }\n  return false;\n}"
    "angle_surface_manager.cc (Read)")
  _simplelive_replace(angle_source
    "ANGLESurfaceManager::~ANGLESurfaceManager() {\n  CleanUp(true);\n  ::ReleaseMutex(mutex_);\n  ::CloseHandle(mutex_);\n  instance_count_--;\n}"
    "ANGLESurfaceManager::~ANGLESurfaceManager() {\n  CleanUp(true);\n  instance_count_--;\n}"
    "angle_surface_manager.cc (destructor)")
  _simplelive_replace(angle_source
    "void ANGLESurfaceManager::Create() {\n  CleanUp(false);\n  if (!CreateD3DTexture()) {"
    "void ANGLESurfaceManager::Create() {\n  CleanUp(false);\n  frame_pending_ = true;\n  if (!CreateD3DTexture()) {"
    "angle_surface_manager.cc (Create)")
  _simplelive_replace(angle_source
    [=[void ANGLESurfaceManager::CleanUp(bool release_context) {
  if (release_context) {
    if (display_ != EGL_NO_DISPLAY && surface_ != EGL_NO_SURFACE) {
      eglReleaseTexImage(display_, surface_, EGL_BACK_BUFFER);
    }
    if (display_ != EGL_NO_DISPLAY && context_ != EGL_NO_CONTEXT) {
      eglDestroyContext(display_, context_);
      context_ = EGL_NO_CONTEXT;
    }
    if (surface_ != EGL_NO_SURFACE) {
      eglDestroySurface(display_, surface_);
      surface_ = EGL_NO_SURFACE;
    }
    if (instance_count_ == 1) {
      eglTerminate(display_);
    }
    display_ = EGL_NO_DISPLAY;
    // Release D3D device & context if the instance is being destroyed.
    if (d3d_11_device_context_) {
      d3d_11_device_context_->Release();
      d3d_11_device_context_ = nullptr;
    }
    if (d3d_11_device_) {
      d3d_11_device_->Release();
      d3d_11_device_ = nullptr;
    }
  } else {
    // Clear context & destroy existing |surface_|.
    eglMakeCurrent(display_, EGL_NO_SURFACE, EGL_NO_SURFACE, context_);
    if (display_ != EGL_NO_DISPLAY && surface_ != EGL_NO_SURFACE) {
      eglDestroySurface(display_, surface_);
    }
    surface_ = EGL_NO_SURFACE;
  }
  // Release D3D 11 texture(s).
  if (internal_d3d_11_texture_2D_) {
    internal_d3d_11_texture_2D_->Release();
    internal_d3d_11_texture_2D_ = nullptr;
  }
  if (d3d_11_texture_2D_) {
    d3d_11_texture_2D_->Release();
    d3d_11_texture_2D_ = nullptr;
  }
}]=]
    [=[void ANGLESurfaceManager::CleanUp(bool release_context) {
  if (display_ != EGL_NO_DISPLAY && context_ != EGL_NO_CONTEXT &&
      gl_texture_ != 0) {
    if (surface_ != EGL_NO_SURFACE) {
      eglMakeCurrent(display_, surface_, surface_, context_);
    }
    glDeleteTextures(1, &gl_texture_);
    gl_texture_ = 0;
  }
  if (display_ != EGL_NO_DISPLAY && surface_ != EGL_NO_SURFACE) {
    eglReleaseTexImage(display_, surface_, EGL_BACK_BUFFER);
  }
  if (display_ != EGL_NO_DISPLAY) {
    eglMakeCurrent(display_, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
  }
  if (surface_ != EGL_NO_SURFACE) {
    eglDestroySurface(display_, surface_);
    surface_ = EGL_NO_SURFACE;
  }
  // Release D3D11 textures before D3D11 device/context so COM refs drop to 0.
  internal_d3d_11_texture_2D_.Reset();
  d3d_11_texture_2D_.Reset();
  internal_handle_ = nullptr;
  handle_ = nullptr;
  if (release_context) {
    if (display_ != EGL_NO_DISPLAY && context_ != EGL_NO_CONTEXT) {
      eglDestroyContext(display_, context_);
      context_ = EGL_NO_CONTEXT;
    }
    // Keep process-wide ANGLE EGLDisplay initialized across room switches to
    // prevent respawning internal ANGLE/D3D11 driver threads.
    display_ = EGL_NO_DISPLAY;
    if (d3d_11_device_context_) {
      d3d_11_device_context_->Release();
      d3d_11_device_context_ = nullptr;
    }
    if (d3d_11_device_) {
      d3d_11_device_->Release();
      d3d_11_device_ = nullptr;
    }
  }
}]=]
    "angle_surface_manager.cc (CleanUp)")
  _simplelive_replace(angle_source
    "  internal_d3d_11_texture_2D_->AddRef();\n"
    ""
    "angle_surface_manager.cc (internal AddRef leak)")
  _simplelive_replace(angle_source
    "  d3d_11_texture_2D_->AddRef();\n"
    ""
    "angle_surface_manager.cc (external AddRef leak)")
  _simplelive_replace(angle_source
    [=[    if (eglGetPlatformDisplayEXT) {
      display_ = eglGetPlatformDisplayEXT(EGL_PLATFORM_ANGLE_ANGLE,
                                          EGL_DEFAULT_DISPLAY,
                                          kD3D11DisplayAttributes);
      if (eglInitialize(display_, 0, 0) == EGL_FALSE) {
        display_ = eglGetPlatformDisplayEXT(EGL_PLATFORM_ANGLE_ANGLE,
                                            EGL_DEFAULT_DISPLAY,
                                            kD3D11_9_3DisplayAttributes);
        if (eglInitialize(display_, 0, 0) == EGL_FALSE) {
          display_ = eglGetPlatformDisplayEXT(EGL_PLATFORM_ANGLE_ANGLE,
                                              EGL_DEFAULT_DISPLAY,
                                              kD3D9DisplayAttributes);
          if (eglInitialize(display_, 0, 0) == EGL_FALSE) {
            display_ = eglGetPlatformDisplayEXT(EGL_PLATFORM_ANGLE_ANGLE,
                                                EGL_DEFAULT_DISPLAY,
                                                kWrapDisplayAttributes);
            if (eglInitialize(display_, 0, 0) == EGL_FALSE) {
              FAIL("eglGetPlatformDisplayEXT");
            }
          }
        }
      }
    }]=]
    [=[    if (eglGetPlatformDisplayEXT) {
      is_d3d11_ = false;
      display_ = eglGetPlatformDisplayEXT(EGL_PLATFORM_ANGLE_ANGLE,
                                          EGL_DEFAULT_DISPLAY,
                                          kD3D11DisplayAttributes);
      if (eglInitialize(display_, 0, 0) == EGL_FALSE) {
        display_ = eglGetPlatformDisplayEXT(EGL_PLATFORM_ANGLE_ANGLE,
                                            EGL_DEFAULT_DISPLAY,
                                            kD3D11_9_3DisplayAttributes);
        if (eglInitialize(display_, 0, 0) == EGL_FALSE) {
          display_ = eglGetPlatformDisplayEXT(EGL_PLATFORM_ANGLE_ANGLE,
                                              EGL_DEFAULT_DISPLAY,
                                              kD3D9DisplayAttributes);
          if (eglInitialize(display_, 0, 0) == EGL_FALSE) {
            display_ = eglGetPlatformDisplayEXT(EGL_PLATFORM_ANGLE_ANGLE,
                                                EGL_DEFAULT_DISPLAY,
                                                kWrapDisplayAttributes);
            if (eglInitialize(display_, 0, 0) == EGL_FALSE) {
              FAIL("eglGetPlatformDisplayEXT");
            }
          }
        } else {
          is_d3d11_ = true;
        }
      } else {
        is_d3d11_ = true;
      }
    }]=]
    "angle_surface_manager.cc (CreateEGLDisplay)")
  _simplelive_replace(angle_source
    [=[bool ANGLESurfaceManager::CreateAndBindEGLSurface() {
  // Do not create |context_| again, likely due to |Resize|.
  if (context_ == EGL_NO_CONTEXT) {
    // First time from the constructor itself.
    auto count = 0;
    auto result = eglChooseConfig(display_, kEGLConfigurationAttributes,
                                  &config_, 1, &count);
    if (result == EGL_FALSE || count == 0) {
      FAIL("eglChooseConfig");
    }
    context_ = eglCreateContext(display_, config_, EGL_NO_CONTEXT,
                                kEGLContextAttributes);
    if (context_ == EGL_NO_CONTEXT) {
      FAIL("eglCreateContext");
    }
  }
  EGLint buffer_attributes[] = {
      EGL_WIDTH,          width_,         EGL_HEIGHT,         height_,
      EGL_TEXTURE_TARGET, EGL_TEXTURE_2D, EGL_TEXTURE_FORMAT, EGL_TEXTURE_RGBA,
      EGL_NONE,
  };
  surface_ = eglCreatePbufferFromClientBuffer(
      display_, EGL_D3D_TEXTURE_2D_SHARE_HANDLE_ANGLE, internal_handle_,
      config_, buffer_attributes);
  if (surface_ == EGL_NO_SURFACE) {
    FAIL("eglCreatePbufferFromClientBuffer");
  }
  GLuint t;
  glGenTextures(1, &t);
  glBindTexture(GL_TEXTURE_2D, t);
  eglBindTexImage(display_, surface_, EGL_BACK_BUFFER);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  return true;
}]=]
    [=[bool ANGLESurfaceManager::CreateAndBindEGLSurface() {
  // Do not create |context_| again, likely due to |Resize|.
  if (context_ == EGL_NO_CONTEXT) {
    // First time from the constructor itself.
    auto count = 0;
    auto result = eglChooseConfig(display_, kEGLConfigurationAttributes,
                                  &config_, 1, &count);
    if (result == EGL_FALSE || count == 0) {
      FAIL("eglChooseConfig");
    }
    context_ = eglCreateContext(display_, config_, EGL_NO_CONTEXT,
                                kEGL3ContextAttributes);
    if (context_ == EGL_NO_CONTEXT) {
      context_ = eglCreateContext(display_, config_, EGL_NO_CONTEXT,
                                  kEGLContextAttributes);
    }
    if (context_ == EGL_NO_CONTEXT) {
      FAIL("eglCreateContext");
    }
  }
  EGLint buffer_attributes[] = {
      EGL_WIDTH,          width_,         EGL_HEIGHT,         height_,
      EGL_TEXTURE_TARGET, EGL_TEXTURE_2D, EGL_TEXTURE_FORMAT, EGL_TEXTURE_RGBA,
      EGL_NONE,
  };
  surface_ = eglCreatePbufferFromClientBuffer(
      display_, EGL_D3D_TEXTURE_2D_SHARE_HANDLE_ANGLE, internal_handle_,
      config_, buffer_attributes);
  if (surface_ == EGL_NO_SURFACE) {
    FAIL("eglCreatePbufferFromClientBuffer");
  }
  MakeCurrent(true);
  if (gl_texture_ != 0) {
    glDeleteTextures(1, &gl_texture_);
    gl_texture_ = 0;
  }
  glGenTextures(1, &gl_texture_);
  glBindTexture(GL_TEXTURE_2D, gl_texture_);
  eglBindTexImage(display_, surface_, EGL_BACK_BUFFER);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glBindTexture(GL_TEXTURE_2D, 0);
  MakeCurrent(false);
  return true;
}]=]
    "angle_surface_manager.cc (CreateAndBindEGLSurface)")

  if(angle_source MATCHES "WaitForSingleObject\\(mutex_|::ReleaseMutex\\(mutex_|::CloseHandle\\(mutex_|eglTerminate\\(display_|->AddRef\\(\\)")
    message(FATAL_ERROR "Simple Live could not safely apply the pinned ANGLE patch")
  endif()

  # --- 3. Patch video_output.h ---
  file(READ "${source_dir}/video_output.h" vo_header)
  _simplelive_replace(vo_header
    "#include <future>\n#include <memory>"
    "#include <atomic>\n#include <chrono>\n#include <future>\n#include <memory>\n#include <mutex>"
    "video_output.h (includes)")
  _simplelive_replace(vo_header
    [=[    // S/W
    if (pixel_buffer_ != nullptr && texture_id_) {
      return pixel_buffer_textures_.at(texture_id_)->width;
    }]=]
    [=[    // S/W
    if (pixel_buffer_ != nullptr && texture_id_) {
      std::lock_guard<std::mutex> lock(store_->mutex);
      auto it = store_->pixel_buffer_textures.find(texture_id_);
      if (it != store_->pixel_buffer_textures.end()) {
        return it->second->width;
      }
    }]=]
    "video_output.h (width)")
  _simplelive_replace(vo_header
    [=[    // S/W
    if (pixel_buffer_ != nullptr && texture_id_) {
      return pixel_buffer_textures_.at(texture_id_)->height;
    }]=]
    [=[    // S/W
    if (pixel_buffer_ != nullptr && texture_id_) {
      std::lock_guard<std::mutex> lock(store_->mutex);
      auto it = store_->pixel_buffer_textures.find(texture_id_);
      if (it != store_->pixel_buffer_textures.end()) {
        return it->second->height;
      }
    }]=]
    "video_output.h (height)")
  _simplelive_replace(vo_header
    [=[  bool destroyed_ = false;

  std::mutex textures_mutex_ = std::mutex();

  std::unordered_map<int64_t, std::unique_ptr<flutter::TextureVariant>>
      texture_variants_ = {};

  // H/W rendering.

  std::unique_ptr<ANGLESurfaceManager> surface_manager_ = nullptr;
  std::unordered_map<int64_t,
                     std::unique_ptr<FlutterDesktopGpuSurfaceDescriptor>>
      textures_ = {};

  // S/W rendering.

  std::unique_ptr<uint8_t[]> pixel_buffer_ = nullptr;
  std::unordered_map<int64_t, std::unique_ptr<FlutterDesktopPixelBuffer>>
      pixel_buffer_textures_ = {};]=]
    [=[  struct TextureStore {
    std::mutex mutex;
    std::atomic<bool> destroyed{false};
    std::atomic<int64_t> active_texture_id{0};
    std::unordered_map<int64_t, std::unique_ptr<flutter::TextureVariant>>
        variants;
    std::unordered_map<int64_t,
                       std::unique_ptr<FlutterDesktopGpuSurfaceDescriptor>>
        gpu_textures;
    std::unordered_map<int64_t, std::unique_ptr<FlutterDesktopPixelBuffer>>
        pixel_buffer_textures;
  };

  std::atomic<bool> destroyed_{false};
  std::shared_ptr<TextureStore> store_ = std::make_shared<TextureStore>();

  // H/W rendering.

  std::unique_ptr<ANGLESurfaceManager> surface_manager_ = nullptr;

  // S/W rendering.

  std::unique_ptr<uint8_t[]> pixel_buffer_ = nullptr;]=]
    "video_output.h (TextureStore)")

  # --- 4. Patch video_output.cc ---
  file(READ "${source_dir}/video_output.cc" vo_source)
  _simplelive_replace(vo_source
    [=[    if (configuration.enable_hardware_acceleration) {
      try {
        // OpenGL context needs to be set before |mpv_render_context_create|.
        surface_manager_ = std::make_unique<ANGLESurfaceManager>(
            static_cast<int32_t>(width_.value_or(1)),
            static_cast<int32_t>(height_.value_or(1)));
        surface_manager_->MakeCurrent(true);
        Resize(width_.value_or(1), height_.value_or(1));
        mpv_opengl_init_params gl_init_params{
            [](auto, auto name) {
              return reinterpret_cast<void*>(eglGetProcAddress(name));
            },
            nullptr,
        };
        mpv_render_param params[] = {
            {MPV_RENDER_PARAM_API_TYPE, MPV_RENDER_API_TYPE_OPENGL},
            {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl_init_params},
            {MPV_RENDER_PARAM_INVALID, nullptr},
        };
        // Create render context.
        if (mpv_render_context_create(&render_context_, handle_, params) == 0) {
          mpv_render_context_set_update_callback(
              render_context_,
              [](void* context) {
                // Notify Flutter that a new frame is available. The actual
                // rendering will take place in the |Render| method, which will
                // be called by Flutter on the render thread.
                auto that = reinterpret_cast<VideoOutput*>(context);
                that->NotifyRender();
              },
              reinterpret_cast<void*>(this));
          // Set flag to true, indicating that H/W rendering is supported.
          is_hardware_acceleration_enabled = true;
          std::cout << "media_kit: VideoOutput: Using H/W rendering."
                    << std::endl;
        }
      } catch (...) {
        // Do nothing.
        // Likely received an |std::runtime_error| from |ANGLESurfaceManager|,
        // which indicates that H/W rendering is not supported.
      }
    }
    if (!is_hardware_acceleration_enabled) {
      std::cout << "media_kit: VideoOutput: Using S/W rendering." << std::endl;]=]
    [=[    if (configuration.enable_hardware_acceleration) {
      try {
        // OpenGL context needs to be set before |mpv_render_context_create|.
        surface_manager_ = std::make_unique<ANGLESurfaceManager>(
            static_cast<int32_t>(width_.value_or(1)),
            static_cast<int32_t>(height_.value_or(1)));
        Resize(width_.value_or(1), height_.value_or(1));
        if (surface_manager_->is_d3d11()) {
          mpv_set_property_string(handle_, "gpu-hwdec-interop", "d3d11-egl");
        }
        surface_manager_->MakeCurrent(true);
        mpv_opengl_init_params gl_init_params{
            [](auto, auto name) {
              return reinterpret_cast<void*>(eglGetProcAddress(name));
            },
            nullptr,
        };
        mpv_render_param params[] = {
            {MPV_RENDER_PARAM_API_TYPE, MPV_RENDER_API_TYPE_OPENGL},
            {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl_init_params},
            {MPV_RENDER_PARAM_INVALID, nullptr},
        };
        // Create render context.
        if (mpv_render_context_create(&render_context_, handle_, params) == 0) {
          mpv_render_context_set_update_callback(
              render_context_,
              [](void* context) {
                // Notify Flutter that a new frame is available. The actual
                // rendering will take place in the |Render| method, which will
                // be called by Flutter on the render thread.
                auto that = reinterpret_cast<VideoOutput*>(context);
                that->NotifyRender();
              },
              reinterpret_cast<void*>(this));
          // Set flag to true, indicating that H/W rendering is supported.
          is_hardware_acceleration_enabled = true;
          std::cout << "media_kit: VideoOutput: Using H/W rendering."
                    << std::endl;
        }
        surface_manager_->MakeCurrent(false);
      } catch (...) {
        if (surface_manager_ != nullptr) {
          surface_manager_->MakeCurrent(false);
          surface_manager_.reset(nullptr);
        }
      }
    }
    if (!is_hardware_acceleration_enabled) {
      if (surface_manager_ != nullptr) {
        surface_manager_->MakeCurrent(false);
        surface_manager_.reset(nullptr);
      }
      std::cout << "media_kit: VideoOutput: Using S/W rendering." << std::endl;]=]
    "video_output.cc (constructor)")

  _simplelive_replace(vo_source
    [=[VideoOutput::~VideoOutput() {
  destroyed_ = true;
  auto promise = std::promise<void>();
  if (texture_id_) {
    registrar_->texture_registrar()->UnregisterTexture(
        texture_id_, [&, texture_id = texture_id_]() {
          // Add one more task into the thread pool queue & exit the destructor
          // only when it gets executed. This will ensure that all the tasks
          // posted to the thread pool i.e. render or resize before this are
          // executed (and won't reference the dead object anymore), most
          // notably |CheckAndResize| & |Render|.
          auto future = thread_pool_ref_->Post([&, id = texture_id]() {
            std::cout << "media_kit: VideoOutput: Free Texture: " << id
                      << std::endl;
            std::cout << "VideoOutput::~VideoOutput: "
                      << reinterpret_cast<int64_t>(handle_) << std::endl;
            std::lock_guard<std::mutex> lock(textures_mutex_);
            texture_variants_.clear();
            // H/W
            textures_.clear();
            // S/W
            pixel_buffer_textures_.clear();
            // Free (call destructor) |ANGLESurfaceManager| through the thread
            // pool. This will ensure synchronized EGL or ANGLE usage & won't
            // conflict with |Render| or |CheckAndResize| of other
            // |VideoOutput|s.
            surface_manager_.reset(nullptr);
            promise.set_value();
          });
        });
  }

  promise.get_future().wait();
  texture_id_ = 0;

  thread_pool_ref_->Post([render_context = render_context_]() {
    mpv_render_context_free(render_context);
  });
}]=]
    [=[VideoOutput::~VideoOutput() {
  destroyed_.store(true);
  {
    std::lock_guard<std::mutex> lock(store_->mutex);
    store_->destroyed.store(true);
    store_->active_texture_id.store(0);
  }
  if (render_context_ != nullptr) {
    mpv_render_context_set_update_callback(render_context_, nullptr, nullptr);
  }
  bool unregistered = (texture_id_ == 0);
  if (texture_id_) {
    auto promise = std::make_shared<std::promise<void>>();
    auto future = promise->get_future();
    registrar_->texture_registrar()->UnregisterTexture(
        texture_id_, [store = store_, id = texture_id_, promise]() {
          std::cout << "media_kit: VideoOutput: Free Texture: " << id
                    << std::endl;
          {
            std::lock_guard<std::mutex> lock(store->mutex);
            store->variants.erase(id);
            store->gpu_textures.erase(id);
            store->pixel_buffer_textures.erase(id);
          }
          promise->set_value();
        });
    unregistered =
        (future.wait_for(std::chrono::seconds(2)) == std::future_status::ready);
    texture_id_ = 0;
  }
  try {
    auto cleanup = thread_pool_ref_->Post([this, unregistered]() {
      if (unregistered) {
        std::lock_guard<std::mutex> lock(store_->mutex);
        store_->variants.clear();
        store_->gpu_textures.clear();
        store_->pixel_buffer_textures.clear();
      }
      if (render_context_ != nullptr) {
        if (surface_manager_ != nullptr) {
          surface_manager_->MakeCurrent(true);
        }
        mpv_render_context_free(render_context_);
        render_context_ = nullptr;
        if (surface_manager_ != nullptr) {
          surface_manager_->MakeCurrent(false);
        }
      }
      surface_manager_.reset(nullptr);
    });
    cleanup.wait();
  } catch (...) {
  }
}]=]
    "video_output.cc (destructor)")

  _simplelive_replace(vo_source
    [=[void VideoOutput::NotifyRender() {
  if (destroyed_) {
    return;
  }
  thread_pool_ref_->Post(std::bind(&VideoOutput::CheckAndResize, this));
  thread_pool_ref_->Post(std::bind(&VideoOutput::Render, this));
}

void VideoOutput::Render() {
  if (texture_id_) {]=]
    [=[void VideoOutput::NotifyRender() {
  if (destroyed_.load()) {
    return;
  }
  try {
    thread_pool_ref_->Post(std::bind(&VideoOutput::CheckAndResize, this));
    thread_pool_ref_->Post(std::bind(&VideoOutput::Render, this));
  } catch (...) {
  }
}

void VideoOutput::Render() {
  if (destroyed_.load()) {
    return;
  }
  if (texture_id_) {]=]
    "video_output.cc (NotifyRender & Render)")

  _simplelive_replace(vo_source
    [=[    // S/W
    if (pixel_buffer_ != nullptr) {
      int32_t size[]{
          static_cast<int32_t>(pixel_buffer_textures_.at(texture_id_)->width),
          static_cast<int32_t>(pixel_buffer_textures_.at(texture_id_)->height),
      };]=]
    [=[    // S/W
    if (pixel_buffer_ != nullptr) {
      int32_t sw_w = 0, sw_h = 0;
      {
        std::lock_guard<std::mutex> lock(store_->mutex);
        auto it = store_->pixel_buffer_textures.find(texture_id_);
        if (it == store_->pixel_buffer_textures.end()) {
          return;
        }
        sw_w = static_cast<int32_t>(it->second->width);
        sw_h = static_cast<int32_t>(it->second->height);
      }
      int32_t size[]{sw_w, sw_h};]=]
    "video_output.cc (Render S/W)")

  _simplelive_replace(vo_source
    [=[void VideoOutput::SetSize(std::optional<int64_t> width,
                          std::optional<int64_t> height) {
  thread_pool_ref_->Post([&, width, height]() {]=]
    [=[void VideoOutput::SetSize(std::optional<int64_t> width,
                          std::optional<int64_t> height) {
  if (destroyed_.load()) {
    return;
  }
  try {
    thread_pool_ref_->Post([&, width, height]() {
      if (destroyed_.load()) {
        return;
      }]=]
    "video_output.cc (SetSize top)")

  _simplelive_replace(vo_source
    [=[    } else {
      height_ = std::nullopt;
    }
  });
}

void VideoOutput::CheckAndResize() {]=]
    [=[    } else {
      height_ = std::nullopt;
    }
    });
  } catch (...) {
  }
}

void VideoOutput::CheckAndResize() {
  if (destroyed_.load()) {
    return;
  }]=]
    "video_output.cc (SetSize end & CheckAndResize)")

  _simplelive_replace(vo_source
    [=[  if (pixel_buffer_ != nullptr) {
    current_width = pixel_buffer_textures_.at(texture_id_)->width;
    current_height = pixel_buffer_textures_.at(texture_id_)->height;
  }]=]
    [=[  if (pixel_buffer_ != nullptr) {
    std::lock_guard<std::mutex> lock(store_->mutex);
    auto it = store_->pixel_buffer_textures.find(texture_id_);
    if (it != store_->pixel_buffer_textures.end()) {
      current_width = it->second->width;
      current_height = it->second->height;
    }
  }]=]
    "video_output.cc (CheckAndResize S/W)")

  _simplelive_replace(vo_source
    [=[void VideoOutput::Resize(int64_t required_width, int64_t required_height) {
  std::cout << required_width << " " << required_height << std::endl;
  // Unregister previously registered texture & delete underlying objects.
  if (texture_id_) {
    registrar_->texture_registrar()->UnregisterTexture(
        texture_id_, [&, id = texture_id_]() {
          if (id) {
            std::cout << "media_kit: VideoOutput: Free Texture: " << id
                      << std::endl;
            std::lock_guard<std::mutex> lock(textures_mutex_);
            if (destroyed_) {
              return;
            }
            if (texture_variants_.find(id) != texture_variants_.end()) {
              texture_variants_.erase(id);
            }
            // H/W
            if (textures_.find(id) != textures_.end()) {
              textures_.erase(id);
            }
            // S/W
            if (pixel_buffer_textures_.find(id) !=
                pixel_buffer_textures_.end()) {
              pixel_buffer_textures_.erase(id);
            }
          }
        });
    texture_id_ = 0;
  }
  // H/W
  if (surface_manager_ != nullptr) {
    // Destroy internal ID3D11Texture2D & EGLSurface & create new with updated
    // dimensions while preserving previous EGLDisplay & EGLContext.
    surface_manager_->SetSize(static_cast<int32_t>(required_width),
                              static_cast<int32_t>(required_height));
    auto texture = std::make_unique<FlutterDesktopGpuSurfaceDescriptor>();
    texture->struct_size = sizeof(FlutterDesktopGpuSurfaceDescriptor);
    texture->handle = surface_manager_->handle();
    texture->width = texture->visible_width = surface_manager_->width();
    texture->height = texture->visible_height = surface_manager_->height();
    texture->release_context = nullptr;
    texture->release_callback = [](void*) {};
    texture->format = kFlutterDesktopPixelFormatBGRA8888;
    auto texture_variant =
        std::make_unique<flutter::TextureVariant>(flutter::GpuSurfaceTexture(
            kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle, [&](auto, auto) {
              std::lock_guard<std::mutex> lock(textures_mutex_);
              if (texture_id_) {
                surface_manager_->Read();
                return textures_.at(texture_id_).get();
              } else {
                return (FlutterDesktopGpuSurfaceDescriptor*)nullptr;
              }
            }));
    // Register new texture.
    texture_id_ =
        registrar_->texture_registrar()->RegisterTexture(texture_variant.get());
    std::cout << "media_kit: VideoOutput: Create Texture: " << texture_id_
              << std::endl;
    std::lock_guard<std::mutex> lock(textures_mutex_);
    textures_.emplace(std::make_pair(texture_id_, std::move(texture)));
    texture_variants_.emplace(
        std::make_pair(texture_id_, std::move(texture_variant)));
    // Notify public texture update callback.
    texture_update_callback_(texture_id_, required_width, required_height);
  }
  // S/W
  if (pixel_buffer_ != nullptr) {
    auto pixel_buffer_texture = std::make_unique<FlutterDesktopPixelBuffer>();
    pixel_buffer_texture->buffer = pixel_buffer_.get();
    pixel_buffer_texture->width = required_width;
    pixel_buffer_texture->height = required_height;
    pixel_buffer_texture->release_context = nullptr;
    pixel_buffer_texture->release_callback = [](void*) {};
    auto texture_variant = std::make_unique<flutter::TextureVariant>(
        flutter::PixelBufferTexture([&](auto, auto) {
          std::lock_guard<std::mutex> lock(textures_mutex_);
          if (texture_id_) {
            return pixel_buffer_textures_.at(texture_id_).get();
          } else {
            return (FlutterDesktopPixelBuffer*)nullptr;
          }
        }));
    // Register new texture.
    texture_id_ =
        registrar_->texture_registrar()->RegisterTexture(texture_variant.get());
    std::cout << "media_kit: VideoOutput: Create Texture: " << texture_id_
              << std::endl;
    std::lock_guard<std::mutex> lock(textures_mutex_);
    pixel_buffer_textures_.emplace(
        std::make_pair(texture_id_, std::move(pixel_buffer_texture)));
    texture_variants_.emplace(
        std::make_pair(texture_id_, std::move(texture_variant)));
    // Notify public texture update callback.
    texture_update_callback_(texture_id_, required_width, required_height);
  }
}]=]
    [=[void VideoOutput::Resize(int64_t required_width, int64_t required_height) {
  if (destroyed_.load()) {
    return;
  }
  std::cout << required_width << " " << required_height << std::endl;
  // Unregister previously registered texture & delete underlying objects.
  if (texture_id_) {
    store_->active_texture_id.store(0);
    registrar_->texture_registrar()->UnregisterTexture(
        texture_id_, [store = store_, id = texture_id_]() {
          if (id) {
            std::cout << "media_kit: VideoOutput: Free Texture: " << id
                      << std::endl;
            std::lock_guard<std::mutex> lock(store->mutex);
            store->variants.erase(id);
            store->gpu_textures.erase(id);
            store->pixel_buffer_textures.erase(id);
          }
        });
    texture_id_ = 0;
  }
  // H/W
  if (surface_manager_ != nullptr) {
    // Destroy internal ID3D11Texture2D & EGLSurface & create new with updated
    // dimensions while preserving previous EGLDisplay & EGLContext.
    surface_manager_->SetSize(static_cast<int32_t>(required_width),
                              static_cast<int32_t>(required_height));
    auto texture = std::make_unique<FlutterDesktopGpuSurfaceDescriptor>();
    texture->struct_size = sizeof(FlutterDesktopGpuSurfaceDescriptor);
    texture->handle = surface_manager_->handle();
    texture->width = texture->visible_width = surface_manager_->width();
    texture->height = texture->visible_height = surface_manager_->height();
    texture->release_context = nullptr;
    texture->release_callback = [](void*) {};
    texture->format = kFlutterDesktopPixelFormatBGRA8888;
    auto store = store_;
    auto texture_variant =
        std::make_unique<flutter::TextureVariant>(flutter::GpuSurfaceTexture(
            kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle,
            [this, store](auto, auto) -> const FlutterDesktopGpuSurfaceDescriptor* {
              std::lock_guard<std::mutex> lock(store->mutex);
              if (store->destroyed.load()) {
                return nullptr;
              }
              const int64_t active_id = store->active_texture_id.load();
              if (!active_id || surface_manager_ == nullptr) {
                return nullptr;
              }
              auto it = store->gpu_textures.find(active_id);
              if (it == store->gpu_textures.end()) {
                return nullptr;
              }
              surface_manager_->Read();
              return it->second.get();
            }));
    // Register new texture.
    texture_id_ =
        registrar_->texture_registrar()->RegisterTexture(texture_variant.get());
    std::cout << "media_kit: VideoOutput: Create Texture: " << texture_id_
              << std::endl;
    {
      std::lock_guard<std::mutex> lock(store_->mutex);
      store_->gpu_textures.emplace(std::make_pair(texture_id_, std::move(texture)));
      store_->variants.emplace(
          std::make_pair(texture_id_, std::move(texture_variant)));
      store_->active_texture_id.store(texture_id_);
    }
    // Notify public texture update callback.
    texture_update_callback_(texture_id_, required_width, required_height);
  }
  // S/W
  if (pixel_buffer_ != nullptr) {
    auto pixel_buffer_texture = std::make_unique<FlutterDesktopPixelBuffer>();
    pixel_buffer_texture->buffer = pixel_buffer_.get();
    pixel_buffer_texture->width = required_width;
    pixel_buffer_texture->height = required_height;
    pixel_buffer_texture->release_context = nullptr;
    pixel_buffer_texture->release_callback = [](void*) {};
    auto store = store_;
    auto texture_variant = std::make_unique<flutter::TextureVariant>(
        flutter::PixelBufferTexture(
            [store](auto, auto) -> const FlutterDesktopPixelBuffer* {
              std::lock_guard<std::mutex> lock(store->mutex);
              if (store->destroyed.load()) {
                return nullptr;
              }
              const int64_t active_id = store->active_texture_id.load();
              if (!active_id) {
                return nullptr;
              }
              auto it = store->pixel_buffer_textures.find(active_id);
              if (it == store->pixel_buffer_textures.end()) {
                return nullptr;
              }
              return it->second.get();
            }));
    // Register new texture.
    texture_id_ =
        registrar_->texture_registrar()->RegisterTexture(texture_variant.get());
    std::cout << "media_kit: VideoOutput: Create Texture: " << texture_id_
              << std::endl;
    {
      std::lock_guard<std::mutex> lock(store_->mutex);
      store_->pixel_buffer_textures.emplace(
          std::make_pair(texture_id_, std::move(pixel_buffer_texture)));
      store_->variants.emplace(
          std::make_pair(texture_id_, std::move(texture_variant)));
      store_->active_texture_id.store(texture_id_);
    }
    // Notify public texture update callback.
    texture_update_callback_(texture_id_, required_width, required_height);
  }
}]=]
    "video_output.cc (Resize)")

  # --- 5. Patch video_output_manager.h & .cc ---
  file(READ "${source_dir}/video_output_manager.h" vom_header)
  _simplelive_replace(vom_header
    "  // Destroys the |VideoOutput| with given handle.\n  void Dispose(int64_t handle);"
    "  // Destroys the |VideoOutput| with given handle.\n  void Dispose(int64_t handle, std::function<void()> on_done = nullptr);"
    "video_output_manager.h (Dispose)")

  file(READ "${source_dir}/video_output_manager.cc" vom_source)
  _simplelive_replace(vom_source
    [=[void VideoOutputManager::Dispose(int64_t handle) {
  std::thread([=]() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (video_outputs_.find(handle) != video_outputs_.end()) {
      video_outputs_.erase(handle);
    }
  }).detach();
}]=]
    [=[void VideoOutputManager::Dispose(int64_t handle,
                                 std::function<void()> on_done) {
  std::thread([this, handle, on_done = std::move(on_done)]() {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      if (video_outputs_.find(handle) != video_outputs_.end()) {
        video_outputs_.erase(handle);
      }
    }
    if (on_done) {
      on_done();
    }
  }).detach();
}]=]
    "video_output_manager.cc (Dispose)")

  # --- 6. Patch media_kit_video_plugin.cc ---
  file(READ "${source_dir}/media_kit_video_plugin.cc" plugin_source)
  _simplelive_replace(plugin_source
    [=[  } else if (method_call.method_name().compare("VideoOutputManager.Dispose") ==
             0) {
    auto arguments = std::get<flutter::EncodableMap>(*method_call.arguments());
    auto handle =
        std::get<std::string>(arguments[flutter::EncodableValue("handle")]);
    auto handle_value = static_cast<int64_t>(std::stoll(handle.c_str()));
    video_output_manager_->Dispose(handle_value);
    result->Success(flutter::EncodableValue(std::monostate{}));]=]
    [=[  } else if (method_call.method_name().compare("VideoOutputManager.Dispose") ==
             0) {
    auto arguments = std::get<flutter::EncodableMap>(*method_call.arguments());
    auto handle =
        std::get<std::string>(arguments[flutter::EncodableValue("handle")]);
    auto handle_value = static_cast<int64_t>(std::stoll(handle.c_str()));
    auto shared_result =
        std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(
            std::move(result));
    video_output_manager_->Dispose(handle_value, [shared_result]() {
      if (MediaKitVideoPlugin::instance_ != nullptr) {
        MediaKitVideoPlugin::instance_->RunOnMainThread([shared_result]() {
          shared_result->Success(flutter::EncodableValue(std::monostate{}));
        });
      }
    });]=]
    "media_kit_video_plugin.cc (Dispose completion)")

  file(CONFIGURE OUTPUT "${overlay}/angle_surface_manager.h" CONTENT "${angle_header}" @ONLY)
  file(CONFIGURE OUTPUT "${overlay}/angle_surface_manager.cc" CONTENT "${angle_source}" @ONLY)
  file(CONFIGURE OUTPUT "${overlay}/video_output.h" CONTENT "${vo_header}" @ONLY)
  file(CONFIGURE OUTPUT "${overlay}/video_output.cc" CONTENT "${vo_source}" @ONLY)
  file(CONFIGURE OUTPUT "${overlay}/video_output_manager.h" CONTENT "${vom_header}" @ONLY)
  file(CONFIGURE OUTPUT "${overlay}/video_output_manager.cc" CONTENT "${vom_source}" @ONLY)
  file(CONFIGURE OUTPUT "${overlay}/media_kit_video_plugin.cc" CONTENT "${plugin_source}" @ONLY)

  set(patched_sources)
  foreach(source IN LISTS sources)
    if(EXISTS "${source_dir}/${source}")
      list(APPEND patched_sources "${overlay}/${source}")
    else()
      list(APPEND patched_sources "${source}")
    endif()
  endforeach()
  set_property(TARGET media_kit_video_plugin PROPERTY SOURCES "${patched_sources}")
  target_include_directories(media_kit_video_plugin BEFORE PRIVATE "${overlay}" "${_mpv_inc}")
  target_include_directories(media_kit_video_plugin PRIVATE "${source_dir}")
endfunction()
