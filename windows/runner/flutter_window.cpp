#include "flutter_window.h"

#include <optional>

#include <flutter/standard_method_codec.h>
#include "flutter/generated_plugin_registrant.h"
#include "auto_type.h"
#include "utils.h"

/// Eindeutige ID für den registrierten Hotkey.
///
/// Windows verwaltet Hotkeys pro Fenster über ganzzahlige IDs.
/// Bei WM_HOTKEY enthält wParam diese ID — so erkennt MessageHandler, welcher
/// Hotkey ausgelöst wurde. Der Wert 1 ist beliebig; er muss nur eindeutig
/// pro Fenster und Prozess sein.
static constexpr int kAutoTypeHotkeyId = 1;

/// Konstruktor: speichert das Flutter-Dart-Projekt für spätere Verwendung in OnCreate().
///
/// [project] beschreibt den Pfad zu den Dart-Assets, dem AOT-Snapshot usw.
/// Die eigentliche Initialisierung des Flutter-Engines findet erst in OnCreate() statt,
/// weil zu diesem Zeitpunkt das Win32-Fenster-Handle noch nicht existiert.
FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

/// Destruktor: alle Ressourcen werden bereits in OnDestroy() freigegeben.
FlutterWindow::~FlutterWindow() {}

/// Erstellt das Flutter-Fenster und initialisiert alle Subsysteme.
///
/// Wird von Win32Window::Create() aufgerufen, nachdem CreateWindowEx() das HWND erzeugt hat.
/// Reihenfolge der Initialisierungsschritte:
///   1. Basisklassen-Init (Win32Window::OnCreate) — muss als Erstes laufen.
///   2. FlutterViewController erzeugen — startet die Dart VM und das Rendering.
///   3. Plugins registrieren (generierter Code, pflegt sich selbst).
///   4. WinEvent-Hook starten — verfolgt ab sofort das aktive Fremd-Fenster.
///   5. MethodChannel registrieren — ermöglicht Dart↔C++ Kommunikation.
///   6. Kind-Fenster setzen — Flutter rendert in das HWND des Controllers.
///   7. Ersten Frame erzwingen — damit das Fenster sichtbar wird.
///
/// Gibt false zurück wenn die Flutter-Initialisierung scheitert; das bricht den
/// App-Start ab (main.cpp prüft den Rückgabewert).
bool FlutterWindow::OnCreate() {
  /// Basisklassen-Initialisierung (Win32Window::OnCreate).
  /// Setzt interne Felder wie hwnd_ und registriert den WNDCLASSEX.
  /// Muss zuerst aufgerufen werden — alle folgenden Schritte setzen ein gültiges HWND voraus.
  if (!Win32Window::OnCreate()) {
    return false;
  }

  /// GetClientArea() liefert das RECT des Fenster-Inhaltsbereichs (ohne Titelleiste, Rahmen).
  /// right-left = Breite, bottom-top = Höhe in physischen Pixeln.
  RECT frame = GetClientArea();

  /// FlutterViewController verwaltet die Dart VM, das Flutter-Rendering und die Plugin-Infrastruktur.
  /// Die Größe (frame.right-frame.left × frame.bottom-frame.top) muss exakt der Fenstergröße
  /// entsprechen — sonst erzeugt Flutter beim Start unnötige Surface-Operationen.
  /// make_unique: Objekt wird auf dem Heap angelegt; flutter_controller_ besitzt es via unique_ptr.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);

  /// Sicherheitscheck: engine() und view() sind nullptr, wenn die Dart VM nicht starten konnte
  /// (z.B. fehlende Assets, falscher Pfad). In diesem Fall gibt OnCreate() false zurück.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }

  /// RegisterPlugins ist generierter Code (flutter/generated_plugin_registrant.h).
  /// Er registriert alle nativen Flutter-Plugins (z.B. path_provider_windows).
  RegisterPlugins(flutter_controller_->engine());

  /// WinEvent-Hook starten: AutoType::Initialize() ruft SetWinEventHook() für
  /// EVENT_SYSTEM_FOREGROUND auf. Ab jetzt wird bei jedem Fensterwechsel der Callback
  /// WinEventProc aufgerufen, der das neue Fenster-HWND in g_previousHwnd speichert.
  AutoType::Instance().Initialize();

  /// MethodChannel "de.frohlfing.privault/autotype" einrichten.
  /// Ein MethodChannel ist ein benannter Kommunikationskanal zwischen Dart und C++.
  /// StandardMethodCodec serialisiert Argumente als JSON-ähnliche Binärstruktur.
  /// messenger() ist der Plugin-Registrar des Flutter-Engines — er leitet Nachrichten
  /// an den richtigen Handler weiter.
  autotype_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "de.frohlfing.privault/autotype",
      &flutter::StandardMethodCodec::GetInstance());

  /// Handler für eingehende Dart→C++ Methodenaufrufe registrieren.
  ///
  /// [this] im Lambda-Capture: wir brauchen Zugriff auf GetHandle() (geerbt von Win32Window),
  /// um in "registerHotkey" RegisterHotKey() aufzurufen. GetHandle() gibt das Win32-Fenster-
  /// Handle (HWND) zurück, das Win32Window verwaltet.
  ///
  /// Die Signatur des Handlers ist von der Flutter-API vorgegeben:
  ///   call  — enthält method_name() (String) und arguments() (EncodableValue).
  ///   result — über dieses Objekt antwortet C++ an Dart: Success(), Error() oder NotImplemented().
  autotype_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

          /// ---------------------------------------------------------------
          /// "getLastWindowTitle": Titel des letzten Fremd-Fensters abfragen.
          ///
          /// Dart ruft dies auf, bevor der Bestätigungsdialog in Szenario A erscheint.
          /// AutoType::GetLastWindowTitle() liest g_previousHwnd und gibt den
          /// Fenstertitel als std::wstring zurück.
          /// Utf8FromUtf16 wandelt den Windows-internen UTF-16-String in UTF-8 um,
          /// das der MethodChannel als Dart-String überträgt.
          /// ---------------------------------------------------------------
          if (call.method_name() == "getLastWindowTitle") {
              std::wstring title = AutoType::Instance().GetLastWindowTitle();
              result->Success(flutter::EncodableValue(Utf8FromUtf16(title.c_str())));

          /// ---------------------------------------------------------------
          /// "typeCredentials": Benutzername und/oder Passwort tippen.
          ///
          /// Erwartet eine Map mit den Schlüsseln "username" und "password" (beide UTF-8 Strings).
          /// std::get_if prüft ob call.arguments() tatsächlich eine Map ist — defensiver Check,
          /// da Dart prinzipiell beliebige Typen senden könnte.
          /// args->find() sucht den Schlüssel in der Map; end() bedeutet "nicht gefunden".
          /// Utf16FromUtf8 konvertiert die Dart-Strings in UTF-16, das SendInput benötigt.
          /// TypeCredentials gibt false zurück wenn kein Zielfenster mehr existiert →
          /// C++ antwortet mit Error("NO_TARGET_WINDOW"), Dart wirft dann eine PlatformException.
          /// ---------------------------------------------------------------
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

          /// ---------------------------------------------------------------
          /// "registerHotkey": Globalen Hotkey (neu) registrieren.
          ///
          /// Wird von AutofillServiceWindows.init() aufgerufen, nachdem der konfigurierte
          /// Hotkey aus ConfigService gelesen und in MOD_*-Flags + Virtual-Key-Code
          /// umgerechnet wurde. Ermöglicht, den Hotkey ohne Neustart zu ändern.
          ///
          /// Erwartet eine Map mit:
          ///   "modifiers" (int) — Kombination aus MOD_CONTROL, MOD_SHIFT, MOD_ALT, MOD_WIN, MOD_NOREPEAT
          ///   "vk"        (int) — Virtual-Key-Code des Buchstabens (z.B. 65 für 'A')
          ///
          /// Ablauf:
          ///   1. UnregisterHotKey: bestehende Registrierung entfernen (no-op wenn noch keine).
          ///      GetHandle() — von Win32Window geerbt — liefert das HWND dieses Fensters.
          ///      kAutoTypeHotkeyId — die eindeutige ID, unter der Windows den Hotkey führt.
          ///   2. RegisterHotKey: neue Registrierung mit den Dart-Parametern.
          ///      Bei Erfolg (BOOL TRUE) → Success(nullptr).
          ///      Bei Fehler → Error("HOTKEY_FAILED"), Dart loggt die Warnung.
          /// ---------------------------------------------------------------
          /// ---------------------------------------------------------------
          /// "unregisterHotkey": Globalen Hotkey temporär deregistrieren.
          ///
          /// Wird aufgerufen, wenn der AutofillHotkeyDialog geöffnet wird.
          /// Ohne Deregistrierung würde RegisterHotKey die Tastenkombination
          /// auf Systemebene abfangen — Flutter's onKeyEvent erhält die
          /// einzelnen Tasten-Events dann nicht mehr, und der Dialog kann die
          /// Kombination nicht erkennen.
          /// ---------------------------------------------------------------
          } else if (call.method_name() == "unregisterHotkey") {
              UnregisterHotKey(GetHandle(), kAutoTypeHotkeyId);
              result->Success(nullptr);

          } else if (call.method_name() == "registerHotkey") {
              const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
              if (!args) {
                  result->Error("INVALID_ARGS", "Erwartetes Map-Argument fehlt");
                  return;
              }
              auto itMod = args->find(flutter::EncodableValue("modifiers"));
              auto itVk  = args->find(flutter::EncodableValue("vk"));
              if (itMod == args->end() || itVk == args->end()) {
                  result->Error("INVALID_ARGS", "modifiers oder vk fehlt");
                  return;
              }
              /// std::get<int>: EncodableValue speichert Zahlen intern als int32.
              /// static_cast<UINT>: RegisterHotKey erwartet unsigned int.
              int modifiers = std::get<int>(itMod->second);
              int vk        = std::get<int>(itVk->second);
              /// Alte Registrierung entfernen, bevor eine neue angelegt wird.
              /// Ohne UnregisterHotKey schlägt RegisterHotKey für denselben kAutoTypeHotkeyId fehl.
              UnregisterHotKey(GetHandle(), kAutoTypeHotkeyId);
              BOOL ok = RegisterHotKey(GetHandle(), kAutoTypeHotkeyId,
                                       static_cast<UINT>(modifiers),
                                       static_cast<UINT>(vk));
              if (ok) {
                  result->Success(nullptr);
              } else {
                  result->Error("HOTKEY_FAILED", "RegisterHotKey fehlgeschlagen");
              }

          } else {
              /// Unbekannte Methode — Flutter erwartet NotImplemented() als Antwort.
              result->NotImplemented();
          }
      });

  /// Kind-Fenster setzen: Flutter rendert in das HWND des FlutterViewControllers.
  /// Ab diesem Punkt füllt die Flutter-UI das gesamte Fenster aus.
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  /// Callback für den ersten gerenderten Frame: erst dann wird das Fenster sichtbar.
  /// Verhindert ein kurzes Aufblitzen des leeren Fensters vor dem ersten Flutter-Frame.
  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  /// Sicherstellen, dass ein Frame angefordert wird.
  /// Falls Flutter den ersten Frame bereits gerendert hat, bevor SetNextFrameCallback
  /// aufgerufen wurde, würde Show() nie aufgerufen. ForceRedraw() verhindert das.
  flutter_controller_->ForceRedraw();

  return true;
}

/// Räumt alle Ressourcen auf, bevor das Fenster zerstört wird.
///
/// Reihenfolge wichtig:
///   1. Hotkey deregistrieren — kein WM_HOTKEY mehr nach diesem Punkt.
///   2. WinEvent-Hook entfernen — kein WinEventProc mehr nach diesem Punkt.
///   3. MethodChannel freigeben — Dart-Aufrufe werden nicht mehr angenommen.
///   4. FlutterViewController freigeben — Flutter-Engine wird heruntergefahren.
///   5. Basisklassen-OnDestroy (Win32Window::OnDestroy) aufrufen.
void FlutterWindow::OnDestroy() {
  /// UnregisterHotKey: Windows entfernt die Hotkey-Registrierung für dieses Fenster.
  /// GetHandle() liefert das HWND; kAutoTypeHotkeyId ist die beim Registrieren verwendete ID.
  UnregisterHotKey(GetHandle(), kAutoTypeHotkeyId);

  /// AutoType::Cleanup() ruft UnhookWinEvent(g_hook) auf und setzt g_previousHwnd auf nullptr.
  AutoType::Instance().Cleanup();

  /// MethodChannel-Pointer zurücksetzen: der Handler wird nicht mehr aufgerufen.
  autotype_channel_ = nullptr;

  /// FlutterViewController freigeben: beendet die Dart VM und gibt Render-Ressourcen frei.
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

/// Verarbeitet Win32-Nachrichten für dieses Fenster.
///
/// Flutter-Plugins erhalten zuerst die Chance, die Nachricht zu verarbeiten
/// (HandleTopLevelWindowProc). Nur wenn kein Plugin die Nachricht konsumiert,
/// verarbeitet FlutterWindow sie selbst.
///
/// Behandelte Nachrichten:
///   WM_FONTCHANGE — System-Schriftarten haben sich geändert; Flutter neu laden.
///   WM_HOTKEY     — Globaler Hotkey wurde gedrückt; Dart benachrichtigen.
///
/// Alle anderen Nachrichten werden an die Basisklasse Win32Window::MessageHandler
/// weitergeleitet (Default-Verhalten: DefWindowProc).
///
/// noexcept: Win32-Callbacks dürfen keine C++-Exceptions werfen — würde in
/// undefined behavior resultieren.
LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  /// Flutter-Plugins (z.B. url_launcher, file_picker) können Win32-Nachrichten selbst
  /// verarbeiten. HandleTopLevelWindowProc gibt std::optional<LRESULT> zurück:
  ///   has_value() == true  → Plugin hat die Nachricht konsumiert, Wert zurückgeben.
  ///   has_value() == false → Nachricht nicht verarbeitet, wir machen weiter.
  if (flutter_controller_) {
    std::optional<LRESULT> result = flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    /// WM_FONTCHANGE: Das Betriebssystem hat Schriften installiert oder entfernt.
    /// Flutter cached Schrift-Metriken intern — ReloadSystemFonts() leert diesen Cache,
    /// damit Texte korrekt gerendert werden.
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;

    /// WM_HOTKEY: Ein via RegisterHotKey() registrierter globaler Hotkey wurde gedrückt.
    ///
    /// wParam enthält die Hotkey-ID — wir prüfen ob es kAutoTypeHotkeyId ist.
    /// Ablauf:
    ///   1. Titel des letzten Fremd-Fensters lesen (g_previousHwnd).
    ///   2. UTF-16→UTF-8 konvertieren für den MethodChannel.
    ///   3. PriVault in den Vordergrund bringen (SW_RESTORE: aus Taskleiste wiederherstellen).
    ///   4. InvokeMethod("onHotkey"): Dart über den Hotkey informieren.
    ///      Dart navigiert dann zu /autotype-picker und übergibt den Fenstertitel.
    case WM_HOTKEY:
      if (wparam == kAutoTypeHotkeyId && autotype_channel_) {
        /// Guard: Hotkey ignorieren, wenn PriVault bereits Vordergrundfenster ist.
        /// Tritt auf, wenn der Nutzer den Hotkey innerhalb der App drückt.
        /// `GetForegroundWindow() == hwnd` bedeutet: PriVault hat bereits den Fokus — der Hotkey
        /// war kein Aufruf aus einer Fremd-App.
        if (GetForegroundWindow() == hwnd) break;

        /// AutoType::GetLastWindowTitle() liest g_previousHwnd (das Fremd-Fenster vor PriVault).
        std::wstring title = AutoType::Instance().GetLastWindowTitle();
        /// Utf8FromUtf16: Konvertiert Windows-UTF-16 in UTF-8, das der MethodChannel überträgt.
        std::string utf8Title = Utf8FromUtf16(title.c_str());

        /// PriVault in den Vordergrund bringen: SW_RESTORE stellt das Fenster aus dem
        /// minimierten Zustand wieder her. SetForegroundWindow übergibt den Eingabefokus.
        ShowWindow(hwnd, SW_RESTORE);
        SetForegroundWindow(hwnd);

        /// InvokeMethod sendet eine Nachricht von C++ an Dart (umgekehrte Richtung).
        /// "onHotkey" ist der Methodenname; Dart registriert dafür einen Handler in init().
        /// EncodableMap ist das Äquivalent einer Dart Map<String, dynamic>.
        autotype_channel_->InvokeMethod(
            "onHotkey",
            std::make_unique<flutter::EncodableValue>(flutter::EncodableValue(flutter::EncodableMap{
                {flutter::EncodableValue("windowTitle"), flutter::EncodableValue(utf8Title)}
            })));
      }
      break;
  }

  /// Alle nicht behandelten Nachrichten an die Basisklasse weitergeben.
  /// Win32Window::MessageHandler ruft letztlich DefWindowProc auf.
  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
