<?php
declare(strict_types=1);

namespace App\Controller;

use App\Core\Database;
use App\Core\Request;
use App\Core\Response;

/**
 * Controller für Dateianhänge.
 */
final class AttachmentController
{
    /**
     * Dateianhänge laden und speichern.
     *
     * Endpunkt: <code>GET /attachments/{attachment_uuid}</code>
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
     * Antwort (200 OK):
     * <code>
     * {
     *   "attachment_uuid": "{attachment_uuid}",
     *   "entry_uuid": "{entry_uuid}",
     *   "encrypted_meta": "<base64>",
     *   "encrypted_content": "<base64>"
     * }
     * </code>
     *
     * Antwort (401, 403, 404, 422, 500):
     * <code>
     * { "error": "{Fehlermeldung}" }
     * </code>
     *
     * Mögliche Statuscodes:
     * - 200 OK
     * - 401 Unauthorized: API-Token fehlt/ungültig oder RSA-Header/Signatur fehlt/ungültig
     * - 403 Forbidden: kein Zugriff auf den zugehörigen Entry
     * - 404 Not Found: Attachment nicht gefunden
     * - 422 Unprocessable Entity: Pflichtfeld attachment_uuid fehlt/ist leer
     * - 500 Internal Server Error
     *
     * @param Request $request
     * @return Response
     */
    public function getAttachment(Request $request): Response
    {
        // Parameter holen
        $request->ensureHas(['attachment_uuid']);
        $attachmentUuid = $request->string('attachment_uuid');

        // Tresor des authentifizierten Benutzers ermitteln
        $pdo = Database::pdo();
        $stmt = $pdo->prepare('SELECT vault_uuid FROM users WHERE uuid = ?');
        $stmt->execute([$request->authUserUuid()]);
        $vaultUuid = $stmt->fetchColumn();
        if (!$vaultUuid) {
            return Response::error(403);
        }

        // Daten aus Datenbank holen
        $stmt = $pdo->prepare("
            SELECT entry_uuid, encrypted_meta, encrypted_content
            FROM attachments
            WHERE uuid = ? AND vault_uuid = ?
            ");
        $stmt->execute([$attachmentUuid, $vaultUuid]);
        $row = $stmt->fetch();
        if (!$row) {
            return Response::error(404, 'Attachment nicht gefunden');
        }
        $entryUuid = (string)$row['entry_uuid'];
        $encryptedMeta = $row['encrypted_meta'] ?? '';
        $encryptedContent = $row['encrypted_content'] ?? '';

        // Sicherstellen, dass der authentifizierte Benutzer Zugriff auf den Eintrag hat.
        $access = $this->requireEntryAccess($request->authUserUuid(), $entryUuid, $vaultUuid);
        if (!$access) {
            return Response::error(403); // Nicht autorisiert
        }

        // Antwort generieren
        return Response::json([
            'attachment_uuid' => $attachmentUuid,
            'entry_uuid' => $entryUuid,
            'encrypted_meta' => base64_encode($encryptedMeta),
            'encrypted_content' => base64_encode($encryptedContent),
        ]);
    }

    /**
     * Speichert einen neuen Anhang (Metadaten & Inhalt) oder aktualisiert einen bestehenden.
     *
     * Endpunkt: <code>PUT /attachments/{attachment_uuid}</code>
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
     * Body:
     * <code>
     * {
     *   "entry_uuid": "{entry_uuid}",
     *   "encrypted_meta": "<base64>",
     *   "encrypted_content": "<base64>"
     * }
     * </code>
     *
     * Antwort (204 No Content): -
     *
     * Antwort (401, 403, 413, 422, 500):
     * <code>
     * { "error": "{Fehlermeldung}" }
     * </code>
     *
     * Mögliche Statuscodes:
     * - 204 No Content
     * - 401 Unauthorized: API-Token fehlt/ungültig oder RSA-Header/Signatur fehlt/ungültig
     * - 403 Forbidden: kein Zugriff auf den Entry oder Schreibrechte fehlen
     * - 413 Payload Too Large: Attachment überschreitet das Größenlimit
     * - 422 Unprocessable Entity: Payload fehlt/unvollständig oder Base64 ist ungültig
     * - 500 Internal Server Error
     *
     * @param Request $request
     * @return Response
     */
    public function createAttachment(Request $request): Response
    {
        // Parameter holen
        $request->ensureHas(['attachment_uuid', 'entry_uuid', 'encrypted_meta', 'encrypted_content']);
        $attachmentUuid = $request->string('attachment_uuid');
        $entryUuid = $request->string('entry_uuid');
        $encryptedMeta = $request->string('encrypted_meta');
        $encryptedContent = $request->string('encrypted_content');

        // Base64 dekodieren
        $metaBinary = base64_decode($encryptedMeta, true);
        $contentBinary = base64_decode($encryptedContent, true);
        if ($metaBinary === false || $contentBinary === false) {
            return Response::error(422, 'Daten sind kein gültiges Base64');
        }

        // Größe prüfen
        if (strlen($contentBinary) > (int)MAX_ATTACHMENT_BYTES) {
            return Response::error(413, 'Attachment zu groß (max ' . (int)MAX_ATTACHMENT_BYTES . ' Bytes)');
        }

        // Tresor des authentifizierten Benutzers ermitteln
        $pdo = Database::pdo();
        $stmt = $pdo->prepare('SELECT vault_uuid FROM users WHERE uuid = ?');
        $stmt->execute([$request->authUserUuid()]);
        $vaultUuid = $stmt->fetchColumn();
        if (!$vaultUuid) {
            return Response::error(403);
        }

        // Sicherstellen, dass der authentifizierte Benutzer Zugriff auf den Eintrag hat.
        $access = $this->requireEntryAccess($request->authUserUuid(), $entryUuid, $vaultUuid);
        if (!$access) {
            return Response::error(403); // Nicht autorisiert
        }
        if ($access['access_level'] < 2) {
            return Response::error(403, 'Schreibrechte erforderlich');
        }

        // Prüfen, ob UUID bereits existiert (vault_uuid-scoped)
        $check = $pdo->prepare('SELECT COUNT(*) FROM attachments WHERE uuid = ? AND vault_uuid = ?');
        $check->execute([$attachmentUuid, $vaultUuid]);
        $exists = (int)$check->fetchColumn() > 0;
        if ($exists) { // Anhang existiert bereits
            // Anhang aktualisieren
            $stmt = $pdo->prepare('UPDATE attachments SET encrypted_meta = ?, encrypted_content = ? WHERE uuid = ? AND vault_uuid = ?');
            $stmt->execute([$metaBinary, $contentBinary, $attachmentUuid, $vaultUuid]);
        }
        else { // Anhang existiert nicht
            // Anhang hinzufügen
            $stmt = $pdo->prepare('INSERT INTO attachments (uuid, entry_uuid, vault_uuid, encrypted_meta, encrypted_content) VALUES (?, ?, ?, ?, ?)');
            $stmt->execute([$attachmentUuid, $entryUuid, $vaultUuid, $metaBinary, $contentBinary]);
        }

        // Antwort generieren (204 No Content)
        return Response::empty();
    }

    /**
     * Prüft, ob der authentifizierte Nutzer Zugriff auf den Entry hat, und liefert access_level sowie vault_uuid.
     *
     * @param string $userUuid
     * @param string $entryUuid
     * @param string $vaultUuid
     * @return array{access_level:int,vault_uuid:string}|null
     */
    private function requireEntryAccess(string $userUuid, string $entryUuid, string $vaultUuid): ?array
    {
        $pdo = Database::pdo();
        $stmt = $pdo->prepare('
            SELECT p.access_level, e.vault_uuid
            FROM permissions p
            JOIN entries e ON e.uuid = p.entry_uuid AND e.vault_uuid = p.vault_uuid
            WHERE p.user_uuid = ? AND p.entry_uuid = ? AND p.vault_uuid = ? AND p.access_level > 0
        ');
        $stmt->execute([$userUuid, $entryUuid, $vaultUuid]);
        $row = $stmt->fetch();

        return $row ? ['access_level' => (int)$row['access_level'], 'vault_uuid' => $row['vault_uuid']] : null;
    }
}