#include "windows_share_bridge.h"

#include <flutter/standard_method_codec.h>

#include <cstdio>
#include <vector>

namespace WRL = Microsoft::WRL;
namespace WF = ABI::Windows::Foundation;
namespace DT = ABI::Windows::ApplicationModel::DataTransfer;

namespace {

std::string ReadStringArg(const flutter::EncodableMap& args, const char* key) {
  auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) {
    return "";
  }
  if (const auto* value = std::get_if<std::string>(&it->second)) {
    return *value;
  }
  return "";
}

}  // namespace

WindowsShareBridge::WindowsShareBridge() = default;

WindowsShareBridge::~WindowsShareBridge() {
  Detach();
}

void WindowsShareBridge::Attach(flutter::BinaryMessenger* messenger,
                                HWND owner_window) {
  Detach();
  if (!messenger || !owner_window) {
    return;
  }
  owner_window_ = owner_window;
  ui_thread_id_ = ::GetCurrentThreadId();
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) { HandleMethodCall(call, std::move(result)); });
}

void WindowsShareBridge::Detach() {
  if (channel_) {
    channel_->SetMethodCallHandler(nullptr);
    channel_.reset();
  }
  UnbindManager();
  interop_.Reset();
  pending_payload_ = SharePayload{};
  owner_window_ = nullptr;
  ui_thread_id_ = 0;
  if (ro_initialized_) {
    ::RoUninitialize();
    ro_initialized_ = false;
  }
}

void WindowsShareBridge::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "shareRoom") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) {
      result->Success(flutter::EncodableValue(
          BuildResult("error", "invalid_arguments", E_INVALIDARG, false,
                      "Missing share arguments.")));
      return;
    }
    result->Success(flutter::EncodableValue(ShareRoom(*args)));
    return;
  }
  result->NotImplemented();
}

HWND WindowsShareBridge::ResolveTopLevelWindow() const {
  if (!owner_window_ || !::IsWindow(owner_window_)) {
    return nullptr;
  }
  HWND root = ::GetAncestor(owner_window_, GA_ROOT);
  if (root && ::IsWindow(root)) {
    return root;
  }
  return owner_window_;
}

HRESULT WindowsShareBridge::EnsureWinRtReady() {
  using WRL::Wrappers::HStringReference;
  if (interop_) {
    return S_OK;
  }
  HRESULT hr = ::RoGetActivationFactory(
      HStringReference(
          RuntimeClass_Windows_ApplicationModel_DataTransfer_DataTransferManager)
          .Get(),
      IID_PPV_ARGS(&interop_));
  if (hr == CO_E_NOTINITIALIZED) {
    HRESULT init_hr = ::RoInitialize(RO_INIT_SINGLETHREADED);
    if (SUCCEEDED(init_hr)) {
      ro_initialized_ = true;
    } else if (init_hr != RPC_E_CHANGED_MODE) {
      return init_hr;
    }
    hr = ::RoGetActivationFactory(
        HStringReference(
            RuntimeClass_Windows_ApplicationModel_DataTransfer_DataTransferManager)
            .Get(),
        IID_PPV_ARGS(&interop_));
  }
  return hr;
}

void WindowsShareBridge::UnbindManager() {
  if (manager_) {
    if (data_requested_registered_) {
      manager_->remove_DataRequested(data_requested_token_);
      data_requested_registered_ = false;
      data_requested_token_ = EventRegistrationToken{};
    }
    if (target_chosen_registered_) {
      manager_->remove_TargetApplicationChosen(target_chosen_token_);
      target_chosen_registered_ = false;
      target_chosen_token_ = EventRegistrationToken{};
    }
    manager_.Reset();
  }
  bound_window_ = nullptr;
}

HRESULT WindowsShareBridge::EnsureManagerBound(HWND top_hwnd) {
  if (manager_ && bound_window_ == top_hwnd && data_requested_registered_) {
    return S_OK;
  }
  UnbindManager();

  HRESULT hr = EnsureWinRtReady();
  if (FAILED(hr) || !interop_) {
    return FAILED(hr) ? hr : E_FAIL;
  }

  hr = interop_->GetForWindow(top_hwnd, IID_PPV_ARGS(&manager_));
  if (FAILED(hr) || !manager_) {
    return FAILED(hr) ? hr : E_FAIL;
  }

  auto data_requested_cb = WRL::Callback<WF::ITypedEventHandler<
      DT::DataTransferManager*, DT::DataRequestedEventArgs*>>(
      [this](DT::IDataTransferManager*,
             DT::IDataRequestedEventArgs* args) -> HRESULT {
        return OnDataRequested(args);
      });
  hr = manager_->add_DataRequested(data_requested_cb.Get(),
                                   &data_requested_token_);
  if (FAILED(hr)) {
    manager_.Reset();
    return hr;
  }
  data_requested_registered_ = true;

  // Register TargetApplicationChosen once so selection does not leak handlers.
  // Selecting a target still does not confirm the target completed sending.
  auto target_chosen_cb = WRL::Callback<WF::ITypedEventHandler<
      DT::DataTransferManager*, DT::TargetApplicationChosenEventArgs*>>(
      [](DT::IDataTransferManager*,
         DT::ITargetApplicationChosenEventArgs*) -> HRESULT { return S_OK; });
  if (SUCCEEDED(manager_->add_TargetApplicationChosen(
          target_chosen_cb.Get(), &target_chosen_token_))) {
    target_chosen_registered_ = true;
  }

  bound_window_ = top_hwnd;
  return S_OK;
}

HRESULT WindowsShareBridge::OnDataRequested(
    DT::IDataRequestedEventArgs* args) {
  using WRL::Wrappers::HStringReference;
  ++data_requested_seq_;
  last_data_requested_hr_ = S_OK;

  if (!args) {
    last_data_requested_hr_ = E_INVALIDARG;
    return E_INVALIDARG;
  }

  WRL::ComPtr<DT::IDataRequest> request;
  HRESULT hr = args->get_Request(&request);
  if (FAILED(hr) || !request) {
    last_data_requested_hr_ = FAILED(hr) ? hr : E_FAIL;
    return last_data_requested_hr_;
  }

  if (!pending_payload_.valid || pending_payload_.title.empty() ||
      pending_payload_.url.empty()) {
    request->FailWithDisplayText(
        HStringReference(L"当前没有可分享的直播间信息").Get());
    last_data_requested_hr_ = E_INVALIDARG;
    return S_OK;
  }

  WRL::ComPtr<DT::IDataPackage> data;
  hr = request->get_Data(&data);
  if (FAILED(hr) || !data) {
    last_data_requested_hr_ = FAILED(hr) ? hr : E_FAIL;
    return last_data_requested_hr_;
  }

  WRL::ComPtr<DT::IDataPackagePropertySet> properties;
  hr = data->get_Properties(&properties);
  if (FAILED(hr) || !properties) {
    last_data_requested_hr_ = FAILED(hr) ? hr : E_FAIL;
    return last_data_requested_hr_;
  }

  // Windows requires a non-empty DataPackage title.
  hr = properties->put_Title(
      HStringReference(pending_payload_.title.c_str(),
                       static_cast<unsigned int>(pending_payload_.title.size()))
          .Get());
  if (FAILED(hr)) {
    request->FailWithDisplayText(
        HStringReference(L"无法设置直播间分享标题").Get());
    last_data_requested_hr_ = hr;
    return hr;
  }

  if (!pending_payload_.description.empty()) {
    properties->put_Description(
        HStringReference(
            pending_payload_.description.c_str(),
            static_cast<unsigned int>(pending_payload_.description.size()))
            .Get());
  }

  if (!pending_payload_.application_name.empty()) {
    properties->put_ApplicationName(
        HStringReference(
            pending_payload_.application_name.c_str(),
            static_cast<unsigned int>(pending_payload_.application_name.size()))
            .Get());
  }

  bool any_format_written = false;

  // Provide standard WebLink + ContentSourceWebLink for URI/link targets.
  WRL::ComPtr<WF::IUriRuntimeClassFactory> uri_factory;
  if (SUCCEEDED(::RoGetActivationFactory(
          HStringReference(RuntimeClass_Windows_Foundation_Uri).Get(),
          IID_PPV_ARGS(&uri_factory))) &&
      uri_factory) {
    WRL::ComPtr<WF::IUriRuntimeClass> uri;
    if (SUCCEEDED(uri_factory->CreateUri(
            HStringReference(
                pending_payload_.url.c_str(),
                static_cast<unsigned int>(pending_payload_.url.size()))
                .Get(),
            &uri)) &&
        uri) {
      WRL::ComPtr<DT::IDataPackage2> data2;
      if (SUCCEEDED(data.As(&data2)) && data2) {
        if (SUCCEEDED(data2->SetWebLink(uri.Get()))) {
          any_format_written = true;
        }
      }
      WRL::ComPtr<DT::IDataPackagePropertySet2> props2;
      if (SUCCEEDED(properties.As(&props2)) && props2) {
        props2->put_ContentSourceWebLink(uri.Get());
      }
    }
  }

  // Provide plain text ("title\nurl") for text-only share targets.
  // Never call SetStorageItemsReadOnly with an empty file vector.
  const std::wstring& text_to_share =
      pending_payload_.text.empty() ? pending_payload_.url
                                    : pending_payload_.text;
  hr = data->SetText(
      HStringReference(text_to_share.c_str(),
                       static_cast<unsigned int>(text_to_share.size()))
          .Get());
  if (SUCCEEDED(hr)) {
    any_format_written = true;
  }

  if (!any_format_written) {
    request->FailWithDisplayText(
        HStringReference(L"无法准备直播间分享数据").Get());
    last_data_requested_hr_ = FAILED(hr) ? hr : E_FAIL;
    return last_data_requested_hr_;
  }

  return S_OK;
}

flutter::EncodableMap WindowsShareBridge::ShareRoom(
    const flutter::EncodableMap& args) {
  if (ui_thread_id_ != 0 && ::GetCurrentThreadId() != ui_thread_id_) {
    return BuildResult("error", "wrong_thread", RPC_E_WRONG_THREAD, false,
                       "Share must run on the UI STA thread.");
  }

  HWND top_hwnd = ResolveTopLevelWindow();
  if (!top_hwnd) {
    return BuildResult("error", "window_invalid", E_HANDLE, false,
                       "Top-level window handle is invalid.");
  }

  const std::string title_utf8 = ReadStringArg(args, "title");
  const std::string url_utf8 = ReadStringArg(args, "url");
  const std::string description_utf8 = ReadStringArg(args, "description");
  const std::string text_utf8 = ReadStringArg(args, "text");

  const std::wstring title = Utf8ToWide(title_utf8);
  const std::wstring url = Utf8ToWide(url_utf8);
  const std::wstring description = Utf8ToWide(description_utf8);
  const std::wstring text = Utf8ToWide(text_utf8);

  if (title.empty() || url.empty()) {
    return BuildResult("error", "invalid_arguments", E_INVALIDARG, false,
                       "Title and URL must be non-empty.");
  }

  HRESULT hr = EnsureWinRtReady();
  if (FAILED(hr) || !interop_) {
    return BuildResult("error", "interop_failed", FAILED(hr) ? hr : E_FAIL,
                       false, "Failed to initialize Windows Share interop.");
  }

  // Check whether Windows reports DataTransferManager as supported.
  using WRL::Wrappers::HStringReference;
  WRL::ComPtr<DT::IDataTransferManagerStatics2> statics2;
  if (SUCCEEDED(::RoGetActivationFactory(
          HStringReference(
              RuntimeClass_Windows_ApplicationModel_DataTransfer_DataTransferManager)
              .Get(),
          IID_PPV_ARGS(&statics2))) &&
      statics2) {
    boolean supported = TRUE;
    if (SUCCEEDED(statics2->IsSupported(&supported)) && !supported) {
      return BuildResult("unsupported", "not_supported", S_OK, false,
                         "Windows DataTransferManager is not supported.");
    }
  }

  hr = EnsureManagerBound(top_hwnd);
  if (FAILED(hr)) {
    return BuildResult("error", "manager_failed", hr, false,
                       "Failed to bind DataTransferManager to window.");
  }

  // Overwrite the entire payload atomically before showing the Share UI so no
  // fields from an earlier share call can leak into this request.
  pending_payload_ = SharePayload{
      true,
      title,
      description.empty() ? title : description,
      url,
      text.empty() ? (title + L"\n" + url) : text,
      L"Simple Live",
  };

  const uint64_t seq_before = data_requested_seq_;
  last_data_requested_hr_ = S_OK;

  hr = interop_->ShowShareUIForWindow(top_hwnd);
  const bool data_requested = data_requested_seq_ > seq_before;

  if (FAILED(hr)) {
    return BuildResult("error", "show_failed", hr, data_requested,
                       "ShowShareUIForWindow failed.");
  }
  if (data_requested && FAILED(last_data_requested_hr_)) {
    return BuildResult("error", "data_request_failed", last_data_requested_hr_,
                       true, "DataRequested failed to populate DataPackage.");
  }

  return BuildResult("opened", "", S_OK, data_requested);
}

std::wstring WindowsShareBridge::Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int required = ::MultiByteToWideChar(
      CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), nullptr, 0);
  if (required <= 0) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(required), L'\0');
  const int written = ::MultiByteToWideChar(
      CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), wide.data(),
      required);
  if (written <= 0) {
    return std::wstring();
  }
  wide.resize(static_cast<size_t>(written));
  return wide;
}

std::string WindowsShareBridge::FormatHResult(HRESULT hr) {
  char buf[16];
  std::snprintf(buf, sizeof(buf), "0x%08lX", static_cast<unsigned long>(hr));
  return std::string(buf);
}

bool WindowsShareBridge::IsProcessHighIntegrity() {
  HANDLE token = nullptr;
  if (!::OpenProcessToken(::GetCurrentProcess(), TOKEN_QUERY, &token)) {
    return false;
  }
  DWORD needed = 0;
  ::GetTokenInformation(token, TokenIntegrityLevel, nullptr, 0, &needed);
  if (needed == 0) {
    ::CloseHandle(token);
    return false;
  }
  std::vector<BYTE> buffer(needed);
  bool high = false;
  if (::GetTokenInformation(token, TokenIntegrityLevel, buffer.data(), needed,
                            &needed)) {
    auto* label = reinterpret_cast<const TOKEN_MANDATORY_LABEL*>(buffer.data());
    if (label && label->Label.Sid) {
      const PUCHAR count = ::GetSidSubAuthorityCount(label->Label.Sid);
      if (count && *count > 0) {
        const DWORD rid =
            *::GetSidSubAuthority(label->Label.Sid, static_cast<DWORD>(*count - 1));
        high = rid >= SECURITY_MANDATORY_HIGH_RID;
      }
    }
  }
  ::CloseHandle(token);
  return high;
}

bool WindowsShareBridge::IsCdpPolicyDisabled() {
  DWORD value = 1;
  DWORD size = sizeof(value);
  const LSTATUS status = ::RegGetValueW(
      HKEY_LOCAL_MACHINE, L"SOFTWARE\\Policies\\Microsoft\\Windows\\System",
      L"EnableCdp", RRF_RT_REG_DWORD, nullptr, &value, &size);
  return status == ERROR_SUCCESS && value == 0;
}

flutter::EncodableMap WindowsShareBridge::BuildResult(
    const char* status,
    const char* code,
    HRESULT hr,
    bool data_requested,
    const std::string& message) {
  return flutter::EncodableMap{
      {flutter::EncodableValue("status"), flutter::EncodableValue(status)},
      {flutter::EncodableValue("code"), flutter::EncodableValue(code)},
      {flutter::EncodableValue("hresult"),
       flutter::EncodableValue(FormatHResult(hr))},
      {flutter::EncodableValue("dataRequested"),
       flutter::EncodableValue(data_requested)},
      {flutter::EncodableValue("elevated"),
       flutter::EncodableValue(IsProcessHighIntegrity())},
      {flutter::EncodableValue("cdpDisabled"),
       flutter::EncodableValue(IsCdpPolicyDisabled())},
      {flutter::EncodableValue("message"), flutter::EncodableValue(message)},
  };
}
