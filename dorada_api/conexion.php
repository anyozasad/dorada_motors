<?php

header("Content-Type: application/json; charset=UTF-8");

$origen = $_SERVER["HTTP_ORIGIN"] ?? "";
$origenesPermitidos = array_filter(array_map(
    "trim",
    explode(",", getenv("APP_ORIGINS") ?: "http://localhost:8080,http://127.0.0.1:8080")
));

if ($origen !== "" && in_array($origen, $origenesPermitidos, true)) {
    header("Access-Control-Allow-Origin: " . $origen);
    header("Vary: Origin");
}

header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");

if ($_SERVER["REQUEST_METHOD"] === "OPTIONS") {
    http_response_code(204);
    exit;
}

$dbHost = getenv("DB_HOST") ?: "localhost";
$dbUser = getenv("DB_USER") ?: "root";
$dbPass = getenv("DB_PASS") ?: "";
$dbName = getenv("DB_NAME") ?: "dorada_motors";
$dbPort = (int)(getenv("DB_PORT") ?: 3306);

/*
 * Conexión robusta:
 * 1) conecta al servidor MySQL
 * 2) crea dorada_motors si no existe
 * 3) importa el esquema automáticamente si faltan tablas principales
 */
$conexion = @new mysqli(
    $dbHost,
    $dbUser,
    $dbPass,
    "",
    $dbPort
);

if ($conexion->connect_error) {
    error_log("Dorada Motors DB: " . $conexion->connect_error);
    http_response_code(500);

    echo json_encode([
        "estado" => false,
        "mensaje" => "No se pudo conectar con MySQL. Verifica que MySQL esté encendido en XAMPP."
    ], JSON_UNESCAPED_UNICODE);

    exit;
}

$conexion->set_charset("utf8mb4");

$nombreSeguro = preg_replace('/[^A-Za-z0-9_]/', '', $dbName);
if ($nombreSeguro === "") {
    $nombreSeguro = "dorada_motors";
}

if (!$conexion->query(
    "CREATE DATABASE IF NOT EXISTS `" . $nombreSeguro . "`
     CHARACTER SET utf8mb4
     COLLATE utf8mb4_unicode_ci"
)) {
    error_log("Dorada Motors CREATE DATABASE: " . $conexion->error);
    http_response_code(500);
    echo json_encode([
        "estado" => false,
        "mensaje" => "No se pudo crear la base de datos dorada_motors."
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

if (!$conexion->select_db($nombreSeguro)) {
    error_log("Dorada Motors SELECT DB: " . $conexion->error);
    http_response_code(500);
    echo json_encode([
        "estado" => false,
        "mensaje" => "No se pudo seleccionar la base de datos dorada_motors."
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

$tablasPrincipales = [
    "usuario",
    "categoria",
    "marca",
    "producto",
    "pedido",
    "detalle_pedido",
    "pago"
];

$faltanTablas = false;

foreach ($tablasPrincipales as $tabla) {
    $tablaEscapada = $conexion->real_escape_string($tabla);
    $resultadoTabla = $conexion->query("SHOW TABLES LIKE '" . $tablaEscapada . "'");

    if (!$resultadoTabla || $resultadoTabla->num_rows === 0) {
        $faltanTablas = true;
        break;
    }
}

if ($faltanTablas) {
    $archivoSql = __DIR__ . "/dorada_motors.sql";

    if (!is_file($archivoSql)) {
        http_response_code(500);
        echo json_encode([
            "estado" => false,
            "mensaje" => "Falta el archivo dorada_motors.sql para preparar la base de datos."
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $sql = file_get_contents($archivoSql);

    if ($sql === false || trim($sql) === "") {
        http_response_code(500);
        echo json_encode([
            "estado" => false,
            "mensaje" => "El archivo dorada_motors.sql está vacío."
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }

    if (!$conexion->multi_query($sql)) {
        error_log("Dorada Motors IMPORT SQL: " . $conexion->error);
        http_response_code(500);
        echo json_encode([
            "estado" => false,
            "mensaje" => "No se pudo crear la estructura de la base de datos.",
            "detalle" => $conexion->error
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }

    do {
        if ($resultado = $conexion->store_result()) {
            $resultado->free();
        }
    } while ($conexion->more_results() && $conexion->next_result());

    if ($conexion->errno) {
        error_log("Dorada Motors IMPORT SQL final: " . $conexion->error);
        http_response_code(500);
        echo json_encode([
            "estado" => false,
            "mensaje" => "La base de datos no pudo terminar de prepararse.",
            "detalle" => $conexion->error
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $conexion->select_db($nombreSeguro);
    $conexion->set_charset("utf8mb4");
}
