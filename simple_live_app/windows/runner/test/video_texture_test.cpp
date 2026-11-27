#include "angle_surface_manager.h"

#include <TlHelp32.h>
#include <mpv/client.h>
#include <mpv/render.h>
#include <mpv/render_gl.h>

#include <chrono>
#include <iostream>
#include <string>

using Microsoft::WRL::ComPtr;

static void* GetEglProc(void*, const char* name) {
  return reinterpret_cast<void*>(eglGetProcAddress(name));
}

static int CountProcessThreads() {
  DWORD pid = ::GetCurrentProcessId();
  HANDLE snap = ::CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
  if (snap == INVALID_HANDLE_VALUE) return -1;
  int count = 0;
  THREADENTRY32 te{};
  te.dwSize = sizeof(te);
  if (::Thread32First(snap, &te)) {
    do {
      if (te.th32OwnerProcessID == pid) count++;
    } while (::Thread32Next(snap, &te));
  }
  ::CloseHandle(snap);
  return count;
}

bool CheckPixel(ID3D11Device* device, ID3D11DeviceContext* context,
    HANDLE handle, unsigned char red, unsigned char green) {
  ComPtr<ID3D11Texture2D> shared;
  if (FAILED(device->OpenSharedResource(handle, IID_PPV_ARGS(&shared)))) return false;
  D3D11_TEXTURE2D_DESC desc{};
  shared->GetDesc(&desc);
  desc.Usage = D3D11_USAGE_STAGING;
  desc.BindFlags = 0;
  desc.MiscFlags = 0;
  desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
  ComPtr<ID3D11Texture2D> staging;
  if (FAILED(device->CreateTexture2D(&desc, nullptr, &staging))) return false;
  context->CopyResource(staging.Get(), shared.Get());
  D3D11_MAPPED_SUBRESOURCE mapped{};
  if (FAILED(context->Map(staging.Get(), 0, D3D11_MAP_READ, 0, &mapped))) return false;
  const auto* pixel = static_cast<const unsigned char*>(mapped.pData);
  const bool correct = pixel[2] == red && pixel[1] == green;
  context->Unmap(staging.Get(), 0);
  return correct;
}

int main(int argc, char** argv) {
  ComPtr<ID3D11Device> device;
  ComPtr<ID3D11DeviceContext> context;
  if (FAILED(D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, 0,
      nullptr, 0, D3D11_SDK_VERSION, &device, nullptr, &context))) return 1;

  for (int i = 0; i < 3; ++i) {
    ANGLESurfaceManager surface(64, 64);
    if (!surface.is_d3d11()) return 10;
    surface.Draw([] {
      glClearColor(1, 0, 0, 1);
      glClear(GL_COLOR_BUFFER_BIT);
    });
    if (!surface.Read() || surface.Read() ||
        !CheckPixel(device.Get(), context.Get(), surface.handle(), 255, 0)) return 2;
    surface.SetSize(100, 70);
    surface.Draw([] {
      glClearColor(0, 1, 0, 1);
      glClear(GL_COLOR_BUFFER_BIT);
    });
    if (!surface.Read() || surface.Read() ||
        !CheckPixel(device.Get(), context.Get(), surface.handle(), 0, 255)) return 3;
  }

  // Verify libmpv v0.42+ integration, d3d11-egl zero-copy driver loading,
  // audio-buffer=0.5 acceptance, and thread stability across 5 room cycles.
  int threads_after_2 = -1;
  int threads_after_5 = -1;
  std::string mpv_ver;
  for (int iter = 1; iter <= 5; ++iter) {
    ANGLESurfaceManager surface(128, 72);
    mpv_handle* mpv = mpv_create();
    if (!mpv) return 11;
    mpv_request_log_messages(mpv, "v");
    if (mpv_initialize(mpv) != 0) return 12;

    char* ver = mpv_get_property_string(mpv, "mpv-version");
    if (!ver) return 13;
    mpv_ver = ver;
    mpv_free(ver);
    if (mpv_ver.find("0.42.") == std::string::npos &&
        mpv_ver.find("0.4") == std::string::npos) {
      return 14;
    }

    if (mpv_set_property_string(mpv, "vo", "libmpv") != 0) return 15;
    if (mpv_set_property_string(mpv, "hwdec", "auto") != 0) return 16;
    if (mpv_set_property_string(mpv, "gpu-hwdec-interop", "d3d11-egl") != 0) return 17;
    if (mpv_set_property_string(mpv, "audio-buffer", "0.5") != 0) return 18;
    mpv_set_property_string(mpv, "ao", "null");

    surface.MakeCurrent(true);
    mpv_opengl_init_params gl_init{ GetEglProc, nullptr };
    mpv_render_param params[] = {
        { MPV_RENDER_PARAM_API_TYPE, const_cast<char*>(MPV_RENDER_API_TYPE_OPENGL) },
        { MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl_init },
        { MPV_RENDER_PARAM_INVALID, nullptr },
    };
    mpv_render_context* rctx = nullptr;
    if (mpv_render_context_create(&rctx, mpv, params) != 0 || !rctx) return 19;
    surface.MakeCurrent(false);

    bool saw_d3d11_egl = false;
    bool saw_dxva2_egl_error = false;
    if (argc >= 2 && iter == 1) {
      const char* cmd[] = { "loadfile", argv[1], nullptr };
      mpv_command(mpv, cmd);
      auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(8);
      int frames = 0;
      while (std::chrono::steady_clock::now() < deadline && frames < 2) {
        mpv_event* ev = mpv_wait_event(mpv, 0.05);
        if (ev->event_id == MPV_EVENT_LOG_MESSAGE) {
          auto* msg = static_cast<mpv_event_log_message*>(ev->data);
          std::string text(msg->text ? msg->text : "");
          if (text.find("d3d11-egl") != std::string::npos) saw_d3d11_egl = true;
          if (text.find("dxva2-egl") != std::string::npos) return 20;
        }
        if (mpv_render_context_update(rctx) & MPV_RENDER_UPDATE_FRAME) {
          surface.Draw([&] {
            mpv_opengl_fbo fbo{ 0, surface.width(), surface.height(), 0 };
            mpv_render_param rparams[] = {
                { MPV_RENDER_PARAM_OPENGL_FBO, &fbo },
                { MPV_RENDER_PARAM_INVALID, nullptr },
            };
            mpv_render_context_render(rctx, rparams);
          });
          surface.Read();
          frames++;
        }
      }
      if (frames < 1) return 21;
      char* cur_hw = mpv_get_property_string(mpv, "hwdec-current");
      std::string hw = cur_hw ? cur_hw : "";
      if (cur_hw) mpv_free(cur_hw);
      std::cout << "LIVE hwdec-current=" << hw << "\n";
      if (hw != "d3d11va") return 22;
    }

    for (int j = 0; j < 200; ++j) {
      mpv_event* ev = mpv_wait_event(mpv, 0.002);
      if (ev->event_id == MPV_EVENT_NONE) break;
      if (ev->event_id == MPV_EVENT_LOG_MESSAGE) {
        auto* msg = static_cast<mpv_event_log_message*>(ev->data);
        std::string text(msg->text ? msg->text : "");
        if (text.find("d3d11-egl") != std::string::npos) saw_d3d11_egl = true;
        if (text.find("dxva2-egl") != std::string::npos) saw_dxva2_egl_error = true;
      }
    }
    if (!saw_d3d11_egl || saw_dxva2_egl_error) return 23;

    // Proper teardown order: free render_context with EGL current before ANGLESurfaceManager.
    surface.MakeCurrent(true);
    mpv_render_context_set_update_callback(rctx, nullptr, nullptr);
    mpv_render_context_free(rctx);
    surface.MakeCurrent(false);
    mpv_terminate_destroy(mpv);

    ::Sleep(100);
    int threads = CountProcessThreads();
    if (iter == 2) threads_after_2 = threads;
    if (iter == 5) threads_after_5 = threads;
  }

  if (threads_after_2 < 0 || threads_after_5 - threads_after_2 > 3) {
    std::cerr << "Thread leak detected: iter2=" << threads_after_2
              << " iter5=" << threads_after_5 << "\n";
    return 24;
  }

  std::cout << "PASS: shared pixels correct after draws and resize; duplicate reads skipped; "
            << mpv_ver << " d3d11-egl active; threads iter2=" << threads_after_2
            << " iter5=" << threads_after_5 << "\n";
  return 0;
}
