// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#ifndef VIDEO_OUTPUT_MANAGER_H_
#define VIDEO_OUTPUT_MANAGER_H_

#include <flutter/plugin_registrar_windows.h>

#include <unordered_map>

#include "thread_pool.h"
#include "video_output.h"

// Creates & disposes |VideoOutput| instances for video embedding.
//
// The methods in this class are thread-safe & run on separate worker thread so
// that they don't block Flutter's UI thread while platform channels are being
// invoked.
class VideoOutputManager {
 public:
  VideoOutputManager(flutter::PluginRegistrarWindows* registrar);

  // Creates a new |VideoOutput| instance. It's texture ID may be used to render
  // the video. The changes in it's texture ID & video dimensions will be
  // notified via the |texture_update_callback|.
  void Create(
      int64_t handle,
      VideoOutputConfiguration configuration,
      std::function<void(int64_t, int64_t, int64_t)> texture_update_callback);

  // Sets the required video output size.
  // This forces |VideoOutput| to resize the internal OpenGL surface / D3D
  // texture.
  void SetSize(int64_t handle,
               std::optional<int64_t> width,
               std::optional<int64_t> height);

  // Destroys the |VideoOutput| with given handle.
  void Dispose(int64_t handle);

  ~VideoOutputManager();

 private:
  std::mutex mutex_ = std::mutex();
  // All the operations involving ANGLE or EGL or libmpv must be performed on
  // same single thread to prevent any race conditions or invalid ANGLE usage.
  // Not doing so results in access violations & crashes.
  //
  // Technically, the correct place to do all the video rendering (& thus
  // resize) etc. is on Flutter's render thread itself (exposed as callback in
  // |flutter::GpuSurfaceTexture| & |flutter::PixelBufferTexture|). However,
  // this slows down the UI too much. So, a good idea seemed to have a separate
  // worker thread which queues all the rendering related jobs & performs them
  // orderly. |ThreadPool| is exactly that.
  //
  // All of the following tasks involve ANGLE or OpenGL context etc. etc.
  // Following operations are performed through the |ThreadPool|:
  //
  // * Rendering of video frame i.e. |mpv_render_context_render| (also involves
  //   |eglMakeCurrent| etc.) after being notified by
  //   |mpv_render_context_set_update_callback|.
  // * Creation / Disposal of new |VideoOutput|.
  //     * For creation, |mpv_render_context_create| & instantiation of a new
  //       |ANGLESurfaceManager| is done through |ThreadPool| (in |VideoOutput|
  //       constructor).
  //     * For disposal, |ThreadPool| ensures that all the pending |Render| or
  //       |Resize| tasks are completed before freeing the |ANGLESurfaceManager|
  //       & |mpv_render_context| etc.
  // * Resizing of |ANGLESurfaceManager| & creation of newly sized Flutter
  //   textures (|flutter::GpuSurfaceTexture| & |flutter::PixelBufferTexture|).
  //
  // Creating a |ThreadPool| with maximum number of worker threads as 1, ensures
  // that all the posted tasks are performed on a single thread orderly. This
  // also makes usage of any |std::mutex| unnecessary (for the good).
  std::unique_ptr<ThreadPool> thread_pool_ = std::make_unique<ThreadPool>(1);
  flutter::PluginRegistrarWindows* registrar_ = nullptr;
  std::unordered_map<int64_t, std::unique_ptr<VideoOutput>> video_outputs_ = {};
};

#endif  // VIDEO_OUTPUT_MANAGER_H_
