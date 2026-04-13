import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/app_file_factory.dart';
import 'package:privault/core/app_file.dart';
import 'package:privault/core/helper.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/detail/detail_state.dart';
import 'package:privault/models/payloads/attachment_meta_payload.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/password_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

final detailProvider = NotifierProvider<DetailNotifier, DetailState>(() {
  return DetailNotifier();
});

/// Das `DetailNotifier` ist die Riverpod‑Version des alten DetailViewModel.
/// Alle Kommentare wurden beibehalten.
/// Interne technische Felder bleiben intern.
/// UI‑Felder werden in den State geschrieben.
class DetailNotifier extends Notifier<DetailState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final CryptoService _cryptoService;
  late final DatabaseService _databaseService;
  late final PasswordService _passwordService;
  late final SessionService _sessionService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen (nicht reaktiv, nicht UI‑relevant) ---
  // ------------------------------------------------------------------------

  /// Die aktuell geladene Datenbank-Entität.
  EntryEntity? _entry;

  /// Der entpackte 32-Byte AES-Schlüssel für diesen spezifischen Eintrag.
  /// Wird benötigt, um Daten und Anhänge zu ver- und zu entschlüsseln.
  Uint8List? _entryKey;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
  ///
  /// Die Verwendung von `Ref.watch` oder `Ref.listen` innerhalb dieser Methode ist unbedenklich.
  /// Ändert sich eine Abhängigkeit dieses Notifiers (bei Verwendung von `Ref.watch`), wird der Build-Prozess erneut ausgeführt. Der Notifier selbst wird jedoch nicht neu erstellt. Seine Instanz bleibt zwischen den Build-Ausführungen erhalten.
  @override
  DetailState build() {
    // Dienste aus getIt holen
    _cryptoService = getIt<CryptoService>();
    _databaseService = getIt<DatabaseService>();
    _sessionService = getIt<SessionService>();
    _passwordService = getIt<PasswordService>();

    // Initialer State
    return const DetailState();
  }

  /// Lädt den Eintrag anhand seiner ID.
  Future<void> load(int id) async {
    if (state.isBusy) return;

    // Status zurücksetzen
    state = const DetailState().copyWith(status: DetailActionStatus.progress, error: AppError.none());

    try {
      // 1. Eintrag aus Datenbank laden
      _entry = await _databaseService.getEntry(id);
      if (_entry == null) throw Exception("Eintrag nicht gefunden");

      // 2. Berechtigung laden
      final perm = await _databaseService.getPermissionByEntryIdAndUserId(_entry!.id, 1);
      if (perm == null) throw Exception("Keine Berechtigung für diesen Eintrag");
      final myAccessLevel = perm.accessLevel;

      // 3. Entry-Key mittels RSA entschlüsseln
      if (_sessionService.privateKey == null) throw Exception("Sitzungsschlüssel fehlt");
      _entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, _sessionService.privateKey!);

      // 4. Stammdaten mittels AES entschlüsseln
      final decryptedData = await _cryptoService.decrypt(_entry!.encryptedData, _entryKey!);
      final payload = EntryPayload.fromJson(json.decode(utf8.decode(decryptedData)));

      // 5. Passwort- und Audit-Hinweis generieren
      final passwordHint = _createPasswordHint(payload.passwordTimestamp);
      final auditHint = await _createAuditHint();

      // 6. Dateianhänge laden

      // 6. Dateianhänge inkl. Metadaten laden
      final attachments = await _loadAttachmentsWithMetas(_entry!.id);

      // 7. Freunde und Berechtigungen laden
      final friends = await _databaseService.getNotHiddenFriendsWithAccessLevel(_entry!.id);

      // 8. Alles zusammen in den State schreiben
      state = state.copyWith(
        category: payload.category,
        title: payload.title,
        username: payload.username,
        password: payload.password,
        passwordStrength: _passwordService.estimateStrength(payload.password),
        passwordHint: passwordHint,
        url: payload.url,
        notes: payload.notes,
        favicon: payload.favicon,
        auditHint: auditHint,
        attachments: attachments,
        friends: friends,
        myAccessLevel: myAccessLevel,
        status: DetailActionStatus.loaded,
      );
    } catch (e, st) {
      Logger().fatal("Fehler beim Laden: $e", stack: st);
      state = state.copyWith(status: DetailActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Stammdaten ---
  // ------------------------------------------------------------------------

  /// Generiert einen Audit-Hinweis über Ersteller und letzte Änderung.
  Future<String> _createAuditHint() async {
    var creator = "Unbekannt";
    var updater = "Unbekannt";

    final cu = _entry!.creatorId != 0 ? await _databaseService.getUser(_entry!.creatorId) : null;
    final uu = _entry!.updaterId != 0 ? await _databaseService.getUser(_entry!.updaterId) : null;

    if (cu != null) creator = cu.name;
    if (uu != null) updater = uu.name;

    final dateStr = DateFormat("dd.MM.yyyy HH:mm:ss").format(_entry!.updatedAt.toLocal());

    return "• Erstellt von: $creator \n• Zuletzt bearbeitet von: $updater, am $dateStr";
  }

  /// Generiert einen Passwort-Hinweis über das Alter des Passworts.
  String _createPasswordHint(DateTime? passwordTimestamp) {
    if (passwordTimestamp == null) return '';

    final dateStr = DateFormat("dd.MM.yyyy").format(passwordTimestamp.toLocal());

    // Ein Jahr hat durchschnittlich 365.25 Tage. Ein Monat hat somit durchschnittlich 30.4375 Tage.
    final days = DateTime.now().difference(passwordTimestamp).inDays;
    if (days == 0) return 'Heute geändert.';
    if (days == 1) return 'Gestern geändert.';
    if (days < 14) return 'Geändert am $dateStr (vor $days Tagen).'; // 2 bis 13 Tagen (weniger als 2 Wochen)
    if (days < 60.875) return 'Geändert am $dateStr (vor ${(days / 7).round()} Wochen).'; // 2 bis 9 Wochen (weniger als 2 Monate)
    if (days < 730.5) return 'Geändert am $dateStr (vor ${(days / 30.4375).round()} Monaten).'; // 2 bis 23 Monaten (weniger als 2 Jahren)

    final years = days ~/ 365.25; // abgerundet
    final month = ((days - years * 365.25) / 30.4375).round(); // restliche Monate (gerundet)
    if (month == 0) return 'Geändert am $dateStr (vor $years Jahren).';
    if (month == 1) return 'Geändert am $dateStr (vor $years Jahren und 1 Monat).';
    return 'Geändert am $dateStr (vor $years Jahren und $month Monaten).';
  }

  /// Kopiert den Text in die Zwischenablage.
  void copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  /// Öffnet die URL in einem neuen Browser-Tab.
  // todo gehört das nicht in die UI?
  Future<void> openUrl() async {
    if (state.url.isEmpty) return;
    final uri = Uri.parse(state.url.startsWith('http') ? state.url : 'https://${state.url}');
    try {
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success) {
        state = state.copyWith(status: DetailActionStatus.failure, error: AppError(ErrorCode.unknown, text: 'Die URL konnte nicht geöffnet werden.'));
      }
    } catch (e, st) {
      Logger().fatal('Fehler beim Öffnen der URL ${state.url}: $e', stack: st);
      state = state.copyWith(status: DetailActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Anhänge ---
  // ------------------------------------------------------------------------

  /// Lädt alle Anhänge und entschlüsselt parallel die Metadaten.
  Future<List<({AttachmentEntity attachment, AttachmentMetaPayload meta})>> _loadAttachmentsWithMetas(int entryId) async {
    final attachments = await _databaseService.getAttachmentsByEntryId(entryId);
    final List<({AttachmentEntity attachment, AttachmentMetaPayload meta})> result = [];
    for (var att in attachments) {
      final decryptedMeta = await _cryptoService.decrypt(att.encryptedMeta, _entryKey!);
      final meta = AttachmentMetaPayload.fromJson(json.decode(utf8.decode(decryptedMeta)));
      result.add((attachment: att, meta: meta));
    }
    return result;
  }

  /// Fügt dem aktuellen Eintrag einen neuen Dateianhang hinzu.
  Future<void> addAttachment(AppFile file) async {
    if (state.isBusy) return;

    // 1. Status auf progress setzen
    state = state.copyWith(status: DetailActionStatus.progress, error: AppError.none());

    try {
      if (_entry == null) throw Exception('Kein Eintrag zum Anhängen einer Datei geladen.');
      if (_entryKey == null) throw Exception('Der AES-Schlüssel des Eintrags ${_entry!.id} ist nicht entpackt.');

      // 2. Datei auslesen
      final bytes = await file.readAsBytes();
      final mimeType = getMimeType(file.name);

      // 3. Thumbnail erzeugen (wenn es ein Bild ist)
      String? thumbnailBase64;
      if (mimeType.startsWith('image/')) {
        thumbnailBase64 = await createThumbnail(bytes);
      }

      // 4. Metadaten-Payload vorbereiten
      final metaPayload = AttachmentMetaPayload(
        filename: file.name,
        mime: mimeType,
        size: bytes.length,
        thumbnail: thumbnailBase64,
        timestamp: DateTime.now().toUtc(),
      );

      // 5. Verschlüsseln (AES)
      final encryptedMeta = await _cryptoService.encrypt(Uint8List.fromList(utf8.encode(json.encode(metaPayload.toJson()))), _entryKey!);
      final encryptedContent = await _cryptoService.encrypt(bytes, _entryKey!);

      // 6. Entity speichern
      await _databaseService.saveAttachment(AttachmentEntity(
        id: 0,
        uuid: const Uuid().v4(),
        entryId: _entry!.id,
        encryptedMeta: encryptedMeta,
        encryptedContent: encryptedContent,
        isSynced: false,
      ));

      // 7. Zeitstempel des Eintrags aktualisieren
      _entry = _entry!.copyWith(updatedAt: DateTime.now().toUtc());
      await _databaseService.saveEntry(_entry!);

      // 8. State aktualisieren
      final attachments = await _loadAttachmentsWithMetas(_entry!.id);
      state = state.copyWith(
        attachments: attachments,
        status: DetailActionStatus.attachmentAdded,
      );
    } catch (e, st) {
      Logger().fatal('Fehler beim Hinzufügen eines Anhangs: $e', stack: st);
      state = state.copyWith(status: DetailActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Entschlüsselt einen Anhang und öffnet ihn mit der System-App.
  // todo gehört das nicht in die UI? Zumindest der Part nachdem die Daten entschlüsselt sind?
  Future<void> openAttachment(AttachmentEntity attachment, String filename) async {
    if (state.isBusy) return;

    // Status auf progress setzen
    state = state.copyWith(status: DetailActionStatus.progress, error: AppError.none());

    try {
      if (_entry == null) throw Exception('Kein Eintrag zum Öffnen des Anhangs geladen.');
      if (_entryKey == null) throw Exception('Der AES-Schlüssel des Eintrags ${_entry!.id} ist nicht entpackt.');

      // Inhalt entschlüsseln
      final decryptedContent = await _cryptoService.decrypt(attachment.encryptedContent, _entryKey!);
      final tempFile = await createTempAppFile(filename);
      await tempFile.writeAsBytes(decryptedContent);

      // Datei öffnen
      await OpenFilex.open(tempFile.path); // todo

      // Sicherheits-Cleanup: Temporäre Datei verzögert löschen
      Future.microtask(() async {
        for (var i = 0; i < 10; i++) {
          await Future.delayed(const Duration(seconds: 2));
          try {
            if (await tempFile.exists()) {
              await tempFile.delete();
              Logger().debug('Sicherheits-Cleanup: Temporäre Datei gelöscht (Versuch ${i + 1}).');
              break;
            }
          } catch (e) {
            // Fehler nur loggen, den Cleanup-Prozess aber nicht unterbrechen.
            Logger().error('Fehler beim Entfernen der temporären Datei (Versuch ${i + 1}): $e');
            state = state.copyWith(error: AppError(ErrorCode.cleanupFailed));
          }
        }
      });

      state = state.copyWith(status: DetailActionStatus.loaded);
    } catch (e, st) {
      Logger().fatal('Fehler beim Öffnen des Anhangs: $e', stack: st);
      state = state.copyWith(status: DetailActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Löscht einen spezifischen Anhang.
  Future<void> deleteAttachment(AttachmentEntity attachment) async {
    if (state.isBusy) return;

    // Status auf progress setzen
    state = state.copyWith(status: DetailActionStatus.progress, error: AppError.none());

    try {
      await _databaseService.deleteAttachment(attachment.id);
      final attachments = await _loadAttachmentsWithMetas(_entry!.id);
      state = state.copyWith(
        attachments: attachments,
        status: DetailActionStatus.attachmentDeleted,
      );
    } catch (e, st) {
      Logger().fatal('Fehler beim Löschen: $e', stack: st);
      state = state.copyWith(status: DetailActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // /// Erzeugt ein Vorschaubild ohne Ränder
  // /// Die Funktion muss static sein, das sie innerhalb eines Worker-Threads aufgerufen wird.
  // static String? _createThumbnail(Uint8List bytes) {
  //   try {
  //     // 1. Image dekodieren
  //     final image = img.decodeImage(bytes);
  //     if (image == null || image.width <= 0 || image.height <= 0) return null;
  //
  //     const maxWidth = 128;
  //     const maxHeight = 128;
  //
  //     // 2. Aspect-Fit berechnen
  //     final scale = math.min(maxWidth / image.width, maxHeight / image.height);
  //     final newW = math.max(1, (image.width * scale).round());
  //     final newH = math.max(1, (image.height * scale).round());
  //
  //     // 3. Resize auf exakte Zielgröße (verhindert Trauerränder)
  //     final thumbnail = img.copyResize(image, width: newW, height: newH, interpolation: img.Interpolation.linear);
  //
  //     // 4. Encode mit 80% Qualität
  //     return base64Encode(img.encodeJpg(thumbnail, quality: 80));
  //   } catch (e) {
  //     // In statischen Methoden können wir kein logError() der Instanz rufen!
  //     // Wir loggen hier nur auf die Konsole oder geben null zurück.
  //     debugPrint('Thumbnail-Fehler: $e');
  //     return null;
  //   }
  // }

  // ------------------------------------------------------------------------
  // --- Geteilt mit ---
  // ------------------------------------------------------------------------

   /// Teilt den Eintrag mit einem Freund.
  Future<void> shareWith(UserEntity targetUser) async {
    if (state.isBusy) return;

    // Status auf progress setzen
    state = state.copyWith(status: DetailActionStatus.progress, error: AppError.none());

    try {
      if (_entry == null) throw Exception('Kein Eintrag zum Teilen geladen.');
      if (_entryKey == null) throw Exception('Der AES-Schlüssel des Eintrags ${_entry!.id} ist nicht entpackt.');

      // 1. Aktuelle Berechtigungen des Freundes auf diesen Eintrag aus der Datenbank laden
      final perm = await _databaseService.getPermissionByEntryIdAndUserId(_entry!.id, targetUser.id);

      // 2. Berechtigungen aktualisieren und in der Datenbank speichern
      if (perm == null) {
        // Neues Zugriffsrecht: Entry-Key mit RSA-PubKey des Empfängers verschlüsseln
        final encryptedEntryKey = await _cryptoService.encryptRsa(_entryKey!, targetUser.publicKey);
        await _databaseService.savePermission(PermissionEntity(
          id: 0,
          entryId: _entry!.id,
          userId: targetUser.id,
          encryptedKey: encryptedEntryKey,
          accessLevel: 1, // Default: Nur Lesen (max 2 beim direkten Teilen)
        ));
      } else {
        // Bestehendes (ggf. entzogenes) Recht reaktivieren
        String encryptedEntryKey = perm.encryptedKey;
        if (encryptedEntryKey.isEmpty) {
          encryptedEntryKey = await _cryptoService.encryptRsa(_entryKey!, targetUser.publicKey);
        }
        await _databaseService.savePermission(perm.copyWith(accessLevel: 1, encryptedKey: encryptedEntryKey));
      }

      // 3. Zeitstempel des Eintrags aktualisieren
      _entry = _entry!.copyWith(updatedAt: DateTime.now().toUtc());
      await _databaseService.saveEntry(_entry!);

      // 4. State aktualisieren
      final friends = await _databaseService.getNotHiddenFriendsWithAccessLevel(_entry!.id);
      state = state.copyWith(
        friends: friends,
        status: DetailActionStatus.shareUpdated,
      );
    } catch (e, st) {
      Logger().fatal('Fehler beim Teilen: $e', stack: st);
      state = state.copyWith(status: DetailActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Aktualisiert die Berechtigungsstufe eines Freundes.
  Future<void> updateAccessLevel(UserEntity user, int newLevel) async {
    // Validierung der Parameter
    if (newLevel < 0 || newLevel > 2) {
      // 2 = Lesen und Schreiben is ok, aber 3 = Vollzugriff ist hier nicht erlaubt
      state = state.copyWith(status: DetailActionStatus.failure, error: AppError(ErrorCode.valueInvalid));
      return;
    }

    if (state.isBusy) return;

    // Status auf loading setzen
    state = state.copyWith(status: DetailActionStatus.progress, error: AppError.none());

    try {
      if (_entry == null) throw Exception('Kein Eintrag zum Teilen geladen.');
      if (_entryKey == null) throw Exception('Der AES-Schlüssel des Eintrags ${_entry!.id} ist nicht entpackt.');

      // 1. Aktuelle Berechtigungen des Freundes auf diesen Eintrag aus der Datenbank laden
      final perm = await _databaseService.getPermissionByEntryIdAndUserId(_entry!.id, user.id);
      if (perm != null) {
        // Parameter user ist nicht korrekt!
        state = state.copyWith(status: DetailActionStatus.failure, error: AppError(ErrorCode.valueInvalid, text: 'Eintrag ${_entry!.id} wird nicht mit Freund ${user.name} geteilt. Berechtigung kann nicht geändert werden.'));
        return;
      }

      // Trivial-Check: keine Änderung?
      if (perm!.accessLevel == newLevel) {
        state = state.copyWith(status: DetailActionStatus.loaded);
        return; // keine Änderung -> Operation erfolgreich!
      }

      // 2. Entry-Key löschen bzw. neu generieren, falls erforderlich
      String encKey = perm.encryptedKey;
      if (newLevel == 0) {
        encKey = ''; // Key löschen bei Rechteentzug
      } else if (encKey.isEmpty) {
        encKey = await _cryptoService.encryptRsa(_entryKey!, user.publicKey);
      }

      // 3. Zugriffsrecht und Entry-Key in der Datenbank speichern
      await _databaseService.savePermission(perm.copyWith(accessLevel: newLevel, encryptedKey: encKey));

      // 4. Zeitstempel des Eintrags aktualisieren
      _entry = _entry!.copyWith(updatedAt: DateTime.now().toUtc());
      await _databaseService.saveEntry(_entry!);

      // 5. State aktualisieren
      final friends = await _databaseService.getNotHiddenFriendsWithAccessLevel(_entry!.id);
      state = state.copyWith(
        friends: friends,
        status: newLevel > 0 ? DetailActionStatus.shareUpdated : DetailActionStatus.accessRevoked,
      );
    } catch (e, st) {
      Logger().fatal('Rechte konnten nicht geändert werden: $e', stack: st);
      state = state.copyWith(status: DetailActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Entzieht einem Freund den Zugriff auf diesen Eintrag.
  Future<void> revokeAccess(UserEntity user) async {
    await updateAccessLevel(user, 0);
  }
}