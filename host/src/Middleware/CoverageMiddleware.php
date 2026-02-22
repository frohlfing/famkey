<?php
declare(strict_types=1);

namespace App\Middleware;

use App\Core\MiddlewareInterface;
use App\Core\Request;
use App\Core\Response;
use DOMDocument;
use SimpleXMLElement;

/**
 * Code-Coverage-Aufzeichnung
 *
 * Diese Middleware zeichnet Code-Coverage auf, wenn der Debug-Mode aktiviert (`DEBUG=true`) und `X-Coverage` im
 * Request-Header gesetzt ist.
 *
 * Storage:
 * - `/coverage/data.json` (kumuliert pro Datei/Zeile)
 * - `/coverage/clover.xml` (für IDE-Integration)
 */
final class CoverageMiddleware implements MiddlewareInterface
{
    /** @inheritDoc */
    public function process(Request $request, callable $next): Response
    {
        if (!$this->shouldStartCoverage($request)) {
            return $next($request);
        }

        // Aufzeichnung starten
        xdebug_start_code_coverage(XDEBUG_CC_UNUSED | XDEBUG_CC_DEAD_CODE);

        try {
            return $next($request);
        } finally {
            // Aufzeichnung beenden
            $coverage = xdebug_get_code_coverage();
            xdebug_stop_code_coverage();

            // Aufzeichnung speichern
            if ($coverage) {
                $this->persistCoverage($coverage);
            }
        }
    }

    /**
     * Entscheidet, ob Coverage gestartet werden soll.
     *
     * @param Request $request
     * @return bool
     */
    private function shouldStartCoverage(Request $request): bool
    {
        if (DEBUG !== true) {
            return false;
        }

        if (!function_exists('xdebug_start_code_coverage') || !function_exists('xdebug_get_code_coverage')) {
            return false;
        }

        // Aktivierung per Header "X-Coverage"
        $hdr = $request->header('X-Coverage');
        return $hdr !== null;
    }

    /**
     * Persistiert Coverage-Daten (data.json + clover.xml).
     *
     * @param array<string,array<int,int>> $coverage
     */
    private function persistCoverage(array $coverage): void
    {
         // Coverage-Verzeichnis erstellen, falls nicht vorhanden
        $projectRoot = realpath(__DIR__ . '/../..');
        $dir = $projectRoot . DIRECTORY_SEPARATOR . 'coverage';
        if (!is_dir($dir)) {
            mkdir($dir, 0777, true);
        }

        // data.json kumulieren
        $dataFile = $dir . DIRECTORY_SEPARATOR . 'data.json';
        $data = file_exists($dataFile) ? json_decode(file_get_contents($dataFile), true) : [];
        $root = realpath($projectRoot);
        foreach ($coverage as $file => $lines) {
            $realFile = realpath($file);
            if ($realFile === false || $root === false || !str_starts_with($realFile, $root . DIRECTORY_SEPARATOR)) {
                continue; // keine Projektdatei
            }
            foreach ($lines as $line => $hit) {
                if ($hit === -2) {
                    continue; // Zeile ist nicht ausführbar
                }
                if (!isset($data[$realFile])) {
                    $data[$realFile] = [];
                }
                if (!isset($data[$realFile][$line])) {
                    $data[$realFile][$line] = 0;  // nicht ausgeführt
                }
                if ($hit > 0) {
                    $data[$realFile][$line] += $hit; // Zeile ausgeführt
                }
            }
        }
        file_put_contents($dataFile, json_encode($data, JSON_UNESCAPED_SLASHES), LOCK_EX);

        // Clover-XML-Datei für die IDE erstellen bzw. aktualisieren
        $xml = new SimpleXMLElement('<?xml version="1.0" encoding="UTF-8"?><coverage></coverage>');
        $xml->addAttribute('generated', (string)time());
        $project = $xml->addChild('project');
        $project->addAttribute('timestamp', (string)time());
        $project->addAttribute('name', 'Integration Coverage');
        foreach ($data as $file => $lines) {
            $fileNode = $project->addChild('file');
            $fileNode->addAttribute('name', str_replace('\\', '/', (string)$file));
            foreach ($lines as $line => $hit) {
                $lineNode = $fileNode->addChild('line');
                $lineNode->addAttribute('num', (string)$line);
                $lineNode->addAttribute('count', (string)max(0, (int)$hit));
                $lineNode->addAttribute('type', 'stmt');
            }
        }

        $xmlString = $xml->asXML();
        if ($xmlString !== false) {
            $dom = new DOMDocument('1.0', 'UTF-8');
            $dom->preserveWhiteSpace = false;
            $dom->formatOutput = true;
            $dom->loadXML($xmlString);
            file_put_contents($dir . DIRECTORY_SEPARATOR . 'clover.xml', $dom->saveXML(), LOCK_EX);
        }
    }
}