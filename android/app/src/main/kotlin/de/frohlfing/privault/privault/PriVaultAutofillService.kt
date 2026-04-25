package de.frohlfing.privault.privault

import android.app.PendingIntent
import android.app.assist.AssistStructure
import android.app.assist.AssistStructure.ViewNode
import android.os.CancellationSignal
import android.service.autofill.*
import android.view.View
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import android.widget.RemoteViews
import android.content.Intent

class PriVaultAutofillService : AutofillService() {

    override fun onFillRequest(request: FillRequest, cancellationSignal: CancellationSignal, callback: FillCallback) {
        val structure = request.fillContexts.lastOrNull()?.structure ?: run {
            callback.onSuccess(null)
            return
        }

        val parsed = parseStructure(structure)
        if (parsed.usernameId == null && parsed.passwordId == null) {
            callback.onSuccess(null)
            return
        }

        val autofillIds = listOfNotNull(parsed.usernameId, parsed.passwordId).toTypedArray()

        // Auth-Intent: Öffnet die Flutter-App zur Credential-Auswahl
        val authIntent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_AUTOFILL_PICK
            putExtra(EXTRA_DOMAIN, parsed.domain)
            putExtra(EXTRA_USERNAME_ID, parsed.usernameId)
            putExtra(EXTRA_PASSWORD_ID, parsed.passwordId)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        val pendingIntent = PendingIntent.getActivity(
            this, REQUEST_CODE_AUTOFILL, authIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val presentation = RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
            setTextViewText(android.R.id.text1, "PriVault")
        }

        val response = FillResponse.Builder()
            .setAuthentication(autofillIds, pendingIntent.intentSender, presentation)
            .build()

        callback.onSuccess(response)
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        callback.onSuccess()
    }

    // -------------------------------------------------------------------------

    private data class ParsedStructure(
        val domain: String?,
        val usernameId: AutofillId?,
        val passwordId: AutofillId?,
    )

    private fun parseStructure(structure: AssistStructure): ParsedStructure {
        var domain: String? = null
        var usernameId: AutofillId? = null
        var passwordId: AutofillId? = null

        fun traverseNode(node: ViewNode) {
            // Domain aus der Web-URL ableiten
            if (domain == null) {
                node.webDomain?.takeIf { it.isNotBlank() }?.let { domain = it }
            }

            val hints = node.autofillHints ?: emptyArray()
            val inputType = node.inputType

            when {
                View.AUTOFILL_HINT_PASSWORD in hints ||
                (inputType and android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD) != 0 ||
                (inputType and android.text.InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD) != 0 -> {
                    if (passwordId == null) passwordId = node.autofillId
                }
                View.AUTOFILL_HINT_USERNAME in hints ||
                View.AUTOFILL_HINT_EMAIL_ADDRESS in hints ||
                (inputType and android.text.InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS) != 0 ||
                (inputType and android.text.InputType.TYPE_TEXT_VARIATION_WEB_EMAIL_ADDRESS) != 0 -> {
                    if (usernameId == null) usernameId = node.autofillId
                }
            }

            for (i in 0 until node.childCount) {
                traverseNode(node.getChildAt(i))
            }
        }

        for (i in 0 until structure.windowNodeCount) {
            val windowNode = structure.getWindowNodeAt(i)
            // Domain aus dem Window-Titel ableiten (Fallback)
            if (domain == null) {
                windowNode.title?.toString()?.let { title ->
                    // Typisches Format: "paypal.com - Chrome"
                    val parts = title.split(" - ", " – ")
                    if (parts.size >= 2) domain = parts[0].trim()
                }
            }
            traverseNode(windowNode.rootViewNode)
        }

        return ParsedStructure(domain, usernameId, passwordId)
    }

    companion object {
        const val ACTION_AUTOFILL_PICK = "de.frohlfing.privault.AUTOFILL_PICK"
        const val EXTRA_DOMAIN = "autofill_domain"
        const val EXTRA_USERNAME_ID = "autofill_username_id"
        const val EXTRA_PASSWORD_ID = "autofill_password_id"
        const val EXTRA_RESULT_USERNAME = "autofill_result_username"
        const val EXTRA_RESULT_PASSWORD = "autofill_result_password"
        private const val REQUEST_CODE_AUTOFILL = 1001

        /** Baut das FillResponse-Dataset aus dem Activity-Result zusammen. */
        fun buildDataset(
            packageName: String,
            usernameId: AutofillId?,
            passwordId: AutofillId?,
            username: String,
            password: String,
        ): Dataset {
            val presentation = RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
                setTextViewText(android.R.id.text1, username)
            }
            return Dataset.Builder(presentation).apply {
                usernameId?.let { setValue(it, AutofillValue.forText(username)) }
                passwordId?.let { setValue(it, AutofillValue.forText(password)) }
            }.build()
        }
    }
}
