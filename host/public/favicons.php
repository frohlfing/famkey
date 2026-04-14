<?php
/**
 * favicons.php – Favicon-Proxy
 *
 * Browser blockieren per CORS (Cross-Origin Resource Sharing) direkte Anfragen an externe Domains,
 * sofern der Zielserver keinen `Access-Control-Allow-Origin`-Header setzt.
 *
 * Dieser Proxy löst das Problem:
 * Er ruft das Favicon vom Google-Dienst ab und liefert es mit dem nötigen CORS-Header an den Browser zurück.
 *
 * Endpunkt: GET /favicons.php?domain={domain}
 *
 * Dieser Endpunkt liegt bewusst nicht unter /api/, da er kein Teil des REST-API-Protokolls ist.
 */

// Wichtig! CORS-Header setzen
header('Access-Control-Allow-Origin: *');

// Browser senden den OPTIONS-Preflight und erwarten darauf eine 2xx-Antwort mit den CORS-Headern
// bevor sie den eigentlichen GET-Request abschicken.
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// Nur GET-Anfragen erlauben
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    exit;
}

// Domain auslesen und validieren
$domain = trim($_GET['domain'] ?? '');
$domain = preg_replace('#^https?://#', '', $domain); // Protokoll entfernen
$domain = explode('/', $domain)[0]; // Pfad abschneiden
if ($domain === '') {
    http_response_code(422);
    exit;
}

// google liefert PNG, damit kann Flutter umgehen
$faviconUrl = sprintf('https://www.google.com/s2/favicons?domain=%s&sz=64', urlencode($domain));

// duckduckgo liefert ICO, wird von Flutter nicht unterstützt
//$faviconUrl = sprintf('https://icons.duckduckgo.com/ip3/%s.ico', urlencode($domain));

// Favicon abholen
$data = @file_get_contents($faviconUrl);
if ($data === false) {
    http_response_code(404);
    exit;
}

// Favicon ausgeben
header('Content-Type: image/png');
header('Cache-Control: public, max-age=86400');
header('Content-Length: ' . strlen($data));
echo $data;
