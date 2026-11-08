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

if ($metodo === "POST") {
    if (!puede("pagos") || !csrfValido($_SERVER["HTTP_X_CSRF_TOKEN"] ?? null)) {
        responderPago(["estado"=>false,"mensaje"=>"Permiso o token CSRF inválido"], 403);
    }
    $datos = json_decode(file_get_contents("php://input"), true);
    if (!is_array($datos)) {
        responderPago(["estado"=>false,"mensaje"=>"Datos inválidos"], 400);
    }

    $idPedido = (int)($datos["id_pedido"] ?? 0);
    $metodoPago = trim($datos["metodo_pago"] ?? "");
    $monto = (float)($datos["monto"] ?? 0);
    $estado = trim($datos["estado_pago"] ?? "Pendiente");

    if ($idPedido <= 0 || $metodoPago === "" || $monto < 0 ||
        !in_array($estado, ["Pendiente","Pagado","Rechazado"], true)) {
        responderPago(["estado"=>false,"mensaje"=>"Completa correctamente los datos del pago"], 400);
    }

    $stmt = $conexion->prepare("SELECT id_pedido FROM pedido WHERE id_pedido=? LIMIT 1");
    $stmt->bind_param("i",$idPedido);
    $stmt->execute();
    if (!$stmt->get_result()->fetch_assoc()) {
        responderPago(["estado"=>false,"mensaje"=>"Pedido no encontrado"], 404);
    }

    $stmt = $conexion->prepare("
        INSERT INTO pago(id_pedido,metodo_pago,monto,fecha_pago,estado_pago)
        VALUES (?,?,?,NOW(),?)
    ");
    $stmt->bind_param("isds",$idPedido,$metodoPago,$monto,$estado);

    $conexion->begin_transaction();
    try {
        if (!$stmt->execute()) {
            throw new RuntimeException("No se pudo registrar el pago");
        }
        $idPago = (int)$conexion->insert_id;

        if ($estado === "Pagado") {
            $stmtPedido = $conexion->prepare("
                UPDATE pedido
                SET estado_pedido='Pagado'
                WHERE id_pedido=? AND estado_pedido NOT IN ('Cancelado','Completado')
            ");
            $stmtPedido->bind_param("i",$idPedido);
            $stmtPedido->execute();
        }

        $conexion->commit();
        responderPago([
            "estado"=>true,
            "mensaje"=>"Pago registrado",
            "id_pago"=>$idPago
        ], 201);
    } catch (Throwable $e) {
        $conexion->rollback();
        responderPago(["estado"=>false,"mensaje"=>$e->getMessage()], 500);
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
