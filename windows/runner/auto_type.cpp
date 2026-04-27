#include "auto_type.h"

#include <vector>

/// -----------------------------------------------------------------------------
/// Globale Zustandsvariablen (Datei-Scope)
/// -----------------------------------------------------------------------------

/// HWND des zuletzt aktiven Nicht-PriVault-Vordergrundfensters.
///
/// Wird von WinEventProc aktualisiert, sobald das OS ein neues Fenster in den
/// Vordergrund bringt. Bleibt nullptr, bis zum ersten Mal ein fremdes Fenster
/// fokussiert wurde. Nach Cleanup() wieder nullptr.
///
/// Zugriff: Nur aus dem Haupt-Thread. WinEventHooks mit WINEVENT_OUTOFCONTEXT
/// werden im Thread des Registrierenden ausgeführt — das ist der Flutter UI-Thread.
/// Kein Locking nötig.
static HWND g_previousHwnd = nullptr;

/// Handle des aktiven WinEvent-Hooks.
///
/// Gesetzt von Initialize(), freigegeben in Cleanup(). nullptr = kein Hook aktiv.
static HWINEVENTHOOK g_hook = nullptr;

/// -----------------------------------------------------------------------------
/// WinEvent-Callback
/// -----------------------------------------------------------------------------

/// Callback für EVENT_SYSTEM_FOREGROUND: speichert das neue Vordergrundfenster.
///
/// Wird vom OS aufgerufen, sobald ein anderes Fenster den Fokus erhält.
/// Guard-Logik:
///   1. idObject/idChild-Filter: nur das Fenster selbst, keine Child-Elemente.
///   2. nullptr-Check: degenerate case abfangen.
///   3. PID-Check: eigenen Prozess ausschließen (defensiver Fallback, falls
///      WINEVENT_SKIPOWNPROCESS in seltenen Szenarien nicht greift).
static void CALLBACK WinEventProc(HWINEVENTHOOK, DWORD, HWND hwnd,
    LONG idObject, LONG idChild, DWORD, DWORD) {
    if (idObject != OBJID_WINDOW || idChild != CHILDID_SELF) return;
    if (hwnd == nullptr) return;
    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    if (pid == GetCurrentProcessId()) return;
    g_previousHwnd = hwnd;
}

/// -----------------------------------------------------------------------------
/// AutoType — Singleton-Implementierung
/// -----------------------------------------------------------------------------

/// Meyer's Singleton — thread-sicher ab C++11.
AutoType& AutoType::Instance() {
    static AutoType instance;
    return instance;
}

/// Startet den WinEvent-Hook für EVENT_SYSTEM_FOREGROUND.
///
/// Muss einmalig in FlutterWindow::OnCreate() aufgerufen werden.
/// WINEVENT_OUTOFCONTEXT: Callback läuft im eigenen Thread (kein DLL-Inject).
/// WINEVENT_SKIPOWNPROCESS: eigene Fensterereignisse werden übersprungen.
/// idProcess=0, idThread=0: alle Prozesse und Threads überwachen.
void AutoType::Initialize() {
    g_hook = SetWinEventHook(
        EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND,
        nullptr, WinEventProc,
        0, 0,
        WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
}

/// Entfernt den WinEvent-Hook und setzt den HWND-Cache zurück.
/// Wird in FlutterWindow::OnDestroy() aufgerufen.
void AutoType::Cleanup() {
    if (g_hook) {
        UnhookWinEvent(g_hook);
        g_hook = nullptr;
    }
    g_previousHwnd = nullptr;
}

/// Gibt den Titel des zuletzt aktiven Nicht-PriVault-Fensters zurück.
///
/// IsWindow() prüft, ob g_previousHwnd noch gültig ist (Fenster könnte
/// inzwischen geschlossen worden sein).
/// Puffer von 512 Zeichen reicht für alle üblichen Fenstertitel.
/// Gibt "" zurück, wenn g_previousHwnd nullptr oder nicht mehr gültig.
std::wstring AutoType::GetLastWindowTitle() const {
    if (g_previousHwnd == nullptr || !IsWindow(g_previousHwnd)) return L"";
    wchar_t title[512] = {};
    GetWindowTextW(g_previousHwnd, title, 512);
    return std::wstring(title);
}

/// Tippt username und/oder password in das Zielfenster (g_previousHwnd).
///
/// Ablauf:
///   1. Sicherheitscheck: g_previousHwnd muss gültig sein.
///   2. Zielfenster in den Vordergrund holen und 150 ms warten (Fokus-Stabilisierung).
///   3. Alle Tastaturereignisse in einem einzigen atomaren SendInput-Aufruf senden.
///
/// Sequenz (abhängig davon welche Felder befüllt sind):
///   - Beide vorhanden:  Benutzername → Tab → Passwort → Enter
///   - Nur Benutzername: Benutzername → Enter
///   - Nur Passwort:     Passwort → Enter
///
/// Warum zwei SendInput-Aufrufe bei username + password?
///   Browser verarbeiten VK_TAB intern asynchron: keydown → blur/focus-Events →
///   JavaScript → Fokus wechselt ins nächste Feld. Das dauert typischerweise
///   einige Millisekunden. Wenn Passwort-Zeichen im selben atomaren Batch wie
///   Tab stehen, landen sie noch im Username-Feld, bevor der Fokus-Wechsel
///   abgeschlossen ist. Ein Sleep(100) zwischen Tab und Passwort gibt dem
///   Browser Zeit, den Fokus sauber zu wechseln.
///
/// Warum VK_TAB statt KEYEVENTF_UNICODE für Tab?
///   Browser und Login-Dialoge verarbeiten Feldwechsel über WM_KEYDOWN(VK_TAB).
///   KEYEVENTF_UNICODE erzeugt nur WM_CHAR, keinen WM_KEYDOWN — Tab käme dort
///   nicht an.
///   Hinweis: Texteditoren mit Autocomplete (z.B. Notepad++) interpretieren
///   VK_TAB als "Vorschlag annehmen". Das ist ein bekanntes Auto-Type-Problem,
///   das auch andere Password-Manager betrifft.
///
/// Gibt false zurück, wenn g_previousHwnd nullptr oder nicht mehr gültig ist.
bool AutoType::TypeCredentials(const std::wstring& username, const std::wstring& password) {
    HWND targetHwnd = g_previousHwnd;
    if (targetHwnd == nullptr || !IsWindow(targetHwnd)) return false;

    ShowWindow(targetHwnd, SW_RESTORE);
    SetForegroundWindow(targetHwnd);
    Sleep(150);

    auto sendBatch = [](std::vector<INPUT>& inputs) {
        if (!inputs.empty()) {
            SendInput(static_cast<UINT>(inputs.size()), inputs.data(), sizeof(INPUT));
            inputs.clear();
        }
    };

    auto addUnicode = [](std::vector<INPUT>& inputs, wchar_t c) {
        INPUT down = {};
        down.type = INPUT_KEYBOARD;
        down.ki.wScan = static_cast<WORD>(c);
        down.ki.dwFlags = KEYEVENTF_UNICODE;
        INPUT up = down;
        up.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
        inputs.push_back(down);
        inputs.push_back(up);
    };

    auto addVk = [](std::vector<INPUT>& inputs, WORD vk) {
        INPUT down = {};
        down.type = INPUT_KEYBOARD;
        down.ki.wVk = vk;
        INPUT up = down;
        up.ki.dwFlags = KEYEVENTF_KEYUP;
        inputs.push_back(down);
        inputs.push_back(up);
    };

    std::vector<INPUT> inputs;

    if (!username.empty() && !password.empty()) {
        /// Batch 1: Benutzername + Tab — atomar, damit Tab den Fokus wechselt
        inputs.reserve((username.size() + 1) * 2);
        for (wchar_t c : username) addUnicode(inputs, c);
        addVk(inputs, VK_TAB);
        sendBatch(inputs);

        /// 100 ms warten: Browser verarbeitet Tab-Event und wechselt den Fokus
        Sleep(100);

        /// Batch 2: Passwort + Enter — landet jetzt im richtigen Feld
        inputs.reserve((password.size() + 1) * 2);
        for (wchar_t c : password) addUnicode(inputs, c);
        addVk(inputs, VK_RETURN);
        sendBatch(inputs);
    } else if (!username.empty()) {
        inputs.reserve((username.size() + 1) * 2);
        for (wchar_t c : username) addUnicode(inputs, c);
        addVk(inputs, VK_RETURN);
        sendBatch(inputs);
    } else if (!password.empty()) {
        inputs.reserve((password.size() + 1) * 2);
        for (wchar_t c : password) addUnicode(inputs, c);
        addVk(inputs, VK_RETURN);
        sendBatch(inputs);
    }

    return true;
}

/// Tippt einen Unicode-String zeichenweise via SendInput.
/// Nicht mehr direkt von TypeCredentials genutzt — bleibt für zukünftige Nutzung erhalten.
void AutoType::TypeString(const std::wstring& text) const {
    std::vector<INPUT> inputs;
    inputs.reserve(text.size() * 2);
    for (wchar_t c : text) {
        INPUT down = {};
        down.type = INPUT_KEYBOARD;
        down.ki.wScan = static_cast<WORD>(c);
        down.ki.dwFlags = KEYEVENTF_UNICODE;
        INPUT up = down;
        up.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
        inputs.push_back(down);
        inputs.push_back(up);
    }
    if (!inputs.empty()) {
        SendInput(static_cast<UINT>(inputs.size()), inputs.data(), sizeof(INPUT));
    }
}

/// Drückt und lässt einen virtuellen Tastatur-Key (z.B. VK_RETURN) los.
/// Nicht mehr direkt von TypeCredentials genutzt, bleibt für zukünftige Nutzung.
void AutoType::TypeKey(WORD vk) const {
    INPUT inputs[2] = {};
    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wVk = vk;
    inputs[1] = inputs[0];
    inputs[1].ki.dwFlags = KEYEVENTF_KEYUP;
    SendInput(2, inputs, sizeof(INPUT));
}
