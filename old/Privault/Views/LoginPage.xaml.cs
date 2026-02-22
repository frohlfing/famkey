using Privault.Core.ViewModels;

namespace Privault.Views;

/// <summary>
/// Code-Behind für die Loginseite.
/// </summary>
public partial class LoginPage
{
    /// <summary>
    /// Konstruktor
    /// </summary>
    /// <param name="viewModel">Das ViewModel für die Loginseite</param>
    public LoginPage(LoginViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;

        // Initialisierung des ViewModels beim Laden der Seite triggern
        Loaded += async (_, _) => 
        {
            await viewModel.InitializeCommand.ExecuteAsync(null);
        };
        
        // Fokus-Logik für den Vault-Picker
        viewModel.OnVaultPicked += () =>
        {
            PasswordEntry.Focus();
        };
        
        // Nur einmalig beim Laden feuern
        Loaded += (_, _) =>
        {
            // Kleiner Delay für den Render-Zyklus
            Dispatcher.DispatchDelayed(TimeSpan.FromMilliseconds(100), () =>
            {
                if (string.IsNullOrWhiteSpace(VaultNameEntry.Text))
                {
                    VaultNameEntry.Focus();
                }
                else
                {
                    // Cursor ans Ende
                    // ReSharper disable once NullCoalescingConditionIsAlwaysNotNullAccordingToAPIContract
                    PasswordEntry.CursorPosition = (PasswordEntry.Text ?? string.Empty).Length;
                    PasswordEntry.Focus();
                }
            });
        };
    }
}

