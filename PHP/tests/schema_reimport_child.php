<?php
declare(strict_types=1);

/**
 * Proceso PHP aislado: fuerza el arranque automático del SQL con una tabla
 * inexistente y una columna eliminada en la BD TEMPORAL de GitHub Actions.
 */
if (getenv("GITHUB_ACTIONS") !== "true" ||
    getenv("DB_NAME") !== "dorada_schema_ci_test") {
    fwrite(STDERR, "Solo se ejecuta en CI sobre la BD temporal.\n");
    exit(2);
}
try {
    // Validar también que el endpoint NO acepte una tabla incompleta.
if (getenv("DORADA_SCHEMA_CHECK") === "1") {
    require_once __DIR__ . "/../dorada_api/conexion_estado.php";
    exit;
}
require_once __DIR__ . "/../dorada_api/conexion.php";
    require_once __DIR__ . "/../dorada_api/sistema_bootstrap.php";
    $db = $conexion->query("SELECT DATABASE() AS nombre")->fetch_assoc()["nombre"] ?? "";
    if ($db !== "dorada_schema_ci_test") {
        throw new RuntimeException("Se conectó a una base diferente");
    }
    if (!columnaExiste($conexion, "producto", "imagen_url")) {
        throw new RuntimeException("No se reparó producto.imagen_url");
    }
    $favorite = $conexion->query("SHOW TABLES LIKE 'favorito'");
    if (!$favorite || $favorite->num_rows !== 1) {
        throw new RuntimeException("No se restauró la tabla favorito");
    }
    $cantidad = (int)($conexion->query(
        "SELECT COUNT(*) AS n FROM producto"
    )->fetch_assoc()["n"] ?? 0);
    if ($cantidad < 19) {
        throw new RuntimeException("La migración borró productos existentes");
    }
    echo "OK: restaurar tabla faltante y columna antigua antes de importar catálogo.\n";
} catch (Throwable $e) {
    fwrite(STDERR, "ERROR REIMPORTACION: " . $e->getMessage() . "\n");
    exit(1);
}
