/// Stub-Implementierung für Mobile (Android, iOS, Windows, ...).
///
/// Auf diesen Plattformen übernimmt [HeadlessInAppWebView] den Druck.
/// Diese Datei wird nur kompiliert, wenn [dart:html] nicht verfügbar ist.
Future<bool> printHtmlNatively(String html, String jobName) async => false;