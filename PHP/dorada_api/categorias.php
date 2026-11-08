<?php
include("conexion.php");

header("Content-Type: application/json; charset=UTF-8");

function responderCategoria(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

$metodo = $_SERVER["REQUEST_METHOD"];

// Los catálogos públicos solo admiten lectura; la edición exige un
// administrador autenticado y el token CSRF de la sesión administrativa.
if (in_array($metodo, ["POST", "PUT", "DELETE"], true)) {
    require_once __DIR__ . "/auth_admin.php";
    if (!adminActual() || !puede("categorias")) {
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
    $datos = json_decode(file_get_contents("php://input"), true);
    if (!is_array($datos)) {
        responderCategoria(["estado"=>false,"mensaje"=>"Datos inválidos"], 400);
    }

    $nombre = trim($datos["nombre_categoria"] ?? "");
    if ($nombre === "") {
        responderCategoria(["estado"=>false,"mensaje"=>"Escribe el nombre de la categoría"], 400);
    }

    if ($metodo === "POST") {
        $stmt = $conexion->prepare("INSERT INTO categoria(nombre_categoria) VALUES (?)");
        $stmt->bind_param("s",$nombre);
        if (!$stmt->execute()) {
            responderCategoria(["estado"=>false,"mensaje"=>"No se pudo registrar la categoría"], 409);
        }
        responderCategoria([
            "estado"=>true,
            "mensaje"=>"Categoría registrada",
            "id_categoria"=>$conexion->insert_id
        ], 201);
    }

    $id = (int)($datos["id_categoria"] ?? $_GET["id"] ?? 0);
    if ($id <= 0) {
        responderCategoria(["estado"=>false,"mensaje"=>"Falta id_categoria"], 400);
    }

    $stmt = $conexion->prepare("UPDATE categoria SET nombre_categoria=? WHERE id_categoria=?");
    $stmt->bind_param("si",$nombre,$id);
    if (!$stmt->execute()) {
        responderCategoria(["estado"=>false,"mensaje"=>"No se pudo actualizar la categoría"], 409);
    }

    responderCategoria(["estado"=>true,"mensaje"=>"Categoría actualizada"]);
}

if ($metodo === "DELETE") {
    $datos = json_decode(file_get_contents("php://input"), true) ?: [];
    $id = (int)($datos["id_categoria"] ?? $_GET["id"] ?? 0);
    if ($id <= 0) {
        responderCategoria(["estado"=>false,"mensaje"=>"Falta id_categoria"], 400);
    }

    $stmt = $conexion->prepare("SELECT COUNT(*) AS total FROM producto WHERE id_categoria=?");
    $stmt->bind_param("i",$id);
    $stmt->execute();
    if ((int)$stmt->get_result()->fetch_assoc()["total"] > 0) {
        responderCategoria(["estado"=>false,"mensaje"=>"La categoría tiene productos asociados"], 409);
    }

    $stmt = $conexion->prepare("DELETE FROM categoria WHERE id_categoria=?");
    $stmt->bind_param("i",$id);
    $stmt->execute();

    responderCategoria(["estado"=>true,"mensaje"=>"Categoría eliminada"]);
}

$id = (int)($_GET["id"] ?? 0);
if ($id > 0) {
    $stmt = $conexion->prepare("SELECT * FROM categoria WHERE id_categoria=? LIMIT 1");
    $stmt->bind_param("i",$id);
    $stmt->execute();
    $fila = $stmt->get_result()->fetch_assoc();
    if (!$fila) responderCategoria(["estado"=>false,"mensaje"=>"Categoría no encontrada"], 404);
    echo json_encode($fila, JSON_UNESCAPED_UNICODE);
    exit;
}

$resultado = $conexion->query("SELECT * FROM categoria ORDER BY nombre_categoria");
$categorias = [];
while ($fila = $resultado->fetch_assoc()) $categorias[] = $fila;
echo json_encode($categorias, JSON_UNESCAPED_UNICODE);
