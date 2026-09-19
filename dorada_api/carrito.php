<?php

include("conexion.php");
require_once "sistema_bootstrap.php";

function responderCarrito(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function obtenerCarritoActivo(mysqli $conexion, int $idUsuario): int {
    $stmt = $conexion->prepare("
        SELECT id_carrito
        FROM carrito
        WHERE id_usuario=? AND estado='Activo'
        ORDER BY id_carrito DESC
        LIMIT 1
    ");
    $stmt->bind_param("i",$idUsuario);
    $stmt->execute();
    $fila = $stmt->get_result()->fetch_assoc();

    if ($fila) return (int)$fila["id_carrito"];

    $estado = "Activo";
    $stmt = $conexion->prepare("
        INSERT INTO carrito (id_usuario,estado,fecha_creacion)
        VALUES (?,?,NOW())
    ");
    $stmt->bind_param("is",$idUsuario,$estado);
    $stmt->execute();

    return (int)$conexion->insert_id;
}

$metodo = $_SERVER["REQUEST_METHOD"];

if ($metodo === "POST" || $metodo === "PUT") {
    $datos = json_decode(file_get_contents("php://input"), true);

    if (!is_array($datos)) {
        responderCarrito(["estado"=>false,"mensaje"=>"Datos inválidos"], 400);
    }

    $idUsuario = (int)($datos["id_usuario"] ?? 0);
    $idProducto = (int)($datos["id_producto"] ?? 0);
    $cantidad = (int)($datos["cantidad"] ?? 1);

    if ($idUsuario <= 0 || $idProducto <= 0 || $cantidad <= 0) {
        responderCarrito(["estado"=>false,"mensaje"=>"Datos incompletos"], 400);
    }

    $stmt = $conexion->prepare("SELECT stock FROM producto WHERE id_producto=? LIMIT 1");
    $stmt->bind_param("i",$idProducto);
    $stmt->execute();
    $producto = $stmt->get_result()->fetch_assoc();

    if (!$producto) {
        responderCarrito(["estado"=>false,"mensaje"=>"Producto no encontrado"], 404);
    }

    if ($cantidad > (int)$producto["stock"]) {
        responderCarrito(["estado"=>false,"mensaje"=>"La cantidad supera el stock disponible"], 409);
    }

    $idCarrito = obtenerCarritoActivo($conexion,$idUsuario);

    $stmt = $conexion->prepare("
        INSERT INTO detalle_carrito (id_carrito,id_producto,cantidad)
        VALUES (?,?,?)
        ON DUPLICATE KEY UPDATE cantidad=VALUES(cantidad)
    ");
    $stmt->bind_param("iii",$idCarrito,$idProducto,$cantidad);
    $stmt->execute();

    responderCarrito([
        "estado"=>true,
        "mensaje"=>"Carrito actualizado",
        "id_carrito"=>$idCarrito
    ]);
}

if ($metodo === "DELETE") {
    $datos = json_decode(file_get_contents("php://input"), true) ?: [];
    $idUsuario = (int)($datos["id_usuario"] ?? $_GET["id_usuario"] ?? 0);
    $idProducto = (int)($datos["id_producto"] ?? $_GET["id_producto"] ?? 0);
    $vaciar = !empty($datos["vaciar"]) || ($_GET["vaciar"] ?? "") === "1";

    if ($idUsuario <= 0) {
        responderCarrito(["estado"=>false,"mensaje"=>"Falta id_usuario"], 400);
    }

    $idCarrito = obtenerCarritoActivo($conexion,$idUsuario);

    if ($vaciar) {
        $stmt = $conexion->prepare("DELETE FROM detalle_carrito WHERE id_carrito=?");
        $stmt->bind_param("i",$idCarrito);
        $stmt->execute();
        responderCarrito(["estado"=>true,"mensaje"=>"Carrito vaciado"]);
    }

    if ($idProducto <= 0) {
        responderCarrito(["estado"=>false,"mensaje"=>"Falta id_producto"], 400);
    }

    $stmt = $conexion->prepare("
        DELETE FROM detalle_carrito
        WHERE id_carrito=? AND id_producto=?
    ");
    $stmt->bind_param("ii",$idCarrito,$idProducto);
    $stmt->execute();

    responderCarrito(["estado"=>true,"mensaje"=>"Producto eliminado del carrito"]);
}

$idUsuario = (int)($_GET["id_usuario"] ?? 0);

if ($idUsuario <= 0) {
    responderCarrito(["estado"=>false,"mensaje"=>"Falta id_usuario"], 400);
}

$idCarrito = obtenerCarritoActivo($conexion,$idUsuario);

$stmt = $conexion->prepare("
    SELECT
        dc.id_detalle_carrito,
        dc.cantidad,
        p.id_producto,
        p.nombre_producto,
        p.precio,
        p.stock,
        p.imagen_url,
        m.nombre_marca,
        c.nombre_categoria,
        (dc.cantidad * p.precio) AS subtotal
    FROM detalle_carrito dc
    INNER JOIN producto p ON dc.id_producto=p.id_producto
    INNER JOIN marca m ON p.id_marca=m.id_marca
    INNER JOIN categoria c ON p.id_categoria=c.id_categoria
    WHERE dc.id_carrito=?
    ORDER BY dc.id_detalle_carrito DESC
");
$stmt->bind_param("i",$idCarrito);
$stmt->execute();
$resultado = $stmt->get_result();

$items = [];
$total = 0.0;
while ($fila = $resultado->fetch_assoc()) {
    $items[] = $fila;
    $total += (float)$fila["subtotal"];
}

echo json_encode([
    "estado"=>true,
    "id_carrito"=>$idCarrito,
    "items"=>$items,
    "total"=>round($total,2)
], JSON_UNESCAPED_UNICODE);
