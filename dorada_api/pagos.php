<?php
include("conexion.php");
require_once "auth_admin.php";

header("Content-Type: application/json; charset=UTF-8");

if (!adminActual()) {
    http_response_code(401);
    echo json_encode(["estado"=>false,"mensaje"=>"Acceso administrativo requerido"], JSON_UNESCAPED_UNICODE);
    exit;
}

function responderPago(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

$metodo = $_SERVER["REQUEST_METHOD"];

if ($metodo !== "POST" && $metodo !== "GET") {
    header("Allow: GET, POST");
    responderPago(["estado"=>false,"mensaje"=>"Método no permitido"],405);
}

if (!puede("pagos")) {
    responderPago(["estado"=>false,"mensaje"=>"Tu rol no puede consultar pagos"],403);
}

if ($metodo === "POST") {
    if (!csrfValido($_SERVER["HTTP_X_CSRF_TOKEN"] ?? null)) {
        responderPago(["estado"=>false,"mensaje"=>"Token CSRF inválido"],419);
    }

    $datos = json_decode(file_get_contents("php://input"), true);
    if (!is_array($datos)) {
        responderPago(["estado"=>false,"mensaje"=>"Datos de pago inválidos"],400);
    }

    $idPedido = (int)($datos["id_pedido"] ?? 0);
    $metodoPago = trim((string)($datos["metodo_pago"] ?? ""));
    $monto = (float)($datos["monto"] ?? 0);
    $estado = trim((string)($datos["estado_pago"] ?? "Pendiente"));
    $metodosValidos = ["Efectivo","Yape","Plin","Transferencia"];

    if ($idPedido <= 0 || !is_finite($monto) || $monto <= 0
        || !in_array($metodoPago, $metodosValidos, true)
        || !in_array($estado, ["Pendiente","Pagado","Rechazado"], true)) {
        responderPago(["estado"=>false,"mensaje"=>"Verifica el pedido, monto, método y estado"],422);
    }

    $conexion->begin_transaction();
    try {
        // Bloquear el pedido serializa las confirmaciones concurrentes.
        $stmt = $conexion->prepare(
            "SELECT id_pedido,total,estado_pedido
             FROM pedido WHERE id_pedido=? FOR UPDATE"
        );
        $stmt->bind_param("i",$idPedido);
        $stmt->execute();
        $pedido = $stmt->get_result()->fetch_assoc();
        if (!$pedido) {
            $conexion->rollback();
            responderPago(["estado"=>false,"mensaje"=>"Pedido no encontrado"],404);
        }

        if ((string)$pedido["estado_pedido"] === "Cancelado") {
            $conexion->rollback();
            responderPago(["estado"=>false,"mensaje"=>"No se aceptan pagos de pedidos cancelados"],409);
        }

        $stmt = $conexion->prepare(
            "SELECT COALESCE(SUM(monto),0) AS monto
             FROM pago WHERE id_pedido=? AND estado_pago='Pagado'"
        );
        $stmt->bind_param("i",$idPedido);
        $stmt->execute();
        $totalConfirmado = (float)$stmt->get_result()->fetch_assoc()["monto"];
        $totalPedido = (float)$pedido["total"];
        $saldo = max(0,round($totalPedido-$totalConfirmado,2));

        if ($monto > $totalPedido + 0.009 ||
            ($estado === "Pagado" && $monto > $saldo + 0.009)) {
            $conexion->rollback();
            responderPago([
                "estado"=>false,
                "mensaje"=>"El pago supera el saldo pendiente de S/ ".number_format($saldo,2)
            ],409);
        }

        $stmt = $conexion->prepare(
            "INSERT INTO pago(id_pedido,metodo_pago,monto,fecha_pago,estado_pago)
             VALUES (?,?,?,NOW(),?)"
        );
        $stmt->bind_param("isds",$idPedido,$metodoPago,$monto,$estado);
        $stmt->execute();
        $idPago = (int)$conexion->insert_id;

        $nuevoTotalConfirmado = $totalConfirmado + ($estado === "Pagado" ? $monto : 0);
        $saldoNuevo = max(0,round($totalPedido-$nuevoTotalConfirmado,2));
        $estadoPedido = (string)$pedido["estado_pedido"];

        // Solo se confirma todo el pedido cuando la suma de pagos lo cubre.
        // Nunca retroceder un envío ni una venta completada.
        if ($estado === "Pagado"
            && $saldoNuevo <= 0.009
            && !in_array($estadoPedido,["Pagado","Enviado","Completado"],true)) {
            $estadoPedido = "Pagado";
            $stmt = $conexion->prepare(
                "UPDATE pedido SET estado_pedido=? WHERE id_pedido=?"
            );
            $stmt->bind_param("si",$estadoPedido,$idPedido);
            $stmt->execute();
        }

        $conexion->commit();
        responderPago([
            "estado"=>true,
            "mensaje"=>"Pago registrado en MySQL",
            "id_pago"=>$idPago,
            "monto_confirmado"=>round($nuevoTotalConfirmado,2),
            "saldo_pendiente"=>$saldoNuevo,
            "estado_pedido"=>$estadoPedido
        ],201);
    } catch (Throwable $e) {
        $conexion->rollback();
        error_log("Pago API: ".$e->getMessage());
        responderPago(["estado"=>false,"mensaje"=>"No se pudo registrar el pago"],500);
    }
}

$idPedido = (int)($_GET["id_pedido"] ?? 0);

if ($idPedido > 0) {
    $stmt = $conexion->prepare("
        SELECT pg.*,u.nombres,u.apellidos
        FROM pago pg
        INNER JOIN pedido p ON pg.id_pedido=p.id_pedido
        INNER JOIN usuario u ON p.id_usuario=u.id_usuario
        WHERE pg.id_pedido=?
        ORDER BY pg.id_pago DESC
    ");
    $stmt->bind_param("i",$idPedido);
    $stmt->execute();
    $resultado = $stmt->get_result();
} else {
    $resultado = $conexion->query("
        SELECT pg.*,u.nombres,u.apellidos
        FROM pago pg
        INNER JOIN pedido p ON pg.id_pedido=p.id_pedido
        INNER JOIN usuario u ON p.id_usuario=u.id_usuario
        ORDER BY pg.id_pago DESC
    ");
}

$pagos = [];
while ($fila = $resultado->fetch_assoc()) $pagos[] = $fila;
echo json_encode($pagos, JSON_UNESCAPED_UNICODE);
