import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:privault/viewmodels/detail_view_model.dart';
import 'package:privault/models/entities/attachment_entity.dart';

class DetailScreen extends StatefulWidget {
  final int entryId;

  const DetailScreen({super.key, required this.entryId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late DetailViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<DetailViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewModel.initialize(widget.entryId);
    });
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label in die Zwischenablage kopiert')),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    if (url.isEmpty) return;
    final Uri uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('URL konnte nicht geöffnet werden')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Öffnen: $e')),
        );
      }
    }
  }

  Color _getStrengthColor(int score) {
    switch (score) {
      case 0: return const Color(0xFFCBD5E1);
      case 1: return const Color(0xFFDC2626);
      case 2: return const Color(0xFFF59E0B);
      case 3: return const Color(0xFF84CC16);
      case 4: return const Color(0xFF16A34A);
      default: return const Color(0xFFCBD5E1);
    }
  }

  String _getStrengthText(int score) {
    switch (score) {
      case 0: return "";
      case 1: return "Sehr schwach";
      case 2: return "Schwach";
      case 3: return "Gut";
      case 4: return "Stark";
      default: return "";
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'image': return Icons.image_outlined;
      case 'pdf': return Icons.picture_as_pdf_outlined;
      case 'word': return Icons.description_outlined;
      case 'slides': return Icons.present_to_all_outlined;
      case 'excel': return Icons.table_chart_outlined;
      case 'archive': return Icons.inventory_2_outlined;
      case 'video': return Icons.movie_outlined;
      case 'audio': return Icons.audiotrack_outlined;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DetailViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/edit', arguments: widget.entryId);
              if (result == true && mounted) {
                _viewModel.initialize(widget.entryId);
              }
            },
          ),
        ],
      ),
      body: viewModel.isBusy
          ? const Center(child: CircularProgressIndicator())
          : viewModel.errorMessage != null
              ? Center(child: Text(viewModel.errorMessage!, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Center(
                        child: Column(
                          children: [
                            if (viewModel.favicon.isNotEmpty)
                              Image.memory(base64Decode(viewModel.favicon), width: 64, height: 64)
                            else
                              const Icon(Icons.vpn_key_outlined, size: 64, color: Colors.blueGrey),
                            const SizedBox(height: 16),
                            Text(viewModel.title, 
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                            Text(viewModel.category, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Username Card
                      ListTile(
                        title: const Text('Benutzername'),
                        subtitle: Text(viewModel.username),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () => _copyToClipboard(context, viewModel.username, 'Benutzername'),
                          tooltip: 'Benutzername kopieren',
                        ),
                      ),
                      const Divider(),

                      // Password Card mit Stärke-Meter
                      Column(
                        children: [
                          ListTile(
                            title: const Text('Passwort'),
                            subtitle: Text(viewModel.isPasswordHidden ? '••••••••' : viewModel.password),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(viewModel.isPasswordHidden ? Icons.visibility : Icons.visibility_off),
                                  onPressed: viewModel.togglePasswordVisibility,
                                  tooltip: viewModel.isPasswordHidden ? 'Passwort anzeigen' : 'Passwort verbergen',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () => _copyToClipboard(context, viewModel.password, 'Passwort'),
                                  tooltip: 'Passwort kopieren',
                                ),
                              ],
                            ),
                          ),
                          if (viewModel.password.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: (viewModel.passwordStrength + 1) / 5,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor: AlwaysStoppedAnimation<Color>(_getStrengthColor(viewModel.passwordStrength)),
                                        minHeight: 4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _getStrengthText(viewModel.passwordStrength),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _getStrengthColor(viewModel.passwordStrength)
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const Divider(),

                      // URL Section
                      if (viewModel.url.isNotEmpty) ...[
                        ListTile(
                          title: const Text('URL'),
                          subtitle: Text(viewModel.url),
                          trailing: IconButton(
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () => _openUrl(context, viewModel.url),
                            tooltip: 'URL öffnen',
                          ),
                        ),
                        const Divider(),
                      ],

                      // Notes Section
                      if (viewModel.notes.isNotEmpty) ...[
                        ListTile(
                          title: const Text('Notizen'),
                          subtitle: Text(viewModel.notes),
                        ),
                        const Divider(),
                      ],

                      // Anhänge Section
                      _buildSectionHeaderWithAction('Anhänge', Icons.add_circle_outline, 'Datei anhängen', viewModel.addAttachment),
                      const SizedBox(height: 8),
                      if (viewModel.attachments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('Keine Anhänge vorhanden.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                        )
                      else
                        ...viewModel.attachments.map((att) {
                          final meta = viewModel.getAttachmentMeta(att.uuid);
                          final iconType = viewModel.getIconType(meta?.filename ?? '');
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(_getIconForType(iconType), size: 32, color: Colors.blueGrey),
                              title: Text(meta?.filename ?? 'Datei'),
                              subtitle: Text(viewModel.formatSize(meta?.size ?? 0)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Anhang löschen'),
                                      content: Text("Soll der Anhang '${meta?.filename}' wirklich gelöscht werden?"),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Löschen', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true && mounted) {
                                    viewModel.deleteAttachment(att);
                                  }
                                },
                                tooltip: 'Anhang löschen',
                              ),
                              onTap: () => viewModel.openAttachment(att),
                            ),
                          );
                        }).toList(),

                      const Divider(),

                      // Audit Hint
                      if (viewModel.auditHint.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            viewModel.auditHint,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    );
  }

  Widget _buildSectionHeaderWithAction(String title, IconData icon, String tooltip, VoidCallback onPressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionTitle(title),
        Tooltip(message: tooltip, child: IconButton(icon: Icon(icon), onPressed: onPressed)),
      ],
    );
  }
}
