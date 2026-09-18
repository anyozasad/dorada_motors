<?php

include("conexion.php");

if ($_SERVER["REQUEST_METHOD"] === "POST") {

    $datos = json_decode(
        file_get_contents("php://input"),
        true
    );

    $nombres = $datos["nombres"];
    $apellidos = $datos["apellidos"];
    $correo = $datos["correo"];
    $contrasena = password_hash(
        $datos["contrasena"],
        PASSWORD_DEFAULT
    );
    $telefono = $datos["telefono"];

    $sql = "INSERT INTO usuario
            (nombres, apellidos, correo, contrasena, telefono)
            VALUES (?, ?, ?, ?, ?)";

    $stmt = $conexion->prepare($sql);

    $stmt->bind_param(
        "sssss",
        $nombres,
        $apellidos,
        $correo,
        $contrasena,
        $telefono
    );

    if ($stmt->execute()) {

        echo json_encode([
            "estado" => true,
            "mensaje" => "Usuario registrado",
            "id_usuario" => $conexion->insert_id
        ]);
    } else {

        echo json_encode([
            "estado" => false,
            "mensaje" => "No se pudo registrar",
            "error" => $stmt->error
        ]);
    }

    exit;
}

$resultado = $conexion->query("
    SELECT
        id_usuario,
        nombres,
        apellidos,
        correo,
        telefono
    FROM usuario
");

$usuarios = [];

while ($fila = $resultado->fetch_assoc()) {
    $usuarios[] = $fila;
}

echo json_encode($usuarios);