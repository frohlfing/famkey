import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:famkey/features/report/report_notifier.dart';
import 'package:famkey/features/report/report_state.dart';
import 'package:famkey/widgets/confirm_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

/// Die [ReportPage] zeigt eine Sicherheitsanalyse des Tresors.
///
/// Sie prüft alle gespeicherten Passwörter gegen die HaveIBeenPwned-Datenbank
/// und zeigt außerdem Passwortstärken, Altersverteilung und älteste Passwörter an.
class ReportPage extends ConsumerStatefulWidget {

  /// Konstruktor
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {

  // ------------------------------------------------------------------------
  // --- Aufklapp-Zustand der Klapplisten ---
  // ------------------------------------------------------------------------

  bool _pwnedExpanded    = false;
  bool _urgentExpanded   = false;
  bool _weakestExpanded  = false;
  bool _oldestExpanded   = false;
  bool _unknownExpanded  = false;
  bool _excludedExpanded = false;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

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

  @override
  Widget build(BuildContext context) {

    ref.listen(reportProvider.select((s) => s.status), (previous, next) {
      switch (next) {
        case ReportActionStatus.aborted:
          Navigator.of(context).pop();
          break;
        default:
          break;
      }
    });

    final isBusy   = ref.watch(reportProvider.select((s) => s.isBusy));
    final status   = ref.watch(reportProvider.select((s) => s.status));
    final notifier = ref.read(reportProvider.notifier);
    final theme    = Theme.of(context);

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
        return const Center(child: Text('Bericht wird gestartet…'));

      case ReportActionStatus.loading:
        return _buildLoadingHint(theme);

      case ReportActionStatus.failure:
        return _buildError(theme);

      case ReportActionStatus.loaded:
        return _buildReport(context, theme);
    }
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPwnedSection(context, theme),
        const SizedBox(height: 48),
        _buildStrengthSection(context, theme),
        const SizedBox(height: 48),
        _buildAgeSection(context, theme),
        const SizedBox(height: 24),
        _buildExcludedSection(context, theme),
        const SizedBox(height: 32),
      ],
    );
  }

  // ------------------------------------------------------------------------
  // --- Abschnitt 1: Kompromittierte Passwörter ---
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
              title: 'Kompromittierte Passwörter',
              subtitle: 'Passwörter, die in bekannten Datenlecks aufgetaucht sind',
              subtitleColor: Colors.grey,
              theme: theme,
            ),
            const SizedBox(height: 10),
            Text(
              'Es wird geprüft, ob ein Passwort in einer öffentlich bekannten Datenbank '
              'geleakter Zugangsdaten vorkommt. Die Prüfung erfolgt anonym per '
              'k-Anonymitäts-Modell – das Passwort verlässt das Gerät niemals im Klartext.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 6),
            _buildHibpAttribution(theme),
            const SizedBox(height: 12),
            _buildCollapsibleHeader(
              theme: theme,
              icon: pwned.isEmpty ? Icons.check_circle_outline : Icons.lock_open,
              iconColor: pwned.isEmpty ? Colors.green : Colors.red,
              title: pwned.isEmpty
                  ? 'Kein Passwort in Leaks gefunden ✓'
                  : '${pwned.length} von $total Passwörtern kompromittiert!',
              subtitle: pwned.isEmpty
                  ? 'Alle geprüften Passwörter sind sicher'
                  : '${pwned.length} ${pwned.length == 1 ? 'Passwort sollte' : 'Passwörter sollten'} sofort geändert werden',
              subtitleColor: pwned.isEmpty ? Colors.green : Colors.red,
              isExpanded: _pwnedExpanded,
              onToggle: () => setState(() => _pwnedExpanded = !_pwnedExpanded),
            ),
            if (_pwnedExpanded) ...[
              const SizedBox(height: 12),
              if (pwned.isEmpty)
                _buildSuccessBanner(theme)
              else
                ...pwned.map((e) => _buildPwnedCard(e, theme)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHibpAttribution(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Datenquelle: ',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => launchUrl(Uri.parse('https://haveibeenpwned.com'), mode: LaunchMode.externalApplication),
                  child: Text(
                    'Have I Been Pwned',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              Text(
                ' von Troy Hunt.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
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
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green, fontWeight: FontWeight.w600),
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
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
            _buildExcludeButton(entry.id),
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
        final urgent          = ref.watch(reportProvider.select((s) => s.urgentPasswords));
        final weakest         = ref.watch(reportProvider.select((s) => s.weakestPasswords));
        final buckets         = ref.watch(reportProvider.select((s) => s.strengthBuckets));
        final noPasswordCount = ref.watch(reportProvider.select((s) => s.noPasswordCount));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.shield_outlined,
              iconColor: urgent.isEmpty ? Colors.green : Colors.red,
              title: 'Passwortstärke',
              subtitle: 'Geschätzte Zeit zum Knacken bei 10¹⁰ Versuchen/Sek. (GPU-Cracking)',
              subtitleColor: Colors.grey,
              theme: theme,
            ),
            const SizedBox(height: 12),
            if (buckets.isNotEmpty) _buildStrengthChart(buckets, theme),
            if (noPasswordCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '$noPasswordCount ${noPasswordCount == 1 ? 'Eintrag ohne Passwort wurde' : 'Einträge ohne Passwort wurden'} nicht ausgewertet.',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ),
            const SizedBox(height: 12),
            if (urgent.isNotEmpty) ...[
              _buildCollapsibleHeader(
                theme: theme,
                icon: Icons.lock_open,
                iconColor: Colors.red,
                title: 'Dringend ändern',
                subtitle: '${urgent.length} ${urgent.length == 1 ? 'Passwort' : 'Passwörter'} mit Score 0 (Sehr schwach) oder 1 (Schwach)',
                subtitleColor: Colors.red,
                isExpanded: _urgentExpanded,
                onToggle: () => setState(() => _urgentExpanded = !_urgentExpanded),
              ),
              if (_urgentExpanded) ...[
                const SizedBox(height: 8),
                ...urgent.map((e) => _buildUrgentCard(e, theme)),
              ],
              const SizedBox(height: 8),
            ],
            if (weakest.isNotEmpty) ...[
              _buildCollapsibleHeader(
                theme: theme,
                icon: Icons.format_list_numbered,
                iconColor: theme.colorScheme.primary,
                title: 'Top 10 der schwächsten Passwörter',
                subtitle: 'Die ${weakest.length} schwächsten Passwörter mit Score 2 (Mittel) oder besser',
                subtitleColor: Colors.grey,
                isExpanded: _weakestExpanded,
                onToggle: () => setState(() => _weakestExpanded = !_weakestExpanded),
              ),
              if (_weakestExpanded) ...[
                const SizedBox(height: 8),
                ...weakest.asMap().entries.map((e) => _buildWeakestCard(e.key + 1, e.value, theme)),
              ],
            ],
            if (urgent.isEmpty && weakest.isEmpty) ...[
              const SizedBox(height: 4),
              _buildSuccessBanner(theme),
            ],
          ],
        );
      },
    );
  }

  Widget _buildUrgentCard(ReportEntry entry, ThemeData theme) {
    final color = entry.strength == 0 ? const Color(0xFF991B1B) : const Color(0xFFDC2626);
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStrengthBadge(entry.strength, entry.crackTime, theme),
            _buildExcludeButton(entry.id),
          ],
        ),
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
          backgroundColor: _strengthColor(entry.strength),
          child: Text(
            '$rank',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          entry.username.isNotEmpty ? entry.username : 'Kein Benutzername',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStrengthBadge(entry.strength, entry.crackTime, theme),
            _buildExcludeButton(entry.id),
          ],
        ),
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
  // --- Abschnitt 3: Passwortalter ---
  // ------------------------------------------------------------------------

  Widget _buildAgeSection(BuildContext context, ThemeData theme) {
    return Consumer(
      builder: (ctx, ref, _) {
        final ageBuckets = ref.watch(reportProvider.select((s) => s.ageBuckets));
        final oldest     = ref.watch(reportProvider.select((s) => s.oldestPasswords));
        final unknown    = ref.watch(reportProvider.select((s) => s.unknownAgeEntries));
        final maxCount   = ageBuckets.isEmpty ? 1 : ageBuckets.map((b) => b.count).reduce((a, b) => a > b ? a : b);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.calendar_today_outlined,
              iconColor: theme.colorScheme.tertiary,
              title: 'Passwortalter',
              subtitle: 'Wie lange wurde ein Passwort nicht geändert?',
              subtitleColor: Colors.grey,
              theme: theme,
            ),
            const SizedBox(height: 12),
            if (ageBuckets.isEmpty)
              Text('Keine Daten vorhanden.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey))
            else
              _buildBarChart(ageBuckets, maxCount, theme),
            const SizedBox(height: 12),
            _buildCollapsibleHeader(
              theme: theme,
              icon: Icons.history,
              iconColor: theme.colorScheme.primary,
              title: 'Top 10 der ältesten Passwörter',
              subtitle: 'Passwörter, die am längsten nicht geändert wurden',
              subtitleColor: Colors.grey,
              isExpanded: _oldestExpanded,
              onToggle: () => setState(() => _oldestExpanded = !_oldestExpanded),
            ),
            if (_oldestExpanded) ...[
              const SizedBox(height: 12),
              if (oldest.isEmpty)
                Text('Keine Einträge vorhanden.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey))
              else
                ...oldest.asMap().entries.map((e) => _buildOldestCard(e.key + 1, e.value, theme)),
            ],
            if (unknown.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildCollapsibleHeader(
                theme: theme,
                icon: Icons.help_outline,
                iconColor: Colors.grey,
                title: 'Unbekanntes Passwortalter',
                subtitle: '${unknown.length} ${unknown.length == 1 ? 'Eintrag' : 'Einträge'} ohne Datum der letzten Passwortänderung',
                subtitleColor: Colors.grey,
                isExpanded: _unknownExpanded,
                onToggle: () => setState(() => _unknownExpanded = !_unknownExpanded),
              ),
              if (_unknownExpanded) ...[
                const SizedBox(height: 12),
                ...unknown.take(10).map((e) => _buildUnknownAgeCard(e, theme)),
                if (unknown.length > 10)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      '… und ${unknown.length - 10} weitere',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ),
              ],
            ],
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
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
            _buildExcludeButton(entry.id),
          ],
        ),
        onTap: () => _openDetail(entry.id),
      ),
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
        trailing: _buildExcludeButton(entry.id),
        onTap: () => _openDetail(entry.id),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // --- Abschnitt 4: Ausgeschlossene Einträge ---
  // ------------------------------------------------------------------------

  Widget _buildExcludedSection(BuildContext context, ThemeData theme) {
    return Consumer(
      builder: (ctx, ref, _) {
        final excluded = ref.watch(reportProvider.select((s) => s.excludedEntries));
        if (excluded.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _excludedExpanded = !_excludedExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.disabled_visible_outlined, size: 15, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(
                        'Ausgeschlossene Einträge (${excluded.length})',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _excludedExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 15,
                        color: Colors.grey[500],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_excludedExpanded) ...[
              const SizedBox(height: 8),
              ...excluded.map((e) => _buildExcludedCard(e, theme)),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildExcludedCard(ReportEntry entry, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.disabled_visible_outlined, color: Colors.grey[400], size: 20),
        title: Text(entry.title, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
        subtitle: entry.username.isNotEmpty
            ? Text(entry.username, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.undo),
          iconSize: 18,
          color: Colors.grey[500],
          tooltip: 'Wieder in den Bericht aufnehmen',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          onPressed: () => ref.read(reportProvider.notifier).toggleReportExcluded(entry.id),
        ),
        onTap: () => _openDetail(entry.id),
      ),
    );
  }

  Widget _buildBarChart(List<AgeBucket> buckets, int maxCount, ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          children: [
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

  /// Schaltfläche zum Ausschließen eines Eintrags aus dem Bericht.
  Widget _buildExcludeButton(int entryId) {
    return IconButton(
      icon: const Icon(Icons.do_not_disturb_on_outlined),
      iconSize: 20,
      color: Colors.grey[400],
      tooltip: 'Vom Bericht ausschließen',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      onPressed: () => ref.read(reportProvider.notifier).toggleReportExcluded(entryId),
    );
  }

  /// Aufklappbarer Abschnitts-Header im Stil der Hauptliste.
  Widget _buildCollapsibleHeader({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color subtitleColor,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 12)),
        trailing: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
        onTap: onToggle,
      ),
    );
  }

  /// Statischer Abschnitts-Header (nicht aufklappbar).
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
              Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: subtitleColor)),
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
