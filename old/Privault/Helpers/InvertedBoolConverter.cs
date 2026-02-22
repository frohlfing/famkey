using System.Globalization;

namespace Privault.Helpers;

/// <summary>
/// Invertiert einen booleschen Wert.
/// </summary>
public sealed class InvertedBoolConverter : IValueConverter
{
    /// <summary>
    /// Konvertiert einen booleschen Wert in seinen invertierten Wert.
    /// </summary>
    /// <param name="value">Der zu konvertierende Wert. Wird als <see cref="bool"/> erwartet.</param>
    /// <param name="targetType">(wird nicht verwendet)</param>
    /// <param name="parameter">(wird nicht verwendet)</param>
    /// <param name="culture">(wird nicht verwendet)</param>
    /// <returns>Der invertierte boolesche Wert. Bei <c>null</c> oder unerwarteten Werten wird <c>true</c> zurückgegeben.</returns>
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is bool b) return !b;
        return true; // null/unerwartet => "invertiert" konservativ sichtbar machen
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}