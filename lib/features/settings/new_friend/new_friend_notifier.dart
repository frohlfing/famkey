import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/core/app_error.dart';
import 'package:famkey/core/logger.dart';
import 'package:famkey/core/service_locator.dart';
import 'package:famkey/database/database.dart';
import 'package:famkey/features/settings/new_friend/new_friend_state.dart';
import 'package:famkey/services/database_service.dart';
import 'package:famkey/services/session_service.dart';
import 'package:famkey/services/web_service.dart';

final newFriendProvider = NotifierProvider<NewFriendNotifier, NewFriendState>(() {
  return NewFriendNotifier();
});

class NewFriendNotifier extends Notifier<NewFriendState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final DatabaseService _databaseService;
  late final SessionService _sessionService;
  late final WebService _webService;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
  ///
  /// Die Verwendung von `Ref.watch` oder `Ref.listen` innerhalb dieser Methode ist unbedenklich.
  /// Ändert sich eine Abhängigkeit dieses Notifiers (bei Verwendung von `Ref.watch`), wird der Build-Prozess erneut ausgeführt. Der Notifier selbst wird jedoch nicht neu erstellt. Seine Instanz bleibt zwischen den Build-Ausführungen erhalten.
  @override
  NewFriendState build() {
    // Dienste aus getIt holen
    _databaseService = getIt<DatabaseService>();
    _sessionService = getIt<SessionService>();
    _webService = getIt<WebService>();

    // Initialer State
    return NewFriendState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    if (state.isBusy) return;

    // UI-State zurücksetzen
    state = const NewFriendState();
  }

  // ------------------------------------------------------------------------
  // --- Speichern ---
  // ------------------------------------------------------------------------

  /// Fügt den einen Freund über den angegebenen Namen hinzu.
  Future<void> save() async {
    if (state.isBusy) return;

    // 1. Benutzereingabe bereinigen
    final userName = state.userName.trim();

    // 2. UI-State aktualisieren
    state = state.copyWith(
      userName: userName,
      status: NewFriendActionStatus.progress, error: AppError.none(),
    );

    try {

      // 3. Benutzereingabe validieren
      if (userName.isEmpty) {
        state = state.copyWith(status: NewFriendActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'userName'));
        return; // kein Name angegeben
      }
      final lowerName = userName.toLowerCase();
      if (lowerName == _sessionService.user?.name.toLowerCase()) {
        state = state.copyWith(status: NewFriendActionStatus.failure, error: AppError(ErrorCode.userSelfAdd, field: 'userName'));
        return;  // Name == Benutzer der App
      }
      final existing = await _databaseService.getUserByName(userName);
      if (existing != null) {
        state = state.copyWith(status: NewFriendActionStatus.failure, error: AppError(ErrorCode.userAlreadyAdded, field: 'userName'));
        return; // Name bereits in der Liste
      }

      // 4. WebService konfigurieren
      if (_sessionService.settings == null) throw Exception('Die Einstellungen sind nicht in der Session abgelegt.');
      if (_sessionService.settings!.host.isEmpty || _sessionService.settings!.apiToken.isEmpty) {
        state = state.copyWith(status: NewFriendActionStatus.failure, error: AppError(ErrorCode.valueRequired, text: 'Der Sync-Server ist noch nicht eingerichtet.'));
        return;
      }
      _webService.updateConfig(host: _sessionService.settings!.host, apiToken: _sessionService.settings!.apiToken);

      // 5. Person auf dem Server suchen
      final userResponse = await _webService.findUser(_sessionService.vaultName, userName);
      if (userResponse == null) {
        state = state.copyWith(status: NewFriendActionStatus.failure, error: AppError(ErrorCode.userNotFound, field: 'userName'));
        return;
      }

      // 6. Person als Freund in die Datenbank einfügen
      // syncedName wird auf den gesuchten Namen gesetzt und bleibt unveränderlich.
      // Bei Freunden (id > 1) dient syncedName als Original-Name zur Anzeige bei Umbenennung.
      await _databaseService.saveUser(UserEntity(
        id: 0,
        uuid: userResponse.userUuid,
        name: userName,
        publicKey: userResponse.publicKey,
        isVerified: false,
        isHidden: false,
        syncedName: userName,
        updatedAt: DateTime.now().toUtc(),
      ));

      // 7. UI-State aktualisieren
      state = state.copyWith(
        status: NewFriendActionStatus.saved,
      );

    } on DioException catch (de) { // Exception des HTTP-Clients
      //final msg = de.response?.statusMessage ?? (de.message ?? 'Netzwerkfehler');
      //final text = de.response?.statusCode != null ? '$msg (Code ${de.response?.statusCode})' : msg;
      //state = state.copyWith(status: NewFriendActionStatus.failure, error: AppError(ErrorCode.networkError, text: text));
      state = state.copyWith(status: NewFriendActionStatus.failure, error: WebService.convertDioError(de));

    } catch (e, st) {
      log.fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(status: NewFriendActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für Benutzername.
  void setUserName(String value) {
    final error = state.error.field == 'userName' ? AppError.none() : null;
    state = state.copyWith(userName: value, error: error);
  }
}