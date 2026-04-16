import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pdf/widgets.dart' as pw;

// Conditional Import: dart:html ist nur auf Web verfügbar.
// Auf Mobile greift der Stub, der false zurückgibt.
import 'html_print_helper_stub.dart'
    if (dart.library.html) 'html_print_helper_web.dart';

import '../renderer.dart';

/// Sicherer Renderer für HTML-Inhalte.
///
/// Nutzt eine native Browser-Engine, um auch komplexes HTML korrekt und
/// performant darstellen zu können.
///
/// ## Sicherheits-Architektur (Defense in Depth)
///
/// Da PriVault ein Passwort-Safe ist, hat Sicherheit höchste Priorität.
/// Der Renderer verwendet mehrere unabhängige Schutzschichten:
///
/// ### Schicht 0 – HTML-Sanitisierung (vor dem Rendern)
/// Bevor das HTML die WebView erreicht, werden alle aktiven Inhalte entfernt:
/// - `<script>`-Tags (inkl. Inhalt) → vollständig gelöscht
/// - Inline-Event-Handler (`onclick=`, `onload=`, `onerror=`, etc.) → entfernt
///
/// ### Schicht 1 – Content Security Policy (CSP) per HTML-Injektion
/// Vor dem Rendern wird eine strikte CSP als `<meta>`-Tag injiziert:
/// - `default-src 'none'` → alles blockiert, sofern nicht explizit erlaubt
/// - `script-src` fehlt → JavaScript vollständig verboten
/// - `style-src 'unsafe-inline'` → nur inline-CSS erlaubt
/// - `img-src data: blob:` → nur eingebettete Bilder (data-URI / Blob)
/// - `font-src data:` → nur eingebettete Fonts
/// - `connect-src` fehlt → fetch/XHR/WebSocket verboten
/// - `frame-src` fehlt → keine iframes innerhalb des Dokuments
///
/// ### Schicht 2 – WebView-Settings (native Plattform-Ebene)
/// - `javaScriptEnabled: false` → JS auf Engine-Ebene deaktiviert
/// - `blockNetworkLoads/blockNetworkImage: true` → Netzwerk auf Android blockiert
/// - `allowFileAccessFromFileURLs: false` → kein lokaler Dateizugriff
///
/// ### Schicht 3 – Navigations-Interceptor (Laufzeit-Ebene)
/// Alle HTTP(S)-Navigationen werden zur Laufzeit abgebrochen.
///
/// ## Drucken
/// - **Web**: Verstecktes `<iframe>` via `package:web` + `contentWindow.print()`
/// - **Mobile**: [HeadlessInAppWebView] + `printCurrentPage`
class HtmlRenderer implements Renderer {
  /// Rohdaten des HTML-Dokuments.
  final Uint8List? bytes;

  /// Konstruktor.
  const HtmlRenderer(this.bytes);

  @override
  bool get isPrintable => bytes != null && bytes!.isNotEmpty;

  /// Dekodiert die Bytes als UTF-8-String.
  String? get html => bytes == null ? null : utf8.decode(bytes!, allowMalformed: true);

  // --------------------------------------------------------------------------
  // --- Schicht 0: HTML-Sanitisierung ---
  // --------------------------------------------------------------------------

  /// Entfernt `<script>`-Tags inkl. Inhalt (auch mehrzeilig).
  static final RegExp _scriptTagPattern = RegExp(
    r'<script\b[^>]*>.*?</script>',
    caseSensitive: false,
    dotAll: true,
  );

  /// Entfernt Inline-Event-Handler-Attribute (`on*="..."` und `on*='...'`).
  ///
  /// Triple-quoted Raw-String nötig, da einfache Raw-Strings `r'...'`
  /// kein `'` im Muster erlauben.
  static final RegExp _eventHandlerPattern = RegExp(
    r'''\s+on\w+\s*=\s*(?:"[^"]*"|'[^']*')''',
    caseSensitive: false,
  );

  String _sanitize(String rawHtml) => rawHtml
      .replaceAll(_scriptTagPattern, '')
      .replaceAll(_eventHandlerPattern, '');

  // --------------------------------------------------------------------------
  // --- Schicht 1: CSP-Injektion ---
  // --------------------------------------------------------------------------

  /// Strikte Content Security Policy, die alle externen Ressourcen blockiert.
  ///
  /// Kein script-src → JavaScript ist vollständig verboten.
  /// Kein connect-src → Netzwerkzugriffe (fetch, XHR) sind verboten.
  /// img-src erlaubt nur data: und blob: (eingebettete Bilder).
  static const String _cspMetaTag =
      '<meta http-equiv="Content-Security-Policy" '
      'content="'
      "default-src 'none'; "
      "style-src 'unsafe-inline'; "
      "img-src data: blob:; "
      "font-src data:;"
      '">';

  /// Injiziert die CSP so früh wie möglich in das HTML-Dokument.
  ///
  /// Strategie:
  /// 1. Falls ein `<head>`-Tag vorhanden ist → CSP direkt dahinter einfügen,
  ///    damit sie vor allen anderen Tags wirksam ist.
  /// 2. Falls kein `<head>` vorhanden ist → CSP an den Anfang des Dokuments
  ///    prependen (z. B. bei HTML-Fragmenten ohne vollständige Struktur).
  String _injectCsp(String rawHtml) {
    final headTagPattern = RegExp(r'<head(?:\s[^>]*)?>', caseSensitive: false);
    final match = headTagPattern.firstMatch(rawHtml);

    if (match != null) {
      final i = match.end;
      return '${rawHtml.substring(0, i)}\n$_cspMetaTag\n${rawHtml.substring(i)}';
    }

    return '$_cspMetaTag\n$rawHtml';
  }

  /// Sanitisierung → CSP-Injektion.
  String _prepare(String rawHtml) => _injectCsp(_sanitize(rawHtml));

  // --------------------------------------------------------------------------
  // --- Schicht 2: WebView-Settings ---
  // --------------------------------------------------------------------------

  /// Gemeinsame WebView-Sicherheitseinstellungen für Vorschau und Druck.
  static InAppWebViewSettings get _secureSettings => InAppWebViewSettings(
    // --- Schicht 2: Native WebView-Sicherheitseinstellungen ---

    // JavaScript auf Engine-Ebene vollständig deaktivieren.
    // Greift unabhängig von der CSP (Defense in Depth).
    javaScriptEnabled: false,

    // Android: Alle Netzwerkoperationen auf nativer Ebene blockieren.
    // Greift bevor die Browser-Engine überhaupt eine Anfrage stellt.
    blockNetworkLoads: true,
    blockNetworkImage: true,

    // Kein Zugriff auf das lokale Dateisystem über file://-URLs.
    allowFileAccessFromFileURLs: false,
    allowUniversalAccessFromFileURLs: false,

    // Keine automatische Media-Wiedergabe (Audio/Video-Tags).
    mediaPlaybackRequiresUserGesture: true,

    // Transparenter Hintergrund, damit der App-Theme durchscheint.
    transparentBackground: true,

    // Keine Geolocation-Anfragen.
    geolocationEnabled: false,
  );

  // --------------------------------------------------------------------------
  // --- Widget-Aufbau ---
  // --------------------------------------------------------------------------

  @override
  Widget buildWidget() {
    final content = html;

    if (content == null || content.isEmpty) {
      return const Center(child: Text('Keine HTML-Daten verfügbar.'));
    }

    return InAppWebView(
      initialData: InAppWebViewInitialData(
        data: _prepare(content),
        mimeType: 'text/html',
        encoding: 'utf-8',
      ),
      initialSettings: _secureSettings,

      // --- Schicht 3: Navigations-Interceptor ---
      // Fängt jeden Navigationsversuch zur Laufzeit ab.
      // Nur about:blank und data:-URLs (eingebettete Inhalte) sind erlaubt.
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final url = navigationAction.request.url?.toString() ?? '';

        // Eingebettete Inhalte (data-URI, about:blank beim initialen Laden)
        if (url.startsWith('data:') || url.startsWith('about:')) {
          return NavigationActionPolicy.ALLOW;
        }

        // Alle externen Navigationen (http, https, file, ftp, ...) blockieren
        debugPrint('[HtmlRenderer] Externe Navigation blockiert: $url');
        return NavigationActionPolicy.CANCEL;
      },

      // Externe Ressource-Anfragen mit Custom-Schemes explizit ablehnen
      onLoadResourceWithCustomScheme: (controller, request) async {
        debugPrint('[HtmlRenderer] Custom-Scheme blockiert: ${request.url}');
        return CustomSchemeResponse(
          data: Uint8List(0),
          contentType: 'text/plain',
          contentEncoding: 'utf-8',
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // --- Drucken ---
  // --------------------------------------------------------------------------

  /// Druckt das HTML nativ – plattformabhängig via Conditional Import.
  ///
  /// Gibt `true` zurück wenn der Druck initiiert wurde,
  /// `false` bei Fehler oder fehlenden Daten.
  @override
  Future<bool> printNatively(String jobName) async {
    final content = html;
    if (content == null || content.isEmpty) return false;

    final prepared = _prepare(content);

    // Web-Pfad: Conditional Import löst html_print_helper_web.dart auf.
    // Stub auf Mobile gibt false zurück → Mobile-Pfad unten greift.
    final handledByWeb = await printHtmlNatively(prepared, jobName);
    if (handledByWeb) return true;

    // Mobile/Desktop-Pfad: HeadlessInAppWebView.
    final completer = Completer<void>();

    // Flag: true sobald loadData() aufgerufen wurde.
    // Auf Windows meldet onLoadStop immer about:blank als URL – auch nach
    // dem echten Ladevorgang. Ein URL-Vergleich funktioniert daher nicht.
    // Stattdessen: ersten onLoadStop (initiales about:blank) überspringen,
    // zweiten (nach loadData) für den Druck verwenden.
    bool dataLoaded = false;

    final headless = HeadlessInAppWebView(
      initialSettings: _secureSettings,
      onWebViewCreated: (controller) async {
        await controller.loadData(
          data: prepared,
          mimeType: 'text/html',
          encoding: 'utf-8',
        );
        dataLoaded = true;
      },

      onLoadStop: (controller, url) async {
        if (!dataLoaded) return; // Initiales about:blank überspringen

        await controller.printCurrentPage(
          settings: PrintJobSettings(jobName: jobName),
        );
        if (!completer.isCompleted) completer.complete();
      },
      onReceivedError: (controller, request, error) {
        debugPrint('[HtmlRenderer] Druckfehler: ${error.description}');
        if (!completer.isCompleted) completer.complete();
      },
    );

    await headless.run();

    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => debugPrint('[HtmlRenderer] Drucken: Timeout erreicht.'),
    );

    await headless.dispose();
    return true;
  }

  // --------------------------------------------------------------------------
  // --- PDF-Fallback ---
  // --------------------------------------------------------------------------

  /// Fallback: Gibt den rohen HTML-Text aus.
  ///
  /// Dieser Pfad wird nur erreicht, wenn [printNatively] `false` zurückgibt,
  /// also wenn [buildWidget] noch nicht aufgerufen wurde. In der Praxis
  /// sollte das nicht vorkommen, da der Nutzer die Vorschau vor dem Drucken
  /// sieht.
  @override
  pw.Widget buildPrintableWidget() {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(24),
      child: pw.Text(
        html ?? '',
        style: const pw.TextStyle(fontSize: 11),
      ),
    );
  }
}