<?php

include("conexion.php");
require_once "sistema_bootstrap.php";

function responderDetalle(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $datos = json_decode(file_get_contents("php://input"), true);

    if (!is_array($datos)) {
        responderDetalle(["estado"=>false,"mensaje"=>"Datos inválidos"], 400);
    }

    $idPedido = (int)($datos["id_pedido"] ?? 0);
    $idProducto = (int)($datos["id_producto"] ?? 0);
    $cantidad = (int)($datos["cantidad"] ?? 0);
    $precio = (float)($datos["precio_unitario"] ?? $datos["precio"] ?? 0);

    if ($idPedido <= 0 || $idProducto <= 0 || $cantidad <= 0) {
        responderDetalle(["estado"=>false,"mensaje"=>"Completa los datos del detalle"], 400);
    }

    $conexion->begin_transaction();

    try {
        $stmt = $conexion->prepare("
            SELECT precio,stock
            FROM producto
            WHERE id_producto=?
            FOR UPDATE
        ");
        $stmt->bind_param("i",$idProducto);
        $stmt->execute();
        $producto = $stmt->get_result()->fetch_assoc();

        if (!$producto) throw new RuntimeException("Producto no encontrado");
        if ((int)$producto["stock"] < $cantidad) throw new RuntimeException("Stock insuficiente");

        if ($precio <= 0) $precio = (float)$producto["precio"];
        $subtotal = round($cantidad * $precio, 2);

        $stmt = $conexion->prepare("
            INSERT INTO detalle_pedido
            (id_pedido,id_producto,cantidad,precio_unitario,subtotal)
            VALUES (?,?,?,?,?)
        ");
        $stmt->bind_param("iiidd",$idPedido,$idProducto,$cantidad,$precio,$subtotal);
        $stmt->execute();

        $stockAnterior = (int)$producto["stock"];
        $stockNuevo = $stockAnterior - $cantidad;

        $stmt = $conexion->prepare("UPDATE producto SET stock=? WHERE id_producto=?");
        $stmt->bind_param("ii",$stockNuevo,$idProducto);
        $stmt->execute();

        $tipo = "Salida";
        $motivo = "Pedido #" . $idPedido . " (detalle legado)";
        $stmt = $conexion->prepare("
            INSERT INTO movimiento_stock
            (id_producto,tipo_movimiento,cantidad,motivo,fecha_movimiento,stock_anterior,stock_nuevo)
            VALUES (?,?,?,?,NOW(),?,?)
        ");
        $stmt->bind_param("isisii",$idProducto,$tipo,$cantidad,$motivo,$stockAnterior,$stockNuevo);
        $stmt->execute();

        $stmt = $conexion->prepare("
            UPDATE pedido
            SET total=(
                SELECT COALESCE(SUM(subtotal),0)
                FROM detalle_pedido
                WHERE id_pedido=?
            )
            WHERE id_pedido=?
        ");
        $stmt->bind_param("ii",$idPedido,$idPedido);
        $stmt->execute();

        $conexion->commit();
        responderDetalle(["estado"=>true,"mensaje"=>"Detalle registrado","subtotal"=>$subtotal]);
    } catch (Throwable $e) {
        $conexion->rollback();
        responderDetalle(["estado"=>false,"mensaje"=>$e->getMessage()], 400);
    }
}

$idPedido = (int)($_GET["id_pedido"] ?? 0);

$sql = "
    SELECT
        d.id_detalle,
        d.id_pedido,
        d.id_producto,
        d.cantidad,
        d.precio_unitario,
        d.subtotal,
        p.nombre_producto,
        p.imagen_url
    FROM detalle_pedido d
    INNER JOIN producto p ON d.id_producto=p.id_producto
";

if ($idPedido > 0) {
    $stmt = $conexion->prepare($sql . " WHERE d.id_pedido=? ORDER BY d.id_detalle");
    $stmt->bind_param("i",$idPedido);
    $stmt->execute();
    $resultado = $stmt->get_result();
} else {
    $resultado = $conexion->query($sql . " ORDER BY d.id_detalle DESC");
}

$detalles = [];
while ($fila = $resultado->fetch_assoc()) {
    $detalles[] = $fila;
}

echo json_encode($detalles, JSON_UNESCAPED_UNICODE);
