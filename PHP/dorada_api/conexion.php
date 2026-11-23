<?php

header("Content-Type: application/json; charset=UTF-8");

$origen = $_SERVER["HTTP_ORIGIN"] ?? "";
$origenesPermitidos = array_filter(array_map(
    "trim",
    explode(",", getenv("APP_ORIGINS") ?: "http://localhost:8080,http://127.0.0.1:8080")
));

$esOrigenLocal = preg_match(
    '#^https?://(localhost|127\\.0\\.0\\.1)(:[0-9]+)?$#',
    $origen
) === 1;

if ($origen !== "" && (in_array($origen, $origenesPermitidos, true) || $esOrigenLocal)) {
    header("Access-Control-Allow-Origin: " . $origen);
    header("Vary: Origin");
}

header("Access-Control-Allow-Headers: Content-Type, Authorization, X-CSRF-Token");
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
try {
    $conexion = @new mysqli(
        $dbHost,
        $dbUser,
        $dbPass,
        "",
        $dbPort
    );
} catch (Throwable $e) {
    error_log("Dorada Motors DB: " . $e->getMessage());
    http_response_code(503);
    echo json_encode([
        "estado" => false,
        "mensaje" => "MySQL no responde. Enciende MySQL desde XAMPP y vuelve a intentar."
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

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

// No cambiar silenciosamente el nombre de la base configurada: eso podía
// hacer que PHP leyera otra base y pareciera que los registros desaparecieron.
if (!preg_match('/^[A-Za-z0-9_]{1,64}$/D', $dbName)) {
    error_log("Dorada Motors: DB_NAME inválido");
    http_response_code(500);
    echo json_encode([
        "estado" => false,
        "mensaje" => "La configuración DB_NAME es inválida. Usa letras, números y guion bajo."
    ], JSON_UNESCAPED_UNICODE);
    exit;
}
$nombreSeguro = $dbName;

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
    "direccion",
    "categoria",
    "marca",
    "producto",
    "pedido",
    "detalle_pedido",
    "pago",
    "proveedor",
    "compra",
    "detalle_compra",
    "movimiento_stock",
    "comprobante",
    "sesion_cliente",
    "carrito",
    "detalle_carrito",
    "favorito",
    "solicitud_soporte"
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

    // El SQL de demostración fue escrito para dorada_motors. Respetar
    // DB_NAME, especialmente en instalaciones heredadas y pruebas aisladas.
    // Una petición nunca debe crear tablas accidentalmente en otra base.
    $sql = preg_replace(
        '/^CREATE DATABASE IF NOT EXISTS dorada_motors\\b/mi',
        'CREATE DATABASE IF NOT EXISTS `' . $nombreSeguro . '`',
        $sql
    );
    $sql = preg_replace(
        '/^USE dorada_motors\\s*;/mi',
        'USE `' . $nombreSeguro . '`;',
        $sql
    );
    if ($sql === null) {
        error_log("Dorada Motors: no se pudo adaptar SQL a DB_NAME");
        http_response_code(500);
        echo json_encode(["estado"=>false,
            "mensaje"=>"No se pudo preparar la estructura SQL."],
            JSON_UNESCAPED_UNICODE);
        exit;
    }

    // Primero instalar las tablas, luego corregir las columnas heredadas,
    // y SOLO DESPUÉS insertar datos iniciales. En bases antiguas faltaban
    // columnas como producto.imagen_url; el INSERT fallaba antes de llegar
    // a sistema_bootstrap.php y aparecía "Unknown column" en el dashboard.
    $inicioDatos = strpos($sql, 'INSERT IGNORE INTO categoria (nombre_categoria) VALUES');
    if ($inicioDatos === false) {
        error_log("Dorada Motors: falta el límite de datos iniciales en el SQL");
        http_response_code(500);
        echo json_encode([
            "estado" => false,
            "mensaje" => "El archivo SQL no tiene el formato esperado."
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    $definiciones = substr($sql, 0, $inicioDatos);
    $datosIniciales = substr($sql, $inicioDatos);

    try {
        // Este lote contiene únicamente CREATE DATABASE/USE/CREATE TABLE.
        if (!$conexion->multi_query($definiciones)) {
            throw new RuntimeException("No se pudo crear el esquema: " . $conexion->error);
        }
        do {
            if ($resultado = $conexion->store_result()) {
                $resultado->free();
            }
        } while ($conexion->more_results() && $conexion->next_result());
        if ($conexion->errno) {
            throw new RuntimeException("No se pudo completar el esquema: " . $conexion->error);
        }
        // No dejar desactivadas las claves foráneas al migrar ni al fallar.
        $conexion->query("SET FOREIGN_KEY_CHECKS=1");

        // Migrar únicamente columnas/índices faltantes de instalaciones
        // antiguas, sin borrar inventario, pedidos ni clientes existentes.
        require_once __DIR__ . "/sistema_bootstrap.php";

        $sql = $datosIniciales;
    } catch (Throwable $e) {
        error_log("Dorada Motors SQL: " . $e->getMessage());
        http_response_code(503);
        echo json_encode([
            "estado" => false,
            "mensaje" => "La estructura MySQL no se pudo completar. " .
                "Revisa permisos y el registro PHP; no se borraron registros."
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }

    if (!$conexion->multi_query($sql)) {
        error_log("Dorada Motors IMPORT SQL: " . $conexion->error);
        http_response_code(500);
        echo json_encode([
            "estado" => false,
            "mensaje" => "No se pudo crear la estructura de la base de datos.",
            "detalle" => "Revisa el registro de errores de PHP/MySQL."
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
