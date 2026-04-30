#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>

#include <memory>

#include "win32_window.h"

/// Hauptfenster der App: hostet die Flutter-View und verwaltet die nativen Subsysteme.
///
/// Erbt von Win32Window (erstellt das native Win32-Fenster und leitet Nachrichten weiter).
/// Verantwortlich für:
///   - Flutter-Engine starten und in das Win32-Fenster einbetten.
///   - MethodChannel "de.frohlfing.famkey/autotype" registrieren (Dart ↔ C++ Kommunikation).
///   - WinEvent-Hook via AutoType::Initialize() starten (aktives Fremd-Fenster verfolgen).
///   - Globalen Hotkey (WM_HOTKEY) empfangen und an Dart weiterleiten.
///   - Ressourcen in OnDestroy() sauber freigeben.
class FlutterWindow : public Win32Window {
 public:
  /// Konstruktor: speichert das Flutter-Dart-Projekt; eigentliche Init in OnCreate().
  ///
  /// [project] beschreibt Pfad zu den Dart-Assets und dem AOT-Snapshot.
  explicit FlutterWindow(const flutter::DartProject& project);

  /// Destruktor: Ressourcen werden bereits in OnDestroy() freigegeben, hier kein Code nötig.
  virtual ~FlutterWindow();

 protected:
  /// Initialisiert Flutter und alle nativen Subsysteme nach Erstellung des Win32-Fensters.
  ///
  /// Aufgerufen von Win32Window::Create() sobald das HWND verfügbar ist.
  /// Gibt false zurück wenn die Flutter-Engine nicht gestartet werden kann.
  bool OnCreate() override;

  /// Räumt alle Ressourcen auf bevor das Fenster zerstört wird.
  ///
  /// Reihenfolge: Hotkey → WinEvent-Hook → MethodChannel → FlutterViewController → Basisklasse.
  void OnDestroy() override;

  /// Win32-Nachrichtenverarbeitung: Flutter-Plugins zuerst, dann WM_FONTCHANGE und WM_HOTKEY.
  ///
  /// noexcept: Win32-Callbacks dürfen keine C++-Exceptions werfen.
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  /// Das Flutter-Dart-Projekt (Asset-Pfade, AOT-Snapshot-Pfad).
  ///
  /// Wird im Konstruktor gesetzt und in OnCreate() an den FlutterViewController übergeben.
  flutter::DartProject project_;

  /// Verwaltet die Flutter-Engine und das Flutter-View-HWND.
  ///
  /// Erzeugt in OnCreate(), freigegeben in OnDestroy().
  /// Enthält engine() (Dart VM + Rendering) und view() (das native Flutter-Fenster).
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  /// Bidirektionaler Kommunikationskanal zwischen Dart und C++ für Auto-Type.
  ///
  /// Registrierter Name: "de.frohlfing.famkey/autotype".
  /// Dart → C++: "getLastWindowTitle", "typeCredentials", "registerHotkey".
  /// C++ → Dart: "onHotkey" (via InvokeMethod bei WM_HOTKEY).
  ///
  /// Erzeugt in OnCreate(), freigegeben in OnDestroy().
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> autotype_channel_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
