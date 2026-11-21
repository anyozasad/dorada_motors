<?php
declare(strict_types=1);

// Verificación real de PHP + MySQL usada por el APK al elegir servidor.
// No expone contraseñas, datos de clientes ni credenciales internas.
require_once __DIR__ . "/conexion.php";
header("Content-Type: application/json; charset=UTF-8");
header("Cache-Control: no-store");

if (($_SERVER["REQUEST_METHOD"] ?? "GET") !== "GET") {
    http_response_code(405);
    echo json_encode(["estado"=>false, "mensaje"=>"Método no permitido"], JSON_UNESCAPED_UNICODE);
    exit;
}

$tablasNecesarias = [
    "usuario", "direccion", "producto", "pedido", "detalle_pedido",
    "pago", "carrito", "detalle_carrito", "favorito", "solicitud_soporte"
];

try {
    $consulta = $conexion->query(
        "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE()"
    );
    if (!$consulta) {
        throw new RuntimeException("No se pudo consultar la estructura de MySQL");
    }
    $existentes = [];
    while ($fila = $consulta->fetch_assoc()) {
        $existentes[(string)$fila["TABLE_NAME"]] = true;
    }
    $faltantes = array_values(array_filter(
        $tablasNecesarias,
        static fn(string $tabla): bool => !isset($existentes[$tabla])
    ));
    if ($faltantes) {
        http_response_code(503);
        echo json_encode([
            "estado"=>false,
            "api"=>"dorada_motors",
            "mensaje"=>"La base de datos del sistema no está completa."
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }

    echo json_encode([
        "estado"=>true,
        "api"=>"dorada_motors",
        "mensaje"=>"Conexión PHP/MySQL verificada.",
        "tablas_verificadas"=>count($tablasNecesarias)
    ], JSON_UNESCAPED_UNICODE);
} catch (Throwable $e) {
    error_log("Dorada Motors comprobar conexión: ".$e->getMessage());
    http_response_code(503);
    echo json_encode([
        "estado"=>false,
        "api"=>"dorada_motors",
        "mensaje"=>"No se puede comprobar la base de datos. Revisa XAMPP y MySQL."
    ], JSON_UNESCAPED_UNICODE);
}
