<?php

/**
 * Coverage-Report-Generator
 *
 * Dieses Skript generiert einen interaktiven HTML-Report aus den gesammelten Code-Coverage-Daten.
 *
 * Funktionsweise:
 * - Lädt Coverage-Daten aus coverage/data.json (erstellt von CoverageMiddleware)
 * - Analysiert PHP-Dateien mittels Token-Parsing, um Funktionen/Methoden zu identifizieren
 * - Berechnet Coverage-Statistiken pro Funktion und Datei (exklusive globaler Scope)
 * - Berücksichtigt ignorierte Methoden gemäß COVERAGE_IGNORE-Konfiguration
 * - Rendert einen hierarchischen, aufklappbaren Report mit Farbcodierung:
 *   * Grün: >= 80% Coverage
 *   * Gelb: 50-79% Coverage
 *   * Rot: < 50% Coverage
 * - Zeigt Quellcode mit Zeilennummern und Hit-Counts für jede Funktion
 */

/**
 * Pfad zur Coverage-Datendatei.
 */
$dataFile = __DIR__ . '/../../coverage/data.json';

/**
 * Methoden/Funktionen, die im Report als "nicht messbar" behandelt werden sollen.
 *
 * Schlüssel: relativer Pfad wie im Report (toRelativePath())
 * Wert: Liste von Methodennamen, die ausgegraut und aus den Prozenten rausgerechnet werden.
 *
 * Diese Konfiguration erlaubt es, bestimmte Methoden von der Coverage-Messung auszuschließen,
 * z.B. wenn sie nicht sinnvoll testbar sind (Bootstrap-Code, Middleware-Initialisierung, etc.).
 */
const COVERAGE_IGNORE = [
    'src/Core/Application.php' => ['__construct', 'create', 'addMiddleware', 'handle'],
    'src/Core/Bootstrap.php' => ['registerAutoloader', 'loadConfig', 'configureErrorReporting', 'initFatalFallbackHandler'],
    'src/Core/Router.php' => ['add', 'get', 'post', 'patch', 'put', 'delete', 'allowedMethods', 'listRoutes', 'normalizePath'],
    'src/Middleware/CoverageMiddleware.php' => ['process', 'shouldStartCoverage', 'persistCoverage'],
    'routes.php' => ['registerRoutes'],
];

// Prüfen, ob Coverage-Daten vorhanden sind
if (!file_exists($dataFile)) {
    die('<h1>Keine Coverage-Daten gefunden.</h1>');
}

// Coverage-Daten laden und validieren
$data = json_decode(file_get_contents($dataFile), true);
if (!is_array($data)) {
    die('<h1>Coverage-Daten sind ungültig.</h1>');
}

/**
 * Escaped HTML-Sonderzeichen für sichere Ausgabe.
 *
 * Verhindert XSS-Angriffe durch Konvertierung von Sonderzeichen in HTML-Entities.
 *
 * @param string $s Der zu maskierende String
 * @return string Der HTML-sichere String
 */
function h(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/**
 * Berechnet Coverage-Statistiken für einen bestimmten Zeilenbereich.
 *
 * Zählt ausführbare Zeilen im angegebenen Bereich und ermittelt, wie viele davon
 * mindestens einmal ausgeführt wurden. Ignorierte Zeilen werden nicht mitgezählt.
 *
 * @param array<int,int> $lineHits Zuordnung Zeilennummer => Anzahl Ausführungen
 * @param array<int,true> $ignoredLines Set von Zeilennummern, die ignoriert werden sollen
 * @param int $startLine Erste Zeile des Bereichs (inklusiv)
 * @param int $endLine Letzte Zeile des Bereichs (inklusiv)
 * @return array{total:int, covered:int, percent:float} Statistik mit Gesamt-, Abgedeckte-Zeilen und Prozentsatz
 */
function coverageStatsForRange(array $lineHits, array $ignoredLines, int $startLine, int $endLine): array
{
    $total = 0;
    $covered = 0;

    foreach ($lineHits as $line => $hit) {
        if ($line < $startLine || $line > $endLine) {
            continue;
        }
        if (isset($ignoredLines[$line])) {
            continue; // aus der Metrik rausrechnen
        }
        $total++;
        if ($hit > 0) {
            $covered++;
        }
    }

    $percent = $total > 0 ? ($covered / $total) * 100.0 : 100.0;
    return ['total' => $total, 'covered' => $covered, 'percent' => $percent];
}

/**
 * Aggregiert Coverage für eine Datei ausschließlich aus ihren Funktionen/Methoden.
 *
 * Der globale Scope (Code außerhalb von Funktionen) wird dabei ignoriert, um aussagekräftigere
 * Metriken zu erhalten. Bootstrap-Code und Top-Level-Statements verfälschen sonst die Statistik.
 *
 * Fallback:
 * - Wenn keine Funktionen gefunden werden, wird die Datei als "whole-file range" ausgewertet,
 *   damit reine Skript-Dateien nicht komplett leer erscheinen.
 *
 * @param array<int,int> $lineHits Zuordnung Zeilennummer => Anzahl Ausführungen
 * @param array<int,true> $ignoredLines Set von Zeilennummern, die ignoriert werden sollen
 * @param string $filePath Absoluter Pfad zur Quell-Datei
 * @param array<int,string> $sourceLines Array mit allen Zeilen der Datei
 * @return array{total:int, covered:int, percent:float} Aggregierte Coverage-Statistik
 */
function coverageStatsForFileFromFunctions(array $lineHits, array $ignoredLines, string $filePath, array $sourceLines): array
{
    $functions = findFunctionsInFile($filePath);

    if (empty($functions)) {
        return coverageStatsForRange($lineHits, $ignoredLines, 1, count($sourceLines));
    }

    $total = 0;
    $covered = 0;

    foreach ($functions as $fn) {
        $s = coverageStatsForRange($lineHits, $ignoredLines, (int)$fn['start'], (int)$fn['end']);
        $total += $s['total'];
        $covered += $s['covered'];
    }

    $percent = $total > 0 ? ($covered / $total) * 100.0 : 100.0;
    return ['total' => $total, 'covered' => $covered, 'percent' => $percent];
}

/**
 * Findet alle Funktionen und Methoden in einer PHP-Datei mittels Token-Analyse.
 *
 * Durchsucht den Quellcode nach T_FUNCTION-Tokens und extrahiert Name sowie Start- und Endzeile
 * jeder Funktion/Methode. Anonyme Funktionen werden ignoriert (kein Name).
 *
 * @param string $filePath Absoluter Pfad zur PHP-Datei
 * @return array<int, array{name:string,start:int,end:int}> Liste der gefundenen Funktionen mit Name und Zeilenbereich
 */
function findFunctionsInFile(string $filePath): array
{
    $code = @file_get_contents($filePath);
    if ($code === false) {
        return [];
    }

    $tokens = token_get_all($code);
    $functions = [];

    $n = count($tokens);
    for ($i = 0; $i < $n; $i++) {
        $t = $tokens[$i];

        if (!is_array($t) || $t[0] !== T_FUNCTION) {
            continue;
        }

        $name = null;
        $nameLine = (int)$t[2];

        $j = $i + 1;
        for (; $j < $n; $j++) {
            $tj = $tokens[$j];

            if (is_array($tj) && $tj[0] === T_STRING) {
                $name = $tj[1];
                $nameLine = (int)$tj[2];
                break;
            }

            if ($tj === '(') { // anonyme function
                break;
            }
        }

        if ($name === null) {
            continue;
        }

        $startLine = $nameLine;
        $braceLevel = 0;
        $foundBodyStart = false;

        $k = $j;
        for (; $k < $n; $k++) {
            if ($tokens[$k] === '{') {
                $braceLevel = 1;
                $foundBodyStart = true;
                break;
            }
        }

        if (!$foundBodyStart) {
            continue;
        }

        $endLine = $startLine;
        for ($k = $k + 1; $k < $n; $k++) {
            $tk = $tokens[$k];

            if (is_array($tk)) {
                $endLine = (int)$tk[2];
                continue;
            }

            if ($tk === '{') {
                $braceLevel++;
            } elseif ($tk === '}') {
                $braceLevel--;
                if ($braceLevel === 0) {
                    break;
                }
            }
        }

        $functions[] = [
            'name' => $name,
            'start' => $startLine,
            'end' => max($startLine, $endLine),
        ];
    }

    usort($functions, fn($a, $b) => $a['start'] <=> $b['start']);
    return $functions;
}

/**
 * Rendert den Quellcode eines Zeilenbereichs mit Coverage-Highlighting.
 *
 * Jede Zeile wird farblich markiert:
 * - Grün (hit): Zeile wurde mindestens einmal ausgeführt
 * - Rot (miss): Zeile wurde nicht ausgeführt
 * - Grau (ignored): Zeile wird von der Coverage-Messung ausgeschlossen
 * - Neutral: Zeile ist nicht ausführbar oder nicht gemessen
 *
 * @param array<int,int> $lineHits Zuordnung Zeilennummer => Anzahl Ausführungen
 * @param array<int,string> $sourceLines Array mit allen Zeilen der Datei
 * @param array<int,true> $ignoredLines Set von Zeilennummern, die ignoriert werden sollen
 * @param int $startLine Erste Zeile des Bereichs (inklusiv)
 * @param int $endLine Letzte Zeile des Bereichs (inklusiv)
 */
function renderLines(array $lineHits, array $sourceLines, array $ignoredLines, int $startLine, int $endLine): void
{
    for ($lineNum = $startLine; $lineNum <= $endLine; $lineNum++) {
        $code = $sourceLines[$lineNum - 1] ?? '';
        $code = rtrim($code, "\r\n");

        if (isset($ignoredLines[$lineNum])) {
            $hit = null;
            $class = 'ignored';
        } elseif (array_key_exists($lineNum, $lineHits)) {
            $hit = $lineHits[$lineNum];
            $class = $hit > 0 ? 'hit' : 'miss';
        } else {
            $hit = null;
            $class = 'neutral';
        }

        $hitLabel = $hit === null ? '' : '(' . $hit . ')';

        echo '<div class="code-line ' . h($class) . '">';
        echo '<span class="ln">' . $lineNum . '</span>';
        echo '<span class="src">' . h($code) . '</span>';
        echo '<span class="hits">' . h($hitLabel) . '</span>';
        echo '</div>';
    }
}

/**
 * Konvertiert einen absoluten Dateipfad in einen projektrelativen Pfad.
 *
 * Entfernt das Projekt-Root-Verzeichnis vom Pfad und normalisiert die Trennzeichen auf "/".
 * Falls die Konvertierung fehlschlägt, wird der Originalpfad mit normalisierten Trennzeichen zurückgegeben.
 *
 * @param string $absolutePath Absoluter Dateipfad
 * @return string Relativer Pfad zum Projekt-Root (mit "/" als Trennzeichen)
 */
function toRelativePath(string $absolutePath): string
{
    $projectRoot = realpath(__DIR__ . '/../../');
    $realFile = realpath($absolutePath);

    if ($projectRoot && $realFile && str_starts_with($realFile, $projectRoot . DIRECTORY_SEPARATOR)) {
        $rel = substr($realFile, strlen($projectRoot . DIRECTORY_SEPARATOR));
        return str_replace('\\', '/', $rel);
    }

    return str_replace('\\', '/', $absolutePath);
}

/**
 * Ermittelt die Farbklasse basierend auf dem Coverage-Prozentsatz.
 *
 * Schwellwerte:
 * - < 50%: 'bad' (rot)
 * - 50-79%: 'warn' (gelb)
 * - >= 80%: 'good' (grün)
 *
 * @param float $percent Coverage-Prozentsatz (0.0 bis 100.0)
 * @return string CSS-Klasse für die Farbe ('bad', 'warn' oder 'good')
 */
function coverageColor(float $percent): string
{
    if ($percent < 50.0) {
        return 'bad';
    }
    if ($percent < 80.0) {
        return 'warn';
    }
    return 'good';
}

/**
 * Ermittelt alle Zeilennummern, die für eine Datei ignoriert werden sollen.
 *
 * Durchsucht die Datei nach Funktionen, die in COVERAGE_IGNORE aufgelistet sind,
 * und markiert deren gesamten Zeilenbereich als ignoriert.
 *
 * @param string $absoluteFilePath Absoluter Pfad zur Datei
 * @return array<int,true> Set von Zeilennummern (Key = Zeilennummer, Value = true)
 */
function ignoredLinesForFile(string $absoluteFilePath): array
{
    $rel = toRelativePath($absoluteFilePath);
    $ignoreNames = COVERAGE_IGNORE[$rel] ?? null;
    if ($ignoreNames === null || $ignoreNames === []) {
        return [];
    }

    $functions = findFunctionsInFile($absoluteFilePath);
    if ($functions === []) {
        return [];
    }

    $ignored = [];
    foreach ($functions as $fn) {
        if (!in_array($fn['name'], $ignoreNames, true)) {
            continue;
        }
        for ($ln = (int)$fn['start']; $ln <= (int)$fn['end']; $ln++) {
            $ignored[$ln] = true;
        }
    }

    return $ignored;
}

/**
 * Rendert eine Coverage-Zusammenfassungszeile mit einheitlichem Grid-Layout.
 *
 * Das Layout verwendet CSS Grid, damit alle Fortschrittsbalken perfekt untereinander ausgerichtet sind.
 * Leere Dateien/Funktionen (total = 0) werden speziell behandelt und ausgegraut dargestellt.
 *
 * @param string $label Anzuzeigender Text (Dateiname, Funktionsname, etc.)
 * @param float $percent Coverage-Prozentsatz (0.0 bis 100.0)
 * @param string $meta Zusatzinformationen (z.B. "25/100")
 * @param int $indentPx Einrückung in Pixeln für hierarchische Darstellung
 * @param int $total Anzahl der ausführbaren Zeilen (0 = leer/keine Messung)
 */
function renderSummary(string $label, float $percent, string $meta, int $indentPx = 0, int $total = 0): void
{
    $isEmpty = ($total === 0);
    $p = $isEmpty ? 0.0 : max(0.0, min(100.0, $percent));
    $pctLabel = $isEmpty ? '—' : (number_format($percent, 1, ',', '') . '%');
    $color = $isEmpty ? 'neutral' : coverageColor($percent);
    $labelClass = $isEmpty ? 'label empty' : 'label';

    echo '<div class="node">';
    echo '<div class="' . h($labelClass) . '" style="padding-left:' . $indentPx . 'px">' . h($label) . '</div>';
    echo '<div class="bar"><span class="' . h($color) . '" style="width:' . h((string)$p) . '%"></span></div>';
    echo '<div class="pct">' . h($pctLabel) . '</div>';
    echo '<div class="meta">' . h($meta) . '</div>';
    echo '</div>';
}

// HTML-Report generieren
echo '
<html lang="de">
<head>
  <title>Coverage</title>
  <style>
    body { font-family: sans-serif; margin: 16px; }
    .tree { max-width: 1200px; }
    details > summary { cursor: pointer; user-select: none; list-style: none; }
    details > summary::-webkit-details-marker { display: none; }
    summary { padding: 6px 8px; }
    .node {
      display: grid;
      grid-template-columns: 1fr 220px 72px 96px;
      align-items: center;
      column-gap: 10px;
    }
    .label {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .label.empty { color: #999; }
    .bar {
      height: 10px;
      background: #eee;
      border-radius: 999px;
      overflow: hidden;
    }
    .bar > span { display: block; height: 100%; width: 0; }
    .bar > span.good { background: #34c759; }   /* grün */
    .bar > span.warn { background: #ffcc00; }   /* gelb */
    .bar > span.bad  { background: #ff3b30; }   /* rot */
    .bar > span.neutral { background: #cfcfcf; }
    .pct {
      text-align: right;
      font-variant-numeric: tabular-nums;
      color: #444;
    }
    .meta {
      text-align: right;
      color: #777;
      font-variant-numeric: tabular-nums;
      white-space: nowrap;
    }
    .file { margin: 6px 0; }
    .fn { margin: 4px 0; }
    .code { margin: 8px 0 12px 0; }
    .code-line {
      display: flex;
      gap: 10px;
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace;
      font-size: 13px;
      line-height: 1.45;
      padding: 2px 8px;
      white-space: pre;
    }
    .ln { width: 56px; text-align: right; color: #888; flex: 0 0 auto; }
    .src { flex: 1 1 auto; overflow: hidden; }
    .hits { width: 70px; text-align: right; color: #666; flex: 0 0 auto; }
    .hit { background: #c8f7c5; }
    .miss { background: #f7c5c5; }
    .neutral { color: #777; background: #fff; }
    .ignored { color: #999; background: #f2f2f2; }
  </style>
</head>
<body>
<h1>Coverage-Report</h1>
<div class="tree">
';

// Projekt-Gesamtstatistik berechnen (Summe aller Dateien)
$projectTotal = 0;
$projectCovered = 0;

foreach ($data as $file => $lineHits) {
    $source = @file($file);
    if (!$source) {
        continue;
    }
    $ignoredLines = ignoredLinesForFile($file);
    $stats = coverageStatsForFileFromFunctions($lineHits, $ignoredLines, $file, $source);
    $projectTotal += $stats['total'];
    $projectCovered += $stats['covered'];
}

$projectPercent = $projectTotal > 0 ? ($projectCovered / $projectTotal) * 100.0 : 100.0;

// Projekt-Wurzelknoten rendern (standardmäßig ausgeklappt)
echo '<details open class="file">';
echo '<summary>';
renderSummary('FamKey.Host', $projectPercent, $projectCovered . '/' . $projectTotal, 0, $projectTotal);
echo '</summary>';

// Dateien "wie im Explorer" sortieren:
// 1) Erst alles in Unterordnern (controller/..., public/..., ...)
// 2) Dann Dateien im Projekt-Root (core.php, config.php, ...)
// Innerhalb jeder Gruppe alphabetisch sortieren (case-insensitive)
$files = array_keys($data);
usort($files, function (string $a, string $b): int {
    $ra = toRelativePath($a);
    $rb = toRelativePath($b);

    $aHasDir = str_contains($ra, '/');
    $bHasDir = str_contains($rb, '/');

    if ($aHasDir !== $bHasDir) {
        return $aHasDir ? -1 : 1; // Verzeichnisse zuerst
    }

    if ($aHasDir && $bHasDir) {
        $aFirst = explode('/', $ra, 2)[0];
        $bFirst = explode('/', $rb, 2)[0];

        $cmp = strcasecmp($aFirst, $bFirst);
        if ($cmp !== 0) {
            return $cmp; // erst nach Top-Level-Ordner gruppieren
        }
    }

    return strcasecmp($ra, $rb); // innerhalb der Gruppe alphabetisch
});

// Alle Dateien durchgehen und Coverage-Details rendern
foreach ($files as $file) {
    $lineHits = $data[$file];
    $source = @file($file);
    if (!$source) {
        continue;
    }
    $relFile = toRelativePath($file);
    $ignoredLines = ignoredLinesForFile($file);
    $fileStats = coverageStatsForFileFromFunctions($lineHits, $ignoredLines, $file, $source);
    $fileMeta = $fileStats['covered'] . '/' . $fileStats['total'];

    echo '<details class="file">';
    echo '<summary>';
    renderSummary($relFile, $fileStats['percent'], '(' . $fileMeta . ')', 22, $fileStats['total']);
    echo '</summary>';

    // Funktionen/Methoden in der Datei finden und einzeln rendern
    $functions = findFunctionsInFile($file);
    if (!empty($functions)) {
        foreach ($functions as $fn) {
            $fnStats = coverageStatsForRange($lineHits, $ignoredLines, (int)$fn['start'], (int)$fn['end']);
            $fnMeta = $fnStats['covered'] . '/' . $fnStats['total'];

            echo '<details class="fn">';
            echo '<summary>';
            renderSummary($fn['name'], $fnStats['percent'], '(' . $fnMeta . ')', 44, $fnStats['total']);
            echo '</summary>';

            echo '<div class="code">';
            renderLines($lineHits, $source, $ignoredLines, (int)$fn['start'], (int)$fn['end']);
            echo '</div>';

            echo '</details>';
        }
    } else {
        // Fallback für Dateien ohne Funktionen (reine Skripte): gesamten Inhalt anzeigen
        echo '<div class="code">';
        renderLines($lineHits, $source, $ignoredLines, 1, count($source));
        echo '</div>';
    }

    echo '</details>';
}

echo '</details>';
echo '</div></body></html>';
