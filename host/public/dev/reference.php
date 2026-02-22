<?php
declare(strict_types=1);

/**
 * Datei: public/dev/reference.php
 *
 * Dieses Skript generiert eine API-Referenzseite aus den PHPDoc-Kommentaren der Controller-Methoden.
 *
 * Funktionsweise:
 * - Endpunkte werden aus routes.php ermittelt (Single Source of Truth).
 * - Doku-Text wird per Reflection aus den Controller-Methoden gelesen.
 */

use App\Core\Bootstrap;
use App\Core\Router;

require_once __DIR__ . '/../../src/Core/Bootstrap.php';

// Autoloader + Secrets/DEBUG etc. (falls ihr es für Ausgabe/Env braucht)
Bootstrap::registerAutoloader();
Bootstrap::loadConfig();

/**
 * @return array<int,array{
 *   method:string,
 *   path:string,
 *   handler:array{0:class-string,1:string},
 *   protected:bool
 * }>
 */
function loadRoutes(): array
{
    // routes.php lädt nur registerRoutes() (global function)
    require_once __DIR__ . '/../../routes.php';

    if (!function_exists('registerRoutes')) {
        return [];
    }

    $router = new Router();
    registerRoutes($router);
    $routes = $router->listRoutes();

    // leichte Normierung
    $out = [];
    foreach ($routes as $r) {
        if (!isset($r['method'], $r['path'], $r['handler'], $r['protected'])) {
            continue;
        }
        $out[] = [
            'method' => (string)$r['method'],
            'path' => (string)$r['path'],
            'handler' => $r['handler'],
            'protected' => (bool)$r['protected'],
        ];
    }

    return $out;
}

function normalizeDocComment(?string $doc): string
{
    if (!is_string($doc) || $doc === '') {
        return '';
    }

    $doc = preg_replace('#^/\*\*#', '', $doc) ?? $doc;
    $doc = preg_replace('#\*/$#', '', $doc) ?? $doc;

    $lines = preg_split('/\R/u', $doc) ?: [];
    $out = [];

    foreach ($lines as $line) {
        $line = preg_replace('#^\s*\*\s?#', '', $line) ?? $line;
        $line = rtrim((string)$line);

        // Meta-Zeilen ausblenden
        if (preg_match('/^@(param|return|throws|noinspection)\b/i', $line) === 1) {
            continue;
        }

        $out[] = $line;
    }

    // Trim: führende/leere Zeilen entfernen
    while ($out !== [] && trim((string)$out[0]) === '') {
        array_shift($out);
    }
    while ($out !== [] && trim((string)$out[count($out) - 1]) === '') {
        array_pop($out);
    }

    // Mehrfach-Leerzeilen auf genau 1 reduzieren
    $collapsed = [];
    $prevBlank = false;
    foreach ($out as $line) {
        $blank = (trim($line) === '');
        if ($blank && $prevBlank) {
            continue;
        }
        $collapsed[] = $line;
        $prevBlank = $blank;
    }

    return implode("\n", $collapsed);
}

function renderDocAsHtml(string $doc): string
{
    if ($doc === '') {
        return '<div class="muted">(keine Dokumentation gefunden)</div>';
    }

    $parts = preg_split('#(<code>|</code>)#i', $doc, -1, PREG_SPLIT_DELIM_CAPTURE) ?: [];
    $html = '';
    $inCode = false;

    foreach ($parts as $p) {
        $tag = strtolower($p);
        if ($tag === '<code>') {
            $inCode = true;
            $html .= '<pre class="code"><code>';
            continue;
        }
        if ($tag === '</code>') {
            $inCode = false;
            $html .= '</code></pre>';
            continue;
        }

        if ($inCode) {
            // Wenn direkt nach <code> ein Zeilenumbruch folgt, entfernen
            $p = preg_replace('/^\R+/u', '', $p) ?? $p;
            $html .= htmlspecialchars($p, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
            continue;
        }

        $escaped = htmlspecialchars($p, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        $escaped = trim($escaped);
        if ($escaped === '') {
            continue;
        }

        $paras = preg_split("/\n\s*\n/u", $escaped) ?: [];
        foreach ($paras as $para) {
            $para = trim($para);
            if ($para === '') {
                continue;
            }

            $lines = preg_split("/\n/u", $para) ?: [];
            foreach ($lines as &$line) {
                $line = preg_replace(
                    '/^(Endpunkt|Header|Query|Body|Antwort|Mögliche Statuscodes)(\b)/u',
                    '<strong>$1</strong>$2',
                    $line
                ) ?? $line;
            }
            unset($line);

            $paraHtml = implode("\n", $lines);
            $html .= '<p>' . nl2br($paraHtml, false) . '</p>';
        }
    }

    return $html;
}

function h(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

$routes = loadRoutes();

// Für TOC
$items = [];
foreach ($routes as $r) {
    $id = strtolower($r['method'] . '-' . ltrim(str_replace('/', '-', $r['path']), '-'));
    $items[] = [
        'id' => $id,
        'title' => $r['method'] . ' ' . $r['path'],
        'protected' => $r['protected'],
        'handler' => $r['handler'],
    ];
}

// Default: wenn kein Hash gesetzt ist, ersten Endpunkt auswählen
$defaultId = $items[0]['id'] ?? '';

?>
<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <title>priVault API–Referenz</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <!--suppress CssUnusedSymbol -->
    <style>
        :root { --bg:#f4f4f4; --fg:#222; --muted:#666; --card:#fff; --border:#ddd; --codebg:#111; --codefg:#eee; }
        body { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace; line-height: 1.6; margin: 0; background: var(--bg); color: var(--fg); }
        .wrap { margin: 0 auto; padding: 20px; }
        h1 { margin: 0 0 10px; }
        .muted { color: var(--muted); }
        .grid { display: grid; grid-template-columns: 440px 1fr; gap: 14px; align-items: start; }
        .card { background: var(--card); border: 1px solid var(--border); border-radius: 8px; padding: 14px; }
        .toc a { color: inherit; text-decoration: none; }
        .toc a:hover { text-decoration: underline; }
.toc-link {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 100%;
  display: block;
}
        /* (4) pills links/rechts gleich breit: gilt für .pill allgemein */
        .pill {
            display:inline-block;
            padding: 2px 8px;
            border-radius: 999px;
            font-size: 12px;
            border: 1px solid var(--border);
            background: #fafafa;
            min-width: 78px;
            text-align: center;
            box-sizing: border-box;
        }
        .pill.protected { border-color: #b35; color: #b35; background: #fff5f7; }
        .pill.open { border-color: #3a7; color: #2a6; background: #f4fffa; }

        .endpoint-title { display:flex; gap:10px; align-items: baseline; justify-content: space-between; }
        .endpoint-title h2 { margin: 0; font-size: 18px; }
        .handler { font-size: 12px; color: var(--muted); }
        pre.code { background: var(--codebg); color: var(--codefg); padding: 12px; border-radius: 8px; overflow: auto; }
        code { font-family: inherit; }
        .doc { margin-top: 10px; }
        .doc p { margin: 8px 0; }     /* (1) weniger vertikale Luft als <br><br> */
        .hr { height: 1px; background: var(--border); margin: 10px 0; }

        /* (3) Sidebar bleibt sichtbar */
        .toc.card { position: sticky; top: 16px; }

        /* (3) rechte Spalte: nur ein Endpunkt sichtbar, eigener Scrollbereich */
        .content.card { max-height: calc(100vh - 40px); overflow: auto; }
        .endpoint { display: none; }
        .endpoint.active { display: block; }

        @media (max-width: 900px) {
            .grid { grid-template-columns: 1fr; }
            .content.card { max-height: none; }
            .toc.card { position: static; }
        }
    </style>
</head>
<body>
<div class="wrap">
    <h1>priVault API–Referenz</h1>
    <div class="muted">
        Generiert aus <code>routes.php</code> + PHPDoc der Controller-Methoden.
    </div>

    <div class="grid" style="margin-top:14px;">
        <div class="card toc">
            <div style="display:flex; justify-content:space-between; gap:10px;">
                <strong>Endpunkte</strong>
                <span class="muted"><?= h((string)count($items)) ?></span>
            </div>
            <div class="hr"></div>

            <?php if ($items === []): ?>
                <div class="muted">Keine Routen gefunden.</div>
            <?php else: ?>
                <?php foreach ($items as $it): ?>
                    <div style="display:flex; justify-content:space-between; gap:10px; margin: 6px 0;">
                        <a class="toc-link" data-target="<?= h($it['id']) ?>" href="#<?= h($it['id']) ?>"><?= h($it['title']) ?></a>
                        <?php if ($it['protected']): ?>
                            <span class="pill protected">RSA: Ja</span>
                        <?php else: ?>
                            <span class="pill open">RSA: Nein</span>
                        <?php endif; ?>
                    </div>
                <?php endforeach; ?>
            <?php endif; ?>
        </div>

        <div>
            <?php foreach ($routes as $r): ?>
                <?php
                $id = strtolower($r['method'] . '-' . ltrim(str_replace('/', '-', $r['path']), '-'));
                $controllerClass = $r['handler'][0] ?? '';
                $controllerMethod = $r['handler'][1] ?? '';
                $docHtml = '<div class="muted">(Handler ungültig)</div>';

                if (is_string($controllerClass) && is_string($controllerMethod) && $controllerClass !== '' && $controllerMethod !== '') {
                    try {
                        $rm = new ReflectionMethod($controllerClass, $controllerMethod);
                        $doc = normalizeDocComment($rm->getDocComment());
                        $docHtml = renderDocAsHtml($doc);
                    } catch (Throwable $e) {
                        $docHtml = '<div class="muted">(Doc-Extraction fehlgeschlagen: ' . h($e->getMessage()) . ')</div>';
                    }
                }
                ?>
                <div class="card endpoint" id="<?= h($id) ?>">
                    <div class="endpoint-title">
                        <h2><?= h($r['method'] . ' ' . $r['path']) ?></h2>
                        <?php if ($r['protected']): ?>
                            <span class="pill protected">RSA-Schutz: Ja</span>
                        <?php else: ?>
                            <span class="pill open">RSA-Schutz: Nein</span>
                        <?php endif; ?>
                    </div>
                    <div class="handler">
                        Handler: <?= h((string)$controllerClass) ?>::<?= h((string)$controllerMethod) ?>()
                    </div>

                    <div class="doc">
                        <?= $docHtml ?>
                    </div>
                </div>
            <?php endforeach; ?>
        </div>
    </div>
</div>

<script>
(function () {
    const defaultId = <?= json_encode($defaultId, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) ?>;

    function setActive(id) {
        document.querySelectorAll('.endpoint').forEach(el => el.classList.remove('active'));

        const target = document.getElementById(id);
        if (target && target.classList.contains('endpoint')) {
            target.classList.add('active');
            const container = document.querySelector('.content.card');
            if (container) container.scrollTop = 0;
        }
    }

    function currentIdFromHash() {
        const h = (location.hash || '').replace(/^#/, '');
        return h || '';
    }

    // Click: nicht "scrollen", nur anzeigen + hash setzen
    document.querySelectorAll('a.toc-link').forEach(a => {
        a.addEventListener('click', function (e) {
            e.preventDefault();
            const id = this.getAttribute('data-target') || '';
            if (!id) return;
            history.replaceState(null, '', '#' + id);
            setActive(id);
        });
    });

    // Initial
    const initial = currentIdFromHash() || defaultId;
    if (initial) {
        history.replaceState(null, '', '#' + initial);
        setActive(initial);
    }

    // Hash-Änderung (Back/Forward)
    window.addEventListener('hashchange', function () {
        const id = currentIdFromHash();
        if (id) setActive(id);
    });
})();
</script>
</body>
</html>