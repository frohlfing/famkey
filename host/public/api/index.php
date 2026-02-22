<?php
declare(strict_types=1);

# Front-Controller

use App\Core\Application;
use App\Core\Request;

require_once __DIR__ . '/../../src/Core/Application.php';

/** @noinspection PhpUnhandledExceptionInspection */
$app = Application::create();

$request = Request::fromGlobals();
$response = $app->handle($request);
$response->send();
