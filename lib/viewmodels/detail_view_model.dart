import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:privault/core/base_view_model.dart';
import 'package:privault/models/entities/user_entity.dart';
import 'package:privault/models/entities/entry_entity.dart';
import 'package:privault/models/entities/attachment_entity.dart';
import 'package:privault/models/entities/permission_entity.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/models/payloads/attachment_meta_payload.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:privault/services/password_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;

/// Das `DetailViewModel` ist für die Anzeige eines Tresoreintrags verantwortlich.
/// Außerdem können hier Dateien an den Eintrag angehängt und Freunde für den Zugriff
/// auf den Eintrag berechtigt werden.
class DetailViewModel extends BaseViewModel {

    // ------------------------------------------------------------------------
    // --- Verwendete Dienste ---
    // ------------------------------------------------------------------------

    final CryptoService _cryptoService;
    final DatabaseService _databaseService;
    final SessionService _sessionService;
    final PasswordService _passwordService;

    // ------------------------------------------------------------------------
    // --- Interne Variablen ---
    // ------------------------------------------------------------------------

    /// Die aktuell geladene Datenbank-Entität.
    EntryEntity? _entry;

    /// Der entschlüsselte 32-Byte AES-Schlüssel für diesen spezifischen Eintrag.
    /// Wird benötigt, um Daten und Anhänge zu ver- und zu entschlüsseln.
    Uint8List? _entryKey;

    // Felder für die Stammdaten
    String _title = '';
    String _category = '';
    String _username = '';
    String _password = '';
    String _url = '';
    String _notes = '';
    String _favicon = '';
    String _auditHint = '';

    /// Gibt an, ob das Passwort ausgeblendet ist
    bool _isPasswordHidden = true;

    /// Liste der Dateianhänge
    List<AttachmentEntity> _attachments = [];

    /// Meta-Daten der Anhänge
    final Map<String, AttachmentMetaPayload> _attachmentMetas = {};

    /// Liste der Freunde mit Zugriff auf diesen Eintrag
    List<UserEntity> _sharedWith = [];

    /// Zugriffsstufen der Freunde
    final Map<int, int> _userAccessLevels = {};

    /// Vollständige Benutzerliste der lokalen Datenbank
    List<UserEntity> _allUsers = [];

    /// Die Zugriffsstufe des aktuellen Benutzers (1=Lesen, 2=Schreiben, 3=Besitzer).
    int _myAccessLevel = 1;

    // ------------------------------------------------------------------------
    // --- Initialisierung & Lifecycle ---
    // ------------------------------------------------------------------------

    /// Konstruktor
    DetailViewModel(this._cryptoService, this._databaseService, this._sessionService, this._passwordService);

    /// Initialisiert das ViewModel und lädt den Eintrag anhand seiner ID.
    Future<void> initialize(int id) async {
        setBusy(true);
        clearError();
        try {
            _entry = await _databaseService.getEntryById(id);
            if (_entry == null) throw Exception("Eintrag nicht gefunden");

            // 1. Berechtigung prüfen
            final perm = await _databaseService.getPermissionByEntryAndUser(_entry!.id!, 1);
            if (perm == null) throw Exception("Keine Berechtigung für diesen Eintrag");
            _myAccessLevel = perm.accessLevel;

            // 2. Entry-Key mittels RSA entschlüsseln
            if (_sessionService.privateKey == null) throw Exception("Sitzungsschlüssel fehlt");
            _entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, utf8.decode(_sessionService.privateKey!));

            // 3. Stammdaten mittels AES entschlüsseln
            final decryptedData = await _cryptoService.decrypt(_entry!.encryptedData, _entryKey!);
            final payload = EntryPayload.fromJson(json.decode(utf8.decode(decryptedData)));
            _title = payload.title;
            _category = payload.category;
            _username = payload.username;
            _password = payload.password;
            _url = payload.url;
            _notes = payload.notes;
            _favicon = _entry!.favicon;

            // 4. Metadaten und Listen laden
            await _updateAuditHint();
            await _loadAttachments();
            await _loadSharedUsers();
            await _loadAllUsers();
        }
        catch (e, st) {
            logError("Entschlüsselung fehlgeschlagen: $e", st);
            notifyUnexpectedError();
        }
        finally {
            setBusy(false);
        }
    }

    // ------------------------------------------------------------------------
    // --- Eigenschaften & Methoden für Stammdaten  ---
    // ------------------------------------------------------------------------

    /// Die Kategorie des Eintrags.
    String get category => _category;

    /// Der Anzeigename des Eintrags.
    String get title => _title;

    /// Der Benutzername des Eintrag.
    String get username => _username;

    /// Der Passwort des Eintrag.
    String get password => _password;

    /// Für das Passwort-Auge. Steuert, ob das Passwortfeld im Klartext oder verborgen angezeigt wird.
    bool get isPasswordHidden => _isPasswordHidden;

    /// Berechnete Stärke des Passworts (0-4).
    int get passwordStrength => _passwordService.estimateStrength(_password);

    /// Schaltet die Sichtbarkeit des Passworts um.
    void togglePasswordVisibility() {
        _isPasswordHidden = !_isPasswordHidden;
        notifyListeners();
    }

    /// Die zugehörige Adresse der Webseite oder des Dienstes.
    String get url => _url;

    /// Ergänzende Notiz (Metadaten).
    String get notes => _notes;

    /// Der binäre Dateninhalt des Website-Icons, gespeichert als Base64-kodierter String.
    /// Ermöglicht die visuelle Identifikation in der Liste ohne zusätzliche Netzwerkanfragen.
    String get favicon => _favicon;

    /// Ein Text-Hinweis über den Ersteller und den Zeitpunkt der letzten Änderung.
    String get auditHint => _auditHint;

    /// Erzeugt ein Vorschaubild ohne Ränder (Aspect-Fit MAUI Parität)
    String? _createThumbnail(Uint8List bytes) {
        try {
            final image = img.decodeImage(bytes);
            if (image == null || image.width <= 0 || image.height <= 0) return null;

            const int maxWidth = 128;
            const int maxHeight = 128;

            // 2) Aspect-Fit berechnen (wie in MAUI Logik)
            final double scale = math.min(maxWidth / image.width, maxHeight / image.height);
            final int newW = math.max(1, (image.width * scale).round());
            final int newH = math.max(1, (image.height * scale).round());

            // 3) Resize auf exakte Zielgröße (verhindert Trauerränder)
            final thumbnail = img.copyResize(image, width: newW, height: newH, interpolation: img.Interpolation.linear);

            // 4) Encode mit 80% Qualität
            return base64Encode(img.encodeJpg(thumbnail, quality: 80));
        }
        catch (e, st) {
            logError('Thumbnail-Fehler: $e', st);
            notifyUnexpectedError();
            return null;
        }
    }

    /// Aktualisiert den Audit-Hinweis über Ersteller und letzte Änderung.
    Future<void> _updateAuditHint() async {
        var creator = "Unbekannt";
        var updater = "Unbekannt";

        final cu = _entry!.creatorId != 0 ? await _databaseService.getUserById(_entry!.creatorId) : null;
        final uu = _entry!.updaterId != 0 ? await _databaseService.getUserById(_entry!.updaterId) : null;

        if (cu != null) creator = cu.name;
        if (uu != null) updater = uu.name;

        final dateStr = DateFormat("dd.MM.yyyy HH:mm:ss").format(_entry!.updatedAt.toLocal());
        _auditHint = "• Erstellt von: $creator \n• Zuletzt bearbeitet von: $updater, am $dateStr";
    }

    // ------------------------------------------------------------------------
    // --- Eigenschaften & Methoden für "Anhänge"  ---
    // ------------------------------------------------------------------------

    /// Liste der Anhänge dieses Eintrags, aufbereitet für die UI.
    List<AttachmentEntity> get attachments => _attachments;

    /// Gibt an, ob der aktuelle Benutzer Anhänge verwalten darf.
    bool get canManageAttachments => _myAccessLevel >= 2;

    /// Liefert die entschlüsselten Metadaten eines Anhangs.
    AttachmentMetaPayload? getAttachmentMeta(String uuid) => _attachmentMetas[uuid];

    /// Fügt dem aktuellen Eintrag einen neuen Dateianhang hinzu.
    Future<void> addAttachment() async {
        if (_entry == null || _entryKey == null) return;
        try {
            final result = await FilePicker.platform.pickFiles(withData: true);
            if (result == null || result.files.isEmpty) return;

            setBusy(true);
            final file = result.files.first;
            final bytes = file.bytes!;
            final mimeType = _getMimeType(file.name);

            // Thumbnail erzeugen falls Bild
            String? thumbnailBase64;
            if (mimeType.startsWith('image/')) {
                thumbnailBase64 = await compute(_createThumbnail, bytes);
            }

            // 1. Metadaten-Payload vorbereiten
            final metaPayload = AttachmentMetaPayload(
                filename: file.name,
                mime: mimeType,
                size: bytes.length,
                timestamp: DateTime.now().toUtc(),
                thumbnail: thumbnailBase64
            );

            // 2. Verschlüsseln (AES)
            final encryptedMeta = await _cryptoService.encrypt(Uint8List.fromList(utf8.encode(json.encode(metaPayload.toJson()))), _entryKey!);
            final encryptedContent = await _cryptoService.encrypt(bytes, _entryKey!);

            // 3. Entity speichern
            final attEntity = AttachmentEntity(
                uuid: const Uuid().v4(),
                entryId: _entry!.id!,
                encryptedMeta: encryptedMeta,
                encryptedContent: encryptedContent,
                isSynced: false
            );

            await _databaseService.saveAttachment(attEntity);

            // 4. Haupteintrag aktualisieren (für Sync-Trigger)
            _entry = _entry!.copyWith(updatedAt: DateTime.now().toUtc());
            await _databaseService.saveEntry(_entry!);

            await _loadAttachments();
        }
        catch (e, st) {
            logError("Fehler beim Hinzufügen: $e", st);
            notifyUnexpectedError();
        }
        finally {
            setBusy(false);
        }
    }

    /// Entschlüsselt einen Anhang und öffnet ihn mit der System-App.
    Future<void> openAttachment(AttachmentEntity attachment) async {
        if (_entryKey == null) return;
        setBusy(true);
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
                                logDebug('🔐 Sicherheits-Cleanup: Temporäre Datei gelöscht (Versuch ${i + 1}).');
                                break;
                            }
                        }
                        catch (e) {
                            // Fehler nur loggen, den Cleanup-Prozess aber nicht unterbrechen.
                            logError('Fehler beim Entfernen der temporären Datei (Versuch ${i + 1}): $e');
                            notifyError("Fehler beim Entfernen der temporären Datei.");
                        }
                    }
                }
            );
        }
        catch (e, st) {
            logError("Anhang konnte nicht geöffnet werden: $e", st);
            notifyUnexpectedError();
        }
        finally {
            setBusy(false);
        }
    }

    /// Löscht einen spezifischen Anhang.
    Future<void> deleteAttachment(AttachmentEntity attachment) async {
        setBusy(true);
        try {
            await _databaseService.deleteAttachment(attachment.id!);
            await _loadAttachments();
        }
        catch (e, st) {
            logError("Fehler beim Löschen: $e", st);
            notifyUnexpectedError();
        }
        finally {
            setBusy(false);
        }
    }

    /// Lädt und entschlüsselt die Metadaten aller Anhänge (Lazy Loading).
    Future<void> _loadAttachments() async {
        _attachments = await _databaseService.getAttachmentsByEntryId(_entry!.id!);
        _attachmentMetas.clear();
        for (var att in _attachments) {
            final decryptedMeta = await _cryptoService.decrypt(att.encryptedMeta, _entryKey!);
            _attachmentMetas[att.uuid] = AttachmentMetaPayload.fromJson(json.decode(utf8.decode(decryptedMeta)));
        }
        notifyListeners();
    }

    /// Ermittelt den Datei-Typ basierend auf Dateiendung.
    String _getMimeType(String filename) {
        final ext = filename.split('.').last.toLowerCase();
        switch (ext) {
            case 'jpg':
            case 'jpeg':
                return 'image/jpeg';
            case 'png':
                return 'image/png';
            case 'gif':
                return 'image/gif';
            case 'bmp':
                return 'image/bmp';
            case 'webp':
                return 'image/webp';
            case 'pdf':
                return 'application/pdf';
            case 'doc':
                return 'application/msword';
            case 'docx':
                return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            case 'ppt':
                return 'application/vnd.ms-powerpoint';
            case 'pptx':
                return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
            case 'xls':
                return 'application/vnd.ms-excel';
            case 'xlsx':
                return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
            case 'csv':
                return 'text/csv';
            case 'vcf':
                return 'text/vcard';
            case 'mp3':
                return 'audio/mpeg';
            case 'wav':
                return 'audio/wav';
            case 'flac':
                return 'audio/flac';
            case 'aac':
                return 'audio/aac';
            case 'ogg':
                return 'audio/ogg';
            case 'mp4':
                return 'video/mp4';
            case 'avi':
                return 'video/x-msvideo';
            case 'mov':
                return 'video/quicktime';
            case 'mkv':
                return 'video/x-matroska';
            case 'webm':
                return 'video/webm';
            case 'zip':
                return 'application/zip';
            case 'rar':
                return 'application/vnd.rar';
            case 'tar':
                return 'application/x-tar';
            case '7z':
                return 'application/x-7z-compressed';
            case 'txt':
                return 'text/plain';
            case 'md':
                return 'text/markdown';
            default:
            return 'application/octet-stream';
        }
    }

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
    // --- Eigenschaften & Methoden für "Geteilt mit"  ---
    // ------------------------------------------------------------------------

    /// Liste der Freunde und deren aktuelle Zugriffsstufe auf diesen Eintrag.
    List<UserEntity> get sharedWith => _sharedWith;

    /// Die Zugriffsstufe des aktuellen Benutzers (1=Lesen, 2=Schreiben, 3=Besitzer).
    int get myAccessLevel => _myAccessLevel; // todo wird das benötigt?

    /// Gibt an, ob der aktuelle Benutzer Schreibrechte besitzt.
    bool get canEdit => _myAccessLevel >= 2;

    /// Gibt an, ob der aktuelle Benutzer die Freigaben verwalten darf (nur Besitzer).
    bool get canManageShares => _myAccessLevel >= 3;

    /// Liste der Kontakte, mit denen der Eintrag noch nicht geteilt wurde.
    List<UserEntity> get availableContacts {
        final sharedIds = _sharedWith.map((u) => u.id).toSet();
        return _allUsers.where((u) => u.id != 1 && !sharedIds.contains(u.id)).toList();
    }
    /// Ermittelt die Zugriffsstufe für einen bestimmten Freund.
    int getAccessLevel(int userId) => _userAccessLevels[userId] ?? 1;

    /// Teilt den Eintrag mit einem Freund.
    Future<void> shareWith(UserEntity targetUser) async {
        if (_entry == null || _entryKey == null || targetUser.id == null) return;
        setBusy(true);
        try {
            final existing = await _databaseService.getPermissionByEntryAndUser(_entry!.id!, targetUser.id!);

            if (existing == null) {
                // Neues Zugriffsrecht: Entry-Key mit RSA-PubKey des Empfängers verschlüsseln
                final encryptedEntryKey = await _cryptoService.encryptRsa(_entryKey!, targetUser.publicKey);
                final perm = PermissionEntity(
                    entryId: _entry!.id!,
                    userId: targetUser.id!,
                    encryptedKey: encryptedEntryKey,
                    accessLevel: 1, // Default: Nur Lesen (max 2 beim direkten Teilen)
                );
                await _databaseService.savePermission(perm);
            }
            else {
                // Bestehendes (ggf. entzogenes) Recht reaktivieren
                String encryptedEntryKey = existing.encryptedKey;
                if (encryptedEntryKey.isEmpty) {
                    encryptedEntryKey = await _cryptoService.encryptRsa(_entryKey!, targetUser.publicKey);
                }
                await _databaseService.savePermission(existing.copyWith(accessLevel: 1, encryptedKey: encryptedEntryKey));
            }

            _entry = _entry!.copyWith(updatedAt: DateTime.now().toUtc());
            await _databaseService.saveEntry(_entry!);
            await _loadSharedUsers();
        }
        catch (e, st) {
            logError("Teilen fehlgeschlagen: $e", st);
            notifyUnexpectedError();
        }
        finally {
            setBusy(false);
        }
    }

    /// Aktualisiert die Berechtigungsstufe eines Freundes.
    Future<void> updateAccessLevel(UserEntity user, int newLevel) async {
        if (_entry == null || user.id == null || _entryKey == null) return;
        setBusy(true);
        try {
            final perm = await _databaseService.getPermissionByEntryAndUser(_entry!.id!, user.id!);
            if (perm != null && perm.accessLevel != newLevel) {
                // Limit auf max Level 2 (wie in MAUI)
                final effectiveLevel = newLevel < 3 ? newLevel : 2; // Max Level 2 beim Teilen

                String encKey = perm.encryptedKey;
                if (effectiveLevel == 0) {
                    encKey = ""; // Key löschen bei Rechteentzug
                }
                else if (encKey.isEmpty) {
                    encKey = await _cryptoService.encryptRsa(_entryKey!, user.publicKey);
                }

                await _databaseService.savePermission(perm.copyWith(accessLevel: effectiveLevel, encryptedKey: encKey));

                _entry = _entry!.copyWith(updatedAt: DateTime.now().toUtc());
                await _databaseService.saveEntry(_entry!);
                await _loadSharedUsers();
            }
        }
        catch (e, st) {
            logError("Rechte konnten nicht geändert werden: $e", st);
            notifyUnexpectedError();
        }
        finally {
            setBusy(false);
        }
    }

    /// Entzieht einem Freund den Zugriff auf diesen Eintrag.
    Future<void> revokeAccess(UserEntity user) async {
        await updateAccessLevel(user, 0);
    }

    /// Lädt die Liste der Personen, mit denen dieser Eintrag geteilt wurde.
    Future<void> _loadSharedUsers() async {
        if (_entry == null) return;
        final permissions = await _databaseService.getPermissionsByEntryId(_entry!.id!);
        List<UserEntity> shared = [];
        _userAccessLevels.clear();
        for (var p in permissions) {
            if (p.userId == 1) continue;
            if (p.accessLevel == 0) continue;
            final user = await _databaseService.getUserById(p.userId);
            if (user != null) {
                shared.add(user);
                _userAccessLevels[user.id!] = p.accessLevel;
            }
        }
        _sharedWith = shared;
        notifyListeners();
    }

    /// Lädt die vollständige Liste aller Benutzer aus der lokalen Datenbank
    Future<void> _loadAllUsers() async {
        _allUsers = await _databaseService.getUsers();
        notifyListeners();
    }
}
