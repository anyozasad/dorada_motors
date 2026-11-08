<?php

include("conexion.php");
require_once "sistema_bootstrap.php";

function responderProducto(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

$metodo = $_SERVER["REQUEST_METHOD"];

// Los catálogos públicos solo admiten lectura; la edición exige un
// administrador autenticado y el token CSRF de la sesión administrativa.
if (in_array($metodo, ["POST", "PUT", "DELETE"], true)) {
    require_once __DIR__ . "/auth_admin.php";
    if (!adminActual() || !puede("gestion-productos")) {
        http_response_code(403);
        echo json_encode(["estado"=>false,"mensaje"=>"Acceso administrativo requerido"], JSON_UNESCAPED_UNICODE);
        exit;
    }
    if (!csrfValido($_SERVER["HTTP_X_CSRF_TOKEN"] ?? null)) {
        http_response_code(419);
        echo json_encode(["estado"=>false,"mensaje"=>"Token de seguridad inválido"], JSON_UNESCAPED_UNICODE);
        exit;
    }
}

if ($metodo === "POST" || $metodo === "PUT") {
    $datos = json_decode(file_get_contents("php://input"),true);
    if (!is_array($datos)) {
        responderProducto(["estado"=>false,"mensaje"=>"Datos de producto inválidos"],400);
    }

    $idCategoria = (int)($datos["id_categoria"] ?? 0);
    $idMarca = (int)($datos["id_marca"] ?? 0);
    $nombre = trim((string)($datos["nombre_producto"] ?? ""));
    $descripcion = trim((string)($datos["descripcion"] ?? ""));
    $tipoVehiculo = trim((string)($datos["tipo_vehiculo"] ?? "Motocicleta / Motokar"));
    $compatibilidad = trim((string)($datos["compatibilidad"] ?? ""));
    $precio = (float)($datos["precio"] ?? 0);
    $precioOferta = (float)($datos["precio_oferta"] ?? 0);
    $stock = (int)($datos["stock"] ?? 0);
    $stockMinimo = (int)($datos["stock_minimo"] ?? 5);
    $imagen = trim((string)($datos["imagen_url"] ?? ""));

    if ($idCategoria<=0 || $idMarca<=0 || $nombre===""
        || strlen($nombre)>180 || !is_finite($precio) || $precio<=0
        || !is_finite($precioOferta) || $precioOferta<0
        || ($precioOferta>0 && $precioOferta>=$precio)
        || $stock<0 || $stockMinimo<0) {
        responderProducto([
            "estado"=>false,
            "mensaje"=>"Verifica nombre, categoría, marca, precio, oferta y stock no negativo"
        ],422);
    }

    $idProducto = (int)($datos["id_producto"] ?? $_GET["id"] ?? 0);
    if ($metodo==="PUT" && $idProducto<=0) {
        responderProducto(["estado"=>false,"mensaje"=>"Falta id_producto"],422);
    }

    $conexion->begin_transaction();
    try {
        if ($metodo==="POST") {
            $stmt=$conexion->prepare(
                "INSERT INTO producto
                 (id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,
                  compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
                 VALUES (?,?,?,?,?,?,?,NULLIF(?,0),?,?,?)"
            );
            $stmt->bind_param(
                "iissssddiis",$idCategoria,$idMarca,$nombre,$descripcion,
                $tipoVehiculo,$compatibilidad,$precio,$precioOferta,
                $stock,$stockMinimo,$imagen
            );
            $stmt->execute();
            $idProducto=(int)$conexion->insert_id;
            $stockAnterior=0;
            $motivo="Stock inicial por API";
        } else {
            $stmt=$conexion->prepare(
                "SELECT stock FROM producto WHERE id_producto=? FOR UPDATE"
            );
            $stmt->bind_param("i",$idProducto);
            $stmt->execute();
            $fila=$stmt->get_result()->fetch_assoc();
            if (!$fila) {
                $conexion->rollback();
                responderProducto(["estado"=>false,"mensaje"=>"Producto no encontrado"],404);
            }
            $stockAnterior=(int)$fila["stock"];
            $motivo="Ajuste de stock por API";
            $stmt=$conexion->prepare(
                "UPDATE producto SET
                   id_categoria=?,id_marca=?,nombre_producto=?,descripcion=?,
                   tipo_vehiculo=?,compatibilidad=?,precio=?,
                   precio_oferta=NULLIF(?,0),stock=?,stock_minimo=?,imagen_url=?
                 WHERE id_producto=?"
            );
            $stmt->bind_param(
                "iissssddiisi",$idCategoria,$idMarca,$nombre,$descripcion,
                $tipoVehiculo,$compatibilidad,$precio,$precioOferta,$stock,
                $stockMinimo,$imagen,$idProducto
            );
            $stmt->execute();
        }

        if ($stock!==$stockAnterior) {
            $tipo=$stock>$stockAnterior ? "Entrada" : "Salida";
            $cantidad=abs($stock-$stockAnterior);
            $stmt=$conexion->prepare(
                "INSERT INTO movimiento_stock
                 (id_producto,tipo_movimiento,cantidad,motivo,fecha_movimiento,
                  stock_anterior,stock_nuevo)
                 VALUES (?,?,?,?,NOW(),?,?)"
            );
            $stmt->bind_param(
                "isisii",$idProducto,$tipo,$cantidad,$motivo,$stockAnterior,$stock
            );
            $stmt->execute();
        }

        $conexion->commit();
        responderProducto([
            "estado"=>true,
            "mensaje"=>$metodo==="POST" ? "Producto registrado" : "Producto actualizado",
            "id_producto"=>$idProducto
        ],$metodo==="POST" ? 201 : 200);
    } catch (Throwable $e) {
        $conexion->rollback();
        error_log("Producto API: ".$e->getMessage());
        $codigo=(int)$e->getCode();
        responderProducto([
            "estado"=>false,
            "mensaje"=>in_array($codigo,[1062,1452],true)
                ? "Categoría, marca o datos de producto inválidos"
                : "No se pudo guardar el producto"
        ],in_array($codigo,[1062,1452],true) ? 422 : 500);
    }
}

if ($metodo === "DELETE") {
    $datos=json_decode(file_get_contents("php://input"),true) ?: [];
    $idProducto=(int)($datos["id_producto"] ?? $_GET["id"] ?? 0);
    if ($idProducto<=0) {
        responderProducto(["estado"=>false,"mensaje"=>"Falta id_producto"],422);
    }

    $conexion->begin_transaction();
    try {
        $stmt=$conexion->prepare(
            "SELECT id_producto FROM producto WHERE id_producto=? FOR UPDATE"
        );
        $stmt->bind_param("i",$idProducto);
        $stmt->execute();
        if (!$stmt->get_result()->fetch_assoc()) {
            $conexion->rollback();
            responderProducto(["estado"=>false,"mensaje"=>"Producto no encontrado"],404);
        }

        $stmt=$conexion->prepare(
            "SELECT
               (SELECT COUNT(*) FROM detalle_pedido WHERE id_producto=?) +
               (SELECT COUNT(*) FROM detalle_compra WHERE id_producto=?) AS total"
        );
        $stmt->bind_param("ii",$idProducto,$idProducto);
        $stmt->execute();
        if ((int)$stmt->get_result()->fetch_assoc()["total"]>0) {
            $conexion->rollback();
            responderProducto([
                "estado"=>false,
                "mensaje"=>"No se puede eliminar un producto ligado a pedidos o compras"
            ],409);
        }

        $stmt=$conexion->prepare("DELETE FROM movimiento_stock WHERE id_producto=?");
        $stmt->bind_param("i",$idProducto);
        $stmt->execute();
        $stmt=$conexion->prepare("DELETE FROM producto WHERE id_producto=?");
        $stmt->bind_param("i",$idProducto);
        $stmt->execute();
        $conexion->commit();
        responderProducto(["estado"=>true,"mensaje"=>"Producto eliminado"]);
    } catch (Throwable $e) {
        $conexion->rollback();
        error_log("Eliminar producto API: ".$e->getMessage());
        responderProducto(["estado"=>false,"mensaje"=>"No se pudo eliminar el producto"],500);
    }
}

$id = (int)($_GET["id"] ?? 0);

$sql = "
    SELECT
        p.id_producto,
        p.nombre_producto,
        p.descripcion,
        p.tipo_vehiculo,
        p.compatibilidad,
        p.precio,
        p.precio_oferta,
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
