<?php
declare(strict_types=1);

namespace App\Controller;

use App\Core\Database;
use App\Core\Request;
use App\Core\Response;

/**
 * Controller für Tresore.
 */
final class VaultController
{
    /**
     * Löscht einen Test-Tresor (falls vorhanden) und bereinigt veraltete Test-Tresore.
     *
     * Endpunkt: <code>DELETE /vaults</code>
     *
     * Header:
     * <code>
     * Authorization: Bearer {api_token}
     * </code>
     *
     * Query:
     * <code>
     * vault_hash={vault_hash}
     * </code>
     *
     * Body: -
     *
     * Antwort (204 No Content): -
     *
     * Antwort (401, 403, 422, 500):
     * <code>
     * { "error": "{Fehlermeldung}" }
     * </code>
     *
     * Mögliche Statuscodes:
     * - 204 No Content
     * - 401 Unauthorized: API-Token fehlt oder ist ungültig
     * - 403 Forbidden: vault_hash gehört zu einem Nicht-Test-Tresor (nur Test-Tresore dürfen gelöscht werden)
     * - 422 Unprocessable Entity: Pflichtfeld vault_hash fehlt/ist leer
     * - 500 Internal Server Error
     *
     * @param Request $request
     * @return Response
     */
    public function deleteTestVaultIfExists(Request $request): Response
    {
        // Parameter holen
        $request->ensureHas(['vault_hash']);
        $vaultHash = $request->string('vault_hash');

        // Bereinigung: Alle Test-Tresore löschen, die älter als 10 Minuten sind.
        $pdo = Database::pdo();
        $pdo->exec("DELETE FROM vaults WHERE is_test = 1 AND created_at < DATE_SUB(NOW(), INTERVAL 10 MINUTE)");

        // Den zu angegebenen Tresor suchen
        $stmt = $pdo->prepare('SELECT is_test FROM vaults WHERE hash_name = ?');
        $stmt->execute([$vaultHash]);
        $isTestVault = $stmt->fetchColumn();

        // Falls es den Tresor gibt, soll er gelöscht werden.
        if ($isTestVault !== false) {
            if ((int)$isTestVault !== 1) {
                return Response::error(403, 'Nur Test-Tresore können über diesen Endpunkt gelöscht werden.');
            }

            // Test-Tresor löschen (durch die Kaskadierung in der DB werden verknüpfte Daten mit gelöscht)
            $stmt = $pdo->prepare('DELETE FROM vaults WHERE hash_name = ?');
            $stmt->execute([$vaultHash]);
        }

        // Antwort generieren (204 No Content)
        return Response::empty();
    }

    /**
     * Löscht den Tresor des authentifizierten Benutzers serverseitig.
     *
     * Endpunkt: <code>DELETE /users/{user_uuid}/vault</code>
     *
     * Header:
     * <code>
     * Authorization: Bearer {api_token}
     * X-User-Uuid: {user_uuid}
     * X-Timestamp: {unix_timestamp_utc}
     * X-Signature: {base64_signature}
     * </code>
     *
     * Query: -
     *
     * Body: -
     *
     * Antwort (204 No Content): -
     *
     * Antwort (401, 403, 404, 422, 500):
     * <code>
     * { "error": "{Fehlermeldung}" }
     * </code>
     *
     * Mögliche Statuscodes:
     * - 204 No Content
     * - 401 Unauthorized: API-Token fehlt/ungültig oder RSA-Header/Signatur fehlt/ungültig
     * - 403 Forbidden: user_uuid stimmt nicht mit der RSA-identifizierten UUID überein
     * - 404 Not Found: Benutzer oder Tresor nicht gefunden
     * - 422 Unprocessable Entity: Pflichtfeld user_uuid fehlt/ist leer
     * - 500 Internal Server Error
     *
     * @param Request $request
     * @return Response
     */
    public function deleteVault(Request $request): Response
    {
        // Parameter holen
        $request->ensureHas(['user_uuid']);
        $userUuid = $request->string('user_uuid');

        // Sicherstellen, dass der angegebene Benutzer der authentifizierte Benutzer ist.
        if ($userUuid !== $request->authUserUuid()) {
            return Response::error(403);
        }

        // Tresor des Benutzers ermitteln
        $pdo = Database::pdo();
        $stmt = $pdo->prepare('SELECT vault_uuid FROM users WHERE uuid = ?');
        $stmt->execute([$userUuid]);
        $vaultUuid = $stmt->fetchColumn();
        if (!$vaultUuid) {
            return Response::error(404, 'Benutzer oder Tresor nicht gefunden');
        }

        // Prüfen, ob der Benutzer der letzte im Tresor ist.
        $stmt = $pdo->prepare('SELECT COUNT(*) FROM users WHERE vault_uuid = ?');
        $stmt->execute([$vaultUuid]);
        $userCount = (int)$stmt->fetchColumn();

        if ($userCount <= 1) {
            // Letzter Benutzer → gesamten Tresor löschen (Kaskadierung entfernt
            // entries, permissions, tombstones, attachments, users)
            $stmt = $pdo->prepare('DELETE FROM vaults WHERE uuid = ?');
            $stmt->execute([$vaultUuid]);
        } else {
            // Nicht der letzte Benutzer → nur eigenen Datensatz entfernen.
            // Der Tresor und die Daten der anderen Benutzer bleiben erhalten.
            // Permissions des Benutzers werden durch FK-Kaskadierung automatisch gelöscht.
            $stmt = $pdo->prepare('DELETE FROM users WHERE uuid = ?');
            $stmt->execute([$userUuid]);
        }

        // Antwort generieren (204 No Content)
        return Response::empty();
    }
}