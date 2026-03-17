/// Hier wierd die Sync‑Protokollversion festgehalten.
///
/// Vor der Synchronisation wird diese Version mit der Version des Servers verglichen:
///
/// - Wenn client.syncProtocolVersion < server.minSupportedSyncProtocol → App zu alt → Sync blockieren
/// - Wenn client.syncProtocolVersion > server.currentSyncProtocol → Server zu alt → Sync blockieren
/// - Sonst → Sync erlaubt
class SyncProtocol {
  static const int version = 1;
}

// todo evtl eine setup.dart, global.dart oder config.dart anlegen und dort diesen Werte speichern