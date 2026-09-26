<?php
if (!isset($conexion) || !($conexion instanceof mysqli)) {
    require_once __DIR__ . "/conexion.php";
}

/*
 * Dorada Motors - estructura simplificada.
 * La base principal usa solo 13 tablas.
 * Este archivo únicamente mantiene compatibilidad de columnas antiguas.
 */

function columnaExiste(mysqli $conexion, string $tabla, string $columna): bool {
    $tablaSegura = preg_replace('/[^A-Za-z0-9_]/', '', $tabla);
    $columnaSegura = $conexion->real_escape_string($columna);
    $r = $conexion->query("SHOW COLUMNS FROM `$tablaSegura` LIKE '$columnaSegura'");
    return $r && $r->num_rows > 0;
}

if (!columnaExiste($conexion, "producto", "stock_minimo")) {
    $conexion->query("ALTER TABLE producto ADD COLUMN stock_minimo INT NOT NULL DEFAULT 5");
}

if (!columnaExiste($conexion, "usuario", "estado")) {
    $conexion->query("ALTER TABLE usuario ADD COLUMN estado VARCHAR(20) NOT NULL DEFAULT 'Activo'");
}

if (!columnaExiste($conexion, "pedido", "id_direccion")) {
    $conexion->query("ALTER TABLE pedido ADD COLUMN id_direccion INT NULL");
}

if (!columnaExiste($conexion, "pedido", "tipo_entrega")) {
    $conexion->query("ALTER TABLE pedido ADD COLUMN tipo_entrega VARCHAR(30) NOT NULL DEFAULT 'Recojo en tienda'");
}

if (!columnaExiste($conexion, "movimiento_stock", "stock_anterior")) {
    $conexion->query("ALTER TABLE movimiento_stock ADD COLUMN stock_anterior INT NULL");
}

if (!columnaExiste($conexion, "movimiento_stock", "stock_nuevo")) {
    $conexion->query("ALTER TABLE movimiento_stock ADD COLUMN stock_nuevo INT NULL");
}

$columnasDetalle = [];
$resColumnas = $conexion->query("SHOW COLUMNS FROM detalle_pedido");
if ($resColumnas) {
    while ($col = $resColumnas->fetch_assoc()) {
        $columnasDetalle[$col["Field"]] = true;
    }
}

if (!isset($columnasDetalle["precio_unitario"])) {
    $conexion->query("ALTER TABLE detalle_pedido ADD COLUMN precio_unitario DECIMAL(10,2) NOT NULL DEFAULT 0");
    if (isset($columnasDetalle["precio"])) {
        $conexion->query("UPDATE detalle_pedido SET precio_unitario=precio WHERE precio_unitario=0");
    }
}

if (!isset($columnasDetalle["subtotal"])) {
    $conexion->query("ALTER TABLE detalle_pedido ADD COLUMN subtotal DECIMAL(10,2) NOT NULL DEFAULT 0");
}

$conexion->query("UPDATE detalle_pedido SET subtotal=cantidad*precio_unitario WHERE subtotal=0");
