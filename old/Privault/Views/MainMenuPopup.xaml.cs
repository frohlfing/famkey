namespace Privault.Views;

public partial class MainMenuPopup
{
    public MainMenuPopup()
    {
        InitializeComponent();

        Popup.Loaded += (_, _) => ApplyPosition();
        //PopupBorder.SizeChanged += (_, _) => ApplyPosition();
    }

    void ApplyPosition()
    {
        var offset = 20;
        Popup.TranslationX = (Popup.WidthRequest - (Anchor?.Width ?? 0)) / 2 - offset;
    }

    private void Button_OnClicked(object? sender, EventArgs e)
    {
        Close();
    }
}