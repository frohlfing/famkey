<?php
declare(strict_types=1);

namespace App\Core;

/**
 * Diese Klasse stellt eine Hilfsfunktion für den Standard-Text eines HTTP-Statuscodes bereit.
 *
 * Beispiel:
 * <code>
 * $data = ['error' => HttpStatus::defaultText($status)];
 * </code>
 */
final class HttpStatus
{
    /**
     * Liefert den Standard-Text zu einem HTTP-Statuscode.
     *
     * @param int $status HTTP-Statuscode (z.B. 404).
     * @return string Standard-Text (z.B. "Not Found").
     */
    public static function defaultText(int $status): string
    {
        return match ($status) {
            // ===== 200er-Bereich: erfolgreich =====
            200 => 'OK',                    // Die Abfrage der Ressource war erfolgreich.
            201 => 'Created',               // Die Ressource wurde erfolgreich erstellt.
            204 => 'No Content',            // Die Antwort beinhaltet keine Daten (z.B. bei der Löschung einer Resource).
            206 => 'Partial Content',       // Die Antwort beinhaltet nur einen Teil der angefragten Liste.

            // ===== 400er-Bereich: Anfrage nicht erfolgreich =====
            400 => 'Bad Request',           // Die Anfrage ist fehlerhaft aufgebaut (Syntaxfehler in JSON).
            401 => 'Unauthorized',          // Unbefugter Zugriffsversuch. API-Token/RSA-Signatur fehlt bzw. ist ungültig.
            403 => 'Forbidden',             // Der Benutzer ist authentifiziert, verfügt jedoch nicht über die erforderliche Berechtigung.
            404 => 'Not Found',             // Entweder stimmt die URL zum Webservice nicht (Content-Type unbestimmt), oder der Endpunkt existiert nicht (message ggf. leer), oder die betroffene Ressource wurde nicht gefunden.
            405 => 'Method Not Allowed',    // Die angegebene HTTP-Methode ist für den Endpunkt nicht erlaubt.
            409 => 'Conflict',              // Die Anfrage kollidiert mit aktuellem Zustand der Ressource (z.B. gesperrt), oder eine neue Ressource soll angelegt werden, existiert aber bereits.
            413 => 'Payload Too Large',     // Payload Too Large: Payload ist zu groß (z. B. Attachment-Upload).
            422 => 'Unprocessable Entity',  // Daten sind für die Resource nicht valide (z.B. Pflichtfeld fehlt) und nicht verarbeitbar.
            426 => 'Upgrade Required',      // Die Client-Version ist veraltet.
            429 => 'Too Many Requests',     // Das Rate-Limit wurde überschritten.

            // ===== 500er-Bereich: Ausnahmefehler =====
            500 => 'Internal Server Error', // Etwas Unerwartetes ist aufgetreten.
            501 => 'Not Implemented',       // Funktion noch in Entwicklung.
            503 => 'Service Unavailable',   // Service nicht verfügbar, evtl. temporär überlastet oder geplante Wartung.

            // Fallback
            default => 'Error',
        };
    }
}