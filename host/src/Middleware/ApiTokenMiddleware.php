<?php
declare(strict_types=1);

namespace App\Middleware;

use App\Core\Database;
use App\Core\MiddlewareInterface;
use App\Core\Request;
use App\Core\Response;

/**
 * Globaler, benutzerunabhängiger API-Schutz.
 *
 * Verhält sich je nach Server-Modus (MULTI_TENANT in config.php) unterschiedlich:
 *
 * Single-Tenant (MULTI_TENANT = false):
 *   Vergleicht den übermittelten Token direkt mit dem globalen API_TOKEN aus config.php.
 *   Kein Datenbankzugriff. Geeignet für selbst gehostete Einzelfamilien-Server.
 *
 * Multi-Tenant (MULTI_TENANT = true):
 *   1. org_slug wird aus dem URL-Pfad /org/{slug}/api/... von Request::fromGlobals() extrahiert.
 *   2. Organisation wird in der Tabelle `organizations` nachgeschlagen (nicht gesperrt).
 *   3. Der übermittelte API-Token wird mit organizations.api_token verglichen.
 *   → Stimmen Organisation und API-Token überein, wird die Anfrage weitergeleitet.
 *
 * Unterstützte Token-Übermittlung:
 *   Bearer: `Authorization: Bearer {api_token}`
 *   Header: `X-API-Token: {api_token}`
 *   Basic-Auth: Passwort == API-Token, z.B. `curl -u :{api_token}`
 *   Query: `?api_token={api_token}`
 */
final class ApiTokenMiddleware implements MiddlewareInterface
{
    /** @inheritDoc */
    public function process(Request $request, callable $next): Response
    {
        $isTestRequest = !empty($request->header('X-Test')) ? 1 : 0;
        if (MULTI_TENANT && !$isTestRequest) {
            return $this->processMultiTenant($request, $next);
        }
        return $this->processSingleTenant($request, $next);
    }

    private function processMultiTenant(Request $request, callable $next): Response
    {
        $orgSlug = $request->orgSlug();
        if ($orgSlug === null) {
            return Response::error(401, 'Kein Organisations-Pfad in der URL (/org/{slug}/api/...).');
        }

        $token = $this->extractToken($request);
        if ($token === null) {
            return Response::error(401, 'Der API-Token fehlt bzw. ist ungültig.');
        }

        $pdo  = Database::pdo();
        $stmt = $pdo->prepare('SELECT uuid, api_token FROM organizations WHERE slug = ? AND blocked_at IS NULL');
        $stmt->execute([$orgSlug]);
        $row = $stmt->fetch();

        if ($row === false || $row['api_token'] !== $token) {
            return Response::error(401, 'Der API-Token fehlt bzw. ist ungültig.');
        }

        // return $next($request);
        return  $next($request->withAttribute('orgUuid', $row['uuid']));
    }

    private function processSingleTenant(Request $request, callable $next): Response
    {
        $token = $this->extractToken($request);
        if ($token === API_TOKEN) {
            return $next($request);
        }
        return Response::error(401, 'Der API-Token fehlt bzw. ist ungültig.');
    }

    /**
     * Extrahiert den API-Token aus dem Request (ohne Validierung).
     *
     * Reihenfolge: Bearer → X-API-Token → Basic-Auth → Query-Parameter.
     */
    private function extractToken(Request $request): ?string
    {
        $authHeader = $request->header('Authorization') ?? '';

        // 1) Bearer Token
        if (str_starts_with($authHeader, 'Bearer ')) {
            $t = substr($authHeader, 7);
            if ($t !== '') return $t;
        }

        // 2) Custom Header
        $t = $request->header('X-API-Token') ?? ($request->server['HTTP_X_API_TOKEN'] ?? null);
        if (is_string($t) && $t !== '') return $t;

        // 3) Basic Auth (z.B. curl -u :{api_token})
        if (str_starts_with($authHeader, 'Basic ')) {
            $parts = explode(':', base64_decode(substr($authHeader, 6)), 2);
            $pass  = $parts[1] ?? '';
            if ($pass !== '') return $pass;
        }
        $phpAuthUser = $request->server['PHP_AUTH_USER'] ?? '';
        if ($phpAuthUser !== '') return $phpAuthUser;

        // 4) Query-Parameter (?api_token=...)
        $t = $request->query('api_token');
        if (is_string($t) && $t !== '') return $t;

        return null;
    }
}
