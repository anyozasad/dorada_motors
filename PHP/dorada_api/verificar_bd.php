<?php
require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/sistema_bootstrap.php";
header("Content-Type: application/json; charset=UTF-8");
require_once __DIR__ . "/auth_admin.php";
if (!adminActual() || rolActual() !== "Administrador") {
    http_response_code(403);
    echo json_encode(["estado"=>false,"mensaje"=>"Acceso administrativo requerido"], JSON_UNESCAPED_UNICODE);
    exit;
}

$resultado = [
    "estado" => false,
    "conexion_mysql" => false,
    "base_datos" => "",
    "tablas_encontradas" => 0,
    "tablas_requeridas" => 18,
    "columnas_producto" => 0,
    "columnas_producto_requeridas" => 4,
    "columnas_usuario" => 0,
    "columnas_usuario_requeridas" => 2,
    "escritura" => false,
    "columnas_criticas_verificadas" => 0,
    "columnas_faltantes" => [],
    "mensaje" => ""
];

try {
    $resultado["conexion_mysql"] = true;

    $bd = $conexion->query("SELECT DATABASE() AS bd");
    $resultado["base_datos"] = $bd ? (string)($bd->fetch_assoc()["bd"] ?? "") : "";

    $tablas = [
        "usuario","direccion","categoria","marca","producto",
        "pedido","detalle_pedido","pago","proveedor","compra",
        "detalle_compra","movimiento_stock","comprobante","sesion_cliente","carrito","detalle_carrito","favorito","solicitud_soporte"
    ];

    $encontradas = 0;
    foreach ($tablas as $tabla) {
        $tablaSegura = $conexion->real_escape_string($tabla);
        $r = $conexion->query("SHOW TABLES LIKE '" . $tablaSegura . "'");
        if ($r && $r->num_rows > 0) {
            $encontradas++;
        }
    }
    $resultado["tablas_encontradas"] = $encontradas;

    $columnasProducto = [
        "stock_minimo","tipo_vehiculo","compatibilidad","precio_oferta"
    ];
    $columnasEncontradas = 0;
    foreach ($columnasProducto as $columna) {
        $columnaSegura = $conexion->real_escape_string($columna);
        $r = $conexion->query("SHOW COLUMNS FROM producto LIKE '" . $columnaSegura . "'");
        if ($r && $r->num_rows > 0) {
            $columnasEncontradas++;
        }
    }
    $resultado["columnas_producto"] = $columnasEncontradas;

    $columnasUsuario = ["rol_sistema","ultimo_acceso"];
    $columnasUsuarioEncontradas = 0;
    foreach ($columnasUsuario as $columna) {
        $columnaSegura = $conexion->real_escape_string($columna);
        $r = $conexion->query("SHOW COLUMNS FROM usuario LIKE '" . $columnaSegura . "'");
        if ($r && $r->num_rows > 0) {
            $columnasUsuarioEncontradas++;
        }
    }
    $resultado["columnas_usuario"] = $columnasUsuarioEncontradas;

    // Un dashboard puede mostrar 18 tablas y aún fallar por columnas
    // faltantes en una instalación antigua. Informar qué reparación falta.
    $criticas = [
        "usuario" => ["id_usuario","nombres","apellidos","correo","contrasena",
            "telefono","estado","rol_sistema"],
        "producto" => ["id_producto","id_categoria","id_marca","nombre_producto",
            "precio","precio_oferta","stock","stock_minimo","imagen_url"],
        "pedido" => ["id_pedido","id_usuario","fecha_pedido","estado_pedido",
            "total","tipo_entrega"],
        "detalle_pedido" => ["id_detalle","id_pedido","id_producto",
            "cantidad","precio_unitario","subtotal"],
        "pago" => ["id_pago","id_pedido","metodo_pago","monto","estado_pago"],
        "proveedor" => ["id_proveedor","razon_social","estado"],
        "compra" => ["id_compra","id_proveedor","total","estado"],
        "detalle_compra" => ["id_compra","id_producto","cantidad","precio_compra","subtotal"],
        "movimiento_stock" => ["id_movimiento","id_producto","cantidad",
            "stock_anterior","stock_nuevo"],
        "comprobante" => ["id_comprobante","id_pedido","tipo_comprobante",
            "numero_comprobante","subtotal","igv","total"],
    ];
    $resultado["columnas_criticas_verificadas"] = array_sum(
        array_map("count", $criticas)
    );
    $columnasExistentes = [];
    $columnasSQL = $conexion->query(
        "SELECT TABLE_NAME,COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS " .
        "WHERE TABLE_SCHEMA=DATABASE()"
    );
    if (!$columnasSQL) {
        throw new RuntimeException("No se pudo consultar el esquema de MySQL.");
    }
    while ($filaCol = $columnasSQL->fetch_assoc()) {
        $columnasExistentes[$filaCol["TABLE_NAME"]][$filaCol["COLUMN_NAME"]] = true;
    }
    foreach ($criticas as $tabla => $nombres) {
        foreach ($nombres as $nombre) {
            if (!isset($columnasExistentes[$tabla][$nombre])) {
                $resultado["columnas_faltantes"][] = "$tabla.$nombre";
            }
        }
    }

    // Prueba real de escritura SIN dejar datos:
    // se inserta una categoría temporal dentro de una transacción y luego se revierte.
    $conexion->begin_transaction();

    $nombrePrueba = "__PRUEBA_CONEXION_" . date("YmdHis") . "__";
    $stmt = $conexion->prepare("INSERT INTO categoria (nombre_categoria) VALUES (?)");
    if (!$stmt) {
        throw new RuntimeException("No se pudo preparar una escritura de prueba.");
    }

    $stmt->bind_param("s", $nombrePrueba);
    if (!$stmt->execute()) {
        throw new RuntimeException("MySQL rechazó la escritura de prueba.");
    }

    $resultado["escritura"] = true;
    $conexion->rollback();

    $resultado["estado"] =
        $resultado["conexion_mysql"] &&
        $resultado["base_datos"] === (getenv("DB_NAME") ?: "dorada_motors") &&
        $resultado["tablas_encontradas"] === 18 &&
        $resultado["columnas_producto"] === 4 &&
        $resultado["columnas_usuario"] === 2 &&
        count($resultado["columnas_faltantes"]) === 0 &&
        $resultado["escritura"];

    $resultado["mensaje"] = $resultado["estado"]
        ? "Conexión correcta: PHP puede leer y guardar datos sin pérdida en MySQL."
        : "La conexión existe, pero falta completar tablas o columnas de la base de datos.";

} catch (Throwable $e) {
    if ($conexion instanceof mysqli) {
        @$conexion->rollback();
    }

    $resultado["mensaje"] = "Error de verificación: " . $e->getMessage();
}

if (!$resultado["estado"]) {
    http_response_code(503);
}
echo json_encode($resultado, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
