import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:privault/features/report/report_notifier.dart';
import 'package:privault/features/report/report_state.dart';
import 'package:privault/widgets/confirm_dialog.dart';

/// Die [ReportPage] zeigt eine Sicherheitsanalyse des Tresors.
///
/// Sie prüft alle gespeicherten Passwörter gegen die HaveIBeenPwned-Datenbank
/// und zeigt außerdem die ältesten Passwörter, Einträge ohne bekanntes Passwort-Datum
/// sowie eine Altersverteilung als Balkendiagramm an.
class ReportPage extends ConsumerStatefulWidget {

  /// Konstruktor
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert die Seite und startet die Analyse, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(reportProvider.notifier);
      await notifier.load();
    });
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  /// Rendert die Seite (getriggert durch Änderungen im State)
  @override
  Widget build(BuildContext context) {

    // Listener für Status-Änderungen
    ref.listen(reportProvider.select((s) => s.status), (previous, next) {
      switch (next) {
        case ReportActionStatus.aborted:
          Navigator.of(context).pop();
          break;
        default:
          break;
      }
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(reportProvider.select((s) => s.isBusy));
    final status = ref.watch(reportProvider.select((s) => s.status));

    // Notifier holen
    final notifier = ref.read(reportProvider.notifier);

    final theme = Theme.of(context);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Sicherheitsbericht'),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: isBusy ? null : () => Navigator.of(context).pop(),
              tooltip: 'Zurück',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Neu laden',
                onPressed: isBusy ? null : notifier.load,
              ),
            ],
          ),
          body: _buildBody(context, status, theme),
        ),

        // // Lade-Overlay (IgnorePointer: Touches sollen den Abbrechen-Button darunter erreichen)
        // if (isBusy)
        //   IgnorePointer(
        //     child: Container(
        //       color: Colors.black.withValues(alpha: 0.1),
        //     ),
        //   ),
      ],
    );
  }

  // ------------------------------------------------------------------------
  // --- Body ---
  // ------------------------------------------------------------------------

  Widget _buildBody(BuildContext context, ReportActionStatus status, ThemeData theme) {
    switch (status) {
      case ReportActionStatus.idle:
      case ReportActionStatus.aborted:
        return _buildEmptyHint(theme);

      case ReportActionStatus.loading:
        return _buildLoadingHint(theme);

      case ReportActionStatus.failure:
        return _buildError(theme);

      case ReportActionStatus.loaded:
        return _buildReport(context, theme);
    }
  }

  Widget _buildEmptyHint(ThemeData theme) {
    return const Center(
      child: Text('Bericht wird gestartet…'),
    );
  }

  Widget _buildLoadingHint(ThemeData theme) {
    return Consumer(
      builder: (ctx, ref, _) {
        final total   = ref.watch(reportProvider.select((s) => s.totalCount));
        final checked = ref.watch(reportProvider.select((s) => s.checkedCount));
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security, size: 48, color: Colors.blueGrey),
                const SizedBox(height: 24),
                Text('Passwörter werden geprüft…', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '$checked von $total',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: total > 0 ? checked / total : null),
                const SizedBox(height: 8),
                Text(
                  'Die HIBP-API wird für jeden Eintrag\neinzeln und anonym abgefragt.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 24),

                // Abbrechen-Button
                ElevatedButton.icon(
                  onPressed: _handleAbortLoading,
                  icon: const Icon(Icons.stop),
                  label: const Text('Abbrechen'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildError(ThemeData theme) {
    final error = ref.read(reportProvider).error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(error.text, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
              onPressed: () => ref.read(reportProvider.notifier).load(),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // --- Fertiger Bericht ---
  // ------------------------------------------------------------------------

  Widget _buildReport(BuildContext context, ThemeData theme) {
    final hasUnknown = ref.watch(reportProvider.select((s) => s.unknownAgeEntries.isNotEmpty));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPwnedSection(context, theme),
        const SizedBox(height: 24),
        _buildStrengthSection(context, theme),
        const SizedBox(height: 24),
        _buildOldestSection(context, theme),
        if (hasUnknown) ...[
          const SizedBox(height: 24),
          _buildUnknownAgeSection(context, theme),
        ],
        const SizedBox(height: 24),
        _buildAgeChartSection(context, theme),
        const SizedBox(height: 32),
      ],
    );
  }

  // ------------------------------------------------------------------------
  // --- Abschnitt 1: HIBP-Treffer ---
  // ------------------------------------------------------------------------

  Widget _buildPwnedSection(BuildContext context, ThemeData theme) {
    return Consumer(
      builder: (ctx, ref, _) {
        final pwned = ref.watch(reportProvider.select((s) => s.pwnedEntries));
        final total = ref.watch(reportProvider.select((s) => s.totalCount));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.warning_amber_rounded,
              iconColor: pwned.isEmpty ? Colors.green : Colors.red,
              title: 'Darknet-Check (HaveIBeenPwned)',
              subtitle: pwned.isEmpty
                  ? 'Kein Passwort in bekannten Leaks gefunden ✓'
                  : '${pwned.length} von $total Passwörtern sind kompromittiert!',
              subtitleColor: pwned.isEmpty ? Colors.green : Colors.red,
              theme: theme,
            ),
            const SizedBox(height: 12),
            if (pwned.isEmpty)
              _buildSuccessBanner(theme)
            else
              ...pwned.map((e) => _buildPwnedCard(e, theme)),
            const SizedBox(height: 8),
            Text(
              'Die Prüfung erfolgt anonym per k-Anonymitäts-Modell (SHA-1-Präfix).\n'
              'Das Passwort verlässt das Gerät dabei niemals im Klartext.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSuccessBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Alle geprüften Passwörter sind sicher!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPwnedCard(ReportEntry entry, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(Icons.lock_open, color: Colors.white, size: 20),
        ),
        title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          entry.username.isNotEmpty ? entry.username : 'Kein Benutzername',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              entry.pwnedCount > 0 ? '${_formatCount(entry.pwnedCount)}×' : '?',
              style: theme.textTheme.titleSmall?.copyWith(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            Text('gefunden', style: theme.textTheme.bodySmall?.copyWith(color: Colors.red)),
          ],
        ),
        onTap: () => _openDetail(entry.id),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // --- Abschnitt 2: Passwortstärke ---
  // ------------------------------------------------------------------------

  Widget _buildStrengthSection(BuildContext context, ThemeData theme) {
    return Consumer(
      builder: (ctx, ref, _) {
        final urgent         = ref.watch(reportProvider.select((s) => s.urgentPasswords));
        final weakest        = ref.watch(reportProvider.select((s) => s.weakestPasswords));
        final buckets        = ref.watch(reportProvider.select((s) => s.strengthBuckets));
        final noPasswordCount = ref.watch(reportProvider.select((s) => s.noPasswordCount));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.shield_outlined,
              iconColor: urgent.isEmpty ? Colors.green : Colors.red,
              title: 'Passwortstärke',
              subtitle: urgent.isEmpty
                  ? 'Keine kritisch schwachen Passwörter ✓'
                  : '${urgent.length} ${urgent.length == 1 ? 'Passwort sollte' : 'Passwörter sollten'} dringend geändert werden!',
              subtitleColor: urgent.isEmpty ? Colors.green : Colors.red,
              theme: theme,
            ),
            const SizedBox(height: 12),

            // Stärkeverteilung
            if (buckets.isNotEmpty) ...[
              _buildStrengthChart(buckets, theme),
              const SizedBox(height: 8),
            ],

            // Hinweis auf ignorierte Einträge
            if (noPasswordCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '$noPasswordCount ${noPasswordCount == 1 ? 'Eintrag ohne Passwort wurde' : 'Einträge ohne Passwort wurden'} nicht ausgewertet.',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ),

            // Dringend ändern (Score 0+1)
            if (urgent.isEmpty)
              _buildSuccessBanner(theme)
            else ...[
              const SizedBox(height: 8),
              Text('Geschätzte Crack-Zeit', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
              const SizedBox(height: 4),
              _buildCollapsibleList(
                context: context,
                theme: theme,
                title: 'Dringend ändern',
                titleColor: Colors.red,
                initiallyExpanded: true,
                children: urgent.map((e) => _buildUrgentCard(e, theme)).toList(),
              ),
            ],

            // Top 10 schwächste (Score 2+3)
            if (weakest.isNotEmpty) ...[
              if (urgent.isEmpty) ...[
                const SizedBox(height: 8),
                Text('Geschätzte Crack-Zeit', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 4),
              ],
              _buildCollapsibleList(
                context: context,
                theme: theme,
                title: 'Top 10 schwächste',
                titleColor: theme.colorScheme.primary,
                initiallyExpanded: true,
                children: weakest.asMap().entries.map((e) => _buildWeakestCard(e.key + 1, e.value, theme)).toList(),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCollapsibleList({
    required BuildContext context,
    required ThemeData theme,
    required String title,
    required Color titleColor,
    required bool initiallyExpanded,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: initiallyExpanded,
        title: Text(title, style: theme.textTheme.labelLarge?.copyWith(color: titleColor, fontWeight: FontWeight.bold)),
        iconColor: titleColor,
        collapsedIconColor: titleColor,
        children: children,
      ),
    );
  }

  Widget _buildUrgentCard(ReportEntry entry, ThemeData theme) {
    final color = entry.strength == 0 ? Colors.red : Colors.orange;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: const Icon(Icons.lock_open, color: Colors.white, size: 20),
        ),
        title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          entry.username.isNotEmpty ? entry.username : 'Kein Benutzername',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _buildStrengthBadge(entry.strength, entry.crackTime, theme),
        onTap: () => _openDetail(entry.id),
      ),
    );
  }

  Widget _buildWeakestCard(int rank, ReportEntry entry, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            '$rank',
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
        title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          entry.username.isNotEmpty ? entry.username : 'Kein Benutzername',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _buildStrengthBadge(entry.strength, entry.crackTime, theme),
        onTap: () => _openDetail(entry.id),
      ),
    );
  }

  Widget _buildStrengthBadge(int score, String crackTime, ThemeData theme) {
    return Text(
      crackTime.isNotEmpty ? crackTime : '–',
      style: theme.textTheme.bodySmall?.copyWith(color: _strengthColor(score), fontWeight: FontWeight.bold),
    );
  }

  Widget _buildStrengthChart(List<StrengthBucket> buckets, ThemeData theme) {
    final maxCount = buckets.isEmpty ? 1 : buckets.map((b) => b.count).reduce((a, b) => a > b ? a : b);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          children: [
            // --- Balken ---
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: buckets.map((bucket) {
                  final relHeight = maxCount > 0 ? bucket.count / maxCount : 0.0;
                  final barColor  = _strengthColor(bucket.score);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (bucket.count > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${bucket.count}',
                                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: barColor),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            const SizedBox(height: 18),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            height: relHeight > 0 ? relHeight * 120 : 4,
                            decoration: BoxDecoration(
                              color: bucket.count > 0 ? barColor : barColor.withValues(alpha: 0.2),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // --- Beschriftungen ---
            Row(
              children: buckets.map((bucket) {
                return Expanded(
                  child: Text(
                    bucket.label,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600], fontSize: 10),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // --- Abschnitt 3: Älteste Passwörter ---
  // ------------------------------------------------------------------------

  Widget _buildOldestSection(BuildContext context, ThemeData theme) {
    return Consumer(
      builder: (ctx, ref, _) {
        final oldest = ref.watch(reportProvider.select((s) => s.oldestPasswords));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.history,
              iconColor: theme.colorScheme.primary,
              title: 'Top 10 – Älteste Passwörter',
              subtitle: 'Passwörter, die am längsten nicht geändert wurden',
              subtitleColor: Colors.grey,
              theme: theme,
            ),
            const SizedBox(height: 12),
            if (oldest.isEmpty)
              Text('Keine Einträge vorhanden.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey))
            else
              ...oldest.asMap().entries.map((e) => _buildOldestCard(e.key + 1, e.value, theme)),
          ],
        );
      },
    );
  }

  Widget _buildOldestCard(int rank, ReportEntry entry, ThemeData theme) {
    final dateStr  = DateFormat('dd.MM.yyyy').format(entry.passwordTimestamp!.toLocal());
    final days     = DateTime.now().difference(entry.passwordTimestamp!).inDays;
    final ageColor = _ageColor(days);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            '$rank',
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
        title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('Geändert: $dateStr', style: theme.textTheme.bodySmall),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: ageColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ageColor.withValues(alpha: 0.5)),
          ),
          child: Text(
            _formatAge(days),
            style: theme.textTheme.bodySmall?.copyWith(color: ageColor, fontWeight: FontWeight.w600),
          ),
        ),
        onTap: () => _openDetail(entry.id),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // --- Abschnitt 4: Unbekanntes Passwort-Alter ---
  // ------------------------------------------------------------------------

  Widget _buildUnknownAgeSection(BuildContext context, ThemeData theme) {
    return Consumer(
      builder: (ctx, ref, _) {
        final entries = ref.watch(reportProvider.select((s) => s.unknownAgeEntries));
        final shown   = entries.take(10).toList();
        final rest    = entries.length - shown.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.help_outline,
              iconColor: Colors.grey,
              title: 'Unbekanntes Passwort-Alter',
              subtitle: '${entries.length} ${entries.length == 1 ? 'Eintrag' : 'Einträge'} ohne Datum der letzten Passwortänderung',
              subtitleColor: Colors.grey,
              theme: theme,
            ),
            const SizedBox(height: 12),
            ...shown.map((e) => _buildUnknownAgeCard(e, theme)),
            if (rest > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  '… und $rest weitere',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildUnknownAgeCard(ReportEntry entry, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.grey,
          child: Icon(Icons.help_outline, color: Colors.white, size: 20),
        ),
        title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          entry.username.isNotEmpty ? entry.username : 'Kein Benutzername',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _openDetail(entry.id),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // --- Abschnitt 5: Balkendiagramm Altersverteilung ---
  // ------------------------------------------------------------------------

  Widget _buildAgeChartSection(BuildContext context, ThemeData theme) {
    return Consumer(
      builder: (ctx, ref, _) {
        final buckets  = ref.watch(reportProvider.select((s) => s.ageBuckets));
        final maxCount = buckets.isEmpty ? 1 : buckets.map((b) => b.count).reduce((a, b) => a > b ? a : b);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.bar_chart,
              iconColor: theme.colorScheme.tertiary,
              title: 'Passwort-Altersverteilung',
              subtitle: 'Wie lange wurde ein Passwort nicht geändert?',
              subtitleColor: Colors.grey,
              theme: theme,
            ),
            const SizedBox(height: 16),
            if (buckets.isEmpty)
              Text('Keine Daten vorhanden.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey))
            else
              _buildBarChart(buckets, maxCount, theme),
          ],
        );
      },
    );
  }

  Widget _buildBarChart(List<AgeBucket> buckets, int maxCount, ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          children: [
            // --- Balken ---
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: buckets.map((bucket) {
                  final relHeight = maxCount > 0 ? bucket.count / maxCount : 0.0;
                  final barColor  = _bucketColor(bucket, theme);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Anzahl über dem Balken
                          if (bucket.count > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${bucket.count}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: barColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            const SizedBox(height: 18),

                          // Balken
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            height: relHeight > 0 ? relHeight * 120 : 4,
                            decoration: BoxDecoration(
                              color: bucket.count > 0 ? barColor : barColor.withValues(alpha: 0.2),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // --- Beschriftungen ---
            Row(
              children: buckets.map((bucket) {
                return Expanded(
                  child: Text(
                    bucket.label,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600], fontSize: 10),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  /// Öffnet die Detailseite und prüft den Eintrag nach der Rückkehr erneut.
  Future<void> _openDetail(int entryId) async {
    await Navigator.of(context).pushNamed('/detail', arguments: entryId);
    if (mounted) {
      ref.read(reportProvider.notifier).recheckEntry(entryId);
    }
  }

  /// Bricht nach einer Rückfrage die laufende Analyse ab.
  Future<void> _handleAbortLoading() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Analyse abbrechen',
      text: 'Möchtest du die Sicherheitsanalyse wirklich abbrechen?',
      cancel: 'Nein, fortfahren',
      ok: 'Ja, abbrechen',
      autofocus: false,
    );
    if (mounted && confirmed == true) {
      ref.read(reportProvider.notifier).abortLoading();
    }
  }

  // ------------------------------------------------------------------------
  // --- Hilfsmethoden ---
  // ------------------------------------------------------------------------

  Widget _buildSectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color subtitleColor,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: subtitleColor)),
            ],
          ),
        ),
      ],
    );
  }

  /// Farbe passend zur Passwortstärke (Score 0–4).
  /// Farben identisch mit [PasswordStrengthBar]; Score 0 etwas dunkler da noch schlechter als Score 1.
  Color _strengthColor(int score) {
    switch (score) {
      case 1:  return const Color(0xFFDC2626);
      case 2:  return const Color(0xFFF59E0B);
      case 3:  return const Color(0xFF84CC16);
      case 4:  return const Color(0xFF16A34A);
      default: return const Color(0xFF991B1B); // score 0
    }
  }

  /// Farbe passend zum Passwort-Alter (grün = frisch, rot = alt)
  Color _ageColor(int days) {
    if (days < 90)  return Colors.green;
    if (days < 180) return Colors.orange;
    if (days < 365) return Colors.deepOrange;
    return Colors.red;
  }

  /// Farbe für einen Alters-Bucket im Balkendiagramm
  Color _bucketColor(AgeBucket bucket, ThemeData theme) {
    if (bucket.daysMin < 0)   return Colors.grey;
    if (bucket.daysMin < 30)  return Colors.green;
    if (bucket.daysMin < 90)  return Colors.lightGreen;
    if (bucket.daysMin < 180) return Colors.orange;
    if (bucket.daysMin < 365) return Colors.deepOrange;
    return Colors.red;
  }

  /// Alterstext für eine Anzahl Tage
  String _formatAge(int days) {
    if (days < 1)   return 'heute';
    if (days < 30)  return '${days}d';
    if (days < 365) return '${(days / 30).round()}M';
    final years  = days ~/ 365;
    final months = (days % 365) ~/ 30;
    return months > 0 ? '${years}J ${months}M' : '${years}J';
  }

  /// Formatiert eine große Zahl leserlich (z.B. 3.500.000 → "3,5 Mio.")
  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)} Mio.';
    if (count >= 1000)    return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }
}
