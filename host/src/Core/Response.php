<?php
declare(strict_types=1);

namespace App\Core;

/**
 * Diese Klasse stellt eine HTTP-Antwort dar.
 *
 * Sie ist als readonly definiert, um Unveränderlichkeit zu gewährleisten.
 *
 * Beispiel:
 * <code>
 * return Response::json(['success' => true]);
 * </code>
 */
final readonly class Response
{
    /** 
     * Normalisierte HTTP-Header (Keys in Kleinbuchstaben).
     * Wird separat definiert, damit wir die Eingabe im Konstruktor vor der Zuweisung normalisieren können.
     * @var array<string, string> 
     */
    public array $headers;

    // ------------------------------------------------------------------------
    // --- Konstruktor ---
    // ------------------------------------------------------------------------

    /**
     * Konstruktor für eine HTTP-Antwort.
     *
     * @param int $status HTTP-Statuscode (Standard: 200 OK)
     * @param array $headers Assoziatives Array mit HTTP-Headern (Standard: Content-Type für JSON)
     * @param string $body Der Antwort-Body als String (Standard: leerer String)
     */
    public function __construct(
        public int $status = 200,
        array $headers = ['Content-Type' => 'application/json; charset=utf-8'],
        public string $body = ''
    ) {
        // Headers normalisieren (in Kleinbuchstaben umwandeln)
        $this->headers = array_change_key_case($headers, CASE_LOWER);
    }

    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------

    /**
     * Erstellt eine JSON-Response.
     *
     * Kodiert die übergebenen Daten als JSON mit UTF-8 und ohne Escaping von Slashes und Unicode-Zeichen.
     * Falls das JSON-Encoding fehlschlägt, wird automatisch eine 500-Fehlerantwort zurückgegeben.
     *
     * @param ?array $data Die zu kodierenden Daten
     * @param int $status HTTP-Statuscode (Standard: 200 OK)
     * @param array $headers Zusätzliche HTTP-Header (werden mit Content-Type: application/json zusammengeführt)
     * @return self Eine neue Response-Instanz mit JSON-Body
     */
    public static function json(?array $data, int $status = 200, array $headers = []): self
    {
        $json = json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        if (!is_string($json)) {
            // Fallback: Wenn JSON-Encoding fehlschlägt, liefern wir einen klaren Serverfehler
            $json = json_encode(
                ['error' => HttpStatus::defaultText(500)],
                JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE
            ) ?: '{"error":"Internal Server Error"}';

            $status = 500;
        }

        return new self(
            $status,
            $headers + ['content-type' => 'application/json; charset=utf-8'],
            $json
        );
    }

    /**
     * Erstellt eine leere Antwort (ohne Body).
     *
     * Nützlich für Statuscodes wie 204 No Content.
     *
     * @param int $status HTTP-Statuscode (Standard: 204 No Content)
     * @param array $headers Zusätzliche HTTP-Header
     * @return self Eine neue Response-Instanz ohne Body
     */
    public static function empty(int $status = 204, array $headers = []): self
    {
        return new self($status, $headers, '');
    }

    /**
     * Loggt die Nachricht und erstellt eine standardisierte JSON-Fehlerantwort.
     *
     * Abhängig vom Statuscode wird folgender Log-Level verwendet:
     * - 2xx → DEBUG
     * - 3xx → INFO
     * - 4xx → WARN bei potenziellen Hackerangriff (401 Unauthorized, 403 Forbidden, 413 Payload Too Large, 429 Too Many Requests) oder bei Datenkonflikt (409), sonst INFO
     * - 5xx → ERROR
     *
     * @param int $status HTTP-Statuscode (typisch: 4xx/5xx).
     * @param string $message Interne/entwicklerfreundliche Nachricht. Wird nur im Debug-Mode (`DEBUG=true`) an den Client gesendet.
     * @param array $context Optionaler Log-Kontext (z.B. ip, ua, user_uuid, route, …).
     * @return self Eine neue Response-Instanz mit JSON-Body
     *
     * @see HttpStatus Für HTTP-Statuscode-Konstanten und Standardtexte
     */
    public static function error(int $status, string $message = '', array $context = []): self
    {
        if ($message === '') {
            $message = HttpStatus::defaultText($status);
        }

        // Fehler loggen

        if ($status >= 500) {
            $level = 'ERROR';
        }
        else if ($status >= 400) {
            $level = in_array($status, [401, 403, 409, 413, 429], true) ? 'WARN' : 'INFO';
        }
        else if ($status >= 300) {
            $level = 'INFO';
        }
        else { // 2xx
            $level = 'DEBUG';
        }

        $context += ['status' => $status];
        
        // Stacktrace für Kontext hinzufügen (ohne Argumente für Performance)
        $trace = debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS, 2);
        if (isset($trace[1])) {
            $context += [
                'file' => $trace[1]['file'] ?? null,
                'line' => $trace[1]['line'] ?? null,
                'trace' => $trace,
            ];
        }

        Logger::log($level, $message, $context);

        // Antwort erstellen

        $data = ['error' => HttpStatus::defaultText($status)];
        if (DEBUG) {
            $data['message'] = $message;
            $data['status'] = $status;
        }
        return self::json($data, $status);
    }

    /**
     * Fügt einen HTTP-Header hinzu und gibt eine neue Response-Instanz zurück.
     *
     * Diese Methode ist immutabel: Das Original-Objekt wird nicht verändert,
     * sondern eine Kopie mit dem zusätzlichen Header wird zurückgegeben.
     * Der Header-Name wird automatisch in Kleinbuchstaben konvertiert.
     *
     * @param string $name Name des Headers
     * @param string $value Wert des Headers
     * @return self Eine neue Response-Instanz mit dem zusätzlichen Header
     */
    public function withHeader(string $name, string $value): self
    {
        // Da die Klasse readonly ist, erstellen wir eine neue Instanz mit den erweiterten Headern.
        $newHeaders = $this->headers;
        $newHeaders[strtolower($name)] = $value;

        return new self($this->status, $newHeaders, $this->body);
    }

    /**
     * Sendet die HTTP-Antwort an den Client.
     *
     * Setzt den HTTP-Statuscode, sendet alle konfigurierten Header und gibt den Response-Body aus.
     *
     * Achtung: Diese Methode hat Seiteneffekte und sollte nur einmal pro Request aufgerufen werden.
     */
    public function send(): void
    {
        if (headers_sent()) {
            return;
        }

        http_response_code($this->status);
        foreach ($this->headers as $k => $v) {
            header($k . ': ' . $v);
        }
        echo $this->body;
    }
}