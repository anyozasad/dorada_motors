<?php

include("conexion.php");

header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $datos = json_decode(file_get_contents("php://input"), true);

    if (!is_array($datos)) {
        http_response_code(400);
        echo json_encode(["estado"=>false,"mensaje"=>"Datos de dirección inválidos"], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $idUsuario = (int)($datos["id_usuario"] ?? 0);
    $departamento = trim($datos["departamento"] ?? "");
    $provincia = trim($datos["provincia"] ?? "");
    $distrito = trim($datos["distrito"] ?? "");
    $direccion = trim($datos["direccion_detalle"] ?? "");
    $referencia = trim($datos["referencia"] ?? "");

    if ($idUsuario <= 0 || $direccion === "") {
        http_response_code(400);
        echo json_encode(["estado"=>false,"mensaje"=>"Completa la dirección"], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $stmt = $conexion->prepare("
        INSERT INTO direccion
        (id_usuario,departamento,provincia,distrito,direccion_detalle,referencia)
        VALUES (?,?,?,?,?,?)
    ");
    $stmt->bind_param(
        "isssss",
        $idUsuario,
        $departamento,
        $provincia,
        $distrito,
        $direccion,
        $referencia
    );

    if (!$stmt->execute()) {
        http_response_code(500);
        echo json_encode(["estado"=>false,"mensaje"=>"No se pudo registrar la dirección"], JSON_UNESCAPED_UNICODE);
        exit;
    }

    echo json_encode([
        "estado"=>true,
        "mensaje"=>"Dirección registrada",
        "id_direccion"=>$conexion->insert_id
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

$idUsuario = (int)($_GET["id_usuario"] ?? 0);

if ($idUsuario > 0) {
    $stmt = $conexion->prepare("SELECT * FROM direccion WHERE id_usuario=? ORDER BY id_direccion DESC");
    $stmt->bind_param("i",$idUsuario);
    $stmt->execute();
    $resultado = $stmt->get_result();
} else {
    $resultado = $conexion->query("SELECT * FROM direccion ORDER BY id_direccion DESC");
}

$direcciones = [];
while ($fila = $resultado->fetch_assoc()) {
    $direcciones[] = $fila;
}

echo json_encode($direcciones, JSON_UNESCAPED_UNICODE);
