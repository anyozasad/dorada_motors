<?php

include("conexion.php");
require_once "sistema_bootstrap.php";

function responderFavorito(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

$metodo = $_SERVER["REQUEST_METHOD"];

if ($metodo === "POST") {
    $datos = json_decode(file_get_contents("php://input"), true);

    if (!is_array($datos)) {
        responderFavorito(["estado"=>false,"mensaje"=>"Datos inválidos"], 400);
    }

    $idUsuario = (int)($datos["id_usuario"] ?? 0);
    $idProducto = (int)($datos["id_producto"] ?? 0);
    $accion = strtolower(trim($datos["accion"] ?? "agregar"));

    if ($idUsuario <= 0 || $idProducto <= 0) {
        responderFavorito(["estado"=>false,"mensaje"=>"Faltan usuario o producto"], 400);
    }

    if ($accion === "quitar" || $accion === "eliminar") {
        $stmt = $conexion->prepare("DELETE FROM favorito WHERE id_usuario=? AND id_producto=?");
        $stmt->bind_param("ii",$idUsuario,$idProducto);
        $stmt->execute();

        responderFavorito(["estado"=>true,"mensaje"=>"Favorito eliminado"]);
    }

    $stmt = $conexion->prepare("
        INSERT IGNORE INTO favorito (id_usuario,id_producto,fecha_registro)
        VALUES (?,?,NOW())
    ");
    $stmt->bind_param("ii",$idUsuario,$idProducto);
    $stmt->execute();

    responderFavorito(["estado"=>true,"mensaje"=>"Producto guardado en favoritos"]);
}

if ($metodo === "DELETE") {
    $datos = json_decode(file_get_contents("php://input"), true) ?: [];
    $idUsuario = (int)($datos["id_usuario"] ?? $_GET["id_usuario"] ?? 0);
    $idProducto = (int)($datos["id_producto"] ?? $_GET["id_producto"] ?? 0);

    if ($idUsuario <= 0 || $idProducto <= 0) {
        responderFavorito(["estado"=>false,"mensaje"=>"Faltan usuario o producto"], 400);
    }

    $stmt = $conexion->prepare("DELETE FROM favorito WHERE id_usuario=? AND id_producto=?");
    $stmt->bind_param("ii",$idUsuario,$idProducto);
    $stmt->execute();

    responderFavorito(["estado"=>true,"mensaje"=>"Favorito eliminado"]);
}

$idUsuario = (int)($_GET["id_usuario"] ?? 0);

if ($idUsuario > 0) {
    $stmt = $conexion->prepare("
        SELECT
            f.id_favorito,
            f.id_usuario,
            f.fecha_registro,
            p.id_producto,
            p.nombre_producto,
            p.precio,
            p.stock,
            p.imagen_url,
            m.nombre_marca,
            c.nombre_categoria
        FROM favorito f
        INNER JOIN producto p ON f.id_producto=p.id_producto
        INNER JOIN marca m ON p.id_marca=m.id_marca
        INNER JOIN categoria c ON p.id_categoria=c.id_categoria
        WHERE f.id_usuario=?
        ORDER BY f.id_favorito DESC
    ");
    $stmt->bind_param("i",$idUsuario);
    $stmt->execute();
    $resultado = $stmt->get_result();
} else {
    $resultado = $conexion->query("
        SELECT
            f.id_favorito,
            f.id_usuario,
            f.fecha_registro,
            p.id_producto,
            p.nombre_producto,
            p.precio,
            p.stock,
            p.imagen_url,
            m.nombre_marca,
            c.nombre_categoria
        FROM favorito f
        INNER JOIN producto p ON f.id_producto=p.id_producto
        INNER JOIN marca m ON p.id_marca=m.id_marca
        INNER JOIN categoria c ON p.id_categoria=c.id_categoria
        ORDER BY f.id_favorito DESC
    ");
}

$datos = [];
while ($fila = $resultado->fetch_assoc()) {
    $datos[] = $fila;
}

echo json_encode($datos, JSON_UNESCAPED_UNICODE);
