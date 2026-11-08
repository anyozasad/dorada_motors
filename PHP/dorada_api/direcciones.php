<?php
include("conexion.php");
require_once "sistema_bootstrap.php";
require_once __DIR__ . "/cliente_auth.php";

header("Content-Type: application/json; charset=UTF-8");

function responderDireccion(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

$metodo = $_SERVER["REQUEST_METHOD"];
$idClienteSesion = requerirClienteApi($conexion);

if ($metodo === "POST" || $metodo === "PUT") {
    $datos = json_decode(file_get_contents("php://input"), true);

    if (!is_array($datos)) {
        responderDireccion(["estado"=>false,"mensaje"=>"Datos de dirección inválidos"], 400);
    }

    $idUsuario = (int)($datos["id_usuario"] ?? 0);
    requerirClienteApi($conexion, $idUsuario);
    $departamento = trim($datos["departamento"] ?? "");
    $provincia = trim($datos["provincia"] ?? "");
    $distrito = trim($datos["distrito"] ?? "");
    $direccion = trim($datos["direccion_detalle"] ?? "");
    $referencia = trim($datos["referencia"] ?? "");

    if ($idUsuario <= 0 || $direccion === "") {
        responderDireccion(["estado"=>false,"mensaje"=>"Completa la dirección"], 400);
    }

    $stmt = $conexion->prepare("SELECT id_usuario FROM usuario WHERE id_usuario=? AND rol_sistema='Cliente' LIMIT 1");
    $stmt->bind_param("i",$idUsuario);
    $stmt->execute();
    if (!$stmt->get_result()->fetch_assoc()) {
        responderDireccion(["estado"=>false,"mensaje"=>"Usuario no encontrado"], 404);
    }

    if ($metodo === "POST") {
        $stmt = $conexion->prepare("
            INSERT INTO direccion
            (id_usuario,departamento,provincia,distrito,direccion_detalle,referencia)
            VALUES (?,?,?,?,?,?)
        ");
        $stmt->bind_param("isssss",$idUsuario,$departamento,$provincia,$distrito,$direccion,$referencia);

        if (!$stmt->execute()) {
            responderDireccion(["estado"=>false,"mensaje"=>"No se pudo registrar la dirección"], 500);
        }

        responderDireccion([
            "estado"=>true,
            "mensaje"=>"Dirección registrada",
            "id_direccion"=>$conexion->insert_id
        ], 201);
    }

    $idDireccion = (int)($datos["id_direccion"] ?? $_GET["id"] ?? 0);
    if ($idDireccion <= 0) {
        responderDireccion(["estado"=>false,"mensaje"=>"Falta id_direccion"], 400);
    }

    $stmt = $conexion->prepare(
        "SELECT id_direccion FROM direccion WHERE id_direccion=? AND id_usuario=? LIMIT 1"
    );
    $stmt->bind_param("ii",$idDireccion,$idClienteSesion);
    $stmt->execute();
    if (!$stmt->get_result()->fetch_assoc()) {
        responderDireccion(["estado"=>false,"mensaje"=>"Dirección no encontrada en tu cuenta"],404);
    }

    $stmt = $conexion->prepare("
        UPDATE direccion
        SET id_usuario=?,departamento=?,provincia=?,distrito=?,direccion_detalle=?,referencia=?
        WHERE id_direccion=? AND id_usuario=?
    ");
    $stmt->bind_param("isssssii",$idUsuario,$departamento,$provincia,$distrito,$direccion,$referencia,$idDireccion,$idClienteSesion);
    $stmt->execute();

    responderDireccion(["estado"=>true,"mensaje"=>"Dirección actualizada"]);
}

if ($metodo === "DELETE") {
    $datos = json_decode(file_get_contents("php://input"), true) ?: [];
    $idDireccion = (int)($datos["id_direccion"] ?? $_GET["id"] ?? 0);

    if ($idDireccion <= 0) {
        responderDireccion(["estado"=>false,"mensaje"=>"Falta id_direccion"], 400);
    }

    // Comprobar pertenencia antes de consultar pedidos asociados:
    // no divulgar datos de direcciones de otros clientes.
    $stmt = $conexion->prepare(
        "SELECT id_direccion FROM direccion WHERE id_direccion=? AND id_usuario=? LIMIT 1"
    );
    $stmt->bind_param("ii",$idDireccion,$idClienteSesion);
    $stmt->execute();
    if (!$stmt->get_result()->fetch_assoc()) {
        responderDireccion(["estado"=>false,"mensaje"=>"Dirección no encontrada en tu cuenta"],404);
    }

    $stmt = $conexion->prepare("SELECT COUNT(*) AS total FROM pedido WHERE id_direccion=?");
    $stmt->bind_param("i",$idDireccion);
    $stmt->execute();
    if ((int)$stmt->get_result()->fetch_assoc()["total"] > 0) {
        responderDireccion(["estado"=>false,"mensaje"=>"La dirección está asociada a pedidos"], 409);
    }

    $stmt = $conexion->prepare("DELETE FROM direccion WHERE id_direccion=? AND id_usuario=?");
    $stmt->bind_param("ii",$idDireccion,$idClienteSesion);
    $stmt->execute();

    responderDireccion(["estado"=>true,"mensaje"=>"Dirección eliminada"]);
}

$idUsuario = (int)($_GET["id_usuario"] ?? 0);
if ($idUsuario <= 0) $idUsuario = $idClienteSesion;
requerirClienteApi($conexion, $idUsuario);
$idDireccion = (int)($_GET["id"] ?? 0);

if ($idDireccion > 0) {
    $stmt = $conexion->prepare("SELECT * FROM direccion WHERE id_direccion=? AND id_usuario=? LIMIT 1");
    $stmt->bind_param("ii",$idDireccion,$idClienteSesion);
    $stmt->execute();
    $fila = $stmt->get_result()->fetch_assoc();
    if (!$fila) responderDireccion(["estado"=>false,"mensaje"=>"Dirección no encontrada"], 404);
    echo json_encode($fila, JSON_UNESCAPED_UNICODE);
    exit;
}

if ($idUsuario > 0) {
    $stmt = $conexion->prepare("
        SELECT d.*
        FROM direccion d
        INNER JOIN usuario u ON d.id_usuario=u.id_usuario
        WHERE d.id_usuario=? AND u.rol_sistema='Cliente'
        ORDER BY d.id_direccion DESC
    ");
    $stmt->bind_param("i",$idUsuario);
    $stmt->execute();
    $resultado = $stmt->get_result();
} else {
    $resultado = $conexion->query("
        SELECT d.*
        FROM direccion d
        INNER JOIN usuario u ON d.id_usuario=u.id_usuario
        WHERE u.rol_sistema='Cliente'
        ORDER BY d.id_direccion DESC
    ");
}

$direcciones = [];
while ($fila = $resultado->fetch_assoc()) $direcciones[] = $fila;
echo json_encode($direcciones, JSON_UNESCAPED_UNICODE);
