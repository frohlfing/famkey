<?php
declare(strict_types=1);

namespace App\Core;

final class HtmlHelper
{
    /**
     * Escaped einen String sicher für die Ausgabe in HTML.
     */
    public static function h(string $s): string
    {
        return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }

    /**
     * Wandelt einen beliebigen String in einen URL-sicheren Slug um.
     * Deutsch: ä→ae, ö→oe, ü→ue, ß→ss. Sonderzeichen → Bindestrich. Großbuchstaben → Kleinbuchstaben.
     */

    /**
     * Wandelt einen beliebigen String in einen URL-sicheren Slug um.
     *
     * Großbuchstaben werden in Kleinbuchstaben umgewandelt.
     * Deutsche Umlaute werden ausgeschrieben, z. B. ä → ae, ö → oe, ü → ue, ß → ss.
     * Alle übrigen nicht-alphanumerischen Zeichen werden durch Bindestriche ersetzt.
     * Das Ergebnis wird auf maximal 64 Zeichen gekürzt.
     */
    public static function slugify(string $s): string
    {
        $s = mb_strtolower($s, 'UTF-8');
        $s = strtr($s, ['ä' => 'ae', 'ö' => 'oe', 'ü' => 'ue', 'ß' => 'ss']);
        $s = preg_replace('/[^a-z0-9]+/', '-', $s) ?? '';
        $s = trim($s, '-');

        return substr($s, 0, 64);
    }
}