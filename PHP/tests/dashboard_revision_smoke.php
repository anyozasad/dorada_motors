<?php
declare(strict_types=1);

/**
 * Prueba de regresión contra MySQL/MariaDB real.
 * Cambiar stock o estado sin insertar filas debe activar la sincronización
 * del dashboard; cada modificación se revierte mediante ROLLBACK.
 */
require_once __DIR__ . "/../dorada_api/conexion.php";
require_once __DIR__ . "/../dorada_api/dashboard_revision.php";

$producto = $conexion->query(
    "SELECT id_producto FROM producto ORDER BY id_producto DESC LIMIT 1"
)->fetch_assoc();
$pedido = $conexion->query(
    "SELECT id_pedido, estado_pedido FROM pedido ORDER BY id_pedido DESC LIMIT 1"
)->fetch_assoc();
if (!$producto || !$pedido) {
    throw new RuntimeException("La prueba requiere un producto y pedido reales del smoke test");
}

$base = revisionDatosDashboard($conexion);
if (!preg_match('/^[a-f0-9]{64}$/', $base)) {
    throw new RuntimeException("Huella inválida del dashboard");
}

$idProducto = (int)$producto["id_producto"];
$conexion->begin_transaction();
try {
    $stmt = $conexion->prepare(
        "UPDATE producto SET stock=stock+1 WHERE id_producto=?"
    );
    $stmt->bind_param("i", $idProducto);
    $stmt->execute();
    if (revisionDatosDashboard($conexion) === $base) {
        throw new RuntimeException("El dashboard no detectó el cambio de stock");
    }
} finally {
    $conexion->rollback();
}
if (revisionDatosDashboard($conexion) !== $base) {
    throw new RuntimeException("El rollback del stock no restauró los datos");
}

$idPedido = (int)$pedido["id_pedido"];
$estadoNuevo = $pedido["estado_pedido"] === "Pendiente"
    ? "Procesando" : "Pendiente";
$conexion->begin_transaction();
try {
    $stmt = $conexion->prepare(
        "UPDATE pedido SET estado_pedido=? WHERE id_pedido=?"
    );
    $stmt->bind_param("si", $estadoNuevo, $idPedido);
    $stmt->execute();
    if (revisionDatosDashboard($conexion) === $base) {
        throw new RuntimeException("El dashboard no detectó el nuevo estado del pedido");
    }
} finally {
    $conexion->rollback();
}
if (revisionDatosDashboard($conexion) !== $base) {
    throw new RuntimeException("El rollback del pedido no restauró el estado");
}
echo "OK: dashboard detecta cambios de stock y estado sin nuevas filas; rollback correcto.\n";
