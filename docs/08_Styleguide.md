# 08 Styleguide

## 1 Namenskonventionen

### 1.1 Namenskonventionen in Flutter / Dart
In Flutter / Dart folgen wir den offiziellen Richtlinien von Google (Effective Dart). 
Ein wesentlicher Unterschied zu C# ist die Verwendung von `snake_case` für Dateinamen und der Verzicht auf das `I`-Präfix bei Interfaces (abstrakten Klassen).

| Element                                         | Konvention                     | Beispiel                                                      |
|:------------------------------------------------|:-------------------------------|:--------------------------------------------------------------|
| Klassen, Mixins und Interfaces (Abstract)       | PascalCase                     | `CryptoService`, `LoginViewModel`, `UserEntity`               |
| Dateinamen                                      | snake_case                     | `crypto_service.dart`, `login_view_model.dart`                |
| Variablen, Eigenschaften und Funktionsparameter | camelCase                      | `tempResult`, `entryIndex`                                    |
| Methoden                                        | camelCase (Verb vorangestellt) | `getPassword`, `calculateHash`                                |
| Private Variablen/Eigenschaften/Methoden        | `_` + camelCase                | `_dbConnection`, `_fetchInternalData()`                       |
| Konstanten                                      | camelCase                      | `maxRetries`, `defaultTimeout`                                |
| Test-Datei                                      | Zieldatei + `_test.dart`       | `database_service_test.dart`                                  |
| Test-Beschreibung                               | Klartext (String)              | `test('SyncAsync should register user when new', () => ...)`  |

- **Dateinamen:** Alle Dateien im Projekt werden konsequent in `snake_case.dart` benannt.
- **Private Elemente:** In Dart werden private Felder und Methoden durch einen führenden Unterstrich (`_`) gekennzeichnet. Dies regelt in Dart auch technisch die Sichtbarkeit (Library-private).

- Suffixe bzgl. DTOs und Payloads:
    - **Request:** Daten, die die App an den Server sendet.
    - **Response:** Daten, die die App vom Server empfängt.
    - **Dto:** Für Unter-Strukturen innerhalb von Requests/Responses.
    - **Payload:** Der Inhalt eines verschlüsselten Blobs. Ein Payload ist das, was nach der Entschlüsselung aus einem String wieder zu einem Objekt wird.

### 1.2 Namenskonventionen in PHP
In PHP folgen wir den `PHP Standards Recommendations` ([PSR-1: Basic Coding Standard](https://www.php-fig.org/psr/psr-1/) und [PSR-12: Extended Coding Style](https://www.php-fig.org/psr/psr-12/)).

### 1.3 Namenskonventionen für das Datenbankschema
Wir verwenden sowohl für die SQLite-DB als auch für die MySQL-Datenbank dieselben Konventionen.

| Objekt            | Regel                             | Beispiel DB       | 
|:------------------|:----------------------------------|:------------------|
| Tabelle**         | snake_case, Plural                | `entries`         |
| Spalte**          | snake_case                        | `created_at`      | 
| Auto Increment ID | `id`                              | `id`              | 
| Foreign Key       | Singular der Fremdtabelle + `_id` | `user_id`         |
| Pivot-Tabelle     | Alphabetisch sortiert, snake_case | `entries_users`   | 
| Index             | `idx_<tabelle>_<spalte(n)>`       | `idx_users_email` |
| Unique Key        | `uk_<tabelle>_<spalte(n)>`        | `idx_users_email` |

### 1.4 Namenskonventionen für die API
Die API kommuniziert ausschließlich im `snake_case` Format.

## 2. Code-Dokumentation
Es wird ausschließlich in **Deutsch** dokumentiert.

### 2.1 Kommentare in C#
In Dart folgen wir den offiziellen Konventionen, die vom Werkzeug `dart doc` verarbeitet werden. 
Das Format ist `///`. Es kann Markdown für die Formatierung verwendet werden.
- Der erste, einzelne Absatz dient als kurze Zusammenfassung.
- Längere Erklärungen folgen nach einer Leerzeile.
- Parameter & Verweise werden mit eckigen Klammern [parameterName] referenziert.

### 2.2 Beschreibung für eine Testmethode:
`<Gliederungspunkt>.<Methodenindex>.<Testfall> <Methode>: <Erwartetes Verhalten>` 
Beispiel: `5.2.1 UploadAttachmentAsync: Lädt eine Datei erfolgreich hoch.`

### 2.3 Kommentare in PHP
- In **PHP** folgen wir den [PSR-5: PHPDoc](https://github.com/php-fig/fig-standards/blob/master/proposed/phpdoc.md).


