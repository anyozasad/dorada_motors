<?php
declare(strict_types=1);

/**
 * Huella del estado real del sistema. No depende solo de cantidad de filas:
 * cambiar el estado de un pedido, pago, stock, soporte o perfil también
 * obliga a refrescar las tablas PHP visibles al administrador.
 *
 * Usa consultas agregadas, sin transferir datos privados a JavaScript.
 */
function revisionDatosDashboard(mysqli $conexion): string {
    $consultas = [
        "SELECT COUNT(*) AS n,
                COALESCE(SUM(CRC32(CONCAT_WS('|',
                    id_pedido, id_usuario, estado_pedido, total, tipo_entrega))),0) AS suma
         FROM pedido",
        "SELECT COUNT(*) AS n,
                COALESCE(SUM(CRC32(CONCAT_WS('|',
                    id_pago, id_pedido, estado_pago, monto, COALESCE(referencia_cliente,'')))),0) AS suma
         FROM pago",
        "SELECT COUNT(*) AS n,
                COALESCE(SUM(CRC32(CONCAT_WS('|',
                    id_producto, nombre_producto, precio, precio_oferta, stock,
                    COALESCE(imagen_url,'')))),0) AS suma
         FROM producto",
        "SELECT COUNT(*) AS n,
                COALESCE(SUM(CRC32(CONCAT_WS('|',
                    id_usuario, nombres, apellidos, correo, COALESCE(telefono,''), estado))),0) AS suma
         FROM usuario",
        "SELECT COUNT(*) AS n,
                COALESCE(SUM(CRC32(CONCAT_WS('|',
                    id_solicitud, estado, COALESCE(respuesta,'')))),0) AS suma
         FROM solicitud_soporte",
        "SELECT COUNT(*) AS n,
                COALESCE(SUM(CRC32(CONCAT_WS('|',
                    id_compra, estado, total))),0) AS suma
         FROM compra",
        "SELECT COUNT(*) AS n, COALESCE(MAX(id_movimiento),0) AS suma
         FROM movimiento_stock",
        "SELECT COUNT(*) AS n,
                COALESCE(SUM(CRC32(CONCAT_WS('|',
                    id_direccion, id_usuario, departamento, provincia, distrito,
                    direccion_detalle, COALESCE(referencia,'')))),0) AS suma
         FROM direccion",
        "SELECT COUNT(*) AS n,
                COALESCE(SUM(CRC32(CONCAT_WS('|',id_categoria,nombre_categoria))),0) AS suma
         FROM categoria",
        "SELECT COUNT(*) AS n,
                COALESCE(SUM(CRC32(CONCAT_WS('|',id_marca,nombre_marca))),0) AS suma
         FROM marca",
        "SELECT COUNT(*) AS n,
                COALESCE(SUM(CRC32(CONCAT_WS('|',
                    id_proveedor,razon_social,COALESCE(ruc,''),estado))),0) AS suma
         FROM proveedor",
        "SELECT COUNT(*) AS n,
                COALESCE(SUM(CRC32(CONCAT_WS('|',
                    id_comprobante,id_pedido,tipo_comprobante,numero_comprobante,total))),0) AS suma
         FROM comprobante",
    ];
    $huellas = [];
    foreach ($consultas as $sql) {
        $resultado = $conexion->query($sql);
        if (!$resultado) {
            throw new RuntimeException("No fue posible comprobar la versión de los datos del dashboard");
        }
        $fila = $resultado->fetch_assoc();
        $huellas[] = (string)($fila["n"] ?? "0") . ":" . (string)($fila["suma"] ?? "0");
    }
    return hash("sha256", implode(";", $huellas));
}
