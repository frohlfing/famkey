<?php
declare(strict_types=1);

namespace App\Core;

use Throwable;

/**
 * Diese Klasse verarbeitet alle nicht abgefangenen Exceptions und wandelt sie in strukturierte
 * JSON-Antworten um. Im Debug-Modus werden zusätzliche Details zur Exception ausgegeben.
 */
final readonly class ErrorHandler
{
    /**
     * Behandelt eine Exception und gibt eine entsprechende Response zurück.
     *
     * Diese Methode loggt die Exception mit Kontextinformationen und erstellt eine
     * JSON-Antwort für den Client. Bei HttpExceptions wird der spezifische Statuscode
     * verwendet, ansonsten wird 500 (Internal Server Error) zurückgegeben.
     *
     * Im Debug-Modus (`DEBUG=true`) enthält die Antwort zusätzliche Informationen:
     * - Exception-Klassenname
     * - Fehlermeldung
     * - Statuscode
     * - Dateiname und Zeilennummer
     * - Stack-Trace
     *
     * @param Throwable $e Die zu behandelnde Exception
     * @param Request $request Die aktuelle HTTP-Anfrage
     * @return Response JSON-Response mit Fehlerinformationen
     */
    public function handle(Throwable $e, Request $request): Response
    {
        // Statuscode ermitteln: Bei HttpException den spezifischen Code verwenden, sonst 500
        $status = 500;
        if ($e instanceof HttpException) {
            $status = $e->getStatus();
        }

        // Exception mit Kontextinformationen loggen
        Logger::error($e->getMessage(), [
            'exception' => get_class($e),
            'status' => $status,
            'file' => $e->getFile(),
            'line' => $e->getLine(),
            'trace' => array_slice($e->getTrace(), 0, 2),
            'method' => $request->method,
            'path' => $request->path,
        ]);

        // Basis-Payload mit Standard-Fehlertext erstellen
        $data = ['error' => HttpStatus::defaultText($status)];
        if (DEBUG) {
            $data['message'] = $e->getMessage();
            $data['exception'] = get_class($e);
            $data['status'] = $status;
        }

        return Response::json($data, $status);
    }
}