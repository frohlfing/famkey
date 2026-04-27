#include "flutter_window.h"

#include <optional>

#include <flutter/standard_method_codec.h>
#include "flutter/generated_plugin_registrant.h"
#include "auto_type.h"
#include "utils.h"

// TODO: ID aus dem konfigurierten Tastenkürzel (ConfigService.autofillHotkey) ableiten.
// Derzeit hardcoded: Strg+Shift+A.
static constexpr int kAutoTypeHotkeyId = 1;

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

  // WinEvent-Hook starten, um das letzte Nicht-PriVault-Fenster zu verfolgen
  AutoType::Instance().Initialize();

  // MethodChannel für Auto-Type registrieren
  autotype_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "de.frohlfing.privault/autotype",
      &flutter::StandardMethodCodec::GetInstance());

  autotype_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

          if (call.method_name() == "getLastWindowTitle") {
              std::wstring title = AutoType::Instance().GetLastWindowTitle();
              result->Success(flutter::EncodableValue(Utf8FromUtf16(title.c_str())));

          } else if (call.method_name() == "typeCredentials") {
              const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
              if (!args) {
                  result->Error("INVALID_ARGS", "Erwartetes Map-Argument fehlt");
                  return;
              }
              auto itUser = args->find(flutter::EncodableValue("username"));
              auto itPass = args->find(flutter::EncodableValue("password"));
              if (itUser == args->end() || itPass == args->end()) {
                  result->Error("INVALID_ARGS", "username oder password fehlt");
                  return;
              }
              const auto& username = std::get<std::string>(itUser->second);
              const auto& password = std::get<std::string>(itPass->second);
              bool ok = AutoType::Instance().TypeCredentials(
                  Utf16FromUtf8(username), Utf16FromUtf8(password));
              if (ok) {
                  result->Success(nullptr);
              } else {
                  result->Error("NO_TARGET_WINDOW", "Kein Zielfenster verfügbar");
              }

          } else {
              result->NotImplemented();
          }
      });

  // TODO: Tastenkürzel aus ConfigService.autofillHotkey lesen und in MOD_*/VK_* übersetzen.
  // Derzeit hardcoded: Strg+Shift+A.
  RegisterHotKey(GetHandle(), kAutoTypeHotkeyId, MOD_CONTROL | MOD_SHIFT | MOD_NOREPEAT, 'A');

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  UnregisterHotKey(GetHandle(), kAutoTypeHotkeyId);
  AutoType::Instance().Cleanup();
  autotype_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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

    case WM_HOTKEY:
      if (wparam == kAutoTypeHotkeyId && autotype_channel_) {
        std::wstring title = AutoType::Instance().GetLastWindowTitle();
        std::string utf8Title = Utf8FromUtf16(title.c_str());

        // PriVault in den Vordergrund bringen
        ShowWindow(hwnd, SW_RESTORE);
        SetForegroundWindow(hwnd);

        // Flutter über den Hotkey informieren
        autotype_channel_->InvokeMethod(
            "onHotkey",
            std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
                {flutter::EncodableValue("windowTitle"), flutter::EncodableValue(utf8Title)}
            }));
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
