<?php
require_once "conexion.php";
require_once "auth_admin.php";

requerirAdmin();

if (rolActual() !== "Administrador") {
    http_response_code(403);
    exit("Acceso denegado");
}

registrarBitacora($conexion, "sistema", "Descargar respaldo", "Se generó un respaldo SQL de dorada_motors.");

$archivo = "dorada_motors_backup_" . date("Ymd_His") . ".sql";
header("Content-Type: application/sql; charset=UTF-8");
header("Content-Disposition: attachment; filename=" . $archivo);
header("Pragma: no-cache");

echo "-- Dorada Motors / ADN Imports\n";
echo "-- Respaldo generado: " . date("Y-m-d H:i:s") . "\n";
echo "SET FOREIGN_KEY_CHECKS=0;\n\n";

$tablas = [];
$resultado = $conexion->query("SHOW TABLES");
while ($fila = $resultado->fetch_row()) {
    $tablas[] = $fila[0];
}

foreach ($tablas as $tabla) {
    if (!preg_match('/^[A-Za-z0-9_]+$/', $tabla)) continue;

    $crear = $conexion->query("SHOW CREATE TABLE " . $tabla)->fetch_assoc();
    $valoresCrear = array_values($crear);

    echo "DROP TABLE IF EXISTS " . $tabla . ";\n";
    echo ($crear["Create Table"] ?? $valoresCrear[1]) . ";\n\n";

    $datos = $conexion->query("SELECT * FROM " . $tabla);
    while ($fila = $datos->fetch_assoc()) {
        $columnas = array_keys($fila);
        $valores = [];

        foreach ($fila as $valor) {
            $valores[] = $valor === null
                ? "NULL"
                : "'" . $conexion->real_escape_string((string)$valor) . "'";
        }

        echo "INSERT INTO " . $tabla . " (" . implode(",", $columnas) . ") VALUES (" .
            implode(",", $valores) . ");\n";
    }

    echo "\n";
}

echo "SET FOREIGN_KEY_CHECKS=1;\n";
exit;
