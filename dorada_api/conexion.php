<?php

header("Content-Type: application/json; charset=UTF-8");

$origen = $_SERVER["HTTP_ORIGIN"] ?? "";
$origenesPermitidos = array_filter(array_map(
    "trim",
    explode(",", getenv("APP_ORIGINS") ?: "http://localhost:8080,http://127.0.0.1:8080")
));

if ($origen !== "" && in_array($origen, $origenesPermitidos, true)) {
    header("Access-Control-Allow-Origin: " . $origen);
    header("Vary: Origin");
}

header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");

if ($_SERVER["REQUEST_METHOD"] === "OPTIONS") {
    http_response_code(204);
    exit;
}

$dbHost = getenv("DB_HOST") ?: "localhost";
$dbUser = getenv("DB_USER") ?: "root";
$dbPass = getenv("DB_PASS") ?: "";
$dbName = getenv("DB_NAME") ?: "dorada_motors";
$dbPort = (int)(getenv("DB_PORT") ?: 3306);

$conexion = new mysqli(
    $dbHost,
    $dbUser,
    $dbPass,
    $dbName,
    $dbPort
);

if ($conexion->connect_error) {
    error_log("Dorada Motors DB: " . $conexion->connect_error);
    http_response_code(500);

    echo json_encode([
        "estado" => false,
        "mensaje" => "No se pudo conectar con la base de datos"
    ], JSON_UNESCAPED_UNICODE);

    exit;
}

$conexion->set_charset("utf8mb4");
