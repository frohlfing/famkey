<?php

require_once __DIR__ . '/../../config.php';

header('Location: ../api/version?api_token=' . API_TOKEN);

exit;
