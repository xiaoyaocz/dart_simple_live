#ifndef RUNNER_WINDOWS_SHARE_BRIDGE_H_
#define RUNNER_WINDOWS_SHARE_BRIDGE_H_

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <windows.h>
// Must be included after windows.h.
#include <roapi.h>
#include <shobjidl.h>
#include <windows.applicationmodel.datatransfer.h>
#include <windows.foundation.h>
#include <wrl.h>
#include <wrl/client.h>
#include <wrl/event.h>
#include <wrl/wrappers/corewrappers.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>

class WindowsShareBridge {
 public:
  static constexpr const char* kChannelName = "simple_live/windows_share";

  WindowsShareBridge();
  ~WindowsShareBridge();

  WindowsShareBridge(const WindowsShareBridge&) = delete;
  WindowsShareBridge& operator=(const WindowsShareBridge&) = delete;

  void Attach(flutter::BinaryMessenger* messenger, HWND owner_window);
  void Detach();

 private:
  struct SharePayload {
    bool valid = false;
    std::wstring title;
    std::wstring description;
    std::wstring url;
    std::wstring text;
    std::wstring application_name;
  };

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::EncodableMap ShareRoom(const flutter::EncodableMap& args);
  HWND ResolveTopLevelWindow() const;
  HRESULT EnsureWinRtReady();
  HRESULT EnsureManagerBound(HWND top_hwnd);
  void UnbindManager();
  HRESULT OnDataRequested(
      ABI::Windows::ApplicationModel::DataTransfer::IDataRequestedEventArgs*
          args);

  static std::wstring Utf8ToWide(const std::string& utf8);
  static std::string FormatHResult(HRESULT hr);
  static bool IsProcessHighIntegrity();
  static bool IsCdpPolicyDisabled();
  static flutter::EncodableMap BuildResult(const char* status,
                                           const char* code,
                                           HRESULT hr,
                                           bool data_requested,
                                           const std::string& message = "");

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND owner_window_ = nullptr;
  HWND bound_window_ = nullptr;
  DWORD ui_thread_id_ = 0;
  bool ro_initialized_ = false;
  bool data_requested_registered_ = false;
  bool target_chosen_registered_ = false;
  uint64_t data_requested_seq_ = 0;
  HRESULT last_data_requested_hr_ = S_OK;
  SharePayload pending_payload_;

  Microsoft::WRL::ComPtr<IDataTransferManagerInterop> interop_;
  Microsoft::WRL::ComPtr<
      ABI::Windows::ApplicationModel::DataTransfer::IDataTransferManager>
      manager_;
  EventRegistrationToken data_requested_token_{};
  EventRegistrationToken target_chosen_token_{};
};

#endif  // RUNNER_WINDOWS_SHARE_BRIDGE_H_
