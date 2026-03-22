import 'package:privault/core/app_error.dart';
import 'package:privault/features/edit/edit_form_data.dart';

/// Ein Enum für den Status von Aktionen
enum EditActionStatus {
  initial, // Der Ausgangszustand
  // todo Unterscheidung notwendig?
  loading, // Eintrag wird geladen
  creating, // Neuer Eintrag wird gespeichert
  updating, // Bestehender Eintrag wird gespeichert
  deleting, // Eintrag wird gelöscht
  loaded, // Eintrag wurde erfolgreich geladen
  saved, // Eintrag wurde erfolgreich gespeichert
  deleted, // Eintrag wurde erfolgreich gelöscht
  failure, // Aktion mit Fehler beendet
}

/// Der State beinhaltet alles, was die UI wissen muss.
class EditState {

  /// Liste der bereits im Tresor vorhandenen Kategorien für die Autovervollständigung.
  final List<String> existingCategories;

  /// Die interne ID des Eintrags.
  /// 0 für neue Einträge, bevor der Eintrag in die Datenbank geschrieben wird.
  final int entryId;

  /// Die Formulardaten.
  final EditFormData formData;

  /// Der ursprünglichen Formulardaten (für den Dirty-Check).
  final EditFormData originalFormData;

  /// Die berechnete Passwortstärke.
  final int passwordStrength;

  /// Der Status der letzten Aktion.
  final EditActionStatus status;

  /// Der Fehler der letzten Aktion.
  final FormError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy =>
    status == EditActionStatus.loading ||
    status == EditActionStatus.creating ||
    status == EditActionStatus.updating ||
    status == EditActionStatus.deleting;

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isDirty => formData != originalFormData;

  /// Gibt an, ob die Ansicht im Edit- oder im Insert-Modus ist.
  bool get isEditMode => entryId > 0;

  /// Gibt den Titel für die AppBar zurück.
  String get displayTitle => formData.title.trim().isEmpty ? (isEditMode ? 'Eintrag bearbeiten' : 'Neuer Eintrag') : formData.title.trim();

  /// Konstruktor
  const EditState({
    this.existingCategories = const [],
    this.entryId = 0,
    this.formData = const EditFormData(),
    this.originalFormData = const EditFormData(),
    this.passwordStrength = 0,
    this.status = EditActionStatus.initial,
    this.error = const FormError.none(),
  });

  /// Status aktualisieren (immutable)
  EditState copyWith({
    List<String>? existingCategories,
    int? entryId,
    EditFormData? formData,
    EditFormData? originalFormData,
    int? passwordStrength,
    EditActionStatus? status,
    FormError? error,
  }) {
    return EditState(
      existingCategories: existingCategories ?? this.existingCategories,
      entryId: entryId ?? this.entryId,
      formData: formData ?? this.formData,
      originalFormData: originalFormData ?? this.originalFormData,
      passwordStrength: passwordStrength ?? this.passwordStrength,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
