#ifndef FLUTTER_INAPPWEBVIEW_COM_APARTMENT_H_
#define FLUTTER_INAPPWEBVIEW_COM_APARTMENT_H_
#include <windows.h>

namespace flutter_inappwebview_plugin {
// COM is thread-local. Flutter's platform callbacks need their own STA even
// when the runner's main thread was initialized. Keep it alive for WebView2's
// asynchronous callbacks, not just for CreateCoreWebView2Environment's call.
class ComApartment {
 public:
  ComApartment() : result_(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED)) {}
  ~ComApartment() {
    // Both S_OK and S_FALSE add a reference; RPC_E_CHANGED_MODE does not.
    if (SUCCEEDED(result_)) CoUninitialize();
  }
  HRESULT result() const { return result_; }
  HRESULT ensure() {
    APTTYPE type;
    APTTYPEQUALIFIER qualifier;
    const auto status = CoGetApartmentType(&type, &qualifier);
    // A previous successful initialization is not proof of current readiness:
    // other native lifecycles can have released COM on this platform thread.
    // A process-wide MTA (e.g. a media worker) makes an uninitialized thread
    // report IMPLICIT_MTA, not CO_E_NOTINITIALIZED. It can still enter STA;
    // rejecting it here permanently breaks every subsequent WebView startup.
    if (status == CO_E_NOTINITIALIZED || FAILED(result_) ||
        (SUCCEEDED(status) && type == APTTYPE_MTA &&
         qualifier == APTTYPEQUALIFIER_IMPLICIT_MTA)) {
      result_ = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
      return result_;
    }
    if (FAILED(status)) return status;
    return type == APTTYPE_STA || type == APTTYPE_MAINSTA ? S_OK : RPC_E_CHANGED_MODE;
  }
  ComApartment(const ComApartment&) = delete;
  ComApartment& operator=(const ComApartment&) = delete;
 private:
  HRESULT result_;
};

inline HRESULT ensureWebViewComApartment() {
  // Environment wrappers can be disposed while a WebView still holds a copy
  // of their COM interfaces. Own the STA on the actual calling thread until
  // thread exit, not until the last Dart environment wrapper is disposed.
  thread_local ComApartment apartment;
  return apartment.ensure();
}
}
#endif
