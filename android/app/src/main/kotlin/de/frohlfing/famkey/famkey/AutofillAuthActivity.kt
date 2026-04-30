package de.frohlfing.famkey.famkey

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.autofill.AutofillId
import android.view.autofill.AutofillManager

/**
 * Leichtgewichtige Vermittler-Activity für den Autofill-Authentifizierungsflow.
 *
 * # Das Kernproblem: FLAG_ACTIVITY_NEW_TASK vs. setResult()
 *
 * Das Android-Autofill-Framework startet die Auth-Activity mit
 * `startIntentSenderForResult()`. Das ist wie `startActivityForResult()` –
 * der Aufrufer (Android-Framework) erwartet, dass die Activity am Ende
 * `setResult()` aufruft, um das Ergebnis (die ausgefüllten Formularfelder)
 * zurückzugeben.
 *
 * FamKey hat aber ein besonderes Bedürfnis: Die eigentliche Flutter-UI
 * (MainActivity) soll in FamKeys eigenem Task (Aufgaben-Stack) laufen.
 * Dazu braucht man `FLAG_ACTIVITY_NEW_TASK`. Dieser Flag bricht jedoch genau
 * die Ergebnisübermittlung: Android ignoriert `setResult()` für Activities,
 * die mit `FLAG_ACTIVITY_NEW_TASK` gestartet wurden.
 *
 * Kurz gesagt: Man kann nicht beides haben – `FLAG_ACTIVITY_NEW_TASK` UND
 * funktionierendes `setResult()`.
 *
 * # Die Lösung: Zwei-Activity-Relais-Muster
 *
 * Diese Activity (AutofillAuthActivity) ist ein schlanker Vermittler:
 *
 * ```
 * Chrome-Task:                        FamKey-Task:
 * ┌──────────────────────────┐        ┌─────────────────────────────┐
 * │ AutofillAuthActivity     │        │ MainActivity (Flutter)       │
 * │                          │        │                              │
 * │ • KEIN NEW_TASK          │  ───►  │ • MIT FLAG_ACTIVITY_NEW_TASK │
 * │ • kann setResult() rufen │  ◄───  │ • Flutter läuft hier        │
 * │ • sitzt in Chrome-Task   │ Relay  │ • sitzt in FamKey-Task    │
 * └──────────────────────────┘        └─────────────────────────────┘
 *         │ setResult()
 *         ▼
 * Android-Autofill-Framework
 *         │
 *         ▼
 * Formular in Chrome wird befüllt ✓
 * ```
 *
 * AutofillAuthActivity:
 * 1. Registriert Callbacks im [AutofillResultRelay] (Singleton, für beide
 *    Activities sichtbar, weil beide im selben Prozess laufen)
 * 2. Startet MainActivity mit `FLAG_ACTIVITY_NEW_TASK` (FamKeys Task)
 * 3. Wartet still auf das Ergebnis (die Callbacks im Relay)
 * 4. Wenn MainActivity ein Ergebnis liefert → Callback wird aufgerufen
 *    → `setResult(RESULT_OK, dataset)` → `finish()`
 *
 * # Was ist ein "Task" in Android?
 *
 * Ein Task ist ein Stapel von Screens (Activities). Beim Drücken von "Zurück"
 * kommt man zum vorherigen Screen im Stack. Chrome hat seinen eigenen Task,
 * FamKey hat seinen eigenen Task. Mit `FLAG_ACTIVITY_NEW_TASK` startet eine
 * Activity im Task der App, zu der sie gehört – nicht im Task des Aufrufers.
 *
 * # Warum ist das Theme transparent?
 *
 * `Theme.Translucent.NoTitleBar` macht diese Activity unsichtbar (kein Fenster).
 * Der Nutzer sieht sie nie – sie ist nur ein technischer Vermittler im Hintergrund.
 */
class AutofillAuthActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Formularfeld-IDs und Domain aus dem Intent lesen.
        // Diese wurden von FamKeyAutofillService in den PendingIntent gepackt.
        val usernameId = getAutofillId(intent, FamKeyAutofillService.EXTRA_USERNAME_ID)
        val passwordId = getAutofillId(intent, FamKeyAutofillService.EXTRA_PASSWORD_ID)
        val domain = intent.getStringExtra(FamKeyAutofillService.EXTRA_DOMAIN) ?: ""
        Log.d(TAG, "AutofillAuthActivity.onCreate: usernameId=$usernameId, passwordId=$passwordId")

        // Callbacks im Relay registrieren, BEVOR MainActivity gestartet wird.
        // So ist sichergestellt, dass MainActivity sofort delivern kann, sobald
        // der Nutzer einen Eintrag auswählt.
        AutofillResultRelay.set(
            onResult = { username, password ->
                // Dieser Block wird aufgerufen, wenn MainActivity über den MethodChannel
                // "completeAutofill" sendet und AutofillResultRelay.deliver() aufruft.
                Log.d(TAG, "AutofillAuthActivity: relay – setResult(OK)")

                // Dataset = Behälter mit den konkreten Feldwerten (username → Feld X, password → Feld Y).
                // buildDataset() erzeugt diesen Behälter mit den korrekten AutofillIds.
                val dataset = FamKeyAutofillService.buildDataset(packageName, usernameId, passwordId, username, password)

                // Das Dataset als Ergebnis verpacken.
                // EXTRA_AUTHENTICATION_RESULT ist der Schlüssel, den das Android-Framework
                // erwartet, um die Daten aus dem Intent zu lesen.
                val replyIntent = Intent().apply {
                    putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, dataset)
                }

                // setResult() übergibt das Ergebnis an den Aufrufer (Android-Framework).
                // RESULT_OK signalisiert Erfolg.
                setResult(RESULT_OK, replyIntent)

                // finish() schließt diese Activity – der Chrome-Task kommt zurück in den
                // Vordergrund. Das Android-Framework liest das Dataset und befüllt die Felder.
                finish()
            },
            onCancel = {
                // Dieser Block wird aufgerufen, wenn der Nutzer den X-Button in FamKey drückt.
                Log.d(TAG, "AutofillAuthActivity: relay – cancel, setResult(CANCELED)")
                setResult(RESULT_CANCELED)
                finish()
            },
        )

        // FamKeys Task in den Vordergrund bringen.
        // FLAG_ACTIVITY_NEW_TASK ist hier unbedenklich, weil wir das Ergebnis nicht
        // über diese Activity zurückliefern – das macht das Relay über setResult() oben.
        // Mit REORDER_TO_FRONT wird der FamKey-Task nach vorne gebracht, falls er
        // bereits existiert (Warm-Start). MainActivity.onNewIntent() wird dann aufgerufen.
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            action = FamKeyAutofillService.ACTION_AUTOFILL_PICK
            putExtra(FamKeyAutofillService.EXTRA_DOMAIN, domain)
            putExtra(FamKeyAutofillService.EXTRA_USERNAME_ID, usernameId)
            putExtra(FamKeyAutofillService.EXTRA_PASSWORD_ID, passwordId)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(mainIntent)
    }

    override fun onDestroy() {
        super.onDestroy()
        // Callbacks löschen, damit kein veralteter Callback auf diese zerstörte
        // Activity zeigt. Ohne diese Bereinigung könnte ein verspätetes deliver()
        // auf ein nicht mehr existierendes Activity-Objekt zugreifen.
        AutofillResultRelay.clear()
    }

    /**
     * Liest eine [AutofillId] aus dem Intent-Extra auf eine Art, die auch auf
     * Android 13+ (API 33) ohne Deprecation-Warnung funktioniert.
     *
     * Hintergrund: Ab API 33 ist `getParcelableExtra(key)` ohne Typ veraltet,
     * weil der Typ nicht sicher geprüft werden kann. Die neue Überladung mit
     * Typ-Parameter ist erst ab API 33 verfügbar – daher der Build-Check.
     */
    private fun getAutofillId(intent: Intent, key: String): AutofillId? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(key, AutofillId::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(key)
        }

    companion object {
        private const val TAG = "FamKey"
    }
}
