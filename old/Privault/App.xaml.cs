using Privault.Core.Services.Contracts;

namespace Privault;

public partial class App
{
    public App(IConfigService configService, IUiService uiService)
    {
        InitializeComponent();
        var theme = configService.Theme;
        _ = uiService.SetThemeAsync(theme);
        MainPage = new AppShell();
    }
}