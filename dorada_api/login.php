<?php

include("conexion.php");

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    echo json_encode([
        "estado" => false,
        "mensaje" => "Método no permitido"
    ]);
    exit;
}

$datos = json_decode(file_get_contents("php://input"), true);

if (!is_array($datos)) {
    echo json_encode([
        "estado" => false,
        "mensaje" => "Datos de inicio de sesión inválidos"
    ]);
    exit;
}

$correo = strtolower(trim($datos["correo"] ?? ""));
$contrasena = $datos["contrasena"] ?? "";

if ($correo === "" || $contrasena === "") {
    echo json_encode([
        "estado" => false,
        "mensaje" => "Completa correo y contraseña"
    ]);
    exit;
}

$stmt = $conexion->prepare("
    SELECT
        id_usuario,
        nombres,
        apellidos,
        correo,
        contrasena,
        telefono
    FROM usuario
    WHERE correo = ?
    LIMIT 1
");

$stmt->bind_param("s", $correo);
$stmt->execute();
$usuario = $stmt->get_result()->fetch_assoc();

if (!$usuario || !password_verify($contrasena, $usuario["contrasena"])) {
    echo json_encode([
        "estado" => false,
        "mensaje" => "Correo o contraseña incorrectos"
    ]);
    exit;
}

unset($usuario["contrasena"]);

echo json_encode([
    "estado" => true,
    "mensaje" => "Inicio de sesión correcto",
    "usuario" => $usuario
]);
