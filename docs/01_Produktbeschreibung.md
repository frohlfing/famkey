# 01 Produktbeschreibung

---

## 1. Vision & Zielgruppe / Motivation
PriVault ist ein Passwort-Manager, bei dem der Nutzer die volle Kontrolle über seine Daten behält. 

**Zielgruppe:**
- Sicherheitsbewusste Privatanwender und Familien.
- Kleine bis mittlere Teams, die Zugangsdaten sicher teilen müssen.
- Nutzer, die eine self-hosted Synchronisations-Infrastruktur bevorzugen.

---

## 2. Kern-Features im Überblick

### Features

* 🔐 **BSI-konforme Kryptografie:** AES-256-GCM, RSA-4096 (OAEP) und Argon2id Hashing.
* 💻 **Cross-Platform:** Native Apps für Windows, Android und iOS.
*  ⚡ **Offline-First:** Volle Funktionalität ohne Internetverbindung. Sync erfolgt bei Verfügbarkeit.
* 📱 **Multi-Device Sync:** Nahtlose Nutzung auf mehreren Geräten durch sicheren Schlüsselaustausch.
* ☁️ **Self-Hosted Sync-Server:** Einfaches PHP/MySQL Backend (läuft auf jedem Standard-Webspace).
* 🏷️ **Zero-Knowledge:** Der Server kennt keine Passwort und keine Keys der Tresore.
* 📚 **Multi-Tenant:** Mandantenfähig - Mehrere getrennte Tresore auf demselben Server.
* 🤝 **Secure Sharing:** Sicheres Teilen von Einträgen zwischen ausgewählten Personen mittels Hybrid-Verschlüsselung.
* 🪪 **Identitäts-Schutz:** Verifizierung der Freunde durch Fingerprint (Optional, sonst vertrauen wir auf TOFU - Trust on First Use).
* 👀 **Biometrie:** Login via Fingerabdruck/FaceID (Hardware-Backed Keystore).
* 📝 **Auto-Fill:** Integration in das Betriebssystem zum automatischen Ausfüllen von Login-Feldern.
* 📎 **Anhänge:** Verschlüsseltes Speichern von Dateien.
* 🖼️ **Favicon-Cache:** Automatisches Speichern der Favicons zur visuellen Unterscheidung der Einträge
* 🎲 **Passwort-Generator:** Sichere Generierung eines Passworts.
* 🚦 **Passwort-Meter:** Bewerten der Passwortstärke.
* 💱 **Master-Passwort-Wechsel:** Ändern des Master-Passworts jederzeit von jedem Gerät aus.
* 🚑 **Key-Rotation:** Austausch aller Schlüssel durch Notfall-Reset (Erste-Hilfe z.B. bei Diebstahl).
* 🖨️ **Paper Backup:** PDF-Ausdruck für den physischen Tresor
* 📄 **Import / Export:** Leichter Systemwechsel durch Standardschnittstellen (CSV-Format).


### 🔐 Sicherheit & Kryptografie
- **End-to-End Encryption (E2EE):** Verschlüsselung erfolgt ausschließlich auf dem Client.
- **BSI-konforme Algorithmen:** Einsatz von AES-256-GCM (symmetrisch), RSA-4096 (asymmetrisch) und Argon2id (Key Derivation).
- **Zero-Knowledge-Architektur:** Der Server speichert nur verschlüsselte Blobs. Master-Passwort und Schlüssel verlassen nie das Endgerät.

### 📱 Bedienkomfort & Plattformen
- **Cross-Platform:** Native Apps für **Windows, Android und iOS** mittels .NET MAUI.
- **Biometrie-Integration:** Schneller Login via Fingerabdruck oder FaceID durch hardware-gestützte Keystores.
- **Auto-Fill:** Systemweite Integration zum automatischen Ausfüllen von Logins in Browsern und Apps.
- **Offline-First:** Volle Funktionalität auch ohne Internetverbindung; Synchronisation erfolgt automatisch bei Verfügbarkeit.

### 🤝 Secure Sharing (Family Sharing)
- **Selektives Teilen:** Einträge können mit spezifischen Personen geteilt werden, ohne den gesamten Tresor freizugeben.
- **Rollenkonzept:** Unterscheidung zwischen Leserecht, Schreibrecht und Vollzugriff (Besitzer).
- **Identitätsschutz:** Optionale Verifizierung von Freunden über kryptografische Fingerprints (Fingerprint-Check).

### 🚑 Notfall- & Datenmanagement
- **Key-Rotation (Notfall-Reset):** Austausch aller kryptografischen Schlüssel bei Verlust eines Geräts.
- **Anhänge:** Sicheres Speichern von verschlüsselten Dateien (Bilder, Dokumente).
- **Import/Export:** Einfacher Umzug durch Unterstützung des CSV-Formats.
- **Paper Backup:** Generierung eines PDF-Notfallbogens für den physischen Safe.

---

## 3. Marktvergleich & Abgrenzung

### 3.1 Produkte auf dem Markt

siehe [IT-Sicherheit auf dem digitalen Verbrauchermarkt: Fokus Passwortmanager](https://www.bsi.bund.de/SharedDocs/Downloads/DE/BSI/Publikationen/DVS-Berichte/passwortmanager.pdf?__blob=publicationFile) vom BSI (Bundesamt für Sicherheit in der Informationstechnik).

| Feature                       |        PriVault        |        KeePass         |      Bitwarden      |
|:------------------------------|:----------------------:|:----------------------:|:-------------------:|
| **Zero-Knowledge**            |           Ja           |           Ja           |         Ja          |
| **Native Multi-Device Sync**  |           Ja           | Nein (via Cloud-Files) |         Ja          |
| **Self-Hosting**              |  Einfach (PHP/MySQL)   |          N/A           |  Komplex (Docker)   |
| **Native Mobile Apps**        |           Ja           |     Drittanbieter      |         Ja          |
| **Secure Sharing**            | Hybrid-Verschlüsselung |          Nein          | Ja (Organisationen) |

**Der PriVault-Vorteil:** PriVault kombiniert die einfache Synchronisation moderner Cloud-Manager mit der Souveränität von KeePass und einer Architektur, die für das sichere Teilen optimiert ist.

---

## 4. BSI-Anforderungen (Konformität)
PriVault orientiert sich an den Empfehlungen des **BSI (Bundesamt für Sicherheit in der Informationstechnik)** für Passwort-Manager (TR-02102):

1. **Starke KDF:** Verwendung von **Argon2id** statt veraltetem PBKDF2, um Brute-Force-Angriffe auf GPU-Clustern zu erschweren.
2. **Authentizität:** Integritätsschutz der Daten durch **AES-GCM** (Authenticated Encryption).
3. **Sicherer Transport:** Zwingende Nutzung von **TLS 1.3** für die Kommunikation mit dem Sync-Server.
4. **Zufallszahlen:** Verwendung kryptografisch sicherer Zufallszahlengeneratoren (CSPRNG) der jeweiligen Betriebssysteme.
5. **Speicher-Hygiene:** Aktives Löschen ("Wiping") von Schlüsseln aus dem RAM nach Gebrauch (so weit technisch unter .NET möglich).
