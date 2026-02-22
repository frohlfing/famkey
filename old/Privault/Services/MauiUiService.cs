using System.Reflection;
using CommunityToolkit.Maui.Alerts;
using Privault.Core.Models.Results;
using Privault.Core.Services.Contracts;

namespace Privault.Services;

/// <summary>
/// MAUI-Implementierung für UI-Interaktionen über Shell.Current.
/// </summary>
public sealed class MauiUiService : IUiService
{
    // ------------------------------------------------------------------------
    // --- Konstanten und Felder ---
    // ------------------------------------------------------------------------
    
    // --- Theme Katalog (Auto-Discovery) ---
    
    private Dictionary<(string Kind, string Mode), Type> _themeTypes = new();
    
    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------
    
    // --- Dialoge & Feedback ---
    
    /// <inheritdoc />
    public Task<string?> PromptAsync(string title, string message, string accept = "OK", string cancel = "Abbrechen") =>
        //Shell.Current.DisplayPromptAsync(title, message, accept, cancel);
        MainThread.InvokeOnMainThreadAsync(() => Shell.Current.DisplayPromptAsync(title, message, accept, cancel));

    /// <inheritdoc />
    public Task AlertAsync(string title, string message) =>
        //Shell.Current.DisplayAlert(title, message, "OK");
        MainThread.InvokeOnMainThreadAsync(() => Shell.Current.DisplayAlert(title, message, "OK"));
    
    /// <inheritdoc />
    public Task InfoAsync(string message) =>
        //Shell.Current.DisplayAlert("Info", message, "OK");
        MainThread.InvokeOnMainThreadAsync(() => Shell.Current.DisplayAlert("Info", message, "OK"));
    
    /// <inheritdoc />
    public Task ErrorAsync(string message) =>
        //Shell.Current.DisplayAlert("Fehler", message, "OK");
        MainThread.InvokeOnMainThreadAsync(() => Shell.Current.DisplayAlert("Fehler", message, "OK"));
    
    /// <inheritdoc />
    public Task<bool> ConfirmAsync(string title, string message, string accept, string cancel) =>
        //Shell.Current.DisplayAlert(title, message, accept, cancel);
        MainThread.InvokeOnMainThreadAsync(() => Shell.Current.DisplayAlert(title, message, accept, cancel));

    /// <inheritdoc />
    public Task<string?> ActionSheetAsync(string title, string cancel, string? destruction, params string[] buttons) =>
        //Shell.Current.DisplayActionSheet(title, cancel, destruction, buttons);
        MainThread.InvokeOnMainThreadAsync(() => Shell.Current.DisplayActionSheet(title, cancel, destruction, buttons));

    /// <inheritdoc />
    public Task ToastAsync(string message) =>
        //Toast.Make(message).Show();
        MainThread.InvokeOnMainThreadAsync(() => Toast.Make(message).Show());

    // --- Navigation ---
    
    /// <inheritdoc />
    public Task NavigateAsync(string route, IDictionary<string, object>? parameters = null)
    {
        if (string.IsNullOrWhiteSpace(route))
            throw new ArgumentException("Route darf nicht leer sein.", nameof(route));
        
        // Sicherheitshalber auf dem UI-Thread ausführen
        return MainThread.InvokeOnMainThreadAsync(async () =>
        {
            if (Shell.Current == null)
                throw new InvalidOperationException("Shell.Current ist nicht verfügbar.");

            var animate = !OperatingSystem.IsWindows();
            
            // Sonderfall: Zurück
            if (route == "..")
            {
                if (parameters == null)
                    await Shell.Current.GoToAsync(new ShellNavigationState(".."), animate);
                else
                    await Shell.Current.GoToAsync(new ShellNavigationState(".."), animate, parameters);

                // if (parameters == null)
                //     await Shell.Current.GoToAsync("..");
                // else
                //     await Shell.Current.GoToAsync("..", parameters);

                return;
            }
            
            var isAbsolute = route.StartsWith('/');
            var key = route.Trim('/');
            var viewName = $"{char.ToUpper(key[0])}{key.Substring(1).ToLower()}Page"; // erster Buchstabe groß, Rest klein
            if (isAbsolute)
                viewName = $"///{viewName}";

            if (parameters == null)
                await Shell.Current.GoToAsync(new ShellNavigationState(viewName), animate);
            else
                await Shell.Current.GoToAsync(new ShellNavigationState(viewName), animate, parameters);

            // if (parameters == null)
            //     await Shell.Current.GoToAsync(viewName);
            // else
            //     await Shell.Current.GoToAsync(viewName, parameters);
        });
    }

    // --- Theming ---

    /// <inheritdoc />
    public IReadOnlyList<string> GetThemeKinds()
    {
        if (_themeTypes.Count == 0)
            LoadThemeTypes();
        
        return _themeTypes.Keys
            .Select(k => k.Kind)
            .Distinct(StringComparer.Ordinal)
            .OrderBy(k => k == "Modern" ? string.Empty : k, StringComparer.Ordinal)
            .ToList();
    }

    /// <inheritdoc />
    public IReadOnlyList<string> GetThemeModes()
    {
        // Theme-Modes sind konzeptionell immer: System, Light, Dark
        return new List<string> { "System", "Light", "Dark" };
    }
    
    /// <inheritdoc />
    public Task SetThemeAsync(string value)
    {
        // 1. Parameter validieren und in Theme-Art und -Mode aufteilen.
        var kinds = GetThemeKinds();
        var modes = GetThemeModes();
        if (string.IsNullOrWhiteSpace(value))
            value = $"{kinds[0]}.{modes[0]}";
        var parts = value.Trim().Split('.', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        var kind = parts.Length >= 1 && kinds.Contains(parts[0]) ? parts[0] : kinds[0];
        var mode = parts.Length >= 2 && modes.Contains(parts[1]) ? parts[1] : modes[0];

        // Theme anwenden
        return MainThread.InvokeOnMainThreadAsync(() =>
        {
            var app = Application.Current;
            if (app == null) return;

            // 1) AppTheme setzen (beeinflusst u.a. AppThemeBinding und RequestedTheme)
            app.UserAppTheme = mode switch
            {
                "Light" => AppTheme.Light,
                "Dark" => AppTheme.Dark,
                _ => AppTheme.Unspecified
            };

            // 2) Effektiven Modus bestimmen (System -> abhängig vom OS)
            var effectiveMode = mode != "System" ? mode : (app.RequestedTheme == AppTheme.Dark ? "Dark" : "Light");

            // 3) Bisheriges Theme-Dictionary entfernen.
            // Wir entfernen alle Dictionaries, die wir als "Theme-Dictionaries" erkannt haben.
            // Dadurch muss beim Hinzufügen eines neuen Themes kein Code angepasst werden.
            
            // Alle tatsächlich bekannten Theme-ResourceDictionaries ergeben sich aus den Value-Types der Map.
            // Damit müssen wir nirgendwo Klassen einzeln aufzählen.
            if (_themeTypes.Count == 0) 
                LoadThemeTypes();
            var themeTypes = _themeTypes.Values.ToHashSet();
            var merged = app.Resources.MergedDictionaries;
            var toRemove = merged.Where(rd => rd != null && themeTypes.Contains(rd.GetType())).ToList();
            foreach (var rd in toRemove)
                merged.Remove(rd);

            // 4) Neues Theme-Dictionary hinzufügen (ohne Source-Setter!)
            if (_themeTypes.TryGetValue((kind, effectiveMode), out var type))
            {
                var instance = Activator.CreateInstance(type);
                if (instance is not ResourceDictionary dictionary)
                    throw new InvalidOperationException($"ResourceDictionary-Instanz vom Typ {type.FullName} konnte nicht erstellt werden.");
                merged.Add(dictionary);
            }
        });
    }
    
    // --- File-Systems ---
   
    /// <inheritdoc />
    public async Task<PickedFileResult?> PickFileAsync(string title)
    {
        var result = await FilePicker.Default.PickAsync(new PickOptions { PickerTitle = title });
        if (result == null) return null;

        await using var stream = await result.OpenReadAsync();
        using var ms = new MemoryStream();
        await stream.CopyToAsync(ms);

        return new PickedFileResult
        {
            Filename = result.FileName,
            Mime = result.ContentType,
            Content = ms.ToArray()
        };
    }

    /// <inheritdoc />
    public Task CopyToClipboardAsync(string text) =>
        Clipboard.Default.SetTextAsync(text);

    /// <inheritdoc />
    public async Task OpenUrlAsync(string url)
    {
        if (string.IsNullOrWhiteSpace(url)) return;

        var uriString = url.StartsWith("http", StringComparison.OrdinalIgnoreCase)
            ? url
            : "https://" + url;

        await Browser.Default.OpenAsync(uriString, BrowserLaunchMode.SystemPreferred);
    }

    /// <inheritdoc />
    public async Task OpenFileAsync(string filename, byte[] content)
    {
        // Tempfile schreiben
        var safeName = string.IsNullOrWhiteSpace(filename) ? "file.bin" : filename;
        var path = Path.Combine(FileSystem.CacheDirectory, safeName);

        await File.WriteAllBytesAsync(path, content);

        try
        {
            await Launcher.Default.OpenAsync(new OpenFileRequest
            {
                File = new ReadOnlyFile(path),
                Title = safeName
            });
        }
        finally
        {
            // Best-effort Cleanup mit Retry (weil Datei evtl. noch gelockt ist)
            _ = Task.Run(async () =>
            {
                for (var i = 0; i < 10; i++)
                {
                    await Task.Delay(2000);
                    try
                    {
                        if (File.Exists(path))
                            File.Delete(path);
                        break;
                    }
                    catch
                    {
                        // retry
                    }
                }
            });
        }
    }

    /// <inheritdoc />
    public async Task<bool> SaveFileAsync(string filename, byte[] content)
    {
#if IOS || MACCATALYST
        if (!OperatingSystem.IsIOSVersionAtLeast(14) && !OperatingSystem.IsMacCatalystVersionAtLeast(14))
            return false;
#endif
        try
        {
            using var stream = new MemoryStream(content);

#pragma warning disable CA1416
            var result = await CommunityToolkit.Maui.Storage.FileSaver.Default.SaveAsync(filename, stream, CancellationToken.None);
#pragma warning restore CA1416

            return result.IsSuccessful;
        }
        catch
        {
            return false;
        }
    }
    
    /// <inheritdoc />
    public async Task OpenSystemSettingsAsync(string action)
    {
#if ANDROID
    // var context = Android.App.Application.Context;
    // string intentStr = action switch
    // {
    //     "biometrics" => Android.Provider.Settings.ActionSecuritySettings,
    //     "autofill" => Android.Provider.Settings.ActionAutofillSettings,
    //     _ => Android.Provider.Settings.ActionApplicationDetailsSettings
    // };
    //
    // var intent = new Android.Content.Intent(intentStr);
    // if (action == "app_info")
    // {
    //     var uri = Android.Net.Uri.FromParts("package", context.PackageName, null);
    //     intent.SetData(uri);
    // }
    // intent.AddFlags(Android.Content.ActivityFlags.NewTask);
    // context.StartActivity(intent);

#elif IOS || MACCATALYST
    // string url = action switch
    // {
    //     "autofill" => "App-Prefs:root=PASSWORDS", // Achtung: Private API, Nutzung auf eigene Gefahr
    //     _ => Foundation.NSUrl.FromString(UIKit.UIApplication.OpenSettingsUrlString).ToString()
    // };
    // await Launcher.OpenAsync(url);

#elif WINDOWS
        string uri = action switch
        {
            "biometrics" => "ms-settings:signinoptions",
            "autofill" => "https://support.microsoft.com/de-de/windows/ausf%C3%BCllen-von-formularen-mit-microsoft-autofill-64eb7382-777e-400a-8671-8884976c666e",
            _ => "ms-settings:appsfeatures-app"
        };
        await Launcher.OpenAsync(uri);
#endif

        await Task.CompletedTask;
    }
    
    // ------------------------------------------------------------------------
    // --- Private Methoden ---
    // ------------------------------------------------------------------------

    // --- Theme Katalog (Auto-Discovery) ---
    
    /// <summary>
    /// Lädt per Reflection die ResourceDictionary-Typen für Themes und speichert sie im internen Cache <c>_themeTypes</c>.
    /// </summary>
    /// <remarks>
    /// Die Klassen (aus <c>x:Class</c>) müssen im Namespace <c>Privault.Resources.Styles.Themes</c>
    /// liegen und <c>ModernLight</c>, <c>ModernDark</c>, <c>ClassicLight</c> usw. heißen.
    /// </remarks>
    private void LoadThemeTypes()
    {
        // 1. Alle ResourceDictionary-Typen im Namensraum Privault.Resources.Styles.Themes ermitteln
        
        var themeTypeList = new List<Type>();

        // Alle Assemblys durchlaufen
        const string themeNamespace = "Privault.Resources.Styles.Themes";
        var assemblies = AppDomain.CurrentDomain.GetAssemblies();
        foreach (var asm in assemblies)
        {
            Type[] types;
            try
            {
                types = asm.GetTypes();
            }
            catch (ReflectionTypeLoadException ex)
            {
                types = ex.Types.Where(t => t != null).Cast<Type>().ToArray();
            }
            catch
            {
                continue;
            }
            
            // ALle Typen im Assemblys durchlaufen
            foreach (var t in types)
            {
                if (t.IsAbstract) continue;
                if (t.Namespace != themeNamespace) continue;
                if (!typeof(ResourceDictionary).IsAssignableFrom(t)) continue;
                themeTypeList.Add(t); // Type ist im richtigen Namensraum und ist ein ResourceDictionary
            }
        }
        
        // 2. Die Typen-Liste zum Dictionary umwandeln (mit Theme-Art und -Mode als Schlüssel)

        // Namenskonvention: Klasse = "{ThemeKind}{ThemeMode}" z.B. "ModernLight", "ModernDark".
        var themeTypeDict = new Dictionary<(string Kind, string Mode), Type>();
        foreach (var t in themeTypeList)
        {
            var name = t.Name;
            string kind;
            string mode;
            if (name.EndsWith("Light", StringComparison.Ordinal))
            {
                kind = name.Substring(0, name.Length - "Light".Length);
                mode = "Light";
            }
            else if (name.EndsWith("Dark", StringComparison.Ordinal))
            {
                kind = name.Substring(0, name.Length - "Dark".Length);
                mode = "Dark";
            }
            else
            {
                // Unbekanntes Suffix -> ignorieren (damit zufällige Dictionaries im Namespace nicht stören).
                continue;
            }

            if (string.IsNullOrWhiteSpace(kind))
                continue;

            themeTypeDict[(kind, mode)] = t;
        }

        // Modern.Light und Modern.Dark werden vorausgesetzt (Baseline für eure App).
        if (!themeTypeDict.ContainsKey(("Modern", "Light")) || !themeTypeDict.ContainsKey(("Modern", "Dark")))
            throw new InvalidOperationException("Die Themes Modern.Light.xaml und Modern.Dark.xaml sind erforderlich.");

        // Ergebnis veröffentlichen (atomar genug für unseren Anwendungsfall, da Lazy einmalig aufgerufen wird)
        _themeTypes = themeTypeDict;
    }
}