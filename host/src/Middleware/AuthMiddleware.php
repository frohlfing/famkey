<?php
declare(strict_types=1);

namespace App\Middleware;

use App\Core\Database;
use App\Core\MiddlewareInterface;
use App\Core\Request;
use App\Core\Response;

/**
 * Authentifizierung
 *
 * Diese Middleware authentifiziert den Benutzer über seine RSA-Signatur.
 * - Wenn die Signatur ungültig oder der Zeitstempel abgelaufen ist, wird die Anfrage mit dem Statuscode 401
 *   (Unauthorized) beendet.
 * - Bei erfolgreicher Prüfung wird Request->attributes['authUserUuid'] gesetzt.
 *
 * Konfiguration:
 * - Maximale zulässige Zeitabweichung ist fix (5 Minuten)
 *
 * Request-Header:
 * - `X-User-Uuid`: UUID des anfragenden Benutzers
 * - `X-Timestamp`: Unix-Zeit (UTC)
 * - `X-Signature`: RSA-Signatur über `{user_uuid}:{timestamp}` (Base64, PKCS#1 v1.5)
 */
final class AuthMiddleware implements MiddlewareInterface
{
    /**
     * Maximale zulässige Zeitabweichung in Sekunden (±).
     */
    private int $maxSkewSeconds = 300;

    /** @inheritDoc */
    public function process(Request $request, callable $next): Response
    {
        if (!$request->isProtectedRoute()) {
            return $next($request); // Pfad ist öffentlich
        }

        // Authentifizierungs-Header auslesen
        $uuid = trim(($request->header('X-User-Uuid') ?? ''));
        $timestamp = trim(($request->header('X-Timestamp') ?? ''));
        $signature = trim(($request->header('X-Signature') ?? ''));
        if ($uuid === '' || $timestamp === '' || $signature === '') {
            return Response::error(401, 'Fehlende Authentifizierungs-Header');
        }

        // Zeitfenster prüfen (max. 5 Minuten Abweichung gegen Replay-Attacks)
        if (abs(time() - (int)$timestamp) > $this->maxSkewSeconds) {
            return Response::error(401, 'Request-Zeitstempel ungültig oder abgelaufen');
        }

        // Public Key aus DB holen
        $pdo = Database::pdo();
        $stmt = $pdo->prepare('SELECT public_key FROM users WHERE uuid = ?');
        $stmt->execute([$uuid]);
        $publicKey = $stmt->fetchColumn();
        if (!$publicKey) {
            return Response::error(401, 'Benutzer im Authentifizierungs-Header unbekannt');
        }

        // Public Key für PHP aufbereiten (SPKI Format)
        $pubKey = "-----BEGIN PUBLIC KEY-----\n" .
            wordwrap($publicKey, 64, "\n", true) .
            "\n-----END PUBLIC KEY-----";

        $payload = "$uuid:$timestamp";
        $ok = openssl_verify($payload, base64_decode($signature), $pubKey, OPENSSL_ALGO_SHA256);
        if ($ok !== 1) {
            return Response::error(401, 'Kryptografische Signatur ungültig');
        }

        return $next($request->withAttribute('authUserUuid', $uuid));
    }
}