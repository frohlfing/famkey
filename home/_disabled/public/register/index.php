<?php
declare(strict_types=1);

/**
 * Datei: public/register/index.php
 *
 * Registrierungsformular für den FamKey-Sync-Server auf famkey.de.
 * Benutzer geben ihre E-Mail-Adresse an und erhalten einen API-Token per E-Mail.
 *
 * Ablauf:
 * 1. Formular ausfüllen (Familienname optional, E-Mail Pflicht)
 * 2. Bestätigungs-E-Mail wird verschickt
 * 3. Klick auf den Link in der E-Mail → confirm.php generiert den API-Token
 */

use App\Core\Bootstrap;
use App\Core\Database;

require_once __DIR__ . '/../../src/Core/Bootstrap.php';
Bootstrap::registerAutoloader();
Bootstrap::loadConfig();

function h(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

$error   = '';
$success = false;

// ── POST: Registrierung einleiten ─────────────────────────────────────────────

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email      = trim($_POST['email']       ?? '');
    $familyName = trim($_POST['family_name'] ?? '');

    // Validierung
    if ($email === '') {
        $error = 'Bitte gib deine E-Mail-Adresse ein.';
    } elseif (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $error = 'Die E-Mail-Adresse ist ungültig.';
    } else {
        $pdo = Database::pdo();

        // Prüfen ob bereits eine ausstehende Anfrage für diese E-Mail existiert
        $stmt = $pdo->prepare('SELECT confirm_token FROM registrations WHERE email = ? AND expires_at > NOW()');
        $stmt->execute([$email]);
        if ($stmt->fetch()) {
            // Nicht verraten dass die E-Mail existiert – gleiche Erfolgsmeldung
            $success = true;
        } else {
            // Abgelaufene Einträge für diese E-Mail bereinigen
            $pdo->prepare('DELETE FROM registrations WHERE email = ?')->execute([$email]);

            // Bestätigungs-Token erzeugen (64 Hex-Zeichen)
            $confirmToken = bin2hex(random_bytes(32));
            $expiresAt    = date('Y-m-d H:i:s', time() + 3600); // 1 Stunde

            $pdo->prepare('INSERT INTO registrations (confirm_token, email, family_name, expires_at) VALUES (?, ?, ?, ?)')
                ->execute([$confirmToken, $email, $familyName ?: null, $expiresAt]);

            // Bestätigungs-E-Mail versenden
            $confirmUrl = rtrim(REGISTER_BASE_URL, '/') . '/register/confirm.php?token=' . urlencode($confirmToken);
            $subject    = 'FamKey – E-Mail-Adresse bestätigen';
            $body       = "Hallo" . ($familyName ? " ($familyName)" : "") . ",\n\n"
                . "bitte bestätige deine E-Mail-Adresse, um deinen FamKey-Sync-Server-Zugang zu erhalten.\n\n"
                . "Bestätigungs-Link (gültig für 1 Stunde):\n"
                . $confirmUrl . "\n\n"
                . "Falls du diese Anfrage nicht gestellt hast, kannst du diese E-Mail einfach ignorieren.\n\n"
                . "Dein FamKey-Team";

            $headers  = "From: " . MAIL_FROM_NAME . " <" . MAIL_FROM . ">\r\n";
            $headers .= "Reply-To: " . MAIL_FROM . "\r\n";
            $headers .= "Content-Type: text/plain; charset=UTF-8\r\n";
            $headers .= "X-Mailer: PHP/" . PHP_VERSION;

            mail($email, '=?UTF-8?B?' . base64_encode($subject) . '?=', $body, $headers);

            $success = true;
        }
    }
}

?>
<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <title>FamKey – Sync-Server-Zugang anfordern</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        *, *::before, *::after { box-sizing: border-box; }
        :root { --bg: #f5f5f5; --card: #fff; --fg: #1a1a1a; --muted: #666; --border: #ddd; --accent: #1a1a2e; --accent-fg: #fff; --red: #c00; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg); color: var(--fg); margin: 0; padding: 24px 16px; line-height: 1.6; }
        .wrap { max-width: 520px; margin: 0 auto; }
        .logo { font-size: 24px; font-weight: 700; letter-spacing: -0.5px; margin-bottom: 4px; }
        .tagline { color: var(--muted); margin-bottom: 32px; }
        .card { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 28px; }
        h2 { margin: 0 0 6px; font-size: 20px; }
        .subtitle { color: var(--muted); font-size: 14px; margin-bottom: 24px; }
        label { display: block; font-size: 14px; font-weight: 600; margin-bottom: 6px; }
        input[type=text], input[type=email] {
            width: 100%; padding: 10px 12px; border: 1px solid var(--border); border-radius: 8px;
            font: inherit; font-size: 15px; margin-bottom: 16px; outline: none;
        }
        input:focus { border-color: var(--accent); box-shadow: 0 0 0 3px rgba(26,26,46,.12); }
        .hint { font-size: 12px; color: var(--muted); margin-top: -12px; margin-bottom: 16px; }
        button { width: 100%; padding: 12px; background: var(--accent); color: var(--accent-fg); border: none; border-radius: 8px; font: inherit; font-size: 15px; font-weight: 600; cursor: pointer; }
        button:hover { opacity: .9; }
        .error { color: var(--red); font-size: 14px; margin-bottom: 16px; padding: 10px 12px; background: #fff0f0; border: 1px solid #fcc; border-radius: 8px; }
        .success-icon { font-size: 48px; text-align: center; margin-bottom: 12px; }
        .note { font-size: 13px; color: var(--muted); margin-top: 20px; padding-top: 16px; border-top: 1px solid var(--border); }
        .zk-box { background: #f0f7ff; border: 1px solid #bcd; border-radius: 8px; padding: 12px 14px; font-size: 13px; margin-top: 20px; }
        .zk-box strong { display: block; margin-bottom: 4px; }
    </style>
</head>
<body>
<div class="wrap">
    <div class="logo">FamKey</div>
    <div class="tagline">Selbst gehosteter Passwort-Manager</div>

    <div class="card">

        <?php if ($success): ?>

            <div class="success-icon">📬</div>
            <h2 style="text-align:center;">E-Mail unterwegs!</h2>
            <p style="text-align:center; color:var(--muted);">
                Wir haben dir einen Bestätigungs-Link geschickt.<br>
                Bitte prüfe deinen Posteingang (und ggf. den Spam-Ordner).
            </p>
            <p style="text-align:center; font-size:13px; color:var(--muted);">
                Der Link ist <strong>1 Stunde</strong> gültig.
            </p>

        <?php else: ?>

            <h2>Sync-Server-Zugang anfordern</h2>
            <p class="subtitle">Du erhältst einen persönlichen API-Token per E-Mail. Damit verbindest du deine FamKey-App mit dem Sync-Server auf famkey.de.</p>

            <?php if ($error !== ''): ?>
                <div class="error"><?= h($error) ?></div>
            <?php endif; ?>

            <form method="post" novalidate>
                <label for="family_name">Familienname <span style="font-weight:400;color:var(--muted)">(optional)</span></label>
                <input type="text" id="family_name" name="family_name" placeholder="z.&thinsp;B. Familie Müller" value="<?= h($_POST['family_name'] ?? '') ?>" maxlength="255">

                <label for="email">E-Mail-Adresse</label>
                <input type="email" id="email" name="email" placeholder="max@beispiel.de" value="<?= h($_POST['email'] ?? '') ?>" required maxlength="255">
                <p class="hint">An diese Adresse wird dein Token geschickt.</p>

                <button type="submit">Bestätigungs-E-Mail anfordern</button>
            </form>

            <div class="zk-box">
                <strong>Hinweis zum Datenschutz</strong>
                Der API-Token sichert nur den <em>Transportweg</em> zum Sync-Server.
                Deine Passwörter bleiben lokal verschlüsselt – der Server sieht niemals Klartextdaten (Zero-Knowledge).
                Deine E-Mail-Adresse wird ausschließlich zur Kontoverwaltung gespeichert.
            </div>

            <p class="note">
                Diesen Token gibst du anschließend in der FamKey-App unter
                <strong>Einstellungen → Sync-Server</strong> ein.<br>
                Alle Familienmitglieder tragen denselben Token ein.
            </p>

        <?php endif; ?>
    </div>
</div>
</body>
</html>
