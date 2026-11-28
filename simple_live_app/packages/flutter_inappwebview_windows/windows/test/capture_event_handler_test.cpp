// Local COM regression; no browser profile, network, or user data is used.
#include <windows.h>
#include <roapi.h>
#include <windows.foundation.h>
#include <windows.graphics.capture.h>
#include <wrl.h>

#include <atomic>
#include <future>
#include <iostream>
#include <thread>

#include "../custom_platform_view/capture_event_handler.h"

using Handler = ABI::Windows::Foundation::ITypedEventHandler<
  ABI::Windows::Graphics::Capture::Direct3D11CaptureFramePool*, IInspectable*>;

int main()
{
  if (FAILED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED))) return 2;
  std::promise<Microsoft::WRL::ComPtr<IAgileReference>> result;
  std::atomic<int> calls = 0;
  auto lifetime = std::make_shared<int>(0);
  std::thread creator([&] {
    if (FAILED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED))) ExitProcess(2);
    auto callback = [&](auto*, auto*) -> HRESULT { ++calls; return S_OK; };
#ifdef LEGACY_CAPTURE_CALLBACK
    // Exact pre-fix delegate pattern, retained as a negative control.
    auto handler = Microsoft::WRL::Callback<Handler>(callback);
#else
    auto handler = flutter_inappwebview_plugin::MakeCaptureEventHandler<Handler>(
      lifetime, callback);
#endif
    Microsoft::WRL::ComPtr<IAgileReference> reference;
    auto hr = RoGetAgileReference(AGILEREFERENCE_DEFAULT,
      __uuidof(Handler), handler.Get(), &reference);
    if (FAILED(hr)) ExitProcess(2);
    result.set_value(reference);
    handler.Reset();
    CoUninitialize();
  });
  auto reference = result.get_future().get();
  creator.join();
  Microsoft::WRL::ComPtr<Handler> resolved;
  auto hr = reference->Resolve(__uuidof(Handler), &resolved);
  if (SUCCEEDED(hr) && resolved) hr = resolved->Invoke(nullptr, nullptr);
  if (FAILED(hr) || !resolved || calls != 1) {
    std::cerr << "FAIL: capture delegate lost after apartment exit; hr=0x"
      << std::hex << static_cast<unsigned long>(hr) << '\n';
    return 1;
  }
  lifetime.reset();
  // A notification already copied by GraphicsCapture must not reach a dead
  // bridge, even if removing the event registration cannot cancel that copy.
  hr = resolved->Invoke(nullptr, nullptr);
  if (FAILED(hr) || calls != 1) return 3;
  resolved.Reset();
  reference.Reset();
  CoUninitialize();
  std::cout << "PASS: delegate survives COM apartment exit; late event is inert\n";
  return 0;
}
