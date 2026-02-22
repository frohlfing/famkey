<?php
declare(strict_types=1);

namespace App\Core;

use PDO;
use Pdo\Mysql;
use PDOException;

/**
 * Diese Klasse stellt eine singletonartige PDO-Instanz bereit.
 *
 * Konfiguration (siehe `config.php`):
 * - `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS`, `DB_SSLCA`
 *
 * Funktionsweise:
 * - Erst beim ersten Aufruf wird eine Verbindung aufgebaut.
 * - Danach wird dieselbe PDO-Instanz wiederverwendet (pro PHP-Request-Prozess).
 */
final class Database
{
    /**
     * PDO (PHP Data Objects) ist eine Datenbankabstraktionsschicht für PHP.
     * Sie bietet eine einheitliche Schnittstelle für den Zugriff auf verschiedene Datenbanksysteme.
     *
     * Diese statische Variable hält die Singleton-Instanz der PDO-Verbindung.
     * Beim ersten Zugriff wird die Verbindung zur Datenbank hergestellt,
     * bei weiteren Zugriffen wird die bereits existierende Instanz zurückgegeben.
     *
     * @var PDO|null Die PDO-Datenbankverbindung oder null, wenn noch keine Verbindung hergestellt wurde.
     */
    private static ?PDO $pdo = null;

    /**
     * Liefert eine (singletonartige) PDO-Instanz für MySQL.
     *
     * @return PDO
     * @throws PDOException Wenn die Verbindung fehlschlägt.
     */
    public static function pdo(): PDO
    {
        if (self::$pdo !== null) {
            return self::$pdo;
        }

        $dsn = 'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4';

        $options = [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ];

        // Optional: SSL CA
        if (DB_SSLCA) {
            $options[Mysql::ATTR_SSL_CA] = DB_SSLCA;
        }

        self::$pdo = new PDO($dsn, DB_USER, DB_PASS, $options);
        return self::$pdo;
    }
}