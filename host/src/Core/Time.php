<?php
declare(strict_types=1);

namespace App\Core;

use DateMalformedStringException;
use DateTime;
use DateTimeZone;
use Throwable;

/**
 * Diese Klasse stellt Zeit-Hilfsfunktionen bereit.
 */
final class Time
{
    /**
     * Erzeugt aktuellen ISO 8601 Zeitstempel mit Millisekunden in UTC.
     *
     * Beispiel:
     *  ```php
     *  $now = \App\Core\Time::getUTC();
     *  ```
     *
     * Format:
     * 2026-01-14T17:13:41.542Z
     *
     * Hinweis:
     * Fallback ohne Millisekunden, falls DateTime scheitert.
     *
     * @return string
     */
    public static function getUTC(): string
    {
        try {
            return new DateTime('now', new DateTimeZone('UTC'))->format('Y-m-d\TH:i:s.v\Z');
        }
        catch (DateMalformedStringException) {
            // Fallback ohne Millisekunden
            return gmdate('Y-m-d\TH:i:s\Z');
        }
    }

        /**
         * Normalisiert einen beliebigen Datums-String in das API-konforme UTC ISO-8601 Format.
         *
         * Akzeptiert verschiedene Eingabeformate (z.B. "2026-01-01", "now", Timestamp) und
         * erzwingt das einheitliche Format `YYYY-MM-DDThh:mm:ss.vvvZ`.
         *
         * @param string $dateString Beliebiger Datums-String
         * @return string|null Normalisierter String oder null bei Parse-Fehler
         */
        public static function normalizeIso8601(string $dateString): ?string
        {
            try {
                $dt = new DateTime($dateString);
                $dt->setTimezone(new DateTimeZone('UTC'));
                return $dt->format('Y-m-d\TH:i:s.v\Z');
            } catch (Throwable) {
                return null;
            }
        }

        /**
         * Wandelt einen ISO-8601-String in ein MySQL-kompatibles Format um.
         *
         * Diese Methode bereitet einen API-Datums-String (z.B. aus dem Request) für
         * die Speicherung in einer `DATETIME(3)` Spalte vor.
         * Die Zeitzone wird dabei strikt auf UTC gesetzt.
         *
         * Eingang: "2026-01-28T14:30:00.123Z"
         * Ausgang: "2026-01-28 14:30:00.123"
         *
         * @param string $isoDate ISO-8601 Datum/Zeit.
         * @return string|null MySQL-Format oder null bei Parse-Fehler.
         */
        public static function iso8601ToMysql(string $isoDate): ?string
        {
            try {
                $dt = new DateTime($isoDate);
                $dt->setTimezone(new DateTimeZone('UTC'));
                return $dt->format('Y-m-d H:i:s.v');
            } catch (Throwable) {
                return null;
            }
        }
    }