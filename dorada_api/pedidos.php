<?php

include("conexion.php");

if ($_SERVER["REQUEST_METHOD"] === "POST") {

    $datos = json_decode(
        file_get_contents("php://input"),
        true
    );

    $id_usuario = $datos["id_usuario"];
    $estado = $datos["estado_pedido"] ?? "Pendiente";
    $total = $datos["total"];

    $sql = "INSERT INTO pedido
            (
                id_usuario,
                fecha_pedido,
                estado_pedido,
                total
            )
            VALUES (?, NOW(), ?, ?)";

    $stmt = $conexion->prepare($sql);

    $stmt->bind_param(
        "isd",
        $id_usuario,
        $estado,
        $total
    );

    if ($stmt->execute()) {

        echo json_encode([
            "estado" => true,
            "mensaje" => "Pedido registrado",
            "id_pedido" => $conexion->insert_id
        ]);
    } else {

        echo json_encode([
            "estado" => false,
            "mensaje" => "Error al registrar pedido"
        ]);
    }

    exit;
}

$resultado = $conexion->query("
    SELECT
        p.id_pedido,
        p.fecha_pedido,
        p.estado_pedido,
        p.total,

        u.id_usuario,
        u.nombres,
        u.apellidos

    FROM pedido p

    INNER JOIN usuario u
        ON p.id_usuario = u.id_usuario

    ORDER BY p.id_pedido DESC
");

$pedidos = [];

while ($fila = $resultado->fetch_assoc()) {
    $pedidos[] = $fila;
}

echo json_encode($pedidos);