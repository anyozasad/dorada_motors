<?php

include("conexion.php");
require_once "sistema_bootstrap.php";

function responderProducto(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

$metodo = $_SERVER["REQUEST_METHOD"];

if ($metodo === "POST" || $metodo === "PUT") {
    $datos = json_decode(file_get_contents("php://input"), true);

    if (!is_array($datos)) {
        responderProducto(["estado"=>false,"mensaje"=>"Datos inválidos"], 400);
    }

    $idCategoria = (int)($datos["id_categoria"] ?? 0);
    $idMarca = (int)($datos["id_marca"] ?? 0);
    $nombre = trim($datos["nombre_producto"] ?? "");
    $descripcion = trim($datos["descripcion"] ?? "");
    $precio = (float)($datos["precio"] ?? 0);
    $stock = max(0, (int)($datos["stock"] ?? 0));
    $stockMinimo = max(0, (int)($datos["stock_minimo"] ?? 5));
    $imagen = trim($datos["imagen_url"] ?? "");

    if ($idCategoria <= 0 || $idMarca <= 0 || $nombre === "" || $precio < 0) {
        responderProducto(["estado"=>false,"mensaje"=>"Completa correctamente los datos del producto"], 400);
    }

    if ($metodo === "POST") {
        $stmt = $conexion->prepare("
            INSERT INTO producto
            (id_categoria,id_marca,nombre_producto,descripcion,precio,stock,stock_minimo,imagen_url)
            VALUES (?,?,?,?,?,?,?,?)
        ");
        $stmt->bind_param("iissdiis",$idCategoria,$idMarca,$nombre,$descripcion,$precio,$stock,$stockMinimo,$imagen);

        if ($stmt->execute()) {
            responderProducto([
                "estado"=>true,
                "mensaje"=>"Producto registrado",
                "id_producto"=>$conexion->insert_id
            ], 201);
        }

        responderProducto(["estado"=>false,"mensaje"=>"No se pudo registrar el producto"], 500);
    }

    $idProducto = (int)($datos["id_producto"] ?? $_GET["id"] ?? 0);
    if ($idProducto <= 0) {
        responderProducto(["estado"=>false,"mensaje"=>"Falta id_producto"], 400);
    }

    $stmt = $conexion->prepare("
        UPDATE producto
        SET id_categoria=?,id_marca=?,nombre_producto=?,descripcion=?,precio=?,stock=?,stock_minimo=?,imagen_url=?
        WHERE id_producto=?
    ");
    $stmt->bind_param("iissdiisi",$idCategoria,$idMarca,$nombre,$descripcion,$precio,$stock,$stockMinimo,$imagen,$idProducto);
    $stmt->execute();

    responderProducto(["estado"=>true,"mensaje"=>"Producto actualizado"]);
}

if ($metodo === "DELETE") {
    $datos = json_decode(file_get_contents("php://input"), true) ?: [];
    $idProducto = (int)($datos["id_producto"] ?? $_GET["id"] ?? 0);

    if ($idProducto <= 0) {
        responderProducto(["estado"=>false,"mensaje"=>"Falta id_producto"], 400);
    }

    $stmt = $conexion->prepare("
        SELECT
            (SELECT COUNT(*) FROM detalle_pedido WHERE id_producto=?) +
            (SELECT COUNT(*) FROM detalle_compra WHERE id_producto=?) AS usos
    ");
    $stmt->bind_param("ii",$idProducto,$idProducto);
    $stmt->execute();
    $usos = (int)$stmt->get_result()->fetch_assoc()["usos"];

    if ($usos > 0) {
        responderProducto([
            "estado"=>false,
            "mensaje"=>"No se puede eliminar un producto con movimientos"
        ], 409);
    }

    foreach (["favorito","detalle_carrito","movimiento_stock","carrito_favorito"] as $tabla) {
        $stmt = $conexion->prepare("DELETE FROM " . $tabla . " WHERE id_producto=?");
        if ($stmt) {
            $stmt->bind_param("i",$idProducto);
            $stmt->execute();
        }
    }

    $stmt = $conexion->prepare("DELETE FROM producto WHERE id_producto=?");
    $stmt->bind_param("i",$idProducto);
    $stmt->execute();

    responderProducto(["estado"=>true,"mensaje"=>"Producto eliminado"]);
}

$id = (int)($_GET["id"] ?? 0);

$sql = "
    SELECT
        p.id_producto,
        p.nombre_producto,
        p.descripcion,
        p.precio,
        p.stock,
        p.stock_minimo,
        p.imagen_url,
        c.id_categoria,
        c.nombre_categoria,
        m.id_marca,
        m.nombre_marca
    FROM producto p
    INNER JOIN categoria c ON p.id_categoria=c.id_categoria
    INNER JOIN marca m ON p.id_marca=m.id_marca
";

if ($id > 0) {
    $stmt = $conexion->prepare($sql . " WHERE p.id_producto=? LIMIT 1");
    $stmt->bind_param("i",$id);
    $stmt->execute();
    $producto = $stmt->get_result()->fetch_assoc();

    if (!$producto) {
        responderProducto(["estado"=>false,"mensaje"=>"Producto no encontrado"], 404);
    }

    echo json_encode($producto, JSON_UNESCAPED_UNICODE);
    exit;
}

$resultado = $conexion->query($sql . " ORDER BY p.id_producto DESC");
$productos = [];
while ($fila = $resultado->fetch_assoc()) {
    $productos[] = $fila;
}

echo json_encode($productos, JSON_UNESCAPED_UNICODE);
