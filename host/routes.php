<?php
declare(strict_types=1);

use App\Controller\AttachmentController;
use App\Controller\SyncController;
use App\Controller\VaultController;
use App\Controller\UserController;
use App\Controller\VersionController;
use App\Core\Router;

/** @noinspection PhpRedundantOptionalArgumentInspection */

/**
 * routes.php
 *
 * Zweck:
 * - Zentrale Registrierung aller API-Routen gemäß API-Spezifikation.
 * - Single Source of Truth für:
 *   - HTTP-Verb
 *   - Pfad
 *   - Handler
 *   - RSA-Schutz (Identity Proof)
 *
 * RSA-Schutz (protected) bedeutet:
 * - Die Route erfordert die RSA-Signatur-Header (X-User-Uuid, X-Timestamp, X-Signature)
 * - Die Prüfung erfolgt über AuthMiddleware anhand des Route-Flags (nicht via hardcodierter Pfad-Liste).
 *
 * @param Router $router Der Router der Applikation.
 */
function registerRoutes(Router $router): void
{
    // --- Resource version ---

    $router->get('/version', [VersionController::class, 'version'], protected: false);

    // --- Resource User ---

    // Liefert die Benutzerdaten anhand seiner UUID.
    $router->get('/users/{user_uuid}', [UserController::class, 'getUser'], protected: false);

    // Sucht einen Benutzer im Tresor anhand seines Namens-Hashes.
    $router->get('/users', [UserController::class, 'findUser'], protected: false);

    // Registriert einen neuen Benutzer im Tresor.
    $router->post('/users', [UserController::class, 'register'], protected: false);

    // Aktualisiert Salt und Private Key nach Änderung des Master-Passworts.
    $router->put('/users/{user_uuid}/password', [UserController::class, 'changePassword'], protected: true);

    // Aktualisiert Salt und Private Key nach Änderung des Master-Passworts.
    $router->put('/users/{user_uuid}/password', [UserController::class, 'changePassword'], protected: true);

    // Speichert die verschlüsselte Freundesliste des Benutzers.
    $router->put('/users/{user_uuid}/friends', [UserController::class, 'saveFriends'], protected: true);

    // Liefert die öffentlichen RSA-Schlüssel aller Benutzer im Tresor.
    $router->get('/users/{user_uuid}/public_keys', [UserController::class, 'getPublicKeys'], protected: true);

    // --- Bulk-Aktion Sync ---

    // Liefert alle neuen / geänderten Einträge und die UUIDs verknüpfter Anhänge.
    $router->get('/users/{user_uuid}/entries/sync', [SyncController::class, 'pullSync'], protected: true);

    // Übernimmt Änderungen und Löschungen. Der Server nutzt „Last-Write-Wins“.
    $router->post('/users/{user_uuid}/entries/sync', [SyncController::class, 'pushSync'], protected: true);

    // --- Resource Attachment ---

    // Lädt die verschlüsselten Metadaten und den Inhalt eines Anhangs.
    $router->get('/attachments/{attachment_uuid}', [AttachmentController::class, 'getAttachment'], protected: true);

    // Speichert einen neuen Anhang (Metadaten & Inhalt) auf dem Server.
    $router->put('/attachments/{attachment_uuid}', [AttachmentController::class, 'createAttachment'], protected: true);

    // --- Resource Vault ---

    // Löscht einen Test-Tresor und bereinigt veraltete Test-Tresore.
    $router->delete('/vaults', [VaultController::class, 'deleteTestVaultIfExists'], protected: false);
}