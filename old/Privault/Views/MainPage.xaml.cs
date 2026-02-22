using CommunityToolkit.Maui.Views;
using Privault.Core.ViewModels;

namespace Privault.Views;

/// <summary>
/// Code-Behind für die Hauptseite.
/// </summary>
public partial class MainPage
{
	/// <summary>
	/// Konstruktor
	/// </summary>
	/// <param name="viewModel">Das ViewModel für die Hauptseite</param>
    public MainPage(MainViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;

		// Initialisierung des ViewModels beim Laden der Seite triggern
		Loaded += async (_, _) => 
		{
			await viewModel.InitializeCommand.ExecuteAsync(null);
		};

        // Dadurch stürzt die App hin und wieder ab, wenn man die Seiten nach einer längeren Wartezeit wechselt :-(
		// Fokus auf die SearchBar setzen, wenn die Seite geladen ist
        //Loaded += (_, _) =>
        //{
        //	Dispatcher.DispatchDelayed(TimeSpan.FromMilliseconds(100), () =>
        //	{
        //		SearchBar.Focus();
        //	});
        //};
    }

    private void MenuButton_OnClicked(object? sender, EventArgs e)
    {
        var popup = new MainMenuPopup { Anchor = MenuButton };
        this.ShowPopup(popup);
    }

}