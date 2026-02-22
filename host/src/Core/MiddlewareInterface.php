<?php
declare(strict_types=1);

namespace App\Core;

/**
 * Interface für die Middleware
 *
 * Zweck:
 * - Definiert die Middleware-Signatur.
 * - Ähnlich PSR-15: Middleware kann Request prüfen/ändern und entweder:
 *   - $next($request) aufrufen (Pipeline fortsetzen)
 *   - oder selbst eine Response zurückgeben (Pipeline abbrechen)
 *
 * Beispiel:
 * <code>
 * final class ExampleMiddleware implements MiddlewareInterface {
 *     public function process(Request $request, callable $next): Response {
 *         // Vorher: prüfen/ändern
 *         $response = $next($request);
 *         // Nachher: Response anpassen
 *         return $response->withHeader('x-example', '1');
 *     }
 * }
 * </code>
 */
interface MiddlewareInterface
{
    /**
     * Verarbeitet eine Anfrage und gibt eine Antwort zurück.
     *
     * @param Request $request Aktuelle Anfrage.
     * @param callable(Request):Response $next Nächster Schritt der Pipeline.
     * @return Response HTTP-Antwort.
     */
    public function process(Request $request, callable $next): Response;
}