import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:privault/viewmodels/detail_view_model.dart';

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

  /// Kopiert den Text in die Zwischenablage und gibt eine SnackBar mit dem Ergebnis aus.
  ///
  /// - [context] BuildContext des Widgets
  /// - [text] Text, der in die Zwischenablage kopiert werden soll
  /// - [label] Beschriftung des Kopierten Texts
  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label in die Zwischenablage kopiert')));
  }

  /// Öffnet die angegebene URL in einem neuen Browser-Tab oder gibt eine SnackBar mit dem Ergebnis aus.
  Future<void> _openUrl(BuildContext context, String url) async {
    if (url.isEmpty) return;
    final Uri uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL konnte nicht geöffnet werden')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Öffnen: $e')));
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

  /// Gibt einen Text basierend auf der Stärke des Passworts zurück.
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
      case 'vcard': return Icons.contact_page_outlined;
      case 'archive': return Icons.inventory_2_outlined;
      case 'video': return Icons.movie_outlined;
      case 'audio': return Icons.audiotrack_outlined;
      case 'text': return Icons.text_snippet_outlined;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DetailViewModel>();

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Details'),
            centerTitle: true,
            actions: [
              if (viewModel.canEdit) // Bearbeiten-Button ausblenden, wenn nur Leserecht
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
          body: viewModel.errorMessage != null
          ? Center(
              child: Text(viewModel.errorMessage!, style: const TextStyle(color: Colors.red)),
            )
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
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Image.memory(base64Decode(viewModel.favicon), width: 64, height: 64),
                          ),
                        Text(
                          viewModel.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          viewModel.category,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                        ),
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

                  // Password Section
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
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _getStrengthText(viewModel.passwordStrength),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _getStrengthColor(viewModel.passwordStrength),
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
                    ListTile(title: const Text('Notizen'), subtitle: Text(viewModel.notes)),
                    const Divider(),
                  ],

                  // Anhänge Section
                  if (viewModel.canManageAttachments || viewModel.attachments.isNotEmpty) ...[
                    if (viewModel.canManageAttachments)
                      _buildSectionHeaderWithAction(
                        'Anhänge',
                        Icons.add_circle_outline,
                        'Datei anhängen',
                        viewModel.addAttachment,
                      )
                    else
                      _buildSectionTitle('Anhänge'),
                    const SizedBox(height: 4),
                    if (viewModel.attachments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
                        child: Text(
                          'Keine Anhänge vorhanden.',
                          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                        ),
                      )
                    else
                      ...viewModel.attachments.map((att) {
                        final meta = viewModel.getAttachmentMeta(att.uuid);
                        final iconType = viewModel.getIconType(meta?.filename ?? '', meta?.mime ?? '');
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => viewModel.openAttachment(att),
                                child: meta?.thumbnail != null && meta!.thumbnail!.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.memory(
                                          base64Decode(meta.thumbnail!),
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Icon(_getIconForType(iconType), size: 48, color: Colors.blueGrey),
                              ),
                            ),
                            title: Text(meta?.filename ?? 'Datei'),
                            subtitle: Text(viewModel.formatSize(meta?.size ?? 0)),
                            trailing: viewModel.canManageAttachments ? IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              iconSize: 26,
                              tooltip: 'Anhang löschen',
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Anhang löschen'),
                                    content: Text("Soll der Anhang '${meta?.filename}' wirklich gelöscht werden?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Abbrechen'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Ja, löschen', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && mounted) {
                                  viewModel.deleteAttachment(att);
                                }
                              },
                            ) : null,
                          ),
                        );
                      }),
                    const Divider(),
                  ],

                  // Geteilt mit Section
                  if (viewModel.canManageShares || viewModel.sharedWith.isNotEmpty) ...[
                    _buildSharedWithSection(viewModel),
                    const Divider(),
                  ],

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
        ),
        if (viewModel.isBusy)
          Container(
            color: Colors.black.withValues(alpha: 0.1),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildSharedWithSection(DetailViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (viewModel.canManageShares)
          _buildSectionHeaderWithAction('Geteilt mit', Icons.person_add_alt_1_outlined, 'Freigabe hinzufügen', () {
            _showShareDialog(context, viewModel);
          })
        else
          _buildSectionTitle('Geteilt mit'),
        const SizedBox(height: 4),
        if (viewModel.sharedWith.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
            child: Text(
              'Dieser Eintrag ist noch nicht geteilt.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          )
        else
          ...viewModel.sharedWith.map((user) {
            final isWritable = viewModel.getAccessLevel(user.id!) == 2;
            Widget leadingIcon = Stack(
              alignment: Alignment.bottomRight,
              children: [
                const Icon(Icons.person_outline, size: 40, color: Colors.blueGrey),
                if (!user.isVerified)
                  const Icon(Icons.warning, size: 18, color: Colors.amber),
              ],
            );

            if (!user.isVerified) {
              leadingIcon = MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.pushNamed(context, '/settings', arguments: {'focus_user_uuid': user.uuid});
                    if (mounted) _viewModel.initialize(widget.entryId);
                  },
                  child: Tooltip(
                    message: 'Person ist nicht verifiziert!',
                    child: leadingIcon,
                  ),
                ),
              );
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: leadingIcon,
                title: Text(user.name),
                trailing: viewModel.canManageShares ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Schreiben', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                      value: isWritable,
                      onChanged: (bool value) {
                        viewModel.updateAccessLevel(user, value ? 2 : 1);
                      },
                    )),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      iconSize: 26,
                      tooltip: 'Zugriff entziehen',
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Zugriff entziehen'),
                            content: Text('Möchtest du diesen Eintrag nicht mehr mit ${user.name} teilen?'),
                            actions: [
                              TextButton(child: const Text('Abbrechen'), onPressed: () => Navigator.of(ctx).pop(false)),
                              TextButton(
                                child: const Text('Ja, Zugriff entziehen', style: TextStyle(color: Colors.red)),
                                onPressed: () => Navigator.of(ctx).pop(true),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          viewModel.revokeAccess(user);
                        }
                      },
                    ),
                  ],
                ) : (isWritable ? const Text('Schreiben', style: TextStyle(color: Colors.grey)) : const Text('Nur Lesen', style: TextStyle(color: Colors.grey))),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _showShareDialog(BuildContext context, DetailViewModel viewModel) async {
    final available = viewModel.availableContacts;
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eintrag teilen'),
          content: available.isEmpty
              ? const Text('Keine weiteren Kontakte verfügbar.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: available.length,
                    separatorBuilder: (ctx, i) => const Divider(),
                    itemBuilder: (ctx, index) {
                      final user = available[index];
                      Widget leadingIcon = Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            child: Icon(Icons.person, size: 20),
                          ),
                          if (!user.isVerified)
                            const Icon(Icons.warning, size: 16, color: Colors.amber),
                        ],
                      );

                      if (!user.isVerified) {
                        leadingIcon = Tooltip(
                          message: 'Person ist nicht verifiziert!',
                          child: leadingIcon,
                        );
                      }

                      return ListTile(
                        leading: leadingIcon,
                        title: Text(user.name),
                        onTap: () {
                          viewModel.shareWith(user);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
          actions: <Widget>[TextButton(child: const Text('Abbrechen'), onPressed: () => Navigator.of(context).pop())],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
    );
  }

  Widget _buildSectionHeaderWithAction(String title, IconData icon, String tooltip, VoidCallback onPressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionTitle(title),
        Tooltip(
          message: tooltip,
          child: IconButton(icon: Icon(icon), onPressed: onPressed),
        ),
      ],
    );
  }
}
