# Flutter

## Unterschied zwischen watch und read (und listen)

| Methode                     | Wann benutzen?                                         | Was passiert?                                                                                                                   |
|-----------------------------|--------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------|  
| `ref.watch(provider)`       | In der build-Methode.                                  | Registriert das Widget als "Zuhörer". Sobald der State sich ändert, wird die ganze `build`-Methode neu ausgeführt.              |
| `ref.read(provider)`        | In Callbacks (`onPressed`) oder einmalig im `listen`.  | Holt den aktuellen Schnappschuss des States, ohne eine dauerhafte Verbindung aufzubauen. Es löst keinen Re-Build aus.           |
| `ref.listen(provider, ...)` | In der `build`-Methode (für Seiteneffekte).            | Führt eine Funktion aus, wenn sich der State ändert (wenn `next` ungleich `previous` ist), aber ohne das Widget neu zu rendern. |
