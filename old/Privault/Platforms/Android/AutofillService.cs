using Android.App;
using Android.Service.Autofill;
//using Android.Views.Autofill;
using Android.OS;
//using Android.Runtime;
using Privault.Core.Services.Contracts;
using System.Runtime.Versioning;

namespace Privault;

[SupportedOSPlatform("android26.0")] // Autofill gibt es erst ab Android 8.0 (API 26)
[Service(Name = "com.privault.app.PrivaultAutofillService", 
         Permission = Android.Manifest.Permission.BindAutofillService, 
         Exported = true)]
[IntentFilter(["android.service.autofill.AutofillService"])]
public class PrivaultAutofillService : AutofillService
{
    private IDatabaseService? _databaseService;
    private ISessionService? _sessionService;

    public override void OnCreate()
    {
        base.OnCreate();
        
        // Services über den MAUI-Resolver holen
        var services = IPlatformApplication.Current?.Services;
        _databaseService = services?.GetService<IDatabaseService>();
        _sessionService = services?.GetService<ISessionService>();
    }

    /// <summary>
    /// Wird aufgerufen, wenn Android Daten zum Ausfüllen benötigt.
    /// </summary>
    public override void OnFillRequest(FillRequest request, CancellationSignal cancellationSignal, FillCallback callback)
    {
        // Wir nutzen Task.Run, um den UI-Thread nicht zu blockieren und async-Logik zu erlauben
        Task.Run(async () =>
        {
            try
            {
                await HandleFillRequestAsync(request, callback);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Autofill Fehler: {ex.Message}");
                // Im Fehlerfall muss die Callback-Methode trotzdem aufgerufen werden
                callback.OnSuccess(null);
            }
        });
    }

    /// <summary>
    /// Wird aufgerufen, wenn der Benutzer Daten in einer anderen App speichert.
    /// </summary>
    public override void OnSaveRequest(SaveRequest request, SaveCallback callback)
    {
        // Aktuell quittieren wir Speicheranfragen nur als erfolgreich
        callback.OnSuccess();
    }

    private async Task HandleFillRequestAsync(FillRequest request, FillCallback callback)
    {
        // 1. Kontext extrahieren
        var contexts = request.FillContexts;
        if (contexts.Count == 0)
        {
            callback.OnSuccess(null);
            return;
        }

        // Die letzte View-Struktur enthält meist die aktuellen Eingabefelder
        var structure = contexts[^1].Structure;
        var packageName = structure.ActivityComponent?.PackageName;

        // 2. Sicherheitscheck: Ist der User eingeloggt?
        if (_sessionService == null || !_sessionService.IsLoggedIn || string.IsNullOrEmpty(packageName))
        {
            callback.OnSuccess(null);
            return;
        }

        // 3. Suche nach passenden Einträgen im Tresor
        if (_databaseService != null)
        {
            var entries = await _databaseService.GetEntriesAsync();
            // Suche nach Einträgen, deren URL den Paketnamen der App enthält (z.B. "com.facebook.katana")
            var matchingEntry = entries.FirstOrDefault(e => e.Url.Contains(packageName));

            if (matchingEntry != null)
            {
                // TODO: Hier würde die Entschlüsselung und das Erstellen des Dataset erfolgen
                // Da dies sehr komplex ist (View-Parsing), senden wir vorerst null.
                callback.OnSuccess(null);
                return;
            }
        }

        callback.OnSuccess(null);
    }
}