using System.Globalization;

namespace Privault.Helpers;

/// <summary>
/// Konvertiert den Icon-Typ in den entsprechenden Dateinamen und zurück.
/// </summary>
public sealed class IconTypeToImageSourceConverter : IValueConverter
{
    /// <summary>
    /// Konvertiert einen Icon-Typ in die entsprechende Bildquelle.
    /// </summary>
    /// <param name="value">Der Icon-Typ. </param>
    /// <param name="targetType">Wird nicht verwendet. </param>
    /// <param name="parameter">Wird nicht verwendet </param>
    /// <param name="culture">Wird nicht verwendet </param>
    /// <returns> Eine <see cref="ImageSource"/> für die Datei "file_{value}.png". </returns>
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        return ImageSource.FromFile($"file_{value}.png");
    }

    /// <summary>
    /// Konvertiert einen Dateinamen in den Icon-Typ.
    /// </summary>
    /// <param name="value"> Der Dateiname Format "file_{iconType}.png". </param>
    /// <param name="targetType">(wird nicht verwendet). </param>
    /// <param name="parameter">(wird nicht verwendet). </param>
    /// <param name="culture">(wird nicht verwendet). </param>
    /// <returns> Der extrahierte Icon-Typ. </returns>
    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        var v = (string)value!;
        return v.Substring(5, v.Length - 9);
    }
}