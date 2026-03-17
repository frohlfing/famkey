import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:open_filex/open_filex.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/icon_helper.dart';
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
    state = const DetailState().copyWith(status: DetailActionStatus.loading, error: FormError.none());

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
      _entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, utf8.decode(_sessionService.privateKey!));

      // 4. Stammdaten mittels AES entschlüsseln
      final decryptedData = await _cryptoService.decrypt(_entry!.encryptedData, _entryKey!);
      final payload = EntryPayload.fromJson(json.decode(utf8.decode(decryptedData)));

      // 5. Audit-Hinweis generieren
      final auditHint = await _createAuditHint();

      // 6. Dateianhänge laden
      final attachments = await _databaseService.getAttachmentsByEntryId(_entry!.id);
      final attachmentMetas = await _loadAttachmentMetas(attachments);

      // 7. Freunde laden
      // todo dies kann alles zusammen mit einer Datenbankabfrage zusammengefasst werden und in einer Map auf benannten Record gespeichert werden
      final allFriends = await _databaseService.getNotHiddenFriends();
      final permissions = await _databaseService.getPermissionsByEntryId(_entry!.id);
      final sharedFriends = await _loadSharedFriends(permissions);
      final friendAccessLevels = await _loadFriendAccessLevels(permissions);

      // 8. Alles zusammen in den State schreiben
      state = state.copyWith(
        // Stammdaten
        category: payload.category,
        title: payload.title,
        username: payload.username,
        password: payload.password,
        passwordStrength: _passwordService.estimateStrength(payload.password),
        url: payload.url,
        notes: payload.notes,
        favicon: _entry!.favicon,
        auditHint: auditHint,
        // Anhänge
        attachments: attachments,
        attachmentMetas: attachmentMetas,
        // Freunde
        allFriends: allFriends,
        sharedFriends: sharedFriends,
        friendAccessLevels: friendAccessLevels,
        // Zugriffsrecht
        myAccessLevel: myAccessLevel,
        // Status
        status: DetailActionStatus.success,
      );
    } catch (e, st) {
      Logger().fatal("Fehler beim Laden: $e", stack: st);
      state = state.copyWith(status: DetailActionStatus.failure, error: FormError(ErrorCode.unknown));
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

  /// Kopiert den Text in die Zwischenablage.
  void copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

   /// Öffnet die URL in einem neuen Browser-Tab.
  Future<void> openUrl() async {
    if (state.url.isEmpty) return;
    final uri = Uri.parse(state.url.startsWith('http') ? state.url : 'https://${state.url}');
    try {
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success) {
        state = state.copyWith(status: DetailActionStatus.failure, error: FormError(ErrorCode.unknown, text: 'Die URL konnte nicht geöffnet werden.'));
      }
    } catch (e, st) {
      Logger().fatal('Fehler beim Öffnen der URL ${state.url}: $e', stack: st);
      state = state.copyWith(status: DetailActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Anhänge ---
  // ------------------------------------------------------------------------

  /// Lädt und entschlüsselt die Metadaten aller Anhänge (Lazy Loading).
  Future<Map<String, AttachmentMetaPayload>> _loadAttachmentMetas(List<AttachmentEntity> attachments) async {
    final metas = <String, AttachmentMetaPayload>{};
    for (var att in attachments) {
      final decryptedMeta = await _cryptoService.decrypt(att.encryptedMeta, _entryKey!);
      metas[att.uuid] = AttachmentMetaPayload.fromJson(json.decode(utf8.decode(decryptedMeta)));
    }
    return metas;
  }

  /// Fügt dem aktuellen Eintrag einen neuen Dateianhang hinzu.
  Future<void> addAttachment() async {
    if (state.isBusy) return;

    // Status auf loading setzen
    state = state.copyWith(status: DetailActionStatus.loading, error: FormError.none());

    try {
      if (_entry == null) throw Exception('Kein Eintrag zum Anhängen einer Datei geladen.');
      if (_entryKey == null) throw Exception('Der AES-Schlüssel des Eintrags ${_entry!.id} ist nicht entpackt.');

      // Datei auswählen
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) {
        state = state.copyWith(status: DetailActionStatus.initial);
        return;
      }
      final file = result.files.first;
      final bytes = file.bytes!;
      final mimeType = getMimeType(file.name);

      // Thumbnail erzeugen (wenn es ein Bild ist)
      String? thumbnailBase64;
      if (mimeType.startsWith('image/')) {
        // compute lagert eine Berechnung in einen separaten Worker-Thread aus.
        // Die Worker-Funktion darf keine Instanz-Methode sein, sonst wird versucht,
        // das gesamte DetailViewModel in den Thread zu kopieren, was schief geht.
        thumbnailBase64 = await compute(_createThumbnail, bytes);
      }

      // 1. Metadaten-Payload vorbereiten
      final metaPayload = AttachmentMetaPayload(filename: file.name,
          mime: mimeType,
          size: bytes.length,
          timestamp: DateTime.now().toUtc(),
          thumbnail: thumbnailBase64);

      // 2. Verschlüsseln (AES)
      final encryptedMeta = await _cryptoService.encrypt(Uint8List.fromList(utf8.encode(json.encode(metaPayload.toJson()))), _entryKey!);
      final encryptedContent = await _cryptoService.encrypt(bytes, _entryKey!);

      // 3. Entity speichern
      await _databaseService.saveAttachment(AttachmentEntity(
        id: 0,
        uuid: const Uuid().v4(),
        entryId: _entry!.id,
        encryptedMeta: encryptedMeta,
        encryptedContent: encryptedContent,
        isSynced: false,
      ));

      // 4. Zeitstempel des Eintrags aktualisieren
      _entry = _entry!.copyWith(updatedAt: DateTime.now().toUtc());
      await _databaseService.saveEntry(_entry!);

      // 5. State aktualisieren
      final attachments = await _databaseService.getAttachmentsByEntryId(_entry!.id);
      final attachmentMetas = await _loadAttachmentMetas(attachments);
      state = state.copyWith(
        attachments: attachments,
        attachmentMetas: attachmentMetas,
        status: DetailActionStatus.attachmentAdded,
      );
    } catch (e, st) {
      Logger().fatal('Fehler beim Hinzufügen eines Anhangs: $e', stack: st);
      state = state.copyWith(status: DetailActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  /// Entschlüsselt einen Anhang und öffnet ihn mit der System-App.
  Future<void> openAttachment(AttachmentEntity attachment) async {
    if (state.isBusy) return;

    // Status auf loading setzen
    state = state.copyWith(status: DetailActionStatus.loading, error: FormError.none());

    try {
      if (_entry == null) throw Exception('Kein Eintrag zum Öffnen des Anhangs geladen.');
      if (_entryKey == null) throw Exception('Der AES-Schlüssel des Eintrags ${_entry!.id} ist nicht entpackt.');
      final meta = state.attachmentMetas[attachment.uuid];
      if (meta == null) throw Exception("Metadaten des Anhangs ${attachment.uuid} fehlen");

      // Inhalt entschlüsseln
      final decryptedContent = await _cryptoService.decrypt(attachment.encryptedContent, _entryKey!);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${meta.filename}');
      await tempFile.writeAsBytes(decryptedContent);

      // Datei öffnen
      await OpenFilex.open(tempFile.path);

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
            state = state.copyWith(error: FormError(ErrorCode.cleanupFailed));
          }
        }
      });

      state = state.copyWith(status: DetailActionStatus.success);
    } catch (e, st) {
      Logger().fatal('Fehler beim Öffnen des Anhangs: $e', stack: st);
      state = state.copyWith(status: DetailActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  /// Löscht einen spezifischen Anhang.
  Future<void> deleteAttachment(AttachmentEntity attachment) async {
    if (state.isBusy) return;

    // Status auf loading setzen
    state = state.copyWith(status: DetailActionStatus.loading, error: FormError.none());

    try {
      await _databaseService.deleteAttachment(attachment.id);
      final attachments = await _databaseService.getAttachmentsByEntryId(_entry!.id);
      final attachmentMetas = await _loadAttachmentMetas(attachments);
      state = state.copyWith(
        attachments: attachments,
        attachmentMetas: attachmentMetas,
        status: DetailActionStatus.attachmentDeleted,
      );
    } catch (e, st) {
      Logger().fatal('Fehler beim Löschen: $e', stack: st);
      state = state.copyWith(status: DetailActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  /// Erzeugt ein Vorschaubild ohne Ränder (Aspect-Fit MAUI Parität)
  /// Die Funktion muss static sein, das sie innerhalb eines Worker-Threads aufgerufen wird.
  static String? _createThumbnail(Uint8List bytes) {
    try {
      // 1. Image dekodieren
      final image = img.decodeImage(bytes);
      if (image == null || image.width <= 0 || image.height <= 0) return null;

      const maxWidth = 128;
      const maxHeight = 128;

      // 2. Aspect-Fit berechnen (wie in MAUI Logik)
      final scale = math.min(maxWidth / image.width, maxHeight / image.height);
      final newW = math.max(1, (image.width * scale).round());
      final newH = math.max(1, (image.height * scale).round());

      // 3. Resize auf exakte Zielgröße (verhindert Trauerränder)
      final thumbnail = img.copyResize(image, width: newW, height: newH, interpolation: img.Interpolation.linear);

      // 4. Encode mit 80% Qualität
      return base64Encode(img.encodeJpg(thumbnail, quality: 80));
    } catch (e) {
      // In statischen Methoden können wir kein logError() der Instanz rufen!
      // Wir loggen hier nur auf die Konsole oder geben null zurück.
      debugPrint('Thumbnail-Fehler: $e');
      return null;
    }
  }

  // ------------------------------------------------------------------------
  // --- Geteilt mit ---
  // ------------------------------------------------------------------------

  /// Lädt die Liste der Freunde, mit denen dieser Eintrag geteilt wird.
  Future<List<UserEntity>> _loadSharedFriends(List<PermissionEntity> permissions) async {
    List<UserEntity> shared = [];
    for (var p in permissions) {
      if (p.userId == 1 || p.accessLevel == 0) continue; // Benutzer der App (id=1) ist kein Freund
      final friend = await _databaseService.getUser(p.userId);
      if (friend != null) {
        shared.add(friend);
      }
    }
    return shared;
  }

  /// Lädt die Liste der Freunde, mit denen dieser Eintrag geteilt wird.
  Future<Map<int, int>> _loadFriendAccessLevels(List<PermissionEntity> permissions) async {
    final accessLevels = <int, int>{};
    for (var p in permissions) {
      if (p.userId == 1 || p.accessLevel == 0) continue; // Benutzer der App (id=1) ist kein Freund
      final friend = await _databaseService.getUser(p.userId);
      if (friend != null) {
        accessLevels[friend.id] = p.accessLevel;
      }
    }
    return accessLevels;
  }

  /// Teilt den Eintrag mit einem Freund.
  Future<void> shareWith(UserEntity targetUser) async {
    if (state.isBusy) return;

    // Status auf loading setzen
    state = state.copyWith(status: DetailActionStatus.loading, error: FormError.none());

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
      final permissions = await _databaseService.getPermissionsByEntryId(_entry!.id);
      final sharedFriends = await _loadSharedFriends(permissions);
      final friendAccessLevels = await _loadFriendAccessLevels(permissions);
      state = state.copyWith(
        sharedFriends: sharedFriends,
        friendAccessLevels: friendAccessLevels,
        status: DetailActionStatus.shareUpdated,
      );
    } catch (e, st) {
      Logger().fatal('Fehler beim Teilen: $e', stack: st);
      state = state.copyWith(status: DetailActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  /// Aktualisiert die Berechtigungsstufe eines Freundes.
  Future<void> updateAccessLevel(UserEntity user, int newLevel) async {
    // Validierung der Parameter
    if (newLevel < 0 || newLevel > 2) {
      // 2 = Lesen und Schreiben is ok, aber 3 = Vollzugriff ist hier nicht erlaubt
      state = state.copyWith(status: DetailActionStatus.failure, error: FormError(ErrorCode.valueInvalid));
      return;
    }

    if (state.isBusy) return;

    // Status auf loading setzen
    state = state.copyWith(status: DetailActionStatus.loading, error: FormError.none());

    try {
      if (_entry == null) throw Exception('Kein Eintrag zum Teilen geladen.');
      if (_entryKey == null) throw Exception('Der AES-Schlüssel des Eintrags ${_entry!.id} ist nicht entpackt.');

      // 1. Aktuelle Berechtigungen des Freundes auf diesen Eintrag aus der Datenbank laden
      final perm = await _databaseService.getPermissionByEntryIdAndUserId(_entry!.id, user.id);
      if (perm != null) {
        // Parameter user ist nicht korrekt!
        state = state.copyWith(status: DetailActionStatus.failure, error: FormError(ErrorCode.valueInvalid, text: 'Eintrag ${_entry!.id} wird nicht mit Freund ${user.name} geteilt. Berechtigung kann nicht geändert werden.'));
        return;
      }

      // Trivial-Check: keine Änderung?
      if (perm!.accessLevel == newLevel) {
        state = state.copyWith(status: DetailActionStatus.success);
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
      final permissions = await _databaseService.getPermissionsByEntryId(_entry!.id);
      final friendAccessLevels = await _loadFriendAccessLevels(permissions);
      state = state.copyWith(
        friendAccessLevels: friendAccessLevels,
        status: newLevel > 0 ? DetailActionStatus.shareUpdated : DetailActionStatus.accessRevoked,
      );
    } catch (e, st) {
      Logger().fatal('Rechte konnten nicht geändert werden: $e', stack: st);
      state = state.copyWith(status: DetailActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  /// Entzieht einem Freund den Zugriff auf diesen Eintrag.
  Future<void> revokeAccess(UserEntity user) async {
    await updateAccessLevel(user, 0);
  }
}