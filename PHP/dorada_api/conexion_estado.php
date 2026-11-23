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
    // Coincide con el esquema SQL del proyecto completo: el diagnóstico
    // anterior revisaba solo 9 tablas y podía dar un OK falso.
    "usuario" => ["id_usuario","nombres","apellidos","correo","contrasena","telefono","estado","rol_sistema","ultimo_acceso"],
    "direccion" => ["id_direccion","id_usuario","departamento","provincia","distrito","direccion_detalle","referencia"],
    "categoria" => ["id_categoria","nombre_categoria"],
    "marca" => ["id_marca","nombre_marca"],
    "producto" => ["id_producto","id_categoria","id_marca","nombre_producto","descripcion","tipo_vehiculo","compatibilidad","precio","precio_oferta","stock","stock_minimo","imagen_url"],
    "pedido" => ["id_pedido","id_usuario","clave_operacion","fecha_pedido","estado_pedido","total","id_direccion","tipo_entrega"],
    "detalle_pedido" => ["id_detalle","id_pedido","id_producto","cantidad","precio_unitario","subtotal"],
    "pago" => ["id_pago","id_pedido","metodo_pago","monto","fecha_pago","estado_pago","referencia_cliente","fecha_referencia"],
    "proveedor" => ["id_proveedor","razon_social","ruc","telefono","correo","direccion","estado"],
    "compra" => ["id_compra","id_proveedor","fecha_compra","total","estado"],
    "detalle_compra" => ["id_detalle_compra","id_compra","id_producto","cantidad","precio_compra","subtotal"],
    "movimiento_stock" => ["id_movimiento","id_producto","tipo_movimiento","cantidad","motivo","fecha_movimiento","stock_anterior","stock_nuevo"],
    "comprobante" => ["id_comprobante","id_pedido","tipo_comprobante","numero_comprobante","fecha_emision","subtotal","igv","total"],
    "sesion_cliente" => ["token_hash","id_usuario","fecha_creacion","fecha_expiracion"],
    "carrito" => ["id_carrito","id_usuario","estado","fecha_creacion"],
    "detalle_carrito" => ["id_detalle_carrito","id_carrito","id_producto","cantidad"],
    "favorito" => ["id_favorito","id_usuario","id_producto","fecha_registro"],
    "solicitud_soporte" => ["id_solicitud","id_usuario","asunto","mensaje","estado","respuesta","fecha_creacion","fecha_actualizacion"],
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
