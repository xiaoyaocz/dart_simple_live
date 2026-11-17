#pragma once

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include <atomic>
#include <memory>

#include "../in_app_webview/in_app_webview.h"
#include "graphics_context.h"
#include "texture_bridge.h"

namespace flutter_inappwebview_plugin
{
  class CustomPlatformView {
  public:
    static inline const wchar_t* CLASS_NAME = L"CustomPlatformView";

    std::shared_ptr<flutter_inappwebview_plugin::InAppWebView> view;

    CustomPlatformView(flutter::BinaryMessenger* messenger,
      flutter::TextureRegistrar* texture_registrar,
      GraphicsContext* graphics_context,
      HWND hwnd,
      std::shared_ptr<flutter_inappwebview_plugin::InAppWebView> webView);
    ~CustomPlatformView();

    TextureBridge* texture_bridge() const { return texture_bridge_.get(); }

    int64_t texture_id() const { return texture_id_; }

    void UnregisterMethodCallHandler() const;
  private:
    HWND hwnd_;
    std::unique_ptr<flutter::TextureVariant> flutter_texture_;
    std::unique_ptr<TextureBridge> texture_bridge_;
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
    std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
      event_channel_;
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;

    flutter::TextureRegistrar* texture_registrar_;
    int64_t texture_id_;
    std::shared_ptr<std::atomic<bool>> alive_ = std::make_shared<std::atomic<bool>>(true);

    void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    void RegisterEventHandlers();

    template <typename T>
    void EmitEvent(const T& value)
    {
      if (*alive_ && event_sink_ && view && view->plugin && view->plugin->isEngineAvailable()) {
        event_sink_->Success(value);
      }
    }
  };
}