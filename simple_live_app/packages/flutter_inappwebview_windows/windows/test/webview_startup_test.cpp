// Local-only WebView2 lifecycle regression. Pass a fresh temporary profile path.
#include <windows.h>
#include <wrl.h>
#include <WebView2.h>
#include <iostream>
#include <thread>
#include <future>
#ifdef COM_APARTMENT_HEADER
#include COM_APARTMENT_HEADER
#else
#include "../utils/com_apartment.h"
#endif
using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;
static bool waitFor(bool& done) {
  const auto deadline = GetTickCount64() + 15000;
  while (!done && GetTickCount64() < deadline) {
    MSG msg;
    while (PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) {
      TranslateMessage(&msg);
      DispatchMessage(&msg);
    }
    if (!done) MsgWaitForMultipleObjects(0, nullptr, FALSE, 20, QS_ALLINPUT);
  }
  return done;
}
int wmain(int argc, wchar_t** argv) {
  if (argc != 2) return 2;
  int exitCode = 1;
  std::promise<void> mtaReady, releaseMta;
  auto release = releaseMta.get_future();
  std::thread media([&] {
    CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    mtaReady.set_value();
    release.wait();
    CoUninitialize();
  });
  mtaReady.get_future().wait();
  std::thread platform([&] {
    using flutter_inappwebview_plugin::ensureWebViewComApartment;
    if (FAILED(ensureWebViewComApartment())) return;
    // Reproduce stale success on the real WebView2 entry, not a mocked HRESULT.
    CoUninitialize();
    if (FAILED(ensureWebViewComApartment())) return;
    for (int i = 0; i < 20; ++i) {
      if (i > 0) CoUninitialize();
      if (FAILED(ensureWebViewComApartment())) return;
      bool done = false;
      HRESULT result = E_PENDING;
      ComPtr<ICoreWebView2Environment> environment;
      auto hr = CreateCoreWebView2EnvironmentWithOptions(nullptr, argv[1], nullptr,
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
          [&](HRESULT value, ICoreWebView2Environment* env) -> HRESULT {
            result = value; environment = env; done = true; return S_OK;
          }).Get());
      if (FAILED(hr)) {
        std::cerr << "Environment startup: 0x" << std::hex << static_cast<unsigned long>(hr) << '\n';
        return;
      }
      if (!waitFor(done)) { std::cerr << "Environment timeout\n"; ExitProcess(3); }
      if (FAILED(result) || !environment) { std::cerr << "Environment callback: 0x" << std::hex << static_cast<unsigned long>(result) << '\n'; return; }
      HWND host = CreateWindowExW(0, L"STATIC", L"WebView startup test", WS_POPUP,
                                  0, 0, 400, 240, nullptr, nullptr, GetModuleHandle(nullptr), nullptr);
      if (!host) return;
      ComPtr<ICoreWebView2Controller> controller;
      done = false;
      hr = environment->CreateCoreWebView2Controller(host,
        Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
          [&](HRESULT value, ICoreWebView2Controller* view) -> HRESULT {
            result = value; controller = view; done = true; return S_OK;
          }).Get());
      if (FAILED(hr)) { DestroyWindow(host); return; }
      if (!waitFor(done)) { std::cerr << "Controller timeout\n"; ExitProcess(3); }
      if (FAILED(result) || !controller) { DestroyWindow(host); return; }
      controller->Close(); controller.Reset(); environment.Reset(); DestroyWindow(host);
    }
    std::cout << "PASS: 20 real WebView2 environment/controller startup-close cycles after COM loss; fresh profile, no navigation or messages\n";
    exitCode = 0;
  });
  platform.join();
  releaseMta.set_value();
  media.join();
  return exitCode;
}
