using Privault.Views;

namespace Privault;

public partial class AppShell
{
    public AppShell()
    {
        InitializeComponent();
        Routing.RegisterRoute(nameof(DetailPage), typeof(DetailPage));
        Routing.RegisterRoute(nameof(EditPage), typeof(EditPage));
        Routing.RegisterRoute(nameof(SettingsPage), typeof(SettingsPage));
    }
}