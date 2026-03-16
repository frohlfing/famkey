import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/features/detail/detail_notifier.dart';
import 'package:privault/widgets/confirm_dialog.dart';
import 'package:privault/widgets/friend_selector_dialog.dart';
import 'package:privault/widgets/password_strength_bar.dart';
import 'package:privault/widgets/snack.dart';
import 'package:url_launcher/url_launcher.dart';

/// Der [DetailPage] ist dafür zuständig, dir die vollständigen Details eines bestimmten
/// Tresor-Eintrags anzuzeigen.
///
/// Über die [entryId] lädt der Screen die entsprechenden Daten mithilfe des [DetailViewModel].
/// In dieser Ansicht kannst du:
/// * Benutzernamen und Passwörter einsehen und in die Zwischenablage kopieren.
/// * Die Passwortsicherheit anhand einer visuellen Anzeige beurteilen.
/// * Hinterlegte URLs direkt im Browser öffnen.
/// * Notizen lesen und Anhänge (wie Bilder oder Dokumente) verwalten oder ansehen.
/// * Falls du die Berechtigung hast, direkt in den Bearbeitungsmodus wechseln.
class DetailPage extends ConsumerStatefulWidget {
  /// Die ID des anzuzeigenden Eintrags
  final int entryId;

  /// Konstruktor
  const DetailPage({super.key, required this.entryId});

  @override
  ConsumerState<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends ConsumerState<DetailPage> {

  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  /// Gibt an, ob das Passwort ausgeblendet ist
  bool _obscurePassword = true;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Screen und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Daten laden
      final notifier = ref.read(detailProvider.notifier);
      await notifier.load(widget.entryId);
    });
  }

  // /// Entfernt den Listener und gibt alle Ressourcen frei.
  // @override
  // void dispose() {
  //   _viewModel.removeListener(_onViewModelChanged);
  // }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  /// Baut die zentrale Detailansicht eines Eintrags auf.
  @override
  Widget build(BuildContext context) {
    // Notifier und State holen
    final notifier = ref.read(detailProvider.notifier);
    final state = ref.watch(detailProvider);

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
              if (state.canEdit) // Bearbeiten-Button ausblenden, wenn nur Leserecht
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
                      if (state.favicon.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Image.memory(
                            base64Decode(state.favicon),
                            width: 64,
                            height: 64,
                          ),
                        ),
                      Text(
                        state.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        state.category,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ------------------------------------------------------------------------
                // Stammdaten
                // ------------------------------------------------------------------------

                // Benutzername
                ListTile(
                  title: const Text('Benutzername'),
                  subtitle: Text(state.username),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copyToClipboard(state.username, 'Benutzername'),
                    tooltip: 'Benutzername kopieren',
                  ),
                ),
                const Divider(),

                // Passwort
                Column(
                  children: [
                    ListTile(
                      title: const Text('Passwort'),
                      subtitle: Text(_obscurePassword ? '••••••••' : state.password),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                            tooltip: _obscurePassword ? 'Passwort anzeigen' : 'Passwort verbergen',
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () => _copyToClipboard(state.password, 'Passwort'),
                            tooltip: 'Passwort kopieren',
                          ),
                        ],
                      ),
                    ),
                    if (state.password.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: PasswordStrengthBar(
                          score: notifier.getPasswordStrength(),
                        ),
                      ),
                  ],
                ),
                const Divider(),

                // URL
                if (state.url.isNotEmpty) ...[
                  ListTile(
                    title: const Text('URL'),
                    subtitle: Text(state.url),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _openUrl(state.url),
                      tooltip: 'URL öffnen',
                    ),
                  ),
                  const Divider(),
                ],

                // Notizen
                if (state.notes.isNotEmpty) ...[
                  ListTile(title: const Text('Notizen'), subtitle: Text(state.notes)),
                  const Divider(),
                ],

                // ------------------------------------------------------------------------
                // Anhänge
                // ------------------------------------------------------------------------
                if (notifier.canManageAttachments() || state.attachments.isNotEmpty) ...[
                  if (notifier.canManageAttachments())
                    _buildSectionHeaderWithAction(
                      'Anhänge',
                      Icons.add_circle_outline,
                      'Datei anhängen',
                      _handleAddAttachment,
                    )
                  else
                    _buildSectionTitle('Anhänge'),
                  const SizedBox(height: 4),
                  if (state.attachments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 0, bottom: 8, left: 16, right: 16),
                      child: Text(
                        'Keine Anhänge vorhanden.',
                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                      ),
                    )
                  else
                    ...state.attachments.map((attachment) {
                      final meta = notifier.getAttachmentMeta(attachment.uuid);
                      final iconType = notifier.getIconType(meta?.filename ?? '', meta?.mime ?? '');
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => notifier.openAttachment(attachment),
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
                          subtitle: Text(notifier.formatSize(meta?.size ?? 0)),
                          trailing: notifier.canManageAttachments()
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
                if (state.canManageShares || state.sharedFriends.isNotEmpty) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (state.canManageShares)
                        _buildSectionHeaderWithAction(
                          'Geteilt mit',
                          Icons.person_add_alt_1_outlined,
                          'Freigabe hinzufügen',
                          _handleAddFriend,
                        )
                      else
                        _buildSectionTitle('Geteilt mit'),
                      const SizedBox(height: 4),
                      if (state.sharedFriends.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 0, bottom: 8, left: 16, right: 16),
                          child: Text(
                            'Dieser Eintrag ist noch nicht geteilt.',
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                          ),
                        )
                      else
                        ...state.sharedFriends.map((friend) {
                          final isWritable = notifier.getAccessLevel(friend.id) == 2;
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
                                  if (mounted) notifier.load(widget.entryId);
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
                              trailing: state.canManageShares
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
                                            onChanged: (bool value) => notifier.updateAccessLevel(friend, value ? 2 : 1),
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
                if (state.auditHint.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      state.auditHint,
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

        if (state.isBusy)
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
    // Busy-Check
    if (ref.read(detailProvider).isBusy) return;

    //final notifier = ref.read(detailProvider.notifier);

    // Aktuellen State holen
    final state = ref.read(detailProvider);
    
    Navigator.of(context).pop(state.hasChanged);
  }

  /// Öffnet die Bearbeitungsseite und aktualisiert die Daten bei Rückkehr, falls Änderungen vorgenommen wurden.
  Future<void> _handleEdit() async {
    // Busy-Check
    if (ref.read(detailProvider).isBusy) return;
    
    // Bearbeitungsseite aufrufen
    final hasChanged = await Navigator.of(context).pushNamed('/edit', arguments: widget.entryId);
    if (hasChanged != true || !mounted) return;

    // Daten haben sich geändert. Wir halten das im State fest, damit wir beim Zurücknavigieren 
    // der Hauptseite signalisieren können, dass die Liste neu geladen werden muss.
    final notifier = ref.read(detailProvider.notifier);
    notifier.markAsChanged();
    
    // Daten neu laden
    notifier.load(widget.entryId);
  }

  /// Speichert erst die Änderungen, wenn gewünscht und springt dann zurück.
  Future<void> _handleAddAttachment() async {
    // Busy-Check
    if (ref.read(detailProvider).isBusy) return;

    // Dateianhang hinzufügen
    final notifier = ref.read(detailProvider.notifier);
    final success = await notifier.addAttachment();
    if (!mounted) return;

    // Aktuellen State holen
    final state = ref.read(detailProvider);

    // Fehlerfall
    if (!success) {
      if (state.error.field == null) {
        Snack.show(context, state.error.text);
      }
      return;
    }

    // Erfolgsfall
    return; // ohne Meldung weiter machen
  }

  /// Fragt nach Bestätigung und löscht dann den Anhang.
  Future<void> _handleDeleteAttachment(dynamic attachment) async {
    // Busy-Check
    if (ref.read(detailProvider).isBusy) return;

    // Bestätigung fragen
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Anhang löschen',
      text: 'Möchtest du diesen Anhang wirklich löschen?',
      ok: 'Ja, löschen',
      autofocus: false,
    );
    if (confirmed != true || !mounted) return;
    
    // Dateianhang löschen
    final notifier = ref.read(detailProvider.notifier);
    final success = await notifier.deleteAttachment(attachment);
    if (!mounted) return;
    
    // Aktuellen State holen
    final state = ref.read(detailProvider);

    // Fehlerfall
    if (!success) {
      if (state.error.field == null) {
        Snack.show(context, state.error.text);
      }
      return;
    }

    // Erfolgsfall
    return; // ohne Meldung weiter machen
  }

  /// Öffnet einen Dialog zur Auswahl eines Kontakts aus Deiner Freundesliste,
  /// um diesen Eintrag mit ihm zu teilen.
  ///
  /// Es werden nur Kontakte angezeigt, die noch keinen Zugriff auf den Eintrag haben.
  Future<void> _handleAddFriend() async {
    // Busy-Check
    if (ref.read(detailProvider).isBusy) return;

    // Freund auswählen lassen 
    final notifier = ref.read(detailProvider.notifier);
    final user = await FriendSelectorDialog.show(context, notifier.getUnsharedFriends());
    if (user == null || !mounted) return;

    // Eintrag mit dem Freund teilen.
    final success = await notifier.shareWith(user);
    if (!mounted) return;

    // Aktuellen State holen
    final state = ref.read(detailProvider);

    // Fehlerfall
    if (!success) {
      if (state.error.field == null) {
        Snack.show(context, state.error.text);
      }
      return;
    }

    // Erfolgsfall
    return; // ohne Meldung weiter machen
  }

  /// Fragt nach Bestätigung und entzieht dann den Zugriff für den Benutzer.
  Future<void> _handleDeleteFriend(dynamic user) async {
    // Busy-Check
    if (ref.read(detailProvider).isBusy) return;

    // Bestätigen lassen
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Zugriff entziehen',
      text: 'Möchtest du diesen Eintrag nicht mehr mit der Person teilen?',
      ok: 'Ja, Zugriff entziehen',
    );
    if (confirmed != true || !mounted) return;

    // Freund löschen
    final notifier = ref.read(detailProvider.notifier);
    final success = await notifier.revokeAccess(user);
    if (!mounted) return;

    // Aktuellen State holen
    final state = ref.read(detailProvider);

    // Fehlerfall
    if (!success) {
      if (state.error.field == null) {
        Snack.show(context, state.error.text);
      }
      return;
    }

    // Erfolgsfall
    return; // ohne Meldung weiter machen
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
