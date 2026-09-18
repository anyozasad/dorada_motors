<?php

include("conexion.php");

if ($_SERVER["REQUEST_METHOD"] === "POST") {

    $datos = json_decode(
        file_get_contents("php://input"),
        true
    );

    $nombre = $datos["nombre_marca"];

    $stmt = $conexion->prepare(
        "INSERT INTO marca (nombre_marca)
         VALUES (?)"
    );

    $stmt->bind_param("s", $nombre);

    $stmt->execute();

    echo json_encode([
        "estado" => true,
        "mensaje" => "Marca registrada"
    ]);

    exit;
}

$resultado = $conexion->query(
    "SELECT * FROM marca"
);

$marcas = [];

while ($fila = $resultado->fetch_assoc()) {
    $marcas[] = $fila;
}

echo json_encode($marcas);