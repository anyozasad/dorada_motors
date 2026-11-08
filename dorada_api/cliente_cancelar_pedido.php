<?php
declare(strict_types=1);

require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/sistema_bootstrap.php";
require_once __DIR__ . "/cliente_auth.php";

header("Content-Type: application/json; charset=UTF-8");
header("Cache-Control: no-store");

function responderCancelacion(array $data, int $codigo = 200): void {
    http_response_code($codigo);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

if (($_SERVER["REQUEST_METHOD"] ?? "") !== "POST") {
    responderCancelacion(["estado"=>false,"mensaje"=>"Método no permitido"],405);
}

$idCliente = requerirClienteApi($conexion);
$datos = json_decode(file_get_contents("php://input"),true);
$idPedido = is_array($datos) ? (int)($datos["id_pedido"] ?? 0) : 0;

if ($idPedido <= 0) {
    responderCancelacion(["estado"=>false,"mensaje"=>"Selecciona un pedido válido"],422);
}

$conexion->begin_transaction();
try {
    $stmt = $conexion->prepare(
        "SELECT id_pedido,estado_pedido FROM pedido
         WHERE id_pedido=? AND id_usuario=? FOR UPDATE"
    );
    $stmt->bind_param("ii",$idPedido,$idCliente);
    $stmt->execute();
    $pedido = $stmt->get_result()->fetch_assoc();

    if (!$pedido) {
        $conexion->rollback();
        responderCancelacion(["estado"=>false,"mensaje"=>"Pedido no encontrado"],404);
    }

    $estadoActual = (string)$pedido["estado_pedido"];
    if ($estadoActual === "Cancelado") {
        $conexion->commit();
        responderCancelacion([
            "estado"=>true,"estado_pedido"=>"Cancelado",
            "mensaje"=>"El pedido ya estaba cancelado"
        ]);
    }
    if ($estadoActual !== "Pendiente") {
        $conexion->rollback();
        responderCancelacion([
            "estado"=>false,
            "mensaje"=>"Solo puedes cancelar pedidos pendientes. Contacta a soporte si el pedido ya está en proceso."
        ],409);
    }

    $stmt = $conexion->prepare(
        "SELECT COUNT(*) AS total
         FROM pago WHERE id_pedido=? AND estado_pago='Pagado'"
    );
    $stmt->bind_param("i",$idPedido);
    $stmt->execute();
    $cobros = (int)$stmt->get_result()->fetch_assoc()["total"];
    if ($cobros > 0) {
        $conexion->rollback();
        responderCancelacion([
            "estado"=>false,
            "mensaje"=>"Este pedido tiene pagos confirmados. Contacta a soporte para gestionar la devolución."
        ],409);
    }

    $stmt = $conexion->prepare(
        "SELECT id_producto, SUM(cantidad) AS cantidad FROM detalle_pedido
         WHERE id_pedido=? GROUP BY id_producto ORDER BY id_producto"
    );
    $stmt->bind_param("i",$idPedido);
    $stmt->execute();
    $detalles = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    if (!$detalles) {
        throw new RuntimeException("El pedido no contiene detalles para restaurar inventario");
    }

    foreach ($detalles as $detalle) {
        $idProducto = (int)$detalle["id_producto"];
        $cantidad = (int)$detalle["cantidad"];
        if ($cantidad <= 0) throw new RuntimeException("Cantidad de detalle inválida");
        $stmt = $conexion->prepare(
            "SELECT stock FROM producto WHERE id_producto=? FOR UPDATE"
        );
        $stmt->bind_param("i",$idProducto);
        $stmt->execute();
        $fila = $stmt->get_result()->fetch_assoc();
        if (!$fila) throw new RuntimeException("No se encontró el producto del pedido");

        $anterior = (int)$fila["stock"];
        $nuevo = $anterior + $cantidad;

        $stmt = $conexion->prepare("UPDATE producto SET stock=? WHERE id_producto=?");
        $stmt->bind_param("ii",$nuevo,$idProducto);
        $stmt->execute();

        $tipo = "Entrada";
        $motivo = "Cancelación cliente del pedido #".$idPedido;
        $stmt = $conexion->prepare(
            "INSERT INTO movimiento_stock
             (id_producto,tipo_movimiento,cantidad,motivo,fecha_movimiento,stock_anterior,stock_nuevo)
             VALUES (?,?,?,?,NOW(),?,?)"
        );
        $stmt->bind_param("isisii",$idProducto,$tipo,$cantidad,$motivo,$anterior,$nuevo);
        $stmt->execute();
    }

    $estadoCancelado = "Cancelado";
    $stmt = $conexion->prepare(
        "UPDATE pedido SET estado_pedido=? WHERE id_pedido=?"
    );
    $stmt->bind_param("si",$estadoCancelado,$idPedido);
    $stmt->execute();

    $stmt = $conexion->prepare(
        "UPDATE pago SET estado_pago='Rechazado'
         WHERE id_pedido=? AND estado_pago='Pendiente'"
    );
    $stmt->bind_param("i",$idPedido);
    $stmt->execute();

    $conexion->commit();
    responderCancelacion([
        "estado"=>true,"id_pedido"=>$idPedido,"estado_pedido"=>"Cancelado",
        "mensaje"=>"Pedido cancelado. El stock fue devuelto al inventario."
    ]);
} catch (Throwable $e) {
    $conexion->rollback();
    error_log("Cancelación cliente pedido: " . $e->getMessage());
    responderCancelacion(["estado"=>false,"mensaje"=>"No se pudo cancelar el pedido. Intenta nuevamente o contacta a soporte."],500);
}
