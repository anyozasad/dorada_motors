<?php

include("conexion.php");
require_once "sistema_bootstrap.php";

if ($_SERVER["REQUEST_METHOD"] === "PUT") {
    $datos = json_decode(file_get_contents("php://input"), true);

    if (!is_array($datos)) {
        http_response_code(400);
        echo json_encode(["estado"=>false,"mensaje"=>"Datos inválidos"], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $idUsuario = (int)($datos["id_usuario"] ?? 0);
    $telefono = trim($datos["telefono"] ?? "");

    if ($idUsuario <= 0 || strlen($telefono) < 7) {
        http_response_code(400);
        echo json_encode(["estado"=>false,"mensaje"=>"Teléfono inválido"], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $stmt = $conexion->prepare("UPDATE usuario SET telefono=? WHERE id_usuario=? AND rol_sistema='Cliente'");
    $stmt->bind_param("si", $telefono, $idUsuario);

    if (!$stmt->execute()) {
        http_response_code(500);
        echo json_encode(["estado"=>false,"mensaje"=>"No se pudo actualizar el teléfono"], JSON_UNESCAPED_UNICODE);
        exit;
    }

    echo json_encode([
        "estado"=>true,
        "mensaje"=>"Teléfono actualizado"
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $datos = json_decode(file_get_contents("php://input"), true);

    if (!is_array($datos)) {
        echo json_encode([
            "estado" => false,
            "mensaje" => "Datos de registro inválidos"
        ]);
        exit;
    }

    $nombres = trim($datos["nombres"] ?? "");
    $apellidos = trim($datos["apellidos"] ?? "");
    $correo = strtolower(trim($datos["correo"] ?? ""));
    $contrasenaPlano = $datos["contrasena"] ?? "";
    $telefono = trim($datos["telefono"] ?? "");

    if ($nombres === "" || $correo === "" || $contrasenaPlano === "") {
        echo json_encode([
            "estado" => false,
            "mensaje" => "Completa nombres, correo y contraseña"
        ]);
        exit;
    }

    if (!filter_var($correo, FILTER_VALIDATE_EMAIL)) {
        echo json_encode([
            "estado" => false,
            "mensaje" => "Ingresa un correo válido"
        ]);
        exit;
    }

    if (strlen($contrasenaPlano) < 6) {
        echo json_encode([
            "estado" => false,
            "mensaje" => "La contraseña debe tener al menos 6 caracteres"
        ]);
        exit;
    }

    $stmt = $conexion->prepare("SELECT id_usuario FROM usuario WHERE correo = ? LIMIT 1");
    $stmt->bind_param("s", $correo);
    $stmt->execute();

    if ($stmt->get_result()->fetch_assoc()) {
        echo json_encode([
            "estado" => false,
            "mensaje" => "Ese correo ya está registrado"
        ]);
        exit;
    }

    $contrasena = password_hash($contrasenaPlano, PASSWORD_DEFAULT);

    $stmt = $conexion->prepare("
        INSERT INTO usuario
        (nombres, apellidos, correo, contrasena, telefono)
        VALUES (?, ?, ?, ?, ?)
    ");

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
            "mensaje" => "No se pudo registrar el usuario"
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
        telefono,
        estado
    FROM usuario
    WHERE rol_sistema='Cliente'
    ORDER BY id_usuario DESC
");

$usuarios = [];

while ($fila = $resultado->fetch_assoc()) {
    $usuarios[] = $fila;
}

echo json_encode($usuarios);
