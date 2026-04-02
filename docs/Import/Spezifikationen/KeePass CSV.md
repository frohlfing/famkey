# KeePass CSV

Quelle: https://keepass.info/help/base/importexport.html

- Die Datei muss mit UTF-8 (Unicode) kodiert sein. Andere Kodierungen werden nicht unterstützt.
- Alle Felder müssen in Anführungszeichen (") eingeschlossen sein. Diese Anführungszeichen sind zwingend erforderlich, Felder ohne Anführungszeichen sind nicht zulässig.
- Anführungszeichen (") in Zeichenfolgen werden als \" (zwei Zeichen) kodiert. Backslashes (\) werden als \\ kodiert.
- Mehrzeilige Kommentare werden durch normale Zeilenumbrüche realisiert. Die Kodierung von Zeilenumbrüchen mit \n wird nicht unterstützt.

---

KeePass 1.x importiert und exportiert Daten von/in CSV-Dateien im folgenden Format:

"Account","Login Name","Password","Web Site","Comments"

Das Feld 'Account' in einer CSV-Datei entspricht dem Titelfeld eines KeePass-Eintrags, 
'Login Name' entspricht dem Benutzernamen, 
'Web Site' entspricht der URL und 
'Comments' entsprechen den Notizen. 

Andere Felder wie der Zeitpunkt der letzten Änderung, die Ablaufzeit, das Symbol (Icon), Dateianhänge usw. werden nicht unterstützt.

---

KeePassXC 2.7.10 importiert und exportiert Daten von/in CSV-Dateien im folgenden Format:

"Group","Title","Username","Password","URL","Notes","TOTP","Icon","Last Modified","Created"
