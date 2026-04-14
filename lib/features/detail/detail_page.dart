import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_file_factory.dart';
import 'package:privault/core/helper.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/detail/detail_notifier.dart';
import 'package:privault/features/detail/detail_state.dart';
import 'package:privault/widgets/confirm_dialog.dart';
import 'package:privault/features/detail/friend_dialog.dart';
import 'package:privault/widgets/password_strength_bar.dart';
import 'package:privault/widgets/snack.dart';

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
  var _obscurePassword = true;

  /// Gibt an, ob der Eintrag durch die Bearbeitungsseite geändert wurde.
  var _hasChanged = false;

  /// Lokaler Guard, um mehrfaches Öffnen des Pickers zu verhindern
  var _isPickingFile = false;

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

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  /// Baut die zentrale Detailansicht eines Eintrags auf.
  @override
  Widget build(BuildContext context) {
    // Listener für Status-Änderungen
    ref.listen(detailProvider.select((s) => s.status), (previous, next) {
      switch (next) {
        case DetailActionStatus.attachmentAdded:
          Snack.show(context, 'Anhang hinzugefügt', success: true);
          break;

        case DetailActionStatus.attachmentDeleted:
          Snack.show(context, 'Anhang gelöscht', success: true);
          break;

        case DetailActionStatus.shareUpdated:
          Snack.show(context, 'Zugriffsrecht für Freund aktualisiert', success: true);
          break;

        case DetailActionStatus.accessRevoked:
          Snack.show(context, 'Zugriffsrecht für Freund entzogen', success: true);
          break;

        case DetailActionStatus.failure:
          final state = ref.read(detailProvider);
          if (state.error.field == null) {
            // Nur allgemeine Fehler anzeigen
            Snack.show(context, state.error.text);
          }
          break;

        default:
          break;
      }
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(detailProvider.select((s) => s.isBusy));
    final canEdit = ref.watch(detailProvider.select((s) => s.canEdit));

    // Notifier holen
    final notifier = ref.read(detailProvider.notifier);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Details'),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => isBusy ? null : Navigator.of(context).pop(_hasChanged),
              tooltip: "Zurück",
            ),
            actions: [
              if (canEdit) // Bearbeiten-Button ausblenden, wenn nur Leserecht
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Bearbeiten',
                  onPressed: isBusy ? null : _handleEdit,
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

                Consumer(
                  builder: (ctx, ref, _) {
                    final favicon = ref.watch(detailProvider.select((s) => s.favicon));
                    final title = ref.watch(detailProvider.select((s) => s.title));
                    final category = ref.watch(detailProvider.select((s) => s.category));
                    return Center(
                      child: Column(
                        children: [
                          if (favicon.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Image.memory(base64Decode(favicon), width: 64, height: 64),
                              //child: Image.memory(base64Decode(favicon), width: 64, height: 64, errorBuilder: (ctx, err, stack) => const Icon(Icons.lock_outlined)),
                            ),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            category,
                            style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // ------------------------------------------------------------------------
                // Stammdaten
                // ------------------------------------------------------------------------

                // --- Benutzername ---
                Consumer(
                  builder: (ctx, ref, _) {
                    final username = ref.watch(detailProvider.select((s) => s.username));
                    //if (username.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: [
                        ListTile(
                          title: const Text('Benutzername'),
                          subtitle: Text(username),
                          trailing: username.isNotEmpty ? IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () => _handleCopyToClipboard(username, 'Benutzername'),
                            tooltip: 'Benutzername kopieren',
                          ) : null,
                        ),
                        const Divider(),
                      ],
                    );
                  },
                ),

                // --- Passwort ---
                Consumer(
                  builder: (ctx, ref, _) {
                    final password = ref.watch(detailProvider.select((s) => s.password));
                    final passwordStrength = ref.watch(detailProvider.select((s) => s.passwordStrength));
                    final passwordHint = ref.watch(detailProvider.select((s) => s.passwordHint));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          title: const Text('Passwort'),
                          subtitle: Text(password.isNotEmpty && _obscurePassword ? '••••••••' : password),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: password.isNotEmpty ? [
                              IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                tooltip: _obscurePassword ? 'Passwort anzeigen' : 'Passwort verbergen',
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () => _handleCopyToClipboard(password, 'Passwort'),
                                tooltip: 'Passwort kopieren',
                              ),
                            ] : [],
                          ),
                        ),
                        if (password.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: PasswordStrengthBar(score: passwordStrength),
                          ),
                        if (password.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              passwordHint,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                            ),
                          ),
                        const Divider(),
                      ],
                    );
                  },
                ),

                // --- URL ---
                Consumer(
                  builder: (ctx, ref, _) {
                    final url = ref.watch(detailProvider.select((s) => s.url));
                    //if (url.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: [
                        ListTile(
                          title: const Text('URL'),
                          subtitle: Text(url),
                          trailing: url.isNotEmpty ? IconButton(
                            icon: const Icon(Icons.open_in_new),
                            onPressed: notifier.openUrl,
                            tooltip: 'URL öffnen',
                          ) : null,
                        ),
                        const Divider(),
                      ],
                    );
                  },
                ),

                // --- Notizen ---
                Consumer(
                  builder: (ctx, ref, _) {
                    final notes = ref.watch(detailProvider.select((s) => s.notes));
                    if (notes.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: [
                        ListTile(
                          title: const Text('Notizen'),
                          subtitle: Text(notes),
                        ),
                        const Divider(),
                      ],
                    );
                  },
                ),

                // ------------------------------------------------------------------------
                // Anhänge
                // ------------------------------------------------------------------------
                Consumer(
                  builder: (ctx, ref, _) {
                    final canManageAttachments = ref.watch(detailProvider.select((s) => s.canManageAttachments));
                    final attachments = ref.watch(detailProvider.select((s) => s.attachments));
                    if (!canManageAttachments && attachments.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (canManageAttachments)
                          _buildSectionHeaderWithAction(
                            'Anhänge',
                            _isPickingFile ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_circle_outline),
                            'Datei anhängen',
                            isBusy || _isPickingFile ? null : _handleAddAttachment,
                          )
                        else
                          _buildSectionTitle('Anhänge'),
                        const SizedBox(height: 4),
                        if (attachments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 0, bottom: 8, left: 16, right: 16),
                            child: Text('Keine Anhänge vorhanden.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                          )
                        else
                          ...attachments.map((attachment) {
                            final iconType = getIconType(attachment.meta.filename, attachment.meta.mime);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => notifier.openAttachment(attachment.attachment, attachment.meta.filename),
                                    child: attachment.meta.thumbnail != null && attachment.meta.thumbnail!.isNotEmpty ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.memory(base64Decode(attachment.meta.thumbnail!), width: 48, height: 48, fit: BoxFit.cover),
                                    ) : Icon(getIconForType(iconType), size: 48, color: Colors.blueGrey),
                                  ),
                                ),
                                title: Text(attachment.meta.filename),
                                subtitle: Text(formatSize(attachment.meta.size)),
                                trailing: canManageAttachments ? IconButton(
                                  icon: const Icon(Icons.delete),
                                  tooltip: 'Anhang löschen',
                                  onPressed: () => _handleDeleteAttachment(attachment.attachment),
                                ) : null,
                              ),
                            );
                          }),
                        const Divider(),
                      ],
                    );
                  },
                ),

                // ------------------------------------------------------------------------
                // Geteilt mit
                // ------------------------------------------------------------------------
                Consumer(
                  builder: (ctx, ref, _) {
                    final canManageShares = ref.watch(detailProvider.select((s) => s.canManageShares));
                    final sharedFriends = ref.watch(detailProvider.select((s) => s.sharedFriends));
                    if (!canManageShares && sharedFriends.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (canManageShares)
                          _buildSectionHeaderWithAction(
                            'Geteilt mit',
                            const Icon(Icons.person_add_alt_1_outlined),
                            'Freigabe hinzufügen',
                            _handleAddFriend,
                          )
                        else
                          _buildSectionTitle('Geteilt mit'),
                        const SizedBox(height: 4),
                        if (sharedFriends.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 0, bottom: 8, left: 16, right: 16),
                            child: Text('Dieser Eintrag ist noch nicht geteilt.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                          )
                        else
                          ...sharedFriends.map((friend) {
                            final isWritable = friend.accessLevel == 2;
                            Widget leadingIcon = Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                const Icon(Icons.person_outline, size: 40, color: Colors.blueGrey),
                                if (!friend.user.isVerified) const Icon(Icons.warning, size: 18, color: Colors.amber),
                              ],
                            );

                            if (!friend.user.isVerified) {
                              leadingIcon = MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () async {
                                    await Navigator.pushNamed(ctx, '/settings', arguments: {'focus_user_uuid': friend.user.uuid});
                                    if (mounted) notifier.load(widget.entryId);
                                  },
                                  child: Tooltip(message: 'Person ist nicht verifiziert!', child: leadingIcon),
                                ),
                              );
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: leadingIcon,
                                title: Text(friend.user.name),
                                trailing: canManageShares ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Schreibrechte', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Transform.scale(
                                      scale: 0.75,
                                      child: Switch(
                                        value: isWritable,
                                        onChanged: (bool value) => notifier.updateAccessLevel(friend.user, value ? 2 : 1),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      tooltip: 'Zugriff entziehen',
                                      onPressed: () => _handleDeleteFriend(friend.user),
                                    ),
                                  ],
                                ) : (isWritable
                                    ? const Text('Schreibrechte', style: TextStyle(color: Colors.grey))
                                    : const Text('Nur Leserechte', style: TextStyle(color: Colors.grey))
                                  ),
                              ),
                            );
                          }),
                        const Divider(),
                      ],
                    );
                  },
                ),

                // --- Audit-Hinweis ---
                Consumer(
                  builder: (ctx, ref, _) {
                    final auditHint = ref.watch(detailProvider.select((s) => s.auditHint));
                    if (auditHint.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(auditHint, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                    );
                  },
                ),

                // --- Abstand zum unteren Rand ---
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),

        if (isBusy)
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
  Widget _buildSectionHeaderWithAction(String title, Widget icon, String tooltip, VoidCallback? onPressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionTitle(title),
        Padding(
          padding: EdgeInsets.only(top: 0, bottom: 0, left: 0, right: 24),
          child: IconButton(icon: icon, tooltip: tooltip, onPressed: onPressed),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  /// Öffnet die Bearbeitungsseite und aktualisiert die Daten bei Rückkehr, falls Änderungen vorgenommen wurden.
  Future<void> _handleEdit() async {
    final hasChanged = await Navigator.of(context).pushNamed('/edit', arguments: widget.entryId);
    if (hasChanged == true) {
      // hat die Edit-Seite "true" zurückgegeben?
      _hasChanged = true;
      if (mounted) {
        final notifier = ref.read(detailProvider.notifier);
        notifier.load(widget.entryId);
      }
    }
  }

  /// Kopiert den Text in die Zwischenablage und gibt eine SnackBar mit dem Ergebnis aus.
  /// `label` ist die Beschriftung des kopierten Textes.
  void _handleCopyToClipboard(String text, String label) {
    final notifier = ref.read(detailProvider.notifier);
    notifier.copyToClipboard(text);
    Snack.show(context, '$label in die Zwischenablage kopiert', success: true);
  }

  /// Fügt einen Dateianhang hinzu.
  Future<void> _handleAddAttachment() async {
    if (_isPickingFile) return;
    setState(() => _isPickingFile = true); // Mit setState wird erst die anonymen Funktion aufgerufen, danach wird das Widget als "dirty" markiert (wodurch im nächsten Frame die build-Methode neu rendert)
    try {
      // Datei auswählen
      final picker = createAppFilePicker();
      final files = await picker.pickFiles();
      if (!mounted || files.isEmpty) return;

      // Datei an den Notifier übergeben
      final notifier = ref.read(detailProvider.notifier);
      notifier.addAttachment(files.first);
    }
    finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  /// Fragt nach Bestätigung und löscht dann den Anhang.
  Future<void> _handleDeleteAttachment(AttachmentEntity attachment) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Anhang löschen',
      text: 'Möchtest du diesen Anhang wirklich löschen?',
      ok: 'Ja, löschen',
      autofocus: false,
    );
    if (mounted && confirmed == true) {
      final notifier = ref.read(detailProvider.notifier);
      notifier.deleteAttachment(attachment);
    }
  }

  /// Öffnet einen Dialog zur Auswahl eines Kontakts aus Deiner Freundesliste,
  /// um diesen Eintrag mit ihm zu teilen.
  ///
  /// Es werden nur Kontakte angezeigt, die noch keinen Zugriff auf den Eintrag haben.
  Future<void> _handleAddFriend() async {
    final state = ref.read(detailProvider);
    final user = await FriendDialog.show(context, state.unsharedFriends);
    if (mounted && user != null) {
      final notifier = ref.read(detailProvider.notifier);
      notifier.shareWith(user);
    }
  }

  /// Fragt nach Bestätigung und entzieht dann den Zugriff für den Benutzer.
  Future<void> _handleDeleteFriend(UserEntity user) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Zugriff entziehen',
      text: 'Möchtest du diesen Eintrag nicht mehr mit der Person teilen?',
      ok: 'Ja, Zugriff entziehen',
    );
    if (mounted && confirmed == true) {
      final notifier = ref.read(detailProvider.notifier);
      notifier.revokeAccess(user);
    }
  }
}
