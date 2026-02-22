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
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class DetailViewModel extends BaseViewModel {
  final CryptoService _cryptoService;
  final DatabaseService _databaseService;
  final SessionService _sessionService;

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
  bool _isPasswordHidden = true;

  DetailViewModel(this._cryptoService, this._databaseService, this._sessionService);

  // Getters
  String get title => _title;
  String get category => _category;
  String get username => _username;
  String get password => _password;
  String get url => _url;
  String get notes => _notes;
  String get favicon => _favicon;
  bool get isPasswordHidden => _isPasswordHidden;
  List<AttachmentEntity> get attachments => _attachments;

  AttachmentMetaPayload? getAttachmentMeta(String uuid) => _attachmentMetas[uuid];

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

      // Anhänge laden
      _attachments = await _databaseService.getAttachmentsByEntryId(_entry!.id!);
      _attachmentMetas.clear();
      for (var att in _attachments) {
        final decryptedMeta = await _cryptoService.decrypt(att.encryptedMeta, _entryKey!);
        _attachmentMetas[att.uuid] = AttachmentMetaPayload.fromJson(json.decode(utf8.decode(decryptedMeta)));
      }

    } catch (e) {
      setError("Entschlüsselung fehlgeschlagen: $e");
    } finally {
      setBusy(false);
    }
  }

  Future<void> openAttachment(AttachmentEntity attachment) async {
    if (_entryKey == null) return;
    setBusy(true);
    try {
      final meta = _attachmentMetas[attachment.uuid];
      if (meta == null) throw Exception("Metadaten fehlen");

      // 1. Datei im Speicher entschlüsseln
      final decryptedContent = await _cryptoService.decrypt(attachment.encryptedContent, _entryKey!);

      // 2. Temporäre Datei erstellen (Flutter-Standard für Datei-Vorschau)
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('\${tempDir.path}/\${meta.filename}');
      await tempFile.writeAsBytes(decryptedContent);

      // 3. Datei öffnen
      await OpenFilex.open(tempFile.path);

      // Hinweis: Das Löschen der Temp-Datei sollte idealerweise nach dem Schließen
      // der Datei-App passieren (wie in MAUI). In Flutter ist das systembedingt
      // etwas schwieriger zu timen, aber für den 1:1 Port reicht das erst mal so.
    } catch (e) {
      setError("Anhang konnte nicht geöffnet werden: $e");
    } finally {
      setBusy(false);
    }
  }

  Future<void> deleteEntry() async {
    if (_entry == null) return;
    setBusy(true);
    try {
      await _databaseService.deleteEntry(_entry!.id!);
    } catch (e) {
      setError("Löschen fehlgeschlagen: $e");
    } finally {
      setBusy(false);
    }
  }
}
