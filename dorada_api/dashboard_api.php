<?php

header("Content-Type: application/json; charset=UTF-8");
require_once "conexion.php";

try {
    $totalProductos = (int)$conexion->query(
        "SELECT COUNT(*) AS total FROM producto"
    )->fetch_assoc()["total"];

    $totalUsuarios = (int)$conexion->query(
        "SELECT COUNT(*) AS total FROM usuario"
    )->fetch_assoc()["total"];

    $totalPedidos = (int)$conexion->query(
        "SELECT COUNT(*) AS total FROM pedido"
    )->fetch_assoc()["total"];

    $totalVentas = (float)$conexion->query(
        "SELECT COALESCE(SUM(total), 0) AS total FROM pedido"
    )->fetch_assoc()["total"];

    $resultado = $conexion->query("
        SELECT
            p.id_pedido,
            p.fecha_pedido,
            p.estado_pedido,
            p.total,
            u.nombres,
            u.apellidos
        FROM pedido p
        INNER JOIN usuario u
            ON p.id_usuario = u.id_usuario
        ORDER BY p.id_pedido DESC
        LIMIT 5
    ");

    $ultimosPedidos = [];

    while ($fila = $resultado->fetch_assoc()) {
        $ultimosPedidos[] = $fila;
    }

    echo json_encode([
        "estado" => true,
        "productos" => $totalProductos,
        "usuarios" => $totalUsuarios,
        "pedidos" => $totalPedidos,
        "ventas" => $totalVentas,
        "ultimos_pedidos" => $ultimosPedidos
    ], JSON_UNESCAPED_UNICODE);

} catch (Throwable $e) {
    http_response_code(500);

    echo json_encode([
        "estado" => false,
        "mensaje" => "Error al cargar el dashboard",
        "error" => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}

?>