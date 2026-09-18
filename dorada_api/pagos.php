<?php

include("conexion.php");

if ($_SERVER["REQUEST_METHOD"] === "POST") {

    $datos = json_decode(
        file_get_contents("php://input"),
        true
    );

    $id_pedido = $datos["id_pedido"];
    $metodo = $datos["metodo_pago"];
    $monto = $datos["monto"];
    $estado = $datos["estado_pago"];

    $sql = "INSERT INTO pago
            (
                id_pedido,
                metodo_pago,
                monto,
                fecha_pago,
                estado_pago
            )
            VALUES (?, ?, ?, NOW(), ?)";

    $stmt = $conexion->prepare($sql);

    $stmt->bind_param(
        "isds",
        $id_pedido,
        $metodo,
        $monto,
        $estado
    );

    if ($stmt->execute()) {

        echo json_encode([
            "estado" => true,
            "mensaje" => "Pago registrado"
        ]);
    } else {

        echo json_encode([
            "estado" => false,
            "mensaje" => "Error al registrar pago"
        ]);
    }

    exit;
}

$resultado = $conexion->query(
    "SELECT * FROM pago
     ORDER BY id_pago DESC"
);

$pagos = [];

while ($fila = $resultado->fetch_assoc()) {
    $pagos[] = $fila;
}

echo json_encode($pagos);