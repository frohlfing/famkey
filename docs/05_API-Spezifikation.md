# 05 API-Spezifikation

## 1. API-Token

Der Zugriff wird durch einen globalen API-Token gesichert.

```http
Authorization: Bearer {api_token}
```
Kompatibilität ist zusätzlich gegeben über:
- Header `X-API-Token: {api_token}`
- Query-Parameter `?api_token={api_token}`
- Basic Auth (Passwort = API-Token)

Fehlt der Token oder ist er falsch, antwortet der Server mit `401 Unauthorized`.

* Beispiel mit Curl:
    ```shell
    curl /version
      -H "Authorization: Bearer {api_token}"
    ```

## 2. RSA-Signatur (Identity Proof)

Die Identität des Benutzers wird durch eine kryptografische RSA-Signatur pro Request bewiesen.

Für geschützte Endpunkte sind folgende Header zwingend erforderlich:
- `X-User-Uuid`: Die UUID des anfragenden Benutzers.
- `X-Timestamp`: Aktuelle Unix-Zeit (UTC). Maximal 5 Minuten Abweichung zulässig.
- `X-Signature`: RSA-Signatur (Base64) über den String `{user_uuid}:{timestamp}` (Padding: PKCS#1 v1.5).

## 3. Rate-Limit

Die Anzahl der Anfragen ist aus Sicherheitsgründen pro Zeitraum limitiert.
Nur eine bestimmte Anzahl von Anforderungen pro Zeitfenster ist zulässig.

Im Antwortheader wird das Rate-Limit angegeben, z.B.:

```
X-RateLimit-Limit: 60      # Schwelle
X-RateLimit-Remaining: 8   # Restkontingent
X-RateLimit-Reset: 12      # Sekunden bis Reset
```

Dies bedeutet:
- Max. 60 Requests pro Zeitfenster sind möglich.
- Es sind noch 8 Requests im aktuellen Zeitfenster übrig.
- In 12 Sekunden wird das Kontingent wieder zurückgesetzt.

Im Debug-Modus kann per Request-Header das Rate-Limit überschrieben werden (für Unit-Tests hilfreich).
X-RateLimit-Limit = 0 bedeutet kein Limit.

Das Zeitfenster beträgt 1 Minute.

## 4. Zeitangaben

Zeitangaben verwenden die UTC-Zeit mit einer Präzision von 3 Nachkommastellen.
Sie werden als ISO 8601 Zeichenketten formatiert dargestellt (mit 3 oder 6 Ziffern nach dem Sekunden-Teil).

Beispiel: `2026-01-14T17:13:41.542Z`
oder:`2026-01-14T17:13:41.542000Z`

## 5. Statuscodes

- 200 - OK: Die Abfrage der Ressource war erfolgreich.
- 201 - Created: Die Ressource wurde erfolgreich erstellt.
- 204 - No Content: Die Antwort beinhaltet keine Daten (z.B. bei der Löschung einer Resource).
- 400 - Bad Request: Die Anfrage ist fehlerhaft aufgebaut (Syntaxfehler in JSON).  
- 401 - Unauthorized: Fehlender/ungültiger API-Token oder RSA-Signierung
- 403 - Forbidden: Fehlende Berechtigung
- 404 - Not Found: Die Angefragte Resource wurde nicht gefunden.
- 405 - Method Not Allowed: Die angegebene HTTP-Methode ist für die Resource nicht erlaubt.
- 409 - Conflict: Eine neue Resource soll angelegt werden, existiert aber bereits.
- 413 - Payload Too Large: Payload ist zu groß (z. B. Attachment-Upload).
- 422 - Unprocessable Entity: Pflichtfelder fehlen/ungültig.
- 429 - Too Many Requests: Wenn das Rate-Limit (z. B. >200 Einträge/h) überschritten wurde.
- 500 - Internal Server Error: Unerwarteter Serverfehler.

## 6. Bulk-Aktionen

Ein Bulk-Endpunkt verarbeitet in einem Request mehrere Ressourcen einer Collection.

* Sync:
  `sync` ist eine Bulk-Aktion auf der Collection `entries` des Benutzers.
  - `GET /users/{user_uuid}/entries/sync` liefert alle seit `since` geänderten Entries sowie Löschungen.
  - `POST /users/{user_uuid}/entreis/sync` wendet ein Batch von Änderungen und Löschungen auf dem Server an (Last-Write-Wins).

## 7. Endpunkte

| Resource   | HTTP-Verb  | Endpunkt                        | RSA-Schutz | Parameter                                                                                                                                                                                                                                                 | Antwort bei Erfolg                                                                                                                                                                                                                                                           | Beschreibung                                                                  |
|------------|------------|---------------------------------|------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------| 
| version    | GET        | /version                        | nein       |                                                                                                                                                                                                                                                           | (200) { service: "priVault", major, minor, patch }                                                                                                                                                                                                                           | Liefert die API-Version und die minimal erforderliche Client-Minor-Version.   |
| user       | GET        | /users/{user_uuid}              | nein       |                                                                                                                                                                                                                                                           | (200) { user_uuid, vault_uuid, user_hash, salt, public_key, encrypted_private_key, encrypted_friends? }                                                                                                                                                                      | Liefert die Benutzerdaten anhand seiner UUID.                                 |
|            | GET        | /users                          | nein       | QUERY: vault_hash, user_hash                                                                                                                                                                                                                              | (200) { user_uuid, vault_uuid, user_hash, salt, public_key, encrypted_private_key, encrypted_friends? } oder null                                                                                                                                                            | Sucht einen Benutzer in einem bestimmten Tresor anhand seines Namens-Hashes.  |
|            | POST       | /users                          | nein       | BODY: { user_uuid, vault_hash, user_hash, salt, public_key, encrypted_private_key }                                                                                                                                                                       | (201) { user_uuid, vault_uuid, user_hash, salt, public_key, encrypted_private_key, encrypted_friends? }                                                                                                                                                                      | Registriert einen neuen Benutzer im Tresor (legt den Tresor ggf. an).         |
|            | PUT        | /users/{user_uuid}/password     | ja         | BODY: { salt, encrypted_private_key }                                                                                                                                                                                                                     | (204) -                                                                                                                                                                                                                                                                      | Aktualisiert Salt und Private Key nach Änderung des Master-Passworts.         |
|            | PUT        | /users/{user_uuid}/friends      | ja         | BODY: { encrypted_friends }                                                                                                                                                                                                                               | (204) -                                                                                                                                                                                                                                                                      | Speichert die verschlüsselte Freundesliste des Benutzers.                     |
|            | GET        | /users/{user_uuid}/public_keys  | ja         |                                                                                                                                                                                                                                                           | (200) [{ user_uuid, public_key }, ... }]                                                                                                                                                                                                                                     | Liefert die öffentlichen RSA-Schlüssel aller Benutzer im Tresor.              |
| entry      | GET        | /users/{user_uuid}/entries/sync | ja         | QUERY: since (optional)                                                                                                                                                                                                                                   | (200) { updates: [{ entry_uuid, encrypted_data, encrypted_key, access_level, attachment_uuids, friends: [{ user_uuid, encrypted_key, access_level }, ...], creator_uuid, updater_uuid, updated_at }, ...],<br/>deletes: [{ entry_uuid, deleted_at }, ...],<br/>server_time } | Bulk-Aktion: Liefert alle Änderungen seit der letzten Synchronisation (Pull). |
|            | POST       | /users/{user_uuid}/entries/sync | ja         | BODY: { updates: [{ entry_uuid, encrypted_data, encrypted_key, access_level, attachment_uuids, friends: [{user_uuid, encrypted_key, access_level}, ...], creator_uuid, updater_uuid, updated_at }, ...],<br/>deletes: [{ entry_uuid, deleted_at }, ...] } | (204) -                                                                                                                                                                                                                                                                      | Bulk-Aktion: Synchronisiert clientseitige Änderungen (Push).                  |
| attachment | GET        | /attachments/{attachment_uuid}  | ja         |                                                                                                                                                                                                                                                           | (200) { attachment_uuid, entry_uuid, encrypted_meta, encrypted_content }                                                                                                                                                                                                     | Lädt die verschlüsselten Metadaten und den Inhalt eines Anhangs.              |
|            | PUT        | /attachments/{attachment_uuid}  | ja         | BODY: { entry_uuid, encrypted_meta, encrypted_content }                                                                                                                                                                                                   | (204) -                                                                                                                                                                                                                                                                      | Speichert einen neuen Anhang (Metadaten & Inhalt) auf dem Server.             |
| vault      | DELETE     | /vaults                         | nein       | QUERY: vault_hash                                                                                                                                                                                                                                         | (204) -                                                                                                                                                                                                                                                                      | Löscht einen Test-Tresor und bereinigt veraltete Test-Tresore.                |

# 8. Tests

Mit `X-Test` im Request-Header schaltet der Server in den Test-Betrieb.  
Die Daten können dann durch DELETE /test wieder gelöscht werden.

Mit `X-Coverage` im Header wird der Request für einen Code-Coverage-Report protokolliert.
