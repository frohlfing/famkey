import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/features/settings/import/import_form_data.dart';
import 'package:privault/features/settings/import/import_parser.dart';
import 'package:privault/features/settings/import/import_state.dart';
import 'package:privault/features/settings/import/parser/bitwarden_json_parser.dart';
import 'package:privault/features/settings/import/parser/keepass_xml_parser.dart';
//import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
//import 'package:privault/services/session_service.dart';

final importProvider = NotifierProvider<ImportNotifier, ImportState>(() {
  return ImportNotifier();
});

class ImportNotifier extends Notifier<ImportState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  //late final CryptoService _cryptoService;
  late final DatabaseService _databaseService;
  //late final SessionService _sessionService;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
  ///
  /// Die Verwendung von `Ref.watch` oder `Ref.listen` innerhalb dieser Methode ist unbedenklich.
  /// Ändert sich eine Abhängigkeit dieses Notifiers (bei Verwendung von `Ref.watch`), wird der Build-Prozess erneut ausgeführt. Der Notifier selbst wird jedoch nicht neu erstellt. Seine Instanz bleibt zwischen den Build-Ausführungen erhalten.
  @override
  ImportState build() {
    // Dienste aus getIt holen
    //_cryptoService = getIt<CryptoService>();
    _databaseService = getIt<DatabaseService>();
    //_sessionService = getIt<SessionService>();

    // Initialer State
    return ImportState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    if (state.isBusy) return;

    // UI-State zurücksetzen
    state = const ImportState();
  }

  // ------------------------------------------------------------------------
  // --- Speichern ---
  // ------------------------------------------------------------------------

  /// Startet den Importprozess.
  Future<void> import() async {
    if (state.isBusy) return;

    var formData = state.formData;

    // 1. UI-State aktualisieren
    state = state.copyWith(
      formData: formData,
      status: ImportActionStatus.parse, error: AppError.none(),
    );

    try {

      // 2. Benutzereingabe validieren
      if (formData.format == ImportFileFormat.none) {
        state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'format'));
        return;
      }

      if (formData.file.isEmpty) {
        state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'file'));
        return;
      }

      // todo 3. Sicherheitsabfrage: "Der Tresor wird in eine unverschlüsselte Datei exportiert. Fortfahren?"

      // 4. Parser auswählen
      ImportParser parser;
      switch (formData.format) {
        case ImportFileFormat.keepassXml:
          parser = KeepassXmlParser(formData.file);
          break;
        case ImportFileFormat.bitwardenJson:
          parser = BitwardenJsonParser(formData.file);
          break;
        default:
          state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.valueInvalid, field: 'format'));
          return;
      }

      // 5. Datei parsen
      final importPayload = await parser.parse();
      if (importPayload == null) {
        state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.validationFailed, text: parser.errorText ?? "Die Datei entspricht nicht dem Format", field: 'file'));
        return;
      }

      // 6. Daten validieren
      // todo
      // - Sicherstellen, dass die Einträge noch nicht existieren (wenn bereits vorhanden, nachfragen ob Abbruch oder überspringen)
      // - UUID muss gesetzt sein (wenn nicht, wir ein Wert generiert)
      // - Titel muss gesetzt sein (wenn nicht, nachfragen ob Abbruch oder überspringen)

      // 5. Daten importieren
      await _databaseService.import(importPayload); // todo _databaseService.import implementieren

      // 8. State aktualisieren
      state = state.copyWith(
        formData: ImportFormData(), // Passwortfelder leeren
        status: ImportActionStatus.success,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Importieren: $e", stack: st);
      state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für neues Passwort
  void setFormat(ImportFileFormat value) {
    final error = state.error.field == 'format' ? AppError.none() : null;
    final formData = state.formData.copyWith(format: value);
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setter für bisheriges Passwort
  void setFile(String value) {
    final error = state.error.field == 'file' ? AppError.none() : null;
    final formData = state.formData.copyWith(file: value);
    state = state.copyWith(formData: formData, error: error);
  }
}
