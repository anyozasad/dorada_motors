<?php

header("Content-Type: application/json; charset=UTF-8");
header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");

require_once "conexion.php";
require_once "auth_admin.php";

if (!adminActual() || !puede("inicio")) {
    http_response_code(401);
    echo json_encode(["estado"=>false,"mensaje"=>"Inicia sesión en el dashboard PHP para consultar las métricas"], JSON_UNESCAPED_UNICODE);
    exit;
}
require_once "sistema_bootstrap.php";

function serieUltimos7Dias(mysqli $conexion, string $consulta, string $campoValor): array {
    $mapa = [];
    $resultado = $conexion->query($consulta);

    while ($fila = $resultado->fetch_assoc()) {
        $mapa[$fila["fecha"]] = (float)$fila[$campoValor];
    }

    $serie = [];
    for ($i = 6; $i >= 0; $i--) {
        $fecha = date("Y-m-d", strtotime("-{$i} day"));
        $serie[] = [
            "fecha" => $fecha,
            "dia" => date("d/m", strtotime($fecha)),
            "total" => $mapa[$fecha] ?? 0,
        ];
    }

    return $serie;
}

try {
    $totalProductos = (int)$conexion->query(
        "SELECT COUNT(*) AS total FROM producto"
    )->fetch_assoc()["total"];

    $totalUsuarios = (int)$conexion->query(
        "SELECT COUNT(*) AS total FROM usuario WHERE rol_sistema='Cliente'"
    )->fetch_assoc()["total"];

    $totalPedidos = (int)$conexion->query(
        "SELECT COUNT(*) AS total FROM pedido"
    )->fetch_assoc()["total"];

    $pedidosPendientes = (int)$conexion->query(
        "SELECT COUNT(*) AS total FROM pedido WHERE LOWER(estado_pedido) IN ('pendiente','procesando')"
    )->fetch_assoc()["total"];

    $totalVentas = (float)$conexion->query(
        "SELECT COALESCE(SUM(total),0) AS total FROM pedido WHERE LOWER(estado_pedido)<>'cancelado'"
    )->fetch_assoc()["total"];

    $ventasHoy = (float)$conexion->query(
        "SELECT COALESCE(SUM(total),0) AS total
         FROM pedido
         WHERE DATE(fecha_pedido)=CURDATE()
           AND LOWER(estado_pedido)<>'cancelado'"
    )->fetch_assoc()["total"];

    $ventasMes = (float)$conexion->query(
        "SELECT COALESCE(SUM(total),0) AS total
         FROM pedido
         WHERE YEAR(fecha_pedido)=YEAR(CURDATE())
           AND MONTH(fecha_pedido)=MONTH(CURDATE())
           AND LOWER(estado_pedido)<>'cancelado'"
    )->fetch_assoc()["total"];

    $soportePendiente = puede("soporte")
        ? (int)$conexion->query(
            "SELECT COUNT(*) AS total FROM solicitud_soporte
             WHERE estado IN ('Abierto','En proceso')"
          )->fetch_assoc()["total"]
        : 0;

    $stockBajo = (int)$conexion->query(
        "SELECT COUNT(*) AS total FROM producto WHERE stock<=stock_minimo"
    )->fetch_assoc()["total"];

    $stockCritico = (int)$conexion->query(
        "SELECT COUNT(*) AS total FROM producto WHERE stock<=2"
    )->fetch_assoc()["total"];

    $proveedores = (int)$conexion->query(
        "SELECT COUNT(*) AS total FROM proveedor"
    )->fetch_assoc()["total"];

    $compras = (float)$conexion->query(
        "SELECT COALESCE(SUM(total),0) AS total
         FROM compra
         WHERE LOWER(estado)<>'anulado'"
    )->fetch_assoc()["total"];

    $resultado = $conexion->query("
        SELECT
            p.id_pedido,
            p.fecha_pedido,
            p.estado_pedido,
            p.total,
            p.tipo_entrega,
            u.nombres,
            u.apellidos
        FROM pedido p
        INNER JOIN usuario u ON p.id_usuario=u.id_usuario
        ORDER BY p.id_pedido DESC
        LIMIT 5
    ");

    $ultimosPedidos = [];
    while ($fila = $resultado->fetch_assoc()) {
        $ultimosPedidos[] = $fila;
    }

    $alertasStock = $conexion->query("
        SELECT id_producto,nombre_producto,stock,stock_minimo
        FROM producto
        WHERE stock<=stock_minimo
        ORDER BY stock ASC, nombre_producto ASC
        LIMIT 5
    ")->fetch_all(MYSQLI_ASSOC);

    $pagosRecientes = $conexion->query("
        SELECT
            pg.id_pago,
            pg.id_pedido,
            pg.metodo_pago,
            pg.monto,
            pg.estado_pago,
            pg.fecha_pago,
            u.nombres,
            u.apellidos
        FROM pago pg
        INNER JOIN pedido p ON p.id_pedido=pg.id_pedido
        INNER JOIN usuario u ON u.id_usuario=p.id_usuario
        ORDER BY pg.id_pago DESC
        LIMIT 5
    ")->fetch_all(MYSQLI_ASSOC);

    $productosMasVendidos = $conexion->query("
        SELECT
            pr.id_producto,
            pr.nombre_producto,
            COALESCE(SUM(dp.cantidad),0) AS vendidos,
            COALESCE(SUM(dp.subtotal),0) AS importe
        FROM detalle_pedido dp
        INNER JOIN producto pr ON pr.id_producto=dp.id_producto
        INNER JOIN pedido p ON p.id_pedido=dp.id_pedido
        WHERE LOWER(p.estado_pedido)<>'cancelado'
        GROUP BY pr.id_producto,pr.nombre_producto
        ORDER BY vendidos DESC, importe DESC
        LIMIT 5
    ")->fetch_all(MYSQLI_ASSOC);

    $ventas7Dias = serieUltimos7Dias(
        $conexion,
        "SELECT DATE(fecha_pedido) AS fecha, COALESCE(SUM(total),0) AS total
         FROM pedido
         WHERE fecha_pedido >= CURDATE() - INTERVAL 6 DAY
           AND LOWER(estado_pedido)<>'cancelado'
         GROUP BY DATE(fecha_pedido)
         ORDER BY fecha",
        "total"
    );

    $pedidos7Dias = serieUltimos7Dias(
        $conexion,
        "SELECT DATE(fecha_pedido) AS fecha, COUNT(*) AS total
         FROM pedido
         WHERE fecha_pedido >= CURDATE() - INTERVAL 6 DAY
         GROUP BY DATE(fecha_pedido)
         ORDER BY fecha",
        "total"
    );

    echo json_encode([
        "estado" => true,
        "actualizado_en" => date("Y-m-d H:i:s"),
        "productos" => $totalProductos,
        "usuarios" => $totalUsuarios,
        "pedidos" => $totalPedidos,
        "pedidos_pendientes" => $pedidosPendientes,
        "ventas" => $totalVentas,
        "ventas_hoy" => $ventasHoy,
        "ventas_mes" => $ventasMes,
        "soporte_pendiente" => $soportePendiente,
        "stock_bajo" => $stockBajo,
        "stock_critico" => $stockCritico,
        "proveedores" => $proveedores,
        "compras" => $compras,
        "ultimos_pedidos" => $ultimosPedidos,
        "alertas_stock" => $alertasStock,
        "pagos_recientes" => $pagosRecientes,
        "productos_mas_vendidos" => $productosMasVendidos,
        "ventas_7_dias" => $ventas7Dias,
        "pedidos_7_dias" => $pedidos7Dias
    ], JSON_UNESCAPED_UNICODE);

} catch (Throwable $e) {
    error_log("Dashboard API: " . $e->getMessage());
    http_response_code(500);

    echo json_encode([
        "estado" => false,
        "mensaje" => "Error al cargar el dashboard"
    ], JSON_UNESCAPED_UNICODE);
}
