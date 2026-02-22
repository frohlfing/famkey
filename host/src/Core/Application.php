<?php

/** @noinspection PhpUnused */

declare(strict_types=1);

namespace App\Core;

use App\Middleware\ApiTokenMiddleware;
use App\Middleware\AuthMiddleware;
use App\Middleware\CoverageMiddleware;
use App\Middleware\JsonBodyParserMiddleware;
use App\Middleware\RateLimitMiddleware;
use ErrorException;
use LogicException;
use Throwable;

/**
 * Zentrale Application-Klasse für das Framework.
 *
 * Verantwortlichkeiten:
 * - Verwaltet globale Middleware und deren Ausführungsreihenfolge
 * - Registriert Routen über eine Router-Komponente (GET, POST, DELETE)
 * - Führt Request-Handling durch Middleware-Pipeline aus
 * - Delegiert Route-Matching an Router
 * - Fängt Exceptions ab und delegiert diese an ErrorHandler
 *
 * Lifecycle:
 * 1. Bootstrap (Autoloader, Error-Handling, Secrets)
 * 2. Middleware-Registrierung (Reihenfolge ist wichtig!)
 * 3. Routen-Registrierung
 * 4. Request-Handling (Middleware → Router → Controller)
 *
 * @see Application::create() Factory-Methode für die Initialisierung
 * @see Application::handle() Haupt-Einstiegspunkt für Request-Verarbeitung
 */
final class Application
{
    /**
     * Liste globaler Middleware, die für jede Anfrage ausgeführt wird.
     *
     * Reihenfolge:
     * - Die Middleware wird in der Reihenfolge ausgeführt, in der sie hinzugefügt wird.
     * - Beispiel: addMiddleware(A); addMiddleware(B);
     *   -> Ausführung: A -> B -> Handler
     *
     * @var list<MiddlewareInterface>
     */
    private array $middleware = [];

    /**
     * Merkt sich registrierte Middleware-Klassen, um Duplikate zu verhindern.
     *
     * Schlüssel: Fully Qualified Class Name (FQCN), z.B. "App\Middleware\ApiTokenMiddleware"
     *
     * @var array<string,true>
     */
    private array $middlewareIndex = [];

    // ------------------------------------------------------------------------
    // --- Konstruktor ---
    // ------------------------------------------------------------------------

    /**
     * Konstruktor.
     *
     * Der Konstruktor ist privat, um eine direkte Instanziierung mittels `new` zu verhindern (Singleton Pattern).
     * Stattdessen sollte `Application::create()` verwendet werden.
     *
     * @param Router $router Router-Instanz für das Matching von Routen.
     * @param ErrorHandler $errorHandler Zentrale Fehlerbehandlung (Exceptions -> Response).
     */
    private function __construct(
        private readonly Router $router,
        private readonly ErrorHandler $errorHandler,
    ) {}

    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------

    /**
     * Erzeugt eine neue Application-Instanz.
     *
     * @return Application
     * @throws ErrorException
     */
    public static function create(): Application
    {
        require_once __DIR__ . '/Bootstrap.php';

        // 1) Autoloader zuerst, damit Facades & Rest geladen werden können
        Bootstrap::registerAutoloader();

        // 2) Emergency-Fallback-Handler (möglichst früh)
        Bootstrap::initFatalFallbackHandler();

        // 3) Secrets laden
        Bootstrap::loadConfig();

        // 4) Error-Reporting konfigurieren
        Bootstrap::configureErrorReporting();

        // 5) Application erstellen
        $router = new Router();
        $app = new Application(router: $router, errorHandler: new ErrorHandler());

        // 6) Middleware hinzufügen (Reihenfolge ist relevant!)
        $app->addMiddleware(new CoverageMiddleware());
        $app->addMiddleware(new JsonBodyParserMiddleware());
        $app->addMiddleware(new ApiTokenMiddleware());
        $app->addMiddleware(new RateLimitMiddleware());
        $app->addMiddleware(new AuthMiddleware());

        // 7) Routen hinzufügen
        require_once __DIR__ . '/../../routes.php';
        registerRoutes($router);

        return $app;
    }

    /**
     * Registriert globale Middleware.
     *
     * Regeln:
     * - Jede Middleware-Klasse darf nur einmal registriert werden.
     *   (Sonst passieren schwer zu debuggen Effekte: doppelte Auth-Prüfung,
     *    doppeltes Rate-Limit, doppelte Coverage-Handler etc.)
     *
     * @param MiddlewareInterface $m Middleware-Instanz.
     *
     * @throws LogicException Wenn dieselbe Middleware-Klasse mehrfach registriert wird.
     */
    public function addMiddleware(MiddlewareInterface $m): void
    {
        $class = get_class($m);

        if (isset($this->middlewareIndex[$class])) {
            throw new LogicException('Middleware doppelt registriert: ' . $class);
        }

        $this->middlewareIndex[$class] = true;
        $this->middleware[] = $m;
    }

    /**
     * Führt die Anfrage durch Middleware + Router + Handler aus und liefert eine Response.
     *
     * Ablauf:
     * - Router wird am Ende der Middleware-Kette ausgeführt
     * - Middleware kann:
     *   - Request validieren (Auth, RateLimit, JSON parsing)
     *   - bei Fehlern selbst eine Response zurückgeben
     * - Handler (Controller-Methode) wird nur aufgerufen, wenn:
     *   - Route gefunden wurde
     *   - Middleware nicht vorher abgebrochen hat
     *
     * Fehlerbehandlung:
     * - Jede unbehandelte Exception wird abgefangen und an ErrorHandler delegiert.
     *
     * @param Request $request Eingehende HTTP-Anfrage.
     * @return Response HTTP-Antwort.
     */
    public function handle(Request $request): Response
    {
        // 1) Route zuerst matchen, damit Middleware Route-Metadaten nutzen kann
        $match = $this->router->match($request->method, $request->path);
        if ($match === null) {
            $methods = $this->router->allowedMethods($request->path);
            if (!empty($methods) && !in_array($request->method, $methods, true)) {
                // Pfad existiert, aber nicht für die gegebene Methode
                return Response::error(405)
                    ->withHeader('Allow', implode(', ', $methods));
            }
            // Pfad existiert nicht
            return Response::error(404);
        }

        // Route-Parameter: {id} etc.
        $request = $request->withAttribute('routeParams', $match['params']);

        // Route-Metadaten: geschützt ja/nein (für AuthMiddleware)
        $request = $request->withAttribute('routeProtected', (bool)$match['protected']);

        /** @var array{0:class-string,1:string} $handler */
        $handler = $match['handler'];
        $class = $handler[0];
        $method = $handler[1];

        // 2) Core macht jetzt nur noch Dispatch (kein Match mehr)
        $core = function (Request $req) use ($class, $method): Response {
            $controller = new $class();
            return $controller->$method($req);
        };

        // Middleware-Pipeline bauen: außen -> innen -> core
        $pipeline = array_reduce(
            array_reverse($this->middleware),
            fn (callable $next, MiddlewareInterface $m) => fn (Request $r): Response => $m->process($r, $next),
            $core
        );

        try {
            return $pipeline($request);
        } catch (Throwable $e) {
            return $this->errorHandler->handle($e, $request);
        }
    }
}