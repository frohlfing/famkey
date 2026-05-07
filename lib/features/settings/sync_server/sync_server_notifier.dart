import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/core/app_error.dart';
import 'package:famkey/core/logger.dart';
import 'package:famkey/core/service_locator.dart';
import 'package:famkey/database/database.dart';
import 'package:famkey/features/settings/sync_server/sync_server_form_data.dart';
import 'package:famkey/features/settings/sync_server/sync_server_state.dart';
import 'package:famkey/services/database_service.dart';
import 'package:famkey/services/info_service.dart';
import 'package:famkey/services/session_service.dart';
import 'package:famkey/services/web_service.dart';

final syncServerProvider = NotifierProvider<SyncServerNotifier, SyncServerState>(() {
  return SyncServerNotifier();
});

class SyncServerNotifier extends Notifier<SyncServerState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final DatabaseService _databaseService;
  late final InfoService _infoService;
  late final SessionService _sessionService;
  late final WebService _webService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen (nicht reaktiv, nicht UI‑relevant) ---
  // ------------------------------------------------------------------------

  /// Die Datenbank-Entität.
  SettingsEntity? _settings;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
  ///
  /// Die Verwendung von `Ref.watch` oder `Ref.listen` innerhalb dieser Methode ist unbedenklich.
  /// Ändert sich eine Abhängigkeit dieses Notifiers (bei Verwendung von `Ref.watch`), wird der Build-Prozess erneut ausgeführt. Der Notifier selbst wird jedoch nicht neu erstellt. Seine Instanz bleibt zwischen den Build-Ausführungen erhalten.
  @override
  SyncServerState build() {
    // Dienste aus getIt holen
    _databaseService = getIt<DatabaseService>();
    _infoService = getIt<InfoService>();
    _sessionService = getIt<SessionService>();
    _webService = getIt<WebService>();

    // Initialer State
    return SyncServerState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    if (state.isBusy) return;

    // UI-State zurücksetzen
    state = const SyncServerState().copyWith(status: SyncServerActionStatus.progress);
    
    try {
      // Daten aus der Datenbank laden
      _settings = await _databaseService.getSettings();
      if (_settings == null) throw Exception('Die Einstellungen sind nicht in der Datenbank hinterlegt.'); // wird bereits direkt nach dem Login angelegt

      // UI-State aktualisieren
      final formData = SyncServerFormData(
        host: _settings!.host,
        apiToken: _settings!.apiToken,
      );
      state = state.copyWith(
        formData: formData,
        originalFormData: formData,
        isRegistered: _settings!.lastSyncAt.year > 1970,
        status: SyncServerActionStatus.loaded,
      );

    } catch (e, st) {
      log.fatal('Fehler beim Laden: $e', stack: st);
      state = state.copyWith(status: SyncServerActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Speichern ---
  // ------------------------------------------------------------------------

  /// Speichert Einstellungen für den Sync-Server.
  Future<void> save() async {
    if (state.isBusy) return;

    // 1. Benutzereingabe bereinigen
    var formData = state.formData;
    formData = formData.copyWith(
      host: _normalizeUrl(formData.host),
      apiToken: formData.apiToken.trim(),
    );

    // 2. UI-State aktualisieren
    state = state.copyWith(
      formData: formData,
      status: SyncServerActionStatus.progress, error: AppError.none(),
    );

    try {

      // 3. Benutzereingabe validieren
      // if (formData.host.isEmpty) {
      //   state = state.copyWith(status: SyncServerActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'host'));
      //   return;
      // }
      // if (formData.apiToken.isEmpty) {
      //   state = state.copyWith(status: SyncServerActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'apiToken'));
      //   return;
      // }

      // 4. Datenbank und Session aktualisieren
      if (formData != state.originalFormData) {
        if (_settings == null) throw Exception("Die Einstellungen sind nicht geladen.");
        final serverChanged = formData.host != state.originalFormData.host;
        final updatedSettings = _settings!.copyWith(
          host: formData.host,
          apiToken: formData.apiToken,
          lastSyncAt: serverChanged ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true) : null, // auf 1970‑01‑01 00:00:00 UTC zurücksetzen bei Host-Wechsel (= andere Organisation/anderer Server)
        );
        _settings = await _databaseService.saveSettings(updatedSettings);
        _sessionService.setSettings(_settings!);
        if (serverChanged) {
          _webService.updateConfig(host: formData.host, apiToken: formData.apiToken);
        }
      }

      // 5. State aktualisieren
      state = state.copyWith(
        originalFormData: formData,
        status: SyncServerActionStatus.saved,
      );

    } catch (e, st) {
      log.fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(status: SyncServerActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Normalisiert die URL
  String _normalizeUrl(String url) {
    // Entfernt ein Slash-Zeichen am Ende der URL.
    url = url.trim().replaceAll(RegExp(r'/+$'), '');

    // Protokoll hinzufügen
    if (url.isNotEmpty && !url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    return url;
  }

  /// Testet die Verbindung zum Sync-Server.
  Future<void> testConnection() async {
    if (state.isBusy) return;

    // 1. Benutzereingabe bereinigen
    var formData = state.formData;
    formData = formData.copyWith(
      host: _normalizeUrl(formData.host),
      apiToken: formData.apiToken.trim(),
    );

    // 2. UI-State aktualisieren
    state = state.copyWith(
      formData: formData,
      status: SyncServerActionStatus.progress, error: AppError.none(),
    );
    
    try {

      // 3. Benutzereingabe validieren
      if (formData.host.isEmpty) {
        state = state.copyWith(status: SyncServerActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'host'));
        return;
      }
      if (formData.apiToken.isEmpty) {
        state = state.copyWith(status: SyncServerActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'apiToken'));
        return;
      }
      _webService.updateConfig(host: formData.host, apiToken: formData.apiToken);

      // 4. Server-Version prüfen
      // Falls die Serverantwort ein unerwartetes Format hat, wird `VersionResponse` mit leeren Werten zurückgegeben.
      final serverVersion = await _webService.getServerVersion();
      if (!serverVersion.service.contains("FamKey")) {
        state = state.copyWith(status: SyncServerActionStatus.failure, error: AppError(ErrorCode.noSyncService));
        return;
      }
      if (_infoService.syncProtocolVersion < serverVersion.minSyncProtocolVersion) {
        state = state.copyWith(status: SyncServerActionStatus.failure, error: AppError(ErrorCode.appIsOutdated));
        return;
      }
      if (_infoService.syncProtocolVersion > serverVersion.syncProtocolVersion) {
        state = state.copyWith(status: SyncServerActionStatus.failure, error: AppError(ErrorCode.serverIsOutdated));
        return;
      }

      // 5. UI-State aktualisieren
      state = state.copyWith(status: SyncServerActionStatus.testSuccessful);

    } on DioException catch (de) { // Exception des HTTP-Clients
      state = state.copyWith(status: SyncServerActionStatus.failure, error: WebService.convertDioError(de));

    } catch (e, st) {
      log.fatal("Fehler beim Verbindungstest: $e", stack: st);
      state = state.copyWith(status: SyncServerActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für Serveradresse
  void setHost(String value) {
    final error = state.error.field == 'host' ? AppError.none() : null;
    final formData = state.formData.copyWith(host: value);
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setter für API-Token
  void setApiToken(String value) {
    final error = state.error.field == 'apiToken' ? AppError.none() : null;
    final formData = state.formData.copyWith(apiToken: value);
    state = state.copyWith(formData: formData, error: error);
  }
}
