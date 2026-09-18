<?php

include("conexion.php");

if ($_SERVER["REQUEST_METHOD"] === "POST") {

    $datos = json_decode(
        file_get_contents("php://input"),
        true
    );

    $id_categoria = $datos["id_categoria"];
    $id_marca = $datos["id_marca"];
    $nombre = $datos["nombre_producto"];
    $descripcion = $datos["descripcion"];
    $precio = $datos["precio"];
    $stock = $datos["stock"];
    $imagen = $datos["imagen_url"] ?? "";

    $sql = "INSERT INTO producto
            (
                id_categoria,
                id_marca,
                nombre_producto,
                descripcion,
                precio,
                stock,
                imagen_url
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)";

    $stmt = $conexion->prepare($sql);

    $stmt->bind_param(
        "iissdis",
        $id_categoria,
        $id_marca,
        $nombre,
        $descripcion,
        $precio,
        $stock,
        $imagen
    );

    if ($stmt->execute()) {

        echo json_encode([
            "estado" => true,
            "mensaje" => "Producto registrado",
            "id_producto" => $conexion->insert_id
        ]);
    } else {

        echo json_encode([
            "estado" => false,
            "mensaje" => "Error al registrar producto",
            "error" => $stmt->error
        ]);
    }

    exit;
}

$resultado = $conexion->query("
    SELECT
        p.id_producto,
        p.nombre_producto,
        p.descripcion,
        p.precio,
        p.stock,
        p.imagen_url,

        c.id_categoria,
        c.nombre_categoria,

        m.id_marca,
        m.nombre_marca

    FROM producto p

    INNER JOIN categoria c
        ON p.id_categoria = c.id_categoria

    INNER JOIN marca m
        ON p.id_marca = m.id_marca

    ORDER BY p.id_producto DESC
");

$productos = [];

while ($fila = $resultado->fetch_assoc()) {
    $productos[] = $fila;
}

echo json_encode($productos);