import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:famkey/core/logger.dart';
import 'package:famkey/core/service_locator.dart';
import 'package:famkey/database/database.dart';
import 'package:famkey/models/payloads/entry_payload.dart';
import 'package:famkey/models/payloads/index_payload.dart';
import 'package:famkey/services/autofill_service.dart';
import 'package:famkey/services/crypto_service.dart';
import 'package:famkey/services/database_service.dart';
import 'package:famkey/services/session_service.dart';

/// Die Flutter-Seite zur Eintrags-Auswahl beim Autofill-Vorgang (nur Android).
///
/// # Wann erscheint diese Seite?
///
/// Diese Seite wird geöffnet, sobald der Nutzer in einer anderen App (z.B. Chrome)
/// auf die "FamKey"-Autofill-Bubble getippt hat und FamKey geöffnet wurde.
/// Der native [FamKeyAutofillService] hat die Domain der Ziel-Website bereits
/// ermittelt (z.B. "paypal.com") und in [AutofillService.pendingDomain] abgelegt.
///
/// # Was diese Seite macht
///
/// 1. Alle Einträge aus der verschlüsselten Datenbank laden.
/// 2. Für jeden Eintrag den verschlüsselten Index (Metadaten: Titel, URL, Favicon)
///    entschlüsseln und prüfen, ob die URL zur Ziel-Domain passt.
/// 3. Passende Einträge als Liste anzeigen.
/// 4. Wenn der Nutzer einen Eintrag antippt: vollständige Daten entschlüsseln,
///    [AutofillService.complete] aufrufen → Kotlin befüllt das Formular.
///
/// # Warum ist die Entschlüsselung zweistufig?
///
/// FamKey verschlüsselt Einträge in zwei Schichten:
/// - **encryptedIndex**: Nur Metadaten (Titel, URL, Favicon) – schnell zu laden,
///   damit die Liste ohne das gesamte Passwort entschlüsselt werden kann.
/// - **encryptedData**: Alle Felder inkl. Benutzername und Passwort – wird erst
///   entschlüsselt, wenn der Nutzer einen Eintrag auswählt.
///
/// # Navigations-Stack-Besonderheit
///
/// Diese Seite kann auf zwei Arten auf den Navigator-Stack gelangt sein:
///
/// **Warm-Start (bereits eingeloggt):**
///   Stack: [`/main`, `/autofill-picker`]
///   Nach Abschluss → `Navigator.pop()` → zurück zu `/main` ✓
///
/// **Cold-Start (gerade eingeloggt):**
///   Die Login-Seite hat `pushReplacementNamed('/autofill-picker')` verwendet,
///   d.h. die Login-Seite wurde durch diese ersetzt. Stack: [`/autofill-picker`]
///   Nach Abschluss → `Navigator.pop()` würde den Stack leeren → schwarzer Bildschirm!
///   Stattdessen: `Navigator.canPop()` prüfen → wenn false → `pushReplacementNamed('/main')` ✓
class AutofillPickerPage extends StatefulWidget {
  const AutofillPickerPage({super.key});

  @override
  State<AutofillPickerPage> createState() => _AutofillPickerPageState();
}

class _AutofillPickerPageState extends State<AutofillPickerPage> {
  late final AutofillService _autofillService;
  late final CryptoService _cryptoService;
  late final DatabaseService _databaseService;
  late final SessionService _sessionService;

  /// Das Future, das beim Initialisieren gestartet wird und die passenden Einträge lädt.
  /// `late final` bedeutet: wird genau einmal gesetzt (in initState) und danach nie
  /// mehr geändert. Das verhindert, dass bei einem Widget-Rebuild die Einträge
  /// erneut geladen werden.
  late final Future<List<({EntryEntity entry, IndexPayload index})>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    // Services über GetIt (Dependency Injection) holen.
    // GetIt ist ein Service-Locator: man registriert Services einmalig beim Start
    // und holt sie überall in der App mit getIt<ServiceName>() ab.
    _autofillService = getIt();
    _cryptoService = getIt();
    _databaseService = getIt();
    _sessionService = getIt();
    // Einträge sofort laden – das Ergebnis wird im FutureBuilder (in build) angezeigt.
    _entriesFuture = _loadMatchingEntries();
  }

  /// Lädt alle Einträge und filtert sie nach der Ziel-Domain.
  ///
  /// Gibt eine Liste von Records zurück – jeder Record enthält sowohl das
  /// Datenbankentity (`entry`) als auch die entschlüsselten Metadaten (`index`).
  /// Records sind anonyme Datenstrukturen: `({EntryEntity entry, IndexPayload index})`.
  Future<List<({EntryEntity entry, IndexPayload index})>> _loadMatchingEntries() async {
    final domain = _autofillService.pendingDomain ?? '';
    log.debug('AutofillPicker: Lade Einträge');

    // indexKey ist ein von SessionService verwalteter AES-Schlüssel, der speziell
    // für die Entschlüsselung des encryptedIndex (Metadaten) der Einträge abgeleitet wurde.
    // Ist null, wenn kein Nutzer eingeloggt ist → leere Liste zurückgeben.
    final indexKey = _sessionService.indexKey;
    if (indexKey == null) {
      log.debug('AutofillPicker: kein indexKey – Abbruch');
      return [];
    }

    // Alle Einträge aus der Datenbank laden (noch verschlüsselt).
    final entries = await _databaseService.getEntries();
    final result = <({EntryEntity entry, IndexPayload index})>[];

    for (final entry in entries) {
      if (entry.encryptedIndex.isEmpty) continue;
      try {
        // encryptedIndex mit dem indexKey entschlüsseln.
        // Das Ergebnis ist ein JSON-String (als UTF-8-Bytes) mit Titel, URL und Favicon.
        final decrypted = await _cryptoService.decrypt(entry.encryptedIndex, indexKey);
        final payload = IndexPayload.fromJson(json.decode(utf8.decode(decrypted)));

        // Nur Einträge aufnehmen, deren URL zur Ziel-Domain passt.
        if (_matchesDomain(payload.url, domain)) {
          result.add((entry: entry, index: payload));
        }
      } catch (_) {
        // Entschlüsselungsfehler silently ignorieren (z.B. korrupte Daten).
      }
    }

    // Alphabetisch sortieren, damit die Liste immer gleich aussieht.
    result.sort((a, b) => a.index.title.toLowerCase().compareTo(b.index.title.toLowerCase()));
    log.debug('AutofillPicker: ${result.length} Treffer');
    return result;
  }

  /// Prüft, ob die gespeicherte URL eines Eintrags zur Ziel-Domain passt.
  ///
  /// Beispiele:
  /// - `url = "https://www.paypal.com/login"`, `domain = "paypal.com"` → true
  /// - `url = "paypal.com"`, `domain = "paypal.com"` → true (kein Schema → https:// wird ergänzt)
  /// - `url = "sub.paypal.com"`, `domain = "paypal.com"` → true (Subdomain)
  /// - `domain = ""` (unbekannt) → true (alle Einträge zeigen)
  bool _matchesDomain(String url, String domain) {
    if (domain.isEmpty) return true;  // unbekannte Domain → alle zeigen
    final d = domain.toLowerCase();
    try {
      // Wenn die URL kein Schema hat (z.B. "paypal.com"), URI.parse würde sie
      // falsch parsen. Daher "https://" voranstellen.
      final fullUrl = url.startsWith('http') ? url : 'https://$url';
      final host = Uri.parse(fullUrl).host.toLowerCase();
      // Exakter Match ODER Subdomain (z.B. "www.paypal.com" endet mit ".paypal.com")
      // ODER umgekehrt (Domain ist Subdomain der gespeicherten URL).
      return host == d || host.endsWith('.$d') || d.endsWith('.$host');
    } catch (_) {
      // Ungültige URL → einfacher Contains-Vergleich als Fallback.
      return url.toLowerCase().contains(d);
    }
  }

  /// Wird aufgerufen, wenn der Nutzer einen Eintrag antippt.
  ///
  /// Lädt die vollständigen verschlüsselten Daten (Benutzername, Passwort) des Eintrags,
  /// entschlüsselt sie und schickt sie via [AutofillService.complete] an Kotlin.
  ///
  /// **Entschlüsselungs-Ablauf (RSA + AES):**
  /// 1. Permission laden: enthält den `encryptedKey` – der Eintragschlüssel (AES),
  ///    der mit dem RSA-Public-Key des Nutzers verschlüsselt wurde.
  /// 2. `encryptedKey` mit dem RSA-Private-Key des Nutzers entschlüsseln → `entryKey` (AES).
  /// 3. `entry.encryptedData` mit dem `entryKey` (AES-256-GCM) entschlüsseln → JSON.
  /// 4. JSON zu [EntryPayload] parsen → Benutzername und Passwort extrahieren.
  Future<void> _selectEntry(EntryEntity entry) async {
    log.debug('AutofillPicker: _selectEntry id=${entry.id}');
    final userId = _sessionService.user?.id;
    final privateKey = _sessionService.privateKey;

    // Sicherheitscheck: Session könnte in Ausnahmesituationen weg sein.
    if (userId == null || privateKey == null) {
      log.debug('AutofillPicker: _selectEntry – kein userId oder privateKey');
      return;
    }

    try {
      // Schritt 1: Permission für diesen Eintrag und diesen Nutzer laden.
      // Die Permission enthält den mit RSA verschlüsselten Eintragschlüssel.
      final perm = await _databaseService.getPermissionByEntryIdAndUserId(entry.id, userId);
      if (perm == null || perm.encryptedKey.isEmpty) {
        log.debug('AutofillPicker: _selectEntry – keine Permission gefunden');
        return;
      }

      // Schritt 2: Eintragschlüssel (AES) mit dem RSA-Private-Key des Nutzers entschlüsseln.
      final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, privateKey);

      // Schritt 3: Eintragsdaten (Benutzername, Passwort, ...) mit dem AES-Schlüssel entschlüsseln.
      final decryptedData = await _cryptoService.decrypt(entry.encryptedData, entryKey);

      // Schritt 4: JSON parsen.
      final payload = EntryPayload.fromJson(json.decode(utf8.decode(decryptedData)));

      log.debug('AutofillPicker: complete()');

      // Zugangsdaten an Kotlin schicken. Kotlin → AutofillResultRelay → AutofillAuthActivity
      // → setResult(RESULT_OK, dataset) → Android befüllt das Formular → Chrome kommt wieder
      // in den Vordergrund. FamKey geht mit moveTaskToBack(true) in den Hintergrund.
      await _autofillService.complete(payload.username, payload.password);
      log.debug('AutofillPicker: complete() abgeschlossen');

      // Route entfernen, damit der Picker nicht sichtbar ist wenn FamKey wieder in den Vordergrund kommt.
      // Im Cold-Start-Fall (Login → pushReplacementNamed('/autofill-picker')) ist der Picker die einzige
      // Route im Stack – pop() würde einen leeren Stack erzeugen (schwarzer Bildschirm). Daher zu /main.
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();        // Warm-Start: zurück zu /main
        } else {
          Navigator.of(context).pushReplacementNamed('/main');  // Cold-Start: zu /main navigieren
        }
      }
    } catch (e) {
      log.debug('AutofillPicker: _selectEntry Fehler: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final domain = _autofillService.pendingDomain;

    return Scaffold(
      appBar: AppBar(
        // Titelzeile: zeigt die Domain, damit der Nutzer sieht, für welche
        // Website er gerade einen Eintrag auswählt.
        title: Text(domain != null && domain.isNotEmpty ? 'Autofill: $domain' : 'Autofill'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          // Schließen-Button: Autofill abbrechen und Picker schließen.
          onPressed: () async {
            // cancel() informiert Kotlin → AutofillResultRelay.cancel()
            // → AutofillAuthActivity.setResult(CANCELED) → Chrome bekommt kein Ergebnis.
            await _autofillService.cancel();
            if (mounted) {
              // Gleiche canPop-Logik wie in _selectEntry:
              // Cold-Start → pushReplacementNamed, Warm-Start → pop.
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacementNamed('/main');
              }
            }
          },
        ),
      ),
      body: FutureBuilder(
        // FutureBuilder zeigt unterschiedliche Widgets je nach Ladezustand des Futures.
        future: _entriesFuture,
        builder: (context, snapshot) {
          // Solange die Einträge noch geladen werden: Lade-Kreis zeigen.
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? [];

          // Genau ein Treffer → direkt ausfüllen, ohne den Nutzer zu fragen.
          // addPostFrameCallback stellt sicher, dass _selectEntry erst aufgerufen wird,
          // nachdem der aktuelle Frame vollständig gerendert wurde (keine Navigation
          // mitten in einem Build-Durchlauf).
          if (entries.length == 1) {
            log.debug('AutofillPicker: 1 Treffer – Auto-Select');
            WidgetsBinding.instance.addPostFrameCallback((_) => _selectEntry(entries[0].entry));
            return const Center(child: CircularProgressIndicator());
          }

          // Keine passenden Einträge gefunden.
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      domain != null && domain.isNotEmpty
                          ? 'Keine Einträge für "$domain" gefunden.'
                          : 'Keine Einträge gefunden.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            );
          }

          // Mehrere Treffer → Liste anzeigen.
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final item = entries[i];
              return ListTile(
                // Favicon als Avatar, falls vorhanden; sonst erster Buchstabe des Titels.
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
                onTap: () => _selectEntry(item.entry),
              );
            },
          );
        },
      ),
    );
  }
}
