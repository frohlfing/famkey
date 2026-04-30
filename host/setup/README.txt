FamKey – Sync-Server Installation
====================================

VERZEICHNISSTRUKTUR
-------------------
Dieses Archiv enthält zwei Ordner:

  server-root/   →  eine Ebene OBERHALB des Web-Root hochladen
                    z. B. nach /home/user/  (wenn Web-Root = /home/user/httpdocs/)

  web-root/      →  Inhalt direkt IN den Web-Root hochladen
                    z. B. nach /home/user/httpdocs/


INSTALLATION (5 Schritte)
--------------------------
1. Inhalt von server-root/ eine Ebene ÜBER den Web-Root hochladen (FTP/SFTP).
2. Inhalt von web-root/    direkt IN den Web-Root hochladen.
3. MySQL-Datenbank anlegen:
     Zeichensatz:  utf8mb4
     Kollation:    utf8mb4_unicode_ci
4. Setup-Assistenten aufrufen:
     https://deine-domain.de/setup
   Das Script prüft die Voraussetzungen, fragt Datenbankzugangsdaten ab,
   schreibt config.php und richtet das Datenbankschema ein.
5. FamKey-App öffnen → Einstellungen → Sync-Server → URL eintragen.


VORAUSSETZUNGEN
---------------
  • PHP 8.4 oder neuer
  • MySQL 8.x oder MariaDB  (Charset utf8mb4)
  • HTTPS  (Let's Encrypt empfohlen – bei den meisten Hostern mit einem Klick)


NACH DER INSTALLATION
----------------------
Der Setup-Ordner (setup/) wird am Ende des Setups automatisch gelöscht.
Falls nicht: Ordner manuell löschen – er darf nicht dauerhaft erreichbar sein.


WEITERE INFORMATIONEN
----------------------
  GitHub:  https://github.com/frohlfing/FamKey
  Lizenz:  GPL-3.0
