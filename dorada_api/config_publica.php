<?php
declare(strict_types=1);
require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/empresa_config.php";

header("Content-Type: application/json; charset=UTF-8");
header("Cache-Control: no-store");
header("X-Content-Type-Options: nosniff");

if (($_SERVER["REQUEST_METHOD"] ?? "") !== "GET") {
    http_response_code(405);
    echo json_encode([
        "estado" => false,
        "mensaje" => "Método no permitido"
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

$config = cargarConfigEmpresa();
echo json_encode([
    "estado" => true,
    "costo_delivery" => round(max(0, (float)($config["costo_delivery"] ?? 0)), 2),
    "moneda" => (string)($config["moneda"] ?? "S/")
], JSON_UNESCAPED_UNICODE);
