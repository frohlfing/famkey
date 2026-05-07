<?php
/** @noinspection DuplicatedCode */

declare(strict_types=1);

namespace App\Controller;

use App\Core\Database;
use App\Core\Request;
use App\Core\Response;
use App\Core\Time;
use App\Core\Uuid;
use PDOException;

/**
 * Controller für Benutzer.
 */
final class UserController
{
    /**
     * Liefert die Benutzerdaten anhand seiner UUID.
     *
     * Endpunkt: <code>GET /users/{user_uuid}</code>
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
     *   "user_uuid": "{user_uuid}",
     *   "vault_uuid": "{vault_uuid}",
     *   "user_hash": "{user_hash}",
     *   "salt": "{salt}",
     *   "public_key": "{public_key}",
     *   "encrypted_private_key": "{encrypted_private_key}",
     *   "master_key_timestamp": "{master_key_timestamp}",
     *   "encrypted_friends": "{encrypted_friends}"
     * }
     * </code>
     * <code>
     * null
     * </code>
     *
     * Antwort (401, 404, 422, 500):
     * <code>
     * { "error": "{Fehlermeldung}" }
     * </code>
     *
     * Mögliche Statuscodes:
     * - 200 OK
     * - 401 Unauthorized: API-Token fehlt oder ist ungültig
     * - 404 Not Found: Benutzer nicht gefunden
     * - 422 Unprocessable Entity: Pflichtfeld fehlt
     * - 500 Internal Server Error
     *
     * @param Request $request
     * @return Response
     */
    public function getUser(Request $request): Response
    {
        // Parameter holen
        $request->ensureHas(['user_uuid']);
        $userUuid = $request->string('user_uuid');

        // Benutzer holen
        $pdo = Database::pdo();
        $stmt = $pdo->prepare('
            SELECT 
                uuid AS user_uuid, 
                vault_uuid, 
                hash_name AS user_hash, 
                salt, 
                public_key, 
                encrypted_private_key,
                master_key_timestamp,
                encrypted_friends
            FROM users
            WHERE uuid = ?
        ');
        $stmt->execute([$userUuid]);
        $row = $stmt->fetch();

        // Prüfen, ob der User existiert
        if (!$row) {
            return Response::error(404, 'Benutzer nicht gefunden');
        }

        // Antwort generieren
        return Response::json($row);
    }

    /**
     * Sucht einen Benutzer in einem bestimmten Tresor anhand seines Namens-Hashes.
     *
     * Endpunkt: <code>GET /users</code>
     *
     * Header:
     * <code>
     * Authorization: Bearer {api_token}
     * </code>
     *
     * Query:
     * <code>
     * vault_hash={vault_hash}
     * user_hash={user_hash}
     * </code>
     *
     * Body: -
     *
     * Antwort (200 OK):
     * <code>
     * {
     *   "user_uuid": "{user_uuid}",
     *   "vault_uuid": "{vault_uuid}",
     *   "user_hash": "{user_hash}",
     *   "salt": "{salt}",
     *   "public_key": "{public_key}",
     *   "encrypted_private_key": "{encrypted_private_key}",
     *   "master_key_timestamp": "{master_key_timestamp}",
     *   "encrypted_friends": "{encrypted_friends}"
     * }
     * </code>
     * <code>
     * null
     * </code>
     *
     * Antwort (401, 422, 500):
     * <code>
     * { "error": "{Fehlermeldung}" }
     * </code>
     *
     * Mögliche Statuscodes:
     * - 200 OK
     * - 401 Unauthorized: API-Token fehlt oder ist ungültig
     * - 422 Unprocessable Entity: Pflichtfeld fehlt
     * - 500 Internal Server Error
     *
     * @param Request $request
     * @return Response
     */
    public function findUser(Request $request): Response
    {
        // Parameter holen
        $request->ensureHas(['vault_hash', 'user_hash']);
        $vaultHash = $request->string('vault_hash');
        $userHash = $request->string('user_hash');

        // Benutzer suchen (mit Organisations-Isolation im Multi-Tenant-Modus)
        $orgUuid = $request->orgUuid();
        $pdo = Database::pdo();
        if ($orgUuid !== null) {
            $stmt = $pdo->prepare('
                SELECT
                    u.uuid AS user_uuid,
                    u.vault_uuid,
                    u.hash_name AS user_hash,
                    u.salt,
                    u.public_key,
                    u.encrypted_private_key,
                    u.master_key_timestamp,
                    u.encrypted_friends
                FROM users u
                JOIN vaults v ON u.vault_uuid = v.uuid
                WHERE v.hash_name = ? AND u.hash_name = ? AND v.org_uuid = ?
            ');
            $stmt->execute([$vaultHash, $userHash, $orgUuid]);
        } else {
            $stmt = $pdo->prepare('
                SELECT
                    u.uuid AS user_uuid,
                    u.vault_uuid,
                    u.hash_name AS user_hash,
                    u.salt,
                    u.public_key,
                    u.encrypted_private_key,
                    u.master_key_timestamp,
                    u.encrypted_friends
                FROM users u
                JOIN vaults v ON u.vault_uuid = v.uuid
                WHERE v.hash_name = ? AND u.hash_name = ? AND v.org_uuid IS NULL
            ');
            $stmt->execute([$vaultHash, $userHash]);
        }
        $row = $stmt->fetch();
        if ($row === false) {
            $row = null; // Benutzer nicht gefunden
        }

        // Antwort generieren
        return Response::json($row);
    }

    /**
     * Registriert einen neuen Benutzer im Tresor (legt den Tresor ggf. an).
     *
     * Endpunkt: <code>POST /users</code>
     *
     * Header:
     * <code>
     * Authorization: Bearer {api_token}
     * </code>
     *
     * Query: -
     *
     * Body:
     * <code>
     * {
     *   "user_uuid": "{user_uuid}",
     *   "vault_hash": "{vault_hash}",
     *   "user_hash": "{user_hash}",
     *   "salt": "{salt}",
     *   "public_key": "{public_key}",
     *   "encrypted_private_key": "{encrypted_private_key}",
     *   "master_key_timestamp": "{master_key_timestamp}",
     * }
     * </code>
     *
     * Antwort (201 Created):
     * <code>
     * {
     *   "user_uuid": "{user_uuid}",
     *   "vault_uuid": "{vault_uuid}",
     *   "user_hash": "{user_hash}",
     *   "salt": "{salt}",
     *   "public_key": "{public_key}",
     *   "encrypted_private_key": "{encrypted_private_key}",
     *   "master_key_timestamp": "{master_key_timestamp}",
     *   "encrypted_friends": "{encrypted_friends}"
     * }
     * </code>
     *
     * Antwort (401, 409, 422, 500):
     * <code>
     * { "error": "{Fehlermeldung}" }
     * </code>
     *
     * Mögliche Statuscodes:
     * - 201 Created
     * - 401 Unauthorized: API-Token fehlt oder ist ungültig
     * - 409 Conflict: Benutzer existiert bereits (oder Konflikt bei Insert/Unique Constraint)
     * - 422 Unprocessable Entity: Pflichtfeld fehlt
     * - 500 Internal Server Error
     *
     * @param Request $request
     * @return Response
     */
    public function register(Request $request): Response
    {
        // Parameter holen
        $request->ensureHas(['user_uuid', 'vault_hash', 'user_hash', 'salt', 'public_key', 'encrypted_private_key', 'master_key_timestamp']);
        $userUuid = $request->string('user_uuid');
        $vaultHash = $request->string('vault_hash');
        $userHash = $request->string('user_hash');
        $salt = $request->string('salt');
        $publicKey = $request->string('public_key');
        $encryptedPrivateKey = $request->string('encrypted_private_key');
        $masterKeyTimestamp = Time::iso8601ToMysql($request->date('master_key_timestamp'));

        // Header-Parameter
        //$isTestRequest = !empty($request->server['HTTP_X_TEST']) ? 1 : 0;
        $isTestRequest = !empty($request->header('X-Test')) ? 1 : 0;

        $orgUuid = $request->orgUuid();

        try {
            // Tresor-ID ermitteln (innerhalb der Organisation im Multi-Tenant-Modus)
            $pdo = Database::pdo();
            if ($orgUuid !== null) {
                $stmt = $pdo->prepare('SELECT uuid FROM vaults WHERE hash_name = ? AND org_uuid = ?');
                $stmt->execute([$vaultHash, $orgUuid]);
            } else {
                $stmt = $pdo->prepare('SELECT uuid FROM vaults WHERE hash_name = ? AND org_uuid IS NULL');
                $stmt->execute([$vaultHash]);
            }
            $vaultUuid = $stmt->fetchColumn();

            // Tresor anlegen, falls noch nicht vorhanden
            if (!$vaultUuid) {
                $vaultUuid = Uuid::v4();
                try {
                    if ($orgUuid !== null) {
                        $stmtInsert = $pdo->prepare('INSERT INTO vaults (uuid, hash_name, is_test, org_uuid) VALUES (?, ?, ?, ?)');
                        $stmtInsert->execute([$vaultUuid, $vaultHash, $isTestRequest, $orgUuid]);
                    } else {
                        $stmtInsert = $pdo->prepare('INSERT INTO vaults (uuid, hash_name, is_test) VALUES (?, ?, ?)');
                        $stmtInsert->execute([$vaultUuid, $vaultHash, $isTestRequest]);
                    }
                } catch (PDOException $e) {
                    if ($e->getCode() !== '23000') { // nicht "Can't write; duplicate key in table" (s. https://dev.mysql.com/doc/mysql-errors/8.0/en/server-error-reference.html)
                        throw $e;
                    }
                    // Race: Tresor existiert inzwischen – erneut lesen
                    $stmt->execute($orgUuid !== null ? [$vaultHash, $orgUuid] : [$vaultHash]);
                    $vaultUuid = $stmt->fetchColumn();
                    if (!$vaultUuid) {
                        throw $e; // Tresor-ID konnte nicht ermittelt werden
                    }
                }
            }

            // Vorab prüfen, ob die UUID bereits existiert
            $stmt = $pdo->prepare('SELECT uuid FROM users WHERE uuid = ?');
            $stmt->execute([$userUuid]);
            if ($stmt->fetch()) {
                return Response::error(409); // Benutzer existiert bereits in diesem Tresor
            }

            // Vorab prüfen, ob der Benutzername im Vault bereits existiert
            $stmt = $pdo->prepare('SELECT uuid FROM users WHERE vault_uuid = ? AND hash_name = ?');
            $stmt->execute([$vaultUuid, $userHash]);
            if ($stmt->fetch()) {
                return Response::error(409); // Benutzer existiert bereits in diesem Tresor
            }

            // Benutzer anlegen
            $stmt = $pdo->prepare('INSERT INTO users (uuid, vault_uuid, hash_name, salt, public_key, encrypted_private_key, master_key_timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)');
            $stmt->execute([$userUuid, $vaultUuid, $userHash, $salt, $publicKey, $encryptedPrivateKey, $masterKeyTimestamp]);

            // Antwort generieren
            return Response::json([
                'user_uuid' => $userUuid,
                'vault_uuid' => $vaultUuid,
                'user_hash' => $userHash,
                'salt' => $salt,
                'public_key' => $publicKey,
                'encrypted_private_key' => $encryptedPrivateKey,
                'master_key_timestamp' => $masterKeyTimestamp,
                'encrypted_friends' => null
            ], 201);
        }
        catch (PDOException $e) {
            if ($e->getCode() === '23000') {  // "Can't write; duplicate key in table" (s. https://dev.mysql.com/doc/mysql-errors/8.0/en/server-error-reference.html)
                // Falls es zwischenzeitlich einen Race gab und der User jetzt existiert, liefere 409 zurück
                return Response::error(409);
            }
            throw $e;
        }
    }

    /**
     * Aktualisiert Salt und RSA-Key eines Benutzers nach Passwortwechsel.
     *
     * Endpunkt: <code>PUT /users/{user_uuid}/password</code>
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
     *   "salt": "{salt}",
     *   "public_key": "{public_key}",
     *   "encrypted_private_key": "{encrypted_private_key}",
     *   "master_key_timestamp": "{master_key_timestamp}",
     * }
     * </code>
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
     * - 401 Unauthorized: API-Token fehlt/ungültig oder RSA-Header/Signatur fehlt/ungültig
     * - 403 Forbidden: user_uuid im Body stimmt nicht mit der RSA-identifizierten UUID überein
     * - 422 Unprocessable Entity: Pflichtfeld fehlt
     * - 500 Internal Server Error
     *
     * @param Request $request
     * @return Response
     */
    public function changePassword(Request $request): Response
    {
        // Parameter holen
        $request->ensureHas(['user_uuid', 'salt', 'public_key', 'encrypted_private_key', 'master_key_timestamp']);
        $userUuid = $request->string('user_uuid');
        $salt = $request->string('salt');
        $publicKey = $request->string('public_key');
        $encryptedPrivateKey = $request->string('encrypted_private_key');
        $masterKeyTimestamp = Time::iso8601ToMysql($request->date('master_key_timestamp'));

        // Der zu ändernde Benutzer muss der authentifizierte Benutzer sein.
        if ($userUuid !== $request->authUserUuid()) {
            return Response::error(403); // Nicht autorisiert
        }

        // Passwort ändern
        $pdo = Database::pdo();
        $stmt = $pdo->prepare('UPDATE users SET salt = ?, public_key = ?, encrypted_private_key = ?, master_key_timestamp = ? WHERE uuid = ?');
        $stmt->execute([$salt, $publicKey, $encryptedPrivateKey, $masterKeyTimestamp, $userUuid]);

        // Antwort generieren (204 No Content)
        return Response::empty();
    }

    /**
     * Speichert die verschlüsselte Freundesliste des Benutzers.
     *
     * Endpunkt: <code>PUT /users/{user_uuid}/friends</code>
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
     * { "encrypted_friends": "<encrypted_friends>" }
     * </code>
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
     * - 403 Forbidden: user_uuid in der Route stimmt nicht mit der RSA-identifizierten UUID überein
     * - 404 Not Found: Benutzer nicht gefunden
     * - 422 Unprocessable Entity: Pflichtfeld fehlt
     * - 500 Internal Server Error
     *
     * @param Request $request
     * @return Response
     */
    public function saveFriends(Request $request): Response
    {
        // Parameter holen
        $request->ensureHas(['user_uuid', 'encrypted_friends']);
        $userUuid = $request->string('user_uuid');
        $encryptedFriends = $request->string('encrypted_friends');

        // Sicherstellen, dass der angegebene Benutzer der authentifizierte Benutzer ist.
        if ($userUuid !== $request->authUserUuid()) {
            return Response::error(403); // Nicht autorisiert
        }

        // Prüfen, ob der User existiert
        $pdo = Database::pdo();
        $check = $pdo->prepare('SELECT uuid FROM users WHERE uuid = ?');
        $check->execute([$userUuid]);
        if (!$check->fetch()) {
            return Response::error(404, 'Benutzer nicht gefunden');
        }

        // Freundesliste speichern
        $stmt = $pdo->prepare('UPDATE users SET encrypted_friends = ? WHERE uuid = ?');
        $stmt->execute([$encryptedFriends, $userUuid]);

        // Antwort generieren (204 No Content)
        return Response::empty();
    }

    /**
     * Liefert die öffentlichen RSA-Schlüssel aller Benutzer im Tresor.
     *
     * Endpunkt: <code>GET /users/{user_uuid}/public_keys</code>
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
     * [
     *   {
     *     "user_uuid": "{user_uuid}",
     *     "public_key": "{public_key}"
     *   }
     * ]
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
     * - 403 Forbidden: user_uuid in der Route stimmt nicht mit der RSA-identifizierten UUID überein
     * - 404 Not Found: Benutzer nicht gefunden
     * - 422 Unprocessable Entity: Pflichtfeld fehlt
     * - 500 Internal Server Error
     *
     * @param Request $request
     * @return Response
     */
    public function getPublicKeys(Request $request): Response
    {
        // Parameter holen
        $request->ensureHas(['user_uuid']);
        $userUuid = $request->string('user_uuid');

        // Sicherstellen, dass der angegebene Benutzer der authentifizierte Benutzer ist.
        if ($userUuid !== $request->authUserUuid()) {
            return Response::error(403); // Nicht autorisiert
        }

        // Tresor des Benutzers ermitteln
        $pdo = Database::pdo();
        $stmt = $pdo->prepare('SELECT vault_uuid FROM users WHERE uuid = ?');
        $stmt->execute([$userUuid]);
        $vaultUuid = $stmt->fetchColumn();
        if (!$vaultUuid) {
            return Response::error(404, 'Benutzer nicht gefunden');
        }

         // Die öffentlichen RSA-Schlüssel aller Benutzer in diesem Tresor holen
        $stmt = $pdo->prepare('SELECT uuid AS user_uuid, public_key FROM users WHERE vault_uuid = ?');
        $stmt->execute([$vaultUuid]);
        //$users = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $publicKeys = $stmt->fetchAll();
    
        // Antwort generieren
        return Response::json($publicKeys);
    }

    /**
     * Ändert den Benutzernamen (Hash-Name) eines Benutzers.
     *
     * Endpunkt: <code>PATCH /users/{user_uuid}/name</code>
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
     * { "user_hash": "{user_hash}" }
     * </code>
     *
     * Antwort (204 No Content): -
     *
     * Antwort (401, 403, 404, 409, 422, 500):
     * <code>
     * { "error": "{Fehlermeldung}" }
     * </code>
     *
     * Mögliche Statuscodes:
     * - 204 No Content
     * - 401 Unauthorized: API-Token fehlt/ungültig oder RSA-Header/Signatur fehlt/ungültig
     * - 403 Forbidden: user_uuid in der Route stimmt nicht mit der RSA-identifizierten UUID überein
     * - 404 Not Found: Benutzer nicht gefunden
     * - 409 Conflict: Neuer Benutzername ist im Tresor bereits vergeben
     * - 422 Unprocessable Entity: Pflichtfeld fehlt
     * - 500 Internal Server Error
     *
     * @param Request $request
     * @return Response
     */
    public function patchUserName(Request $request): Response
    {
        // Parameter holen
        $request->ensureHas(['user_uuid', 'user_hash']);
        $userUuid = $request->string('user_uuid');
        $userHash = $request->string('user_hash');

        // Sicherstellen, dass der angegebene Benutzer der authentifizierte Benutzer ist.
        if ($userUuid !== $request->authUserUuid()) {
            return Response::error(403);
        }

        $pdo = Database::pdo();

        // Tresor des Benutzers ermitteln
        $stmt = $pdo->prepare('SELECT vault_uuid FROM users WHERE uuid = ?');
        $stmt->execute([$userUuid]);
        $vaultUuid = $stmt->fetchColumn();
        if (!$vaultUuid) {
            return Response::error(404, 'Benutzer nicht gefunden');
        }

        // Prüfen, ob der neue Name im Tresor bereits vergeben ist (anderer Benutzer)
        $stmt = $pdo->prepare('SELECT uuid FROM users WHERE vault_uuid = ? AND hash_name = ? AND uuid != ?');
        $stmt->execute([$vaultUuid, $userHash, $userUuid]);
        if ($stmt->fetch()) {
            return Response::error(409, 'Benutzername ist im Tresor bereits vergeben');
        }

        // Name aktualisieren
        $stmt = $pdo->prepare('UPDATE users SET hash_name = ? WHERE uuid = ?');
        $stmt->execute([$userHash, $userUuid]);

        // Antwort generieren (204 No Content)
        return Response::empty();
    }
}