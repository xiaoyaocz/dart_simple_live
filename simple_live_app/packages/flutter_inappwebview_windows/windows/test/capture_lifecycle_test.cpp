// Real D3D/GraphicsCapture regression; uses only a generated color surface.
#include <windows.h>
#include <windows.foundation.h>
#include <windows.ui.composition.desktop.h>

#include <iostream>

#include "../custom_platform_view/texture_bridge.h"
#include "../custom_platform_view/texture_bridge_gpu.h"
#include "../custom_platform_view/util/composition.desktop.interop.h"

using namespace flutter_inappwebview_plugin;

class TestBridge : public TextureBridge {
public:
  using TextureBridge::TextureBridge;
  void PrepareIncompleteStart() {
    frame_pool_ = graphics_context_->CreateCaptureFramePool(
      graphics_context_->device(), kPixelFormat, 1, {320, 240});
    if (!frame_pool_) throw std::runtime_error("No frame pool");
  }
  bool HasPool() const { return static_cast<bool>(frame_pool_); }
};

class TestGpuBridge : public TextureBridgeGpu {
public:
  using TextureBridgeGpu::TextureBridgeGpu;
  bool FramePending() {
    const std::lock_guard<std::mutex> lock(mutex_);
    return frame_pending_;
  }
};

int main()
{
  rx::RoHelper ro(RO_INIT_SINGLETHREADED);
  winrt::com_ptr<ABI::Windows::System::IDispatcherQueueController> queue;
  DispatcherQueueOptions options{sizeof(options), DQTYPE_THREAD_CURRENT, DQTAT_COM_STA};
  winrt::check_hresult(ro.CreateDispatcherQueueController(options, queue.put()));
  GraphicsContext graphics(&ro);
  auto compositor = graphics.CreateCompositor();
  winrt::com_ptr<ABI::Windows::UI::Composition::ISpriteVisual> sprite;
  winrt::check_hresult(compositor->CreateSpriteVisual(sprite.put()));
  auto visual = sprite.as<ABI::Windows::UI::Composition::IVisual>();
  winrt::check_hresult(visual->put_Size({320, 240}));
  winrt::com_ptr<ABI::Windows::UI::Composition::ICompositionColorBrush> brush;
  winrt::check_hresult(compositor->CreateColorBrushWithColor({255, 255, 0, 0}, brush.put()));
  winrt::check_hresult(sprite->put_Brush(
    brush.as<ABI::Windows::UI::Composition::ICompositionBrush>().get()));
  HWND hwnd = CreateWindowExW(WS_EX_NOACTIVATE, L"STATIC",
    L"SimpleLive capture regression", WS_POPUP | WS_VISIBLE,
    0, 0, 320, 240, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
  if (!hwnd) return 2;
  auto target = util::TryCreateDesktopWindowTarget(compositor, hwnd);
  winrt::check_hresult(target.as<ABI::Windows::UI::Composition::ICompositionTarget>()->put_Root(visual.get()));
  auto pump = [&] {
    for (int i = 0; i < 40; ++i) {
      winrt::check_hresult(brush->put_Color({255, static_cast<BYTE>(i * 5), 0, 0}));
      MSG msg;
      while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
      }
      Sleep(5);
    }
  };
  int frames = 0;
  const DWORD platformThread = GetCurrentThreadId();
  bool wrongThread = false;
  for (int cycle = 0; cycle < 20; ++cycle) {
    TestBridge bridge(&graphics, visual.get());
    bridge.PrepareIncompleteStart();
    bridge.Stop();
    if (bridge.HasPool()) {
      std::cerr << "FAIL: incomplete Start retained frame pool\n";
      return 1;
    }
    bridge.SetOnFrameAvailable([&] {
      wrongThread = wrongThread || GetCurrentThreadId() != platformThread;
      ++frames;
    });
    for (int restart = 0; restart < 2; ++restart) {
      const int before = frames;
      if (!bridge.Start() || bridge.Start()) return 3;
      pump();
      if (frames == before || wrongThread) return 4;
      bridge.Stop();
      bridge.Stop();
      const int stopped = frames;
      pump();
      if (frames != stopped || bridge.HasPool()) return 5;
    }
  }
  {
    TestGpuBridge bridge(&graphics, visual.get());
    if (!bridge.Start()) return 6;
    pump();
    if (!bridge.FramePending()) return 7;
    for (int i = 0; i < 3; ++i) {
      auto descriptor = bridge.GetSurfaceDescriptor(320, 240);
      if (!descriptor || !descriptor->handle || bridge.FramePending()) return 8;
      descriptor->release_callback(descriptor->release_context);
    }
    bridge.Stop();
    if (bridge.FramePending() || bridge.GetSurfaceDescriptor(320, 240)) return 9;
    if (!bridge.Start()) return 10;
    pump();
    if (!bridge.FramePending()) return 11;
    bridge.Stop();
  }
  pump(); // Flush notifications copied before the last bridge was destroyed.
  winrt::check_hresult(target.as<ABI::Windows::UI::Composition::ICompositionTarget>()->put_Root(nullptr));
  target = nullptr;
  DestroyWindow(hwnd);
  std::cout << "PASS: 20 bridge lifecycles, 40 start/stop cycles, " << frames
    << " real frames; partial-start cleanup, stopped callbacks and GPU frame reuse checked\n";
  return 0;
}
