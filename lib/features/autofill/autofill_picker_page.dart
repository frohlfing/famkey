import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/models/payloads/index_payload.dart';
import 'package:privault/services/autofill_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';

/// Zeigt passende Einträge zur Auswahl beim Autofill-Vorgang an (unter Android).
///
/// Wird geöffnet, wenn der native [PriVaultAutofillService] einen Autofill-Request sendet.
/// Der Nutzer wählt einen Eintrag – danach werden die Felder in der anfragenden App befüllt
/// und diese Activity geschlossen.
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

  late final Future<List<({EntryEntity entry, IndexPayload index})>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _autofillService = getIt();
    _cryptoService = getIt();
    _databaseService = getIt();
    _sessionService = getIt();
    _entriesFuture = _loadMatchingEntries();
  }

  Future<List<({EntryEntity entry, IndexPayload index})>> _loadMatchingEntries() async {
    final domain = _autofillService.pendingDomain ?? '';
    final indexKey = _sessionService.indexKey;
    if (indexKey == null) return [];

    final entries = await _databaseService.getEntries();
    final result = <({EntryEntity entry, IndexPayload index})>[];

    for (final entry in entries) {
      if (entry.encryptedIndex.isEmpty) continue;
      try {
        final decrypted = await _cryptoService.decrypt(entry.encryptedIndex, indexKey);
        final payload = IndexPayload.fromJson(json.decode(utf8.decode(decrypted)));
        if (_matchesDomain(payload.url, domain)) {
          result.add((entry: entry, index: payload));
        }
      } catch (_) {}
    }

    result.sort((a, b) => a.index.title.toLowerCase().compareTo(b.index.title.toLowerCase()));
    return result;
  }

  bool _matchesDomain(String url, String domain) {
    if (domain.isEmpty) return true;
    final d = domain.toLowerCase();
    try {
      final fullUrl = url.startsWith('http') ? url : 'https://$url';
      final host = Uri.parse(fullUrl).host.toLowerCase();
      return host == d || host.endsWith('.$d') || d.endsWith('.$host');
    } catch (_) {
      return url.toLowerCase().contains(d);
    }
  }

  Future<void> _selectEntry(EntryEntity entry) async {
    final userId = _sessionService.user?.id;
    final privateKey = _sessionService.privateKey;
    if (userId == null || privateKey == null) return;

    try {
      final perm = await _databaseService.getPermissionByEntryIdAndUserId(entry.id, userId);
      if (perm == null || perm.encryptedKey.isEmpty) return;

      final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, privateKey);
      final decryptedData = await _cryptoService.decrypt(entry.encryptedData, entryKey);
      final payload = EntryPayload.fromJson(json.decode(utf8.decode(decryptedData)));

      await _autofillService.complete(payload.username, payload.password);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final domain = _autofillService.pendingDomain;

    return Scaffold(
      appBar: AppBar(
        title: Text(domain != null && domain.isNotEmpty ? 'Autofill: $domain' : 'Autofill'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            await _autofillService.cancel();
          },
        ),
      ),
      body: FutureBuilder(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? [];

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

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final item = entries[i];
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
                onTap: () => _selectEntry(item.entry),
              );
            },
          );
        },
      ),
    );
  }
}
