# FamKey – Sync-Server

Der Sync-Server ermöglicht es, Tresore zwischen mehreren Geräten und Benutzern zu synchronisieren.
Er läuft als schlanke PHP-Anwendung auf jedem Standard-Webhost.

- GitHub: https://github.com/frohlfing/FamKey
- Lizenz: GPL-3.0

---

## Voraussetzungen

- PHP 8.4 oder neuer
- MySQL 8.x oder MariaDB (Charset `utf8mb4`)
- HTTPS (z.B. Basic- bzw. Let's Encrypt-Zertifikate – bei den meisten Hostern mit einem Klick einrichtbar)

---

## Installation

### 1. Domain einrichten

Richte bei deinem Hoster eine Domain oder Subdomain ein und aktiviere SSL,
sodass die Domain unter HTTPS erreichbar ist.

### 2. MySQL-Datenbank anlegen

Lege über das Verwaltungs-Panel deines Hosters eine neue Datenbank an:
- Zeichensatz:  utf8mb4
- Kollation:  utf8mb4_unicode_ci

Merke dir Datenbankname, Benutzername und Passwort.

### 3. Dateien hochladen

Entpacke das Archiv `famkey_server.zip` und lade den Inhalt des Ordners `famkey/`
auf deinen Server hoch (z.B. per WinSCP oder einem anderen FTP/SFTP-Programm).

### 4. Start-Verzeichnis für den Web-Bowser festlegen

Lege über das Verwaltungs-Panel deines Hosters das Web-Root-Verzeichnis auf 
das Unterverzeichnis `public` fest.

### 4. Setup-Assistenten starten

Rufe im Browser `https://deine-domain.de/setup` auf.

Der Assistent prüft die Systemanforderungen, fragt Datenbankverbindung und
Server-Einstellungen ab, legt `config.php` automatisch an und richtet das
Datenbankschema ein.

> **Wichtig:** Am Ende des Setups wird der `setup/`-Ordner automatisch gelöscht.
> Falls nicht: Ordner manuell löschen – er darf nicht dauerhaft erreichbar sein.

### 5. App verbinden

Öffne die FamKey-App und trage unter **Einstellungen** die Server-URL ein.
Gib dort auch den API-Token an (siehe unten).

---

## Konfiguration

Die Konfiguration liegt in `config.php` im Server-Root (wird vom Setup-Assistenten angelegt).
Eine kommentierte Vorlage findest du in `config.example.php`.

```php
const DB_HOST = 'localhost';
const DB_NAME = 'famkey';
const DB_USER = 'root';
const DB_PASS = '';

const MULTI_TENANT = false;   // true = Multi-Tenant (famkey.de)
const API_TOKEN  = '...';     // nur Single-Tenant

const RATE_LIMIT = 200;       // max. API-Anfragen pro Minute (0 = kein Limit)
const MAX_ATTACHMENT_BYTES = 25 * 1024 * 1024;

const DEBUG = false;
const LOG_LEVEL = 'WARN';    // DEBUG | INFO | WARN | ERROR
const LOG_MAX_DAYS = 7;
```

---

## Betriebsmodi

### Single-Tenant (Standard, `MULTI_TENANT = false`)

Ein Server, eine Familie. Alle Geräte teilen sich einen gemeinsamen API-Token,
der direkt in `config.php` hinterlegt ist.

```php
const MULTI_TENANT = false;
const API_TOKEN    = 'mein-geheimer-token';
```

Die App trägt als Server-URL einfach die Domain ein, z.B. `https://meine-domain.de`.

### Multi-Tenant (`MULTI_TENANT = true`)

Ein Server, mehrere unabhängige Gruppen (Familien, Vereine, Arbeitsgruppen).
Jede Gruppe wird als **Organisation** verwaltet und erhält eine eigene
Server-Adresse und einen eigenen API-Token.

```php
const MULTI_TENANT = false;
```

URL-Schema: `https://meine-domain.de/org/{slug}/`

#### Organisation einrichten

1. Rufe `/dev/organizations.php` auf (passwortgeschützt, siehe [Dev-Bereich](#dev-bereich)).
2. Gib der neuen Organisation einen Namen – daraus wird der `slug` der Server-Adresse generiert.
3. Nach dem Anlegen zeigt die Seite **Server-Adresse** und **API-Token** an – beides an den Nutzer weitergeben.

Über dieselbe Seite können Organisationen gesperrt, entsperrt oder gelöscht werden
(Löschen entfernt per FK-Kaskade alle verknüpften Tresore und Benutzer).
Der API-Token einer Organisation kann jederzeit erneuert werden – danach müssen alle
konfigurierten Clients aktualisiert werden.

---

## API-Token

Der API-Token ist ein gemeinsamer geheimer Schlüssel zwischen Server und App.
Er schützt den Server vor unbefugtem Zugriff.

> Der API-Token ist **nicht benutzerbezogen** – er ist ein Vertrauensbeweis für den Server selbst. 
> Wer den Token kennt, kann Tresore anlegen und synchronisieren.
> Teile ihn nur mit Personen, die den Server nutzen dürfen.

---

## Dev-Bereich

Der Ordner `public/dev/` enthält Hilfswerkzeuge für Betrieb und Entwicklung
und ist per HTTP-Basisauthentifizierung geschützt.

Konfiguration: `public/dev/.htaccess` (Vorlage: `.htaccess.example`)
und `public/dev/.htpasswd` (mit `htpasswd` erzeugen).

| Seite                  | Beschreibung                                          |
|------------------------|-------------------------------------------------------|
| `index.php`            | Übersicht / Dashboard                                 |
| `organizations.php`    | Organisationen verwalten (nur Multi-Tenant)           |
| `reference.php`        | API-Referenz                                          |
| `coverage.php`         | Test-Coverage-Bericht                                 |
| `phpinfo.php`          | PHP-Konfiguration                                     |
| `version.php`          | Schema- und Protokollversion                          |

---

## Verzeichnisstruktur

```
host/
├── migrations/           # SQL-Migrationsskripte
├── public/               # Web-Root (Ziel der Domain/Subdomain)
│   ├── api/              # REST-API-Endpunkte
│   ├── dev/              # Verwaltungs- und Entwicklungswerkzeuge (passwortgeschützt)
│   ├── setup/            # Ersteinrichtungs-Assistent (nach Setup löschen!)
│   ├── .htaccess         # URL-Rewriting
│   ├── favicons.php      # Favicon-Proxy
│   └── index.html        # Startseite
├── src/                  # PHP-Bibliotheken und Klassen
│   ├── Controller/       # Controller-Klassen
│   ├── Core/             # Framework-Kern
│   └── Middleware/       # Request/Response-Middleware
├── config.php            # Lokale Konfiguration (nicht im Git)
├── config.example.php    # Vorlage für config.php
└── routes.php            # URL-Routing
```
