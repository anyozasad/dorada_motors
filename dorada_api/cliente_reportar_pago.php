<?php
declare(strict_types=1);

require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/sistema_bootstrap.php";
require_once __DIR__ . "/cliente_auth.php";

header("Content-Type: application/json; charset=UTF-8");
header("Cache-Control: no-store");

function responderReferencia(array $data, int $codigo = 200): void {
    http_response_code($codigo);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

if (($_SERVER["REQUEST_METHOD"] ?? "") !== "POST") {
    responderReferencia(["estado"=>false,"mensaje"=>"Método no permitido"],405);
}

$idCliente = requerirClienteApi($conexion);
$datos = json_decode(file_get_contents("php://input"), true);
$idPedido = is_array($datos) ? (int)($datos["id_pedido"] ?? 0) : 0;
$referencia = is_array($datos) ? trim((string)($datos["referencia"] ?? "")) : "";

if ($idPedido <= 0 || !preg_match('/^[A-Za-z0-9][A-Za-z0-9 -]{5,79}$/', $referencia)) {
    responderReferencia([
        "estado"=>false,
        "mensaje"=>"Ingresa un número de operación válido (6 a 80 caracteres alfanuméricos)"
    ],422);
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
        responderReferencia(["estado"=>false,"mensaje"=>"Pedido no encontrado"],404);
    }
    if (!in_array($pedido["estado_pedido"],["Pendiente","Procesando"],true)) {
        $conexion->rollback();
        responderReferencia([
            "estado"=>false,
            "mensaje"=>"Este pedido ya no admite referencias de pago."
        ],409);
    }

    $stmt = $conexion->prepare(
        "SELECT id_pago,metodo_pago FROM pago
         WHERE id_pedido=? AND estado_pago='Pendiente'
         ORDER BY id_pago DESC LIMIT 1 FOR UPDATE"
    );
    $stmt->bind_param("i",$idPedido);
    $stmt->execute();
    $pago = $stmt->get_result()->fetch_assoc();
    if (!$pago || !in_array($pago["metodo_pago"],["Yape","Plin","Transferencia"],true)) {
        $conexion->rollback();
        responderReferencia([
            "estado"=>false,
            "mensaje"=>"No hay un pago digital pendiente para este pedido."
        ],409);
    }

    $idPago = (int)$pago["id_pago"];
    $stmt = $conexion->prepare(
        "UPDATE pago SET referencia_cliente=?,fecha_referencia=NOW()
         WHERE id_pago=? AND estado_pago='Pendiente'"
    );
    $stmt->bind_param("si",$referencia,$idPago);
    $stmt->execute();
    $conexion->commit();

    responderReferencia([
        "estado"=>true,
        "mensaje"=>"Referencia enviada. El administrador debe verificar el pago.",
        "estado_pago"=>"Pendiente",
        "id_pago"=>$idPago,
        "referencia"=>$referencia
    ]);
} catch (Throwable $e) {
    $conexion->rollback();
    error_log("Dorada Motors referencia de pago: ".$e->getMessage());
    responderReferencia([
        "estado"=>false,
        "mensaje"=>"No se pudo registrar la referencia de pago."
    ],500);
}
