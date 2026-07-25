#include "flutter_window.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <algorithm>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr const wchar_t kWakeMessageName[] =
    L"dev.ultrasend.shrimpsend.wake_main_window";

UINT GetWakeMessage() {
  static UINT message = ::RegisterWindowMessageW(kWakeMessageName);
  return message;
}

void BringWindowToFrontNatively(HWND hwnd) {
  if (::IsIconic(hwnd)) {
    ::ShowWindow(hwnd, SW_RESTORE);
  }
  ::ShowWindow(hwnd, SW_SHOW);
  ::SetForegroundWindow(hwnd);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // When launched at startup (--startup arg, registered by
  // windows_launch_at_startup_service.dart), the Dart layer keeps the window
  // hidden via window_manager and parks it in the tray. An unconditional
  // Show() on the first frame would override that hide and pop the window
  // onto the desktop, so skip it here and let window_manager own visibility.
  const auto& entrypoint_args = project_.dart_entrypoint_arguments();
  const bool launched_at_startup =
      std::find(entrypoint_args.begin(), entrypoint_args.end(),
                "--startup") != entrypoint_args.end();

  if (!launched_at_startup) {
    flutter_controller_->engine()->SetNextFrameCallback([&]() {
      this->Show();
    });
  }

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == GetWakeMessage()) {
    BringWindowToFrontNatively(hwnd);
    if (flutter_controller_ && flutter_controller_->engine()) {
      flutter::MethodChannel<flutter::EncodableValue> channel(
          flutter_controller_->engine()->messenger(),
          "dev.ultrasend/desktop_lifecycle",
          &flutter::StandardMethodCodec::GetInstance());
      channel.InvokeMethod("bringToFront",
                           std::make_unique<flutter::EncodableValue>());
    }
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
