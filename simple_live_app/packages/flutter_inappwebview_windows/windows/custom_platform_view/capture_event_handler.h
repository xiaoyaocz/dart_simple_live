#pragma once

#include <wrl.h>

#include <memory>
#include <utility>

namespace flutter_inappwebview_plugin
{
  // GraphicsCapture stores an agile reference to event handlers. A plain WRL
  // Callback is apartment-bound: resolving it after COM teardown can fail with
  // RPC_E_SERVER_DIED_DNE, and GraphicsCapture then invokes a null delegate.
  // The frame pool still dispatches on its creating thread (Create, not
  // CreateFreeThreaded); FtmBase only removes the handler's COM proxy dependency.
  template<typename Handler, typename Callback>
  Microsoft::WRL::ComPtr<Handler> MakeCaptureEventHandler(
    std::weak_ptr<int> lifetime, Callback&& callback)
  {
    return Microsoft::WRL::Callback<Microsoft::WRL::Implements<
      Microsoft::WRL::RuntimeClassFlags<Microsoft::WRL::ClassicCom>,
      Handler, Microsoft::WRL::FtmBase>>(
        [lifetime, callback = std::forward<Callback>(callback)](auto* sender,
          IInspectable* args) mutable -> HRESULT
        {
          // Removal does not cancel a notification already copied by the pool.
          // Owner destruction and delivery both run on the creating dispatcher.
          if (lifetime.expired()) return S_OK;
          return callback(sender, args);
        });
  }
}
