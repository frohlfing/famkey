import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/app_file.dart';
import 'package:privault/core/app_file_factory.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/features/detail/preview/preview_state.dart';
import 'package:privault/core/renderer_factory.dart';

final previewProvider = NotifierProvider<PreviewNotifier, PreviewState>(() {
  return PreviewNotifier();
});

class PreviewNotifier extends Notifier<PreviewState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  //late final CryptoService _cryptoService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen (nicht reaktiv, nicht UI‑relevant) ---
  // ------------------------------------------------------------------------

  // DIe anzuzeigende Datei.
  //AppFile? _file;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
  ///
  /// Die Verwendung von `Ref.watch` oder `Ref.listen` innerhalb dieser Methode ist unbedenklich.
  /// Ändert sich eine Abhängigkeit dieses Notifiers (bei Verwendung von `Ref.watch`), wird der Build-Prozess erneut ausgeführt. Der Notifier selbst wird jedoch nicht neu erstellt. Seine Instanz bleibt zwischen den Build-Ausführungen erhalten.
  @override
  PreviewState build() {
    // Dienste aus getIt holen
    //_cryptoService = getIt<CryptoService>();

    // Initialer State
    return PreviewState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load(AppFile file) async {
    if (state.isBusy) return;
    // Ladeanzeige einblenden
    state = const PreviewState().copyWith(status: PreviewActionStatus.loading, error: AppError.none());

    try {
      // Daten auslesen
      final bytes = await file.readAsBytes();

      // UI-State aktualisieren
      state = const PreviewState().copyWith(
        file: file,
        bytes: bytes,
        status: PreviewActionStatus.loaded,
      );

    } catch (e, st) {
      Logger().fatal('Fehler beim Laden: $e', stack: st);
      state = state.copyWith(status: PreviewActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Aktionen ---
  // ------------------------------------------------------------------------

  /// Lädt den Anhang herunter bzw. öffnet ihn mit der System-App (nativ).
  Future<void> download() async {
    if (state.isBusy) return;
    state = state.copyWith(status: PreviewActionStatus.progress, error: AppError.none());
    try {
      await downloadAppFile(state.file);
      state = state.copyWith(status: PreviewActionStatus.success);
    } catch (e, st) {
      Logger().fatal('Fehler beim Herunterladen der Datei: $e', stack: st);
      state = state.copyWith(status: PreviewActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Druckt den Anhang.
  Future<void> print() async {
    if (state.isBusy) return;

    state = state.copyWith(status: PreviewActionStatus.progress, error: AppError.none());

    try {
      final bytes = state.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Keine Daten zum Drucken vorhanden.');
      }

      final renderer = createRenderer(bytes, state.file.mime);
      if (!renderer.isPrintable) {
        throw StateError('Dieser Dateityp kann nicht gedruckt werden.');
      }
      await renderer.print(state.file.name);

      state = state.copyWith(status: PreviewActionStatus.success);

    } catch (e, st) {
      Logger().fatal('Fehler beim Drucken des Anhangs: $e', stack: st);
      state = state.copyWith(status: PreviewActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }
}