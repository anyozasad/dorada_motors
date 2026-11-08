<?php
declare(strict_types=1);

require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/cliente_auth.php";
header("Content-Type: application/json; charset=UTF-8");
header("Cache-Control: no-store");

function responderSoporte(array $data, int $codigo = 200): void {
    http_response_code($codigo);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

$idUsuario = requerirClienteApi($conexion);
$metodo = $_SERVER["REQUEST_METHOD"] ?? "GET";

if ($metodo === "GET") {
    $stmt = $conexion->prepare(
        "SELECT id_solicitud,asunto,mensaje,estado,respuesta,fecha_creacion,fecha_actualizacion
         FROM solicitud_soporte WHERE id_usuario=? ORDER BY id_solicitud DESC LIMIT 100"
    );
    $stmt->bind_param("i", $idUsuario);
    $stmt->execute();
    responderSoporte([
        "estado"=>true,
        "solicitudes"=>$stmt->get_result()->fetch_all(MYSQLI_ASSOC)
    ]);
}

if ($metodo !== "POST") {
    responderSoporte(["estado"=>false,"mensaje"=>"Método no permitido"],405);
}

$input = json_decode(file_get_contents("php://input"), true);
if (!is_array($input)) {
    responderSoporte(["estado"=>false,"mensaje"=>"Datos inválidos"],400);
}
$asunto = trim((string)($input["asunto"] ?? ""));
$mensaje = trim((string)($input["mensaje"] ?? ""));

if (strlen($asunto) < 5 || strlen($asunto) > 180
    || strlen($mensaje) < 10 || strlen($mensaje) > 5000) {
    responderSoporte([
        "estado"=>false,
        "mensaje"=>"Escribe un asunto de 5 a 180 caracteres y un detalle de 10 a 5000"
    ],422);
}

$stmt = $conexion->prepare(
    "INSERT INTO solicitud_soporte (id_usuario,asunto,mensaje,estado,fecha_creacion)
     VALUES (?,?,?,'Abierto',NOW())"
);
$stmt->bind_param("iss", $idUsuario, $asunto, $mensaje);
$stmt->execute();

responderSoporte([
    "estado"=>true,
    "mensaje"=>"Tu solicitud fue enviada al administrador",
    "id_solicitud"=>(int)$conexion->insert_id
],201);
