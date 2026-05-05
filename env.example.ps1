# Vorlage für env.ps1 – Kopieren, umbenennen und Pfade anpassen.
# env.ps1 wird nicht ins Git eingecheckt.

# Pfad zum public-Verzeichnis der FamKey-Homepage (famkey-home-Projekt).
# Wird von bin/deploy.ps1 verwendet, um Releases und die Web-App dorthin zu kopieren.
$env:FAMKEY_HOME_PUBLIC = "C:\Pfad\zu\famkey-home\public"
