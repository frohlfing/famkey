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
    <title>FamKey Dev – API-Referenz</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <!--suppress CssUnusedSymbol -->
    <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        :root {
            --bg: #0d1b2a; --bg-card: #162232; --bg-card2: #1c2d3f;
            --primary: #607D8B; --primary-dark: #455A64; --primary-light: #90A4AE;
            --text: #dce8f0; --text-muted: #90a8b8; --border: #243749;
            --ok: #4caf92; --err: #e57373; --radius: 8px;
            --code-bg: #070f18; --code-fg: #ccd9e3;
        }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; font-size: 14px; }
        a { color: var(--primary-light); text-decoration: none; }
        a:hover { text-decoration: underline; }

/* ── Layout ── */
        .wrap { padding: 20px 24px; }
        .page-title { font-size: 20px; font-weight: 700; color: #e8f4fb; margin-bottom: 4px; }
        .page-sub { color: var(--text-muted); font-size: 13px; margin-bottom: 16px; }
        .grid { display: grid; grid-template-columns: 400px 1fr; gap: 14px; align-items: start; }

        /* ── Cards ── */
        .card { background: var(--bg-card); border: 1px solid var(--border); border-radius: var(--radius); padding: 16px; }
        .divider { height: 1px; background: var(--border); margin: 10px 0; }
        .muted { color: var(--text-muted); }

        /* ── TOC ── */
        .toc.card { position: sticky; top: 16px; max-height: calc(100vh - 80px); overflow-y: auto; }
        .toc-count { font-size: 12px; color: var(--text-muted); }
        .toc-row { display: flex; justify-content: space-between; align-items: center; gap: 10px; margin: 5px 0; }
        .toc-link { color: var(--text-muted); text-decoration: none; font-size: 13px; font-family: ui-monospace, Menlo, Consolas, monospace; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; flex: 1; transition: color .1s; }
        .toc-link:hover { color: var(--text); text-decoration: none; }

        /* ── Pills ── */
        .pill { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: 11px; border: 1px solid; min-width: 72px; text-align: center; font-weight: 600; white-space: nowrap; }
        .pill.protected { border-color: rgba(229,115,115,.4); color: var(--err); background: rgba(229,115,115,.08); }
        .pill.open { border-color: rgba(76,175,146,.4); color: var(--ok); background: rgba(76,175,146,.08); }

        /* ── Content ── */
        .content.card { max-height: calc(100vh - 80px); overflow: auto; }
        .endpoint { display: none; }
        .endpoint.active { display: block; }
        .endpoint-title { display: flex; gap: 12px; align-items: baseline; justify-content: space-between; margin-bottom: 6px; }
        .endpoint-title h2 { margin: 0; font-size: 17px; font-family: ui-monospace, Menlo, Consolas, monospace; color: #e8f4fb; }
        .handler { font-size: 12px; color: var(--text-muted); font-family: ui-monospace, Menlo, Consolas, monospace; margin-bottom: 10px; }

        /* ── Doc ── */
        .doc { margin-top: 12px; font-size: 13px; line-height: 1.7; }
        .doc p { margin: 8px 0; color: var(--text); }
        .doc p strong { color: #e8f4fb; }
        pre.code { background: var(--code-bg); color: var(--code-fg); padding: 14px; border-radius: 6px; overflow: auto; font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 12px; line-height: 1.5; border: 1px solid var(--border); margin: 8px 0; }
        code { font-family: ui-monospace, Menlo, Consolas, monospace; }

        @media (max-width: 900px) {
            .grid { grid-template-columns: 1fr; }
            .content.card { max-height: none; }
            .toc.card { position: static; max-height: none; }
        }
    </style>
</head>
<body>

<div class="wrap">
    <div class="page-title">API-Referenz</div>
    <div class="page-sub">Generiert aus <code style="font-size:12px;background:rgba(255,255,255,.07);padding:2px 6px;border-radius:4px;">routes.php</code> + PHPDoc der Controller-Methoden.</div>

    <div class="grid">
        <div class="card toc">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:2px;">
                <strong style="font-size:13px; color:#e8f4fb;">Endpunkte</strong>
                <span class="toc-count"><?= h((string)count($items)) ?></span>
            </div>
            <div class="divider"></div>

            <?php if ($items === []): ?>
                <div class="muted" style="font-size:13px;">Keine Routen gefunden.</div>
            <?php else: ?>
                <?php foreach ($items as $it): ?>
                    <div class="toc-row">
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

        <div class="content card">
            <?php foreach ($routes as $r): ?>
                <?php
                $id = strtolower($r['method'] . '-' . ltrim(str_replace('/', '-', $r['path']), '-'));
                $controllerClass = $r['handler'][0] ?? '';
                $controllerMethod = $r['handler'][1] ?? '';
                $docHtml = '<div class="muted" style="font-size:13px;">(Handler ungültig)</div>';

                if (is_string($controllerClass) && is_string($controllerMethod) && $controllerClass !== '' && $controllerMethod !== '') {
                    try {
                        $rm = new ReflectionMethod($controllerClass, $controllerMethod);
                        $doc = normalizeDocComment($rm->getDocComment());
                        $docHtml = renderDocAsHtml($doc);
                    } catch (Throwable $e) {
                        $docHtml = '<div class="muted" style="font-size:13px;">(Doc-Extraction fehlgeschlagen: ' . h($e->getMessage()) . ')</div>';
                    }
                }
                ?>
                <div class="endpoint" id="<?= h($id) ?>">
                    <div class="endpoint-title">
                        <h2><?= h($r['method'] . ' ' . $r['path']) ?></h2>
                        <?php if ($r['protected']): ?>
                            <span class="pill protected">RSA-Schutz: Ja</span>
                        <?php else: ?>
                            <span class="pill open">RSA-Schutz: Nein</span>
                        <?php endif; ?>
                    </div>
                    <div class="handler">Handler: <?= h((string)$controllerClass) ?>::<?= h((string)$controllerMethod) ?>()</div>
                    <div class="divider"></div>
                    <div class="doc"><?= $docHtml ?></div>
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
        return (location.hash || '').replace(/^#/, '');
    }

    document.querySelectorAll('a.toc-link').forEach(a => {
        a.addEventListener('click', function (e) {
            e.preventDefault();
            const id = this.getAttribute('data-target') || '';
            if (!id) return;
            history.replaceState(null, '', '#' + id);
            setActive(id);
        });
    });

    const initial = currentIdFromHash() || defaultId;
    if (initial) {
        history.replaceState(null, '', '#' + initial);
        setActive(initial);
    }

    window.addEventListener('hashchange', function () {
        const id = currentIdFromHash();
        if (id) setActive(id);
    });
})();
</script>
</body>
</html>
