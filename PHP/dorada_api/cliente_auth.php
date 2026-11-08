<?php
/**
 * Autenticación de clientes para la API móvil.
 * Los tokens aleatorios se almacenan solo como hash SHA-256 en MySQL.
 */
if (!isset($conexion) || !($conexion instanceof mysqli)) {
    require_once __DIR__ . "/conexion.php";
}

function asegurarSesionesCliente(mysqli $conexion): void {
    static $lista = [];
    $id = spl_object_id($conexion);
    if (isset($lista[$id])) return;

    $sql = "CREATE TABLE IF NOT EXISTS sesion_cliente (
        token_hash CHAR(64) NOT NULL PRIMARY KEY,
        id_usuario INT NOT NULL,
        fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        fecha_expiracion DATETIME NOT NULL,
        INDEX idx_sesion_cliente_usuario (id_usuario),
        INDEX idx_sesion_cliente_expiracion (fecha_expiracion),
        CONSTRAINT fk_sesion_cliente_usuario FOREIGN KEY (id_usuario)
          REFERENCES usuario(id_usuario) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";

    if (!$conexion->query($sql)) {
        error_log("Dorada Motors sesiones: " . $conexion->error);
        http_response_code(500);
        echo json_encode(["estado"=>false,"mensaje"=>"No se pudo preparar el acceso seguro"], JSON_UNESCAPED_UNICODE);
        exit;
    }
    $lista[$id] = true;
}

function emitirTokenCliente(mysqli $conexion, int $idUsuario): string {
    asegurarSesionesCliente($conexion);
    $token = bin2hex(random_bytes(32));
    $hash = hash("sha256", $token);
    $stmt = $conexion->prepare(
        "INSERT INTO sesion_cliente (token_hash,id_usuario,fecha_expiracion)
         VALUES (?,?,DATE_ADD(NOW(), INTERVAL 7 DAY))"
    );
    $stmt->bind_param("si", $hash, $idUsuario);
    if (!$stmt->execute()) {
        throw new RuntimeException("No se pudo iniciar la sesión");
    }
    return $token;
}

function tokenBearerCliente(): string {
    $cabecera = $_SERVER["HTTP_AUTHORIZATION"]
        ?? $_SERVER["REDIRECT_HTTP_AUTHORIZATION"]
        ?? "";
    if (!$cabecera && function_exists("getallheaders")) {
        foreach (getallheaders() as $clave => $valor) {
            if (strcasecmp($clave, "Authorization") === 0) {
                $cabecera = (string)$valor;
                break;
            }
        }
    }
    return preg_match('/^Bearer ([a-fA-F0-9]{64})$/', trim($cabecera), $coincide)
        ? $coincide[1] : "";
}

function idClienteAutenticado(mysqli $conexion): int {
    $token = tokenBearerCliente();
    if ($token === "") return 0;
    asegurarSesionesCliente($conexion);
    $hash = hash("sha256", $token);
    $stmt = $conexion->prepare(
        "SELECT s.id_usuario FROM sesion_cliente s
         INNER JOIN usuario u ON u.id_usuario=s.id_usuario
         WHERE s.token_hash=? AND s.fecha_expiracion>NOW()
           AND u.rol_sistema='Cliente' AND u.estado='Activo'
         LIMIT 1"
    );
    $stmt->bind_param("s", $hash);
    $stmt->execute();
    $fila = $stmt->get_result()->fetch_assoc();
    return (int)($fila["id_usuario"] ?? 0);
}

function requerirClienteApi(mysqli $conexion, ?int $idEsperado = null): int {
    $id = idClienteAutenticado($conexion);
    if ($id <= 0) {
        http_response_code(401);
        echo json_encode([
            "estado"=>false,
            "mensaje"=>"Tu sesión venció. Vuelve a iniciar sesión."
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    if ($idEsperado !== null && $id !== $idEsperado) {
        http_response_code(403);
        echo json_encode([
            "estado"=>false,
            "mensaje"=>"No tienes permiso para acceder a esta cuenta."
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    return $id;
}

function cerrarTokenCliente(mysqli $conexion): void {
    $token = tokenBearerCliente();
    if ($token === "") return;
    asegurarSesionesCliente($conexion);
    $hash = hash("sha256", $token);
    $stmt = $conexion->prepare("DELETE FROM sesion_cliente WHERE token_hash=?");
    $stmt->bind_param("s", $hash);
    $stmt->execute();
}
