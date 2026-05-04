FamKey – Sync-Server installieren
=================================

GitHub:  https://github.com/frohlfing/FamKey
Lizenz:  GPL-3.0

Voraussetzungen
---------------
  • PHP 8.4 oder neuer
  • MySQL 8.x oder MariaDB  (Charset utf8mb4)
  • HTTPS  (z.B. Basic- bzw. Let's Encrypt-Zertifikate – bei den meisten Hostern mit einem Klick)

Installationsschritte
----------------------

1. Domain einrichten
   Richte dir bei deinem Hoster eine Domain oder Subdomain ein.
   Aktiviere SSL, sodass die Domain unter Https erreichbar ist.

2. MySQL-Datenbank anlegen
   Lege über das Verwaltungs-Panel deines Hosters eine neue Datenbank an.
      Zeichensatz:  utf8mb4
      Kollation:    utf8mb4_unicode_ci
   Merke dir Datenbankname, Benutzername und Passwort.

3. Dateien hochladen
   Entpacke das Archiv und lade den Inhalt des Ordners famkey/ in das
   Web-Root deines Servers hoch (z.B. per WinSCP ode ein anderes FTP/SFTP-Programm).

4. Setup-Assistenten starten

   Rufe im Browser https://deine-domain.de/setup auf.

   Das Script prüft die Systemanforderungen, fragt Datenbankverbindung und Server-Einstellungen ab,
   legt die Konfiguration automatisch an und richtet das Datenbankschema ein.

   Am Ende des Setups wird der Setup-Ordner (setup/) automatisch gelöscht.
   Falls nicht: Ordner manuell löschen – er darf nicht dauerhaft erreichbar sein.

5. Server-URL in der App eintragen und Sync starten.
   Öffne deine FamKey-App. Trage unter Einstellungen den Sync-Server ein.
   Gib dort auch den API-Token an, der in der Konfigurationsdatei config.php hinterlegt ist.

   HINWEIS: Teile den API-Token nur mit denjenigen, die den Server nutzen dürfen.
