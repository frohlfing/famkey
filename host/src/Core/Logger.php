<?php

/** @noinspection PhpUnused */

declare(strict_types=1);

namespace App\Core;

/**
 * Diese Klasse (Singleton) schreibt Nachrichten in eine Logdatei.
 *
 * Konfiguration (siehe `config.php`):
 * - `LOG_LEVEL` ('DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL')
 * - `LOG_MAX_DAYS` (maximal N Tage werden behalten, default: 7)
 *
 * Storage:
 * `/logs/app-YYYY-MM-DD.log`
 *
 * Beispiele:
 * <code>
 *  Logger::debug("foo");
 * </code>
 * <code>
 * Logger::exception($e, ['where' => 'VersionController.version']);
 * </code>
 *
 * @see http://www.php-fig.org/psr/psr-3/ PSR-3 Specification
 */
final class Logger
{
    /**
     * Singleton-Instanz (Lazy-Init).
     */
    private static ?self $instance = null;

    /**
     * Mapping von Log-Level-Namen zu numerischen Prioritäten.
     *
     * @var array<string,int>
     */
    private const array LEVELS = ['DEBUG' => 0, 'INFO'  => 1, 'WARN'  => 2, 'ERROR' => 3, 'FATAL' => 4];
    
    /**
     * Projekt-Root-Verzeichnis (absoluter Pfad).
     */
    private readonly string $projectRoot;

    /**
     * Minimaler Log-Level, der geschrieben wird ('DEBUG', 'INFO', 'WARN', 'ERROR').
     */
    private readonly string $minLevel;

    /**
     * Maximale Anzahl an Tagen, die Log-Dateien aufbewahrt werden.
     */
    private readonly int $maxDays;

    // ------------------------------------------------------------------------
    // --- Konstruktor ---
    // ------------------------------------------------------------------------

    /**
     * Konstruktor.
     *
     * Der Konstruktor ist privat, um eine direkte Instanziierung mittels `new` zu verhindern (Singleton Pattern).
     *
     * Konfiguration (siehe config.php):
     * - LOG_LEVEL (const)
     * - LOG_MAX_DAYS (const)
     */
    private function __construct()
    {
        $root = realpath(__DIR__ . '/../../');
        $this->projectRoot = $root !== false ? $root : __DIR__ . '/../../';
        $this->minLevel = defined('LOG_LEVEL') ? LOG_LEVEL : 'WARN';
        $this->maxDays  = defined('LOG_MAX_DAYS') ? LOG_MAX_DAYS : 7;
    }

    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------

    /**
     * Schreibt eine Logzeile, wenn der Log-Level >= minimaler Level ist.
     *
     * @param string $level 'DEBUG'|'INFO'|'WARN'|'ERROR'
     * @param string $message Log-Nachricht
     * @param array $context Ergänzende Informationen
     */
    public static function log(string $level, string $message, array $context = []): void
    {
        self::getInstance()->write($level, $message, $context);
    }

    /**
     * Loggt eine Debug-Message.
     *
     * @param string $message Log-Nachricht
     * @param array $context Ergänzende Informationen
     */
    public static function debug(string $message, array $context = []): void
    {
        self::getInstance()->write('DEBUG', $message, $context);
    }

    /**
     * Loggt eine Information.
     *
     * @param string $message Log-Nachricht
     * @param array $context Ergänzende Informationen
     */
    public static function info(string $message, array $context = []): void
    {
        self::getInstance()->write('INFO', $message, $context);
    }

    /**
     * Loggt eine Warnung.
     *
     * @param string $message Log-Nachricht
     * @param array $context Ergänzende Informationen
     */
    public static function warn(string $message, array $context = []): void
    {
        self::getInstance()->write('WARN', $message, $context);
    }

    /**
     * Loggt einen Fehler.
     *
     * @param string $message Log-Nachricht
     * @param array $context Ergänzende Informationen
     */
    public static function error(string $message, array $context = []): void
    {
        self::getInstance()->write('ERROR', $message, $context);
    }

    /**
     * Loggt einen schwerwiegenden Fehler.
     *
     * Dies ist ein Fehler/Exceptions außerhalb von Application::handle() (während des Bootstrapping).
     *
     * @param string $message Log-Nachricht
     * @param array $context Ergänzende Informationen
     */
    public static function fatal(string $message, array $context = []): void
    {
        self::getInstance()->write('FATAL', $message, $context);
    }

    // ------------------------------------------------------------------------
    // --- Private Methoden ---
    // ------------------------------------------------------------------------

    /**
     * Liefert die Logger-Instanz.
     *
     * Wenn noch keine Instanz erzeugt wurde, wird eine erstellt (Singleton Pattern).
     */
    private static function getInstance(): self
    {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    /**
     * Verhindern, dass die Instanz geklont wird (Singleton Pattern).
     */
    private function __clone() {}

    /**
     * Schreibt eine Logzeile, wenn der Log-Level >= minimaler Level ist.
     *
     * @param string $level 'DEBUG'|'INFO'|'WARN'|'ERROR'
     * @param string $message Log-Nachricht
     * @param array $context Ergänzende Informationen
     */
    private function write(string $level, string $message, array $context = []): void
    {
        $level = strtoupper($level);
        $min = strtoupper($this->minLevel);

        $levelValue = self::LEVELS[$level] ?? self::LEVELS['INFO'];
        $minValue   = self::LEVELS[$min] ?? self::LEVELS['WARN'];

        if ($levelValue < $minValue) {
            return;
        }

        $dir = $this->projectRoot . DIRECTORY_SEPARATOR . 'logs';
        if (!is_dir($dir)) {
            @mkdir($dir, 0777, true);
        }

        $date = gmdate('Y-m-d');
        $file = $dir . DIRECTORY_SEPARATOR . 'app-' . $date . '.log';

        $ts = gmdate('Y-m-d\TH:i:s\Z');
        $line = '[' . $ts . '] ' . $level . ': ' . $message;

        if (!empty($context)) {
            $json = json_encode($context, JSON_UNESCAPED_SLASHES);
            if (is_string($json)) {
                $line .= ' ' . $json;
            }
        }

        $line .= "\n";

        @file_put_contents($file, $line, FILE_APPEND | LOCK_EX);

        $this->cleanup($dir);
    }

    /**
     * Löscht alte Log-Dateien, die älter als maxDays sind.
     *
     * Durchsucht das angegebene Verzeichnis nach Log-Dateien im Format
     * `app-YYYY-MM-DD.log` und entfernt alle Dateien, deren Datum älter
     * als der konfigurierte Schwellenwert (maxDays) ist.
     *
     * @param string $dir Absoluter Pfad zum Log-Verzeichnis
     */
    private function cleanup(string $dir): void
    {
        if ($this->maxDays <= 0) {
            return;
        }

        $threshold = strtotime(gmdate('Y-m-d', strtotime('-' . ($this->maxDays - 1) . ' days')));
        if ($threshold === false) {
            return;
        }

        $files = @glob($dir . DIRECTORY_SEPARATOR . 'app-????-??-??.log') ?: [];
        foreach ($files as $path) {
            $base = basename($path);

            if (!preg_match('/^app-(\d{4}-\d{2}-\d{2})\.log$/', $base, $m)) {
                continue;
            }

            $t = strtotime($m[1]);
            if ($t === false) {
                continue;
            }

            if ($t < $threshold) {
                @unlink($path);
            }
        }
    }
}