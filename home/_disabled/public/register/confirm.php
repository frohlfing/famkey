<?php
declare(strict_types=1);

/**
 * Datei: public/register/confirm.php
 *
 * E-Mail-Bestätigung und Organisations-Anlage.
 *
 * Ablauf:
 * 1. confirm_token aus der URL prüfen
 * 2. Abgelaufene Registrierungen bereinigen
 * 3. Organisation anlegen: UUID v4 org_uuid + UUID v4 api_token in organizations eintragen
 * 4. Registrierungseintrag löschen
 * 5. Server-URL und Token dem Benutzer anzeigen
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

$orgUuid    = null;
$apiToken   = null;
$serverUrl  = null;
$familyName = null;
$errorCode  = null; // 'expired' | 'invalid'

$confirmToken = trim($_GET['token'] ?? '');

if ($confirmToken === '' || strlen($confirmToken) !== 64 || !ctype_xdigit($confirmToken)) {
    $errorCode = 'invalid';
} else {
    $pdo = Database::pdo();

    // Abgelaufene Registrierungen bereinigen
    $pdo->exec("DELETE FROM registrations WHERE expires_at <= NOW()");

    // Eintrag holen (nach Bereinigung → abgelaufene sind schon weg)
    $stmt = $pdo->prepare('SELECT email, family_name FROM registrations WHERE confirm_token = ?');
    $stmt->execute([$confirmToken]);
    $row = $stmt->fetch();

    if (!$row) {
        $errorCode = 'expired'; // nicht vorhanden oder gerade bereinigt
    } else {
        $familyName = $row['family_name'];

        // Organisation anlegen: org_uuid in URL, api_token als Geheimnis
        $orgUuid  = Uuid::v4();
        $apiToken = Uuid::v4();
        $pdo->prepare('INSERT INTO organizations (org_uuid, api_token, name) VALUES (?, ?, ?)')
            ->execute([$orgUuid, $apiToken, $row['email']]);

        $serverUrl = rtrim(REGISTER_BASE_URL, '/') . '/org/' . $orgUuid;

        // Bestätigungs-Eintrag löschen
        $pdo->prepare('DELETE FROM registrations WHERE confirm_token = ?')->execute([$confirmToken]);
    }
}

?>
<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <title>FamKey – Sync-Server-Zugang</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        *, *::before, *::after { box-sizing: border-box; }
        :root { --bg: #f5f5f5; --card: #fff; --fg: #1a1a1a; --muted: #666; --border: #ddd; --accent: #1a1a2e; --green: #1b5e20; --green-bg: #f0fff4; --green-border: #b2dfdb; --red: #c00; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg); color: var(--fg); margin: 0; padding: 24px 16px; line-height: 1.6; }
        .wrap { max-width: 540px; margin: 0 auto; }
        .logo { font-size: 24px; font-weight: 700; letter-spacing: -0.5px; margin-bottom: 4px; }
        .tagline { color: var(--muted); margin-bottom: 32px; }
        .card { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 28px; }
        h2 { margin: 0 0 12px; font-size: 20px; }
        .icon { font-size: 48px; text-align: center; margin-bottom: 12px; }
        .label { font-size: 12px; font-weight: 700; color: var(--muted); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 4px; }
        .token-box {
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
            font-size: 14px; letter-spacing: 0.3px;
            background: #f4f4f8; border: 2px solid var(--accent);
            border-radius: 10px; padding: 14px 18px;
            word-break: break-all; margin: 6px 0 10px;
            user-select: all; cursor: text;
        }
        .copy-btn {
            width: 100%; padding: 10px; background: var(--accent); color: #fff;
            border: none; border-radius: 8px; font: inherit; font-size: 13px;
            font-weight: 600; cursor: pointer; margin-bottom: 20px;
        }
        .copy-btn:hover { opacity: .9; }
        .steps { padding: 0; margin: 0; list-style: none; counter-reset: step; }
        .steps li { display: flex; gap: 12px; margin-bottom: 12px; font-size: 14px; }
        .steps li::before { counter-increment: step; content: counter(step); background: var(--accent); color: #fff; border-radius: 50%; min-width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: 700; margin-top: 1px; }
        .note { font-size: 13px; color: var(--muted); margin-top: 20px; padding-top: 16px; border-top: 1px solid var(--border); }
        .warn-box { background: #fff8e1; border: 1px solid #ffe082; border-radius: 8px; padding: 12px 14px; font-size: 13px; margin-top: 16px; }
        .warn-box strong { display: block; margin-bottom: 4px; }
        .error-box { background: #fff0f0; border: 1px solid #fcc; border-radius: 8px; padding: 16px; text-align: center; }
        .divider { height: 1px; background: var(--border); margin: 16px 0; }
    </style>
</head>
<body>
<div class="wrap">
    <div class="logo">FamKey</div>
    <div class="tagline">Selbst gehosteter Passwort-Manager</div>

    <div class="card">

        <?php if ($orgUuid !== null): ?>

            <div class="icon">🎉</div>
            <h2 style="text-align:center;">Dein Sync-Server-Zugang<?= $familyName ? ' für ' . h($familyName) : '' ?></h2>
            <p style="color:var(--muted); font-size:14px;">
                Deine E-Mail-Adresse wurde bestätigt. Trage die folgenden Zugangsdaten in der FamKey-App ein:
            </p>

            <div class="label">Server-Adresse</div>
            <div class="token-box" id="server-url"><?= h($serverUrl) ?></div>
            <button class="copy-btn" onclick="copyValue('server-url', this, 'Server-Adresse kopieren')">Server-Adresse kopieren</button>

            <div class="label">API-Token</div>
            <div class="token-box" id="token"><?= h($apiToken) ?></div>
            <button class="copy-btn" onclick="copyValue('token', this, 'API-Token kopieren')">API-Token kopieren</button>

            <strong style="font-size:14px;">So richtest du die App ein:</strong>
            <ol class="steps" style="margin-top:12px;">
                <li>Öffne die FamKey-App und gehe zu <strong>Einstellungen → Sync-Server</strong>.</li>
                <li>Trage als Server-Adresse die <strong>Server-Adresse</strong> (oben) ein.</li>
                <li>Füge den <strong>API-Token</strong> (oben) in das Token-Feld ein.</li>
                <li>Tippe auf <strong>„Verbindung testen"</strong> und dann <strong>„Speichern"</strong>.</li>
                <li>Teile Server-Adresse und API-Token mit deinen Familienmitgliedern (z.&thinsp;B. per Signal).</li>
            </ol>

            <div class="warn-box">
                <strong>⚠ Diese Zugangsdaten sicher aufbewahren</strong>
                Sie werden dir nur einmal angezeigt. Notiere sie an einem sicheren Ort.
                Falls der Token verloren geht, kannst du über das Registrierungsformular einen neuen anfordern –
                du wirst dann als neue Organisation angelegt (leerer Server).
            </div>

            <p class="note">
                Der API-Token sichert ausschließlich den <em>Transportweg</em> zum Sync-Server.
                Deine Passwörter bleiben lokal verschlüsselt – Zero-Knowledge bleibt gewährleistet.
            </p>

        <?php elseif ($errorCode === 'expired'): ?>

            <div class="error-box">
                <div style="font-size:40px; margin-bottom:8px;">⏱</div>
                <h2>Link abgelaufen</h2>
                <p style="color:var(--muted); font-size:14px;">
                    Der Bestätigungs-Link ist nicht mehr gültig (Gültigkeit: 1 Stunde).<br>
                    Bitte fordere einen neuen an.
                </p>
                <a href="index.php" style="display:inline-block; margin-top:12px; padding:10px 20px; background:var(--accent); color:#fff; border-radius:8px; text-decoration:none; font-size:14px; font-weight:600;">
                    Neu anfordern
                </a>
            </div>

        <?php else: ?>

            <div class="error-box">
                <div style="font-size:40px; margin-bottom:8px;">❌</div>
                <h2>Ungültiger Link</h2>
                <p style="color:var(--muted); font-size:14px;">
                    Der Bestätigungs-Link ist ungültig oder wurde bereits verwendet.
                </p>
                <a href="index.php" style="display:inline-block; margin-top:12px; padding:10px 20px; background:var(--accent); color:#fff; border-radius:8px; text-decoration:none; font-size:14px; font-weight:600;">
                    Zurück zur Registrierung
                </a>
            </div>

        <?php endif; ?>

    </div>
</div>

<script>
function copyValue(id, btn, label) {
    const text = document.getElementById(id).innerText.trim();
    navigator.clipboard.writeText(text).then(() => {
        btn.textContent = '✓ Kopiert!';
        setTimeout(() => btn.textContent = label, 2000);
    });
}
</script>
</body>
</html>
