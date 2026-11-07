<?php
include("conexion.php");

header("Content-Type: application/json; charset=UTF-8");

function responderMarca(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

$metodo = $_SERVER["REQUEST_METHOD"];

if ($metodo === "POST" || $metodo === "PUT") {
    $datos = json_decode(file_get_contents("php://input"), true);
    if (!is_array($datos)) {
        responderMarca(["estado"=>false,"mensaje"=>"Datos inválidos"], 400);
    }

    $nombre = trim($datos["nombre_marca"] ?? "");
    if ($nombre === "") {
        responderMarca(["estado"=>false,"mensaje"=>"Escribe el nombre de la marca"], 400);
    }

    if ($metodo === "POST") {
        $stmt = $conexion->prepare("INSERT INTO marca(nombre_marca) VALUES (?)");
        $stmt->bind_param("s",$nombre);
        if (!$stmt->execute()) {
            responderMarca(["estado"=>false,"mensaje"=>"No se pudo registrar la marca"], 409);
        }
        responderMarca([
            "estado"=>true,
            "mensaje"=>"Marca registrada",
            "id_marca"=>$conexion->insert_id
        ], 201);
    }

    $id = (int)($datos["id_marca"] ?? $_GET["id"] ?? 0);
    if ($id <= 0) {
        responderMarca(["estado"=>false,"mensaje"=>"Falta id_marca"], 400);
    }

    $stmt = $conexion->prepare("UPDATE marca SET nombre_marca=? WHERE id_marca=?");
    $stmt->bind_param("si",$nombre,$id);
    if (!$stmt->execute()) {
        responderMarca(["estado"=>false,"mensaje"=>"No se pudo actualizar la marca"], 409);
    }

    responderMarca(["estado"=>true,"mensaje"=>"Marca actualizada"]);
}

if ($metodo === "DELETE") {
    $datos = json_decode(file_get_contents("php://input"), true) ?: [];
    $id = (int)($datos["id_marca"] ?? $_GET["id"] ?? 0);
    if ($id <= 0) {
        responderMarca(["estado"=>false,"mensaje"=>"Falta id_marca"], 400);
    }

    $stmt = $conexion->prepare("SELECT COUNT(*) AS total FROM producto WHERE id_marca=?");
    $stmt->bind_param("i",$id);
    $stmt->execute();
    if ((int)$stmt->get_result()->fetch_assoc()["total"] > 0) {
        responderMarca(["estado"=>false,"mensaje"=>"La marca tiene productos asociados"], 409);
    }

    $stmt = $conexion->prepare("DELETE FROM marca WHERE id_marca=?");
    $stmt->bind_param("i",$id);
    $stmt->execute();

    responderMarca(["estado"=>true,"mensaje"=>"Marca eliminada"]);
}

$id = (int)($_GET["id"] ?? 0);
if ($id > 0) {
    $stmt = $conexion->prepare("SELECT * FROM marca WHERE id_marca=? LIMIT 1");
    $stmt->bind_param("i",$id);
    $stmt->execute();
    $fila = $stmt->get_result()->fetch_assoc();
    if (!$fila) responderMarca(["estado"=>false,"mensaje"=>"Marca no encontrada"], 404);
    echo json_encode($fila, JSON_UNESCAPED_UNICODE);
    exit;
}

$resultado = $conexion->query("SELECT * FROM marca ORDER BY nombre_marca");
$marcas = [];
while ($fila = $resultado->fetch_assoc()) $marcas[] = $fila;
echo json_encode($marcas, JSON_UNESCAPED_UNICODE);
