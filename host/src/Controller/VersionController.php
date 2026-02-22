<?php

declare(strict_types=1);

namespace App\Controller;

use App\Core\Request;
use App\Core\Response;

/**
 * Controller für Versionsabfragen.
 */
final class VersionController
{
    /**
     * Liefert die API-Version und die minimal erforderliche Client-Minor-Version.
     *
     * Endpunkt: <code>GET /version</code>
     *
     * Header:
     * <code>
     * Authorization: Bearer {api_token}
     * </code>
     *
     * Query: -
     *
     * Body: -
     *
     * Antwort (200 OK):
     * <code>
     * {
     *   "service": "priVault",
     *   "major": {integer},
     *   "minor": {integer},
     *   "patch": {integer}
     *   "required_client_minor": {integer}
     * }
     * </code>
     *
     * Antwort (401, 500):
     * <code>
     * { "error": "{Fehlermeldung}" }
     * </code>
     *
     * Mögliche Statuscodes:
     * - 200 OK
     * - 401 Unauthorized: API-Token fehlt oder ist ungültig
     * - 500 Internal Server Error
     *
     * @param Request $request
     * @return Response
     * @noinspection PhpUnusedParameterInspection
     */
    public function version(Request $request): Response
    {
        $version = explode('.', VERSION);
        return Response::json([
            'service' => 'priVault',
            'major' => (int)$version[0],
            'minor' => (int)$version[1],
            'patch' => (int)$version[2],
            'required_client_minor' => REQUIRED_CLIENT_MINOR,
        ]);
    }
}