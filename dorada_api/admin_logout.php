<?php
require_once "conexion.php";
require_once "auth_admin.php";

if (adminActual()) {
    registrarBitacora($conexion, "sistema", "Cerrar sesión", "El administrador cerró su sesión.");
}

$_SESSION = [];
if (ini_get("session.use_cookies")) {
    $params = session_get_cookie_params();
    setcookie(session_name(), "", time() - 42000, $params["path"], $params["domain"], $params["secure"], $params["httponly"]);
}
session_destroy();

header("Location: admin_login.php");
exit;
