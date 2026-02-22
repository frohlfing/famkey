<?php
// Datenbank Zugangsdaten
const DB_HOST = 'localhost';
const DB_NAME = 'privault';
const DB_USER = 'root';
const DB_PASS = '';
const DB_SSLCA = null; // SSL-Zertifikat für die DB, z.B. __DIR__ . '/sqlca.pem'

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