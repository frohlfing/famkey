import 'package:flutter/material.dart';
import 'package:famkey/database/database.dart'; // Pfad ggf. anpassen

/// Ein modaler Dialog zur Auswahl eines Freundes.
class FriendDialog {

  /// Öffnet den Dialog und gibt bei Bestätigung den ausgewählten Freund zurück.
  static Future<UserEntity?> show(BuildContext context, List<UserEntity> available) async { // todo async kann hier weggelassen werden
    return showDialog<UserEntity>(
      context: context,
      barrierDismissible: false, // wird nicht geschlossen, wenn man außerhalb des Dialoges klickt
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag teilen'),
        content: available.isEmpty
            ? const Text('Keine weiteren Kontakte verfügbar.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: available.length,
                  separatorBuilder: (ctx, i) => const Divider(),
                  itemBuilder: (ctx, index) {
                    final user = available[index];

                    // Icon zusammenbauen (Avatar + Warn-Badge bei fehlender Verifizierung)
                    Widget leadingIcon = Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 20)),
                        if (!user.isVerified) const Icon(Icons.warning, size: 16, color: Colors.amber),
                      ],
                    );

                    // Tooltip hinzufügen, falls nicht verifiziert
                    if (!user.isVerified) {
                      leadingIcon = Tooltip(
                        message: 'Person ist nicht verifiziert!',
                        child: leadingIcon,
                      );
                    }

                    return ListTile(
                      leading: leadingIcon,
                      title: Text(user.name),
                      onTap: () => Navigator.of(ctx).pop(user),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            child: const Text('Abbrechen'),
            onPressed: () => Navigator.of(ctx).pop(null),
          ),
        ],
      ),
    );
  }
}
