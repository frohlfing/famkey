import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web-Implementierung des nativen HTML-Drucks.
///
/// Erstellt ein verstecktes `<iframe>` mit dem sanitisierten HTML als `srcdoc`,
/// wartet auf dessen Ladeereignis und ruft `contentWindow.print()` auf.
/// Das iframe wird nach dem Druck aus dem DOM entfernt.
Future<bool> printHtmlNatively(String htmlContent, String jobName) async {
  final completer = Completer<bool>();

  final iframe = web.HTMLIFrameElement();
  iframe.style.display = 'none';
  iframe.style.width = '0';
  iframe.style.height = '0';
  // srcdoc übergibt HTML direkt – kein Netzwerkaufruf, keine URL.
  iframe.setAttribute('srcdoc', htmlContent);

  web.document.body!.append(iframe);

  iframe.addEventListener(
    'load',
        (web.Event _) {
      try {
        iframe.contentWindow!.print();
        if (!completer.isCompleted) completer.complete(true);
      } catch (e) {
        if (!completer.isCompleted) completer.complete(false);
      } finally {
        // Kurze Verzögerung damit der Druckdialog öffnen kann,
        // dann iframe aus dem DOM entfernen.
        Future.delayed(const Duration(seconds: 2), () => iframe.remove());
      }
    }.toJS,
  );

  return completer.future.timeout(
    const Duration(seconds: 30),
    onTimeout: () {
      iframe.remove();
      return false;
    },
  );
}