package de.frohlfing.privault.privault

import android.app.PendingIntent
import android.app.assist.AssistStructure
import android.app.assist.AssistStructure.ViewNode
import android.os.Build
import android.os.CancellationSignal
import android.service.autofill.*
import android.view.View
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import android.widget.RemoteViews
import android.content.Intent
import android.util.Log
import de.frohlfing.privault.privault.R
import androidx.autofill.inline.v1.InlineSuggestionUi

/**
 * Der Android-Autofill-Service von PriVault.
 *
 * # Was ist ein AutofillService?
 *
 * Android erlaubt es Apps, sich als "Autofill-Provider" zu registrieren.
 * Dazu deklariert man einen Service im AndroidManifest und lässt ihn von
 * `android.service.autofill.AutofillService` erben. Sobald der Nutzer PriVault
 * in den Android-Einstellungen als Autofill-Provider auswählt, ruft Android
 * diesen Service auf, wann immer ein Formular ausfüllt werden muss.
 *
 * # Die zwei Methoden, die Android aufruft
 *
 * Android ruft genau zwei Methoden auf:
 * - `onFillRequest()`: Ein Formular braucht Daten – liefere Vorschläge.
 * - `onSaveRequest()`: Der Nutzer hat ein Formular abgeschickt – willst du die
 *   Daten speichern? (PriVault ignoriert das aktuell.)
 *
 * # Was ist eine AssistStructure?
 *
 * Wenn Android `onFillRequest` aufruft, übergibt es eine [AssistStructure].
 * Das ist eine Baumstruktur, die alle UI-Elemente (Views) des aktuellen Bildschirms
 * beschreibt – ähnlich wie der DOM-Baum einer Webseite:
 *
 * ```
 * AssistStructure
 * └── WindowNode (das Fenster von Chrome)
 *     └── ViewNode (LinearLayout)
 *         ├── ViewNode (Label "Benutzername")
 *         ├── ViewNode (TextInput, autofillHints = [USERNAME])  ← interessant!
 *         ├── ViewNode (Label "Passwort")
 *         └── ViewNode (TextInput, autofillHints = [PASSWORD])  ← interessant!
 * ```
 *
 * `parseStructure()` durchsucht diesen Baum, um die ID des Benutzername-Felds
 * und des Passwort-Felds zu finden.
 *
 * # Dataset-Level-Authentifizierung
 *
 * PriVault verwendet "Dataset-Level-Auth": Der Nutzer klickt auf den
 * "PriVault"-Vorschlag → PriVault öffnet sich zur Auswahl → Der Nutzer wählt
 * einen Eintrag → Das Formular wird sofort befüllt.
 *
 * Alternative wäre "Response-Level-Auth", bei der das Framework nach der
 * Authentifizierung noch einmal Vorschläge zeigt (zwei Klicks statt einem).
 * Dataset-Level ist daher die bessere UX.
 */
class PriVaultAutofillService : AutofillService() {

    /**
     * Wird von Android aufgerufen, wenn ein Formular Autofill-Vorschläge braucht.
     *
     * Diese Methode läuft im Hintergrund (nicht auf dem UI-Thread). Sie muss
     * `callback.onSuccess()` oder `callback.onFailure()` aufrufen, bevor sie
     * zurückkehrt – Android wartet auf dieses Signal.
     *
     * @param request Enthält die [AssistStructure] mit den Formularfeldern und
     *                optional eine InlineSuggestionsRequest (für Keyboard-Chips).
     * @param cancellationSignal Kann von Android gesetzt werden, wenn der Request
     *                           nicht mehr gebraucht wird (z.B. Nutzer hat weggeklickt).
     * @param callback Über dieses Objekt wird die Antwort an Android zurückgegeben.
     */
    override fun onFillRequest(request: FillRequest, cancellationSignal: CancellationSignal, callback: FillCallback) {
        // Die AssistStructure aus dem letzten Fill-Kontext holen.
        // Es könnte mehrere Kontexte geben (wenn der Nutzer z.B. zwischen Feldern
        // wechselt), aber der letzte ist der relevanteste.
        val structure = request.fillContexts.lastOrNull()?.structure ?: run {
            callback.onSuccess(null)  // Kein Kontext → keine Vorschläge
            return
        }

        // Formularfelder und Domain aus der AssistStructure auslesen.
        val parsed = parseStructure(structure)
        Log.d(TAG, "onFillRequest: usernameId=${parsed.usernameId}, passwordId=${parsed.passwordId}")

        // Wenn weder Benutzername- noch Passwort-Feld gefunden wurde, ist das
        // vermutlich kein Login-Formular → keine Vorschläge anbieten.
        if (parsed.usernameId == null && parsed.passwordId == null) {
            Log.d(TAG, "onFillRequest: keine Felder gefunden → kein Response")
            callback.onSuccess(null)
            return
        }

        // Liste aller Felder, die befüllt werden sollen (ohne null-Werte).
        val autofillIds = listOfNotNull(parsed.usernameId, parsed.passwordId).toTypedArray()

        // ─────────────────────────────────────────────────────────────────────
        // Auth-Intent: Öffnet AutofillAuthActivity, wenn der Nutzer auf die
        // PriVault-Bubble tippt.
        //
        // WICHTIG: Kein FLAG_ACTIVITY_NEW_TASK hier! AutofillAuthActivity muss
        // im selben Task wie Chrome bleiben, damit sie setResult() korrekt
        // liefern kann. Sie startet intern MainActivity mit FLAG_ACTIVITY_NEW_TASK.
        // ─────────────────────────────────────────────────────────────────────
        val authIntent = Intent(this, AutofillAuthActivity::class.java).apply {
            action = ACTION_AUTOFILL_PICK
            putExtra(EXTRA_DOMAIN, parsed.domain)
            putExtra(EXTRA_USERNAME_ID, parsed.usernameId)
            putExtra(EXTRA_PASSWORD_ID, parsed.passwordId)
        }

        // PendingIntent: Ein "vorbereiteter" Intent, den Android zu einem späteren
        // Zeitpunkt ausführen kann (wenn der Nutzer auf die Bubble tippt).
        // FLAG_CANCEL_CURRENT statt FLAG_UPDATE_CURRENT: PendingIntents mit
        // FLAG_IMMUTABLE können ihre Extras nach der Erstellung nicht ändern.
        // Ohne CANCEL_CURRENT würden alte AutofillIds aus einem vorherigen
        // Request verwendet werden, was zu falschen Feld-Zuweisungen führt.
        val pendingIntent = PendingIntent.getActivity(
            this, REQUEST_CODE_AUTOFILL, authIntent,
            PendingIntent.FLAG_CANCEL_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        // ─────────────────────────────────────────────────────────────────────
        // Dropdown-Präsentation (klassische Variante, für ältere Android-Versionen
        // oder Apps, die kein Inline-Autofill unterstützen).
        //
        // RemoteViews: Ein Layout, das in einem anderen Prozess (hier: dem
        // Autofill-UI des Android-Systems) gerendert wird. Eigenes Layout statt
        // android.R.layout.simple_list_item_1, weil System-Layouts ab Android 12
        // im Autofill-Kontext nicht mehr korrekt dargestellt werden (leere Bubble).
        // ─────────────────────────────────────────────────────────────────────
        val presentation = RemoteViews(packageName, R.layout.autofill_suggestion).apply {
            setTextViewText(R.id.autofill_label, "PriVault")
        }

        // InlinePresentation: Neuere Variante für Android 11+, zeigt den Vorschlag
        // als Chip direkt in der Tastatur an. Nicht alle Tastaturen unterstützen das.
        val inlineRequest = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) request.inlineSuggestionsRequest else null
        val spec = inlineRequest?.inlinePresentationSpecs?.firstOrNull()
        Log.d(TAG, "onFillRequest: inlineRequest=${inlineRequest != null}, spec=$spec")

        // ─────────────────────────────────────────────────────────────────────
        // Dataset mit Dataset-Level-Authentifizierung aufbauen.
        //
        // Dataset = ein Vorschlag mit konkreten Feldwerten. Da PriVault erst
        // nach der Auswahl durch den Nutzer weiß, welche Zugangsdaten es eintragen
        // soll, sind die Feldwerte hier zunächst `null`. Erst nach der Auth
        // (Relay → AutofillAuthActivity → buildDataset) werden echte Werte geliefert.
        //
        // setAuthentication(pendingIntent) macht aus dem Dataset einen "geschützten"
        // Vorschlag: Wenn der Nutzer darauf tippt, startet Android den PendingIntent
        // (→ AutofillAuthActivity) statt sofort auszufüllen.
        // ─────────────────────────────────────────────────────────────────────
        val authDataset = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            Dataset.Builder().apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && spec != null) {
                    try {
                        // InlinePresentation für Tastatur-Chips erstellen.
                        val slice = InlineSuggestionUi.newContentBuilder(pendingIntent).setTitle("PriVault").build().slice
                        val inlinePresentation = InlinePresentation(slice, spec, false)
                        autofillIds.forEach { id -> setValue(id, null, presentation, inlinePresentation) }
                        Log.d(TAG, "onFillRequest: InlinePresentation erstellt")
                    } catch (e: Exception) {
                        // Fallback auf Dropdown, wenn die InlinePresentation fehlschlägt
                        // (z.B. weil die Tastatur es doch nicht unterstützt).
                        Log.d(TAG, "onFillRequest: InlinePresentation fehlgeschlagen: $e")
                        autofillIds.forEach { id -> setValue(id, null, presentation) }
                    }
                } else {
                    autofillIds.forEach { id -> setValue(id, null, presentation) }
                }
                setAuthentication(pendingIntent.intentSender)
            }.build()
        } else {
            // API < 28: Ältere Dataset-Builder-API ohne Per-Field-Presentation.
            @Suppress("DEPRECATION")
            Dataset.Builder(presentation).apply {
                autofillIds.forEach { id -> setValue(id, null) }
                setAuthentication(pendingIntent.intentSender)
            }.build()
        }

        // Antwort an Android schicken: Eine FillResponse mit einem Dataset.
        // Android zeigt jetzt die PriVault-Bubble im Autofill-Dropdown.
        callback.onSuccess(FillResponse.Builder().addDataset(authDataset).build())
    }

    /**
     * Wird von Android aufgerufen, wenn der Nutzer ein Formular abgeschickt hat
     * und Android fragt, ob PriVault die eingegebenen Daten speichern möchte.
     *
     * PriVault speichert Einträge nur manuell – daher hier kein Implementierung.
     */
    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        callback.onSuccess()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Interne Hilfsklassen und -methoden
    // ─────────────────────────────────────────────────────────────────────────

    /** Ergebnis des Struktur-Parsings: extrahierte Domain und Feld-IDs. */
    private data class ParsedStructure(
        val domain: String?,
        val usernameId: AutofillId?,
        val passwordId: AutofillId?,
    )

    /**
     * Durchsucht die AssistStructure nach Login-Feldern und der Website-Domain.
     *
     * Die AssistStructure ist ein Baum. Diese Methode durchläuft ihn rekursiv
     * (jeder Knoten kann Kinder haben). Für jeden Knoten (ViewNode) prüft sie:
     * - Ist es ein Passwort-Feld?  → passwordId merken
     * - Ist es ein Benutzername-/E-Mail-Feld?  → usernameId merken
     *
     * Außerdem wird die Domain der aktuellen Website ermittelt, damit PriVault
     * nur passende Einträge anzeigt (z.B. nur "PayPal"-Einträge bei paypal.com).
     *
     * # Warum htmlInfo für Chrome?
     *
     * Native Android-Apps setzen `autofillHints` auf ihre Felder (z.B.
     * AUTOFILL_HINT_USERNAME). Aber Chrome rendert Webseiten und übergibt
     * Web-Formularfelder ohne korrekten inputType-Bits in die AssistStructure.
     * Stattdessen liefert Chrome die HTML-Attribute des Input-Elements über
     * `node.htmlInfo.attributes`. Daher prüft diese Methode beides:
     * erstens die Standard-Android-Hints und inputType-Bits,
     * zweitens die HTML-Attribute aus htmlInfo (für Chrome-Webseiten).
     */
    private fun parseStructure(structure: AssistStructure): ParsedStructure {
        var domain: String? = null
        var usernameId: AutofillId? = null
        var passwordId: AutofillId? = null

        /**
         * Rekursive Hilfsfunktion: prüft einen einzelnen ViewNode und alle seine Kinder.
         */
        fun traverseNode(node: ViewNode) {
            // Domain aus der Web-URL ableiten (gesetzt von Chrome für Webseiten).
            if (domain == null) {
                node.webDomain?.takeIf { it.isNotBlank() }?.let { domain = it }
            }

            // Android-Standard-Hints und Input-Type-Bits des Felds.
            val hints = node.autofillHints ?: emptyArray()
            val inputType = node.inputType

            // HTML-Attribut "type" aus Chrome's htmlInfo (z.B. "password", "email", "text").
            // Ist nur verfügbar ab API 26 (Android 8.0) und nur wenn Chrome es liefert.
            val htmlInputType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                node.htmlInfo?.attributes?.firstOrNull { it.first.equals("type", ignoreCase = true) }?.second?.lowercase()
            } else null

            if (htmlInputType != null && node.autofillId != null) {
                Log.d(TAG, "traverseNode: htmlInputType=$htmlInputType autofillId=${node.autofillId}")
            }

            // Felderkennung: Passwort hat Vorrang vor Benutzername.
            // Alle drei Erkennungswege werden geprüft (Hints, inputType-Bits, htmlInfo).
            when {
                // Passwort-Feld erkennen:
                View.AUTOFILL_HINT_PASSWORD in hints ||                           // Standard-Hint
                (inputType and android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD) != 0 ||  // Keyboard-Typ
                (inputType and android.text.InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD) != 0 ||
                htmlInputType == "password" -> {                                   // Chrome
                    if (passwordId == null) passwordId = node.autofillId
                }
                // Benutzername-/E-Mail-Feld erkennen:
                View.AUTOFILL_HINT_USERNAME in hints ||
                View.AUTOFILL_HINT_EMAIL_ADDRESS in hints ||
                (inputType and android.text.InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS) != 0 ||
                (inputType and android.text.InputType.TYPE_TEXT_VARIATION_WEB_EMAIL_ADDRESS) != 0 ||
                htmlInputType == "email" -> {                                      // Chrome
                    if (usernameId == null) usernameId = node.autofillId
                }
            }

            // Rekursiv alle Kinder dieses Knotens durchsuchen.
            for (i in 0 until node.childCount) {
                traverseNode(node.getChildAt(i))
            }
        }

        // Alle Fenster der AssistStructure durchgehen (meist nur eines).
        for (i in 0 until structure.windowNodeCount) {
            val windowNode = structure.getWindowNodeAt(i)

            // Domain aus dem Fenstertitel als Fallback (wenn webDomain nicht gesetzt ist).
            // Chrome formatiert den Titel typischerweise als "paypal.com - Google Chrome".
            if (domain == null) {
                windowNode.title?.toString()?.let { title ->
                    val parts = title.split(" - ", " – ")
                    if (parts.size >= 2) domain = parts[0].trim()
                }
            }
            traverseNode(windowNode.rootViewNode)
        }

        return ParsedStructure(domain, usernameId, passwordId)
    }

    companion object {
        /** Intent-Action: Signalisiert, dass PriVault im Autofill-Modus geöffnet werden soll. */
        const val ACTION_AUTOFILL_PICK = "de.frohlfing.privault.AUTOFILL_PICK"

        /** Intent-Extra: Die Domain der Ziel-Website (z.B. "paypal.com"). */
        const val EXTRA_DOMAIN = "autofill_domain"

        /** Intent-Extra: AutofillId des Benutzername-Felds im Formular. */
        const val EXTRA_USERNAME_ID = "autofill_username_id"

        /** Intent-Extra: AutofillId des Passwort-Felds im Formular. */
        const val EXTRA_PASSWORD_ID = "autofill_password_id"

        /** Nicht mehr in Verwendung, aber für eventuelle Kompatibilität erhalten. */
        const val EXTRA_RESULT_USERNAME = "autofill_result_username"
        const val EXTRA_RESULT_PASSWORD = "autofill_result_password"

        /** Eindeutiger Request-Code für den PendingIntent. */
        private const val REQUEST_CODE_AUTOFILL = 1001

        private const val TAG = "PriVault"

        /**
         * Baut das Dataset mit den echten Zugangsdaten auf.
         *
         * Ein `Dataset` ist der Behälter, den Android benötigt, um Formularfelder
         * zu befüllen. Er ordnet jedem Formularfeld (identifiziert durch seine
         * [AutofillId]) einen Wert zu.
         *
         * Diese Methode wird von [AutofillAuthActivity] aufgerufen, nachdem der
         * Nutzer einen Eintrag in PriVault ausgewählt hat.
         *
         * @param packageName  Wird für das RemoteViews-Layout benötigt (Präsentation).
         * @param usernameId   AutofillId des Benutzername-Felds (kann null sein, wenn
         *                     das Formular nur ein Passwort-Feld hat).
         * @param passwordId   AutofillId des Passwort-Felds.
         * @param username     Der einzutragende Benutzername.
         * @param password     Das einzutragende Passwort.
         */
        fun buildDataset(
            packageName: String,
            usernameId: AutofillId?,
            passwordId: AutofillId?,
            username: String,
            password: String,
        ): Dataset {
            // Präsentation für das befüllte Dataset (zeigt den Benutzernamen,
            // falls Android noch mal eine Auswahl anzeigt).
            val presentation = RemoteViews(packageName, R.layout.autofill_suggestion).apply {
                setTextViewText(R.id.autofill_label, username)
            }

            // Ab API 28: setValue mit Presentation pro Feld (nicht-deprecated API).
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                Dataset.Builder().apply {
                    usernameId?.let { setValue(it, AutofillValue.forText(username), presentation) }
                    passwordId?.let { setValue(it, AutofillValue.forText(password), presentation) }
                }.build()
            } else {
                // API < 28: Ältere API mit einer Presentation für das gesamte Dataset.
                @Suppress("DEPRECATION")
                Dataset.Builder(presentation).apply {
                    usernameId?.let { setValue(it, AutofillValue.forText(username)) }
                    passwordId?.let { setValue(it, AutofillValue.forText(password)) }
                }.build()
            }
        }
    }
}
