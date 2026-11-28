#include <windows.h>
#include <cassert>
#include <thread>
#include <future>
#include "../utils/com_apartment.h"

using flutter_inappwebview_plugin::ComApartment;
HRESULT apartmentStatus() {
  APTTYPE type;
  APTTYPEQUALIFIER qualifier;
  return CoGetApartmentType(&type, &qualifier);
}
int main() {
  std::thread fresh([] {
    assert(apartmentStatus() == CO_E_NOTINITIALIZED);
    {
      ComApartment owner;
      assert(SUCCEEDED(owner.result()));
      { ComApartment nested; assert(nested.result() == S_FALSE); }
      assert(SUCCEEDED(apartmentStatus()));
    }
    assert(apartmentStatus() == CO_E_NOTINITIALIZED);
  });
  fresh.join();
  std::thread mta([] {
    assert(SUCCEEDED(CoInitializeEx(nullptr, COINIT_MULTITHREADED)));
    { ComApartment wrongMode; assert(wrongMode.result() == RPC_E_CHANGED_MODE); }
    assert(SUCCEEDED(apartmentStatus()));
    CoUninitialize();
    assert(apartmentStatus() == CO_E_NOTINITIALIZED);
  });
  mta.join();
  std::thread platform([] {
    assert(apartmentStatus() == CO_E_NOTINITIALIZED);
    // Hundreds of environment wrapper lifetimes must neither uninitialize the
    // platform STA nor add a COM reference on every create/retry.
    for (int i = 0; i < 100; ++i) {
      assert(SUCCEEDED(flutter_inappwebview_plugin::ensureWebViewComApartment()));
      { ComApartment environment; assert(environment.result() == S_FALSE); }
      assert(SUCCEEDED(apartmentStatus()));
    }
  });
  platform.join();
  std::thread recovered([] {
    using flutter_inappwebview_plugin::ensureWebViewComApartment;
    assert(SUCCEEDED(ensureWebViewComApartment()));
    for (int i = 0; i < 100; ++i) {
      // Fault injection: another native lifecycle has drained this thread's
      // COM reference. A cached S_OK must not claim the thread is still ready.
      CoUninitialize();
      assert(apartmentStatus() == CO_E_NOTINITIALIZED);
      assert(SUCCEEDED(ensureWebViewComApartment()));
      assert(SUCCEEDED(apartmentStatus()));
    }
  });
  recovered.join();
  std::thread retryMode([] {
    using flutter_inappwebview_plugin::ensureWebViewComApartment;
    assert(SUCCEEDED(CoInitializeEx(nullptr, COINIT_MULTITHREADED)));
    assert(ensureWebViewComApartment() == RPC_E_CHANGED_MODE);
    CoUninitialize();
    assert(SUCCEEDED(ensureWebViewComApartment()));
    assert(SUCCEEDED(apartmentStatus()));
  });
  retryMode.join();
  // A media worker keeps the process MTA alive. After COM loss the platform
  // thread is implicitly in that MTA, but may still explicitly initialize STA.
  std::promise<void> mtaReady, releaseMta;
  auto release = releaseMta.get_future();
  std::thread media([&] {
    assert(SUCCEEDED(CoInitializeEx(nullptr, COINIT_MULTITHREADED)));
    mtaReady.set_value();
    release.wait();
    CoUninitialize();
  });
  mtaReady.get_future().wait();
  std::thread implicit([] {
    using flutter_inappwebview_plugin::ensureWebViewComApartment;
    assert(SUCCEEDED(ensureWebViewComApartment()));
    CoUninitialize();
    APTTYPE type; APTTYPEQUALIFIER qualifier;
    assert(SUCCEEDED(CoGetApartmentType(&type, &qualifier)));
    assert(type == APTTYPE_MTA && qualifier == APTTYPEQUALIFIER_IMPLICIT_MTA);
    assert(SUCCEEDED(ensureWebViewComApartment()));
    assert(SUCCEEDED(CoGetApartmentType(&type, &qualifier)));
    assert(type == APTTYPE_STA || type == APTTYPE_MAINSTA);
  });
  implicit.join();
  releaseMta.set_value();
  media.join();
}
