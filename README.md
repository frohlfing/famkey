# Privault

Ein selbst-gehosteter **Passwort-Manager** für Desktop und Mobile.
Die Datenhoheit liegt allein beim Nutzer.

**Features:**

* 💻 **Cross-Platform:** Native Apps für Windows, Android und iOS.
* 📱 **Multi-Device Sync:** Nahtlose Nutzung auf mehreren Geräten durch sicheren Schlüsselaustausch.
* ⚡ **Offline-First:** Volle Funktionalität ohne Internetverbindung. Sync erfolgt bei Verfügbarkeit.
* 🤝 **Family Sharing:** Sicheres Teilen von Einträgen mit Familie und Freunden mittels Hybrid-Verschlüsselung.
* 📎 **Anhänge:** Verschlüsseltes Speichern von Dateien und Dokumenten.
* ☁️ **Self-Hosted Sync:** Einfaches PHP/MySQL Backend (läuft auf jedem Standard-Webspace), Multi-Tenant.
* 🏷️ **Zero-Knowledge:** Der Server kennt das Passwort nie.
* 👀 **Biometrie:** Login via Fingerabdruck/FaceID (Hardware-Backed Keystore).
* 📝 **Auto-Fill:** Integration in das Betriebssystem zum automatischen Ausfüllen von Login-Feldern.
* 🔐 **BSI-konforme Kryptografie:** AES-256-GCM, RSA-4096 (OAEP) und Argon2id Hashing.
* 🚑 **Notfall-Reset:** Master-Passwort ändern, AES- und RSA-Keys neu generieren

## Projektdokumentation

Eine detailliertere technische Dokumentation befindet sich in [Projektdokumentation.md](Docs/Projektdokumentation.md).

## Lizenz

Dieses Projekt steht unter der [GPL-3.0-Lizenz](LICENSE).

Das bedeutet: Du darfst diesen Code nutzen, ändern und verbreiten. Wenn du die Software (oder eine modifizierte Version
davon) jedoch weitergibst, musst du deinen Quellcode ebenfalls unter derselben Lizenz offenlegen.