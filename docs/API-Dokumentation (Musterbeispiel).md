# PriVault v1 API Dokumentation

* **Version:** 0.2.0
* **Datum:** 17.12.2025 
* **Autor:** Frank Rohlfing

Die vorliegende Schnittstelle ist eine REST-API. 

**Inhaltsverzeichnis**

## 1. API-Spezifikation

### 1.1 Definition

* **Resource**: Repräsentiert etwas, das über die API über eine ID adressierbar ist.
  Die Daten eines einzelnen Benutzers sind z.B. eine Resource.
* **Entity**, **Model**: Ist die konkrete Instanz einer Resource – also ein einzelnes Objekt mit seinen Daten.
  Frank ist z.B. eine Entität der Resource "User". Hat **Attrribute** (z.B. `id`, `name`).

### 1.2 API-Token

Jeder Request muss den API-Token mitliefern. Bevorzugt im Header per `Bearer`:
```shell
curl https://{host}/api/v1/users \
  -H "Authorization: Bearer {api_token}"
```

Kompatibilität (für Tests) ist zusätzlich gegeben über:

- Custom Header `X-API-Token` (verbreitet, aber nicht standardisiert):
  ```shell
  curl https://{host}/api/v1/users \
    -H "X-API-Token: {api_token}" 
  ```

- Basic Auth (Passwort = API-Token. klassisch für User/Passwort, aber nicht Best Practice für Tokens)
  ```shell
  curl https://{host}/controller/v1/users \
    -v -u :{api_token} 
  ```
  `curl` überträgt den -u-Parameter `username:password` Base64‑kodiert im Header `Authorization: Basic`:,
  ```shell
  curl https://{host}/controller/v1/users \
    -H "Authorization: Basic amRvZUBleGFtcGxlLmNvbTpwYSQkdzByZA=="
  ```
  
- Query-Parameter `?api_token={api_token}` (weniger sicher, da der Token in Logs zu sehen sein könnte):
  ```shell
  curl https://{host}/api/v1/users?api_token={api_token}
  ```
  
Fehlt der Token oder ist er falsch, antwortet der Server mit `401 Unauthorized`.

### 1.3 Rate-Limit

Die Anzahl der Anfragen ist aus Sicherheitsgründen pro Zeitraum limitiert. 
Nur eine bestimmte Anzahl von Anforderungen pro Minute ist zulässig.

Im Antwortheader werden das Rate-Limit und die Anzahl der in der aktuellen Minute verbleibenden Anforderungen angegeben:

```
x-ratelimit-limit: 60
x-ratelimit-remaining: 59
```

### 1.4 Format

**Request:**

Die Daten werden im JSON-Format übermittelt. Für jede Anforderung sollte daher im Header `Accept: application/json` 
angeben werden. 

Der `Content-Type` für `PATCH`- und `POST`-Anforderungen muss `application/json` sein.

Bei den Parametern wird zwischen Groß- und Kleinschreibung unterschieden.

**Response:**

Im Regelfall ist der `Content-Type` der Antwort `application/json`.

Im Fehlerfall wird der Fehlertext über ein JSON-Attribut `error` zurückgesendet.

Beispiel:

```
{
   "error": "No query results for entity [User]."
}
```

### 1.5 Statuscodes

Die API antwortet mit einem der folgenden HTTP-Statuscodes:

**200er-Bereich:**

Die Anfrage war erfolgreich.

-   200 - OK: Die Abfrage der Ressource war erfolgreich.
-   201 - Created: Die Ressource wurde erfolgreich erstellt.
-   204 - No Content: Die Antwort beinhaltet keine Daten (z.B. bei der Löschung einer Resource).
-   206 - Partial Content: Die Antwort beinhaltet nur einen Teil der angefragten Liste.

**400er-Bereich:**

Die Anfrage war nicht erfolgreich.

-   400 - Bad Request: Die Anfrage ist fehlerhaft aufgebaut (Syntaxfehler).
-   401 - Unauthorized: Unbefugter Zugriffsversuch. API-Token/RSA-Signatur fehlt bzw. ist ungültig.
-   403 - Forbidden: Der Benutzer ist authentifiziert, verfügt jedoch nicht über die erforderliche Berechtigung.
-   404 - Not Found: Entweder stimmt die URL zum Webservice nicht (in diesem Fall ist der Content-Type unbestimmt), der Endpunkt existiert nicht (in diesem Fall ist das Message-Attribut leer) oder die betroffene Ressource wurde nicht gefunden.
-   405 - Method Not Allowed: Die angegebene HTTP-Methode ist für den Endpunkt nicht erlaubt.
-   409 - Conflict: Anfrage kann nicht ausgeführt werden, weil sie mit dem aktuellen Zustand der Ressource kollidiert (z.B. ist gesperrt). Oder eine neue Resource soll angelegt werden, existiert aber bereits.
-   422 - Unprocessable Entity: Die Daten sind für die Resource nicht valide (z.B. wenn ein Pflichtfeld fehlt) und sind somit nicht verarbeitbar.
-   429 - Too Many Requests: Das Rate Limit wurde überschritten.

**500er-Bereich:**

Ein Ausnahmefehler ist aufgetreten.

-   500 - Internal Server Error. Etwas Unerwartetes ist aufgetreten.
-   501 - Not Implmented: Die Funktion befindet sich noch in der Entwicklung und steht voraussichtlich mit einem zukünftigen Update zur Verfügung.
-   503 - Service Unavailable: Service nicht verfügbar. Evtl. ist der Server temporär überlastet. Möglicherweise wird auch eine geplante Wartung und somit eine Serviceunterbrechung durchgeführt.

### 1.6 Datentypen

Die API akzeptiert JSON-Werte und gibt diese zurück. 
Dies können Zeichenfolgen in Anführungszeichen, Zahlen, Objekten, Arrays, true, false oder null sein.

**ID / Identifikation einer Ressource:** 

Eine Ressource wird durch das `id`-Attribut als Ganzzahl identifiziert.

Der standardmäßige numerische Typ in JavaScript, Python und PHP reicht aus, um Ganzzahlen der ID darzustellen.

Wenn du eine statische Sprache verwenden, in der ganzzahlige Typen explizit deklariert werden, verwende einen 64-Bit-Ganzzahlentyp (signiert ist OK) für ID-Ganzzahlen. 
Verwende beispielsweise in Java oder C# den `long`-Typ statt `int`.

**Zeitangaben:**

Zeitangaben verwenden die UTC-Zeit und sind als ISO 8601 Zeichenketten formatiert. 
Beispiel: `2025-12-17T19:29:34+01:00`.

**Anmerkung:**  
MySQL Standard ist `YYYY-MM-DD HH:MM:SS`, immer UTC.
 
### 1.7 Listen

Listen lassen sich - falls nicht anders in der Dokumentation der jeweiligen Ressource beschrieben - durch Angaben von GET-Parametern filtern und sortieren.

**Suche:**

Für Listenendpunkte kannst du den Parameter `search` verwenden, um nur die Ressourcen aus der Gesamtmenge zu filtern, 
bei denen mindestens ein Attribut den angegebenen Suchbegriff beinhaltet (ganz oder teilweise).

Beispiel:

```
https://{host}/api/v1/users?search=foo \\
```

Es können auch mehrere Suchbegriffe mit einem Leerzeichen getrennt angegeben werden. 
Es werden dann nur die Ressourcen herausgesucht, die alle genannten Suchbegriffe beinhalten. 
Beachte, dass die Suchbegriffe URL-kodiert übertragen werden müssen, wodurch aus dem Leerzeichen ein Plus-Zeichen wird.

Beispiel:

```
https://{host}/api/v1/users?search=foo+bar \\
```

**Pagination:**

Du kannst die Anzahl der Einträge pro Seite mit Parameter `per_page` bestimmen. 
Die abzufragende Seite gibst du mit Parameters `page` an. Die Zählung der Seiten beginnt bei 1.

Beispiel:

```
https://{host}/api/v1/users?per_page=50&page=3 \\
```

Ein Listenendpunkt könnte limitiert sein. In dem Fall ist die maximale Anzahl Einträge pro Seite dokumentiert.
Wenn nicht alle der angefragten Einträge übermittelt wurden, wird der Statuscode 206 gesetzt (statt 200).


**Sortierung:**

Listen können durch den Parameter `sort_by` sortiert werden. 
Als Wert wird ein Attribut der abgefragten Ressource erwartet. 
Die Sortierrichtung kannst du mit `sort_order=desc` bzw. `sort_order=asc` angeben.

Beispiel:

```
https://{host}/api/v1/users?sort_by=phone&sort_order=desc \
```

**Antwort:**

Die Antwort von Listenendpunkten besteht aus folgenden Attributen:

-   `items`: Die Liste mit den angefragten Resourcen.
- Optional (falls Parameter `per_page` gegeben ist oder bei Statuscode 206):
   -   `current_page`: Die Nummer der aktuellen Seite.
   -   `last_page`: Die Nummer der letzten Seite.
   -   `per_page`: Die Anzahl der Listeneinträge pro Seite.
   -   `total`: Die Anzahl aller Listeneinträge.

Beispiel:

```
Status: 206 Partial Content
{
  "items": [
    /* list of resources */
  ],
  "current_page": 2,
  "last_page":    3,
  "per_page":     10,
  "total":        23
}
```

### 1.8 Endpunkte einer RESTful-Resource

**Leitlinien für den Endpunkt-Name:**

- Der Pfad setz sich zusammen aus:
   - Collection/Ressourcensammlung (Substantiv, keine Verben),
   - optional Ressourcen-ID/UUID
   - optional Subresource (z.B. /password oder changes)
 `/users`, `/users/{id}` statt `/register`, `/user/id={id}`.
- Filter in Query.
- HTTP-Methoden semantisch nutzen:
   - GET liest eine Ressource aus einer Collection.
   - POST legt eine neue Ressource in einer Collection an.
   - PATCH ersetzt einige (bis alle) Attribute einer bestimmten Resource in einer Collection
   - PUT überschreibt eine Resource vollständig (erstellt sie, wenn nicht vorhanden) in einer Collection
   - DELETE löscht eine bestimmte Resource aus einer Collection

Ausnahme Bulk-Aktion:
Eine Bulk-Aktion ist ein Endpunkt, der mehrere Ressourcen in einem 
Rutsch verarbeitet (liest, erstellt, ändert oder löscht).

Ich definiere:
`sync` ist eine Bulk-Aktion auf die Collection `entries`. 
Mit `GET \sync` liest man alle veränderten Einträge aus. 
Mit `POST \sync` schreibt man alle veränderten Einträge.

| Method      | URI (Beispiel)    | Name (Beispiel)   |
|-------------|-------------------|-------------------|
| GET, HEAD   | api/v1/users      | api.users.index   |
| POST        | api/v1/users      | api.users.store   |
| GET, HEAD   | api/v1/users/{id} | api.users.show    |
| PATCH, PUT  | api/v1/users/{id} | api.users.update  |
| DELETE      | api/v1/users/{id} | api.users.destroy |

**GET vs. HEAD:**

`GET` fordert die Daten einer Resource (impliziert auch den Header)
`HEAD` fordert lediglich den Header einer Resource. 

Wir verwenden nur `GET`

**PATCH vs. PUT:** 

* `PATCH` ersetzt partial, also nur die übermittelten Attribute.
* `PUT` überschreibt alle Attribute der Resource. Falls die Resource nicht existiert, wird sie erstellt.

**Method Override:**

HTML-Formulare unterstützen nativ nur die Methoden `GET` und `POST`.
Methoden wie `PUT`, `PATCH` oder `DELETE` sind im Standard‑Formular nicht direkt möglich.

Lösung: Innerhalb des Formulars gibst du ein verstecktes Feld an, das die gewünschte Methode enthält:

```html
<form action="/users/42" method="POST">
    <input type="hidden" name="_method" value="DELETE">
    <button type="submit">Löschen</button>
</form>
```

**Routen der HTML-Formulare:**

Diese Routen gehören nicht zur API. 
Es sind die Standardrouten, mit denen die HTML-Formulare für eine Resource aufgerufen werden können.

| Method     | URI             | Name         |
|------------|-----------------|--------------|
| GET, HEAD  | users/create    | users.create |
| GET, HEAD  | users/{id}/edit | users.edit   |
| GET, HEAD  | users/{id}/copy | users.copy   |

### 1.9 Optionale Request-Attribute

Alle Attribute sind verpflichtend, sofern nicht ausdrücklich als "optional" gekennzeichnet.

## 2. API-Referenz

### 2.1 User

Ein Benutzer hat folgende Attribute:

| Name        | Type     | Read-only | Mandatory | Comment                                                          |
|-------------|----------|-----------|-----------|------------------------------------------------------------------|
|  id         | integer  | yes       | yes       | Wird beim Erstellen automatisch zugewiesen.                      |
|  name       | string   | no        | yes       | Name des Benutzers.                                              |
|  age        | integer  | no        | no        | Alter in Jahren.                                                 |
|  status     | integer  | yes       | yes       | Status (0 = offen, 1 = gesperrt).                                |
|  created_at | datetime | yes       | yes       | Wann die Ressource angelegt wurde. Wird automatisch gesetzt.     |
|  updated_at | datetime | yes       | yes       | Wann die Ressource aktualisiert wurde. Wird automatisch gesetzt. |

* **Index:** `GET /api/v1/users` - Gibt eine Liste aller gespeicherten Benutzer zurück.

  Beispiel:
  
  ```shell
  curl https://{host}/controller/v1/users \
    -H "Authorization: Bearer {api_token}" 
  ```
  
  Antwort:
  
  Status: 200 OK
  
  ```json
  [
    {
      "id":         34,
      "name":       "Frank",
      "age":        null,
      "status":     0,
      "created_at": "2025-12-17T22:55:29+01:00",
      "updated_at": "2025-12-17T10:38:52+01:00"
    }
  ]
  ```

* **Show:** `GET /api/v1/users/{id}` - Gibt die Attribute eines bestimmten Benutzers zurück.

  Beispiel:

  ```shell
  curl https://{host}/controller/v1/users/{id} \
    -H "Authorization: Bearer {api_token}" 
  ```

  Antwort:
  
  Status: 200 OK
  
  ```json
  {
    "id":         34,
    "name":       "Frank",
    "age":        null,
    "status":     0,
    "created_at": "2025-12-17T22:55:29+01:00",
    "updated_at": "2025-12-17T10:38:52+01:00"
  }
  
  ```

* **Create:** `POST /api/v1/users` - Legt einen neuen Benutzer an.

  * Das einzige erforderliche Attribut ist `name`. Alle weiteren beschreibbaren Attribute sind optional.
  * Sollte ein Benutzer mit dem gleichen Namen bereits gespeichert sein, wird ein Fehler zurückgegeben.

  Beispiel:
  
  ```shell
  curl https://{host}/controller/v1/users \
    -H "Content-Type: application/json" 
    -X POST -d '{"name": "Frank"}' \
    -H "Authorization: Bearer {api_token}" 
  ```
  
  Antwort:
  
  Status: 201 Created
  
  ```json
  {
    "id":         34,
    "name":       "Frank",
    "age":        null,
    "status":     0,
    "created_at": "2025-12-17T22:55:29+01:00",
    "updated_at": "2025-12-17T10:38:52+01:00"
  }
  
  ```

* **Update:** `PATCH /api/v1/users/{id}` - Überschreibt ein oder mehrere Attribute eines bestimmten Benutzers.

  * Sollte der Benutzer gesperrt sein, können die Attribute nicht mehr geändert werden. 
  * In diesem Fall wird ein Fehler zurückgegeben.
  
  Beispiel:
  
  ```shell
  curl https://{host}/controller/v1/users/{id} \
    -H "Content-Type: application/json" 
    -X PATCH -d '{"age": 55}' \
    -H "Authorization: Bearer {api_token}"
  ```
  
  Antwort:
  
  Status: 200 OK
  
  ```json
  {
    "id":         34,
    "name":       "Frank",
    "age":        55,
    "status":     0,
    "created_at": "2025-12-17T22:55:29+01:00",
    "updated_at": "2025-12-17T10:38:52+01:00"
  }
  ```

* **Delete:** `DELETE /controller/v1/users/{id}` - Löscht einen bestimmten Benutzer.

  Beispiel
  
  ```shell
  curl https://{host}/controller/v1/users/{id} \
    -X DELETE \
    -H "Authorization: Bearer {api_token}"
  ```
  
  Antwort:
  
  Status: 204 No Content
  
  ```json
  ```