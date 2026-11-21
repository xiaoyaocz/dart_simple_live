#include "angle_surface_manager.h"

#include <iostream>

using Microsoft::WRL::ComPtr;

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

int main() {
  ComPtr<ID3D11Device> device;
  ComPtr<ID3D11DeviceContext> context;
  if (FAILED(D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, 0,
      nullptr, 0, D3D11_SDK_VERSION, &device, nullptr, &context))) return 1;
  for (int i = 0; i < 3; ++i) {
    ANGLESurfaceManager surface(64, 64);
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
  std::cout << "PASS: shared pixels correct after draws and resize; duplicate reads skipped\n";
}
