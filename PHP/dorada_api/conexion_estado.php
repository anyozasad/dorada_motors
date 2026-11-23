<?php
declare(strict_types=1);

// Verificación real de PHP + MySQL usada por el APK al elegir servidor.
// No expone contraseñas, datos de clientes ni credenciales internas.
require_once __DIR__ . "/conexion.php";
try {
    require_once __DIR__ . "/sistema_bootstrap.php";
} catch (Throwable $e) {
    error_log("Dorada Motors: esquema MySQL incompatible: " . $e->getMessage());
    http_response_code(503);
    echo json_encode(["estado"=>false, "api"=>"dorada_motors",
        "mensaje"=>"La conexión existe, pero faltan columnas o permisos para actualizar la base."],
        JSON_UNESCAPED_UNICODE);
    exit;
}
header("Content-Type: application/json; charset=UTF-8");
header("Cache-Control: no-store");

if (($_SERVER["REQUEST_METHOD"] ?? "GET") !== "GET") {
    http_response_code(405);
    echo json_encode(["estado"=>false, "mensaje"=>"Método no permitido"], JSON_UNESCAPED_UNICODE);
    exit;
}

$tablasNecesarias = [
    "usuario", "direccion", "categoria", "marca", "producto", "pedido",
    "detalle_pedido", "pago", "proveedor", "compra", "detalle_compra",
    "movimiento_stock", "comprobante", "sesion_cliente", "carrito",
    "detalle_carrito", "favorito", "solicitud_soporte"
];

$columnasNecesarias = [
    "usuario" => ["id_usuario","nombres","apellidos","correo","contrasena","estado","rol_sistema"],
    "producto" => ["id_producto","id_categoria","id_marca","nombre_producto","precio","precio_oferta","stock","stock_minimo","imagen_url"],
    "pedido" => ["id_pedido","id_usuario","fecha_pedido","estado_pedido","total","tipo_entrega"],
    "detalle_pedido" => ["id_detalle","id_pedido","id_producto","cantidad","precio_unitario","subtotal"],
    "pago" => ["id_pago","id_pedido","metodo_pago","monto","estado_pago"],
    "compra" => ["id_compra","id_proveedor","total","estado"],
    "detalle_compra" => ["id_compra","id_producto","cantidad","precio_compra","subtotal"],
    "movimiento_stock" => ["id_movimiento","id_producto","cantidad","stock_anterior","stock_nuevo"],
    "comprobante" => ["id_comprobante","id_pedido","tipo_comprobante","numero_comprobante","subtotal","igv","total"],
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
    $columnasReales = [];
    $cols = $conexion->query(
        "SELECT TABLE_NAME,COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS " .
        "WHERE TABLE_SCHEMA=DATABASE()"
    );
    if (!$cols) {
        throw new RuntimeException("No se pudo verificar las columnas de MySQL");
    }
    while ($col = $cols->fetch_assoc()) {
        $columnasReales[(string)$col["TABLE_NAME"]][(string)$col["COLUMN_NAME"]] = true;
    }
    $faltantesColumnas = [];
    foreach ($columnasNecesarias as $tabla => $columnas) {
        foreach ($columnas as $columna) {
            if (!isset($columnasReales[$tabla][$columna])) {
                $faltantesColumnas[] = "$tabla.$columna";
            }
        }
    }
    if ($faltantes || $faltantesColumnas) {
        http_response_code(503);
        echo json_encode([
            "estado"=>false,
            "api"=>"dorada_motors",
            "mensaje"=>"La base de datos necesita reparación de tablas o columnas."
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }

    echo json_encode([
        "estado"=>true,
        "api"=>"dorada_motors",
        "mensaje"=>"Conexión PHP/MySQL verificada.",
        "tablas_verificadas"=>count($tablasNecesarias),
        "columnas_verificadas"=>array_sum(array_map("count", $columnasNecesarias))
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
