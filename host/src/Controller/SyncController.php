<?php
/** @noinspection DuplicatedCode */

declare(strict_types=1);

namespace App\Controller;

use App\Core\Database;
use App\Core\Request;
use App\Core\Response;
use App\Core\Time;
use Throwable;

/**
 * Controller für die Synchronisation der Einträge.
 */
final class SyncController
{
    /**
     * Liefert alle Änderungen seit der letzten Synchronisation (Pull).
     *
     * Endpunkt: <code>GET /users/{user_uuid}/entries/sync</code>
     *
     * Header:
     * <code>
     * Authorization: Bearer {api_token}
     * X-User-Uuid: {user_uuid}
     * X-Timestamp: {unix_timestamp_utc}
     * X-Signature: {base64_signature}
     * </code>
     *
     * Query:
     * <code>
     * since={utc_timestamp} // optional
     * </code>
     *
     * Body: -
     *
     * Antwort (200 OK):
     * <code>
     * {
     *   "updates": [
     *     {
     *       "entry_uuid": "{entry_uuid}",
     *       "encrypted_data": "<encrypted_data>",
     *       "encrypted_key": "<encrypted_key>",
     *       "access_level": 3,
     *       "attachment_uuids": ["{attachment_uuid}"],
     *       "friends": [ { "user_uuid": "{user_uuid}", "encrypted_key": "{encrypted_key}", "access_level": "{access_level}" } ],
     *       "creator_uuid": "{user_uuid}",
     *       "updater_uuid": "{user_uuid}",
     *       "updated_at": "{utc_timestamp}"
     *     }
     *   ],
     *   "deletes": [
     *     {
     *       "entry_uuid": "{entry_uuid}",
     *       "deleted_at": "{utc_timestamp}"
     *     }
     *   ],
     *   "server_time": "{utc_timestamp}"
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
     * - 403 Forbidden: user_uuid in der Query stimmt nicht mit der RSA-identifizierten UUID überein
     * - 404 Not Found: Benutzer nicht gefunden
     * - 422 Unprocessable Entity: Pflichtfeld user_uuid fehlt/ist leer oder since ist ungültig formatiert
     * - 500 Internal Server Error
     *
     * Zeitformat:
     * - UTC ISO 8601 (z.B. 2026-01-14T17:13:41.542Z)
     *
     * @param Request $request
     * @return Response
     */
    public function pullSync(Request $request): Response
    {
        $request->ensureHas(['user_uuid']);
        $userUuid = $request->string('user_uuid');

        // Der zu ändernde Benutzer muss der authentifizierte Benutzer sein.
        if ($userUuid !== $request->authUserUuid()) {
            return Response::error(403);
        }

        // Optionalen Zeitfilter holen
        $since = Time::iso8601ToMysql($request->date('since'));

        // Aktuelle Zeit festhalten
        $now = Time::getUTC();

        // Tresor des Benutzers ermitteln
        $pdo = Database::pdo();
        $stmt = $pdo->prepare('SELECT vault_uuid FROM users WHERE uuid = ?');
        $stmt->execute([$userUuid]);
        $vaultUuid = $stmt->fetchColumn();
        if (!$vaultUuid) {
            return Response::error(404, 'Benutzer nicht gefunden');
        }

        // -- Updates --

        $updates = [];

        // Alle geänderten Einträge aus der Datenbank laden.
        $stmt = $pdo->prepare("
            SELECT e.uuid, e.encrypted_data, p.encrypted_key, p.access_level, e.creator_uuid, e.updater_uuid,
                   DATE_FORMAT(e.updated_at, '%Y-%m-%dT%H:%i:%s.%fZ') AS updated_at 
            FROM entries e
            JOIN permissions p ON e.uuid = p.entry_uuid
            WHERE e.vault_uuid = ? AND p.user_uuid = ? AND e.updated_at > ?
            ORDER BY e.updated_at, e.uuid
            ");
        $stmt->execute([$vaultUuid, $userUuid, $since]);

        // Die geänderten Einträge durchlaufen.
        foreach ($stmt->fetchAll() as $row) {
            // Freunde laden, die Zugriff auf den Eintrag haben
            $stmtPerm = $pdo->prepare("
                SELECT user_uuid, encrypted_key, access_level
                FROM permissions 
                WHERE entry_uuid = ? AND user_uuid != ?
                ");
            $stmtPerm->execute([$row['uuid'], $userUuid]);
            $friends = $stmtPerm->fetchAll();

            // Eintrag für die Antwort merken
            $updates[] = [
                'entry_uuid' => $row['uuid'],
                'encrypted_data' => $row['encrypted_data'],
                'encrypted_key' => $row['encrypted_key'],
                'access_level' => (int)$row['access_level'],
                'friends' => $friends,
                'creator_uuid' => $row['creator_uuid'],
                'updater_uuid' => $row['updater_uuid'],
                'updated_at' => $row['updated_at'],
            ];
        }

        // -- Deletes --

        // Alle gelöschten Einträge aus der Datenbank laden und für die Antwort merken.
        $stmt = $pdo->prepare("
            SELECT entry_uuid, DATE_FORMAT(deleted_at, '%Y-%m-%dT%H:%i:%s.%fZ') AS deleted_at  
            FROM tombstones 
            WHERE vault_uuid = ? AND deleted_at > ?
            ");
        $stmt->execute([$vaultUuid, $since]);
        $deletes = $stmt->fetchAll();

        // Antwort generieren
        return Response::json([
            'updates' => $updates,
            'deletes' => $deletes,
            'server_time' => $now,
        ]);
    }

    /**
     * Synchronisiert clientseitige Änderungen (Push).
     *
     * Endpunkt: <code>POST /users/{user_uuid}/entries/sync</code>
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
     *   "updates": [
     *     {
     *       "entry_uuid": "{entry_uuid}",
     *       "encrypted_data": "{encrypted_data}",
     *       "encrypted_key": "{encrypted_key}",
     *       "access_level": 3,
     *       "attachment_uuids": ["{attachment_uuid}"],
     *       "friends": [ { "user_uuid": "{user_uuid}", "encrypted_key": "<encrypted_key>", "access_level": "{access_level}" } ],
     *       "creator_uuid": "{user_uuid}",
     *       "updater_uuid": "{user_uuid}",
     *       "updated_at": "{utc_timestamp}"
     *     }
     *   ],
     *   "deletes": [
     *     {
     *       "entry_uuid": "{entry_uuid}",
     *       "deleted_at": "{utc_timestamp}"
     *     }
     *   ]
     * }
     * </code>
     *
     * Antwort (204 No Content): -
     *
     * Antwort (401, 403, 404, 422, 429, 500):
     * <code>
     * { "error": "{Fehlermeldung}" }
     * </code>
     *
     * Mögliche Statuscodes:
     * - 204 No Content
     * - 401 Unauthorized: API-Token fehlt/ungültig oder RSA-Header/Signatur fehlt/ungültig
     * - 403 Forbidden: keine Berechtigung (z.B. kein Schreibrecht / kein Löschrecht / falsche user_uuid)
     * - 404 Not Found: Tresor konnte für die user_uuid nicht ermittelt werden
     * - 422 Unprocessable Entity: Payload fehlt/hat falsche Typen oder enthält ungültige Felder (z.B. updated_at/deleted_at ungültig)
     * - 429 Too Many Requests: Rate-Limit überschritten
     * - 500 Internal Server Error
     *
     * Zeitformat:
     * - UTC ISO 8601 (z.B. 2026-01-14T17:13:41.542Z)
     *
     * @param Request $request
     * @return Response
     * @throws Throwable
     */
    public function pushSync(Request $request): Response
    {
        // Parameter holen
        $request->ensureHas(['user_uuid', 'updates', 'deletes']);
        $userUuid = $request->string('user_uuid');
        $updates = $request->array('updates');
        $deletes = $request->array('deletes');

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
            return Response::error(404, 'Tresor konnte für die angegebene user_uuid nicht ermittelt werden');
        }

        $pdo->beginTransaction();
        try {

            // -- Updates --

            foreach ($updates as $entry) {
                if (empty($entry['entry_uuid']) ||
                    empty($entry['encrypted_data']) ||
                    empty($entry['encrypted_key']) ||
                    !isset($entry['access_level']) ||
                    !isset($entry['attachment_uuids']) ||
                    !isset($entry['friends']) ||
                    !isset($entry['creator_uuid']) ||
                    !isset($entry['updater_uuid']) ||
                    empty($entry['updated_at'])
                ) {
                    $pdo->rollBack();
                    return Response::error(422, 'Erforderlicher Parameter in "updates" fehlt');
                }

                $entryUuid = $entry['entry_uuid'];
                $encryptedData = $entry['encrypted_data'];
                $encryptedKey = $entry['encrypted_key'];
                $friends = $entry['friends'];
                if (!is_array($friends)) {
                    $pdo->rollBack();
                    return Response::error(422, '"friends" muss ein Array sein');
                }

                $updatedAt = Time::iso8601ToMysql((string)$entry['updated_at']);
                if (!$updatedAt) {
                    $pdo->rollBack();
                    return Response::error(422, '"updated_at" muss ein gültiger ISO-Zeitstempel sein');
                }

                // Eintrag suchen und aktualisieren
                $wasChanged = false;
                $stmt = $pdo->prepare('SELECT updated_at FROM entries WHERE uuid = ?');
                $stmt->execute([$entryUuid]);
                $currUpdatedAt = $stmt->fetchColumn();
                if ($currUpdatedAt) {
                    // Eintrag gefunden → UPDATE: Der Bearbeiter muss Schreibrecht haben.
                    $stmt = $pdo->prepare('SELECT access_level FROM permissions WHERE entry_uuid = ? AND user_uuid = ?');
                    $stmt->execute([$entryUuid, $userUuid]);
                    $accessLevel = (int)$stmt->fetchColumn();
                    if ($accessLevel < 2) {
                        $pdo->rollBack();
                        return Response::error(403, "Kein Schreibrecht für Eintrag $entryUuid");
                    }
                    // Update, wenn veraltet
                    if ($currUpdatedAt < $updatedAt) {
                        $stmt = $pdo->prepare('UPDATE entries SET encrypted_data = ?, updater_uuid = ?, updated_at = ? WHERE uuid = ?');
                        $stmt->execute([$encryptedData, $userUuid, $updatedAt, $entryUuid]);
                        $stmt = $pdo->prepare('UPDATE permissions SET encrypted_key = ?, access_level = ? WHERE entry_uuid = ? AND user_uuid = ?');
                        $stmt->execute([$encryptedKey, $accessLevel, $entryUuid, $userUuid]);
                        $wasChanged = true;
                    }
                } else {
                    // Eintrag nicht gefunden → INSERT
                    $accessLevel = 3; // Ersteller hat Vollzugriff
                    $stmt = $pdo->prepare('INSERT INTO entries (uuid, vault_uuid, encrypted_data, creator_uuid, updater_uuid, updated_at) VALUES (?, ?, ?, ?, ?, ?)');
                    $stmt->execute([$entryUuid, $vaultUuid, $encryptedData, $userUuid, $userUuid, $updatedAt]);
                    $stmt = $pdo->prepare('INSERT INTO permissions (entry_uuid, user_uuid, vault_uuid, encrypted_key, access_level) VALUES (?, ?, ?, ?, ?)');
                    $stmt->execute([$entryUuid, $userUuid, $vaultUuid, $encryptedKey, $accessLevel]);
                    $wasChanged = true;
                }

                if ($wasChanged) {
                    // Freunde aktualisieren
                    $existingUserUuids = [$userUuid];
                    foreach ($friends as $friend) {
                        if (empty($friend['user_uuid']) || empty($friend['encrypted_key']) || !isset($friend['access_level'])) {
                            $pdo->rollBack();
                            return Response::error(422, 'Daten für Freund unvollständig');
                        }

                        $friendUuid = $friend['user_uuid'];
                        $friendEncryptedKey = $friend['encrypted_key'];
                        $friendAccessLevel = $friend['access_level'];

                        if (!is_int($friendAccessLevel)) {
                            $pdo->rollBack();
                            return Response::error(422, 'access_level muss eine Ganzzahl (Integer) sein');
                        }

                        // Prüfen, ob der User überhaupt existiert
                        $stmtCheckUser = $pdo->prepare('SELECT uuid FROM users WHERE uuid = ?');
                        $stmtCheckUser->execute([$friendUuid]);
                        if (!$stmtCheckUser->fetch()) {
                            continue;
                        }

                        $existingUserUuids[] = $friendUuid;

                        // Permission upsert
                        $stmt = $pdo->prepare('SELECT vault_uuid FROM permissions WHERE entry_uuid = ? AND user_uuid = ?');
                        $stmt->execute([$entryUuid, $friendUuid]);
                        if ($stmt->fetch()) {
                            $stmt = $pdo->prepare('UPDATE permissions SET encrypted_key = ?, access_level = ? WHERE entry_uuid = ? AND user_uuid = ?');
                            $stmt->execute([$friendEncryptedKey, $friendAccessLevel, $entryUuid, $friendUuid]);
                        } else {
                            $stmt = $pdo->prepare('INSERT INTO permissions (entry_uuid, user_uuid, vault_uuid, encrypted_key, access_level) VALUES (?, ?, ?, ?, ?)');
                            $stmt->execute([$entryUuid, $friendUuid, $vaultUuid, $friendEncryptedKey, $friendAccessLevel]);
                        }
                    }

                    // Freunde löschen, die nicht in friends enthalten sind
                    $placeholders = implode(',', array_fill(0, count($existingUserUuids), '?'));
                    $stmt = $pdo->prepare("DELETE FROM permissions WHERE entry_uuid = ? AND user_uuid NOT IN ($placeholders)");
                    $stmt->execute(array_merge([$entryUuid], $existingUserUuids));
                }
            }

            // -- Deletes --

            foreach ($deletes as $tomb) {
                if (empty($tomb['entry_uuid']) || empty($tomb['deleted_at'])) {
                    $pdo->rollBack();
                    return Response::error(422, 'Erforderlicher Parameter in "deletes" fehlt');
                }

                $entryUuid = $tomb['entry_uuid'];
                $deletedAt = Time::iso8601ToMysql((string)$tomb['deleted_at']);
                if (!$deletedAt) {
                    $pdo->rollBack();
                    return Response::error(422, '"deleted_at" muss ein gültiger ISO-Zeitstempel sein');
                }

                // Muss Vollzugriff (Level 3) haben zum Löschen
                $stmt = $pdo->prepare('SELECT access_level FROM permissions WHERE entry_uuid = ? AND user_uuid = ?');
                $stmt->execute([$entryUuid, $userUuid]);
                $accessLevel = (int)$stmt->fetchColumn();
                if ($accessLevel < 3) {
                    $pdo->rollBack();
                    return Response::error(403, "Kein Recht zum Löschen des Eintrags $entryUuid");
                }

                // Tombstone erstellen/aktualisieren
                $stmt = $pdo->prepare('SELECT deleted_at FROM tombstones WHERE entry_uuid = ?');
                $stmt->execute([$entryUuid]);
                $currDeletedAt = $stmt->fetchColumn();
                if ($currDeletedAt) {
                    if ($currDeletedAt < $deletedAt) {
                        $stmt = $pdo->prepare('UPDATE tombstones SET deleted_at = ? WHERE entry_uuid = ?');
                        $stmt->execute([$deletedAt, $entryUuid]);
                    }
                } else {
                    $stmt = $pdo->prepare('INSERT INTO tombstones (entry_uuid, vault_uuid, deleted_at) VALUES (?, ?, ?)');
                    $stmt->execute([$entryUuid, $vaultUuid, $deletedAt]);
                }

                // Entry löschen
                $stmt = $pdo->prepare('DELETE FROM entries WHERE uuid = ?');
                $stmt->execute([$entryUuid]);
            }

            // Änderungen committen
            $pdo->commit();

            // Antwort generieren (204 No Content)
            return Response::empty();

        } catch (Throwable $e) {
            $pdo->rollBack(); // todo kann man eine Transaction nicht generell über Application anlegen? Oder besser für jeden Controller einfügen?
            throw $e;
        }
    }
}