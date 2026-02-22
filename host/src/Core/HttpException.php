<?php
declare(strict_types=1);

namespace App\Core;

use RuntimeException;
use Throwable;

/**
 * Diese Klasse stellt eine HTTP-Exception dar.
 *
 * `HttpException` wird verwendet, um HTTP-spezifische Fehler zu signalisieren.
 * Sie erweitert RuntimeException und speichert zusätzlich einen HTTP-Statuscode.
 *
 * Verwendungsbeispiel:
 * <code>
 * throw new HttpException(422, 'Validierung fehlgeschlagen');
 * </code>
 *
 * @see HttpStatus Für HTTP-Statuscode-Konstanten und Standardtexte
 */
final class HttpException extends RuntimeException
{
    /**
     * Erstellt eine neue HTTP-Exception mit dem angegebenen Statuscode.
     *
     * @param int $status HTTP-Statuscode (z.B. 500).
     * @param string $message Fehlermeldung.
     * @param Throwable|null $previous Vorherige Exception für Exception-Chaining. Dies ermöglicht die Beibehaltung der ursprünglichen Exception im Stack-Trace. Standard: null.
     */
    public function __construct(
        private readonly int $status,
        string $message = '',
        ?Throwable $previous = null
    ) {
        parent::__construct($message, 0, $previous);
    }

    /**
     * Gibt den HTTP-Statuscode dieser Exception zurück.
     *
     * @return int Der HTTP-Statuscode (z.B. 500)
     */
    public function getStatus(): int
    {
        return $this->status;
    }
}