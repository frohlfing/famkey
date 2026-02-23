import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:privault/core/base_view_model.dart';
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

  /// Fügt einen neuen Anhang hinzu (Verschlüsselung + DB-Speicherung)
  Future<void> addAttachment() async {
    if (_entry == null || _entryKey == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;

      setBusy(true);
      final file = result.files.first;
      final bytes = file.bytes!;

      // 1. Metadaten vorbereiten
      final metaPayload = AttachmentMetaPayload(
        filename: file.name,
        mime: _getMimeType(file.name),
        size: bytes.length,
        timestamp: DateTime.now().toUtc(),
        thumbnail: '', 
      );

      // 2. Verschlüsseln
      final encryptedMeta = await _cryptoService.encrypt(
        Uint8List.fromList(utf8.encode(json.encode(metaPayload.toJson()))), 
        _entryKey!
      );
      final encryptedContent = await _cryptoService.encrypt(bytes, _entryKey!);

      // 3. Entity speichern
      final attEntity = AttachmentEntity(
        uuid: const Uuid().v4(),
        entryId: _entry!.id!,
        encryptedMeta: encryptedMeta,
        encryptedContent: encryptedContent,
        isSynced: false,
      );

      await _databaseService.saveAttachment(attEntity);
      
      // Haupteintrag aktualisieren für Sync-Trigger
      _entry = _entry!.copyWith(updatedAt: DateTime.now().toUtc());
      await _databaseService.saveEntry(_entry!);

      await _loadAttachments();
    } catch (e) {
      setError("Anhang konnte nicht hinzugefügt werden: $e");
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
      setError("Fehler beim Löschen des Anhangs: $e");
    } finally {
      setBusy(false);
    }
  }

  String _getMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'pdf': return 'application/pdf';
      default: return 'application/octet-stream';
    }
  }

  /// Ermittelt den Datei-Typ für Icons (MAUI Portierung)
  String getIconType(String filename) {
    final file = filename.toLowerCase();
    if (file.endsWith(".png") || file.endsWith(".jpg") || file.endsWith(".jpeg") || file.endsWith(".gif") || file.endsWith(".bmp") || file.endsWith(".webp")) return "image";
    if (file.endsWith(".pdf")) return "pdf";
    if (file.endsWith(".doc") || file.endsWith(".docx")) return "word";
    if (file.endsWith(".ppt") || file.endsWith(".pptx")) return "slides";
    if (file.endsWith(".xls") || file.endsWith(".xlsx") || file.endsWith(".csv")) return "excel";
    if (file.endsWith(".zip") || file.endsWith(".rar") || file.endsWith(".tar") || file.endsWith(".7z")) return "archive";
    return "generic";
  }

  /// Formatiert Byte-Anzahl (MAUI Portierung)
  String formatSize(int bytes) {
    const scale = 1024;
    const orders = ["B", "KB", "MB", "GB"];
    double max = bytes.toDouble();
    int order = 0;
    while (max >= scale && order < orders.length - 1) {
      order++;
      max = max / scale;
    }
    return "${max.toStringAsFixed(2)} ${orders[order]}";
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
      await OpenFilex.open(tempFile.path);
    } catch (e) {
      setError("Anhang konnte nicht geöffnet werden: $e");
    } finally {
      setBusy(false);
    }
  }
}
