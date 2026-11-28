#include "texture_bridge.h"
#include "capture_event_handler.h"

#include <windows.foundation.h>

#include <algorithm>
#include <atomic>
#include <cassert>
#include <iostream>

#include "util/direct3d11.interop.h"

namespace flutter_inappwebview_plugin
{
  const int kNumBuffers = 1;

  TextureBridge::TextureBridge(GraphicsContext* graphics_context,
    ABI::Windows::UI::Composition::IVisual* visual)
    : graphics_context_(graphics_context)
  {
    capture_item_ =
      graphics_context_->CreateGraphicsCaptureItemFromVisual(visual);
    assert(capture_item_);

    capture_item_->add_Closed(
      MakeCaptureEventHandler<ABI::Windows::Foundation::ITypedEventHandler<
      ABI::Windows::Graphics::Capture::GraphicsCaptureItem*,
      IInspectable*>>(
        callback_lifetime_, [](ABI::Windows::Graphics::Capture::IGraphicsCaptureItem* item,
          IInspectable* args) -> HRESULT
        {
          std::cerr << "Capture item was closed." << std::endl;
          return S_OK;
        })
      .Get(),
          &on_closed_token_);
  }

  TextureBridge::~TextureBridge()
  {
    callback_lifetime_.reset();
    const std::lock_guard<std::mutex> lock(mutex_);
    StopInternal();
    if (capture_item_) {
      capture_item_->remove_Closed(on_closed_token_);
    }
  }

  bool TextureBridge::Start()
  {
    const std::lock_guard<std::mutex> lock(mutex_);
    if (is_running_ || !capture_item_) {
      return false;
    }

    ABI::Windows::Graphics::SizeInt32 size{};
    if (FAILED(capture_item_->get_Size(&size))) {
      return false;
    }
    if (size.Width <= 0) size.Width = 1;
    if (size.Height <= 0) size.Height = 1;

    frame_pool_ = graphics_context_->CreateCaptureFramePool(
      graphics_context_->device(),
      static_cast<ABI::Windows::Graphics::DirectX::DirectXPixelFormat>(
        kPixelFormat),
      kNumBuffers, size);
    if (!frame_pool_) {
      return false;
    }

    frame_callback_lifetime_ = std::make_shared<int>(0);
    auto registration_hr = frame_pool_->add_FrameArrived(
      MakeCaptureEventHandler<ABI::Windows::Foundation::ITypedEventHandler<
      ABI::Windows::Graphics::Capture::Direct3D11CaptureFramePool*,
      IInspectable*>>(
        frame_callback_lifetime_, [this](ABI::Windows::Graphics::Capture::IDirect3D11CaptureFramePool*
          pool,
          IInspectable* args) -> HRESULT
        {
          OnFrameArrived();
          return S_OK;
        })
      .Get(),
          &on_frame_arrived_token_);

    if (FAILED(registration_hr)) {
      StopInternal();
      return false;
    }

    if (FAILED(frame_pool_->CreateCaptureSession(capture_item_.get(),
      capture_session_.put()))) {
      std::cerr << "Creating capture session failed." << std::endl;
      StopInternal();
      return false;
    }

    if (SUCCEEDED(capture_session_->StartCapture())) {
      is_running_ = true;
      return true;
    }

    StopInternal();
    return false;
  }

  void TextureBridge::Stop()
  {
    const std::lock_guard<std::mutex> lock(mutex_);
    StopInternal();
  }

  void TextureBridge::StopInternal()
  {
    // A failed Start can already own a registered handler, pool or session.
    // Cleanup must not depend on StartCapture having succeeded.
    is_running_ = false;
    frame_callback_lifetime_.reset();
    if (frame_pool_ && on_frame_arrived_token_.value != 0) {
      frame_pool_->remove_FrameArrived(on_frame_arrived_token_);
      on_frame_arrived_token_.value = 0;
    }
    if (capture_session_) {
      auto closable =
        capture_session_.try_as<ABI::Windows::Foundation::IClosable>();
      if (closable) {
        closable->Close();
      }
      capture_session_ = nullptr;
    }
    if (frame_pool_) {
      auto closable = frame_pool_.try_as<ABI::Windows::Foundation::IClosable>();
      if (closable) closable->Close();
      frame_pool_ = nullptr;
    }
    last_frame_ = nullptr;
    frame_pending_ = false;
    needs_update_ = false;
    last_frame_timestamp_.reset();
  }

  void TextureBridge::OnFrameArrived()
  {
    FrameAvailableCallback callback;
    {
      const std::lock_guard<std::mutex> lock(mutex_);
      if (!is_running_ || !frame_pool_) {
        return;
      }

      bool has_frame = false;

      winrt::com_ptr<ABI::Windows::Graphics::Capture::IDirect3D11CaptureFrame>
        frame;
      auto hr = frame_pool_->TryGetNextFrame(frame.put());
      if (SUCCEEDED(hr) && frame) {
        winrt::com_ptr<
          ABI::Windows::Graphics::DirectX::Direct3D11::IDirect3DSurface>
          frame_surface;

        if (SUCCEEDED(frame->get_Surface(frame_surface.put()))) {
          auto texture =
            TryGetDXGIInterfaceFromObject<ID3D11Texture2D>(frame_surface);
          if (texture && !ShouldDropFrame()) {
            last_frame_ = std::move(texture);
            frame_pending_ = true;
            has_frame = true;
          }
        }
      }

      if (needs_update_ && capture_item_) {
        ABI::Windows::Graphics::SizeInt32 size{};
        if (SUCCEEDED(capture_item_->get_Size(&size)) && size.Width > 0 && size.Height > 0) {
          frame_pool_->Recreate(
            graphics_context_->device(),
            static_cast<ABI::Windows::Graphics::DirectX::DirectXPixelFormat>(
              kPixelFormat),
            kNumBuffers, size);
        }
        needs_update_ = false;
      }

      if (has_frame && frame_available_) {
        callback = frame_available_;
      }
    }
    if (callback) {
      callback();
    }
  }

  bool TextureBridge::ShouldDropFrame()
  {
    if (!frame_duration_.has_value()) {
      return false;
    }
    auto now = std::chrono::high_resolution_clock::now();

    bool should_drop_frame = false;
    if (last_frame_timestamp_.has_value()) {
      auto diff = std::chrono::duration_cast<std::chrono::milliseconds>(
        now - last_frame_timestamp_.value());
      should_drop_frame = diff < frame_duration_.value();
    }

    if (!should_drop_frame) {
      last_frame_timestamp_ = now;
    }
    return should_drop_frame;
  }

  void TextureBridge::NotifySurfaceSizeChanged()
  {
    const std::lock_guard<std::mutex> lock(mutex_);
    needs_update_ = true;
  }

  void TextureBridge::SetFpsLimit(std::optional<int> max_fps)
  {
    const std::lock_guard<std::mutex> lock(mutex_);
    auto value = max_fps.value_or(0);
    if (value != 0) {
      frame_duration_ = FrameDuration(1000.0 / value);
    }
    else {
      frame_duration_.reset();
      last_frame_timestamp_.reset();
    }
  }
}
