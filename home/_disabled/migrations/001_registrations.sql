-- Migration 003: Temporäre Registrierungsanfragen (E-Mail-Bestätigung)
--
-- Ablauf: Benutzer füllt Formular aus → confirm_token per E-Mail →
-- Klick bestätigt E-Mail → api_token wird in api_tokens eingetragen, Zeile wird gelöscht.
-- Abgelaufene Zeilen (expires_at in der Vergangenheit) werden bei jedem Confirm-Aufruf bereinigt.

CREATE TABLE `registrations` (
    `confirm_token` CHAR(64) NOT NULL,          -- bin2hex(random_bytes(32)), URL-sicher
    `email`         VARCHAR(255) NOT NULL,
    `family_name`   VARCHAR(255) DEFAULT NULL,  -- optional, nur zur Anzeige
    `expires_at`    DATETIME(3)  NOT NULL,       -- 1 Stunde Gültigkeit
    PRIMARY KEY (`confirm_token`),
    INDEX `idx_registrations_email`      (`email`),
    INDEX `idx_registrations_expires_at` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

UPDATE `version` SET `schema_version` = 3;
