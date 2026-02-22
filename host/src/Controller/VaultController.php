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
}