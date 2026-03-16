import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:open_filex/open_filex.dart';
import 'package:privault/core/app_error.dart';
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

  /// Der entschlüsselte 32-Byte AES-Schlüssel für diesen spezifischen Eintrag.
  /// Wird benötigt, um Daten und Anhänge zu ver- und zu entschlüsseln.
  Uint8List? _entryKey;

  /// Liste der Dateianhänge
  List<AttachmentEntity> _attachments = []; // todo auch im State

  /// Meta-Daten der Anhänge
  final Map<String, AttachmentMetaPayload> _attachmentMetas = {};

  /// Vollständige Freundesliste der lokalen Datenbank
  List<UserEntity> _friends = [];

  /// Liste der Freunde mit Zugriff auf diesen Eintrag
  List<UserEntity> _sharedFriends = []; // todo auch im State

  /// Zugriffsstufen der Freunde
  final Map<int, int> _friendAccessLevels = {};

  /// Die Zugriffsstufe des aktuellen Benutzers (1=Lesen, 2=Schreiben, 3=Besitzer).
  int _myAccessLevel = 1;

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
    // Busy setzen, Fehler zurücksetzen
    state = state.copyWith(isBusy: true, error: FormError.none());

    try {
      // 1. Eintrag aus Datenbank laden
      _entry = await _databaseService.getEntry(id);
      if (_entry == null) throw Exception("Eintrag nicht gefunden");

      // 2. Berechtigung prüfen
      final perm = await _databaseService.getPermissionByEntryIdAndUserId(_entry!.id, 1);
      if (perm == null) throw Exception("Keine Berechtigung für diesen Eintrag");
      _myAccessLevel = perm.accessLevel;

      // 3. Entry-Key mittels RSA entschlüsseln
      if (_sessionService.privateKey == null) throw Exception("Sitzungsschlüssel fehlt");
      _entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, utf8.decode(_sessionService.privateKey!));

      // 4. Stammdaten mittels AES entschlüsseln
      final decryptedData = await _cryptoService.decrypt(_entry!.encryptedData, _entryKey!);
      final payload = EntryPayload.fromJson(json.decode(utf8.decode(decryptedData)));

      // 5. UI‑State aktualisieren
      state = state.copyWith(
        title: payload.title,
        category: payload.category,
        username: payload.username,
        password: payload.password,
        url: payload.url,
        notes: payload.notes,
        favicon: _entry!.favicon,
      );

      // 6. Metadaten und Listen laden
      await _updateAuditHint();
      await _loadAttachments();
      await _loadSharedFriends();
      await _loadFriends();
    } catch (e, st) {
      Logger().fatal("Fehler beim Laden: $e", stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));
    } finally {
      // Busy zurücksetzen
      state = state.copyWith(isBusy: false);
    }
  }

  // ------------------------------------------------------------------------
  // --- Audit-Hinweis ---
  // ------------------------------------------------------------------------

  /// Aktualisiert den Audit-Hinweis über Ersteller und letzte Änderung.
  Future<void> _updateAuditHint() async {
    var creator = "Unbekannt";
    var updater = "Unbekannt";

    final cu = _entry!.creatorId != 0 ? await _databaseService.getUser(_entry!.creatorId) : null;
    final uu = _entry!.updaterId != 0 ? await _databaseService.getUser(_entry!.updaterId) : null;

    if (cu != null) creator = cu.name;
    if (uu != null) updater = uu.name;

    final dateStr = DateFormat("dd.MM.yyyy HH:mm:ss").format(_entry!.updatedAt.toLocal());
    final hint = "• Erstellt von: $creator \n• Zuletzt bearbeitet von: $updater, am $dateStr";

    state = state.copyWith(auditHint: hint);
  }

  // ------------------------------------------------------------------------
  // --- Anhänge ---
  // ------------------------------------------------------------------------

  /// Lädt und entschlüsselt die Metadaten aller Anhänge (Lazy Loading).
  Future<void> _loadAttachments() async {
    _attachments = await _databaseService.getAttachmentsByEntryId(_entry!.id);
    _attachmentMetas.clear();

    for (var att in _attachments) {
      final decryptedMeta = await _cryptoService.decrypt(att.encryptedMeta, _entryKey!);
      _attachmentMetas[att.uuid] = AttachmentMetaPayload.fromJson(json.decode(utf8.decode(decryptedMeta)));
    }

    state = state.copyWith(attachments: _attachments);
  }

  // todo
  /// Fügt dem aktuellen Eintrag einen neuen Dateianhang hinzu.
  Future<bool> addAttachment() async {
    if (_entry == null || _entryKey == null) return false;

    // Busy setzen, Fehler zurücksetzen
    state = state.copyWith(isBusy: true, error: FormError.none());

    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return false;
      final file = result.files.first;
      final bytes = file.bytes!;
      final mimeType = _getMimeType(file.name);

      // Thumbnail erzeugen falls Bild
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

      // 4. Haupteintrag aktualisieren (für Sync-Trigger)
      _entry = _entry!.copyWith(updatedAt: DateTime.now().toUtc());
      await _databaseService.saveEntry(_entry!);

      await _loadAttachments();
      return true;

    } catch (e, st) {
      Logger().fatal('Fehler beim Hinzufügen eines Anhangs: $e', stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));
      return false;

    } finally {
      // Busy zurücksetzen
      state = state.copyWith(isBusy: false);
    }
  }

  // todo
  /// Entschlüsselt einen Anhang und öffnet ihn mit der System-App.
  Future<bool> openAttachment(AttachmentEntity attachment) async {
    if (_entryKey == null) return false;

    // Busy setzen, Fehler zurücksetzen
    state = state.copyWith(isBusy: true, error: FormError.none());

    try {
      final meta = _attachmentMetas[attachment.uuid];
      if (meta == null) throw Exception("Metadaten fehlen");

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
              Logger().debug('🔐 Sicherheits-Cleanup: Temporäre Datei gelöscht (Versuch ${i + 1}).');
              break;
            }
          } catch (e) {
            // Fehler nur loggen, den Cleanup-Prozess aber nicht unterbrechen.
            Logger().error('Fehler beim Entfernen der temporären Datei (Versuch ${i + 1}): $e');
            state = state.copyWith(error: FormError(ErrorCode.cleanupFailed));
          }
        }
      });

      return true;

    } catch (e, st) {
      Logger().fatal('Fehler beim Öffnen des Anhangs: $e', stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));
      return false;

    } finally {
      // Busy zurücksetzen
      state = state.copyWith(isBusy: false);
    }
  }

  // todo
  /// Löscht einen spezifischen Anhang.
  Future<bool> deleteAttachment(AttachmentEntity attachment) async {
    // Busy setzen, Fehler zurücksetzen
    state = state.copyWith(isBusy: true, error: FormError.none());

    try {
      await _databaseService.deleteAttachment(attachment.id);
      await _loadAttachments();
      return true;
    } catch (e, st) {
      Logger().fatal('Fehler beim Löschen: $e', stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));
      return false;
    } finally {
      // Busy zurücksetzen
      state = state.copyWith(isBusy: false);
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

  /// Ermittelt den Datei-Typ basierend auf Dateiendung.
  String _getMimeType(String filename) {
    // @formatter:off
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg': return 'image/jpeg';
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'gif': return 'image/gif';
      case 'bmp': return 'image/bmp';
      case 'webp': return 'image/webp';
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt': return 'application/vnd.ms-powerpoint';
      case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls': return 'application/vnd.ms-excel';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv': return 'text/csv';
      case 'vcf': return 'text/vcard';
      case 'mp3': return 'audio/mpeg';
      case 'wav': return 'audio/wav';
      case 'flac': return 'audio/flac';
      case 'aac': return 'audio/aac';
      case 'ogg': return 'audio/ogg';
      case 'mp4': return 'video/mp4';
      case 'avi': return 'video/x-msvideo';
      case 'mov': return 'video/quicktime';
      case 'mkv': return 'video/x-matroska';
      case 'webm': return 'video/webm';
      case 'zip': return 'application/zip';
      case 'rar': return 'application/vnd.rar';
      case 'tar': return 'application/x-tar';
      case '7z': return 'application/x-7z-compressed';
      case 'txt': return 'text/plain';
      case 'md': return 'text/markdown';
      default: return 'application/octet-stream';
    }
    // @formatter:on
  }

  // todo
  /// Ermittelt den Datei-Typ basierend auf Dateiendung oder MIME-Typ (Portiert aus MAUI).
  String getIconType(String filename, String mimeType) {
    final file = filename.toLowerCase();
    if (file.endsWith(".png") || file.endsWith(".jpg") || file.endsWith(".jpeg") || file.endsWith(".gif") || file.endsWith(".bmp") || file.endsWith(".webp")) {
      return "image";
    }
    if (file.endsWith(".pdf")) return "pdf";
    if (file.endsWith(".doc") || file.endsWith(".docx")) return "word";
    if (file.endsWith(".ppt") || file.endsWith(".pptx")) return "slides";
    if (file.endsWith(".xls") || file.endsWith(".xlsx") || file.endsWith(".csv")) return "excel";
    if (file.endsWith(".vcf")) return "vcard";
    if (file.endsWith(".mp3") || file.endsWith(".wav") || file.endsWith(".flac") || file.endsWith(".aac") || file.endsWith(".ogg")) {
      return "audio";
    }
    if (file.endsWith(".mp4") || file.endsWith(".avi") || file.endsWith(".mov") || file.endsWith(".mkv") || file.endsWith(".webm")) {
      return "video";
    }
    if (file.endsWith(".zip") || file.endsWith(".rar") || file.endsWith(".tar") || file.endsWith(".7z")) return "archive";
    if (file.endsWith(".txt") || file.endsWith(".md")) return "text";

    final mime = mimeType.toLowerCase();
    if (mime.startsWith("image/")) return "image";
    if (mime.contains("pdf")) return "pdf";
    if (mime.contains("word") || mime.contains("msword") || mime.contains("doc")) return "word";
    if (mime.contains("presentation") || mime.contains("powerpoint") || mime.contains("ppt")) return "slides";
    if (mime.contains("excel") || mime.contains("sheet") || mime.contains("xls")) return "excel";
    if (mime.contains("vcard") || mime.contains("contact")) return "vcard";
    if (mime.contains("audio")) return "audio";
    if (mime.contains("video")) return "video";
    if (mime.contains("zip") || mime.contains("rar") || mime.contains("7z") || mime.contains("tar")) return "archive";
    if (mime.contains("text")) return "text";

    return "generic";
  }

  // todo
  /// Formatiert Byte-Größen in lesbare Einheiten (KB, MB, GB).
  String formatSize(int bytes) {
    const scale = 1024;
    const orders = ["B", "KB", "MB", "GB"];
    double size = bytes.toDouble();
    int order = 0;
    while (size >= scale && order < orders.length - 1) {
      order++;
      size /= scale;
    }
    return "${size.toStringAsFixed(2)} ${orders[order]}";
  }

  // ------------------------------------------------------------------------
  // --- Geteilt mit ---
  // ------------------------------------------------------------------------

  /// Lädt die vollständige Liste aller Benutzer aus der lokalen Datenbank
  Future<void> _loadFriends() async {
    final allUsers = await _databaseService.getUsers();
    _friends = allUsers.where((u) => u.id > 1 && !u.isHidden).toList();
  }

  // todo
  /// Teilt den Eintrag mit einem Freund.
  Future<bool> shareWith(UserEntity targetUser) async {
    if (_entry == null || _entryKey == null) return false;

    // Busy setzen, Fehler zurücksetzen
    state = state.copyWith(isBusy: true, error: FormError.none());

    try {
      final existing = await _databaseService.getPermissionByEntryIdAndUserId(_entry!.id, targetUser.id);

      if (existing == null) {
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
        String encryptedEntryKey = existing.encryptedKey;
        if (encryptedEntryKey.isEmpty) {
          encryptedEntryKey = await _cryptoService.encryptRsa(_entryKey!, targetUser.publicKey);
        }
        await _databaseService.savePermission(existing.copyWith(accessLevel: 1, encryptedKey: encryptedEntryKey));
      }

      _entry = _entry!.copyWith(updatedAt: DateTime.now().toUtc());
      await _databaseService.saveEntry(_entry!);
      await _loadSharedFriends();
      return true;
    } catch (e, st) {
      Logger().fatal('Fehler beim Teilen: $e', stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));
      return false;
    } finally {
      // Busy zurücksetzen
      state = state.copyWith(isBusy: false);
    }
  }

  // todo
  /// Aktualisiert die Berechtigungsstufe eines Freundes.
  Future<bool> updateAccessLevel(UserEntity user, int newLevel) async {
    if (_entry == null || _entryKey == null) return false;

    // Busy setzen, Fehler zurücksetzen
    state = state.copyWith(isBusy: true, error: FormError.none());

    try {
      final perm = await _databaseService.getPermissionByEntryIdAndUserId(_entry!.id, user.id);
      if (perm != null && perm.accessLevel != newLevel) {
        // Limit auf max Level 2 (wie in MAUI)
        final effectiveLevel = newLevel < 3 ? newLevel : 2; // Max Level 2 beim Teilen

        String encKey = perm.encryptedKey;
        if (effectiveLevel == 0) {
          encKey = ""; // Key löschen bei Rechteentzug
        } else if (encKey.isEmpty) {
          encKey = await _cryptoService.encryptRsa(_entryKey!, user.publicKey);
        }

        await _databaseService.savePermission(perm.copyWith(accessLevel: effectiveLevel, encryptedKey: encKey));

        _entry = _entry!.copyWith(updatedAt: DateTime.now().toUtc());
        await _databaseService.saveEntry(_entry!);
        await _loadSharedFriends();
      }

      return true;
    } catch (e, st) {
      Logger().fatal('Rechte konnten nicht geändert werden: $e', stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));
      return false;
    } finally {
      // Busy zurücksetzen
      state = state.copyWith(isBusy: false);
    }
  }

  /// Entzieht einem Freund den Zugriff auf diesen Eintrag.
  Future<bool> revokeAccess(UserEntity user) async {
    return await updateAccessLevel(user, 0);
  }

  /// Lädt die Liste der Freunde, mit denen dieser Eintrag geteilt wird.
  Future<void> _loadSharedFriends() async {
    if (_entry == null) return; // todo

    final permissions = await _databaseService.getPermissionsByEntryId(_entry!.id);

    List<UserEntity> shared = [];
    _friendAccessLevels.clear();

    for (var p in permissions) {
      if (p.userId == 1) continue;
      if (p.accessLevel == 0) continue;

      final friend = await _databaseService.getUser(p.userId);
      if (friend != null) {
        shared.add(friend);
        _friendAccessLevels[friend.id] = p.accessLevel;
      }
    }

    _sharedFriends = shared;

    state = state.copyWith( // todo
      sharedFriends: shared,
      canEdit: _myAccessLevel >= 2,
      canManageShares: _myAccessLevel >= 3,
    );
  }

  // ------------------------------------------------------------------------
  // --- Convenience Setter & Getter ---
  // ------------------------------------------------------------------------

  // --- Stammdaten ---

  /// Berechnete Stärke des Passworts (0-4).
  int getPasswordStrength() {
    return _passwordService.estimateStrength(state.password);
  }

  /// Festhalten, dass die Daten geändert wurden.
  void markAsChanged() {
    state = state.copyWith(hasChanged: true);
  }

  // --- Anhänge ---

  /// Gibt an, ob der aktuelle Benutzer Anhänge verwalten darf.
  bool canManageAttachments() {
    return _myAccessLevel >= 2;
  }

  /// Liefert die entschlüsselten Metadaten eines Anhangs.
  AttachmentMetaPayload? getAttachmentMeta(String uuid) {
    return _attachmentMetas[uuid];
  }

  // --- Geteilt mit ---

  /// Gibt an, ob der aktuelle Benutzer Schreibrechte besitzt.
  bool canEdit() {
    return _myAccessLevel >= 2;
  }

  /// Gibt an, ob der aktuelle Benutzer die Freigaben verwalten darf (nur Besitzer).
  bool canManageShares() {
    return _myAccessLevel >= 3;
  }

  /// Liste der Freunde, mit denen der Eintrag noch nicht geteilt wurde.
  List<UserEntity> getUnsharedFriends() {
    final sharedIds = _sharedFriends.map((u) => u.id).toSet();
    return _friends.where((u) => u.id != 1 && !sharedIds.contains(u.id)).toList();
  }

  /// Ermittelt die Zugriffsstufe für einen bestimmten Freund.
  int getAccessLevel(int userId) {
    return _friendAccessLevels[userId] ?? 1;
  }

  /// Gibt die Fehlermeldung für ein bestimmtes Feld zurück oder null.
  String? getFieldErrorText(String field) {
    return state.error.field == field ? state.error.text : null;
  }
}