# 08 Styleguide

## 1 Namenskonventionen

### 1.1 Namenskonventionen in C#
In C# / .NET MAUI folgen wir den offiziellen Microsoft-Richtlinien (PascalCase vs. camelCase) mit der Ergänzung für private Felder (`_`).

| Element                    | Konvention                                  | Beispiel                                                      |
|:---------------------------|:--------------------------------------------|:--------------------------------------------------------------|
| **Klassen**                | PascalCase                                  | `CryptoService`, `LoginViewModel`, `UserEntity`               |
| **Dateinamen**             | PascalCase                                  | `CryptoService.cs` (Muss exakt wie Klasse heißen)             |
| **Methoden**               | PascalCase                                  | `GetPasswordAsync`, `CalculateHash`                           |
| **Interfaces**             | 'I' + PascalCase                            | `ICryptoService`, `IDatabaseConnection`                       |
| **Öffentliche Properties** | PascalCase                                  | `UserName`, `IsLoggedIn`                                      |
| **Parameter**              | camelCase                                   | `userName`, `inputData`                                       |
| **Lokale Variablen**       | camelCase                                   | `tempResult`, `entryIndex`                                    |
| **Private Felder**         | `_` + camelCase                             | `_dbConnection`, `_currentUser`                               |
| **Asynchrone Methoden**    | Suffix 'Async'                              | `LoadDataAsync()`, `SyncAsync()`                              |
| **Konstanten**             | PascalCase                                  | `MaxRetries`, `DefaultTimeout`                                |
| **Test-Klasse**            | ZielKlasse + 'Tests'                        | `DatabaseServiceTests`                                        |
| **Test-Methode**           | MethodName_StateUnderTest_ExpectedBehavior  | `SyncAsync_WhenUserIsNew_ShouldRegisterUserAndSaveUuid`       |

- Suffixe bzgl. DTOs und Payloads:
    - **Request:** Daten, die die App an den Server sendet.
    - **Response:** Daten, die die App vom Server empfängt.
    - **Dto:** Für Unter-Strukturen innerhalb von Requests/Responses.
    - **Payload:** Der Inhalt eines verschlüsselten Blobs. Ein Payload ist das, was nach der Entschlüsselung aus einem String wieder

### 1.2 Namenskonventionen in PHP
In PHP folgen wir den `PHP Standards Recommendations` ([PSR-1: Basic Coding Standard](https://www.php-fig.org/psr/psr-1/) und [PSR-12: Extended Coding Style](https://www.php-fig.org/psr/psr-12/)).

### 1.3 Namenskonventionen für das Datenbankschema
Wir verwenden sowohl für die SQLite-DB als auch für die MySQL-Datenbank dieselben Konventionen.

| Objekt                | Regel                             | Beispiel DB       | 
|:----------------------|:----------------------------------|:------------------|
| **Tabelle**           | snake_case, Plural                | `entries`         |
| **Spalte**            | snake_case                        | `created_at`      | 
| **Auto Increment ID** | `id`                              | `id`              | 
| **Foreign Key**       | Singular der Fremdtabelle + `_id` | `user_id`         |
| **Pivot-Tabelle**     | Alphabetisch sortiert, snake_case | `entries_users`   | 
| **Index**             | `idx_<tabelle>_<spalte(n)>`       | `idx_users_email` |
| **Unique Key**        | `uk_<tabelle>_<spalte(n)>`        | `idx_users_email` |

### 1.4 Namenskonventionen für die API
Die API kommuniziert ausschließlich im `snake_case` Format.

## 2. Code-Dokumentation
Es wird ausschließlich in Deutsch dokumentiert.

### 2.1 Kommentare in C#
In **C#** folgen wir dem offiziellen C# XML-Standard (**Format:** `///`).
Wir beschränken uns aber auf diese Tags: `<summary>`, `<remarks>`, `<param name="...">`, `<returns>`, `<exception cref="...">`, `<see cref="...">`. 

### 2.2 Beschreibung für eine Testmethode:
`<Gliederungspunkt>.<Methode>.<Testfall> <Methode>: <Erwartetes Verhalten>` 
Beispiel: `5.2.1 UploadAttachmentAsync: Lädt eine Datei erfolgreich hoch.`

### 2.3 Kommentare in PHP
- In **PHP** folgen wir den [PSR-5: PHPDoc](https://github.com/php-fig/fig-standards/blob/master/proposed/phpdoc.md).

## 3. Gliederung

### 3.1 Gliederungspunkte
In der C#-Welt halten wir folgende Reihenfolge innerhalb einer Klasse ein:
1. Konstanten / Statische Felder (`private const`, `static readonly`)
2. Backing Fields (`private readonly`, `private`)
3. Konstruktor(en)
4. Properties
   - Öffentliche Properties
   - Observable Properties (via CommunityToolkit)
   - Berechnete Properties (Get-only)
5. Befehle / Öffentliche Methoden 
6. Ereignishandler (für partial Methoden und UI-Events)
7. Private Methoden / Hilfsmethoden
   - Lifecycle-Methoden (z.B. `OnAppearing`)
   - Interne Logik

### 3.2 Marker einer Klasse
```csharp
// ------------------------------------------------------------------------
// --- Konstanten ---
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// --- Felder ---
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// --- Konstruktor ---
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// --- Eigenschaften ---
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// --- Befehle ---
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// --- Öffentliche Methoden ---
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// --- Ereignishandler ---
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// --- Private Methoden ---
// ------------------------------------------------------------------------
```

### 3.2 Marker einer Testdatei
```csharp
// ------------------------------------------------------------------------
// --- Setup ---
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// --- Tests ---
// ------------------------------------------------------------------------
```

## 4. Clean Code Regeln
- **Sprache:** Code ist **Englisch**. Kommentare sind **Deutsch**.
- **Eine Klasse pro Datei:** Jede C#-Datei enthält nur genau eine Klasse (oder Interface).
- **MVVM Pattern:** Logik im Code-Behind (`.xaml.cs`) vermeiden. Nutzung von ViewModels bevorzugen.
- **Dependency Injection:** Services werden über den Konstruktor in die ViewModels gereicht, nicht mit `new` erstellt.
- **Fehlerbehandlung:** Kritische kryptografische Fehler lösen Exceptions aus, die im UI via `DisplayAlert` oder `Toast` abgefangen werden.
