<?php

include("conexion.php");

if ($_SERVER["REQUEST_METHOD"] === "POST") {

    $datos = json_decode(
        file_get_contents("php://input"),
        true
    );

    $nombre = $datos["nombre_categoria"];

    $stmt = $conexion->prepare(
        "INSERT INTO categoria (nombre_categoria)
         VALUES (?)"
    );

    $stmt->bind_param("s", $nombre);

    $stmt->execute();

    echo json_encode([
        "estado" => true,
        "mensaje" => "Categoría registrada"
    ]);

    exit;
}

$resultado = $conexion->query(
    "SELECT * FROM categoria"
);

$categorias = [];

while ($fila = $resultado->fetch_assoc()) {
    $categorias[] = $fila;
}

echo json_encode($categorias);