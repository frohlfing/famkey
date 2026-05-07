<?php
declare(strict_types=1);

// ── Pfade ────────────────────────────────────────────────────────────────────
$configPath   = __DIR__ . '/../../config.php';
$migrationDir = __DIR__ . '/../../migrations';

// ── Schritt-State ────────────────────────────────────────────────────────────
$step   = (int)($_GET['step'] ?? 1);
$errors = [];

// ── Helpers ──────────────────────────────────────────────────────────────────

function h(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function phpStr(string $v): string
{
    return "'" . str_replace(['\\', "'"], ['\\\\', "\\'"], $v) . "'";
}

// Ersetzt den Wert einer PHP-Konstante in einem Quelltext.
// const NAME = <alt>;  →  const NAME = <neu>;
function setConst(string $src, string $name, string $newValue): string
{
    return preg_replace('/^(const\s+' . preg_quote($name, '/') . '\s*=\s*)[^;]+(;)/m', '${1}' . $newValue . '${2}', $src, 1) ?? $src;
}

// ── Requirements prüfen ──────────────────────────────────────────────────────

function checkRequirements(string $configPath, string $migrationDir): array
{
    $checks = [];

    $ok = version_compare(PHP_VERSION, '8.4.0', '>=');
    $checks[] = ['PHP ≥ 8.4', PHP_VERSION, $ok, $ok ? '' : 'PHP 8.4 oder neuer wird benötigt.'];

    $ok = extension_loaded('pdo');
    $checks[] = ['Erweiterung: PDO', $ok ? 'vorhanden' : 'fehlt', $ok, $ok ? '' : 'Die PDO-Erweiterung fehlt.'];

    $ok = extension_loaded('pdo_mysql');
    $checks[] = ['Erweiterung: PDO_MySQL', $ok ? 'vorhanden' : 'fehlt', $ok, $ok ? '' : 'Die PDO_MySQL-Erweiterung fehlt.'];

    $parentDir = dirname($configPath);
    $ok = is_writable($parentDir);
    $label = basename($parentDir) . '/';
    $checks[] = ['Schreibrechte: ' . $label, $ok ? 'beschreibbar' : 'kein Zugriff', $ok,
        $ok ? '' : "Das Verzeichnis $label ist nicht beschreibbar. Bitte Dateiberechtigungen prüfen."];

    $ok = !file_exists($configPath);
    $checks[] = ['config.php noch nicht vorhanden', $ok ? 'ok' : 'bereits vorhanden!', $ok,
        $ok ? '' : 'Eine config.php existiert bereits – Setup bitte nicht erneut ausführen.'];

    $ok = is_dir($migrationDir) && count(array_filter(glob($migrationDir . '/*.sql') ?: [], fn($f) => basename($f) >= '001')) > 0;
    $checks[] = ['Migrations-Dateien vorhanden', $ok ? 'gefunden' : 'fehlt!', $ok,
        $ok ? '' : 'Keine .sql-Dateien im Verzeichnis migrations/ gefunden.'];

    return $checks;
}

function allPassed(array $checks): bool
{
    return array_all($checks, fn($c) => $c[2]);
}

// ── POST: Install durchführen ────────────────────────────────────────────────

$installSuccess = false;
$devProtected   = false;
$selfDelete     = false;
$skippedDb      = false;

if ($_SERVER['REQUEST_METHOD'] === 'POST' && $step === 3) {

    $skipDb      = isset($_POST['skip_db']);
    $skipApp     = isset($_POST['skip_app']);
    $skipLogging = isset($_POST['skip_logging']);
    $skipDev     = isset($_POST['skip_dev']);
    $selfDelete  = !isset($_POST['skip_cleanup']);

    $dbHost      = trim($_POST['db_host']  ?? 'localhost');
    $dbPort      = max(1, (int)($_POST['db_port']  ?? 3306));
    $dbName      = trim($_POST['db_name']  ?? '');
    $dbUser      = trim($_POST['db_user']  ?? '');
    $dbPass      =      $_POST['db_pass']  ?? '';
    $dbSslCa     = trim($_POST['db_sslca'] ?? '');

    $apiToken    = trim($_POST['api_token']        ?? '');
    $rateLimit   = max(0, (int)($_POST['rate_limit']        ?? 200));
    $maxAttachMb = max(1, (int)($_POST['max_attachment_mb'] ?? 25));

    $logLevel    = in_array($_POST['log_level'] ?? '', ['DEBUG','INFO','WARN','ERROR'], true)
                     ? $_POST['log_level'] : 'WARN';
    $logMaxDays  = max(1, (int)($_POST['log_max_days'] ?? 7));
    $debug       = isset($_POST['debug']);

    $devUser     = trim($_POST['dev_user'] ?? 'admin');
    $devPass     =      $_POST['dev_pass'] ?? '';

    if (!$skipDb  && $dbName   === '') $errors[] = 'Datenbankname ist erforderlich.';
    if (!$skipDb  && $dbUser   === '') $errors[] = 'Datenbankbenutzer ist erforderlich.';
    if (!$skipApp && $apiToken === '') $errors[] = 'API-Token ist erforderlich.';
    if (!$skipDev && $devPass !== '' && $devUser === '') $errors[] = 'Dev-Benutzername ist erforderlich, wenn ein Passwort gesetzt wird.';

    if (empty($errors)) {
        try {
            // ── DB-Verbindung testen + Migrationen ausführen ─────────────────
            if (!$skipDb) {
                $dsn = "mysql:host=$dbHost;port=$dbPort;dbname=$dbName;charset=utf8mb4";
                $pdoOptions = [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION];
                if ($dbSslCa !== '') {
                    $pdoOptions[PDO::MYSQL_ATTR_SSL_CA] = dirname($configPath) . '/' . basename($dbSslCa);
                    $pdoOptions[PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT] = true;
                }
                $pdo = new PDO($dsn, $dbUser, $dbPass, $pdoOptions);
                $migrationFiles = array_filter(glob($migrationDir . '/*.sql') ?: [], fn($f) => basename($f) >= '001');
                sort($migrationFiles);
                foreach ($migrationFiles as $mFile) {
                    $sql = file_get_contents($mFile);
                    $sql = preg_replace('/--[^\n]*\n/', "\n", $sql);
                    foreach (array_filter(array_map('trim', explode(';', $sql))) as $stmt) {
                        $pdo->exec($stmt);
                    }
                }
            } else {
                $skippedDb = true;
            }

            // ── config.php aus config.example.php generieren ─────────────────
            $configContent = file_get_contents(__DIR__ . '/../../config.example.php');
            $configContent = preg_replace('/^<\?php/', "<?php\n// Generiert durch FamKey Setup am " . date('Y-m-d H:i:s'), $configContent, 1);

            if (!$skipDb) {
                $configContent = setConst($configContent, 'DB_HOST', phpStr($dbHost));
                $configContent = setConst($configContent, 'DB_NAME', phpStr($dbName));
                $configContent = setConst($configContent, 'DB_USER', phpStr($dbUser));
                $configContent = setConst($configContent, 'DB_PASS', phpStr($dbPass));
                $configContent = setConst($configContent, 'DB_SSLCA', $dbSslCa !== '' ? "__DIR__ . '/" . addslashes(basename($dbSslCa)) . "'" : 'null');
            }
            if (!$skipApp) {
                $maxBytes = $maxAttachMb * 1024 * 1024;
                $configContent = setConst($configContent, 'API_TOKEN', phpStr($apiToken));
                $configContent = setConst($configContent, 'RATE_LIMIT', (string)$rateLimit);
                $configContent = preg_replace('/^const MAX_ATTACHMENT_BYTES\s*=.*$/m',
                    "const MAX_ATTACHMENT_BYTES = $maxBytes; // $maxAttachMb MB", $configContent);
            }
            if (!$skipLogging) {
                $configContent = setConst($configContent, 'DEBUG', $debug ? 'true' : 'false');
                $configContent = setConst($configContent, 'LOG_LEVEL', phpStr($logLevel));
                $configContent = setConst($configContent, 'LOG_MAX_DAYS', (string)$logMaxDays);
            }

            if (file_put_contents($configPath, $configContent) === false) {
                throw new RuntimeException('config.php konnte nicht geschrieben werden.');
            }

            // ── Dev-Bereich absichern ───────────────────────────────────────
            $devDir       = dirname(__DIR__) . '/dev';
            $htaccessPath = $devDir . '/.htaccess';
            $htpasswdPath = $devDir . '/.htpasswd';
            if (!$skipDev && $devPass !== '') {
                $hash = password_hash($devPass, PASSWORD_BCRYPT);
                file_put_contents($htpasswdPath, "$devUser:$hash\n");
                file_put_contents($htaccessPath,
                    'AuthUserFile "' . $htpasswdPath . '"' . "\n" .
                    'AuthName "FamKey Dev"' . "\n" .
                    'AuthType Basic' . "\n" .
                    'Require valid-user' . "\n"
                );
                $devProtected = true;
            } else {
                file_put_contents($htaccessPath, "Require all denied\n");
            }

            // ── Selbst löschen ──────────────────────────────────────────────
            if ($selfDelete) {
                $setupDir = __DIR__;
                $files = new RecursiveIteratorIterator(
                    new RecursiveDirectoryIterator($setupDir, FilesystemIterator::SKIP_DOTS),
                    RecursiveIteratorIterator::CHILD_FIRST
                );
                foreach ($files as $file) {
                    $file->isDir() ? rmdir($file->getPathname()) : unlink($file->getPathname());
                }
                register_shutdown_function(fn() => @rmdir($setupDir));
            }

            $installSuccess = true;
            $step = 4;

        } catch (PDOException $e) {
            $errors[] = 'Datenbankfehler: ' . $e->getMessage();
        } catch (Throwable $e) {
            $errors[] = 'Fehler: ' . $e->getMessage();
        }
    }
}

// ── Token für Formular vorbelegen ─────────────────────────────────────────────
$defaultToken = strtolower(bin2hex(random_bytes(24)));

// ── Requirements für Schritt 1 ────────────────────────────────────────────────
$requirements = ($step === 1) ? checkRequirements($configPath, $migrationDir) : [];
$reqPassed    = allPassed($requirements);

?><!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>FamKey – Setup</title>
  <link rel="icon" href="../favicon.png" type="image/png">
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    :root {
      --bg: #0d1b2a; --bg-card: #162232; --bg-card2: #1c2d3f;
      --primary: #607D8B; --primary-dark: #455A64; --primary-light: #90A4AE;
      --text: #dce8f0; --text-muted: #90a8b8; --border: #243749;
      --ok: #4caf92; --err: #e57373; --radius: 10px;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
      background: var(--bg); color: var(--text); line-height: 1.6; font-size: 15px;
      min-height: 100vh; display: flex; flex-direction: column; align-items: center;
      justify-content: flex-start; padding: 40px 16px 60px;
    }
    .card {
      width: 100%; max-width: 680px;
      background: var(--bg-card); border: 1px solid var(--border);
      border-radius: var(--radius); padding: 36px 36px;
    }
    .logo { text-align: center; margin-bottom: 28px; }
    .logo svg { width: 52px; height: 52px; filter: drop-shadow(0 0 16px rgba(96,125,139,.4)); }
    .logo h1 { font-size: 1.5rem; font-weight: 700; color: #e8f4fb; margin-top: 10px; letter-spacing: -.3px; }
    .logo p { color: var(--text-muted); font-size: .85rem; margin-top: 4px; }

    .steps-nav { display: flex; justify-content: center; gap: 0; margin-bottom: 28px; }
    .step-dot {
      width: 28px; height: 28px; border-radius: 50%; font-size: .78rem; font-weight: 700;
      display: flex; align-items: center; justify-content: center;
      background: var(--bg-card2); border: 1px solid var(--border); color: var(--text-muted);
    }
    .step-dot.active { background: var(--primary-dark); border-color: var(--primary); color: #fff; }
    .step-dot.done   { background: var(--ok); border-color: var(--ok); color: #fff; }
    .step-line { flex: 1; height: 1px; background: var(--border); align-self: center; max-width: 40px; }

    h2 { font-size: 1.1rem; font-weight: 700; color: #e8f4fb; margin-bottom: 6px; }
    .subtitle { color: var(--text-muted); font-size: .85rem; margin-bottom: 24px; }

    /* Requirements */
    .req-list { list-style: none; margin-bottom: 24px; }
    .req-list li {
      display: flex; align-items: center; gap: 10px;
      padding: 9px 12px; border-radius: 6px; margin-bottom: 6px;
      background: var(--bg-card2); border: 1px solid var(--border); font-size: .85rem;
    }
    .req-list li .label { flex: 1; }
    .req-list li .value { color: var(--text-muted); font-size: .8rem; }
    .req-list li .icon { font-size: 1rem; width: 20px; text-align: center; }
    .req-list li.ok    .icon { color: var(--ok); }
    .req-list li.fail  .icon { color: var(--err); }
    .req-list li .hint { font-size: .78rem; color: var(--err); display: block; margin-top: 3px; }

    /* Form */
    fieldset { position: relative; border: 1px solid var(--border); border-radius: 8px; padding: 16px 16px 10px; margin-bottom: 18px; }
    legend {
      padding: 0 8px; font-size: .78rem; font-weight: 700; color: var(--text-muted);
      text-transform: uppercase; letter-spacing: 1px;
      display: flex; align-items: center; gap: 10px; width: calc(100% - 16px);
    }
    .skip-label {
      margin-left: auto; font-weight: 400; font-size: .72rem;
      text-transform: none; letter-spacing: 0; white-space: nowrap;
      display: inline-flex; align-items: center; gap: 4px; cursor: pointer;
    }
    .skip-label input[type=checkbox] { width: auto; accent-color: var(--primary); }
    fieldset.skipped .field { opacity: 0.35; pointer-events: none; }
    .field { margin-bottom: 14px; }
    label { display: block; font-size: .82rem; font-weight: 600; color: var(--text-muted); margin-bottom: 5px; }
    input[type=text], input[type=password], input[type=number], select {
      width: 100%; background: var(--bg); border: 1px solid var(--border);
      color: var(--text); border-radius: 6px; padding: 8px 11px; font-size: .9rem;
      outline: none; transition: border-color .15s;
    }
    input:focus, select:focus { border-color: var(--primary); }
    .field-row { display: grid; grid-template-columns: 1fr 100px; gap: 10px; }
    .hint-text { font-size: .75rem; color: var(--text-muted); margin-top: 4px; }
    .token-row { display: flex; gap: 8px; }
    .token-row input { flex: 1; font-family: "Cascadia Code", Consolas, monospace; font-size: .8rem; }
    .pw-row { display: flex; gap: 8px; align-items: stretch; }
    .pw-row input { flex: 1; }
    .btn-eye {
      padding: 0 10px; background: var(--bg-card2); border: 1px solid var(--border);
      color: var(--text-muted); border-radius: 6px; cursor: pointer; flex-shrink: 0;
      display: flex; align-items: center; transition: border-color .15s;
    }
    .btn-eye:hover { border-color: var(--primary); color: var(--primary-light); }
    .btn-eye svg { width: 18px; height: 18px; fill: none; stroke: currentColor; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; }
    .btn-regen {
      padding: 8px 12px; background: var(--bg-card2); border: 1px solid var(--border);
      color: var(--text-muted); border-radius: 6px; cursor: pointer; font-size: .78rem;
      white-space: nowrap; transition: border-color .15s;
    }
    .btn-regen:hover { border-color: var(--primary); color: var(--primary-light); }
    .checkbox-row { display: flex; align-items: center; gap: 8px; font-size: .85rem; cursor: pointer; }
    .checkbox-row input[type=checkbox] { width: auto; accent-color: var(--primary); }

    /* Errors */
    .error-box {
      background: rgba(229,115,115,.08); border: 1px solid rgba(229,115,115,.3);
      border-radius: 8px; padding: 12px 14px; margin-bottom: 20px; font-size: .85rem;
    }
    .error-box ul { padding-left: 18px; }
    .error-box li { color: var(--err); margin-bottom: 3px; }

    /* Buttons */
    .btn {
      display: inline-block; padding: 11px 24px; border-radius: 8px; font-weight: 600;
      font-size: .9rem; cursor: pointer; border: none; transition: opacity .15s, transform .1s; text-decoration: none;
    }
    .btn:hover { opacity: .85; transform: translateY(-1px); }
    .btn-primary { background: var(--primary); color: #fff; }
    .btn-outline { background: transparent; border: 2px solid var(--primary); color: var(--primary-light); }
    .btn-block { display: block; width: 100%; text-align: center; }
    .btn-row { display: flex; justify-content: space-between; align-items: center; margin-top: 8px; }

    /* Success */
    .success-icon { text-align: center; font-size: 3rem; margin-bottom: 16px; }
    .success-list { list-style: none; margin: 20px 0; }
    .success-list li { padding: 7px 0; border-bottom: 1px solid var(--border); font-size: .88rem; color: var(--text-muted); display: flex; gap: 8px; align-items: baseline; }
    .success-list li:last-child { border-bottom: none; }
    .success-list li strong { color: var(--text); }
    .success-list li .ok-icon { color: var(--ok); }
    .success-list li .skip-icon { color: var(--text-muted); }

    code {
      background: rgba(0,0,0,.35); border: 1px solid var(--border);
      padding: 1px 6px; border-radius: 4px;
      font-family: "Cascadia Code", Consolas, monospace; font-size: .83em; color: #a8d1e8;
    }
    .footer-note { text-align: center; margin-top: 24px; font-size: .78rem; color: var(--text-muted); }
  </style>
</head>
<body>

<div class="card">

  <!-- Logo -->
  <div class="logo">
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="#607D8B">
      <g><rect fill="none" height="20" width="20" x="0"/></g>
      <path d="M5.5,16.5v-8h9v3.07C16.66,12.3,14.83,9.9,15,11.7c0.34,0,0.68,0.04,1,0.1V8.5C16,7.67,15.33,7,14.5,7H14V5 c0-2.21-1.79-4-4-4S6,2.79,6,5v2H5.5C4.67,7,4,7.67,4,8.5v8C4,17.33,4.67,18,5.5,18h4.89c-0.3-0.46-0.53-0.96-0.68-1.5H5.5z M7.5,5c0-1.38,1.12-2.5,2.5-2.5s2.5,1.12,2.5,2.5v2h-5V5z"/>
      <rect height="0.9" width="3.4" x="6.8" y="9.8"/>
      <rect height="0.9" width="3.4" x="6.8" y="11.6"/>
      <rect height="0.9" width="3.4" x="6.8" y="13.4"/>
      <circle cx="16" cy="14.5" r="1.5"/>
      <path d="M14.5 19c0-1.38 1.12-2.5 2.5-2.5s2.5 1.12 2.5 2.5H14.5z"/>
      <circle cx="12" cy="16" r="1.2"/>
      <path d="M10.8 20c0-1.1.9-2 2-2s2 .9 2 2h-4z"/>
    </svg>
    <h1>FamKey</h1>
    <p>Server-Setup</p>
  </div>

  <!-- Schritt-Navigation -->
  <div class="steps-nav">
    <div class="step-dot <?= $step === 1 ? 'active' : ($step > 1 ? 'done' : '') ?>">1</div>
    <div class="step-line"></div>
    <div class="step-dot <?= $step === 2 ? 'active' : ($step > 2 ? 'done' : '') ?>">2</div>
    <div class="step-line"></div>
    <div class="step-dot <?= $step === 3 ? 'active' : ($step > 3 ? 'done' : '') ?>">3</div>
    <div class="step-line"></div>
    <div class="step-dot <?= $step === 4 ? 'done' : '' ?>">✓</div>
  </div>

<?php if ($step === 1): ?>
  <!-- ══ Schritt 1: Systemvoraussetzungen ═══════════════════════════════════ -->
  <h2>Systemvoraussetzungen</h2>
  <p class="subtitle">FamKey prüft, ob dein Server alle Voraussetzungen erfüllt.</p>

  <ul class="req-list">
    <?php foreach ($requirements as [$label, $value, $ok, $hint]): ?>
    <li class="<?= $ok ? 'ok' : 'fail' ?>">
      <span class="icon"><?= $ok ? '✓' : '✗' ?></span>
      <span class="label">
        <?= h($label) ?>
        <?php if (!$ok && $hint !== ''): ?><span class="hint"><?= h($hint) ?></span><?php endif ?>
      </span>
      <span class="value"><?= h($value) ?></span>
    </li>
    <?php endforeach ?>
  </ul>

  <?php if ($reqPassed): ?>
    <a href="?step=2" class="btn btn-primary btn-block">Weiter &rarr;</a>
  <?php else: ?>
    <p style="color: var(--err); font-size: .85rem; text-align: center;">
      Bitte behebe die markierten Probleme und lade die Seite dann neu.
    </p>
  <?php endif ?>

<?php elseif ($step === 2): ?>
  <!-- ══ Schritt 2: Konfiguration ══════════════════════════════════════════ -->
  <h2>Konfiguration</h2>
  <p class="subtitle">Trage die Zugangsdaten deiner Datenbank und die App-Einstellungen ein.</p>

  <?php if (!empty($errors)): ?>
  <div class="error-box"><ul><?php foreach ($errors as $e): ?><li><?= h($e) ?></li><?php endforeach ?></ul></div>
  <?php endif ?>

  <form method="post" action="?step=3">

    <fieldset id="fs-db">
      <legend>
        Datenbank
        <label class="skip-label">
          <input type="checkbox" name="skip_db" onchange="skipSection(this,'fs-db')">
          Überspringen
        </label>
      </legend>

      <div class="field field-row">
        <div>
          <label for="db_host">Host</label>
          <input type="text" id="db_host" name="db_host" value="<?= h($_POST['db_host'] ?? 'localhost') ?>">
        </div>
        <div>
          <label for="db_port">Port</label>
          <input type="number" id="db_port" name="db_port" value="<?= h($_POST['db_port'] ?? '3306') ?>" min="1" max="65535">
        </div>
      </div>

      <div class="field">
        <label for="db_name">Datenbankname</label>
        <input type="text" id="db_name" name="db_name" value="<?= h($_POST['db_name'] ?? 'famkey') ?>">
      </div>

      <div class="field">
        <label for="db_user">Benutzer</label>
        <input type="text" id="db_user" name="db_user" value="<?= h($_POST['db_user'] ?? '') ?>" autocomplete="username">
      </div>

      <div class="field">
        <label for="db_pass">Passwort</label>
        <input type="password" id="db_pass" name="db_pass" value="<?= h($_POST['db_pass'] ?? '') ?>" autocomplete="current-password">
      </div>

      <div class="field">
        <label for="db_sslca">SSL-CA-Zertifikat <span style="font-weight:400">(optional, z.&nbsp;B. für Hetzner)</span></label>
        <input type="text" id="db_sslca" name="db_sslca" value="<?= h($_POST['db_sslca'] ?? '') ?>" placeholder="z. B. sqlca.pem">
        <p class="hint-text">Nur nötig, wenn dein Hoster eine TLS-Verbindung zur DB vorschreibt. Die Datei muss neben der <code>config.php</code> abgelegt werden.</p>
      </div>
    </fieldset>

    <fieldset id="fs-app">
      <legend>
        App-Einstellungen
        <label class="skip-label">
          <input type="checkbox" name="skip_app" onchange="skipSection(this,'fs-app')">
          Überspringen
        </label>
      </legend>

      <div class="field">
        <label for="api_token">API-Token</label>
        <div class="token-row">
          <input type="text" id="api_token" name="api_token"
                 value="<?= h($_POST['api_token'] ?? $defaultToken) ?>"
                 spellcheck="false" autocomplete="off">
          <button type="button" class="btn-regen"
                  onclick="document.getElementById('api_token').value='<?= bin2hex(random_bytes(24)) ?>'">
            Neu&nbsp;generieren
          </button>
        </div>
        <p class="hint-text">Geheimen Token aufschreiben – wird in der FamKey-App unter <em>Einstellungen → Sync-Server</em> abgefragt.</p>
      </div>

      <div class="field">
        <label for="rate_limit">Rate Limit <span style="font-weight:400">(Einträge/Minute, 0&nbsp;=&nbsp;kein Limit)</span></label>
        <input type="number" id="rate_limit" name="rate_limit" value="<?= h($_POST['rate_limit'] ?? '200') ?>" min="0">
      </div>

      <div class="field">
        <label for="max_attachment_mb">Max. Anhangsgröße (MB)</label>
        <input type="number" id="max_attachment_mb" name="max_attachment_mb" value="<?= h($_POST['max_attachment_mb'] ?? '25') ?>" min="1" max="500">
      </div>
    </fieldset>

    <fieldset id="fs-logging">
      <legend>
        Logging
        <label class="skip-label">
          <input type="checkbox" name="skip_logging" onchange="skipSection(this,'fs-logging')">
          Überspringen
        </label>
      </legend>
      <div class="field">
	    <label for="log_level">Log-Level</label>
		<select id="log_level" name="log_level">
		  <?php foreach (['DEBUG','INFO','WARN','ERROR'] as $l): ?>
		  <option value="<?= $l ?>" <?= ($_POST['log_level'] ?? 'WARN') === $l ? 'selected' : '' ?>><?= $l ?></option>
		  <?php endforeach ?>
		</select>
	  </div>
      <div class="field">
        <label for="log_max_days">Log aufbewahren (Tage)</label>
        <input type="number" id="log_max_days" name="log_max_days" value="<?= h($_POST['log_max_days'] ?? '7') ?>" min="1">
      </div>
      <div class="field">
        <label class="checkbox-row">
          <input type="checkbox" name="debug" <?= isset($_POST['debug']) ? 'checked' : '' ?>>
          Debug-Modus aktivieren
        </label>
        <p class="hint-text">Im Produktivbetrieb ausschalten – gibt interne Fehlermeldungen aus.</p>
      </div>
    </fieldset>

    <fieldset id="fs-dev">
      <legend>
        Dev-Bereich
        <label class="skip-label">
          <input type="checkbox" name="skip_dev" onchange="skipSection(this,'fs-dev')">
          Überspringen
        </label>
      </legend>
      <div class="field">
        <label for="dev_user">Benutzername</label>
        <input type="text" id="dev_user" name="dev_user" value="<?= h($_POST['dev_user'] ?? 'admin') ?>" autocomplete="off">
      </div>
      <div class="field">
        <label for="dev_pass">Passwort</label>
        <div class="pw-row">
          <input type="password" id="dev_pass" name="dev_pass" value="" autocomplete="new-password">
          <button type="button" class="btn-eye" onclick="togglePw('dev_pass',this)" title="Passwort anzeigen">
            <svg id="dev_pass-eye-open" viewBox="0 0 24 24"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
            <svg id="dev_pass-eye-closed" viewBox="0 0 24 24" style="display:none"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
          </button>
        </div>
        <p class="hint-text">Leer lassen, um den Dev-Bereich vollständig zu sperren.</p>
      </div>
    </fieldset>

    <fieldset id="fs-cleanup">
      <legend>
        Nach der Installation
        <label class="skip-label">
          <input type="checkbox" name="skip_cleanup" onchange="skipSection(this,'fs-cleanup')">
          Überspringen
        </label>
      </legend>
      <div class="field">
        <p class="hint-text">Setup-Ordner löschen – verhindert unbeabsichtigte Neu-Installation.</p>
      </div>
    </fieldset>

    <div class="btn-row">
      <a href="?step=1" class="btn btn-outline">&larr; Zurück</a>
      <button type="submit" class="btn btn-primary">Installation starten &rarr;</button>
    </div>
  </form>

  <script>
    function togglePw(id, btn) {
      const input = document.getElementById(id);
      const show = input.type === 'password';
      input.type = show ? 'text' : 'password';
      document.getElementById(id + '-eye-open').style.display   = show ? 'none' : '';
      document.getElementById(id + '-eye-closed').style.display = show ? '' : 'none';
    }
    function skipSection(cb, id) {
      const fs = document.getElementById(id);
      fs.classList.toggle('skipped', cb.checked);
      fs.querySelectorAll('input:not([name^="skip_"]), select, textarea').forEach(el => el.disabled = cb.checked);
    }
  </script>

<?php elseif ($step === 3 && !empty($errors)): ?>
  <!-- ══ Schritt 3: Fehler ══════════════════════════════════════════════════ -->
  <h2>Fehler bei der Installation</h2>
  <p class="subtitle">Bitte korrigiere die folgenden Probleme und versuche es erneut.</p>
  <div class="error-box"><ul><?php foreach ($errors as $e): ?><li><?= h($e) ?></li><?php endforeach ?></ul></div>
  <a href="?step=2" class="btn btn-outline">&larr; Zurück zur Konfiguration</a>

<?php elseif ($step === 4): ?>
  <!-- ══ Schritt 4: Erfolg ══════════════════════════════════════════════════ -->
  <div class="success-icon">✅</div>
  <h2 style="text-align:center">Installation abgeschlossen!</h2>
  <p class="subtitle" style="text-align:center">FamKey ist bereit.</p>

  <ul class="success-list">
    <?php if (!$skippedDb): ?>
    <li><span class="ok-icon">✓</span> <span>Datenbank eingerichtet und <strong>Schema migriert</strong></span></li>
    <?php else: ?>
    <li><span class="skip-icon">–</span> <span>Datenbank übersprungen</span></li>
    <?php endif ?>
    <li><span class="ok-icon">✓</span> <span><strong>config.php</strong> geschrieben</span></li>
    <?php if ($devProtected): ?>
    <li><span class="ok-icon">✓</span> <span>Dev-Bereich <strong>geschützt</strong> (HTTP-Basisauthentifizierung)</span></li>
    <?php else: ?>
    <li><span class="ok-icon">✓</span> <span>Dev-Bereich <strong>gesperrt</strong> – kein Zugriff von außen</span></li>
    <?php endif ?>
    <?php if ($selfDelete): ?>
    <li><span class="ok-icon">✓</span> <span>Setup <strong>gelöscht</strong></span></li>
    <?php endif ?>
  </ul>

  <p style="font-size:.88rem; color:var(--text-muted); margin-bottom:20px;">
    Nächster Schritt: Öffne die FamKey-App → <strong style="color:var(--text)">Einstellungen → Sync-Server</strong>
    und trage die URL deines Servers ein:
    <code><?= h('https://' . ($_SERVER['HTTP_HOST'] ?? 'deine-domain.de')) ?></code>
  </p>

  <a href="/" class="btn btn-primary btn-block">Zur Startseite</a>

<?php endif ?>

</div>

<p class="footer-note">
  FamKey &nbsp;&mdash;&nbsp;
  <a href="https://github.com/frohlfing/famkey" target="_blank" rel="noopener" style="color:var(--text-muted);">GitHub</a>
</p>

</body>
</html>
