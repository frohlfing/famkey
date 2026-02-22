<?php

/** @noinspection PhpUnused */

declare(strict_types=1);

namespace App\Core;

/**
 * Diese Klasse verwaltet Routen nach dem Schema: (HTTP-Methode, Pfad) -> Handler.
 *
 * Beispiel:
 * <code>
 * $router = new Router();
 * $router->add('GET', '/users/{id}', [UserController::class, 'show'], protected: false);
 * $match = $router->match('GET', '/users/{id}');
 * </code>
 */
final class Router
{
    /**
     * Interne Routentabelle.
     *
     * Jede Route besteht aus:
     * - method: HTTP-Methode (z.B. GET)
     * - path: Pfad (z.B. "/users/{id}")
     * - regex: Wenn Route dynamisch ist: Kompilierter Regex für das Matching, sonst null
     * - handler: [ControllerClass::class, 'method']
     * - protected: ob RSA-Auth (Identity Proof) erforderlich ist
     *
     * @var list<array{
     *   method:string,
     *   path:string,
     *   regex:string|null,
     *   handler:array{0:class-string,1:string},
     *   protected:bool
     * }>
     */
    private array $routes = [];

    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------
    
    /**
     * Fügt eine Route hinzu.
     *
     * @param string $method HTTP-Methode (GET/POST/PATCH/DELETE).
     * @param string $path Der Pfad, z.B. "/users/{id}".
     * @param array{0:class-string,1:string} $handler Handler im Format [ControllerClass::class, 'method'].
     * @param bool $protected Wenn true, muss AuthMiddleware (RSA) die Anfrage authentifizieren.
     */
    public function add(string $method, string $path, array $handler, bool $protected = false): void
    {
        $normalizedPath = $this->normalizePath($path);

        // Regulären Ausdruck bauen, falls der Pfad dynamisch ist (wenn er Platzhalter enthält)
        if (str_contains($normalizedPath, '{')) {
            // 1. Regex-Zeichen im Pfad maskieren (damit z.B. Punkte nicht als Regex interpretiert werden)
            // {id} wird hier zu \{id\}
            $quoted = preg_quote($normalizedPath, '#');

            // 2. Platzhalter {param} in Named Capture Groups (?P<param>[^/]+) umwandeln
            // Das [^/]+ bedeutet "alles außer einem Slash", was für Pfadsegmente ideal ist (stoppt beim nächsten /).
            // Wir suchen nach \{...\} (da preg_quote die Klammern escaped hat)
            $regex = preg_replace('/\\\{([a-zA-Z0-9_]+)\\\}/', '(?P<$1>[^/]+)', $quoted);

            // 3. Delimiter und Anker hinzufügen
            $regex = '#^' . $regex . '$#';
        }
        else {
            $regex = null;
        }

        $this->routes[] = [
            'method' => strtoupper($method),
            'path' => $normalizedPath,
            'regex' => $regex,
            'handler' => $handler,
            'protected' => $protected,
        ];
    }

    /**
     * Registriert eine GET-Route.
     *
     * @param string $path Der Pfad, z.B. "/users/{id}".
     * @param array{0:class-string,1:string} $handler Handler im Format [ControllerClass::class, 'method']
     * @param bool $protected Wenn true, muss AuthMiddleware (RSA) die Anfrage authentifizieren.
     */
    public function get(string $path, array $handler, bool $protected = false): void
    {
        $this->add('GET', $path, $handler, $protected);
    }

    /**
     * Registriert eine POST-Route.
     *
     * @param string $path Der Pfad, z.B. "/users".
     * @param array{0:class-string,1:string} $handler Handler im Format [ControllerClass::class, 'method']
     * @param bool $protected Wenn true, muss AuthMiddleware (RSA) die Anfrage authentifizieren.
     */
    public function post(string $path, array $handler, bool $protected = false): void
    {
        $this->add('POST', $path, $handler, $protected);
    }

    /**
     * Registriert eine PATCH-Route.
     *
     * @param string $path Der Pfad, z.B. "/users/{id}".
     * @param array{0:class-string,1:string} $handler Handler im Format [ControllerClass::class, 'method']
     * @param bool $protected Wenn true, muss AuthMiddleware (RSA) die Anfrage authentifizieren.
     */
    public function patch(string $path, array $handler, bool $protected = false): void
    {
        $this->add('PATCH', $path, $handler, $protected);
    }

    /**
     * Registriert eine PUT-Route.
     *
     * @param string $path Der Pfad, z.B. "/users/{id}".
     * @param array{0:class-string,1:string} $handler Handler im Format [ControllerClass::class, 'method']
     * @param bool $protected Wenn true, muss AuthMiddleware (RSA) die Anfrage authentifizieren.
     */
    public function put(string $path, array $handler, bool $protected = false): void
    {
        $this->add('PUT', $path, $handler, $protected);
    }

    /**
     * Registriert eine DELETE-Route.
     *
     * @param string $path Der Pfad, z.B. "/users/{id}".
     * @param array{0:class-string,1:string} $handler Handler im Format [ControllerClass::class, 'method']
     * @param bool $protected Wenn true, muss AuthMiddleware (RSA) die Anfrage authentifizieren.
     */
    public function delete(string $path, array $handler, bool $protected = false): void
    {
        $this->add('DELETE', $path, $handler, $protected);
    }

    /**
     * Sucht die passende Route für Methode + Pfad.
     *
     * @param string $method Die HTTP-Methode (GET/POST/PATCH/DELETE).
     * @param string $path Der Pfad, z.B. "/users/{id}".
     * @return array{
     *   handler:array{0:class-string,1:string},
     *   params:array<string,string>,
     *   protected:bool
     * }|null
     */
    public function match(string $method, string $path): ?array
    {
        $method = strtoupper($method);
        $path = $this->normalizePath($path);

        foreach ($this->routes as $r) {
            if ($r['method'] !== $method) {
                continue;  // Methode stimmt nicht überein
            }
            if ($r['regex'] === null) {
                // Statische Route (schneller String-Vergleich)
                if ($r['path'] === $path) {
                    return ['handler' => $r['handler'], 'params' => [], 'protected' => $r['protected']];
                }
            }
            else {
                // Dynamische Route (Regex)
                if (preg_match($r['regex'], $path, $matches)) {
                    // Numerische Indizes entfernen, nur benannte Parameter behalten
                    $params = array_filter($matches, 'is_string', ARRAY_FILTER_USE_KEY);
                    return ['handler' => $r['handler'], 'params' => $params, 'protected' => $r['protected']];
                }
            }
        }

        return null;
    }

    /**
     * Liefert alle erlaubten HTTP-Methoden für den gegebenen Pfad.
     *
     * @param string $path Der Pfad, z.B. "/users/{id}".
     * @return list<string> Z.B. ["GET","POST"] (leer, wenn der Pfad unbekannt ist).
     */
    public function allowedMethods(string $path): array
    {
        $path = $this->normalizePath($path);
        $methods = [];
        foreach ($this->routes as $r) {
            if ($r['regex'] !== null ? preg_match($r['regex'], $path) : $r['path'] === $path) {
                $methods[] = $r['method'];
            }
        }
        $methods = array_values(array_unique($methods));
        sort($methods);
        return $methods;
    }

    /**
     * Read-only Zugriff auf registrierte Routen.
     *
     * @return list<array{
     *   method:string,
     *   path:string,
     *   handler:array{0:class-string,1:string},
     *   protected:bool
     * }>
     */
    public function listRoutes(): array
    {
        $out = [];
        foreach ($this->routes as $r) {
            $out[] = [
                'method' => (string)$r['method'],
                'path' => (string)$r['path'],
                'handler' => $r['handler'],
                'protected' => (bool)$r['protected'],
            ];
        }
        return $out;
    }

    // ------------------------------------------------------------------------
    // --- Private Methoden ---
    // ------------------------------------------------------------------------
    
    /**
     * Normalisiert Pfade, um versehentliche Unterschiede abzufangen.
     *
     * Regeln:
     * - Immer führender Slash
     * - Kein trailing Slash (außer Root "/")
     *
     * Beispiele:
     * - "users" -> "/users"
     * - "/users/" -> "/users"
     * - "/" -> "/"
     *
     * @param string $path Eingabepfad.
     * @return string Normalisierter Pfad.
     */
    private function normalizePath(string $path): string
    {
        // Sicherstellen, dass "/" am Anfang steht
        $path = '/' . ltrim($path, '/');

        // Trailing Slash entfernen
        $path = rtrim($path, '/');

        // Leerstring mit "/" ersetzen
        return $path === '' ? '/' : $path;
    }
}