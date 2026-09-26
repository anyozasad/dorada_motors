<?php
require_once __DIR__ . "/conexion.php";
header("Content-Type: application/json; charset=UTF-8");

$resultado = [
    "estado" => false,
    "conexion_mysql" => false,
    "base_datos" => "",
    "tablas_encontradas" => 0,
    "tablas_requeridas" => 13,
    "escritura" => false,
    "mensaje" => ""
];

try {
    $resultado["conexion_mysql"] = true;

    $bd = $conexion->query("SELECT DATABASE() AS bd");
    $resultado["base_datos"] = $bd ? (string)($bd->fetch_assoc()["bd"] ?? "") : "";

    $tablas = [
        "usuario","direccion","categoria","marca","producto",
        "pedido","detalle_pedido","pago","proveedor","compra",
        "detalle_compra","movimiento_stock","comprobante"
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
        $resultado["base_datos"] === "dorada_motors" &&
        $resultado["tablas_encontradas"] === 13 &&
        $resultado["escritura"];

    $resultado["mensaje"] = $resultado["estado"]
        ? "Conexión correcta: PHP puede leer y guardar datos en dorada_motors."
        : "La conexión existe, pero falta revisar la estructura de la base de datos.";

} catch (Throwable $e) {
    if ($conexion instanceof mysqli) {
        @$conexion->rollback();
    }

    $resultado["mensaje"] = "Error de verificación: " . $e->getMessage();
}

echo json_encode($resultado, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
