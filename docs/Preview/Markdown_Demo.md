# Markdown Demo

Dieses Dokument zeigt alle unterstützten Elemente des MarkdownRenderers.

---

## Überschriften

# H1 – Hauptüberschrift
## H2 – Abschnittsüberschrift
### H3 – Unterabschnitt

---

## Aufzählungslisten

- Erster Punkt
- Zweiter Punkt mit **fettem** Text
- Dritter Punkt mit `code`
  - Eingerückter Unterpunkt
  - Noch ein Unterpunkt
    - Dritte Ebene
- Zurück zur ersten Ebene

---

## Textformatierung

Normaler Absatz mit **fettem Text**, *kursivem Text* und `inline code`.

**Fett** und *kursiv* können auch **kombiniert mit `code`** in einem Satz erscheinen.

Ein zweiter Absatz. Lorem ipsum dolor sit amet, consectetur adipiscing elit.

---

## Code-Block

```
fun greet(name: String): String {
    return "Hallo, $name!"
}
```

```
SELECT titel, benutzername
FROM passwoerter
WHERE kategorie = 'Bank'
ORDER BY titel ASC;
```

---

\pagebreak

## Horizontale Linie

Oben

---

Unten

---

## Tabelle

| Dienst       | Benutzername       | Notiz                  |
|--------------|--------------------|-----------------------|
| GitHub       | frank@example.com  | 2FA aktiv             |
| Nextcloud    | frank              | Selbst gehostet       |
| ProtonMail   | f.mueller          | Backup-Codes sicher   |
| Bitwarden    | frank@example.com  | Master-Passwort!      |

---

## Tabelle mit Inline-Formatierung in Absätzen darunter

| Spalte A     | Spalte B     | Spalte C     |
|--------------|--------------|--------------|
| **Fett**     | *Kursiv*     | Normal       |
| Wert 1       | Wert 2       | Wert 3       |

Hinweis: Inline-Formatierung innerhalb von Tabellenzellen wird aktuell
als Klartext dargestellt.

---

## Bild

Bilder werden als `data:`-URI eingebettet: `![FamKey Logo](data:image/png;base64,iVBORw0KGgo...)`

![FamKey Logo](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAYAAAA6/NlyAAAACXBIWXMAAA7EAAAOxAGVKw4bAAADkklEQVRoge2aQWgcVRjHf98kTbAkuFIh9WAptA1EDyoEIkgtBRUKUihIWtSYLSq9tfaSUysRPUgPhYZeGgxbi7nk1DZFeulB2xpQq5Aa8KJG8ZBQWttkt8t2s/N5SNpDsjs72fe9zSTsD3LIvnn/7/tlsjsz7y00aLChkHoWU0X4hq0oKZR2oIWQLM1kaWVGesn67sGrsH5NJ/A6ym7gZWAnsDliygzwOzCBcJ0mbsr7zFn2ZC6sI7TTxKdAH9DhGFcCfkEZlMN8696dsbCO8gxFrgGvWOYCIHwi/ZxxjQksennCAmfwIQugnNYLdLvGmAlrhl0ofVZ5ZQgIGXQPsUI4YJZVmTd1hHaXgGarThB60IqjVxHGEaYo8Tdwn3ny3KXIDp5igc0IW4HtwGsI7wLPl8lpoZmXgBu1tmknDC9WeH1a0uyLmJdb+rkD3AbG9Tw/AJci6tQsbPIvrUO0ouysMFxadaAQRoxW+sPGwuY9nGIX0GSSVQ2ly2W6jXCJZyNGO3SMllXladn372O2rCprGTbCAU9HjLaR53jcKM2QQjgWcUhUrapYfWilIkeVL/U876DkqiYJnSjPRRyxDoQX6Ta6kXUStrrxqM8H1iLNOlZ7PRth5YFJTjxy0lvDpW4JqzN83yjHey0bYanrGXaqZXUdvmeSEwdJwhku8odJThyUP12mmwjLER4A/1pkVUWZcplu9zzs2EhsAn5zm25FwK9mWdFMuky2Ew5tVhWrMCX9/OMSYCec5gbwk1leOZSzrhFmwiIowkfAf1aZy7jGNMOuIabLtNLPJLAbuEItKx3lKQLDFNgvn0WuhMTC21aLZkgRsJeQNxDeBrbFnYowQch14HsecXPpsmdCXTbTNMOrCBOPf88VIP8IRGBL24rDf5Q0Pb56sVy1jE22APeyEJQT1ojFXgNst1rWAQ3hNUf42Wd80oSnKDDgs0CyhEu8J0d46LNEsoQD/zuQyRIWTuoF9vgskSzhxU3vL/wWSBrKJp/xyRMWij7jkyYcEnDCZ4FkCSufywd857NEsoThou8CyRIWRvVc5FcTnUmWMLxAK6d8FkiaMKj7t+2iSJ6wZ+ojvMBfEHPDbSM8HsrHzAKHYxy6cR4PJc1lYCjikDxwcGM9Hs4xABX2oJRjkva/IVdXYTlKAeEQrLhfHiPNV3XpoR5FljM7xFuqdBEQdrRxm5Bb8iHza9FLgwbrnP8Bn2zPzIiGs0kAAAAASUVORK5CYII=)

---

## Sonderzeichen

!?§\$€%&#@()[]{}<>=_~-+*,;.:/|\\^´`\'"

## Grenzen des Parsers

- Listen werden als Absatz dargestellt
- Verschachtelte Formatierung wie ***fett-kursiv*** wird nicht unterstützt
- Inline-Formatierung in Tabellenzellen wird ignoriert
- Nur `data:`-URIs bei Bildern (keine HTTP-URLs)