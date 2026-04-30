import 'package:famkey/core/app_error.dart';

/// Ein Enum für den Status von Aktionen
enum CategoryPlaceholderActionStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft
  loaded, // Einstellungen wurden erfolgreich geladen
  saved, // Änderungen wurden erfolgreich gespeichert
  failure, // Aktion mit Fehler beendet
}

class CategoryPlaceholderState {

  /// Die Formulardaten.
  final String categoryPlaceholder;

  /// Die ursprünglichen Formulardaten (für den Dirty-Check).
  final String originalCategoryPlaceholder;

  /// Der Status der letzten Aktion.
  final CategoryPlaceholderActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy =>
    status == CategoryPlaceholderActionStatus.progress;

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isDirty => categoryPlaceholder != originalCategoryPlaceholder;

  /// Konstruktor
  const CategoryPlaceholderState({
    this.categoryPlaceholder = '',
    this.originalCategoryPlaceholder = '',
    this.status = CategoryPlaceholderActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  CategoryPlaceholderState copyWith({
    String? categoryPlaceholder,
    String? originalCategoryPlaceholder,
    CategoryPlaceholderActionStatus? status,
    AppError? error,
  }) {
    return CategoryPlaceholderState(
      categoryPlaceholder: categoryPlaceholder ?? this.categoryPlaceholder,
      originalCategoryPlaceholder: originalCategoryPlaceholder ?? this.originalCategoryPlaceholder,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
