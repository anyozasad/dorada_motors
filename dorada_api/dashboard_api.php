<?php

header("Content-Type: application/json; charset=UTF-8");
require_once "conexion.php";
require_once "sistema_bootstrap.php";

try {
    $totalProductos = (int)$conexion->query(
        "SELECT COUNT(*) AS total FROM producto"
    )->fetch_assoc()["total"];

    $totalUsuarios = (int)$conexion->query(
        "SELECT COUNT(*) AS total FROM usuario WHERE estado='Activo'"
    )->fetch_assoc()["total"];

    $totalPedidos = (int)$conexion->query(
        "SELECT COUNT(*) AS total FROM pedido"
    )->fetch_assoc()["total"];

    $pedidosPendientes = (int)$conexion->query(
        "SELECT COUNT(*) AS total FROM pedido WHERE LOWER(estado_pedido) IN ('pendiente','procesando')"
    )->fetch_assoc()["total"];

    $totalVentas = (float)$conexion->query(
        "SELECT COALESCE(SUM(total),0) AS total FROM pedido"
    )->fetch_assoc()["total"];

    $ventasHoy = (float)$conexion->query(
        "SELECT COALESCE(SUM(total),0) AS total FROM pedido WHERE DATE(fecha_pedido)=CURDATE()"
    )->fetch_assoc()["total"];

    $stockBajo = (int)$conexion->query(
        "SELECT COUNT(*) AS total FROM producto WHERE stock<=stock_minimo"
    )->fetch_assoc()["total"];

    $proveedores = (int)$conexion->query(
        "SELECT COUNT(*) AS total FROM proveedor"
    )->fetch_assoc()["total"];

    $compras = (float)$conexion->query(
        "SELECT COALESCE(SUM(total),0) AS total FROM compra"
    )->fetch_assoc()["total"];

    $resultado = $conexion->query("
        SELECT
            p.id_pedido,
            p.fecha_pedido,
            p.estado_pedido,
            p.total,
            p.tipo_entrega,
            u.nombres,
            u.apellidos
        FROM pedido p
        INNER JOIN usuario u ON p.id_usuario=u.id_usuario
        ORDER BY p.id_pedido DESC
        LIMIT 5
    ");

    $ultimosPedidos = [];
    while ($fila = $resultado->fetch_assoc()) {
        $ultimosPedidos[] = $fila;
    }

    $alertasStock = $conexion->query("
        SELECT id_producto,nombre_producto,stock,stock_minimo
        FROM producto
        WHERE stock<=stock_minimo
        ORDER BY stock ASC
        LIMIT 5
    ")->fetch_all(MYSQLI_ASSOC);

    echo json_encode([
        "estado" => true,
        "productos" => $totalProductos,
        "usuarios" => $totalUsuarios,
        "pedidos" => $totalPedidos,
        "pedidos_pendientes" => $pedidosPendientes,
        "ventas" => $totalVentas,
        "ventas_hoy" => $ventasHoy,
        "stock_bajo" => $stockBajo,
        "proveedores" => $proveedores,
        "compras" => $compras,
        "ultimos_pedidos" => $ultimosPedidos,
        "alertas_stock" => $alertasStock
    ], JSON_UNESCAPED_UNICODE);

} catch (Throwable $e) {
    error_log("Dashboard API: " . $e->getMessage());
    http_response_code(500);

    echo json_encode([
        "estado" => false,
        "mensaje" => "Error al cargar el dashboard"
    ], JSON_UNESCAPED_UNICODE);
}
