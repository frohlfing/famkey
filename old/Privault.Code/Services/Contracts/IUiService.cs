using Privault.Core.Models.Results;

namespace Privault.Core.Services.Contracts;

// ReSharper disable UnusedAutoPropertyAccessor.Global

/// <summary>
/// Abstraktion für UI-Interaktionen, damit Services und ViewModels in Unit-Tests ohne MAUI-Shell testbar bleiben.
/// </summary>
public interface IUiService
{
    // --- Dialoge & Feedback ---
    
    /// <summary>
    /// Zeigt einen Dialog mit Eingabefeld an und gibt die Benutzereingabe als String zurück.
    /// </summary>
    /// <param name="title">Der Titel des Dialogs.</param>
    /// <param name="message">Die Nachricht oder Frage, die im Dialog angezeigt wird.</param>
    /// <param name="accept">Der Text für den Ok-Button. Default: OK</param>
    /// <param name="cancel">Der Text für den Abbrechen-Button. Default: Abbrechen</param>
    /// <returns>Die Benutzereingabe als String, oder null, falls die Operation abgebrochen wurde.</returns>
    Task<string?> PromptAsync(string title, string message, string accept = "OK", string cancel = "Abbrechen");

    /// <summary>
    /// Zeigt einen Benachrichtigungsdialog an.
    /// </summary>
    /// <param name="title">Der Titel des Dialogs.</param>
    /// <param name="message">Die Nachricht, die im Dialog angezeigt wird.</param>
    Task AlertAsync(string title, string message);

    /// <summary>
    /// Zeigt einen Hinweis-Dialog an.
    /// </summary>
    /// <param name="message">Die Nachricht, die im Dialog angezeigt wird.</param>
    Task InfoAsync(string message);
    
    /// <summary>
    /// Zeigt einen Fehlerdialog an.
    /// </summary>
    /// <param name="message">Der Fehlertext, der im Dialog angezeigt wird.</param>
    Task ErrorAsync(string message);
    
    /// <summary>
    /// Zeigt einen Bestätigungsdialog (Ja/Nein) an.
    /// </summary>
    /// <param name="title">Der Titel des Dialogs.</param>
    /// <param name="message">Die Nachricht oder Frage.</param>
    /// <param name="accept">Text für den Bestätigen-Button (z.B. "Ja").</param>
    /// <param name="cancel">Text für den Abbrechen-Button (z.B. "Nein").</param>
    /// <returns><c>true</c>, wenn der Benutzer bestätigt hat, sonst <c>false</c>.</returns>
    Task<bool> ConfirmAsync(string title, string message, string accept, string cancel);

    /// <summary>
    /// Zeigt eine Auswahl-Liste (ActionSheet) an.
    /// </summary>
    /// <param name="title">Titel des ActionSheets.</param>
    /// <param name="cancel">Text für Abbrechen.</param>
    /// <param name="destruction">
    /// Optionaler "destructive" Button (Plattform-UI kann diesen besonders hervorheben).
    /// </param>
    /// <param name="buttons">Die auswählbaren Optionen.</param>
    /// <returns>Den gewählten Button-Text oder <c>null</c> (z.B. bei Abbruch).</returns>
    Task<string?> ActionSheetAsync(string title, string cancel, string? destruction, params string[] buttons);

    /// <summary>
    /// Zeigt eine kurze, nicht-blockierende Benachrichtigung (Toast) an.
    /// </summary>
    /// <param name="message">Die anzuzeigende Nachricht.</param>
    Task ToastAsync(string message);

    // --- Navigation ---

    /// <summary>
    /// Navigiert zur angegebenen Route.
    /// Beginnt die Route mit einem Slash (z.B. "/main", ist die Angabe absolut und die Historie wird gelöscht (kein Zurück-Button).
    /// Ansonsten ist die Angabe relativ und ein Zurück zur vorherigen Seite ist möglich.
    /// Zurück wird mit ".." angegeben.
    /// </summary>
    /// <param name="route">Die Route, zu der navigiert werden soll (z.B. "/main").</param>
    /// <param name="parameters">Optionale Navigationsparameter (z.B. { ["id"] = 123 }).</param>
    /// <remarks>
    /// Definiert sind diese Ziele: <c>"main"</c>, <c>"login"</c>, <c>"settings"</c>, <c>"detail"</c>, <c>"edit"</c>
    /// </remarks>
    Task NavigateAsync(string route, IDictionary<string, object>? parameters = null);

    // --- Theming ---

    /// <summary>
    /// Liefert die Liste der verfügbaren Theme-Arten, z.B. <c>"Modern"</c>, <c>"Classic"</c>, ...
    /// </summary>
    /// <remarks>
    /// Die Liste wird aus den vorhandenen Theme-ResourceDictionaries abgeleitet.
    /// Mindestens ein Eintrag muss implementiert werden! 
    /// </remarks>
    IReadOnlyList<string> GetThemeKinds();

    /// <summary>
    /// Liefert die Liste der verfügbaren Theme-Modes (üblicherweise <c>"System"</c>, <c>"Light"</c>, <c>"Dark"</c>).
    /// </summary>
    /// <remarks>
    /// Mindestens ein Eintrag muss implementiert werden! 
    /// </remarks>
    IReadOnlyList<string> GetThemeModes();

    /// <summary>
    /// Setzt das Theme.
    /// </summary>
    /// <param name="value">Das Theme im Format "{ThemeKind}.{ThemeMode}", z.B. "Modern.Light"</param>
    Task SetThemeAsync(string value);

    // --- File-Systems ---
    
    /// <summary>
    /// Öffnet den Datei-Picker und gibt Datei-Metadaten + Inhalt zurück.
    /// </summary>
    /// <param name="title">Titel des Pickers.</param>
    /// <returns>Ein File-Objekt oder <c>null</c> bei Abbruch.</returns>
    Task<PickedFileResult?> PickFileAsync(string title);

    /// <summary>
    /// Kopiert Text in die Zwischenablage.
    /// </summary>
    Task CopyToClipboardAsync(string text);

    /// <summary>
    /// Öffnet eine URL im Systembrowser.
    /// </summary>
    Task OpenUrlAsync(string url);

    /// <summary>
    /// Öffnet eine Datei mit der Standard-App (Service kümmert sich um Tempfile und Cleanup).
    /// </summary>
    Task OpenFileAsync(string filename, byte[] content);

    /// <summary>
    /// Speichert eine Datei über einen plattformspezifischen Dialog.
    /// </summary>
    Task<bool> SaveFileAsync(string filename, byte[] content);
    
    // todo in 3 Methoden aufteilen
    /// <summary>
    /// Öffnet die Systemeinstellungen für
    /// Biometrie (um einen Fingerabdruck oder Gesicht zu scannen),
    /// Autofill-Service (um die App als Autofill-Dienst auszuwählen) bzw.
    /// App-Info & Berechtigungen (um Berechtigungen für die App zu aktivieren, z.B. Kamera für QR-Codes). 
    /// </summary>
    /// <param name="action"></param>
    /// <returns></returns>
    Task OpenSystemSettingsAsync(string action);
}