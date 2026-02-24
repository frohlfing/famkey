import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:privault/core/base_view_model.dart';
import 'package:privault/models/entities/entry_entity.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:privault/services/password_service.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';

class EditViewModel extends BaseViewModel {
  final CryptoService _cryptoService;
  final DatabaseService _databaseService;
  final SessionService _sessionService;
  final PasswordService _passwordService;
  final Dio _dio = Dio();

  EntryEntity? _entry;
  Uint8List? _entryKey;
  EntryPayload? _originalPayload;
  List<String> _existingCategories = [];

  String _category = '';
  String _title = '';
  String _username = '';
  String _password = '';
  String _url = '';
  String _notes = '';
  bool _isPasswordHidden = true;
  bool _isEditMode = false;

  EditViewModel(this._cryptoService, this._databaseService, this._sessionService, this._passwordService);

  // Getters & Setters
  String get category => _category;

  set category(String value) {
    _category = value;
    notifyListeners();
  }

  String get title => _title;

  set title(String value) {
    _title = value;
    notifyListeners();
  }

  String get username => _username;

  set username(String value) {
    _username = value;
    notifyListeners();
  }

  String get password => _password;

  set password(String value) {
    _password = value;
    notifyListeners();
  }

  String get url => _url;

  set url(String value) {
    _url = value;
    notifyListeners();
  }

  String get notes => _notes;

  set notes(String value) {
    _notes = value;
    notifyListeners();
  }

  bool get isPasswordHidden => _isPasswordHidden;

  bool get isEditMode => _isEditMode;

  List<String> get existingCategories => _existingCategories;

  // Punkt 5: Passwortstärke berechnen
  int get passwordStrength => _passwordService.estimateStrength(_password);

  void togglePasswordVisibility() {
    _isPasswordHidden = !_isPasswordHidden;
    notifyListeners();
  }

  Future<void> initialize(int? id) async {
    setBusy(true);
    clearError();
    try {
      final entries = await _databaseService.getAllEntries();
      _existingCategories = entries.map((e) => e.category).where((c) => c.isNotEmpty).toSet().toList()..sort();

      if (id != null) {
        _isEditMode = true;
        _entry = await _databaseService.getEntryById(id);
        if (_entry != null) {
          final perm = await _databaseService.getPermissionByEntryAndUser(_entry!.id!, 1);
          if (perm != null && _sessionService.privateKey != null) {
            _entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, utf8.decode(_sessionService.privateKey!));
            final decryptedData = await _cryptoService.decrypt(_entry!.encryptedData, _entryKey!);
            final jsonStr = utf8.decode(decryptedData);
            final payload = EntryPayload.fromJson(json.decode(jsonStr));
            _originalPayload = payload;

            _category = payload.category;
            _title = payload.title;
            _username = payload.username;
            _password = payload.password;
            _url = payload.url;
            _notes = payload.notes;
          }
        }
      } else {
        _isEditMode = false;
        _entry = null;
        _entryKey = null;
        _originalPayload = EntryPayload();
        _category = '';
        _title = '';
        _username = '';
        _password = '';
        _url = '';
        _notes = '';
      }
    } catch (e) {
      setError("Fehler beim Laden: $e");
    } finally {
      setBusy(false);
    }
  }

  // Punkt 2: Passwort generieren (Nutzt den Service)
  void generatePassword() {
    final settingsMap = _sessionService.settings;
    if (settingsMap == null) return;

    final int length = settingsMap['pw_length'] ?? 16;
    final bool avoidIlO0 = (settingsMap['pw_avoid_ilo0'] ?? 1) == 1;
    final String specialChars = settingsMap['pw_special_chars'] ?? "!@#\$%^&*()_+-=[]{}|;:,.<>?";

    _password = _passwordService.generatePassword(length, avoidIlO0, specialChars);
    notifyListeners();
  }

  Future<bool> save() async {
    if (_title.isEmpty) {
      setError("Titel darf nicht leer sein");
      return false;
    }

    setBusy(true);
    try {
      if (_entryKey == null) {
        _entryKey = Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)));
      }

      String faviconBase64 = _entry?.favicon ?? '';
      if (_url.isNotEmpty && (_entry == null || _url != _originalPayload?.url)) {
        final icon = await _downloadFavicon(_url);
        if (icon != null) faviconBase64 = icon;
      }

      final payload = EntryPayload(
        category: _category,
        title: _title,
        username: _username,
        password: _password,
        url: _url,
        notes: _notes,
        favicon: faviconBase64,
      );
      final encryptedData = await _cryptoService.encrypt(
        utf8.encode(json.encode(payload.toJson())) as Uint8List,
        _entryKey!,
      );
      final encryptedEntryKey = await _cryptoService.encryptRsa(_entryKey!, _sessionService.user!.publicKey);

      final entity = EntryEntity(
        id: _entry?.id,
        uuid: _entry?.uuid ?? const Uuid().v4(),
        category: _category,
        title: _title,
        url: _url,
        notes: _notes,
        favicon: faviconBase64,
        encryptedData: encryptedData,
        creatorId: _sessionService.user!.id ?? 1,
        updaterId: _sessionService.user!.id ?? 1,
        updatedAt: DateTime.now().toUtc(),
      );

      await _databaseService.saveEntryWithPermissions(entity, 1, encryptedEntryKey);
      return true;
    } catch (e) {
      setError("Fehler beim Speichern: $e");
      return false;
    } finally {
      setBusy(false);
    }
  }

  Future<bool> deleteEntry() async {
    if (_entry == null || _entry!.id == null) return false;
    setBusy(true);
    try {
      await _databaseService.deleteEntry(_entry!.id!);
      return true;
    } catch (e) {
      setError("Fehler beim Löschen: $e");
      return false;
    } finally {
      setBusy(false);
    }
  }

  Future<String?> _downloadFavicon(String url) async {
    try {
      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
      final faviconUrl = 'https://www.google.com/s2/favicons?domain=${uri.host}&sz=64';
      final response = await _dio.get<List<int>>(faviconUrl, options: Options(responseType: ResponseType.bytes));
      if (response.data != null) return base64.encode(response.data!);
    } catch (_) {}
    return null;
  }
}
