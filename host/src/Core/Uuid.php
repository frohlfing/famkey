<?php
declare(strict_types=1);

namespace App\Core;

use Random\RandomException;

/**
 * Diese Klasse stellt eine Hilfsfunktion zum Generieren einer UUID bereit.
 */
final class Uuid
{
    /**
     * Generiert eine v4 UUID (36 Zeichen lang).
     *
     * Beispiel:
     * <code>
     * $id = \App\Core\Uuid::v4();
     * </code>
     *
     * Format: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
     *
     * @return string
     */
    public static function v4(): string
    {
        try {
            $data = random_bytes(16);
        }
        catch (RandomException) {
            // Fallback: pseudo-random bytes
            $data = '';
            for ($i = 0; $i < 16; $i++) {
                $data .= chr(mt_rand(0, 255));
            }
        }

        // Version 4 setzen
        $data[6] = chr((ord($data[6]) & 0x0f) | 0x40);

        // Variant setzen
        $data[8] = chr((ord($data[8]) & 0x3f) | 0x80);

        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
    }
}