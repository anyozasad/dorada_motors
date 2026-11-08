<?php

if (session_status() !== PHP_SESSION_ACTIVE) {
    session_name("adn_admin_session");
    session_set_cookie_params([
        "httponly" => true,
        "secure" => (!empty($_SERVER["HTTPS"]) && $_SERVER["HTTPS"] !== "off"),
        "samesite" => "Lax",
        "path" => "/",
    ]);
    session_start();
}

require_once __DIR__ . "/sistema_bootstrap.php";

function adminActual(): ?array {
    global $conexion;
    if (empty($_SESSION["admin"])) return null;

    $ultimo = (int)($_SESSION["admin_last_activity"] ?? 0);
    if ($ultimo <= 0 || (time() - $ultimo) > 7200) {
        $_SESSION = [];
        session_regenerate_id(true);
        return null;
    }

    // No confiar en el rol guardado en la cookie/sesión tras cambios de personal.
    // Se consulta la cuenta una sola vez por petición PHP.
    static $cuentaComprobada = false;
    if (!$cuentaComprobada) {
        $cuentaComprobada = true;
        $idAdmin = (int)($_SESSION["admin"]["id_usuario"]
            ?? $_SESSION["admin"]["id_admin"] ?? 0);
        if ($idAdmin <= 0 || !($conexion instanceof mysqli)) {
            $_SESSION = [];
            return null;
        }

        $stmt = $conexion->prepare(
            "SELECT id_usuario,nombres,apellidos,correo,rol_sistema
             FROM usuario
             WHERE id_usuario=? AND estado='Activo'
               AND rol_sistema IN ('Administrador','Vendedor','Almacen')
             LIMIT 1"
        );
        $stmt->bind_param("i", $idAdmin);
        $stmt->execute();
        $usuario = $stmt->get_result()->fetch_assoc();
        if (!$usuario) {
            $_SESSION = [];
            session_regenerate_id(true);
            return null;
        }

        $_SESSION["admin"]["rol"] = (string)$usuario["rol_sistema"];
        $_SESSION["admin"]["nombres"] = trim(
            (string)$usuario["nombres"]." ".(string)$usuario["apellidos"]
        );
        $_SESSION["admin"]["correo"] = (string)$usuario["correo"];
    }

    if (empty($_SESSION["admin"])) return null;
    $_SESSION["admin_last_activity"] = time();
    return $_SESSION["admin"];
}

function requerirAdmin(): void {
    if (!adminActual()) {
        $destino = basename($_SERVER["REQUEST_URI"] ?? "dashboard.php");
        header("Location: admin_login.php?next=" . urlencode($destino));
        exit;
    }
}

function rolActual(): string {
    return adminActual()["rol"] ?? "";
}

function puede(string $modulo): bool {
    $rol = rolActual();

    $permisos = [
        "Administrador" => [
            "inicio","clientes","pedidos","pagos","comprobantes","reportes",
            "gestion-productos","productos","inventario","compras","proveedores","categorias","marcas",
            "configuracion","soporte"
        ],
        "Vendedor" => [
            "inicio","clientes","pedidos","pagos","comprobantes","reportes","soporte"
        ],
        "Almacen" => [
            "inicio","gestion-productos","productos","inventario","compras",
            "proveedores","categorias","marcas","reportes"
        ],
    ];

    return in_array($modulo, $permisos[$rol] ?? [], true);
}

function csrfToken(): string {
    if (empty($_SESSION["csrf_token"])) {
        $_SESSION["csrf_token"] = bin2hex(random_bytes(32));
    }
    return $_SESSION["csrf_token"];
}

function csrfInput(): string {
    return '<input type="hidden" name="csrf_token" value="' .
        htmlspecialchars(csrfToken(), ENT_QUOTES, "UTF-8") . '">';
}

function csrfValido(?string $token): bool {
    return is_string($token)
        && !empty($_SESSION["csrf_token"])
        && hash_equals($_SESSION["csrf_token"], $token);
}

function registrarBitacora(mysqli $conexion, string $modulo, string $accion, string $detalle = ""): void {
    $dir = __DIR__ . "/data";
    if (!is_dir($dir)) {
        @mkdir($dir, 0775, true);
    }

    $admin = $_SESSION["admin"] ?? [];
    $registro = [
        "fecha" => date("Y-m-d H:i:s"),
        "id_usuario" => (int)($admin["id_usuario"] ?? $admin["id_admin"] ?? 0),
        "usuario" => (string)($admin["correo"] ?? ""),
        "rol" => (string)($admin["rol"] ?? ""),
        "modulo" => $modulo,
        "accion" => $accion,
        "detalle" => $detalle,
        "ip" => (string)($_SERVER["REMOTE_ADDR"] ?? ""),
    ];

    @file_put_contents(
        $dir . "/auditoria.jsonl",
        json_encode($registro, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . PHP_EOL,
        FILE_APPEND | LOCK_EX
    );
}

function limpiarNext(string $next): string {
    $permitidos = ["dashboard.php"];
    $base = basename(parse_url($next, PHP_URL_PATH) ?: "dashboard.php");
    return in_array($base, $permitidos, true) ? $base : "dashboard.php";
}
