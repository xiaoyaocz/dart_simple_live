#include "../utils/log.h"
#include "custom_platform_view.h"

#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_result_functions.h>

#ifdef HAVE_FLUTTER_D3D_TEXTURE
#include "texture_bridge_gpu.h"
#else
#include "texture_bridge_fallback.h"
#endif

namespace flutter_inappwebview_plugin
{
  constexpr auto kErrorInvalidArgs = "invalidArguments";

  constexpr auto kMethodSetSize = "setSize";
  constexpr auto kMethodSetPosition = "setPosition";
  constexpr auto kMethodSetCursorPos = "setCursorPos";
  constexpr auto kMethodSetPointerUpdate = "setPointerUpdate";
  constexpr auto kMethodSetPointerButton = "setPointerButton";
  constexpr auto kMethodSetScrollDelta = "setScrollDelta";
  constexpr auto kMethodSetFpsLimit = "setFpsLimit";

  constexpr auto kEventType = "type";
  constexpr auto kEventValue = "value";

  static const std::optional<std::pair<double, double>> GetPointFromArgs(
    const flutter::EncodableValue* args)
  {
    const flutter::EncodableList* list =
      std::get_if<flutter::EncodableList>(args);
    if (!list || list->size() != 2) {
      return std::nullopt;
    }
    const auto x = std::get_if<double>(&(*list)[0]);
    const auto y = std::get_if<double>(&(*list)[1]);
    if (!x || !y) {
      return std::nullopt;
    }
    return std::make_pair(*x, *y);
  }

  static const std::optional<std::tuple<double, double, double>>
    GetPointAndScaleFactorFromArgs(const flutter::EncodableValue* args)
  {
    const flutter::EncodableList* list =
      std::get_if<flutter::EncodableList>(args);
    if (!list || list->size() != 3) {
      return std::nullopt;
    }
    const auto x = std::get_if<double>(&(*list)[0]);
    const auto y = std::get_if<double>(&(*list)[1]);
    const auto z = std::get_if<double>(&(*list)[2]);
    if (!x || !y || !z) {
      return std::nullopt;
    }
    return std::make_tuple(*x, *y, *z);
  }

  static const std::string& GetCursorName(const HCURSOR cursor)
  {
    // The cursor names correspond to the Flutter Engine names:
    // in shell/platform/windows/flutter_window_win32.cc
    static const std::string kDefaultCursorName = "basic";
    static const std::pair<std::string, const wchar_t*> mappings[] = {
        {"allScroll", IDC_SIZEALL},
        {kDefaultCursorName, IDC_ARROW},
        {"click", IDC_HAND},
        {"forbidden", IDC_NO},
        {"help", IDC_HELP},
        {"move", IDC_SIZEALL},
        {"none", nullptr},
        {"noDrop", IDC_NO},
        {"precise", IDC_CROSS},
        {"progress", IDC_APPSTARTING},
        {"text", IDC_IBEAM},
        {"resizeColumn", IDC_SIZEWE},
        {"resizeDown", IDC_SIZENS},
        {"resizeDownLeft", IDC_SIZENESW},
        {"resizeDownRight", IDC_SIZENWSE},
        {"resizeLeft", IDC_SIZEWE},
        {"resizeLeftRight", IDC_SIZEWE},
        {"resizeRight", IDC_SIZEWE},
        {"resizeRow", IDC_SIZENS},
        {"resizeUp", IDC_SIZENS},
        {"resizeUpDown", IDC_SIZENS},
        {"resizeUpLeft", IDC_SIZENWSE},
        {"resizeUpRight", IDC_SIZENESW},
        {"resizeUpLeftDownRight", IDC_SIZENWSE},
        {"resizeUpRightDownLeft", IDC_SIZENESW},
        {"wait", IDC_WAIT},
    };

    static std::map<HCURSOR, std::string> cursors;
    static bool initialized = false;

    if (!initialized) {
      initialized = true;
      for (const auto& pair : mappings) {
        HCURSOR cursor_handle = LoadCursor(nullptr, pair.second);
        if (cursor_handle) {
          cursors[cursor_handle] = pair.first;
        }
      }
    }

    const auto it = cursors.find(cursor);
    if (it != cursors.end()) {
      return it->second;
    }
    return kDefaultCursorName;
  }

  CustomPlatformView::CustomPlatformView(flutter::BinaryMessenger* messenger,
    flutter::TextureRegistrar* texture_registrar,
    GraphicsContext* graphics_context,
    HWND hwnd,
    std::shared_ptr<flutter_inappwebview_plugin::InAppWebView> webView)
    : hwnd_(hwnd), view(std::move(webView)), texture_registrar_(texture_registrar)
  {
#ifdef HAVE_FLUTTER_D3D_TEXTURE
    texture_bridge_ =
      std::make_unique<TextureBridgeGpu>(graphics_context, view->surface());

    flutter_texture_ =
      std::make_unique<flutter::TextureVariant>(flutter::GpuSurfaceTexture(
        kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle,
        [bridge = static_cast<TextureBridgeGpu*>(texture_bridge_.get())](
          size_t width,
          size_t height) -> const FlutterDesktopGpuSurfaceDescriptor*
        {
          return bridge->GetSurfaceDescriptor(width, height);
        }));
#else
    texture_bridge_ = std::make_unique<TextureBridgeFallback>(
      graphics_context, webview_->surface());

    flutter_texture_ =
      std::make_unique<flutter::TextureVariant>(flutter::PixelBufferTexture(
        [bridge = static_cast<TextureBridgeFallback*>(texture_bridge_.get())](
          size_t width, size_t height) -> const FlutterDesktopPixelBuffer*
        {
          return bridge->CopyPixelBuffer(width, height);
        }));
#endif

    texture_id_ = texture_registrar->RegisterTexture(flutter_texture_.get());
    texture_bridge_->SetOnFrameAvailable(
      [this, alive = alive_]() {
        if (*alive && view && view->plugin && view->plugin->isEngineAvailable()) {
          texture_registrar_->MarkTextureFrameAvailable(texture_id_);
        }
      });
    // texture_bridge_->SetOnSurfaceSizeChanged([this](Size size) {
    //  view->SetSurfaceSize(size.width, size.height);
    //});

    const auto method_channel_name = "com.pichillilorenzo/custom_platform_view_" + std::to_string(texture_id_);
    method_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        messenger, method_channel_name,
        &flutter::StandardMethodCodec::GetInstance());
    method_channel_->SetMethodCallHandler([this](const auto& call, auto result)
      {
        HandleMethodCall(call, std::move(result));
      });

    const auto event_channel_name = "com.pichillilorenzo/custom_platform_view_" + std::to_string(texture_id_) + "_events";
    event_channel_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
        messenger, event_channel_name,
        &flutter::StandardMethodCodec::GetInstance());

    auto handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
        [this, alive = alive_](const flutter::EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&
          events)
        {
          if (!*alive) return nullptr;
          event_sink_ = std::move(events);
          RegisterEventHandlers();
          return nullptr;
        },
        [this, alive = alive_](const flutter::EncodableValue* arguments)
        {
          if (*alive) {
            event_sink_ = nullptr;
          }
          return nullptr;
        });

    event_channel_->SetStreamHandler(std::move(handler));
  }

  void CustomPlatformView::UnregisterMethodCallHandler() const
  {
    // Registrar destruction runs after the engine has invalidated its messenger.
    if (!view || !view->plugin || !view->plugin->isEngineAvailable()) return;
    if (event_channel_) event_channel_->SetStreamHandler(nullptr);
    if (method_channel_) {
      method_channel_->SetMethodCallHandler(nullptr);
      if (view && view->channelDelegate) {
        view->channelDelegate->UnregisterMethodCallHandler();
      }
    }
  }

  CustomPlatformView::~CustomPlatformView()
  {
    debugLog("dealloc CustomPlatformView");
    *alive_ = false;
    UnregisterMethodCallHandler();
    // 纹理注销可能晚于平台视图析构，先解除捕获当前平台视图的回调。
    if (view) {
      view->onSurfaceSizeChanged(nullptr);
      view->onCursorChanged(nullptr);
    }
    event_sink_ = nullptr;
    texture_bridge_->SetOnFrameAvailable(nullptr);
    texture_bridge_->SetOnSurfaceSizeChanged(nullptr);
    texture_bridge_->Stop();
    // 引擎异步注销纹理；完成前 GPU 回调仍可能访问 bridge 和纹理描述。
    auto bridge = std::shared_ptr<TextureBridge>(std::move(texture_bridge_));
    auto texture = std::shared_ptr<flutter::TextureVariant>(std::move(flutter_texture_));
    // During engine teardown the raster thread is already stopped and its
    // texture registrar is invalid. Release locally on the platform thread.
    if (view && view->plugin && view->plugin->isEngineAvailable()) {
      texture_registrar_->UnregisterTexture(texture_id_, [bridge, texture]() {});
    }
  }

  void CustomPlatformView::RegisterEventHandlers()
  {
    if (!view) {
      return;
    }

    view->onSurfaceSizeChanged([this, alive = alive_](size_t width, size_t height)
      {
        if (*alive && texture_bridge_) {
          texture_bridge_->NotifySurfaceSizeChanged();
        }
      });

    view->onCursorChanged([this, alive = alive_](const HCURSOR cursor)
      {
        if (!*alive || !view || !view->plugin || !view->plugin->isEngineAvailable()) {
          return;
        }
        const auto& name = GetCursorName(cursor);
        const auto event = flutter::EncodableValue(
          flutter::EncodableMap { {
              flutter::EncodableValue(kEventType),
                flutter::EncodableValue("cursorChanged")
            },
          { flutter::EncodableValue(kEventValue), name }});
        EmitEvent(event);
      });
  }

  void CustomPlatformView::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    const auto& method_name = method_call.method_name();

    // setCursorPos: [double x, double y]
    if (method_name.compare(kMethodSetCursorPos) == 0) {
      const auto point = GetPointFromArgs(method_call.arguments());
      if (point && view) {
        view->setCursorPos(point->first, point->second);
        return result->Success();
      }
      return result->Error(kErrorInvalidArgs);
    }

    // setPointerUpdate:
    // [int pointer, int event, double x, double y, double size, double pressure]
    if (method_name.compare(kMethodSetPointerUpdate) == 0) {
      const flutter::EncodableList* list =
        std::get_if<flutter::EncodableList>(method_call.arguments());
      if (!list || list->size() != 6) {
        return result->Error(kErrorInvalidArgs);
      }

      const auto pointer = std::get_if<int32_t>(&(*list)[0]);
      const auto event = std::get_if<int32_t>(&(*list)[1]);
      const auto x = std::get_if<double>(&(*list)[2]);
      const auto y = std::get_if<double>(&(*list)[3]);
      const auto size = std::get_if<double>(&(*list)[4]);
      const auto pressure = std::get_if<double>(&(*list)[5]);

      if (pointer && event && x && y && size && pressure && view) {
        view->setPointerUpdate(*pointer,
          static_cast<flutter_inappwebview_plugin::InAppWebViewPointerEventKind>(*event),
          *x, *y, *size, *pressure);
        return result->Success();
      }
      return result->Error(kErrorInvalidArgs);
    }

    // setScrollDelta: [double dx, double dy]
    if (method_name.compare(kMethodSetScrollDelta) == 0) {
      const auto delta = GetPointFromArgs(method_call.arguments());
      if (delta && view) {
        view->setScrollDelta(delta->first, delta->second);
        return result->Success();
      }
      return result->Error(kErrorInvalidArgs);
    }

    // setPointerButton: {"button": int, "isDown": bool}
    if (method_name.compare(kMethodSetPointerButton) == 0) {
      const auto& map = std::get<flutter::EncodableMap>(*method_call.arguments());

      const auto button = map.find(flutter::EncodableValue("button"));
      const auto isDown = map.find(flutter::EncodableValue("isDown"));
      if (button != map.end() && isDown != map.end()) {
        const auto buttonValue = std::get_if<int32_t>(&button->second);
        const auto isDownValue = std::get_if<bool>(&isDown->second);
        if (buttonValue && isDownValue && view) {
          view->setPointerButtonState(
            static_cast<flutter_inappwebview_plugin::InAppWebViewPointerButton>(*buttonValue), *isDownValue);
          return result->Success();
        }
      }
      return result->Error(kErrorInvalidArgs);
    }

    // setSize: [double width, double height, double scale_factor]
    if (method_name.compare(kMethodSetSize) == 0) {
      auto size = GetPointAndScaleFactorFromArgs(method_call.arguments());
      if (size && view) {
        const auto [width, height, scale_factor] = size.value();
        if (width > 0 && height > 0 && scale_factor > 0) {
          view->setSurfaceSize(static_cast<size_t>(width),
            static_cast<size_t>(height),
            static_cast<float>(scale_factor));

          texture_bridge_->Start();
        }
        return result->Success();
      }
      return result->Error(kErrorInvalidArgs);
    }
    else if (method_name.compare(kMethodSetPosition) == 0) {
      auto position = GetPointAndScaleFactorFromArgs(method_call.arguments());
      if (position && view) {
        const auto [x, y, scale_factor] = position.value();

        view->setPosition(static_cast<size_t>(x),
          static_cast<size_t>(y),
          static_cast<float>(scale_factor));

        return result->Success();
      }
      return result->Error(kErrorInvalidArgs);
    }
    else if (method_name.compare(kMethodSetFpsLimit) == 0) {
      if (const auto value = std::get_if<int32_t>(method_call.arguments())) {
        texture_bridge_->SetFpsLimit(*value == 0 ? std::nullopt
          : std::make_optional(*value));
        return result->Success();
      }
    }

    result->NotImplemented();
  }
}
