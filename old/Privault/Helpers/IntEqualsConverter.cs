using System.Globalization;

namespace Privault.Helpers;

/// <summary>
/// Invertiert einen Integer-Wert.
/// </summary>
public class IntEqualsConverter : IValueConverter
{
    /// <summary>
    /// Konvertiert einen Integer in einen booleschen Wert.
    /// </summary>
    /// <param name="value">Der zu konvertierende Wert. Wird als <see cref="int"/> erwartet.</param>
    /// <param name="targetType">(wird nicht verwendet)</param>
    /// <param name="parameter">(wird nicht verwendet)</param>
    /// <param name="culture">(wird nicht verwendet)</param>
    /// <returns>Der invertierte Wert. Bei <c>null</c> oder unerwarteten Werten wird <c>false</c> zurückgegeben.</returns>
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is int i && parameter is not null && int.TryParse(parameter.ToString(), out var p))
            return i == p;

        return false;
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is bool isChecked && isChecked && parameter is not null && int.TryParse(parameter.ToString(), out var p))
            return p;

        return Binding.DoNothing;
    }
}