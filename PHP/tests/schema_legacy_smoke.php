<?php
declare(strict_types=1);

/**
 * Ejecutar únicamente en GitHub Actions, con una base TEMPORAL independiente.
 * Prueba: DB_NAME configurado, importación automática, columnas heredadas,
 * alteración idempotente y conservación de registros existentes.
 * NUNCA usar sobre la base de XAMPP del usuario.
 */
if (getenv("GITHUB_ACTIONS") !== "true" ||
    getenv("DB_NAME") !== "dorada_schema_ci_test") {
    fwrite(STDERR, "ERROR: esta prueba requiere GitHub Actions y DB_NAME=dorada_schema_ci_test\n");
    exit(2);
}
require_once __DIR__ . "/../dorada_api/conexion.php";
try {
    $actual = $conexion->query("SELECT DATABASE() AS db")->fetch_assoc()["db"] ?? "";
    if ($actual !== "dorada_schema_ci_test") {
        throw new RuntimeException("DB_NAME no corresponde a la base de pruebas: " . $actual);
    }
    $tables = (int)($conexion->query(
        "SELECT COUNT(*) AS n FROM information_schema.tables " .
        "WHERE table_schema=DATABASE()"
    )->fetch_assoc()["n"] ?? 0);
    if ($tables < 18) {
        throw new RuntimeException("No se importaron las 18 tablas iniciales");
    }

    $primero = $conexion->query("SELECT id_producto,nombre_producto,precio FROM producto LIMIT 1")->fetch_assoc();
    if (!$primero) {
        throw new RuntimeException("No se cargó el catálogo de demostración");
    }
    $original = (float)$primero["precio"];
    $idProducto = (int)$primero["id_producto"];

    // Simular la instalación antigua que generaba 'Unknown column'.
    // Únicamente se eliminan columnas de la base EFÍMERA de CI.
    foreach ([
        "ALTER TABLE producto DROP COLUMN imagen_url",
        "ALTER TABLE usuario DROP COLUMN ultimo_acceso",
        "ALTER TABLE proveedor DROP COLUMN ruc",
        "ALTER TABLE pedido DROP COLUMN tipo_entrega",
        "ALTER TABLE solicitud_soporte DROP COLUMN respuesta"
    ] as $sql) {
        $conexion->query($sql);
    }
    require_once __DIR__ . "/../dorada_api/sistema_bootstrap.php";
    foreach ([
        ["producto", "imagen_url"],
        ["usuario", "ultimo_acceso"],
        ["proveedor", "ruc"],
        ["pedido", "tipo_entrega"],
        ["solicitud_soporte", "respuesta"]
    ] as [$tabla, $columna]) {
        if (!columnaExiste($conexion, $tabla, $columna)) {
            throw new RuntimeException("No se recuperó columna $tabla.$columna");
        }
    }
    $stmt = $conexion->prepare("SELECT precio FROM producto WHERE id_producto=?");
    $stmt->bind_param("i", $idProducto);
    $stmt->execute();
    $restaurado = (float)($stmt->get_result()->fetch_assoc()["precio"] ?? -1);
    if (abs($restaurado - $original) > 0.001) {
        throw new RuntimeException("Se modificó el precio del producto existente");
    }
    // Ninguna migración debe borrar pedidos, usuarios ni volver a crear la BD normal.
    $actual = $conexion->query("SELECT DATABASE() AS db")->fetch_assoc()["db"] ?? "";
    if ($actual !== "dorada_schema_ci_test") {
        throw new RuntimeException("La migración cambió de base de datos");
    }
    echo "OK: instalación DB_NAME temporal, 18 tablas, columnas antiguas reparadas y precio preservado.\n";
} catch (Throwable $e) {
    fwrite(STDERR, "ERROR PRUEBA ESQUEMA HEREDADO: " . $e->getMessage() . "\n");
    exit(1);
}
