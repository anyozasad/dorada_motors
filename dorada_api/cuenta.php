<?php
declare(strict_types=1);

require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/cliente_auth.php";
header("Content-Type: application/json; charset=UTF-8");
header("Cache-Control: no-store");

function responderCuenta(array $respuesta, int $codigo = 200): void {
    http_response_code($codigo);
    echo json_encode($respuesta, JSON_UNESCAPED_UNICODE);
    exit;
}

$idUsuario = requerirClienteApi($conexion);
$metodo = $_SERVER["REQUEST_METHOD"] ?? "GET";

if ($metodo === "GET") {
    $stmt = $conexion->prepare(
        "SELECT id_usuario, nombres, apellidos, correo, telefono, estado
         FROM usuario WHERE id_usuario=? AND rol_sistema='Cliente' LIMIT 1"
    );
    $stmt->bind_param("i", $idUsuario);
    $stmt->execute();
    $usuario = $stmt->get_result()->fetch_assoc();
    if (!$usuario) responderCuenta(["estado"=>false, "mensaje"=>"Cliente no encontrado"], 404);
    responderCuenta(["estado"=>true, "usuario"=>$usuario]);
}

if ($metodo !== "PUT") {
    responderCuenta(["estado"=>false, "mensaje"=>"Método no permitido"], 405);
}

$datos = json_decode(file_get_contents("php://input"), true);
if (!is_array($datos)) responderCuenta(["estado"=>false, "mensaje"=>"Datos inválidos"], 400);
$accion = (string)($datos["accion"] ?? "perfil");

if ($accion === "perfil") {
    $nombres = trim((string)($datos["nombres"] ?? ""));
    $apellidos = trim((string)($datos["apellidos"] ?? ""));
    $correo = strtolower(trim((string)($datos["correo"] ?? "")));
    $telefono = trim((string)($datos["telefono"] ?? ""));

    if ($nombres === "" || mb_strlen($nombres) > 120 || mb_strlen($apellidos) > 120) {
        responderCuenta(["estado"=>false, "mensaje"=>"Ingresa nombres válidos"], 422);
    }
    if (!filter_var($correo, FILTER_VALIDATE_EMAIL) || strlen($correo) > 160) {
        responderCuenta(["estado"=>false, "mensaje"=>"Ingresa un correo válido"], 422);
    }
    if ($telefono !== "" && !preg_match('/^[+0-9 ()-]{7,30}$/', $telefono)) {
        responderCuenta(["estado"=>false, "mensaje"=>"Ingresa un teléfono válido"], 422);
    }

    $stmt = $conexion->prepare(
        "SELECT id_usuario FROM usuario WHERE correo=? AND id_usuario<>? LIMIT 1"
    );
    $stmt->bind_param("si", $correo, $idUsuario);
    $stmt->execute();
    if ($stmt->get_result()->fetch_assoc()) {
        responderCuenta(["estado"=>false, "mensaje"=>"El correo ya pertenece a otra cuenta"], 409);
    }

    $stmt = $conexion->prepare(
        "UPDATE usuario SET nombres=?,apellidos=?,correo=?,telefono=?
         WHERE id_usuario=? AND rol_sistema='Cliente' AND estado='Activo'"
    );
    $stmt->bind_param("ssssi", $nombres, $apellidos, $correo, $telefono, $idUsuario);
    try {
        $stmt->execute();
    } catch (mysqli_sql_exception $e) {
        if ((int)$e->getCode() === 1062) {
            responderCuenta(["estado"=>false, "mensaje"=>"El correo ya está registrado"], 409);
        }
        error_log("Actualizar perfil: " . $e->getMessage());
        responderCuenta(["estado"=>false, "mensaje"=>"No se pudo guardar el perfil"], 500);
    }
    responderCuenta([
        "estado"=>true, "mensaje"=>"Perfil actualizado",
        "usuario"=>[
            "id_usuario"=>$idUsuario, "nombres"=>$nombres,
            "apellidos"=>$apellidos, "correo"=>$correo, "telefono"=>$telefono,
        ]
    ]);
}

if ($accion === "clave") {
    $actual = (string)($datos["contrasena_actual"] ?? "");
    $nueva = (string)($datos["contrasena_nueva"] ?? "");
    if (strlen($nueva) < 8 || strlen($nueva) > 128) {
        responderCuenta(["estado"=>false, "mensaje"=>"La nueva contraseña debe tener entre 8 y 128 caracteres"], 422);
    }
    if (hash_equals($actual, $nueva)) {
        responderCuenta(["estado"=>false, "mensaje"=>"La nueva contraseña debe ser diferente"], 422);
    }
    $stmt = $conexion->prepare(
        "SELECT contrasena FROM usuario WHERE id_usuario=? AND rol_sistema='Cliente' LIMIT 1"
    );
    $stmt->bind_param("i", $idUsuario);
    $stmt->execute();
    $fila = $stmt->get_result()->fetch_assoc();
    if (!$fila || !password_verify($actual, (string)$fila["contrasena"])) {
        responderCuenta(["estado"=>false, "mensaje"=>"Contraseña actual incorrecta"], 403);
    }

    $hash = password_hash($nueva, PASSWORD_DEFAULT);
    $conexion->begin_transaction();
    try {
        $stmt = $conexion->prepare(
            "UPDATE usuario SET contrasena=? WHERE id_usuario=? AND rol_sistema='Cliente'"
        );
        $stmt->bind_param("si", $hash, $idUsuario);
        $stmt->execute();

        // Cerrar las demás sesiones, manteniendo abierta la que realizó el cambio.
        $tokenActual = hash("sha256", tokenBearerCliente());
        $stmt = $conexion->prepare(
            "DELETE FROM sesion_cliente WHERE id_usuario=? AND token_hash<>?"
        );
        $stmt->bind_param("is", $idUsuario, $tokenActual);
        $stmt->execute();
        $conexion->commit();
    } catch (Throwable $e) {
        $conexion->rollback();
        error_log("Cambiar contraseña cliente: " . $e->getMessage());
        responderCuenta(["estado"=>false,"mensaje"=>"No se pudo cambiar la contraseña"],500);
    }
    responderCuenta(["estado"=>true,"mensaje"=>"Contraseña actualizada y otras sesiones cerradas"]);
}

responderCuenta(["estado"=>false,"mensaje"=>"Acción no reconocida"],422);
