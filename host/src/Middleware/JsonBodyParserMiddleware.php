<?php
declare(strict_types=1);

namespace App\Middleware;

use App\Core\MiddlewareInterface;
use App\Core\Request;
use App\Core\Response;

/**
 * JSON-Body-Parser.
 *
 * Diese Middleware parst den Body bei Content-Type `application/json` und legt das Ergebnis in
 * `Request->attributes['json']` ab.
 *
 * - Regeln:
 *   - Wenn Content-Type nicht JSON ist: Middleware ist passiv.
 *   - Wenn Body leer ist: Middleware ist passiv.
 *   - Wenn JSON syntaktisch ungültig ist: 400 Bad Request
 *   - Wenn JSON gültig ist, aber kein Objekt (kein assoc array): 422 Unprocessable Entity
 */
final class JsonBodyParserMiddleware implements MiddlewareInterface
{
    /** @inheritDoc */
    public function process(Request $request, callable $next): Response
    {
        $ct = $request->header('Content-Type') ?? '';
        if (stripos($ct, 'application/json') === false) {
            return $next($request);
        }

        $raw = trim($request->rawBody);
        if ($raw === '') {
            return $next($request);
        }

        $decoded = json_decode($raw, true);

        // Syntaxfehler?
        if (json_last_error() !== JSON_ERROR_NONE) {
            return Response::error(400);
        }

        // Wir erwarten ein JSON-Objekt => assoc array
        if (!is_array($decoded)) {
            return Response::error(422);
        }

        return $next($request->withAttribute('json', $decoded));
    }
}