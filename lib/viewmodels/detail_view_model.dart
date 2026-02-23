import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:privault/core/base_view_model.dart';
import 'package:privault/models/entities/user_entity.dart';
import 'package:privault/models/entities/entry_entity.dart';
import 'package:privault/models/entities/attachment_entity.dart';
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
import 'dart:math' as math;

class DetailViewModel extends BaseViewModel {
  final CryptoService _cryptoService;
  final DatabaseService _databaseService;
  final SessionService _sessionService;
  final PasswordService _passwordService;

  EntryEntity? _entry;
  Uint8List? _entryKey;
  List<AttachmentEntity> _attachments = [];
  Map<String, AttachmentMetaPayload> _attachmentMetas = {};

  String _title = '';
  String _category = '';
  String _username = '';
  String _password = '';
  String _url = '';
  String _notes = '';
  String _favicon = '';
  String _auditHint = '';
  bool _isPasswordHidden = true;

  DetailViewModel(this._cryptoService, this._databaseService, this._sessionService, this._passwordService);

  // Getters
  String get title => _title;
  String get category => _category;
  String get username => _username;
  String get password => _password;
  String get url => _url;
  String get notes => _notes;
  String get favicon => _favicon;
  String get auditHint => _auditHint;
  bool get isPasswordHidden => _isPasswordHidden;
  List<AttachmentEntity> get attachments => _attachments;

  AttachmentMetaPayload? getAttachmentMeta(String uuid) => _attachmentMetas[uuid];
  int get passwordStrength => _passwordService.estimateStrength(_password);

  void togglePasswordVisibility() {
    _isPasswordHidden = !_isPasswordHidden;
    notifyListeners();
  }

  Future<void> initialize(int id) async {
    setBusy(true);
    clearError();
    try {
      _entry = await _databaseService.getEntryById(id);
      if (_entry == null) throw Exception("Eintrag nicht gefunden");

      final perm = await _databaseService.getPermissionByEntryAndUser(_entry!.id!, 1);
      if (perm == null) throw Exception("Keine Berechtigung für diesen Eintrag");

      if (_sessionService.privateKey == null) throw Exception("Sitzungsschlüssel fehlt");
      
      _entryKey = await _cryptoService.decryptRsa(
        perm.encryptedKey, 
        utf8.decode(_sessionService.privateKey!)
      );

      final decryptedData = await _cryptoService.decrypt(_entry!.encryptedData, _entryKey!);
      final payload = EntryPayload.fromJson(json.decode(utf8.decode(decryptedData)));

      _title = payload.title;
      _category = payload.category;
      _username = payload.username;
      _password = payload.password;
      _url = payload.url;
      _notes = payload.notes;
      _favicon = _entry!.favicon;

      await _updateAuditHint();
      await _loadAttachments();

    } catch (e) {
      setError("Entschlüsselung fehlgeschlagen: $e");
    } finally {
      setBusy(false);
    }
  }

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

  Future<void> _loadAttachments() async {
    _attachments = await _databaseService.getAttachmentsByEntryId(_entry!.id!);
    _attachmentMetas.clear();
    for (var att in _attachments) {
      final decryptedMeta = await _cryptoService.decrypt(att.encryptedMeta, _entryKey!);
      _attachmentMetas[att.uuid] = AttachmentMetaPayload.fromJson(json.decode(utf8.decode(decryptedMeta)));
    }
    notifyListeners();
  }

  Future<void> addAttachment() async {
    if (_entry == null || _entryKey == null) return;
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;

      setBusy(true);
      final file = result.files.first;
      final bytes = file.bytes!;

      final metaPayload = AttachmentMetaPayload(
        filename: file.name,
        mime: file.extension ?? 'application/octet-stream',
        size: bytes.length,
        timestamp: DateTime.now().toUtc(),
        thumbnail: '', 
      );

      final encryptedMeta = await _cryptoService.encrypt(
        Uint8List.fromList(utf8.encode(json.encode(metaPayload.toJson()))), 
        _entryKey!
      );
      final encryptedContent = await _cryptoService.encrypt(bytes, _entryKey!);

      final attEntity = AttachmentEntity(
        uuid: const Uuid().v4(),
        entryId: _entry!.id!,
        encryptedMeta: encryptedMeta,
        encryptedContent: encryptedContent,
        isSynced: false,
      );

      await _databaseService.saveAttachment(attEntity);
      _entry = _entry!.copyWith(updatedAt: DateTime.now().toUtc());
      await _databaseService.saveEntry(_entry!);
      await _loadAttachments();
    } catch (e) {
      setError("Fehler beim Hinzufügen: $e");
    } finally {
      setBusy(false);
    }
  }

  Future<void> deleteAttachment(AttachmentEntity attachment) async {
    setBusy(true);
    try {
      await _databaseService.deleteAttachment(attachment.id!);
      await _loadAttachments();
    } catch (e) {
      setError("Fehler beim Löschen: $e");
    } finally {
      setBusy(false);
    }
  }

  /// Ermittelt den Datei-Typ basierend auf Dateiendung oder MIME-Typ (Portiert aus MAUI).
  String getIconType(String filename, String mimeType) {
    final file = filename.toLowerCase();
    if (file.endsWith(".png") || file.endsWith(".jpg") || file.endsWith(".jpeg") || file.endsWith(".gif") || file.endsWith(".bmp") || file.endsWith(".webp")) return "image";
    if (file.endsWith(".pdf")) return "pdf";
    if (file.endsWith(".doc") || file.endsWith(".docx")) return "word";
    if (file.endsWith(".ppt") || file.endsWith(".pptx")) return "slides";
    if (file.endsWith(".xls") || file.endsWith(".xlsx") || file.endsWith(".csv")) return "excel";
    if (file.endsWith(".vcf")) return "vcard";
    if (file.endsWith(".mp3") || file.endsWith(".wav") || file.endsWith(".flac") || file.endsWith(".aac") || file.endsWith(".ogg")) return "audio";
    if (file.endsWith(".mp4") || file.endsWith(".avi") || file.endsWith(".mov") || file.endsWith(".mkv") || file.endsWith(".webm")) return "video";
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

  Future<void> openAttachment(AttachmentEntity attachment) async {
    if (_entryKey == null) return;
    setBusy(true);
    try {
      final meta = _attachmentMetas[attachment.uuid];
      if (meta == null) throw Exception("Metadaten fehlen");
      final decryptedContent = await _cryptoService.decrypt(attachment.encryptedContent, _entryKey!);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${meta.filename}');
      await tempFile.writeAsBytes(decryptedContent);
      
      // Datei öffnen
      await OpenFilex.open(tempFile.path);

      // Best-effort Cleanup mit Retry (wie in MAUI)
      // Wir starten einen Hintergrundprozess, der versucht die Datei zu löschen
      Future.microtask(() async {
        for (var i = 0; i < 10; i++) {
          await Future.delayed(const Duration(seconds: 2));
          try {
            if (await tempFile.exists()) {
              await tempFile.delete();
              debugPrint('🔐 Sicherheits-Cleanup: Temporäre Datei gelöscht (Versuch ${i + 1}).');
              break;
            }
          } catch (e) {
            // Falls gesperrt, nächster Versuch im nächsten Durchlauf
          }
        }
      });

    } catch (e) {
      setError("Anhang konnte nicht geöffnet werden: $e");
    } finally {
      setBusy(false);
    }
  }
}
