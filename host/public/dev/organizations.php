<?php
declare(strict_types=1);

/**
 * Datei: public/dev/organizations.php
 *
 * Verwaltung der Organisationen (Multi-Tenant).
 * Jede Organisation repräsentiert eine Familie / Arbeitsgruppe.
 * Nur im Multi-Tenant-Modus verfügbar (MULTI_TENANT = true in config.php).
 */

use App\Core\Bootstrap;
use App\Core\Database;
use App\Core\Uuid;

require_once __DIR__ . '/../../src/Core/Bootstrap.php';
Bootstrap::registerAutoloader();
Bootstrap::loadConfig();

function h(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}


if (!MULTI_TENANT) {
    http_response_code(403);
    ?>
    <!doctype html>
    <html lang="de">
    <head>
        <meta charset="utf-8">
        <title>FamKey Dev – Organisationen</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
            :root { --bg:#0d1b2a; --text:#dce8f0; --text-muted:#90a8b8; --border:#243749; --bg-card:#162232; --primary:#607D8B; --err:#e57373; }
            body { font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif; background:var(--bg); color:var(--text); min-height:100vh; display:flex; align-items:center; justify-content:center; }
            .box { background:var(--bg-card); border:1px solid var(--border); border-radius:10px; padding:32px 40px; max-width:460px; text-align:center; }
            h2 { margin-bottom:12px; color:#e8f4fb; }
            p { color:var(--text-muted); font-size:14px; line-height:1.6; }
            code { background:rgba(255,255,255,.07); padding:2px 6px; border-radius:4px; font-family:monospace; font-size:13px; }
        </style>
    </head>
    <body>
        <div class="box">
            <h2>Single-Tenant-Modus</h2>
            <p>Dieser Bereich ist nur im Multi-Tenant-Modus verfügbar.<br>Setze <code>MULTI_TENANT = true</code> in <code>config.php</code>.</p>
        </div>
    </body>
    </html>
    <?php
    exit;
}

$pdo    = Database::pdo();
$errors = [];
$infos  = [];

// ── POST-Aktionen ─────────────────────────────────────────────────────────────

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action  = $_POST['action']   ?? '';
    $orgUuid = $_POST['org_uuid'] ?? '';

    // Organisation anlegen
    if ($action === 'create') {
        $name = trim($_POST['name'] ?? '');
        if ($name === '') {
            $errors[] = 'Name ist erforderlich.';
        } else {
            $newOrgUuid  = Uuid::v4();
            $newApiToken = Uuid::v4();
            $pdo->prepare('INSERT INTO organizations (uuid, api_token, name) VALUES (?, ?, ?)')
                ->execute([$newOrgUuid, $newApiToken, $name]);
            $proto   = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
            $baseUrl = "$proto://{$_SERVER['HTTP_HOST']}";
            $infos[] = "Organisation angelegt: <strong>" . h($name) . "</strong><br>"
                . "Server-Adresse: <code>" . h($baseUrl . '/org/' . $newOrgUuid) . "</code><br>"
                . "API-Token: <code>" . h($newApiToken) . "</code>";
        }
    }

    // Organisation sperren / entsperren
    if ($action === 'block' && $orgUuid !== '') {
        $pdo->prepare('UPDATE organizations SET blocked_at = NOW(3) WHERE uuid = ? AND blocked_at IS NULL')
            ->execute([$orgUuid]);
        $infos[] = "Organisation gesperrt: " . h($orgUuid);
    }

    if ($action === 'unblock' && $orgUuid !== '') {
        $pdo->prepare('UPDATE organizations SET blocked_at = NULL WHERE uuid = ?')
            ->execute([$orgUuid]);
        $infos[] = "Organisation entsperrt: " . h($orgUuid);
    }

    // Organisation löschen (löscht per FK-Kaskade auch alle verknüpften Tresore und Benutzer!)
    if ($action === 'delete' && $orgUuid !== '') {
        $pdo->prepare('DELETE FROM organizations WHERE uuid = ?')->execute([$orgUuid]);
        $infos[] = "Organisation gelöscht: " . h($orgUuid);
    }
}

// ── Daten laden ───────────────────────────────────────────────────────────────

$orgs = $pdo->query('
    SELECT o.uuid AS org_uuid, o.api_token, o.name, o.blocked_at, o.created_at,
           COUNT(v.uuid) AS vault_count
    FROM organizations o
    LEFT JOIN vaults v ON v.org_uuid = o.uuid
    GROUP BY o.uuid, o.api_token, o.name, o.blocked_at, o.created_at
    ORDER BY o.created_at DESC
')->fetchAll();

$proto   = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$baseUrl = "$proto://{$_SERVER['HTTP_HOST']}";

?>
<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <title>FamKey Dev – Organisationen</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        :root {
            --bg: #0d1b2a; --bg-card: #162232; --bg-card2: #1c2d3f;
            --primary: #607D8B; --primary-dark: #455A64; --primary-light: #90A4AE;
            --text: #dce8f0; --text-muted: #90a8b8; --border: #243749;
            --ok: #4caf92; --warn-col: #ffb74d; --err: #e57373; --radius: 8px;
        }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; font-size: 14px; }
        a { color: var(--primary-light); text-decoration: none; }
        a:hover { text-decoration: underline; }
        code { font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 12px; background: rgba(255,255,255,.07); padding: 2px 6px; border-radius: 4px; word-break: break-all; }

/* ── Layout ── */
        .wrap { max-width: 1000px; margin: 0 auto; padding: 28px 24px; }
        .page-title { font-size: 20px; font-weight: 700; color: #e8f4fb; margin-bottom: 4px; }
        .page-sub { color: var(--text-muted); font-size: 13px; margin-bottom: 24px; }

        /* ── Cards ── */
        .card { background: var(--bg-card); border: 1px solid var(--border); border-radius: var(--radius); padding: 20px; margin-top: 16px; }
        .card-title { font-size: 13px; font-weight: 700; color: #e8f4fb; margin-bottom: 4px; }
        .card-sub { font-size: 12px; color: var(--text-muted); margin-bottom: 14px; }
        .divider { height: 1px; background: var(--border); margin: 14px 0; }

        /* ── Table ── */
        table { width: 100%; border-collapse: collapse; }
        th { text-align: left; padding: 8px 12px; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; letter-spacing: 1px; border-bottom: 1px solid var(--border); white-space: nowrap; }
        td { text-align: left; padding: 10px 12px; border-bottom: 1px solid var(--border); vertical-align: top; font-size: 13px; }
        tbody tr:last-child td { border-bottom: none; }
        tbody tr:hover td { background: rgba(255,255,255,.025); }
        td.mono { font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 11px; word-break: break-all; }
        td.mono .sub { color: var(--text-muted); margin-top: 3px; }

        /* ── Buttons ── */
        .btn { display: inline-block; padding: 5px 14px; border-radius: 6px; font: inherit; font-size: 12px; cursor: pointer; border: 1px solid var(--border); background: var(--bg-card2); color: var(--text); transition: opacity .15s; }
        .btn:hover { opacity: .8; }
        .btn-primary { background: var(--primary-dark); color: #fff; border-color: var(--primary); }
        .btn-danger  { background: rgba(229,115,115,.12); color: var(--err); border-color: rgba(229,115,115,.35); }
        .btn-warn    { background: rgba(255,183,77,.1); color: var(--warn-col); border-color: rgba(255,183,77,.35); }
        .btn-ok      { background: rgba(76,175,146,.12); color: var(--ok); border-color: rgba(76,175,146,.35); }

        /* ── Alerts ── */
        .alert { padding: 12px 16px; border-radius: var(--radius); margin-top: 14px; border: 1px solid; font-size: 13px; line-height: 1.5; }
        .alert-info { background: rgba(76,175,146,.1); border-color: rgba(76,175,146,.3); color: var(--ok); }
        .alert-warn { background: rgba(229,115,115,.1); border-color: rgba(229,115,115,.3); color: var(--err); }

        /* ── Badges ── */
        .badge { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 11px; font-weight: 700; }
        .badge-ok   { background: rgba(76,175,146,.15); color: var(--ok); }
        .badge-warn { background: rgba(255,183,77,.15); color: var(--warn-col); }

        /* ── Form ── */
        .field-row { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
        input[type=text] { background: var(--bg); border: 1px solid var(--border); color: var(--text); border-radius: 6px; padding: 8px 12px; font: inherit; font-size: 13px; outline: none; flex: 1; min-width: 220px; }
        input[type=text]:focus { border-color: var(--primary); box-shadow: 0 0 0 3px rgba(96,125,139,.2); }
        input::placeholder { color: var(--text-muted); }

        .empty { color: var(--text-muted); font-size: 13px; }
    </style>
</head>
<body>


<div class="wrap">
    <div class="page-title">Organisationen</div>
    <div class="page-sub">Jede Organisation repräsentiert eine Familie / Gruppe (Multi-Tenant-Modus).</div>

    <?php foreach ($infos as $msg): ?>
        <div class="alert alert-info"><?= $msg ?></div>
    <?php endforeach; ?>
    <?php foreach ($errors as $msg): ?>
        <div class="alert alert-warn"><?= h($msg) ?></div>
    <?php endforeach; ?>

    <!-- Organisation anlegen -->
    <div class="card">
        <div class="card-title">Neue Organisation anlegen</div>
        <div class="card-sub">Generiert eine neue UUID und einen API-Token. Der Name ist nur für den Admin sichtbar.</div>
        <form method="post">
            <input type="hidden" name="action" value="create">
            <div class="field-row">
                <input type="text" name="name" title="" placeholder="z.&thinsp;B. Familie Müller oder info@example.com" required maxlength="255">
                <button class="btn btn-primary" type="submit">Anlegen</button>
            </div>
        </form>
    </div>

    <!-- Organisations-Tabelle -->
    <div class="card">
        <div class="card-title">Vorhandene Organisationen</div>
        <div class="divider"></div>

        <?php if (empty($orgs)): ?>
            <div class="empty">Keine Organisationen vorhanden.</div>
        <?php else: ?>
            <table>
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>UUID / Server-Adresse</th>
                        <th>API-Token</th>
                        <th>Tresore</th>
                        <th>Status</th>
                        <th>Erstellt</th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>
                <?php foreach ($orgs as $o): ?>
                    <?php $blocked = $o['blocked_at'] !== null; ?>
                    <tr style="<?= $blocked ? 'opacity:.5' : '' ?>">
                        <td><?= h($o['name']) ?></td>
                        <td class="mono">
                            <div><?= h($o['org_uuid']) ?></div>
                            <div class="sub"><?= h($baseUrl . '/org/' . $o['org_uuid']) ?></div>
                        </td>
                        <td class="mono"><?= h($o['api_token']) ?></td>
                        <td><?= (int)$o['vault_count'] ?></td>
                        <td>
                            <?php if ($blocked): ?>
                                <span class="badge badge-warn">Gesperrt</span>
                                <div style="font-size:11px; color:var(--text-muted); margin-top:3px;"><?= h($o['blocked_at']) ?></div>
                            <?php else: ?>
                                <span class="badge badge-ok">Aktiv</span>
                            <?php endif; ?>
                        </td>
                        <td style="white-space:nowrap; color:var(--text-muted);"><?= h(substr($o['created_at'], 0, 10)) ?></td>
                        <td style="white-space:nowrap;">
                            <?php if ($blocked): ?>
                                <form method="post" style="display:inline;">
                                    <input type="hidden" name="action" value="unblock">
                                    <input type="hidden" name="org_uuid" value="<?= h($o['org_uuid']) ?>">
                                    <button class="btn btn-ok" type="submit">Entsperren</button>
                                </form>
                            <?php else: ?>
                                <form method="post" style="display:inline;" onsubmit="return confirm('Organisation sperren? Alle Sync-Anfragen dieser Organisation werden mit 401 abgelehnt.')">
                                    <input type="hidden" name="action" value="block">
                                    <input type="hidden" name="org_uuid" value="<?= h($o['org_uuid']) ?>">
                                    <button class="btn btn-warn" type="submit">Sperren</button>
                                </form>
                            <?php endif; ?>
                            <form method="post" style="display:inline;" onsubmit="return confirm('Organisation löschen? Damit werden ALLE verknüpften Tresore und Benutzer unwiderruflich gelöscht!')">
                                <input type="hidden" name="action" value="delete">
                                <input type="hidden" name="org_uuid" value="<?= h($o['org_uuid']) ?>">
                                <button class="btn btn-danger" type="submit">Löschen</button>
                            </form>
                        </td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
    </div>
</div>
</body>
</html>
