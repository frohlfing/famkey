import 'package:privault/core/app_error.dart';

class EditState {
  /// Gibt an, ob ein Ladesymbol angezeigt wird
  final bool isBusy;

  /// Gibt an, ob die Ansicht im Edit- oder im Insert-Modus ist.
  final bool isEditMode;

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

  /// Die URL des Eintrags (z.B. Login-Seite eines Webdienstes).
  final String url;

  /// Notizen zum Eintrag.
  final String notes;

  /// Der Fehler der letzten Operation.
  final FormError error;

  /// Konstruktor
  const EditState({
    this.isBusy = false,
    this.isEditMode = false,
    this.existingCategories = const [],
    this.entryId = 0,
    this.category = '',
    this.title = '',
    this.username = '',
    this.password = '',
    this.url = '',
    this.notes = '',
    this.error = const FormError.none(),
  });

  EditState copyWith({
    bool? isBusy,
    bool? isEditMode,
    List<String>? existingCategories,
    int? entryId,
    String? category,
    String? title,
    String? username,
    String? password,
    String? url,
    String? notes,
    FormError? error,
  }) {
    return EditState(
      isBusy: isBusy ?? this.isBusy,
      isEditMode: isEditMode ?? this.isEditMode,
      existingCategories: existingCategories ?? this.existingCategories,
      entryId: entryId ?? this.entryId,
      category: category ?? this.category,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      error: error ?? this.error,
    );
  }
}
