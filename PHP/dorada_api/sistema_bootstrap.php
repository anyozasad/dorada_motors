<?php
if (!isset($conexion) || !($conexion instanceof mysqli)) {
    require_once __DIR__ . "/conexion.php";
}

/*
 * Dorada Motors - estructura simplificada.
 * Las tablas de la aplicación y el panel se preparan desde dorada_motors.sql.
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

if (!columnaExiste($conexion, "producto", "tipo_vehiculo")) {
    $conexion->query("ALTER TABLE producto ADD COLUMN tipo_vehiculo VARCHAR(50) NOT NULL DEFAULT 'Motocicleta / Motokar'");
}

if (!columnaExiste($conexion, "producto", "compatibilidad")) {
    $conexion->query("ALTER TABLE producto ADD COLUMN compatibilidad VARCHAR(255) NOT NULL DEFAULT ''");
}

if (!columnaExiste($conexion, "producto", "precio_oferta")) {
    $conexion->query("ALTER TABLE producto ADD COLUMN precio_oferta DECIMAL(10,2) NULL");
}

if (!columnaExiste($conexion, "usuario", "estado")) {
    $conexion->query("ALTER TABLE usuario ADD COLUMN estado VARCHAR(20) NOT NULL DEFAULT 'Activo'");
}

if (!columnaExiste($conexion, "usuario", "rol_sistema")) {
    $conexion->query("ALTER TABLE usuario ADD COLUMN rol_sistema VARCHAR(20) NOT NULL DEFAULT 'Cliente'");
}

if (!columnaExiste($conexion, "usuario", "ultimo_acceso")) {
    $conexion->query("ALTER TABLE usuario ADD COLUMN ultimo_acceso DATETIME NULL");
}

if (!columnaExiste($conexion, "pedido", "id_direccion")) {
    $conexion->query("ALTER TABLE pedido ADD COLUMN id_direccion INT NULL");
}

if (!columnaExiste($conexion, "pedido", "tipo_entrega")) {
    $conexion->query("ALTER TABLE pedido ADD COLUMN tipo_entrega VARCHAR(30) NOT NULL DEFAULT 'Recojo en tienda'");
}

// Claves idempotentes para registros offline: una petición repetida después
// de recuperar Wi-Fi no debe crear dos direcciones o consultas de soporte.
foreach (["direccion", "solicitud_soporte"] as $tablaOffline) {
    if (!columnaExiste($conexion, $tablaOffline, "clave_operacion")) {
        $conexion->query(
            "ALTER TABLE `$tablaOffline` ADD COLUMN clave_operacion VARCHAR(64) NULL DEFAULT NULL"
        );
    }
    $indiceOffline = $conexion->query(
        "SHOW INDEX FROM `$tablaOffline` WHERE Key_name='uq_cliente_operacion'"
    );
    if ($indiceOffline && $indiceOffline->num_rows === 0) {
        $conexion->query(
            "ALTER TABLE `$tablaOffline` ADD UNIQUE KEY uq_cliente_operacion (id_usuario,clave_operacion)"
        );
    }
}

// Una sola compra por intento, incluso si Chrome pierde la respuesta de la API.
if (!columnaExiste($conexion, "pedido", "clave_operacion")) {
    $conexion->query("ALTER TABLE pedido ADD COLUMN clave_operacion VARCHAR(64) NULL DEFAULT NULL");
}
$indicePedido = $conexion->query(
    "SHOW INDEX FROM pedido WHERE Key_name='uq_pedido_cliente_operacion'"
);
if ($indicePedido && $indicePedido->num_rows === 0) {
    $conexion->query(
        "ALTER TABLE pedido ADD UNIQUE KEY uq_pedido_cliente_operacion (id_usuario,clave_operacion)"
    );
}

if (!columnaExiste($conexion, "pago", "referencia_cliente")) {
    $conexion->query("ALTER TABLE pago ADD COLUMN referencia_cliente VARCHAR(100) NULL DEFAULT NULL");
}
if (!columnaExiste($conexion, "pago", "fecha_referencia")) {
    $conexion->query("ALTER TABLE pago ADD COLUMN fecha_referencia DATETIME NULL");
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
    // Solo migrar una vez. No reescribir los detalles de cada venta en cada
    // visita al dashboard, ni modificar descuentos ya registrados.
    $conexion->query("UPDATE detalle_pedido SET subtotal=cantidad*precio_unitario WHERE subtotal=0");
}

/**
 * Compatibilidad no destructiva para bases antiguas de XAMPP. Únicamente
 * añade atributos opcionales que el dashboard y la API ya necesitan.
 * Nunca borra tablas/columnas, altera claves primarias ni inventa montos
 * históricos o contraseñas para cuentas existentes.
 *
 * Si una alteración falla, informar en lugar de fingir que se reparó MySQL.
 */
$columnasCompatibles = [
    "producto" => [
        "descripcion" => "TEXT NULL",
        "imagen_url" => "VARCHAR(255) NOT NULL DEFAULT ''",
        "stock_minimo" => "INT NOT NULL DEFAULT 5",
        "precio_oferta" => "DECIMAL(10,2) NULL",
        "tipo_vehiculo" => "VARCHAR(50) NOT NULL DEFAULT 'Motocicleta / Motokar'",
        "compatibilidad" => "VARCHAR(255) NOT NULL DEFAULT ''",
    ],
    "usuario" => [
        "apellidos" => "VARCHAR(120) NOT NULL DEFAULT ''",
        "telefono" => "VARCHAR(30) NOT NULL DEFAULT ''",
        "estado" => "VARCHAR(20) NOT NULL DEFAULT 'Activo'",
        "rol_sistema" => "VARCHAR(20) NOT NULL DEFAULT 'Cliente'",
        "ultimo_acceso" => "DATETIME NULL",
    ],
    "pedido" => [
        "id_direccion" => "INT NULL",
        "tipo_entrega" => "VARCHAR(30) NOT NULL DEFAULT 'Recojo en tienda'",
        "clave_operacion" => "VARCHAR(64) NULL DEFAULT NULL",
    ],
    "pago" => [
        "estado_pago" => "VARCHAR(30) NOT NULL DEFAULT 'Pendiente'",
        "referencia_cliente" => "VARCHAR(100) NULL DEFAULT NULL",
        "fecha_referencia" => "DATETIME NULL",
    ],
    "proveedor" => [
        "ruc" => "VARCHAR(20) NULL",
        "telefono" => "VARCHAR(30) NULL",
        "correo" => "VARCHAR(160) NULL",
        "direccion" => "VARCHAR(255) NULL",
        "estado" => "VARCHAR(20) NOT NULL DEFAULT 'Activo'",
    ],
    "compra" => [
        "estado" => "VARCHAR(30) NOT NULL DEFAULT 'Registrado'",
    ],
    "direccion" => [
        "referencia" => "VARCHAR(255) NOT NULL DEFAULT ''",
        "clave_operacion" => "VARCHAR(64) NULL DEFAULT NULL",
    ],
    "movimiento_stock" => [
        "motivo" => "VARCHAR(255) NULL",
        "stock_anterior" => "INT NULL",
        "stock_nuevo" => "INT NULL",
    ],
    "comprobante" => [
        "tipo_comprobante" => "VARCHAR(20) NOT NULL DEFAULT 'Boleta'",
        "subtotal" => "DECIMAL(10,2) NOT NULL DEFAULT 0",
        "igv" => "DECIMAL(10,2) NOT NULL DEFAULT 0",
    ],
    "solicitud_soporte" => [
        "estado" => "VARCHAR(20) NOT NULL DEFAULT 'Abierto'",
        "respuesta" => "TEXT NULL",
        "fecha_actualizacion" => "DATETIME NULL",
    ],
    "detalle_compra" => [
        "precio_compra" => "DECIMAL(10,2) NOT NULL DEFAULT 0",
        "subtotal" => "DECIMAL(10,2) NOT NULL DEFAULT 0",
    ],
    "carrito" => [
        "estado" => "VARCHAR(20) NOT NULL DEFAULT 'Activo'",
    ],
];

foreach ($columnasCompatibles as $tablaCompat => $definiciones) {
    foreach ($definiciones as $columnaCompat => $definicion) {
        if (columnaExiste($conexion, $tablaCompat, $columnaCompat)) {
            continue;
        }
        try {
            $conexion->query(
                "ALTER TABLE `$tablaCompat` ADD COLUMN `$columnaCompat` $definicion"
            );
            if (!columnaExiste($conexion, $tablaCompat, $columnaCompat)) {
                throw new RuntimeException("La columna no aparece después de ALTER TABLE");
            }
            error_log("Dorada Motors: columna heredada recuperada: $tablaCompat.$columnaCompat");
        } catch (Throwable $e) {
            error_log("Dorada Motors: fallo migración $tablaCompat.$columnaCompat: " . $e->getMessage());
            http_response_code(503);
            throw new RuntimeException(
                "No se pudo actualizar la estructura de MySQL: $tablaCompat.$columnaCompat. " .
                "Haz una copia de seguridad y revisa permisos de ALTER TABLE.",
                0,
                $e
            );
        }
    }
}
