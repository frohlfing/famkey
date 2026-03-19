import 'package:privault/core/app_error.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/main/sync_statistics.dart';

/// Benutzerdaten, die für eine Identitätsübernahme benötigt werden (bei `syncAskForAdoption` bzw. `syncAskForOnboarding`).
class UserIdentity {
  /// Die globale eindeutige Identifikationsnummer (UUID v4) des Benutzers.
  final String userUuid;

  /// Das serverseitig gespeicherte Salt des Benutzers zur Ableitung des Master-Keys.
  final String salt;

  /// Der öffentliche RSA-Schlüssel des Benutzers (Base64-kodierter SPKI-String).
  final String publicKey;

  /// Der mit dem Master-Passwort verschlüsselte RSA-Privatschlüssel des Benutzers (Base64).
  final String encryptedPrivateKey;

  /// Konstruktor
  const UserIdentity({
    this.userUuid = '',
    this.salt = '',
    this.publicKey = '',
    this.encryptedPrivateKey = '',
  });
}

/// Ein Enum für den Status von Aktionen
enum MainActionStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft
  loaded, // Liste wurde erfolgreich geladen
  synced, // Sync wurde erfolgreich beendet
  adopted, // Benutzeridentität wurde erfolgreich adoptiert
  failure, // Aktion mit Fehler beendet
  syncAskForAdoption, // Passwort wurde auf einem anderen Gerät geändert. Frage, ob die Identität adoptiert werden soll.
  syncAskForOnboarding, // Zweitgerät soll zum ersten mal synchronisiert werden. Frage, ob die Identität adoptiert werden soll.
  syncAskForRekeying, // Schlüssel des Freundes ist ungültig
}

class MainState {

  /// Der Name des Tresors.
  final String vaultName;

  /// Der Suchbegriff.
  final String searchQuery;

  /// Gibt an, ob nur die eigenen Einträge angezeigt werden.
  final bool onlyMyEntries;

  /// Anzuzeigende Einträge gruppiert nach Kategorien
  final Map<String, List<EntryEntity>> groupedEntries;

  /// Speichert die Namen der Kategorien, die aktuell in der UI eingeklappt sind.
  final Set<String> collapsedCategories;

  /// Benutzeridentität, die adoptiert werden muss.
  final UserIdentity adoptionUserIdentity;

  /// Die Sync-Statistik.
  final SyncStatistics syncStatistics;

  /// Der Status der letzten Aktion.
  final MainActionStatus status;

  /// Der Fehler der letzten Operation.
  final FormError error;

  // --- Getter ---

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isBusy => status == MainActionStatus.progress;

  /// Konstruktor
  const MainState({
    this.vaultName = '',
    this.searchQuery = '',
    this.onlyMyEntries = false,
    this.groupedEntries = const {},
    this.collapsedCategories = const {},
    this.adoptionUserIdentity = const UserIdentity(),
    this.syncStatistics = const SyncStatistics(),
    this.status = MainActionStatus.initial,
    this.error = const FormError.none(),
  });

  /// Status aktualisieren (immutable)
  MainState copyWith({
    String? vaultName,
    String? searchQuery,
    bool? onlyMyEntries,
    Map<String, List<EntryEntity>>? groupedEntries,
    Set<String>? collapsedCategories,
    UserIdentity? adoptionUserIdentity,
    SyncStatistics? syncStatistics,
    MainActionStatus? status,
    FormError? error,
  }) {

    return MainState(
      groupedEntries: groupedEntries ?? this.groupedEntries,
      collapsedCategories: collapsedCategories ?? this.collapsedCategories,
      vaultName: vaultName ?? this.vaultName,
      searchQuery: searchQuery ?? this.searchQuery,
      onlyMyEntries: onlyMyEntries ?? this.onlyMyEntries,
      adoptionUserIdentity: adoptionUserIdentity ?? this.adoptionUserIdentity,
      syncStatistics: syncStatistics ?? this.syncStatistics,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
