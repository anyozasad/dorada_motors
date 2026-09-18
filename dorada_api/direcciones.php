<?php

include("conexion.php");

if ($_SERVER["REQUEST_METHOD"] === "POST") {

    $datos = json_decode(
        file_get_contents("php://input"),
        true
    );

    $id_usuario = $datos["id_usuario"];
    $departamento = $datos["departamento"];
    $provincia = $datos["provincia"];
    $distrito = $datos["distrito"];
    $direccion = $datos["direccion_detalle"];
    $referencia = $datos["referencia"];

    $sql = "INSERT INTO direccion
            (
                id_usuario,
                departamento,
                provincia,
                distrito,
                direccion_detalle,
                referencia
            )
            VALUES (?, ?, ?, ?, ?, ?)";

    $stmt = $conexion->prepare($sql);

    $stmt->bind_param(
        "isssss",
        $id_usuario,
        $departamento,
        $provincia,
        $distrito,
        $direccion,
        $referencia
    );

    $stmt->execute();

    echo json_encode([
        "estado" => true,
        "mensaje" => "Dirección registrada"
    ]);

    exit;
}

$resultado = $conexion->query(
    "SELECT * FROM direccion"
);

$direcciones = [];

while ($fila = $resultado->fetch_assoc()) {
    $direcciones[] = $fila;
}

echo json_encode($direcciones);