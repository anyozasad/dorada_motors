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
    if (empty($_SESSION["admin"])) return null;
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

    if ($rol === "Administrador") return true;

    $permisos = [
        "Vendedor" => [
            "inicio","clientes","usuarios","pedidos","pagos",
            "comprobantes","devoluciones","favoritos","reportes"
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
    $admin = adminActual();
    if (!$admin) return;

    $idAdmin = (int)($admin["id_admin"] ?? 0);
    $usuario = (string)($admin["correo"] ?? "admin");
    $rol = (string)($admin["rol"] ?? "Administrador");
    $ip = $_SERVER["REMOTE_ADDR"] ?? "";

    $stmt = $conexion->prepare("
        INSERT INTO bitacora
        (id_admin,usuario,rol,modulo,accion,detalle,ip)
        VALUES (?,?,?,?,?,?,?)
    ");
    if (!$stmt) return;

    $stmt->bind_param(
        "issssss",
        $idAdmin,
        $usuario,
        $rol,
        $modulo,
        $accion,
        $detalle,
        $ip
    );
    $stmt->execute();
}

function limpiarNext(string $next): string {
    $permitidos = ["dashboard.php"];
    $base = basename(parse_url($next, PHP_URL_PATH) ?: "dashboard.php");
    return in_array($base, $permitidos, true) ? $base : "dashboard.php";
}
