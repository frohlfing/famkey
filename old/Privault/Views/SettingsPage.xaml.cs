using Privault.Core.ViewModels;

#if WINDOWS
using Windows.System;
#endif

namespace Privault.Views;

/// <summary>
/// Code-Behind für die Einstellungsseite.
/// </summary>
public partial class SettingsPage
{
    /// <summary>
    /// Konstruktor
    /// </summary>
    /// <param name="viewModel">Das ViewModel für die Einstellungsseite</param>
	public SettingsPage(SettingsViewModel viewModel)
	{
		InitializeComponent();
		BindingContext = viewModel;
		
        // Initialisierung des ViewModels beim Laden der Seite triggern
        Loaded += async (_, _) => 
        {
            await viewModel.InitializeCommand.ExecuteAsync(null);
        };
        
		// Windows-spezifischer Hack für ESC-Taste
#if WINDOWS
        Loaded += (_, _) => 
        {
            // Wir holen uns das native Windows-Fenster-Element
            if (Handler?.PlatformView is Microsoft.UI.Xaml.UIElement platformView)
            {
                platformView.KeyDown += (_, args) => 
                {
                    if (args.Key == VirtualKey.Escape)
                    {
                        // Command im ViewModel ausführen
                        viewModel.CancelCommand.Execute(null);
                    }
                };
            }
        };
#endif
	}
}