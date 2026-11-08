<?php
declare(strict_types=1);

require_once __DIR__ . "/conexion.php";
header("Content-Type: application/json; charset=UTF-8");
header("Cache-Control: no-store");

function respuestaRecuperacion(int $status = 202): void {
    http_response_code($status);
    echo json_encode([
        "estado"=>true,
        "mensaje"=>"Si el correo pertenece a una cuenta activa, el administrador recibirá la solicitud. La identidad debe verificarse antes de restablecer el acceso."
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

if (($_SERVER["REQUEST_METHOD"] ?? "") !== "POST") {
    http_response_code(405);
    echo json_encode(["estado"=>false,"mensaje"=>"Método no permitido"], JSON_UNESCAPED_UNICODE);
    exit;
}

$datos = json_decode(file_get_contents("php://input"), true);
$correo = strtolower(trim((string)($datos["correo"] ?? "")));
if (!filter_var($correo, FILTER_VALIDATE_EMAIL) || strlen($correo) > 160) {
    http_response_code(422);
    echo json_encode(["estado"=>false,"mensaje"=>"Ingresa un correo electrónico válido"], JSON_UNESCAPED_UNICODE);
    exit;
}

$stmt = $conexion->prepare(
    "SELECT id_usuario FROM usuario
     WHERE correo=? AND rol_sistema='Cliente' AND estado='Activo' LIMIT 1"
);
$stmt->bind_param("s",$correo);
$stmt->execute();
$cliente = $stmt->get_result()->fetch_assoc();

if ($cliente) {
    $id = (int)$cliente["id_usuario"];
    $asunto = "Recuperación de acceso";
    // Limitar a una solicitud por cuenta cada 30 minutos.
    $stmt = $conexion->prepare(
        "SELECT id_solicitud FROM solicitud_soporte
         WHERE id_usuario=? AND asunto=?
           AND fecha_creacion>DATE_SUB(NOW(), INTERVAL 30 MINUTE)
         LIMIT 1"
    );
    $stmt->bind_param("is", $id, $asunto);
    $stmt->execute();
    if (!$stmt->get_result()->fetch_assoc()) {
        $mensaje = "Solicitud recibida desde el formulario de acceso. Verificar identidad por un canal confiable antes de cambiar la contraseña. Nunca solicitar la contraseña anterior por mensaje.";
        $stmt = $conexion->prepare(
            "INSERT INTO solicitud_soporte (id_usuario,asunto,mensaje,estado,fecha_creacion)
             VALUES (?,?,?,'Abierto',NOW())"
        );
        $stmt->bind_param("iss", $id, $asunto, $mensaje);
        $stmt->execute();
    }
}

// Misma respuesta si la cuenta existe o no: no divulgar usuarios registrados.
respuestaRecuperacion();
