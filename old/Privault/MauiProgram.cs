using Microsoft.Extensions.Logging;
using CommunityToolkit.Maui;
using Privault.Core.Services;
using Privault.Core.Services.Contracts;
using Privault.Core.ViewModels;
using Privault.Services; 
using Privault.Views;

#if WINDOWS
using Microsoft.Maui.LifecycleEvents;
using Microsoft.UI;
using Microsoft.UI.Windowing;
#endif

namespace Privault;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            // Initialisiert das Toolkit (zwingend nötig für MVVM Features)
            .UseMauiCommunityToolkit()
            .ConfigureFonts(fonts =>
            {
                fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
                fonts.AddFont("OpenSans-Semibold.ttf", "OpenSansSemibold");
                
                //  Material Symbol Icons (Outlined, Regular) (https://fonts.google.com/icons?icon.style=Outlined)
                fonts.AddFont("MaterialSymbolsOutlined-Regular.ttf", "MaterialIcons");
                
                // FontAwesome (https://use.fontawesome.com/releases/v6.7.2/fontawesome-free-6.7.2-web.zip)
                // fonts.AddFont("fa-brands-400.ttf", "FaBrands");
                // fonts.AddFont("fa-regular-400.ttf", "FaRegular");
                // fonts.AddFont("fa-solid-900.ttf", "FaSolid");
            });
        
#if WINDOWS
        // Unter Windows das Fenster automatisch maximieren
        builder.ConfigureLifecycleEvents(events =>
        {
            events.AddWindows(wndLifeCycleBuilder =>
            {
                wndLifeCycleBuilder.OnWindowCreated(window =>
                {
                    // 1. Das native Fenster-Handle holen
                    IntPtr nativeWindowHandle = WinRT.Interop.WindowNative.GetWindowHandle(window);
                    
                    // 2. Die WinUI-ID holen
                    WindowId win32WindowsId = Win32Interop.GetWindowIdFromWindow(nativeWindowHandle);
                    
                    // 3. Das AppWindow-Objekt holen (das ist die moderne Windows-Fenster-API)
                    AppWindow winuiAppWindow = AppWindow.GetFromWindowId(win32WindowsId);

                    // 4. Maximieren, falls möglich
                    if (winuiAppWindow.Presenter is OverlappedPresenter p)
                    {
                        p.Maximize();
                        
                        // Optional: Wenn du verhindern willst, dass man es kleiner ziehen kann:
                        // p.IsResizable = false; 
                        // p.IsMinimizable = false;
                    }
                });
            });
        });
#endif

        // ---------------------------------------------------------
        // SERVICES (Dependency Injection)
        // ---------------------------------------------------------

        // HttpClient-Infrastruktur registrieren
        builder.Services.AddHttpClient();

        // Services (Singleton = leben so lange wie die App)
        builder.Services.AddSingleton<IBiometricService, MauiBiometricService>();
        builder.Services.AddSingleton<ICacheService, MauiCacheService>();
        builder.Services.AddSingleton<IConfigService, ConfigService>();
        builder.Services.AddSingleton<ICryptoService, CryptoService>();
        builder.Services.AddSingleton<IDatabaseService>(_ => new DatabaseService(FileSystem.AppDataDirectory));
        builder.Services.AddSingleton<IGuardService, GuardService>();
        builder.Services.AddSingleton<IKeyValueStore, MauiKeyValueStore>();
        builder.Services.AddSingleton<IPasswordService, PasswordService>();
        builder.Services.AddSingleton<ISessionService, SessionService>();
        builder.Services.AddSingleton<ISyncService, SyncService>();
        builder.Services.AddSingleton<IThumbnailService, MauiThumbnailService>();
        builder.Services.AddSingleton<IUiService, MauiUiService>();
        builder.Services.AddSingleton<IWebService, WebService>();
        
        // Pages & ViewModels (Transient = werden bei jedem Aufruf neu erstellt)
        builder.Services.AddTransient<DetailPage>();
        builder.Services.AddTransient<DetailViewModel>();
        builder.Services.AddTransient<EditPage>();
        builder.Services.AddTransient<EditViewModel>();
        builder.Services.AddTransient<LoginPage>();
        builder.Services.AddTransient<LoginViewModel>();
        builder.Services.AddTransient<MainPage>();
        builder.Services.AddTransient<MainViewModel>();
        builder.Services.AddTransient<SettingsPage>();
        builder.Services.AddTransient<SettingsViewModel>();

#if DEBUG
        builder.Logging.AddDebug();
#endif

        return builder.Build();
    }
}