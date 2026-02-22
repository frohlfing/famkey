<?php
declare(strict_types=1);

namespace App\Core;

use ErrorException;
use Throwable;

/**
 * Bootstrap-Klasse für die Initialisierung der Anwendung.
 *
 * Diese Klasse stellt statische Methoden bereit, um die Anwendung zu starten:
 * - Registrierung eines minimalen PSR-4-ähnlichen Autoloaders
 * - Laden der Konfigurationsdatei (config.php)
 * - Konfiguration des PHP Error-Reportings für API-Betrieb
 * - Einrichtung globaler Error- und Exception-Handler
 */
final class Bootstrap
{
    /**
     * Registriert den minimalen PSR-4-ähnlichen Autoloader (ohne Composer).
     *
     * Lädt Klassen aus dem Namespace `App\` aus dem Ordner `/src`.
     * Beispiel: `App\Core\Request` wird zu `/src/Core/Request.php` aufgelöst.
     */
    public static function registerAutoloader(): void
    {
        spl_autoload_register(static function (string $class): void {
            $prefix = 'App\\';
            if (strncmp($class, $prefix, strlen($prefix)) !== 0) {
                return;
            }

            $relative = substr($class, strlen($prefix));
            $file = __DIR__ . '/../../src/' . str_replace('\\', '/', $relative) . '.php';

            if (is_file($file)) {
                require_once $file;
            }
        });
    }

    /**
     * Lädt die Konfigurationsdatei.
     */
    public static function loadConfig(): void
    {
        require_once __DIR__ . '/../../config.php';
    }

    /**
     * Konfiguriert das PHP Error-Reporting.
     *
     * - Im Debug-Modus (`DEBUG=true`):
     *   - `error_reporting(E_ALL)` → alle Fehlertypen werden erfasst
     *   - `display_errors` bleibt "0" (Fehler werden über Logger/Exception-Handler sichtbar)
     * - Im Produktiv-Modus (`DEBUG=false`):
     *   - `error_reporting(E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED)`
     *   - Deprecated-Warnings werden ausgeblendet
     */
    public static function configureErrorReporting(): void
    {
        // In einer API fast immer sinnvoll: keine HTML-Fehlerausgabe
        ini_set('display_errors', '0');
        ini_set('display_startup_errors', '0');

        if (DEBUG) {
            // Debug: alles reporten (Logger + ErrorHandler übernehmen die Sichtbarkeit)
            error_reporting(E_ALL);
            return;
        }

        // Prod: Deprecated ausblenden, Rest reporten (damit Logging funktioniert)
        $mask = E_ALL;

        if (defined('E_DEPRECATED')) {
            $mask = $mask & ~E_DEPRECATED;
        }
        if (defined('E_USER_DEPRECATED')) {
            $mask = $mask & ~E_USER_DEPRECATED;
        }

        error_reporting($mask);
    }

    /**
     * Richtet globale Error-, Exception- und Shutdown-Handler als Fallback für schwere Fehler ein.
     *
     * Diese Handler greifen nur, wenn Fehler/Exceptions außerhalb von Application::handle()
     * auftreten (während des Bootstrapping).
     *
     * Registriert drei Handler:
     * 1. `set_error_handler`: Wandelt PHP-Errors in Exceptions um (außer Notices/Warnings → nur Logging)
     * 2. `set_exception_handler`: Fängt uncaught Exceptions ab und gibt JSON-Response zurück
     * 3. `register_shutdown_function`: Fängt fatale Fehler (`E_ERROR`, `E_PARSE` etc.) ab
     *
     * Alle Handler respektieren den Debug-Modus:
     * - `DEBUG=true`: detaillierte Fehlerausgabe (Exception-Klasse, Message, File, Line)
     * - `DEBUG=false`: generische Fehlermeldung "Internal Server Error"
     *
     * @throws ErrorException wenn ein relevanter PHP-Error auftritt
     */
    public static function initFatalFallbackHandler(): void
    {
        // PHP Errors -> Exception oder Logging (je nach Schwere)
        set_error_handler(static function (int $errno, string $errstr, string $errfile = '', int $errline = 0): bool {
            // Unterdrückte Fehler per @ nicht anfassen
            if ((error_reporting() & $errno) === 0) {
                return false;
            }

            if ($errno === E_WARNING || $errno === E_USER_WARNING) {
                Logger::warn($errstr, [
                    'errno' => $errno,
                    'file' => $errfile,
                    'line' => $errline,
                    'method' => 'set_error_handler'
                ]);
                return true;
            }

            if ($errno === E_NOTICE || $errno === E_USER_NOTICE ||
                (defined('E_DEPRECATED') && $errno === E_DEPRECATED) ||
                (defined('E_USER_DEPRECATED') && $errno === E_USER_DEPRECATED)) {
                Logger::info($errstr, ['errno' => $errno, 'file' => $errfile, 'line' => $errline, 'method' => 'set_error_handler']);
                return true;
            }

            throw new ErrorException($errstr, 0, $errno, $errfile, $errline);
        });

        // Uncaught Exceptions (außerhalb Application::handle())
        set_exception_handler(static function (Throwable $e): void {
            Logger::fatal($e->getMessage(), [
                'exception' => get_class($e),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
                'method' => 'set_exception_handler',
            ]);

            if (!headers_sent()) {
                http_response_code(500);
                header('Content-Type: application/json; charset=utf-8');
            }

            $data = ['error' => 'Fatal Error'];
            if (defined('DEBUG') && DEBUG) {
                $data['message'] = $e->getMessage();
                $data['exception'] = get_class($e);
            }

            echo json_encode($data, JSON_UNESCAPED_SLASHES);
        });

        // Fatal Error Fallback (z.B. Parse/Compile/Fatal), die nicht im error_handler landen
        register_shutdown_function(static function (): void {
            $err = error_get_last();
            if (!is_array($err)) {
                return;
            }

            $type = (int)($err['type'] ?? 0);

            // Fatal-Typen
            $fatalTypes = [
                E_ERROR,
                E_PARSE,
                E_CORE_ERROR,
                E_CORE_WARNING,
                E_COMPILE_ERROR,
                E_COMPILE_WARNING,
                E_RECOVERABLE_ERROR,
            ];

            if (!in_array($type, $fatalTypes, true)) {
                return;
            }

            $message = (string)($err['message'] ?? 'Fatal error');
            $file = (string)($err['file'] ?? '');
            $line = (int)($err['line'] ?? 0);

            Logger::fatal($message, [
                'errno' => $type,
                'file' => $file,
                'line' => $line,
                'method' => 'shutdown_handler',
            ]);

            // Wenn schon Output lief, können wir Response nicht garantieren – aber versuchen es.
            if (!headers_sent()) {
                http_response_code(500);
                header('Content-Type: application/json; charset=utf-8');
            }

            $data = ['error' => 'Fatal Error'];
            if (defined('DEBUG') && DEBUG) {
                $data['message'] = $message;
            }

            echo json_encode($data, JSON_UNESCAPED_SLASHES);
        });
    }
}