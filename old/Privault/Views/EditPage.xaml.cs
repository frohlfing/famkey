using Privault.Core.ViewModels;

#if WINDOWS
using Windows.System;
#endif

namespace Privault.Views;

/// <summary>
/// Code-Behind für die Editierseite.
/// </summary>
public partial class EditPage : IQueryAttributable
{
    /// <summary>
    /// Konstruktor
    /// </summary>
    /// <param name="viewModel">Das ViewModel für die Editierseite</param>
    public EditPage(EditViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;
		
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

    /// <summary>
    /// Leitet die Navigationsattribute an das ViewModel weiter.
    /// <para>
    /// Diese Methode wird automatisch aufgerufen, weil die Klasse <c>IQueryAttributable</c> implementiert.
    /// </para>
    /// </summary>
    public void ApplyQueryAttributes(IDictionary<string, object> query)
    {
        if (BindingContext is EditViewModel vm)
        {
            vm.InitializeCommand.Execute(query);
        }
    }
}