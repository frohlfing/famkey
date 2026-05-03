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

if (!MULTI_TENANT) {
    http_response_code(403);
    echo '<p style="font-family:sans-serif;padding:2rem;">Dieser Bereich ist nur im Multi-Tenant-Modus verfügbar (<code>MULTI_TENANT = true</code> in <code>config.php</code>).</p>';
    exit;
}

function h(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
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

// Basis-URL aus dem Request ableiten (funktioniert für local dev und Production gleichermaßen)
$proto   = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$baseUrl = "{$proto}://{$_SERVER['HTTP_HOST']}";

?>
<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <title>FamKey – Organisationen</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        :root { --bg:#f4f4f4; --fg:#222; --muted:#666; --card:#fff; --border:#ddd; --red:#c00; --green:#2a6; --orange:#b85c00; }
        body { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; line-height:1.6; margin:0; background:var(--bg); color:var(--fg); }
        .wrap { max-width:900px; margin:0 auto; padding:24px; }
        h1 { margin:0 0 4px; }
        .muted { color:var(--muted); }
        .card { background:var(--card); border:1px solid var(--border); border-radius:8px; padding:16px; margin-top:16px; }
        table { width:100%; border-collapse:collapse; font-size:13px; }
        th, td { text-align:left; padding:8px 10px; border-bottom:1px solid var(--border); vertical-align:top; }
        th { font-weight:bold; white-space:nowrap; }
        td.mono { font-family:monospace; font-size:12px; word-break:break-all; }
        .btn { display:inline-block; padding:5px 12px; border:1px solid var(--border); border-radius:6px; background:var(--card); cursor:pointer; font:inherit; font-size:12px; }
        .btn-primary { background:#1a1a2e; color:#fff; border-color:#1a1a2e; }
        .btn-danger  { color:var(--red); border-color:var(--red); }
        .btn-warn    { color:var(--orange); border-color:var(--orange); }
        .btn-ok      { color:var(--green); border-color:var(--green); }
        .alert { padding:10px 14px; border-radius:6px; margin-top:12px; border:1px solid; font-size:13px; }
        .alert-info  { background:#f0fff4; border-color:#b2dfdb; color:#1b5e20; }
        .alert-warn  { background:#fff8e1; border-color:#ffe082; color:#795548; }
        .field-row { display:flex; gap:8px; align-items:flex-end; flex-wrap:wrap; }
        .field-row input { padding:7px 10px; border:1px solid var(--border); border-radius:6px; font:inherit; font-size:13px; }
        .badge { display:inline-block; padding:2px 8px; border-radius:4px; font-size:11px; font-weight:700; }
        .badge-ok     { background:#e8f5e9; color:#2a6; }
        .badge-warn   { background:#fff3e0; color:var(--orange); }
    </style>
</head>
<body>
<div class="wrap">
    <h1>Organisationen</h1>
    <div class="muted">Jede Organisation repräsentiert eine Familie / Gruppe (Multi-Tenant-Modus).</div>

    <?php foreach ($infos as $msg): ?>
        <div class="alert alert-info"><?= $msg ?></div>
    <?php endforeach; ?>
    <?php foreach ($errors as $msg): ?>
        <div class="alert alert-warn"><?= h($msg) ?></div>
    <?php endforeach; ?>

    <!-- Organisation anlegen -->
    <div class="card">
        <strong>Neue Organisation anlegen</strong>
        <div class="muted" style="margin:4px 0 12px; font-size:12px;">Generiert eine neue org_uuid und einen API-Token. Den Namen sieht nur der Admin.</div>
        <form method="post">
            <input type="hidden" name="action" value="create">
            <div class="field-row">
                <input type="text" name="name" placeholder="z.&thinsp;B. Familie Müller oder info@example.com" style="flex:1; min-width:220px;" required maxlength="255">
                <button class="btn btn-primary" type="submit">Anlegen</button>
            </div>
        </form>
    </div>

    <!-- Organisations-Tabelle -->
    <div class="card">
        <strong>Vorhandene Organisationen</strong>
        <div style="height:1px; background:var(--border); margin:10px 0 12px;"></div>

        <?php if (empty($orgs)): ?>
            <div class="muted">Keine Organisationen vorhanden.</div>
        <?php else: ?>
            <table>
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>org_uuid / Server-Adresse</th>
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
                    <tr style="<?= $blocked ? 'opacity:.6' : '' ?>">
                        <td><?= h($o['name']) ?></td>
                        <td class="mono">
                            <div><?= h($o['org_uuid']) ?></div>
                            <div style="color:var(--muted); margin-top:2px;"><?= h($baseUrl . '/org/' . $o['org_uuid']) ?></div>
                        </td>
                        <td class="mono"><?= h($o['api_token']) ?></td>
                        <td><?= (int)$o['vault_count'] ?></td>
                        <td>
                            <?php if ($blocked): ?>
                                <span class="badge badge-warn">Gesperrt</span>
                                <div style="font-size:11px; color:var(--muted); margin-top:2px;"><?= h($o['blocked_at']) ?></div>
                            <?php else: ?>
                                <span class="badge badge-ok">Aktiv</span>
                            <?php endif; ?>
                        </td>
                        <td style="white-space:nowrap;"><?= h(substr($o['created_at'], 0, 10)) ?></td>
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
