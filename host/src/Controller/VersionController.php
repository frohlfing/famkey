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
     *   "service": "FamKey",
     *   "sync_protocol_version": {integer},
     *   "min_sync_protocol_version": {integer},
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
        return Response::json([
            'service' => 'FamKey v1 REST-API',
            'sync_protocol_version' => SYNC_PROTOCOL_VERSION,
            'min_sync_protocol_version' => MIN_SYNC_PROTOCOL_VERSION,
        ]);
    }
}