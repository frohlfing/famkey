<?php
/** @noinspection PhpUnused */
/** @noinspection SpellCheckingInspection */

// Sync-Protokollversion
const SYNC_PROTOCOL_VERSION = 1;

// Kleinste unterstützte Protokollversion
const MIN_SYNC_PROTOCOL_VERSION = 1;

// Datenbankschema-Version (sollte identisch sein mit dem Wert aus der Tabelle `version`)
const DATABASE_SCHEMA_VERSION = 1;

// Datenbank
const DB_HOST = 'localhost';
const DB_NAME = 'famkey';
const DB_USER = 'root';
const DB_PASS = '';

// SSL-Zertifikat für die DB (siehe https://docs.hetzner.com/de/konsoleh/account-management/databases/mysql)
const DB_SSLCA = null; // __DIR__ . '/sqlca.pem';

// API-Tokens
const API_TOKEN = 'DEIN_API_TOKEN';

// Rate Limit (maximale Anzahl Einträge pro Minute; 0 == kein Limit)
const RATE_LIMIT = 200;

// Debug-Mode
const DEBUG = false;

// Logging ('DEBUG', 'INFO', 'WARN', 'ERROR')
const LOG_LEVEL = 'WARN';
const LOG_MAX_DAYS = 7;

// Maximal erlaubte Größe eines Anhangs (in Bytes)
const MAX_ATTACHMENT_BYTES = 25 * 1024 * 1024; // 25 MB

// Server-Modus: false = Single-Tenant (self-hosted, globaler API_TOKEN)
//               true  = Multi-Tenant (famkey.de, Organisationen per URL-Pfad)
const MULTI_TENANT = false;
