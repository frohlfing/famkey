package de.frohlfing.privault.privault

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.autofill.AutofillId
import android.view.autofill.AutofillManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channel = "de.frohlfing.privault/autofill"
    private var methodChannel: MethodChannel? = null

    // Werden gesetzt, wenn die Activity für Autofill geöffnet wurde
    private var autofillUsernameId: AutofillId? = null
    private var autofillPasswordId: AutofillId? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ArgonChannel.register(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    // Flutter fragt, ob die Activity im Autofill-Modus ist
                    "getAutofillRequest" -> {
                        if (intent?.action == PriVaultAutofillService.ACTION_AUTOFILL_PICK) {
                            result.success(mapOf(
                                "domain" to (intent.getStringExtra(PriVaultAutofillService.EXTRA_DOMAIN) ?: ""),
                            ))
                        } else {
                            result.success(null)
                        }
                    }
                    // Flutter hat ein Credential ausgewählt → Felder befüllen und Activity schließen
                    "completeAutofill" -> {
                        val username = call.argument<String>("username") ?: ""
                        val password = call.argument<String>("password") ?: ""
                        completeAutofill(username, password)
                        result.success(null)
                    }
                    // Flutter bricht die Autofill-Auswahl ab
                    "cancelAutofill" -> {
                        setResult(Activity.RESULT_CANCELED)
                        finish()
                        result.success(null)
                    }
                    // Prüft, ob PriVault aktuell als Autofill-Anbieter im System aktiv ist
                    "isAutofillEnabled" -> {
                        val afm = getSystemService(AutofillManager::class.java)
                        result.success(afm?.hasEnabledAutofillServices() == true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (intent?.action == PriVaultAutofillService.ACTION_AUTOFILL_PICK) {
            @Suppress("DEPRECATION")
            autofillUsernameId = intent.getParcelableExtra(PriVaultAutofillService.EXTRA_USERNAME_ID)
            @Suppress("DEPRECATION")
            autofillPasswordId = intent.getParcelableExtra(PriVaultAutofillService.EXTRA_PASSWORD_ID)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        if (intent.action == PriVaultAutofillService.ACTION_AUTOFILL_PICK) {
            @Suppress("DEPRECATION")
            autofillUsernameId = intent.getParcelableExtra(PriVaultAutofillService.EXTRA_USERNAME_ID)
            @Suppress("DEPRECATION")
            autofillPasswordId = intent.getParcelableExtra(PriVaultAutofillService.EXTRA_PASSWORD_ID)

            // Flutter über den neuen Autofill-Request informieren
            val domain = intent.getStringExtra(PriVaultAutofillService.EXTRA_DOMAIN) ?: ""
            methodChannel?.invokeMethod("onAutofillRequest", mapOf("domain" to domain))
        }
    }

    private fun completeAutofill(username: String, password: String) {
        val dataset = PriVaultAutofillService.buildDataset(
            packageName,
            autofillUsernameId,
            autofillPasswordId,
            username,
            password,
        )
        val replyIntent = Intent().apply {
            putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, dataset)
        }
        setResult(Activity.RESULT_OK, replyIntent)
        finish()
    }
}
