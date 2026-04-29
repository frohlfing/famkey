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

/// Die Flutter-Seite zur Eintrags-Auswahl beim Auto-Type-Vorgang (nur Windows, Szenario B).
///
/// # Wann erscheint diese Seite?
///
/// Der Nutzer hat den konfigurierten Hotkey (z.B. Strg+Shift+A) gedrückt, während
/// er sich in einer anderen App (z.B. Chrome, Firefox, Notepad) befand.
/// C++ hat PriVault in den Vordergrund gebracht und den Fenstertitel der zuvor
/// aktiven App via MethodChannel `onHotkey` an Flutter geschickt.
/// `AutofillServiceWindows.init()` hat dann zu dieser Seite navigiert und den
/// Fenstertitel als Argument mitgegeben.
///
/// # Was diese Seite macht
///
/// 1. Den Fenstertitel aus dem Navigations-Argument lesen.
/// 2. Alle Einträge laden und deren verschlüsselten Index (Metadaten) entschlüsseln.
/// 3. Einträge nach dem Fenstertitel filtern (Matching-Logik, siehe [_matches]).
/// 4. Den passenden Eintrag anzeigen – oder alle, wenn kein Match gefunden wurde.
/// 5. Wenn der Nutzer einen Eintrag wählt: vollständige Daten entschlüsseln,
///    Bestätigungsdialog zeigen, dann [AutofillService.typeCredentials] aufrufen.
///
/// # Unterschied zur [AutofillPickerPage] (Android)
///
/// - Auf Android wählt der Nutzer einen Eintrag, und PriVault gibt das Ergebnis
///   direkt an das Formular zurück (Betriebssystem übernimmt das Eintragen).
/// - Auf Windows muss PriVault die Zugangsdaten selbst tippen (SendInput via C++).
///   Daher gibt es hier immer einen Bestätigungsdialog mit Zielfenster-Angabe –
///   der Nutzer sieht, wohin getippt wird, bevor er bestätigt.
///
/// # Matching-Logik (`_matches`)
///
/// PriVault vergleicht den Fenstertitel mit den gespeicherten Eintragsdaten:
/// 1. **Titel-Substring:** "PayPal" (Eintrags-Titel) im Fenstertitel "PayPal — Mozilla Firefox" → Treffer
/// 2. **URL-Domain:** "paypal.com" (aus Eintrags-URL) im Fenstertitel → Treffer
///
/// Kein Treffer → alle Einträge werden angezeigt (mit Hinweistext).
///
/// # Anzeigemodus
///
/// - **Genau 1 Treffer:** Bestätigungsdialog direkt öffnen, kein Listenumweg.
/// - **Mehrere Treffer:** Liste zeigen, Nutzer wählt manuell.
/// - **Kein Treffer:** Alle Einträge + Hinweis, dass nichts passte.
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

  /// Fenstertitel der App, die vor PriVault aktiv war (z.B. "PayPal – Mozilla Firefox").
  /// Wird als Suchbegriff für das Matching verwendet und im AppBar-Titel angezeigt.
  String _windowTitle = '';

  /// Future mit dem geladenen und gefilterten Eintrags-Ergebnis.
  /// `late final` → wird genau einmal gesetzt (in didChangeDependencies) und nie geändert,
  /// damit der FutureBuilder die Daten nicht bei jedem Widget-Rebuild neu lädt.
  late final Future<_PickerResult> _entriesFuture;

  /// Guard: stellt sicher, dass `didChangeDependencies` die Initialisierung nur einmal ausführt.
  ///
  /// `didChangeDependencies` wird öfter aufgerufen als `initState` – z.B. wenn sich
  /// ein InheritedWidget (wie Theme oder MediaQuery) ändert. Das Navigations-Argument
  /// (`ModalRoute.of(context).settings.arguments`) kann erst in `didChangeDependencies`
  /// gelesen werden, nicht in `initState`, weil `context` dort noch nicht vollständig ist.
  bool _initialized = false;

  /// Guard: verhindert, dass beim Auto-Select (genau 1 Treffer) `_selectEntry` mehrfach
  /// aufgerufen wird.
  ///
  /// `build()` wird während der Pop-Animation und bei App-Fokus-Wechseln mehrfach
  /// aufgerufen. Ohne diesen Guard würde jedes `build()` via `addPostFrameCallback`
  /// eine weitere `_selectEntry`-Instanz in die Callback-Queue stellen.
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
      // Navigations-Argument: AutofillServiceWindows hat beim pushNamed('/autotype-picker')
      // den Fenstertitel als argument übergeben. ModalRoute.of(context) liefert die aktuelle
      // Route; settings.arguments ist das mitgegebene Objekt.
      _windowTitle = ModalRoute.of(context)?.settings.arguments as String? ?? '';
      log.debug('AutoTypePicker geöffnet', context: {'windowTitle': _windowTitle});
      _entriesFuture = _loadEntries();
    }
  }

  /// Lädt alle Einträge, entschlüsselt deren Index (Metadaten) und filtert nach [_windowTitle].
  ///
  /// Gibt ein [_PickerResult] zurück, das sowohl die anzuzeigenden Einträge als auch
  /// die Information enthält, ob Treffer gefunden wurden (für den Hinweistext).
  ///
  /// Die Entschlüsselung des Index (encryptedIndex) ist günstig, weil der Index
  /// nur Metadaten (Titel, URL, Favicon) enthält – das eigentliche Passwort bleibt
  /// verschlüsselt und wird erst in [_selectEntry] entschlüsselt.
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

    // Alphabetisch sortieren für eine konsistente Reihenfolge.
    all.sort((a, b) => a.index.title.toLowerCase().compareTo(b.index.title.toLowerCase()));

    if (_windowTitle.isNotEmpty) {
      final matched = all.where((item) => _matches(item.index, _windowTitle)).toList();
      log.debug('Einträge geladen', context: {'total': all.length, 'matched': matched.length});
      // Wenn Treffer gefunden: nur Treffer zurückgeben (hasMatches = true).
      if (matched.isNotEmpty) return _PickerResult(entries: matched, hasMatches: true);
    }

    // Kein Treffer oder leerer Fenstertitel: alle Einträge zurückgeben (hasMatches = false).
    log.debug('Kein Treffer, zeige alle', context: {'total': all.length});
    return _PickerResult(entries: all, hasMatches: false);
  }

  /// Prüft, ob ein Eintrag zum [windowTitle] passt.
  ///
  /// Zwei Erkennungswege:
  /// 1. **Titel-Substring:** Eintrags-Titel kommt (case-insensitiv) im Fenstertitel vor.
  ///    Beispiel: Eintrag "PayPal", Fenstertitel "PayPal – Anmelden – Mozilla Firefox" → true
  /// 2. **URL-Domain:** Host aus der Eintrags-URL kommt im Fenstertitel vor.
  ///    Beispiel: Eintrag-URL "https://www.paypal.com", Fenstertitel "...paypal..." → true
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

  /// Entschlüsselt den gewählten Eintrag vollständig, zeigt den Bestätigungsdialog
  /// und startet anschließend den Auto-Type-Vorgang.
  ///
  /// # Entschlüsselungs-Ablauf (RSA + AES – identisch zum Android-Picker)
  ///
  /// 1. **Permission laden:** enthält den Eintragschlüssel (AES), verschlüsselt mit
  ///    dem RSA-Public-Key des Nutzers.
  /// 2. **RSA-Decrypt:** Eintragschlüssel mit dem RSA-Private-Key entschlüsseln.
  /// 3. **AES-Decrypt:** Eintragsdaten (Benutzername, Passwort, ...) mit dem AES-Schlüssel
  ///    entschlüsseln → JSON.
  /// 4. **JSON parsen** → [EntryPayload] mit allen Feldern.
  ///
  /// # Bestätigungsdialog
  ///
  /// Vor dem Tippen wird dem Nutzer gezeigt:
  /// - Welcher Eintrag ausgewählt wurde
  /// - Welche Felder getippt werden (Benutzername / Passwort / beides)
  /// - In welches Fenster getippt wird
  /// - Die genaue Sequenz (z.B. "Benutzername → Tab → Passwort → Enter")
  ///
  /// # [popOnCancel]
  ///
  /// Bei Auto-Select (genau 1 Treffer) öffnet sich der Dialog direkt, ohne
  /// dass der Nutzer einen Eintrag in der Liste antippt. Wenn er dann im Dialog
  /// "Abbrechen" drückt, soll der Picker geschlossen werden (zurück zur App).
  /// Mit `popOnCancel = false` (Standard, bei Liste) bleibt der Picker nach
  /// Abbrechen offen, damit der Nutzer einen anderen Eintrag wählen kann.
  Future<void> _selectEntry(EntryEntity entry, IndexPayload index, {bool popOnCancel = false}) async {
    final userId = _sessionService.user?.id;
    final privateKey = _sessionService.privateKey;
    if (userId == null || privateKey == null) return;

    try {
      // ─────────────────────────────────────────────────────────────────────
      // Schritt 1–3: Zweistufige Entschlüsselung (RSA → AES).
      // ─────────────────────────────────────────────────────────────────────
      final perm = await _databaseService.getPermissionByEntryIdAndUserId(entry.id, userId);
      if (perm == null || perm.encryptedKey.isEmpty) return;

      final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, privateKey);
      final decryptedData = await _cryptoService.decrypt(entry.encryptedData, entryKey);
      final payload = EntryPayload.fromJson(json.decode(utf8.decode(decryptedData)));

      if (!mounted) return;

      // ─────────────────────────────────────────────────────────────────────
      // Dialog-Texte dynamisch aufbauen, je nachdem welche Felder vorhanden sind.
      // ─────────────────────────────────────────────────────────────────────
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

      // ─────────────────────────────────────────────────────────────────────
      // Bestätigungsdialog anzeigen.
      // showDialog gibt den Wert zurück, den Navigator.pop(ctx, wert) erhält
      // (true = "Einfügen", false/null = "Abbrechen").
      // ─────────────────────────────────────────────────────────────────────
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
              autofocus: true,  // Enter-Taste schließt den Dialog mit "Einfügen"
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Einfügen'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (confirmed != true) {
        // Dialog wurde abgebrochen. Bei Auto-Select (popOnCancel = true)
        // den Picker schließen; bei manueller Liste offen lassen.
        if (popOnCancel) Navigator.pop(context);
        return;
      }

      log.debug('Auto-Type bestätigt', context: {'windowTitle': _windowTitle});

      // typeCredentials() schickt via MethodChannel die Zugangsdaten an C++.
      // C++ bringt das Zielfenster in den Vordergrund und tippt die Sequenz.
      final ok = await _autofillService.typeCredentials(payload.username, payload.password);
      if (!mounted) return;

      if (ok) {
        // Erfolg: Picker schließen und zurück zur vorherigen Seite.
        Navigator.pop(context);
      } else {
        // Fehlschlag: Zielfenster existiert nicht mehr → Fehlermeldung anzeigen.
        // Picker bleibt offen, damit der Nutzer es manuell schließen kann.
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
        // Fenstertitel im AppBar, damit der Nutzer sieht, für welches Fenster er tippt.
        title: Text(_windowTitle.isNotEmpty ? 'Auto-Type: $_windowTitle' : 'Auto-Type'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<_PickerResult>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          // Lade-Indikator, solange die Einträge noch geladen/entschlüsselt werden.
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

          // ─────────────────────────────────────────────────────────────────
          // Auto-Select: Genau 1 Treffer → Dialog direkt öffnen.
          //
          // addPostFrameCallback stellt sicher, dass _selectEntry erst nach dem
          // vollständigen Rendern dieses Frames aufgerufen wird, nicht während
          // des build()-Durchlaufs. Navigation/Dialoge während build() sind verboten.
          //
          // _autoSelectDone verhindert, dass bei jedem weiteren build()-Aufruf
          // (Pop-Animation, Fokus-Wechsel) ein weiterer Callback eingereiht wird.
          // ─────────────────────────────────────────────────────────────────
          if (result.hasMatches && result.entries.length == 1) {
            if (!_autoSelectDone) {
              _autoSelectDone = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _selectEntry(result.entries[0].entry, result.entries[0].index, popOnCancel: true);
              });
            }
            return const Center(child: CircularProgressIndicator());
          }

          // Trefferliste oder alle Einträge (mit optionalem Hinweistext).
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hinweis, wenn kein Treffer gefunden und stattdessen alle angezeigt werden.
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
/// Kapselt zwei Informationen, die der Builder benötigt:
/// - [entries]: die anzuzeigenden Einträge (entweder gefilterte Treffer oder alle)
/// - [hasMatches]: ob [entries] ein gefiltertes Subset ist (true) oder alle Einträge
///   enthält weil kein Treffer gefunden wurde (false)
///
/// [hasMatches] steuert den Hinweistext: Bei false + nicht-leerem Fenstertitel
/// wird dem Nutzer erklärt, warum alle Einträge statt nur passender angezeigt werden.
class _PickerResult {
  final List<({EntryEntity entry, IndexPayload index})> entries;
  final bool hasMatches;
  const _PickerResult({required this.entries, required this.hasMatches});
}
