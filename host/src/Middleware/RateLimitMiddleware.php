<?php
declare(strict_types=1);

namespace App\Middleware;

use App\Core\MiddlewareInterface;
use App\Core\Request;
use App\Core\Response;

/**
 * Rate-Limiting.
 *
 * Diese Middleware erzwingt ein Rate-Limit pro Client und pro Zeitfenster.
 *
 * Wenn das Limit überschritten wird, wird die Anfrage mit dem Statuscode 429 (Too Many Requests) beendet.
 *
 * Konfiguration (siehe `config.php`):
 * - `RATE_LIMIT` (maximale Anzahl Einträge pro Minute; 0 == kein Limit)
 * - Zeitfenster ist fix (60 Sekunden).
 *
 * Request-Header (optional, nur wenn `DEBUG=true`, überschreibt Konfiguration):
 * - `X-RateLimit-Limit`: Max. Requests pro Zeitfenster (0 == kein Limit)
 *
 * Antwort-Header:
 * - `X-RateLimit-Limit`: Max. Requests pro Zeitfenster
 * - `X-RateLimit-Remaining`: verbleibende Requests im aktuellen Zeitfenster
 * - `X-RateLimit-Reset`: Sekunden bis zum Reset des Zeitfensters
 *
 * Storage:
 * - `sys_get_temp_dir()`/`famkey_rate_limit`
 */
final class RateLimitMiddleware implements MiddlewareInterface
{
    /**
     * Dauer des Zeitfensters in Sekunden (1 Minute).
     */
    private int $windowSeconds = 60;

    /** @inheritDoc */
    public function process(Request $request, callable $next): Response
    {
        [$enabled, $limit] = $this->resolveLimit($request);

        if (!$enabled || $limit <= 0) {
            return $next($request);
        }

        $ip = $this->clientIp($request);

        $now = time();
        $bucket = intdiv($now, $this->windowSeconds);
        $resetInSeconds = (($bucket + 1) * $this->windowSeconds) - $now;

        $key = hash('sha256', $ip . '|' . $request->path . '|' . $bucket);

        $dir = rtrim(sys_get_temp_dir(), '\\/') . DIRECTORY_SEPARATOR . 'famkey_rate_limit';
        if (!is_dir($dir)) {
            @mkdir($dir, 0777, true);
        }

        $file = $dir . DIRECTORY_SEPARATOR . $key . '.txt';
        $newCount = 0;
        $fh = @fopen($file, 'c+');
        if ($fh === false) {
            // Storage nicht verfügbar -> nicht hart abbrechen
            return $next($request);
        }

        try {
            if (!flock($fh, LOCK_EX)) {
                return $next($request);
            }
            $content = stream_get_contents($fh);
            $content = is_string($content) ? trim($content) : '';
            $count = ctype_digit($content) ? (int)$content : 0;
            $newCount = $count + 1;
            ftruncate($fh, 0);
            rewind($fh);
            fwrite($fh, (string)$newCount);
            fflush($fh);
            flock($fh, LOCK_UN);
        }
        finally {
            fclose($fh);
        }

        $remaining = max(0, $limit - $newCount);

        // Header werden immer gesetzt, sobald Rate-Limit aktiv ist – auch bei 429.
        $limitHeader = (string)$limit;
        $remainingHeader = (string)$remaining;
        $resetHeader = (string)max(0, $resetInSeconds);

        if ($newCount > $limit) {
            return Response::error(429, 'Rate-Limit erreicht.')
                ->withHeader('X-RateLimit-Limit', $limitHeader)
                ->withHeader('X-RateLimit-Remaining', '0')
                ->withHeader('X-RateLimit-Reset', $resetHeader);
        }

        $response = $next($request);
        return $response
            ->withHeader('X-RateLimit-Limit', $limitHeader)
            ->withHeader('X-RateLimit-Remaining', $remainingHeader)
            ->withHeader('X-RateLimit-Reset', $resetHeader);
    }

    /**
     * Ermittelt das Limit.
     *
     * @param Request $request
     * @return array{0:bool,1:int} [enabled, limit]
     */
    private function resolveLimit(Request $request): array
    {
        // DEBUG=false -> immer aktiv mit Default
        if (!DEBUG) {
            return [true, RATE_LIMIT];
        }

        // DEBUG=true -> Header kann überschreiben
        $hdr = $request->header('X-RateLimit-Limit');

        // kein Header -> aktiv mit Default
        if ($hdr === null) {
            return [true, RATE_LIMIT];
        }

        $hdr = trim($hdr);

        // leerer Header -> wie kein Header: aktiv mit Default
        if ($hdr === '') {
            return [true, RATE_LIMIT];
        }

        // "0" -> kein Limit
        if ($hdr === '0') {
            return [false, 0];
        }

        // >0 -> Override (nur numerisch)
        if (ctype_digit($hdr)) {
            $n = (int)$hdr;
            if ($n > 0) {
                return [true, $n];
            }
        }

        // Ungültig -> sicherheitsfreundlich: aktiv mit Default
        return [true, RATE_LIMIT];
    }

    /**
     * Ermittelt die Client-IP (Minimal-Setup: REMOTE_ADDR).
     *
     * @param Request $request
     * @return string
     */
    private function clientIp(Request $request): string
    {
        $ip = (string)($request->server['REMOTE_ADDR'] ?? '');
        return $ip !== '' ? $ip : '0.0.0.0';
    }
}