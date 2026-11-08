<?php
declare(strict_types=1);

require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/sistema_bootstrap.php";
require_once __DIR__ . "/cliente_auth.php";
require_once __DIR__ . "/empresa_config.php";

header("Content-Type: application/json; charset=UTF-8");
header("Cache-Control: no-store");

function responderComprobanteCliente(array $data, int $codigo = 200): void {
    http_response_code($codigo);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

if (($_SERVER["REQUEST_METHOD"] ?? "") !== "GET") {
    responderComprobanteCliente(["estado"=>false,"mensaje"=>"Método no permitido"],405);
}

$idUsuario = requerirClienteApi($conexion);
$idPedido = (int)($_GET["id_pedido"] ?? 0);
if ($idPedido <= 0) {
    responderComprobanteCliente(["estado"=>false,"mensaje"=>"Pedido inválido"],422);
}

// La factura solo puede consultarla el cliente dueño del pedido.
// No aceptar id_usuario proporcionado por el navegador.
$stmt = $conexion->prepare(
    "SELECT c.id_comprobante,c.tipo_comprobante,c.numero_comprobante,
            c.fecha_emision,c.subtotal,c.igv,c.total,
            p.id_pedido,p.tipo_entrega,
            u.nombres,u.apellidos,u.correo
     FROM comprobante c
     INNER JOIN pedido p ON p.id_pedido=c.id_pedido
     INNER JOIN usuario u ON u.id_usuario=p.id_usuario
     WHERE p.id_pedido=? AND p.id_usuario=? LIMIT 1"
);
$stmt->bind_param("ii",$idPedido,$idUsuario);
$stmt->execute();
$comprobante = $stmt->get_result()->fetch_assoc();
if (!$comprobante) {
    responderComprobanteCliente([
        "estado"=>false,
        "mensaje"=>"No existe un comprobante emitido para este pedido"
    ],404);
}

$stmt = $conexion->prepare(
    "SELECT d.cantidad,d.precio_unitario,d.subtotal,pr.nombre_producto
     FROM detalle_pedido d
     INNER JOIN producto pr ON pr.id_producto=d.id_producto
     WHERE d.id_pedido=?
     ORDER BY d.id_detalle ASC"
);
$stmt->bind_param("i",$idPedido);
$stmt->execute();
$items = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

$config = cargarConfigEmpresa();
responderComprobanteCliente([
    "estado"=>true,
    "comprobante"=>$comprobante,
    "items"=>$items,
    "empresa"=>[
        "nombre_comercial"=>(string)($config["nombre_comercial"] ?? "Dorada Motors"),
        "razon_social"=>(string)($config["razon_social"] ?? "ADN Import's"),
        "ruc"=>(string)($config["ruc"] ?? ""),
        "direccion"=>(string)($config["direccion"] ?? ""),
        "moneda"=>(string)($config["moneda"] ?? "S/"),
    ],
    "advertencia"=>"Comprobante de demostración. No equivale a un comprobante electrónico validado por SUNAT."
]);
