#pragma once

#include <windows.h>
#include <string>

// Implementiert Auto-Type für Windows (Szenario A):
// Verfolgt das zuletzt aktive Nicht-FamKey-Fenster und tippt Credentials hinein.
class AutoType {
public:
    static AutoType& Instance();

    // Startet den WinEvent-Hook zum Verfolgen des aktiven Fensters.
    // Muss vor der Nachrichtenschleife aufgerufen werden.
    void Initialize();

    // Gibt den WinEvent-Hook frei.
    void Cleanup();

    // Gibt den Titel des zuletzt aktiven Nicht-FamKey-Fensters zurück.
    // Leer, wenn noch kein Fenster verfolgt wurde oder das Fenster nicht mehr existiert.
    std::wstring GetLastWindowTitle() const;

    // Tippt Credentials in das zuletzt aktive Fenster.
    // Sequenz: username → Tab → password → Enter
    // Gibt false zurück, wenn kein gültiges Zielfenster vorhanden ist.
    bool TypeCredentials(const std::wstring& username, const std::wstring& password);

private:
    AutoType() = default;
    ~AutoType() = default;
    AutoType(const AutoType&) = delete;
    AutoType& operator=(const AutoType&) = delete;

    void TypeString(const std::wstring& text) const;
    void TypeKey(WORD vk) const;
};
