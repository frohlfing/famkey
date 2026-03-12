# Ordner: packages/

Der Ordner `packages/` enthält alle wiederverwendbaren, plattformunabhängigen Dart-/Flutter-Pakete.

## Inhalt
- `core/` – Basis-Funktionalität, Utilities, DI, Basisklassen
- `domain/` – Datenmodelle (Entities, DTOs, Payloads, Exceptions)
- `data/` – Datenzugriff (DB, Services, Repositories)

## Zweck
Packages kapseln Logik, die:
- **plattformunabhängig** ist
- **zwischen mehreren Apps geteilt** wird
- **getestet** werden kann
- **keine UI** enthält
- **keinen BuildContext** benötigt

## Besonderheiten
- Jedes Package hat eine eigene `pubspec.yaml`.
- Jedes Package hat einen `lib/`-Ordner, der die öffentliche API darstellt.
- Code außerhalb von `lib/` ist privat.
- Perfekt für Riverpod-Provider, die nicht UI-gebunden sind.

## Wichtig
Packages bilden die **Business-Logik-Schichten**:
- core → Basisschicht
- domain → Datenmodelle
- data → Datenzugriff
