import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/core/app_error.dart';
import 'package:famkey/core/logger.dart';
import 'package:famkey/core/service_locator.dart';
import 'package:famkey/database/database.dart';
import 'package:famkey/features/settings/delete_vault/delete_vault_state.dart';
import 'package:famkey/services/biometric_service.dart';
import 'package:famkey/services/config_service.dart';
import 'package:famkey/services/database_service.dart';
import 'package:famkey/services/session_service.dart';
import 'package:famkey/services/web_service.dart';

final deleteVaultProvider = NotifierProvider<DeleteVaultNotifier, DeleteVaultState>(() {
  return DeleteVaultNotifier();
});

class DeleteVaultNotifier extends Notifier<DeleteVaultState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final BiometricService _biometricService;
  late final ConfigService _configService;
  late final DatabaseService _databaseService;
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
  DeleteVaultState build() {
    _biometricService = getIt<BiometricService>();
    _configService = getIt<ConfigService>();
    _databaseService = getIt<DatabaseService>();
    _sessionService = getIt<SessionService>();
    _webService = getIt<WebService>();

    return const DeleteVaultState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    if (state.isBusy) return;
    state = state.copyWith(status: DeleteVaultActionStatus.progress, error: AppError.none());

    try {
      _settings = await _databaseService.getSettings();
      state = state.copyWith(
        isRegistered: _settings != null && _settings!.lastSyncAt.year > 1970,
        status: DeleteVaultActionStatus.loaded,
      );
    } catch (e, st) {
      log.fatal('Fehler beim Laden: $e', stack: st);
      state = state.copyWith(status: DeleteVaultActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Löschen ---
  // ------------------------------------------------------------------------

  /// Löscht den Tresor nur lokal vom Gerät.
  /// Die Daten auf dem Server bleiben erhalten.
  Future<void> deleteVaultLocal() async {
    if (state.isBusy) return;
    state = state.copyWith(status: DeleteVaultActionStatus.progress, error: AppError.none());

    try {
      // 1. Datenbank löschen
      await _databaseService.deleteCurrentDatabaseAndSaltFile();

      // 2. SecureStore leeren
      await _biometricService.removeMasterKey(_sessionService.vaultName);

      // 3. Konfiguration bereinigen
      if (_configService.lastVaultName == _sessionService.vaultName) {
        _configService.lastVaultName = '';
      }

      // 4. Session zurücksetzen
      _sessionService.clearSession();
      state = state.copyWith(status: DeleteVaultActionStatus.deleted);
    } catch (e, st) {
      log.fatal('Fehler beim lokalen Löschen des Tresors: $e', stack: st);
      state = state.copyWith(status: DeleteVaultActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Löscht den Tresor nur auf dem Server.
  /// Die lokalen Daten bleiben erhalten. lastSyncAt wird zurückgesetzt,
  /// damit der nächste Sync den Tresor unter dem aktuellen Namen neu registriert.
  ///
  /// Falls der Benutzer der letzte im Tresor ist, wird der gesamte Tresor gelöscht.
  /// Andernfalls wird nur der eigene Benutzer-Datensatz entfernt.
  Future<void> deleteVaultServer() async {
    if (state.isBusy) return;
    state = state.copyWith(status: DeleteVaultActionStatus.progress, error: AppError.none());

    try {
      if (_sessionService.user == null || _sessionService.settings == null) {
        throw Exception('Session nicht initialisiert.');
      }
      final settings = _sessionService.settings!;
      final user = _sessionService.user!;

      // WebService konfigurieren
      _webService.updateConfig(host: settings.host, apiToken: settings.apiToken);
      _webService.setSignatureData(userUuid: user.uuid, privateKey: _sessionService.privateKey!, publicKey: user.publicKey);

      // Tresor serverseitig löschen (Server entscheidet: letzter User → Tresor löschen, sonst nur User)
      await _webService.deleteVault(user.uuid);

      // lastSyncAt zurücksetzen → nächster Sync registriert Tresor unter aktuellem Namen neu
      if (_settings == null) throw Exception('Settings nicht geladen.');
      final updatedSettings = _settings!.copyWith(
        lastSyncAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
      _settings = await _databaseService.saveSettings(updatedSettings);
      _sessionService.setSettings(_settings!);

      state = state.copyWith(isRegistered: false, status: DeleteVaultActionStatus.saved);
    } on DioException catch (de) {
      final error = WebService.convertDioError(de);
      log.error(error.text);
      state = state.copyWith(status: DeleteVaultActionStatus.failure, error: error);
    } catch (e, st) {
      log.fatal('Fehler beim serverseitigen Löschen des Tresors: $e', stack: st);
      state = state.copyWith(status: DeleteVaultActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Löscht den Tresor sowohl auf dem Server als auch lokal.
  Future<void> deleteVaultBoth() async {
    if (state.isBusy) return;
    state = state.copyWith(status: DeleteVaultActionStatus.progress, error: AppError.none());

    try {
      if (_sessionService.user == null || _sessionService.settings == null) {
        throw Exception('Session nicht initialisiert.');
      }
      final settings = _sessionService.settings!;
      final user = _sessionService.user!;

      // WebService konfigurieren
      _webService.updateConfig(host: settings.host, apiToken: settings.apiToken);
      _webService.setSignatureData(userUuid: user.uuid, privateKey: _sessionService.privateKey!, publicKey: user.publicKey);

      // Tresor serverseitig löschen
      await _webService.deleteVault(user.uuid);

      // Lokal löschen
      await _databaseService.deleteCurrentDatabaseAndSaltFile();
      await _biometricService.removeMasterKey(_sessionService.vaultName);
      if (_configService.lastVaultName == _sessionService.vaultName) {
        _configService.lastVaultName = '';
      }
      _sessionService.clearSession();
      state = state.copyWith(status: DeleteVaultActionStatus.deleted);
    } on DioException catch (de) {
      final error = WebService.convertDioError(de);
      log.error(error.text);
      state = state.copyWith(status: DeleteVaultActionStatus.failure, error: AppError(ErrorCode.unknown));
    } catch (e, st) {
      log.fatal('Fehler beim vollständigen Löschen des Tresors: $e', stack: st);
      state = state.copyWith(status: DeleteVaultActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }
}
