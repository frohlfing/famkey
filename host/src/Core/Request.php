<?php 

/** @noinspection PhpUnused */

declare(strict_types=1);

namespace App\Core;

/**
 * Diese Klasse stellt ein Request-Objekt dar.
 *
 * Die Request-Klasse kapselt alle Informationen einer eingehenden HTTP-Anfrage.
 * Sie ist als readonly definiert, um Unveränderlichkeit zu gewährleisten.
 * Änderungen an Attributen erfolgen durch Erstellen neuer Instanzen (siehe withAttribute()).
 *
 * Eigenschaften:
 * - `method`: HTTP-Methode (`GET`, `POST`, `PUT`, `DELETE`, etc.)
 * - `path`: Angefragter Pfad (ohne Query-String), normalisiert mit führendem `/`
 * - `query`: Assoziatives Array der Query-Parameter (`$_GET`)
 * - `headers`: Normalisierte HTTP-Header (Kleinbuchstaben als Keys)
 * - `rawBody`: Roher Request-Body als String
 * - `cookies`: Cookie-Daten (`$_COOKIE`)
 * - `server`: Server-Variablen (`$_SERVER`)
 * - `attributes`: Private Attribute für Middleware/Router-Daten
 */
final readonly class Request
{
    // ------------------------------------------------------------------------
    // --- Konstruktor ---
    // ------------------------------------------------------------------------
    
    /**
     * Konstruktor für das Request-Objekt.
     *
     * @param string $method HTTP-Methode (z.B. GET, POST, PUT, DELETE)
     * @param string $path Angefragter Pfad, normalisiert mit führendem /
     * @param array $query Query-Parameter als assoziatives Array
     * @param array $headers HTTP-Header als assoziatives Array (normalisiert nach Kleinbuchstaben)
     * @param string $rawBody Roher Request-Body als String
     * @param array $cookies Cookie-Daten als assoziatives Array
     * @param array $server Server-Variablen als assoziatives Array
     * @param array $attributes Private Attribute für zusätzliche Daten (z.B. von Middleware)
     */
    public function __construct(
        public string $method,
        public string $path,
        public array  $query,
        public array  $headers,
        public string $rawBody,
        public array  $cookies,
        public array  $server,
        private array $attributes = [],
    ) {}

    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------
    
    /**
     * Erstellt ein Request-Objekt aus den globalen PHP-Variablen.
     *
     * Diese Factory-Methode liest die globalen Variablen $_SERVER, $_GET, $_COOKIE
     * und den Request-Body (php://input) aus und erstellt daraus ein neues Request-Objekt.
     *
     * Besonderheit:
     * - Wenn der Pfad mit "/api/" beginnt, wird dieses Präfix entfernt
     * - Header werden normalisiert (Kleinbuchstaben)
     * - REQUEST_METHOD wird zu Großbuchstaben konvertiert (Standard: GET)
     *
     * @return self Neues Request-Objekt mit den Daten der aktuellen Anfrage
     */
    public static function fromGlobals(): self
    {
        $method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');

        $path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
        $path = '/' . ltrim($path, '/');

        // Multi-Tenant: /org/{slug}/api/... → org_slug extrahieren, Präfix entfernen
        if (preg_match('#^/org/([a-z0-9][a-z0-9-]{0,63})(/.*)$#', $path, $m)) {
            $attributes['orgSlug'] = $m[1];
            $path = $m[2];
        }

        if (str_starts_with($path, '/api/')) {
            $path = substr($path, 4); // entfernt "/api"
            $path = '/' . ltrim($path, '/');
        }

        $headers = function_exists('getallheaders') ? (getallheaders() ?: []) : [];
        $rawBody = (string) file_get_contents('php://input');

        return new self(
            method: $method,
            path: $path,
            query: $_GET ?? [],
            headers: self::normalizeHeaders($headers),
            rawBody: $rawBody,
            cookies: $_COOKIE ?? [],
            server: $_SERVER ?? [],
            attributes: $attributes,
        );
    }

    /**
     * Erstellt eine neue Request-Instanz mit einem zusätzlichen Attribut.
     *
     * Da die Klasse als readonly definiert ist, wird eine neue Instanz mit den
     * aktualisierten Attributen zurückgegeben. Diese Methode wird typischerweise
     * von Middleware verwendet, um zusätzliche Daten (z.B. authUserUuid, routeParams)
     * an den Request anzuhängen.
     *
     * @param string $key Name des Attributs
     * @param mixed $value Wert des Attributs
     * @return self Neue Request-Instanz mit dem hinzugefügten Attribut
     */
    public function withAttribute(string $key, mixed $value): self
    {
        $attributes = $this->attributes;
        $attributes[$key] = $value;

        return new self(
            method: $this->method,
            path: $this->path,
            query: $this->query,
            headers: $this->headers,
            rawBody: $this->rawBody,
            cookies: $this->cookies,
            server: $this->server,
            attributes: $attributes,
        );
    }
    
    // /**
    //  * Gibt die Organisations-UUID zurück (Multi-Tenant-Modus).
    //  *
    //  * Wird von Request::fromGlobals() aus dem URL-Pfad /org/{uuid}/api/... extrahiert.
    //  * Ist null im Single-Tenant-Betrieb (wenn MULTI_TENANT = false oder wenn kein /org/-Präfix vorhanden).
    //  *
    //  * @return string|null
    //  */
    // public function orgUuid(): ?string
    // {
    //     $v = $this->attributes['orgUuid'] ?? null;
    //     return is_string($v) && $v !== '' ? $v : null;
    // }

     /**
     * Gibt den URL-Slug der Organisation zurück (Multi-Tenant-Modus).
     *
     * Wird von Request::fromGlobals() aus dem URL-Pfad /org/{slug}/api/... extrahiert.
     * Ist null im Single-Tenant-Betrieb (wenn MULTI_TENANT = false oder wenn kein /org/-Präfix vorhanden).
     *
     * @return string|null
     */
    public function orgSlug(): ?string
    {
        $v = $this->attributes['orgSlug'] ?? null;
        return is_string($v) && $v !== '' ? $v : null;
    }

    /**
     * Gibt die Organisations-UUID zurück (Multi-Tenant-Modus).
     *
     * Wird von der ApiTokenMiddleware nach dem Slug-Lookup in der DB als Attribut gesetzt.
     * Ist null, solange die Middleware nicht durchlaufen wurde oder im Single-Tenant-Betrieb.
     *
     * @return string|null
     */
    public function orgUuid(): ?string
    {
        $v = $this->attributes['orgUuid'] ?? null;
        return is_string($v) && $v !== '' ? $v : null;
    }

    /**
     * Gibt den Wert eines HTTP-Headers zurück.
     *
     * Der Header-Name wird zu Kleinbuchstaben konvertiert, da alle Header
     * bereits normalisiert gespeichert sind.
     *
     * @param string $name Name des Headers (Case-Insensitive)
     * @return string|null Wert des Headers oder null, wenn nicht vorhanden
     */
    public function header(string $name): ?string
    {
        $key = strtolower($name);
        return $this->headers[$key] ?? null;
    }

    /**
     * Gibt die UUID des authentifizierten Benutzers zurück.
     *
     * Diese Methode liefert die UUID des Benutzers, die durch die AuthMiddleware
     * nach erfolgreicher RSA-Signatur-Prüfung gesetzt wurde.
     *
     * @return string|null UUID des authentifizierten Benutzers oder null, wenn nicht authentifiziert
     */
    public function authUserUuid(): ?string
    {
        $v = $this->attributes['authUserUuid'] ?? null;
        return is_string($v) && $v !== '' ? $v : null;
    }

    /**
     * Prüft, ob die aktuelle Route geschützt ist.
     *
     * Diese Methode gibt an, ob für die Route eine Authentifizierung erforderlich ist.
     * Der Wert wird vom Router als Attribut 'routeProtected' gesetzt.
     *
     * @return bool true, wenn die Route geschützt ist, sonst false
     */
    public function isProtectedRoute(): bool
    {
        $v = $this->attributes['routeProtected'] ?? false;
        return $v === true;
    }
    
    /**
     * Holt einen Wert aus den Route-Parametern (z.B. {id}).
     *
     * @param string $key Name des Parameters (ohne Klammern)
     * @param string|null $default Standardwert
     * @return string|null
     */
    public function route(string $key, ?string $default = null): ?string
    {
        $routeParams = $this->attributes['routeParams'] ?? [];
        return is_array($routeParams) ? ($routeParams[$key] ?? $default) : $default;
    }

    /**
     * Holt einen Wert explizit aus dem JSON-Body.
     *
     * @param string $key Der gesuchte Schlüssel
     * @param mixed $default Rückgabewert, falls Schlüssel nicht existiert
     * @return mixed
     */
    public function body(string $key, mixed $default = null): mixed
    {
        $json = $this->attributes['json'] ?? null; // Array erwartet
        return is_array($json) && array_key_exists($key, $json) ? $json[$key] : $default;
    }

    /**
     * Holt einen Wert explizit aus den Query-Parametern.
     *
     * @param string $key Der gesuchte Schlüssel
     * @param mixed $default Rückgabewert, falls Schlüssel nicht existiert
     * @return mixed
     */
    public function query(string $key, mixed $default = null): mixed
    {
        return array_key_exists($key, $this->query) ? $this->query[$key] : $default;
    }
    
    /**
     * Holt einen Wert aus Route, dem JSON-Body oder den Query-Parametern (in dieser Reihenfolge).
     *
     * @param string $key Parametername
     * @param mixed $default Rückgabewert, falls Parameter nicht existiert
     * @return mixed
     */
    public function param(string $key, mixed $default = null): mixed
    {
        // 1. Route Params (z.B. /users/{uuid})
        $routeParams = $this->attributes['routeParams'] ?? [];
        if (array_key_exists($key, $routeParams)) {
            return $routeParams[$key];
        }

        // 2. JSON Body
        $json = $this->attributes['json'] ?? null; // Array erwartet
        if (is_array($json) && array_key_exists($key, $json)) {
            return $json[$key];
        }

        // 3. Query (?foo=bar)
        if (array_key_exists($key, $this->query)) {
            return $this->query[$key];
        }

        return $default;
    }

    /**
     * Prüft, ob alle angegebenen Parameter vorhanden sind (in der Route, JSON-Body oder im Query).
     *
     * @param list<string> $keys Liste der zu prüfenden Parameter
     * @return bool true wenn alle vorhanden, sonst false
     */
    public function has(array $keys): bool
    {
        return array_all($keys, fn($key) => $this->param($key) !== null);
    }

    /**
     * Stellt sicher, dass die angegebenen Parameter vorhanden sind (in der Route, JSON-Body oder im Query).
     *
     * Wenn ein Parameter fehlt, wird eine HttpException (422) geworfen.
     *
     * @param list<string> $keys Liste der Pflichtfelder
     * @param bool $allowEmpty Wenn false (Standard), werfen auch leere Strings ("") einen Fehler.
     * @throws HttpException (422) wenn ein Feld fehlt
     */
    public function ensureHas(array $keys, bool $allowEmpty = false): void
    {
        foreach ($keys as $key) {
            $val = $this->param($key);

            // 1. Existenz-Prüfung
            if ($val === null) {
                throw new HttpException(422, "Erforderlicher Parameter fehlt: $key");
            }

            // 2. Leer-Prüfung
            if (!$allowEmpty && $val === '') {
                throw new HttpException(422, "Parameter darf nicht leer sein: $key");
            }
        }
    }

    /**
     * Holt einen Wert als String (Type-Safe).
     *
     * @param string $key Parametername
     * @param string $default Standardwert, falls Parameter fehlt
     * @return string Parameterwert
     */
    public function string(string $key, string $default = ''): string
    {
        $val = $this->param($key);
        return is_scalar($val) ? (string)$val : $default;
    }

    /**
     * Holt einen Wert als Integer (Type-Safe).
     *
     * @param string $key Parametername
     * @param int $default Standardwert, falls Parameter fehlt
     * @return int Parameterwert
     */
    public function int(string $key, int $default = 0): int
    {
        $val = $this->param($key);
        return is_numeric($val) ? (int)$val : $default;
    }

    /**
     * Holt einen Wert als Boolean.
     * Erkennt "true", "1", "on", "yes" als true.
     *
     * @param string $key Parametername
     * @param bool $default Standardwert, falls Parameter fehlt
     * @return bool Parameterwert
     */
    public function bool(string $key, bool $default = false): bool
    {
        $val = $this->param($key);
        return filter_var($val, FILTER_VALIDATE_BOOLEAN, ['flags' => FILTER_NULL_ON_FAILURE]) ?? $default;
    }

    /**
     * Liest ein Datum aus dem Input und normalisiert es auf UTC ISO-8601.
     *
     * Das Format entspricht der API-Spezifikation: YYYY-MM-DDThh:mm:ss.vvvZ
     * Beispiel: 2026-01-28T14:30:00.123Z
     *
     * @param string $key Parametername
     * @param string $default Standardwert (sollte bereits im ISO-Format sein)
     * @return string Normalisierter ISO-String oder Default-Wert
     */
    public function date(string $key, string $default = '1970-01-01T00:00:00.000Z'): string
    {
        $val = $this->param($key);
        if (!is_scalar($val) || $val === '') {
            return $default;
        }
        return Time::normalizeIso8601((string)$val) ?? $default;
    }

    /**
     * Holt einen Wert als Array.
     *
     * @param string $key Parametername
     * @param array $default Standardwert, falls Parameter fehlt oder kein Array ist
     * @return array Parameterwert
     */
    public function array(string $key, array $default = []): array
    {
        $val = $this->param($key);
        return is_array($val) ? $val : $default;
    }

    // ------------------------------------------------------------------------
    // --- Private Methoden ---
    // ------------------------------------------------------------------------

    /**
     * Normalisiert HTTP-Header zu einem einheitlichen Format.
     *
     * Alle Header-Namen werden zu Kleinbuchstaben konvertiert.
     * Array-Werte werden zu einem kommaseparierten String zusammengefügt.
     *
     * @param array $headers Rohe HTTP-Header (z.B. von getallheaders())
     * @return array Normalisiertes assoziatives Array (lowercase keys, string values)
     */
    private static function normalizeHeaders(array $headers): array
    {
        $out = [];
        foreach ($headers as $k => $v) {
            $out[strtolower((string)$k)] = is_array($v) ? implode(',', $v) : (string)$v;
        }
        return $out;
    }
}