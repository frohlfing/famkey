# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**FamKey** is a self-hosted password manager for Windows, Android, and Web (WebAssembly), built with Flutter/Dart. It uses a PHP/MySQL backend for synchronization. Documentation and comments are in **German**.

## Common Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run -d windows
flutter run -d <android-emulator>
flutter run -d edge --web-header="Cross-Origin-Opener-Policy=same-origin" --web-header="Cross-Origin-Embedder-Policy=require-corp"

# Run all tests
flutter test
flutter test --coverage

# Lint/analyze
flutter analyze

# Code generation (Drift ORM + Riverpod — required after schema/provider changes)
flutter pub run build_runner build --delete-conflicting-outputs

# One-time crypto setup (builds BoringSSL for native platforms)
dart run webcrypto:setup

# Regenerate app icons
flutter pub run flutter_launcher_icons
```

## Architecture

### Pattern: Feature-first Clean Architecture with Riverpod

Each feature under `lib/features/` follows a three-file pattern:
- `*_notifier.dart` — Riverpod `AsyncNotifier` or `Notifier` with business logic
- `*_state.dart` — Immutable state model
- `*_page.dart` — `ConsumerWidget` UI

Features: `login/`, `main/` (vault list + import/export/sync subfeatures), `detail/`, `edit/`, `settings/` (with sub-dialogs), `report/`.

### State Management: Riverpod

- Use `ref.watch()` for reactive reads in `build()`
- Use `ref.read()` for one-shot reads in event handlers
- Riverpod lint is enabled (`riverpod_lint`) — violations are reported by `flutter analyze`

### Services: GetIt Dependency Injection

All singleton services are registered in `lib/core/service_locator.dart` and accessed via `getIt<ServiceName>()`. Key services:
- `CryptoService` — AES-256-GCM, RSA-4096 OAEP, Argon2id (master password KDF)
- `DatabaseService` — abstraction over Drift ORM
- `WebService` — HTTP API client (Dio) for server sync
- `ConfigService` — SharedPreferences wrapper
- `SessionService` — current user / auth state
- `BiometricService`, `PasswordService`, `AutofillService`

### Database: Drift ORM with SQLCipher

Schema defined in `lib/database/database.dart`; generated code is `database.g.dart`. Tables: Users, Entries, Permissions, Settings, Attachments. Run `build_runner` after any schema change.

**Windows requirement:** `sqlite3mc_x64.dll` (SQLCipher) must be in the project root — see `docs/06_Setup.md`.

### Encryption

- **Master password:** Argon2id KDF (64 MB memory, 4 iterations, 4 parallelism)
- **Entry data:** AES-256-GCM via `webcrypto` (BoringSSL on native, SubtleCrypto on web)
- **Sharing:** RSA-4096 OAEP public-key encryption

### Platform Abstraction

Conditional imports are used for web vs. native differences (file I/O, crypto, database connection). Files are named `*_web.dart` / `*_native.dart` with a stub `*.dart` exporting the correct one via `dart.library.ffi` / `dart.library.js_interop`.

### Routing

`MaterialApp` with named routes: `/` (login), `/main`, `/settings`, `/report`. Detail and edit screens use argument passing via `RouteSettings.arguments`.

## Code Generation

The following files are auto-generated and must not be edited manually:
- `lib/database/database.g.dart` (Drift)
- `test/**/*.mocks.dart` (Mockito)
- Any `*.g.dart` alongside Riverpod providers

Regenerate with `flutter pub run build_runner build --delete-conflicting-outputs`.

## Key Documentation

- `docs/02_Kryptografie.md` — Detailed crypto algorithm decisions
- `docs/02_Konzept.md` — Konzeptual overview of the app architecture and functionality
- `docs/05_API-Spezifikation.md` — REST API contract with the PHP backend
- `docs/06_Setup.md` — Full development environment setup (Windows, Android, Web, Backend)
- `docs/08_Styleguide.md` — Code style guidelines
- `docs/Flutter.md` — Flutter/Dart patterns used in this project (Riverpod, Drift, conditional imports)

## Formatter

Line width is set to 999 (effectively unlimited) and trailing commas are preserved. Do not wrap long lines.