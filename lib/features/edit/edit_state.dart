import 'package:privault/core/app_error.dart';
import 'package:privault/models/payloads/entry_payload.dart';

/// Ein Enum für den Status von Aktionen
enum EditActionStatus {
  initial, // Der Ausgangszustand
  loading, // load() wird ausgeführt
  creating, // save() wird im Insert-Modus ausgeführt
  updating, // save() wird im Edit-Modus ausgeführt
  deleting, // delete() wird ausgeführt
  loadSuccess,
  saveSuccess,
  deleteSuccess,
  failure,
}

/// Der State beinhaltet alles, was die UI wissen muss.
class EditState {

  /// Liste der bereits im Tresor vorhandenen Kategorien für die Autovervollständigung.
  final List<String> existingCategories;

  /// Die interne ID des Eintrags.
  /// 0 für neue Einträge, bevor der Eintrag in die Datenbank geschrieben wird.
  final int entryId;

  /// Die Kategorie des Eintrags.
  final String category;

  /// Der Titel des Eintrags.
  final String title;

  /// Der Benutzername des Eintrags.
  final String username;

  /// Das Passwort des Eintrags.
  final String password;

  /// Die berechnete Passwortstärke
  final int passwordStrength;

  /// Die URL des Eintrags (z.B. Login-Seite eines Webdienstes).
  final String url;

  /// Notizen zum Eintrag.
  final String notes;

  /// Der ursprüngliche Payload für den Dirty-Check
  final EntryPayload? originalPayload;

  /// Der Status der letzten Aktion.
  final EditActionStatus status;

  /// Der Fehler der letzten Aktion.
  final FormError error;

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy =>
      status == EditActionStatus.loading ||
      status == EditActionStatus.creating ||
      status == EditActionStatus.updating ||
      status == EditActionStatus.deleting;

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isDirty {
    if (originalPayload == null) {
      // Neuer Eintrag
      return category.isNotEmpty ||
          title.isNotEmpty ||
          username.isNotEmpty ||
          password.isNotEmpty ||
          url.isNotEmpty ||
          notes.isNotEmpty;
    }
    return category != originalPayload!.category ||
        title != originalPayload!.title ||
        username != originalPayload!.username ||
        password != originalPayload!.password ||
        url != originalPayload!.url ||
        notes != originalPayload!.notes;
  }

  /// Gibt an, ob die Ansicht im Edit- oder im Insert-Modus ist.
  bool get isEditMode => entryId > 0;

  /// Gibt den Titel für die AppBar zurück.
  String get displayTitle => title.isEmpty ? (isEditMode ? 'Eintrag bearbeiten' : 'Neuer Eintrag') : title;

  /// Konstruktor
  const EditState({
    this.existingCategories = const [],
    this.entryId = 0,
    this.category = '',
    this.title = '',
    this.username = '',
    this.password = '',
    this.passwordStrength = 0,
    this.url = '',
    this.notes = '',
    this.originalPayload,
    this.status = EditActionStatus.initial,
    this.error = const FormError.none(),
  });

  /// Status aktualisieren (immutable)
  EditState copyWith({
    List<String>? existingCategories,
    int? entryId,
    String? category,
    String? title,
    String? username,
    String? password,
    int? passwordStrength,
    String? url,
    String? notes,
    EntryPayload? originalPayload,
    EditActionStatus? status,
    FormError? error,
  }) {
    return EditState(
      existingCategories: existingCategories ?? this.existingCategories,
      entryId: entryId ?? this.entryId,
      category: category ?? this.category,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      passwordStrength: passwordStrength ?? this.passwordStrength,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      originalPayload: originalPayload ?? this.originalPayload,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
