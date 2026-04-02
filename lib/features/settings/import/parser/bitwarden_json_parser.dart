import 'dart:convert';
import 'dart:io';
import 'package:privault/features/settings/import/import_parser.dart';
import 'package:privault/models/payloads/import_payload.dart';

// todo Parser überarbeiten/vervollständigen und alles dokumentieren

class BitwardenJsonParser implements ImportParser {
  final String path;

  BitwardenJsonParser(this.path);

  @override
  Future<ImportPayload?> parse() async {
    final json = jsonDecode(await File(path).readAsString());

    final items = json['items'] as List;

    return items.map(_parseItem).toList();
  }

  ImportEntry _parseItem(Map<String, dynamic> item) {
    final login = item['login'];

    return ImportEntry(
      uuid: item['id'],
      category: item['type'] == 1 ? 'login' : 'note',
      title: item['name'] ?? '',
      username: login?['username'] ?? '',
      password: login?['password'] ?? '',
      passwordTimestamp: null,
      url: login?['uris']?[0]?['uri'] ?? '',
      notes: item['notes'] ?? '',
      favicon: '', // Bitwarden liefert keine Favicons
      updatedAt: DateTime.parse(item['revisionDate']),
      attachments: _parseAttachments(item),
    );
  }
}
