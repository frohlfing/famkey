<?php
declare(strict_types=1);

namespace App\Middleware;

use App\Core\MiddlewareInterface;
use App\Core\Request;
use App\Core\Response;

/**
 * Globaler, benutzerunabhängiger API-Schutz.
 *
 * Diese Middleware überprüft den übermittelten API-Token.
 * Fehlt der Token oder ist er ungültig, wird die Anfrage mit dem Statuscode 401 (Unauthorized) beendet.
 *
 * Folgende Token-Übermittlung wird unterstützt:
 * - Bearer: `Authorization: Bearer {api_token}`
 * - Header: `X-API-Token: {api_token}`
 * - Basic-Auth: Passwort == API-Token, z.B. `curl -u :{api_token}`
 * - Query: `api_token={api_token}`
 *
 *
 * Beispiel (Curl):
 * <code>
 * curl "https://{host}/api" -H "Authorization: Bearer {api_token}"
 * </code>
 */
final class ApiTokenMiddleware implements MiddlewareInterface
{
    /** @inheritDoc */
    public function process(Request $request, callable $next): Response
    {
        // 1) Bearer Token
        $authHeader = $request->header('Authorization');
        if ($authHeader === 'Bearer ' . API_TOKEN) {
            return $next($request);
        }

        // 2) Custom Header
        // todo das Request-Objekt sollte eine Funktion server(key) bereitstellen, die null zurückgibt, wenn der Parameter nicht existiert.
        if ($request->header('X-API-Token') === API_TOKEN || (isset($request->server['HTTP_X_API_TOKEN']) && $request->server['HTTP_X_API_TOKEN'] === API_TOKEN)) {
            return $next($request);
        }

        // 3) Basic Auth (curl -u :meinGeheimerToken123)
        $authHeader = $request->header('Authorization');
        if (str_starts_with($authHeader, 'Basic ')) {
            [, $pass] = explode(':', base64_decode(substr($authHeader, 6)));
            if ($pass === API_TOKEN) {
                return $next($request);
            }
        }
        else if (isset($request->server['PHP_AUTH_USER']) && $request->server['PHP_AUTH_USER'] === API_TOKEN) {
            return $next($request);
        }

        // 4) GET-Parameter ?api_token=...
        // todo das Request-Objekt sollte eine Funktion query(key) bereitstellen, die null zurückgibt, wenn der Parameter nicht existiert.
        if ($request->query('api_token') === API_TOKEN) {
            return $next($request);
        }

        return Response::error(401, 'Der API-Token fehlt bzw. ist ungültig.');
    }
}