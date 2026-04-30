# 01 Produktbeschreibung

PriVault ist ein ein selbst-gehosteter **Passwort-Manager** für Familien, Teams und Vereine.

---

## 1. Features im Überblick

### Sicherheit & Kryptografie
- 🔐 **BSI-konforme Kryptografie:** AES-256-GCM, RSA-4096 (OAEP) und Argon2id Hashing.
- 👀 **Biometrie:** Schneller Login via Fingerabdruck oder FaceID durch hardware-gestützte Keystores.
- 📝 **Auto-Fill:** Integration in das Betriebssystem zum automatischen Ausfüllen von Login-Feldern.

### Bedienkomfort
- 💻 **Cross-Platform:** Native Apps für Mobil, Windows und Webbrowser.
-  ⚡ **Offline-First:** Volle Funktionalität auch ohne Internetverbindung.
- 📱 **Multi-Device Sync:** Nahtlose Nutzung auf mehreren Geräten durch sicheren Schlüsselaustausch.
- 📎 **Anhänge:** Verschlüsseltes Speichern von Dateien.
- 🤝 **Family Sharing:** Sicheres Teilen von Einträgen mit Familie und Freunden mittels Hybrid-Verschlüsselung.
- 🖼️ **Favicon-Cache:** Automatisches Speichern der Favicons zur visuellen Unterscheidung der Einträge
- 📄 **Import/Export:** Leichter Systemwechsel durch Standardschnittstellen.
- 🖨️ **Paper Backup:** Generierung eines Notfallbogens für den physischen Tresor.

### Backend
- ☁️ **Self-Hosted Sync-Server:** Einfaches PHP/MySQL Backend (läuft auf jedem Standard-Webspace).
- 🏷️ **Zero-Knowledge-Architektur:** Der Server speichert nur verschlüsselte Blobs. Master-Passwort und Schlüssel verlassen nie das Endgerät.
* 📚 **Multi-Tenant:** Mandantenfähig - Mehrere getrennte Tresore auf demselben Server.

---

## 2. Marktvergleich & Abgrenzung

### Produkte auf dem Markt

siehe [IT-Sicherheit auf dem digitalen Verbrauchermarkt: Fokus Passwortmanager](https://www.bsi.bund.de/SharedDocs/Downloads/DE/BSI/Publikationen/DVS-Berichte/passwortmanager.pdf?__blob=publicationFile) vom BSI (Bundesamt für Sicherheit in der Informationstechnik).

| Feature                       |        PriVault        |        KeePass         |      Bitwarden      |
|:------------------------------|:----------------------:|:----------------------:|:-------------------:|
| **Zero-Knowledge**            |           Ja           |           Ja           |         Ja          |
| **Native Multi-Device Sync**  |           Ja           | Nein (via Cloud-Files) |         Ja          |
| **Self-Hosting**              |  Einfach (PHP/MySQL)   |          N/A           |  Komplex (Docker)   |
| **Native Mobile Apps**        |           Ja           |     Drittanbieter      |         Ja          |
| **Secure Sharing**            | Hybrid-Verschlüsselung |          Nein          | Ja (Organisationen) |

---

## 3. BSI-Anforderungen (Konformität)
PriVault orientiert sich an den Empfehlungen des **BSI (Bundesamt für Sicherheit in der Informationstechnik)** für Passwort-Manager (TR-02102):

1. **Starke KDF:** Verwendung von **Argon2id** statt veraltetem PBKDF2, um Brute-Force-Angriffe auf GPU-Clustern zu erschweren.
2. **Authentizität:** Integritätsschutz der Daten durch **AES-GCM** (Authenticated Encryption).
3. **Sicherer Transport:** Zwingende Nutzung von **TLS 1.3** für die Kommunikation mit dem Sync-Server.
4. **Zufallszahlen:** Verwendung kryptografisch sicherer Zufallszahlengeneratoren (CSPRNG) der jeweiligen Betriebssysteme.
5. **Speicher-Hygiene:** Aktives Löschen ("Wiping") von Schlüsseln aus dem RAM nach Gebrauch (so weit technisch unter .NET möglich).
