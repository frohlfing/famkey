import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/models/payloads/index_payload.dart';
import 'package:privault/services/autofill_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:privault/widgets/snack.dart';

/// Zeigt passende Einträge zur Auswahl beim Auto-Type-Vorgang (unter Windows, Szenario B).
///
/// Wird geöffnet, wenn der globale Hotkey (Strg+Shift+A) gedrückt wurde.
/// `AutofillServiceWindows.init()` navigiert zu `/autotype-picker` und übergibt
/// den Fenstertitel der zuletzt aktiven Anwendung als Routenargument (String).
///
/// # Matching-Logik (`_matches`)
///
/// 1. **Titel-Substring:** Eintrags-Titel ist Teilstring des Fenstertitels (case-insensitive).
/// 2. **URL-Domain:** Host aus der Eintrags-URL kommt im Fenstertitel vor.
///
/// # Anzeigemodus
///
/// - **Genau 1 Treffer:** Bestätigungsdialog direkt öffnen (kein Listenumweg).
/// - **Mehrere Treffer:** Trefferliste anzeigen.
/// - **Kein Treffer:** Alle Einträge mit Hinweistext.
///
/// # Ablauf nach Auswahl (`_selectEntry`)
///
/// Permission laden → RSA-Decrypt Entry-Key → AES-Decrypt Daten →
/// Bestätigungsdialog → `typeCredentials()` → `Navigator.pop()`.
class AutoTypePickerPage extends StatefulWidget {
  const AutoTypePickerPage({super.key});

  @override
  State<AutoTypePickerPage> createState() => _AutoTypePickerPageState();
}

class _AutoTypePickerPageState extends State<AutoTypePickerPage> {
  late final AutofillService _autofillService;
  late final CryptoService _cryptoService;
  late final DatabaseService _databaseService;
  late final SessionService _sessionService;

  /// Fenstertitel der Anwendung, die vor PriVault aktiv war.
  String _windowTitle = '';

  /// Future mit dem Ergebnis der Eintragsladung und Filterung.
  /// Wird einmalig in `didChangeDependencies` gestartet.
  late final Future<_PickerResult> _entriesFuture;

  /// Guard: stellt sicher, dass `didChangeDependencies` die Initialisierung nur einmal ausführt.
  bool _initialized = false;

  /// Guard: verhindert, dass Auto-Select bei jedem `build()`-Aufruf erneut getriggert wird.
  ///
  /// `build()` wird während der Pop-Animation und bei App-Fokus-Wechseln mehrfach aufgerufen.
  /// Ohne diesen Guard würde jeder Aufruf via `addPostFrameCallback` eine weitere
  /// `_selectEntry`-Instanz in die Queue stellen, die dann beim nächsten Frame feuert.
  bool _autoSelectDone = false;

  @override
  void initState() {
    super.initState();
    _autofillService = getIt();
    _cryptoService = getIt();
    _databaseService = getIt();
    _sessionService = getIt();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _windowTitle = ModalRoute.of(context)?.settings.arguments as String? ?? '';
      log.debug('AutoTypePicker geöffnet', context: {'windowTitle': _windowTitle});
      _entriesFuture = _loadEntries();
    }
  }

  /// Lädt alle Einträge, entschlüsselt deren Index und filtert nach [_windowTitle].
  Future<_PickerResult> _loadEntries() async {
    final indexKey = _sessionService.indexKey;
    if (indexKey == null) return const _PickerResult(entries: [], hasMatches: false);

    final entries = await _databaseService.getEntries();
    final all = <({EntryEntity entry, IndexPayload index})>[];

    for (final entry in entries) {
      if (entry.encryptedIndex.isEmpty) continue;
      try {
        final decrypted = await _cryptoService.decrypt(entry.encryptedIndex, indexKey);
        final payload = IndexPayload.fromJson(json.decode(utf8.decode(decrypted)));
        all.add((entry: entry, index: payload));
      } catch (_) {}
    }

    all.sort((a, b) => a.index.title.toLowerCase().compareTo(b.index.title.toLowerCase()));

    if (_windowTitle.isNotEmpty) {
      final matched = all.where((item) => _matches(item.index, _windowTitle)).toList();
      log.debug('Einträge geladen', context: {'total': all.length, 'matched': matched.length});
      if (matched.isNotEmpty) return _PickerResult(entries: matched, hasMatches: true);
    }

    log.debug('Kein Treffer, zeige alle', context: {'total': all.length});
    return _PickerResult(entries: all, hasMatches: false);
  }

  /// Prüft, ob ein Eintrag zum [windowTitle] passt (Titel-Substring oder URL-Domain).
  bool _matches(IndexPayload index, String windowTitle) {
    final wt = windowTitle.toLowerCase();
    if (index.title.isNotEmpty && wt.contains(index.title.toLowerCase())) return true;
    if (index.url.isNotEmpty) {
      try {
        final fullUrl = index.url.startsWith('http') ? index.url : 'https://${index.url}';
        final host = Uri.parse(fullUrl).host.toLowerCase();
        if (host.isNotEmpty && wt.contains(host)) return true;
      } catch (_) {}
    }
    return false;
  }

  /// Entschlüsselt den gewählten Eintrag vollständig und startet den Auto-Type-Vorgang.
  ///
  /// [popOnCancel]: wenn true, wird die Seite beim Abbrechen des Dialogs geschlossen
  /// (sinnvoll beim Auto-Select mit genau einem Treffer).
  Future<void> _selectEntry(EntryEntity entry, IndexPayload index, {bool popOnCancel = false}) async {
    final userId = _sessionService.user?.id;
    final privateKey = _sessionService.privateKey;
    if (userId == null || privateKey == null) return;

    try {
      final perm = await _databaseService.getPermissionByEntryIdAndUserId(entry.id, userId);
      if (perm == null || perm.encryptedKey.isEmpty) return;

      final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, privateKey);
      final decryptedData = await _cryptoService.decrypt(entry.encryptedData, entryKey);
      final payload = EntryPayload.fromJson(json.decode(utf8.decode(decryptedData)));

      if (!mounted) return;

      final hasUsername = payload.username.isNotEmpty;
      final hasPassword = payload.password.isNotEmpty;

      final credText = hasUsername && hasPassword
          ? 'Benutzername und Passwort'
          : hasUsername
              ? 'Benutzername'
              : 'Passwort';

      final seqText = hasUsername && hasPassword
          ? 'Benutzername → Tab → Passwort → Enter'
          : hasUsername
              ? 'Benutzername → Enter'
              : 'Passwort → Enter';

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Auto-Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index.title.isNotEmpty) ...[
                Text(index.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
              ],
              Text('$credText wird eingetippt in:'),
              const SizedBox(height: 4),
              Text('"$_windowTitle"', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                'Sequenz: $seqText',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              autofocus: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Einfügen'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (confirmed != true) {
        if (popOnCancel) Navigator.pop(context);
        return;
      }

      log.debug('Auto-Type bestätigt', context: {'windowTitle': _windowTitle});
      final ok = await _autofillService.typeCredentials(payload.username, payload.password);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        Snack.show(context, 'Auto-Type fehlgeschlagen: Zielfenster nicht mehr verfügbar.');
      }
    } catch (_) {
      if (mounted) Snack.show(context, 'Fehler beim Entschlüsseln des Eintrags.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_windowTitle.isNotEmpty ? 'Auto-Type: $_windowTitle' : 'Auto-Type'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<_PickerResult>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final result = snapshot.data ?? const _PickerResult(entries: [], hasMatches: false);

          if (result.entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Keine Einträge vorhanden.', textAlign: TextAlign.center),
              ),
            );
          }

          // Genau ein Treffer: Bestätigungsdialog direkt öffnen, kein Listenumweg.
          // _autoSelectDone verhindert, dass jeder build()-Aufruf (Pop-Animation,
          // App-Fokus-Wechsel etc.) einen weiteren _selectEntry-Call in die Queue stellt.
          if (result.hasMatches && result.entries.length == 1) {
            if (!_autoSelectDone) {
              _autoSelectDone = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _selectEntry(result.entries[0].entry, result.entries[0].index, popOnCancel: true);
              });
            }
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!result.hasMatches && _windowTitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Keine passenden Einträge für "$_windowTitle" – alle Einträge:',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: result.entries.length,
                  itemBuilder: (context, i) {
                    final item = result.entries[i];
                    return ListTile(
                      leading: item.index.favicon.isNotEmpty
                          ? CircleAvatar(
                              backgroundImage: MemoryImage(base64Decode(item.index.favicon)),
                              backgroundColor: Colors.transparent,
                            )
                          : CircleAvatar(
                              child: Text(item.index.title.isNotEmpty ? item.index.title[0].toUpperCase() : '?'),
                            ),
                      title: Text(item.index.title),
                      subtitle: item.index.url.isNotEmpty ? Text(item.index.url, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                      onTap: () => _selectEntry(item.entry, item.index),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Ergebnis der Eintragsladung und -filterung.
///
/// [entries] — die anzuzeigenden Einträge (gefiltert oder alle).
/// [hasMatches] — true wenn [entries] ein gefiltertes Subset ist.
class _PickerResult {
  final List<({EntryEntity entry, IndexPayload index})> entries;
  final bool hasMatches;
  const _PickerResult({required this.entries, required this.hasMatches});
}
