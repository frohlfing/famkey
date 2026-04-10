import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/settings/user_name/user_name_state.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';

final userNameProvider = NotifierProvider<UserNameNotifier, UserNameState>(() {
  return UserNameNotifier();
});

class UserNameNotifier extends Notifier<UserNameState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final DatabaseService _databaseService;
  late final SessionService _sessionService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen (nicht reaktiv, nicht UI‑relevant) ---
  // ------------------------------------------------------------------------

  /// Die Datenbank-Entität.
  UserEntity? _user;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
  ///
  /// Die Verwendung von `Ref.watch` oder `Ref.listen` innerhalb dieser Methode ist unbedenklich.
  /// Ändert sich eine Abhängigkeit dieses Notifiers (bei Verwendung von `Ref.watch`), wird der Build-Prozess erneut ausgeführt. Der Notifier selbst wird jedoch nicht neu erstellt. Seine Instanz bleibt zwischen den Build-Ausführungen erhalten.
  @override
  UserNameState build() {
    // Dienste aus getIt holen
    _databaseService = getIt<DatabaseService>();
    _sessionService = getIt<SessionService>();

    // Initialer State
    return UserNameState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    if (state.isBusy) return;

    // UI-State zurücksetzen
    state = const UserNameState().copyWith(status: UserNameActionStatus.progress);
    
    try {
      // Daten aus der Datenbank laden
      _user = await _databaseService.getUser(1);
      if (_user == null) throw Exception('Benutzer ID=1 nicht gefunden.'); // wird bereits direkt beim Erzeugen des Tresors angelegt

      // UI-State aktualisieren
      state = state.copyWith(
        userName: _user!.name,
        originalUserName: _user!.name,
        status: UserNameActionStatus.loaded,
      );

    } catch (e, st) {
      Logger().fatal('Fehler beim Laden: $e', stack: st);
      state = state.copyWith(status: UserNameActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Speichern ---
  // ------------------------------------------------------------------------

  /// Benennt den Benutzer um.
  Future<void> save() async {
    if (state.isBusy) return;

    // 1. Benutzereingabe bereinigen
    final userName = state.userName.trim();

    // 2. UI-State aktualisieren
    state = state.copyWith(
      userName: userName,
      status: UserNameActionStatus.progress, error: AppError.none(),
    );

    try {

      // 3. Benutzereingabe validieren
      if (userName.isEmpty) {
        state = state.copyWith(status: UserNameActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'userName'));
        return;
      }

      // 4. Datenbank und Session aktualisieren
      if (userName != state.originalUserName) {
        if (_user == null) throw Exception("Die Benutzerdaten sind nicht geladen.");
        final updatedUser = _user!.copyWith(
          name: userName,
        );
        _user = await _databaseService.saveUser(updatedUser);
        _sessionService.setUser(_user!);
      }

      // 5. UI-State aktualisieren
      state = state.copyWith(
        originalUserName: userName,
        status: UserNameActionStatus.saved,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(status: UserNameActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für Benutzername
  void setUserName(String value) {
    final error = state.error.field == 'userName' ? AppError.none() : null;
    state = state.copyWith(userName: value, error: error);
  }
}
