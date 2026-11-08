<?php
require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/cliente_auth.php";

header("Content-Type: application/json; charset=UTF-8");
header("Cache-Control: no-store");

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);
    echo json_encode(["estado"=>false,"mensaje"=>"Método no permitido"], JSON_UNESCAPED_UNICODE);
    exit;
}

cerrarTokenCliente($conexion);
echo json_encode(["estado"=>true,"mensaje"=>"Sesión cerrada"], JSON_UNESCAPED_UNICODE);
