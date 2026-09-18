<?php

include("conexion.php");

if ($_SERVER["REQUEST_METHOD"] === "POST") {

    $datos = json_decode(
        file_get_contents("php://input"),
        true
    );

    $id_pedido = $datos["id_pedido"];
    $id_producto = $datos["id_producto"];
    $cantidad = $datos["cantidad"];
    $precio = $datos["precio_unitario"];

    $subtotal = $cantidad * $precio;

    $sql = "INSERT INTO detalle_pedido
            (
                id_pedido,
                id_producto,
                cantidad,
                precio_unitario,
                subtotal
            )
            VALUES (?, ?, ?, ?, ?)";

    $stmt = $conexion->prepare($sql);

    $stmt->bind_param(
        "iiidd",
        $id_pedido,
        $id_producto,
        $cantidad,
        $precio,
        $subtotal
    );

    if ($stmt->execute()) {

        echo json_encode([
            "estado" => true,
            "mensaje" => "Detalle registrado"
        ]);
    } else {

        echo json_encode([
            "estado" => false,
            "mensaje" => "Error al registrar detalle"
        ]);
    }

    exit;
}

$resultado = $conexion->query("
    SELECT
        d.*,
        p.nombre_producto
    FROM detalle_pedido d

    INNER JOIN producto p
        ON d.id_producto = p.id_producto
");

$detalles = [];

while ($fila = $resultado->fetch_assoc()) {
    $detalles[] = $fila;
}

echo json_encode($detalles);