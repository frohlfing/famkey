package de.frohlfing.privault.privault

/**
 * Prozess-interner Nachrichtenkanal zwischen MainActivity und AutofillAuthActivity.
 *
 * # Das Problem, das dieses Objekt löst
 *
 * Beim Autofill-Ablauf sind zwei Activities beteiligt:
 * - [AutofillAuthActivity]: sitzt im Task von Chrome und muss das Ergebnis via
 *   `setResult()` an das Android-Autofill-Framework liefern.
 * - [MainActivity]: ist der eigentliche Flutter-Bildschirm, auf dem der Nutzer
 *   den Passwort-Eintrag auswählt.
 *
 * Das Problem: MainActivity muss mit FLAG_ACTIVITY_NEW_TASK gestartet werden
 * (damit PriVaults eigener Task wiederverwendet wird), aber dieses Flag bricht
 * die `setResult()`-Kommunikation. MainActivity kann das Ergebnis daher nicht
 * selbst an das Android-Framework liefern.
 *
 * Die Lösung: AutofillAuthActivity registriert *Callback-Funktionen* in diesem
 * Singleton. Wenn MainActivity das Ergebnis hat, ruft es [deliver] auf –
 * das Relay leitet die Callbacks weiter, als ob AutofillAuthActivity selbst
 * das Ergebnis hätte. Da beide Activities im selben Prozess (der PriVault-App)
 * laufen, können sie auf dieses gemeinsame Objekt zugreifen.
 *
 * # Was ist ein Kotlin `object`?
 *
 * `object` erzeugt ein Singleton – es gibt genau eine Instanz dieser Klasse
 * für die gesamte Laufzeit der App. Jeder Zugriff auf `AutofillResultRelay`
 * gibt dasselbe Objekt zurück. Das ist vergleichbar mit statischen Feldern
 * in Java/Kotlin, aber sauberer gekapselt.
 *
 * # Thread-Sicherheit (@Volatile)
 *
 * Android führt UI-Operationen auf dem Main-Thread aus, kann aber andere
 * Aufgaben auf Hintergrund-Threads erledigen. `@Volatile` stellt sicher, dass
 * Änderungen an diesen Variablen sofort für alle Threads sichtbar sind –
 * ohne dass ein Thread eine veraltete Kopie im CPU-Cache hat.
 */
object AutofillResultRelay {

    /**
     * Callback für den Erfolgsfall: wird mit Benutzername und Passwort aufgerufen.
     * Null, wenn kein Request aktiv ist.
     */
    @Volatile private var onResult: ((String, String) -> Unit)? = null

    /**
     * Callback für den Abbruch-Fall: wird ohne Parameter aufgerufen.
     * Null, wenn kein Request aktiv ist.
     */
    @Volatile private var onCancel: (() -> Unit)? = null

    /**
     * Registriert die Callbacks für einen neuen Autofill-Request.
     *
     * Wird von [AutofillAuthActivity.onCreate] aufgerufen, direkt bevor
     * MainActivity gestartet wird. Die Callbacks kapseln das `setResult()`-Verhalten
     * von AutofillAuthActivity – MainActivity muss dafür nichts über AutofillAuthActivity
     * wissen.
     *
     * @param onResult  Wird mit (username, password) aufgerufen, wenn der Nutzer
     *                  einen Eintrag ausgewählt hat.
     * @param onCancel  Wird aufgerufen, wenn der Nutzer den Vorgang abbricht.
     */
    fun set(onResult: (String, String) -> Unit, onCancel: () -> Unit) {
        this.onResult = onResult
        this.onCancel = onCancel
    }

    /**
     * Liefert das Ergebnis an AutofillAuthActivity und räumt das Relay auf.
     *
     * Wird von [MainActivity] aufgerufen, wenn Flutter einen Eintrag ausgewählt hat.
     *
     * Wichtig: Die Callbacks werden vor dem Aufruf auf null gesetzt, um zu verhindern,
     * dass ein zweiter Aufruf (z.B. durch eine Race Condition) denselben Callback
     * nochmal auslöst.
     *
     * @return true, wenn ein Callback registriert war und aufgerufen wurde;
     *         false, wenn kein aktiver Request vorlag (Fallback-Pfad nötig).
     */
    fun deliver(username: String, password: String): Boolean {
        val cb = onResult ?: return false  // kein aktiver Request → false zurückgeben
        onResult = null                    // Callbacks sofort löschen (bevor cb() aufgerufen wird)
        onCancel = null
        cb(username, password)             // AutofillAuthActivity bekommt die Zugangsdaten
        return true
    }

    /**
     * Signalisiert einen Abbruch an AutofillAuthActivity.
     *
     * Wird von [MainActivity] aufgerufen, wenn der Nutzer den Vorgang abbricht.
     *
     * @return true, wenn ein Callback registriert war und aufgerufen wurde;
     *         false, wenn kein aktiver Request vorlag.
     */
    fun cancel(): Boolean {
        val cb = onCancel ?: return false
        onResult = null
        onCancel = null
        cb()
        return true
    }

    /**
     * Löscht alle Callbacks ohne Benachrichtigung.
     *
     * Wird von [AutofillAuthActivity.onDestroy] aufgerufen, damit keine veralteten
     * Callbacks auf ein zerstörtes Activity-Objekt zeigen. Würde man das weglassen,
     * könnte ein späteres `deliver()` versuchen, `setResult()` auf einer bereits
     * zerstörten Activity aufzurufen – was zu Abstürzen führen kann.
     */
    fun clear() {
        onResult = null
        onCancel = null
    }
}
