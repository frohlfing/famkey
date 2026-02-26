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

/// Das [EditViewModel] ist für das Hinzufügen oder Bearbeiten eines Tresoreintrags verantwortlich.
/// Es steuert den gesamten Lebenszyklus eines Eintrags: Erstellung, Entschlüsselung und Bearbeitung.
///
/// **Kernfunktionalitäten:**
/// * Envelope Encryption: Entschlüsselung des AES-Eintragschlüssels via RSA-Privatschlüssel des Nutzers.
/// * Zustandsverwaltung: Unterscheidung zwischen Schreib- und Vollzugriff (Besitzer).
///
/// **Sicherheitskonzept:**
/// Der symmetrische Schlüssel (_entryKey) wird nur im Arbeitsspeicher gehalten und beim Verlassen der Seite
/// sicher gelöscht. Anhänge werden erst bei Bedarf (Lazy Loading) entschlüsselt.
class EditViewModel extends BaseViewModel {
  // ------------------------------------------------------------------------
  // --- Felder ---
  // ------------------------------------------------------------------------

  final CryptoService _cryptoService;
  final DatabaseService _databaseService;
  final SessionService _sessionService;
  final PasswordService _passwordService;
  final Dio _dio = Dio();

  /// Die aktuell geladene Datenbank-Entität. Ist null bei einem neuen Eintrag.
  EntryEntity? _entry;

  /// Der entschlüsselte 32-Byte AES-Schlüssel für diesen spezifischen Eintrag.
  /// Wird benötigt, um Daten und Anhänge zu ver- und zu entschlüsseln.
  Uint8List? _entryKey;

  /// Speichert den ursprünglichen Zustand des Eintrags, um beim Abbrechen Änderungen zu erkennen (Dirty-Check).
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

  // ------------------------------------------------------------------------
  // --- Konstruktor ---
  // ------------------------------------------------------------------------

  EditViewModel(this._cryptoService, this._databaseService, this._sessionService, this._passwordService);

  // ------------------------------------------------------------------------
  // --- Eigenschaften (Getters & Setters) ---
  // ------------------------------------------------------------------------

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

  /// Berechnete Stärke des aktuell eingegebenen Passworts (0-4).
  int get passwordStrength => _passwordService.estimateStrength(_password);

  // ------------------------------------------------------------------------
  // --- Befehle ---
  // ------------------------------------------------------------------------

  /// Schaltet die Sichtbarkeit des Passwortfelds um.
  void togglePasswordVisibility() {
    _isPasswordHidden = !_isPasswordHidden;
    notifyListeners();
  }

  /// Initialisiert das ViewModel. Lädt entweder einen bestehenden Eintrag oder
  /// bereitet die Maske für eine Neuanlage vor.
  Future<void> initialize(int? id) async {
    setBusy(true);
    clearError();
    try {
      // Vorhandene Kategorien für Vorschlagsliste laden
      final entries = await _databaseService.getAllEntries();
      _existingCategories = entries.map((e) => e.category).where((c) => c.isNotEmpty).toSet().toList()..sort();

      if (id != null) {
        _isEditMode = true;
        _entry = await _databaseService.getEntryById(id);
        if (_entry != null) {
          // Berechtigung prüfen und Entry-Key mittels RSA entschlüsseln
          final perm = await _databaseService.getPermissionByEntryAndUser(_entry!.id!, 1);
          if (perm != null && _sessionService.privateKey != null) {
            _entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, utf8.decode(_sessionService.privateKey!));

            // Payload mittels AES entschlüsseln
            final decryptedData = await _cryptoService.decrypt(_entry!.encryptedData, _entryKey!);
            final jsonStr = utf8.decode(decryptedData);
            final payload = EntryPayload.fromJson(json.decode(jsonStr));
            _originalPayload = payload;

            // Daten in UI-Felder übernehmen
            _category = payload.category;
            _title = payload.title;
            _username = payload.username;
            _password = payload.password;
            _url = payload.url;
            _notes = payload.notes;
          }
        }
      } else {
        // Neuer Eintrag: Alles leeren
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

  /// Generiert ein neues Zufallspasswort basierend auf den Benutzereinstellungen.
  void generatePassword() {
    final settingsMap = _sessionService.settings;
    if (settingsMap == null) return;

    final int length = settingsMap['pw_length'] ?? 16;
    final bool avoidIlO0 = (settingsMap['pw_avoid_ilo0'] ?? 1) == 1;
    final String specialChars = settingsMap['pw_special_chars'] ?? "!@#\$%^&*()_+-=[]{}|;:,.<>?";

    _password = _passwordService.generatePassword(length, avoidIlO0, specialChars);
    notifyListeners();
  }

  /// Speichert den aktuellen Eintrag in der Datenbank. Verschlüsselt dabei alle sensiblen Felder.
  /// Gibt die ID des gespeicherten Eintrags zurück.
  Future<int?> save() async {
    if (_title.isEmpty) {
      setError("Titel darf nicht leer sein");
      return null;
    }

    setBusy(true);
    try {
      // 1. Key-Management: Neuen AES-Key generieren, falls nicht vorhanden
      _entryKey ??= Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)));

      // 2. Favicon laden, falls URL sich geändert hat
      String faviconBase64 = _entry?.favicon ?? '';
      if (_url.isNotEmpty && (_entry == null || _url != _originalPayload?.url)) {
        final icon = await _downloadFavicon(_url);
        if (icon != null) faviconBase64 = icon;
      }

      // 3. Payload bauen und verschlüsseln (AES)
      final payload = EntryPayload(
        category: _category,
        title: _title,
        username: _username,
        password: _password,
        url: _url,
        notes: _notes,
        favicon: faviconBase64,
      );

      final payloadBytes = Uint8List.fromList(utf8.encode(json.encode(payload.toJson())));
      final encryptedData = await _cryptoService.encrypt(payloadBytes, _entryKey!);

      // 4. Entry-Key für den Eigenbedarf verschlüsseln (RSA)
      final encryptedEntryKey = await _cryptoService.encryptRsa(_entryKey!, _sessionService.user!.publicKey);

      // 5. Entity erstellen und speichern
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

      final savedId = await _databaseService.saveEntryWithPermissions(entity, 1, encryptedEntryKey);
      return savedId;
    } catch (e) {
      setError("Fehler beim Speichern: $e");
      return null;
    } finally {
      setBusy(false);
    }
  }

  /// Löscht den aktuellen Eintrag.
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

  // ------------------------------------------------------------------------
  // --- Private Methoden ---
  // ------------------------------------------------------------------------

  /// Lädt das Favicon einer Website über den Google-Dienst.
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
