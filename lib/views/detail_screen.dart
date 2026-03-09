import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:privault/viewmodels/detail_view_model.dart';
import 'package:privault/widgets/confirm_dialog.dart';
import 'package:privault/widgets/friend_selector_dialog.dart';
import 'package:privault/widgets/password_strength_bar.dart';
import 'package:privault/widgets/snack.dart';

/// Der [DetailScreen] ist dafür zuständig, dir die vollständigen Details eines bestimmten
/// Tresor-Eintrags anzuzeigen.
///
/// Über die [entryId] lädt der Screen die entsprechenden Daten mithilfe des [DetailViewModel].
/// In dieser Ansicht kannst du:
/// * Benutzernamen und Passwörter einsehen und in die Zwischenablage kopieren.
/// * Die Passwortsicherheit anhand einer visuellen Anzeige beurteilen.
/// * Hinterlegte URLs direkt im Browser öffnen.
/// * Notizen lesen und Anhänge (wie Bilder oder Dokumente) verwalten oder ansehen.
/// * Falls du die Berechtigung hast, direkt in den Bearbeitungsmodus wechseln.
class DetailScreen extends StatefulWidget {
  final int entryId;

  /// Konstruktor
  const DetailScreen({super.key, required this.entryId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  late DetailViewModel _viewModel;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Screen und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    _viewModel = context.read<DetailViewModel>();
    //_viewModel.addListener(_onViewModelChanged);
    _viewModel.init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.load(widget.entryId);
    });
  }

  // /// Entfernt den Listener und gibt alle Ressourcen frei.
  // @override
  // void dispose() {
  //   _viewModel.removeListener(_onViewModelChanged);
  // }

  // /// Wird getriggert, wenn das ViewModel notifyListeners() aufruft.
  // /// Hier kann u.a. der Text vom TextEditingController aktualisiert werden.
  // void _onViewModelChanged() {
  // }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  /// Baut die zentrale Detailansicht eines Eintrags auf.
  @override
  Widget build(BuildContext context) {
    // Dies triggert die build-Methode jedes Mal, wenn das ViewModel notifyListeners() aufruft.
    final viewModel = context.watch<DetailViewModel>();

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Details'),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _handleBack,
              tooltip: "Zurück",
            ),
            actions: [
              if (viewModel.canEdit) // Bearbeiten-Button ausblenden, wenn nur Leserecht
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Bearbeiten',
                  onPressed: _handleEdit,
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ------------------------------------------------------------------------
                // Header
                // ------------------------------------------------------------------------
                Center(
                  child: Column(
                    children: [
                      if (viewModel.favicon.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Image.memory(
                            base64Decode(viewModel.favicon),
                            width: 64,
                            height: 64,
                          ),
                        ),
                      Text(
                        viewModel.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        viewModel.category,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ------------------------------------------------------------------------
                // Stammdaten
                // ------------------------------------------------------------------------

                // Username Card
                ListTile(
                  title: const Text('Benutzername'),
                  subtitle: Text(viewModel.username),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copyToClipboard(viewModel.username, 'Benutzername'),
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
                            tooltip: viewModel.isPasswordHidden ? 'Passwort anzeigen' : 'Passwort verbergen',
                            onPressed: viewModel.togglePasswordVisibility,
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () => _copyToClipboard(viewModel.password, 'Passwort'),
                            tooltip: 'Passwort kopieren',
                          ),
                        ],
                      ),
                    ),
                    if (viewModel.password.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: PasswordStrengthBar(score: viewModel.passwordStrength),
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
                      onPressed: () => _openUrl(viewModel.url),
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

                // ------------------------------------------------------------------------
                // Anhänge
                // ------------------------------------------------------------------------
                if (viewModel.canManageAttachments || viewModel.attachments.isNotEmpty) ...[
                  if (viewModel.canManageAttachments)
                    _buildSectionHeaderWithAction(
                      'Anhänge',
                      Icons.add_circle_outline,
                      'Datei anhängen',
                      _handleAddAttachment,
                    )
                  else
                    _buildSectionTitle('Anhänge'),
                  const SizedBox(height: 4),
                  if (viewModel.attachments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 0, bottom: 8, left: 16, right: 16),
                      child: Text(
                        'Keine Anhänge vorhanden.',
                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                      ),
                    )
                  else
                    ...viewModel.attachments.map((attachment) {
                      final meta = viewModel.getAttachmentMeta(attachment.uuid);
                      final iconType = viewModel.getIconType(
                        meta?.filename ?? '',
                        meta?.mime ?? '',
                      );
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => viewModel.openAttachment(attachment),
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
                                  : Icon(
                                      _getIconForType(iconType),
                                      size: 48,
                                      color: Colors.blueGrey,
                                    ),
                            ),
                          ),
                          title: Text(meta?.filename ?? 'Datei'),
                          subtitle: Text(viewModel.formatSize(meta?.size ?? 0)),
                          trailing: viewModel.canManageAttachments
                              ? IconButton(
                                  icon: const Icon(Icons.delete),
                                  tooltip: 'Anhang löschen',
                                  onPressed: () => _handleDeleteAttachment(attachment),
                                )
                              : null,
                        ),
                      );
                    }),
                  const Divider(),
                ],

                // ------------------------------------------------------------------------
                // Geteilt mit
                // ------------------------------------------------------------------------
                if (viewModel.canManageShares || viewModel.sharedWith.isNotEmpty) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (viewModel.canManageShares)
                        _buildSectionHeaderWithAction(
                          'Geteilt mit',
                          Icons.person_add_alt_1_outlined,
                          'Freigabe hinzufügen',
                          _handleAddFriend,
                        )
                      else
                        _buildSectionTitle('Geteilt mit'),
                      const SizedBox(height: 4),
                      if (viewModel.sharedWith.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 0, bottom: 8, left: 16, right: 16),
                          child: Text(
                            'Dieser Eintrag ist noch nicht geteilt.',
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                          ),
                        )
                      else
                        ...viewModel.sharedWith.map((friend) {
                          final isWritable = viewModel.getAccessLevel(friend.id) == 2;
                          Widget leadingIcon = Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              const Icon(Icons.person_outline, size: 40, color: Colors.blueGrey),
                              if (!friend.isVerified) const Icon(Icons.warning, size: 18, color: Colors.amber),
                            ],
                          );

                          if (!friend.isVerified) {
                            leadingIcon = MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () async {
                                  await Navigator.pushNamed(
                                    context,
                                    '/settings',
                                    arguments: {'focus_user_uuid': friend.uuid},
                                  );
                                  if (mounted) _viewModel.load(widget.entryId);
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
                              title: Text(friend.name),
                              trailing: viewModel.canManageShares
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Schreibrechte',
                                          style: TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                        Transform.scale(
                                          scale: 0.75,
                                          child: Switch(
                                            value: isWritable,
                                            onChanged: (bool value) => viewModel.updateAccessLevel(friend, value ? 2 : 1),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          tooltip: 'Zugriff entziehen',
                                          onPressed: () => _handleDeleteFriend(friend),
                                        ),
                                      ],
                                    )
                                  : (isWritable
                                        ? const Text(
                                            'Schreibrechte',
                                            style: TextStyle(color: Colors.grey),
                                          )
                                        : const Text(
                                            'Nur Leserechte',
                                            style: TextStyle(color: Colors.grey),
                                          )),
                            ),
                          );
                        }),
                    ],
                  ),
                  const Divider(),
                ],

                // Audit Hint
                if (viewModel.auditHint.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      viewModel.auditHint,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
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

  // ------------------------------------------------------------------------
  // --- Widgets ---
  // ------------------------------------------------------------------------

  /// Hilfsmethode zur Erstellung einer einheitlichen, fettgedruckten Überschrift
  /// für die verschiedenen Inhaltsabschnitte der Detailansicht.
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
    );
  }

  /// Erstellt eine Sektion-Überschrift, die zusätzlich eine Aktion (Icon-Button)
  /// auf der rechten Seite enthält – beispielsweise zum Hinzufügen von Anhängen
  /// oder neuen Freigaben.
  Widget _buildSectionHeaderWithAction(String title, IconData icon, String tooltip, VoidCallback onPressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionTitle(title),
        Padding(
          padding: EdgeInsets.only(top: 0, bottom: 0, left: 0, right: 24),
          child: IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onPressed),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  /// Navigiert zurück zur Hauptseite
  Future<void> _handleBack() async {
    if (_viewModel.isBusy) return;
    Navigator.of(context).pop(_viewModel.hasChanged);
  }

  /// Öffnet die Bearbeitungsansicht und aktualisiert die Daten bei Rückkehr, falls Änderungen vorgenommen wurden.
  Future<void> _handleEdit() async {
    if (_viewModel.isBusy) return;
    final hasChanged = await Navigator.of(context).pushNamed('/edit', arguments: widget.entryId);
    if (hasChanged == true && mounted) {
      _viewModel.markAsChanged();
      _viewModel.load(widget.entryId);
    }
  }

  /// Speichert erst die Änderungen, wenn gewünscht und springt dann zurück.
  Future<void> _handleAddAttachment() async {
    if (_viewModel.isBusy) return;
    _viewModel.addAttachment();
  }

  /// Fragt nach Bestätigung und löscht dann den Anhang.
  Future<void> _handleDeleteAttachment(dynamic attachment) async {
    if (_viewModel.isBusy) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Anhang löschen',
      text: 'Möchtest du diesen Anhang wirklich löschen?',
      ok: 'Ja, löschen',
      autofocus: false,
    );
    if (confirmed == true && mounted) {
      _viewModel.deleteAttachment(attachment);
    }
  }

  /// Öffnet einen Dialog zur Auswahl eines Kontakts aus Deiner Freundesliste,
  /// um diesen Eintrag mit ihm zu teilen.
  ///
  /// Es werden nur Kontakte angezeigt, die noch keinen Zugriff auf den Eintrag haben.
  Future<void> _handleAddFriend() async {
    if (_viewModel.isBusy) return;
    final user = await FriendSelectorDialog.show(context, _viewModel.unsharedFriends);
    if (user == null || !mounted) return;
    _viewModel.shareWith(user);
  }

  /// Fragt nach Bestätigung und entzieht dann den Zugriff für den Benutzer.
  Future<void> _handleDeleteFriend(dynamic user) async {
    if (_viewModel.isBusy) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Zugriff entziehen',
      text: 'Möchtest du diesen Eintrag nicht mehr mit der Person teilen?',
      ok: 'Ja, Zugriff entziehen',
    );
    if (confirmed == true && mounted) {
      _viewModel.revokeAccess(user);
    }
  }

  // ------------------------------------------------------------------------
  // --- Interne Methoden ---
  // ------------------------------------------------------------------------

  /// Kopiert den Text in die Zwischenablage und gibt eine SnackBar mit dem Ergebnis aus.
  /// `label` ist die Beschriftung des kopierten Textes.
  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    Snack.show(context, '$label in die Zwischenablage kopiert', success: true);
  }

  /// Öffnet die angegebene URL in einem neuen Browser-Tab oder gibt eine SnackBar mit dem Ergebnis aus.
  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final Uri uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    try {
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success && mounted) {
        Snack.show(context, 'URL konnte nicht geöffnet werden');
      }
    } catch (e, st) {
      if (mounted) Snack.showException(context, e, stackTrace: st, label: 'DetailScreen');
    }
  }

  /// Mappt einen Dateityp oder eine Dateiendung auf ein passendes Icon.
  ///
  /// Dies sorgt für eine visuelle Unterscheidung zwischen verschiedenen Anhangs-Typen
  /// wie Bildern, PDFs, Dokumenten oder Archiven.
  IconData _getIconForType(String type) {
    // @formatter:off
      switch (type) {
        case 'image': return Icons.image_outlined;
        case 'pdf':  return Icons.picture_as_pdf_outlined;
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
    // @formatter:on
  }
}
