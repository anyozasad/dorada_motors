<?php

header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");

if ($_SERVER["REQUEST_METHOD"] === "OPTIONS") {
    http_response_code(200);
    exit;
}

$conexion = new mysqli(
    "localhost",
    "root",
    "",
    "dorada_motors"
);

if ($conexion->connect_error) {

    echo json_encode([
        "estado" => false,
        "mensaje" => "Error de conexión",
        "error" => $conexion->connect_error
    ]);

    exit;
}

$conexion->set_charset("utf8mb4");
