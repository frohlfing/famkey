package de.frohlfing.privault.privault

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.view.autofill.AutofillId
import android.view.autofill.AutofillManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Haupt-Activity von PriVault – der einzige "Bildschirm" der Flutter-App.
 *
 * # Was ist eine FlutterActivity?
 *
 * `FlutterActivity` ist eine Android-Activity, die eine Flutter-Engine einbettet.
 * Der gesamte Dart-Code läuft innerhalb dieser Activity. Aus Android-Sicht ist
 * PriVault eine ganz normale App mit einer Activity – nur dass diese Activity
 * statt nativer Android-Views einen Flutter-Canvas rendert.
 *
 * # Die Brücke zwischen Flutter (Dart) und Android (Kotlin): MethodChannel
 *
 * Flutter und Android kommunizieren über einen MethodChannel. Das ist ein
 * bidirektionaler Nachrichtenkanal mit einem gemeinsamen Namen:
 *
 *   `"de.frohlfing.privault/autofill"`
 *
 * Dart kann Methoden "aufrufen" und Kotlin antwortet:
 *   Dart: `channel.invokeMethod('completeAutofill', {...})`
 *   Kotlin: `call.method == "completeAutofill"` → verarbeiten → `result.success(null)`
 *
 * Kotlin kann auch Dart aufrufen (umgekehrte Richtung):
 *   Kotlin: `methodChannel?.invokeMethod("onAutofillRequest", {...})`
 *   Dart: registrierter Handler in `autofill_service_android.dart`
 *
 * # Autofill-Ablauf in dieser Klasse
 *
 * Diese Activity wird auf zwei verschiedene Arten im Autofill-Kontext aufgerufen:
 *
 * **onCreate (Cold-Start oder neuer Task):**
 *   PriVault war nicht gestartet. [AutofillAuthActivity] hat diese Activity mit
 *   `FLAG_ACTIVITY_NEW_TASK` und dem `ACTION_AUTOFILL_PICK`-Intent gestartet.
 *   Die Autofill-IDs werden aus dem Intent gelesen und gespeichert.
 *   Dart holt sie dann über `getAutofillRequest` via MethodChannel ab.
 *
 * **onNewIntent (Warm-Start):**
 *   PriVault lief bereits. Wegen `launchMode="singleTop"` im Manifest wird keine
 *   neue Activity-Instanz erzeugt – stattdessen wird `onNewIntent` mit dem neuen
 *   Intent aufgerufen. Dart wird über `onAutofillRequest` via MethodChannel
 *   benachrichtigt.
 */
class MainActivity : FlutterActivity() {

    /** Name des MethodChannels – muss auf Dart-Seite identisch sein. */
    private val channel = "de.frohlfing.privault/autofill"

    /**
     * Referenz auf den MethodChannel, gespeichert für Kotlin→Dart-Aufrufe.
     * Wird in `configureFlutterEngine` gesetzt, sobald die Flutter-Engine
     * bereit ist.
     */
    private var methodChannel: MethodChannel? = null

    /**
     * AutofillId des Benutzername-Felds im Formular der anfragenden App (z.B. Chrome).
     * Wird aus dem Intent gelesen, wenn die Activity im Autofill-Modus geöffnet wird.
     * Wird in `completeAutofill` als Fallback verwendet, falls kein Relay aktiv ist.
     */
    private var autofillUsernameId: AutofillId? = null

    /**
     * AutofillId des Passwort-Felds. Analog zu [autofillUsernameId].
     */
    private var autofillPasswordId: AutofillId? = null

    /**
     * Konfiguriert die Flutter-Engine und richtet den MethodChannel ein.
     *
     * Diese Methode wird aufgerufen, bevor der erste Flutter-Frame gerendert wird.
     * Hier registriert Kotlin alle Methoden, die Dart aufrufen kann.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {

                    // ─────────────────────────────────────────────────────────
                    // Dart fragt: "Wurde diese Activity mit einem Autofill-Request
                    // gestartet?" (Szenario A: Cold-Start)
                    //
                    // Dart ruft das beim App-Start in autofill_service_android.dart
                    // unter init() auf. Wenn ja, liefert Kotlin die Domain zurück,
                    // damit Dart _pendingDomain setzen kann.
                    // ─────────────────────────────────────────────────────────
                    "getAutofillRequest" -> {
                        if (intent?.action == PriVaultAutofillService.ACTION_AUTOFILL_PICK) {
                            val domain = intent.getStringExtra(PriVaultAutofillService.EXTRA_DOMAIN) ?: ""
                            Log.d(TAG, "getAutofillRequest: domain=$domain")
                            result.success(mapOf("domain" to domain))
                        } else {
                            Log.d(TAG, "getAutofillRequest: kein Autofill-Intent")
                            result.success(null)  // null = kein Autofill-Request
                        }
                    }

                    // ─────────────────────────────────────────────────────────
                    // Dart meldet: "Der Nutzer hat einen Eintrag ausgewählt."
                    // (Aufruf aus AutofillPickerPage._selectEntry via complete())
                    //
                    // Ablauf:
                    // 1. Relay.deliver() → AutofillAuthActivity.onResult-Callback
                    // 2. AutofillAuthActivity baut Dataset, ruft setResult(OK), finish()
                    // 3. moveTaskToBack(true) → PriVault geht in den Hintergrund
                    //    (statt finish(), damit die Flutter-Session erhalten bleibt)
                    // ─────────────────────────────────────────────────────────
                    "completeAutofill" -> {
                        val username = call.argument<String>("username") ?: ""
                        val password = call.argument<String>("password") ?: ""
                        Log.d(TAG, "completeAutofill: username=$username, usernameId=$autofillUsernameId, passwordId=$autofillPasswordId")
                        completeAutofill(username, password)
                        result.success(null)
                    }

                    // ─────────────────────────────────────────────────────────
                    // Dart meldet: "Der Nutzer hat den X-Button gedrückt."
                    // (Aufruf aus AutofillPickerPage, Schließen-Button)
                    //
                    // Das Relay informiert AutofillAuthActivity über den Abbruch,
                    // damit das Autofill-Framework korrekt benachrichtigt wird.
                    // PriVault geht in den Hintergrund (Session bleibt erhalten).
                    // ─────────────────────────────────────────────────────────
                    "cancelAutofill" -> {
                        Log.d(TAG, "cancelAutofill")
                        // Relay-Cancel versuchen (liefert CANCELED an AutofillAuthActivity falls noch aktiv)
                        AutofillResultRelay.cancel()
                        // Immer in den Hintergrund – nie finish(), damit die Session erhalten bleibt
                        moveTaskToBack(true)
                        result.success(null)
                    }

                    // ─────────────────────────────────────────────────────────
                    // Dart fragt: "Ist PriVault als Autofill-Provider ausgewählt?"
                    // Wird in den Einstellungen angezeigt.
                    // ─────────────────────────────────────────────────────────
                    "isAutofillEnabled" -> {
                        val afm = getSystemService(AutofillManager::class.java)
                        result.success(afm?.hasEnabledAutofillServices() == true)
                    }

                    // ─────────────────────────────────────────────────────────
                    // Dart möchte die Android-Systemeinstellungen öffnen, wo der
                    // Nutzer PriVault als Autofill-Provider auswählen kann.
                    // ─────────────────────────────────────────────────────────
                    "openAutofillSettings" -> {
                        val intent = Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    /**
     * Wird aufgerufen, wenn die Activity zum ersten Mal erzeugt wird (Cold-Start).
     *
     * Im Autofill-Fall hat [AutofillAuthActivity] diese Activity mit einem speziellen
     * Intent gestartet. Wir lesen die Formularfeld-IDs aus dem Intent, damit sie
     * als Fallback in [completeAutofill] verfügbar sind, falls das Relay nicht aktiv ist.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (intent?.action == PriVaultAutofillService.ACTION_AUTOFILL_PICK) {
            autofillUsernameId = getAutofillId(intent, PriVaultAutofillService.EXTRA_USERNAME_ID)
            autofillPasswordId = getAutofillId(intent, PriVaultAutofillService.EXTRA_PASSWORD_ID)
            val domain = intent.getStringExtra(PriVaultAutofillService.EXTRA_DOMAIN) ?: ""
            Log.d(TAG, "onCreate (Autofill): domain=$domain, usernameId=$autofillUsernameId, passwordId=$autofillPasswordId")
        }
    }

    /**
     * Wird aufgerufen, wenn ein neuer Intent an diese (bereits laufende) Activity gesendet wird.
     *
     * Wegen `launchMode="singleTop"` im AndroidManifest wird keine neue Instanz erzeugt,
     * wenn PriVault schon im Vordergrund oder im Hintergrund läuft. Stattdessen erhält
     * die bestehende Instanz den neuen Intent hier.
     *
     * Im Autofill-Warm-Start: [AutofillAuthActivity] hat MainActivity mit
     * `FLAG_ACTIVITY_NEW_TASK` gestartet. Da PriVault bereits einen Task hat,
     * bringt das diesen Task in den Vordergrund und triggert `onNewIntent`.
     *
     * Wichtig: `setIntent(intent)` aktualisiert den "aktuellen Intent" der Activity,
     * damit spätere Aufrufe von `getIntent()` den neuen Intent liefern.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        if (intent.action == PriVaultAutofillService.ACTION_AUTOFILL_PICK) {
            autofillUsernameId = getAutofillId(intent, PriVaultAutofillService.EXTRA_USERNAME_ID)
            autofillPasswordId = getAutofillId(intent, PriVaultAutofillService.EXTRA_PASSWORD_ID)
            val domain = intent.getStringExtra(PriVaultAutofillService.EXTRA_DOMAIN) ?: ""
            Log.d(TAG, "onNewIntent (Autofill): domain=$domain, usernameId=$autofillUsernameId, passwordId=$autofillPasswordId")

            // Dart (autofill_service_android.dart) über den neuen Autofill-Request informieren.
            // Dart setzt _pendingDomain und navigiert zu /autofill-picker (falls eingeloggt).
            methodChannel?.invokeMethod("onAutofillRequest", mapOf("domain" to domain))
        }
    }

    /**
     * Liest eine [AutofillId] aus dem Intent-Extra auf eine Art, die auch auf
     * Android 13+ (API 33) ohne Deprecation-Warnung funktioniert.
     *
     * [AutofillId] ist ein Parcelable-Objekt (serialisierbar für Intent-Extras).
     * Ab API 33 muss der erwartete Typ explizit angegeben werden.
     */
    private fun getAutofillId(intent: Intent, key: String): AutofillId? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(key, AutofillId::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(key)
        }

    /**
     * Führt den Autofill-Abschluss durch: liefert die Zugangsdaten an [AutofillAuthActivity]
     * und sendet PriVault in den Hintergrund.
     *
     * # Normalfall (Relay aktiv)
     *
     * [AutofillResultRelay.deliver] ruft den in [AutofillAuthActivity] registrierten
     * Callback auf. Dieser baut das Dataset und ruft `setResult(RESULT_OK)` + `finish()`
     * auf AutofillAuthActivity auf. Danach kommt Chrome wieder in den Vordergrund,
     * und das Autofill-Framework befüllt das Formular.
     *
     * Anschließend ruft [moveTaskToBack] PriVaults Task in den Hintergrund.
     *
     * # Warum moveTaskToBack statt finish()?
     *
     * `finish()` würde die Activity zerstören → die Flutter-Engine wird heruntergefahren
     * → alle Dart-Objekte (SessionService, entschlüsselte Schlüssel) gehen verloren →
     * der Nutzer müsste sich erneut einloggen.
     *
     * `moveTaskToBack(true)` schickt den Task in den Hintergrund, ohne etwas zu
     * zerstören. Die Flutter-Engine läuft weiter (im Hintergrund). Der Nutzer bleibt
     * eingeloggt und sieht beim nächsten Öffnen von PriVault sofort seine Einträge.
     *
     * # Fallback (Relay nicht aktiv)
     *
     * Falls `deliver()` false zurückgibt (kein aktives Relay, was ungewöhnlich wäre),
     * baut diese Activity selbst ein Dataset und liefert es direkt via `setResult()`.
     * Das funktioniert nur korrekt, wenn diese Activity selbst im richtigen Task sitzt.
     */
    private fun completeAutofill(username: String, password: String) {
        Log.d(TAG, "completeAutofill: username=$username, usernameId=$autofillUsernameId, passwordId=$autofillPasswordId")

        // Normalfall: AutofillAuthActivity wartet im Relay auf das Ergebnis.
        // moveTaskToBack statt finish() → Flutter-Session (Schlüssel, Login) bleibt erhalten.
        if (AutofillResultRelay.deliver(username, password)) {
            Log.d(TAG, "completeAutofill: via Relay geliefert")
            moveTaskToBack(true)
            return
        }

        // Fallback (falls direkt ohne Relay aufgerufen)
        Log.d(TAG, "completeAutofill: kein Relay – baue Dataset direkt")
        val dataset = PriVaultAutofillService.buildDataset(packageName, autofillUsernameId, autofillPasswordId, username, password)
        val replyIntent = Intent().apply {
            putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, dataset)
        }
        setResult(Activity.RESULT_OK, replyIntent)
        finish()
    }

    companion object {
        private const val TAG = "PriVault"
    }
}
