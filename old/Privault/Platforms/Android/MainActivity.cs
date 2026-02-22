using Android.App;
using Android.Content.PM;
using Android.OS;
using Android.Views;
using Plugin.Fingerprint;

namespace Privault;

[Activity(
    Theme = "@style/Maui.SplashTheme",
    MainLauncher = true,
    LaunchMode = LaunchMode.SingleTop,
    ConfigurationChanges = ConfigChanges.ScreenSize | ConfigChanges.Orientation | ConfigChanges.UiMode |
                           ConfigChanges.ScreenLayout | ConfigChanges.SmallestScreenSize | ConfigChanges.Density,
    WindowSoftInputMode = SoftInput.AdjustResize // Aktiviert automatische Anpassung des Fensters beim Einblenden der Tastatur
)]
public class MainActivity : MauiAppCompatActivity
{
    protected override void OnCreate(Bundle? savedInstanceState)
    {
        base.OnCreate(savedInstanceState);

        // Dem Fingerprint-Plugin diese Funktion als Resolver angeben. 
        // Das Plugin ruft diese Funktion später auf, wenn es eine Activity braucht.
        CrossFingerprint.SetCurrentActivityResolver(() => this);
    }
    
    protected override void OnResume()
    {
        base.OnResume();
        // (optional, aber sinnvoll): Fingerprint-Resolver nach Resume erneut setzen
        CrossFingerprint.SetCurrentActivityResolver(() => this);
    }
}