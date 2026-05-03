-- Database Name: famkey
-- Server connection collation: utf8mb4_unicode_ci

-- Tabelle für Organisationen (repräsentiert eine Familie/Verein/Arbeitsgruppe)
CREATE TABLE `organizations` (
    `uuid` CHAR(36) NOT NULL,                       -- Universally Unique Identifier der Organisation
    `name` VARCHAR(255) NOT NULL,                   -- Name der Organisation, eindeutig pro Server
    `api_token` VARCHAR(36) NOT NULL,               -- API-Token der Organisation (UUID v4)
    `blocked_at` DATETIME(3) DEFAULT NULL,          -- Zeitpunkt, seitdem die Organisation deaktiviert wurde
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3), -- Zeitpunkt der Erstellung
    PRIMARY KEY (`uuid`),
    UNIQUE KEY `uk_organizations_name` (`name`),
    UNIQUE KEY `uk_organizations_api_token` (`api_token`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabelle für die Tresore
-- Mappt den Hash (vom Client) auf eine interne ID
CREATE TABLE `vaults` (
    `uuid` VARCHAR(36),                              -- Universally Unique Identifier des Tresors
    `org_uuid`  VARCHAR(36) DEFAULT NULL,            -- Referenz auf organizations.uuid, NULL -> Single-Tenant-Betrieb (MULTI_TENANT = false in config.php)
    `hash_name`  VARCHAR(64) NOT NULL,               -- Name des Tresor (SHA256-Hash), eindeutig pro Server
    `is_test` TINYINT(1) NOT NULL DEFAULT 0,         -- 1 = Test-Tresor
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3), -- Zeitpunkt der Erstellung
    PRIMARY KEY (`uuid`),
    UNIQUE KEY `uk_vaults_org_uuid_hash_name` (`org_uuid`, `hash_name`),
    INDEX `idx_vaults_is_test_created_at` (`is_test`, `created_at`),
    FOREIGN KEY (`org_uuid`) REFERENCES `organizations`(`uuid`) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- Tabelle für die Benutzer
CREATE TABLE `users` (
    `uuid` VARCHAR(36),                              -- Universally Unique Identifier des Benutzers
    `vault_uuid` VARCHAR(36) NOT NULL,               -- Referenz auf vaults.uuid
    `hash_name` VARCHAR(64) NOT NULL,                -- Benutzername (SHA256-Hash), eindeutig pro Tresor
    `salt` TEXT NOT NULL,                            -- Salt des Benutzers (Base64)
    `public_key` TEXT NOT NULL,                      -- RSA Public Key (Base64)
    `encrypted_private_key` TEXT NOT NULL,           -- RSA Private Key (AES verschlüsselt)
    `master_key_timestamp` DATETIME(3) NOT NULL,     -- Zeitstempel des Master-Keys
    `encrypted_friends` LONGTEXT DEFAULT NULL,       -- Freundesliste des Benutzers (AES verschlüsselt)
    PRIMARY KEY (`uuid`),
    UNIQUE KEY `uk_users_vault_uuid_hash_name` (`vault_uuid`, `hash_name`),
    FOREIGN KEY (`vault_uuid`) REFERENCES `vaults`(`uuid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabelle für Einträge (Payload)
--
-- entry_uuid ist nur innerhalb eines Tresors eindeutig. Dieselbe entry_uuid kann in
-- mehreren Tresoren vorkommen (z.B. nach einem Backup-Import in einen anderen Tresor).
-- Daher ist der Primärschlüssel ein Composite aus (uuid, vault_uuid).
-- Alle Queries filtern grundsätzlich auf (uuid, vault_uuid).
CREATE TABLE `entries` (
    `uuid` VARCHAR(36) NOT NULL,                     -- Universally Unique Identifier des Eintrags (nur innerhalb eines Tresors eindeutig)
    `vault_uuid` VARCHAR(36) NOT NULL,               -- Referenz auf vaults.uuid
    `encrypted_data` LONGTEXT,                       -- Daten zum Eintrag (AES verschlüsselt)
    `creator_uuid` VARCHAR(36) NOT NULL,             -- UUID des Benutzers, der den Eintrag erstellt hat
    `updater_uuid` VARCHAR(36) NOT NULL,             -- UUID des Benutzers, der den Eintrag zuletzt aktualisiert hat
    `updated_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3), -- Zeitpunkt der letzten Änderung
    PRIMARY KEY (`uuid`, `vault_uuid`),                                                    -- Composite PK: uuid eindeutig pro Tresor
    INDEX `idx_entries_vault_uuid_updated_at` (`vault_uuid`, `updated_at`),               -- für pullSync
    INDEX `idx_entries_updater_uuid_updated_at` (`updater_uuid`, `updated_at`),           -- für Rate-Limiting-Abfrage
    FOREIGN KEY (`vault_uuid`) REFERENCES `vaults`(`uuid`) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- Tabelle für Berechtigungen (Wer darf was lesen?)
CREATE TABLE `permissions` (
    `entry_uuid` VARCHAR(36) NOT NULL,               -- Referenz auf entries.uuid
    `user_uuid` VARCHAR(36) NOT NULL,                -- Referenz auf users.uuid
    `vault_uuid` VARCHAR(36) NOT NULL,               -- Referenz auf vaults.uuid
    `encrypted_key` TEXT NOT NULL,                   -- AES Entry Key (RSA verschlüsselt)
    `access_level` INT NOT NULL DEFAULT 0,           -- 0=Kein Recht, 1=Lesen, 2=Lesen/Schreiben, 3=Vollzugriff
    PRIMARY KEY (`entry_uuid`, `user_uuid`, `vault_uuid`),                                        -- für pushSync
    UNIQUE KEY `uk_permissions_user_uuid_entry_uuid` (`user_uuid`, `entry_uuid`, `vault_uuid`),   -- für pullSync
    FOREIGN KEY (`entry_uuid`, `vault_uuid`) REFERENCES `entries`(`uuid`, `vault_uuid`) ON DELETE CASCADE,
    FOREIGN KEY (`user_uuid`) REFERENCES `users`(`uuid`) ON DELETE CASCADE,
    FOREIGN KEY (`vault_uuid`) REFERENCES `vaults`(`uuid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. Tabelle für Anhänge
CREATE TABLE `attachments` (
   `uuid` VARCHAR(36),                              -- Universally Unique Identifier des Anhangs
   `entry_uuid` VARCHAR(36) NOT NULL,               -- Referenz auf entries.uuid
   `vault_uuid` VARCHAR(36) NOT NULL,               -- Referenz auf vaults.uuid
   `encrypted_meta` MEDIUMBLOB NOT NULL,            -- Meta-Daten (AES verschlüsselt)
   `encrypted_content` LONGBLOB NOT NULL,           -- Dateiinhalt (AES verschlüsselt, max 4GB)
   PRIMARY KEY (`uuid`),
   INDEX `idx_attachments_entry_uuid` (`entry_uuid`),
   FOREIGN KEY (`entry_uuid`, `vault_uuid`) REFERENCES `entries`(`uuid`, `vault_uuid`) ON DELETE CASCADE,
   FOREIGN KEY (`vault_uuid`) REFERENCES `vaults`(`uuid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabelle für Grabsteine (gelöschte Einträge)
--
-- Composite PK (entry_uuid, vault_uuid), weil dieselbe entry_uuid in zwei Tresoren
-- unabhängig voneinander gelöscht werden kann.
CREATE TABLE `tombstones` (
    `entry_uuid` VARCHAR(36) NOT NULL,               -- UUID des gelöschten Eintrags (nur innerhalb eines Tresors eindeutig)
    `vault_uuid` VARCHAR(36) NOT NULL,               -- Referenz auf vaults.uuid
    `deleted_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3), -- Zeitpunkt der Löschung
    PRIMARY KEY (`entry_uuid`, `vault_uuid`),
    INDEX `idx_tombstones_vault_uuid_deleted_at` (`vault_uuid`, `deleted_at`),
    FOREIGN KEY (`vault_uuid`) REFERENCES `vaults`(`uuid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabelle zur Speicherung der Datenbankschema-Version
CREATE TABLE `version` (
    schema_version INT NOT NULL,                     -- wird erhöht bei Schema-Änderungen
    `updated_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)
);

-- Initialen Versionsstand setzen
INSERT INTO `version` (`schema_version`) VALUES (1);