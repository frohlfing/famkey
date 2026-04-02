import 'dart:convert';
import 'package:privault/features/settings/import/import_parser.dart';
import 'package:privault/models/payloads/import_payload.dart';

// todo Parser überarbeiten/vervollständigen und alles dokumentieren

class KeepassXmlParser implements ImportParser {
  final String path;

  KeepassXmlParser(this.path);

  @override
  Future<ImportPayload?> parse() async {
    final xml = XmlDocument.parse(await File(path).readAsString());

    final binaries = _parseGlobalBinaries(xml);
    final entries = _parseEntries(xml, binaries);

    return entries; // ImportPayload = List<ImportEntry>
  }

  List<ImportEntry> _parseEntries(XmlDocument doc, Map<String, Uint8List> binaries) {
    final result = <ImportEntry>[];

    for (final entry in doc.findAllElements('Entry')) {
      final strings = _parseStrings(entry);

      final uuid = _decodeKeepassUuid(entry);
      final title = strings['Title'] ?? '';
      final username = strings['UserName'] ?? '';
      final password = strings['Password'] ?? '';
      final url = strings['URL'] ?? '';
      final notes = strings['Notes'] ?? '';
      final favicon = ''; // KeePass speichert keine Favicons

      final updatedAt = _parseUpdatedAt(entry);
      final passwordTimestamp = _parsePasswordTimestamp(entry);

      final attachments = _parseAttachments(entry, binaries);

      result.add(ImportEntry(
        uuid: uuid,
        category: _detectCategory(strings),
        title: title,
        username: username,
        password: password,
        passwordTimestamp: passwordTimestamp,
        url: url,
        notes: notes,
        favicon: favicon,
        updatedAt: updatedAt,
        attachments: attachments,
      ));
    }

    return result;
  }

  String _decodeKeepassUuid(String base64Uuid) {
    // 1. Base64 → Bytes
    final bytes = base64.decode(base64Uuid);

    if (bytes.length != 16) {
      throw FormatException("KeePass UUID must be 16 bytes");
    }

    // 2. Bytes → Hex
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    // 3. Hex → UUID-Format
    return "${hex.substring(0, 8)}-"
        "${hex.substring(8, 12)}-"
        "${hex.substring(12, 16)}-"
        "${hex.substring(16, 20)}-"
        "${hex.substring(20)}";
  }

  DateTime? _parsePasswordTimestamp(XmlElement entry) {
    // 1. History prüfen
    final history = entry.findElements('History');
    if (history.isNotEmpty) {
      final histEntries = history.first.findElements('Entry').toList().reversed;

      for (final hist in histEntries) {
        final strings = {
          for (final s in hist.findElements('String'))
            s.findElements('Key').first.text:
            s.findElements('Value').first.text
        };

        if (strings.containsKey('Password')) {
          final times = hist.findElements('Times');
          if (times.isNotEmpty) {
            final ts = times.first.findElements('LastModificationTime');
            if (ts.isNotEmpty) {
              return DateTime.parse(ts.first.text).toUtc();
            }
          }
        }
      }
    }

    // 2. Fallback: Entry selbst
    final times = entry.findElements('Times');
    if (times.isNotEmpty) {
      final ts = times.first.findElements('LastModificationTime');
      if (ts.isNotEmpty) {
        return DateTime.parse(ts.first.text).toUtc();
      }
    }

    return null;
  }

  DateTime _parseUpdatedAt(XmlElement entry) {
    final times = entry.findElements('Times');
    if (times.isNotEmpty) {
      final lastMod = times.first.findElements('LastModificationTime');
      if (lastMod.isNotEmpty) {
        return DateTime.parse(lastMod.first.text).toUtc();
      }

      final creation = times.first.findElements('CreationTime');
      if (creation.isNotEmpty) {
        return DateTime.parse(creation.first.text).toUtc();
      }
    }

    // Fallback
    return DateTime.now().toUtc();
  }

  Map<String, Uint8List> _parseGlobalBinaries(XmlElement meta) {
    final binaries = <String, Uint8List>{};

    for (final bin in meta.findElements('Binaries').first.findElements('Binary')) {
      final id = bin.getAttribute('ID')!;
      final compressed = bin.getAttribute('Compressed') == 'True';
      final data = base64.decode(bin.text.trim());

      binaries[id] = compressed ? gzip.decode(data) : data;
    }

    return binaries;
  }

  Future<void> _parseAttachments(XmlElement entry, int entryId, Map<String, Uint8List> globalBinaries) async {
    for (final bin in entry.findElements('Binary')) {
      final fileName = bin.findElements('Key').first.text;
      final ref = bin.findElements('Value').first.getAttribute('Ref');

      if (ref == null) continue;

      final data = globalBinaries[ref];
      if (data == null) continue;

      final uuid = Uuid().v4();

      await db.into(db.attachments).insert(
        AttachmentsCompanion.insert(
          uuid: uuid,
          entryId: entryId,
          encryptedMeta: encryptMeta({
            'fileName': fileName,
            'size': data.length,
          }),
          encryptedContent: encryptBinary(data),
          isSynced: false,
        ),
      );
    }
  }
}