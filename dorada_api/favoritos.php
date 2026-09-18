<?php

include("conexion.php");

if ($_SERVER["REQUEST_METHOD"] === "POST") {

    $datos = json_decode(
        file_get_contents("php://input"),
        true
    );

    $id_usuario = $datos["id_usuario"];
    $id_producto = $datos["id_producto"];
    $tipo = $datos["tipo_registro"];

    $sql = "INSERT INTO carrito_favorito
            (
                id_usuario,
                id_producto,
                tipo_registro,
                fecha_registro
            )
            VALUES (?, ?, ?, NOW())";

    $stmt = $conexion->prepare($sql);

    $stmt->bind_param(
        "iis",
        $id_usuario,
        $id_producto,
        $tipo
    );

    if ($stmt->execute()) {

        echo json_encode([
            "estado" => true,
            "mensaje" => "Producto agregado"
        ]);
    } else {

        echo json_encode([
            "estado" => false,
            "mensaje" => "No se pudo agregar"
        ]);
    }

    exit;
}

$resultado = $conexion->query("
    SELECT
        cf.id_carrito_favorito,
        cf.id_usuario,
        cf.tipo_registro,
        cf.fecha_registro,

        p.id_producto,
        p.nombre_producto,
        p.precio,
        p.imagen_url

    FROM carrito_favorito cf

    INNER JOIN producto p
        ON cf.id_producto = p.id_producto
");

$datos = [];

while ($fila = $resultado->fetch_assoc()) {
    $datos[] = $fila;
}

echo json_encode($datos);