<?php

include("conexion.php");
require_once "sistema_bootstrap.php";

function responderPedido(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $datos = json_decode(file_get_contents("php://input"), true);

    if (!is_array($datos)) {
        responderPedido(["estado"=>false,"mensaje"=>"Datos de pedido inválidos"], 400);
    }

    $idUsuario = (int)($datos["id_usuario"] ?? 0);
    $idDireccion = !empty($datos["id_direccion"]) ? (int)$datos["id_direccion"] : null;
    $tipoEntrega = trim($datos["tipo_entrega"] ?? "Recojo en tienda");
    $estado = trim($datos["estado_pedido"] ?? "Pendiente");
    $items = $datos["items"] ?? [];

    $stmt = $conexion->prepare("
        SELECT id_usuario,estado
        FROM usuario
        WHERE id_usuario=?
        LIMIT 1
    ");
    $stmt->bind_param("i",$idUsuario);
    $stmt->execute();
    $usuario = $stmt->get_result()->fetch_assoc();

    if (!$usuario || ($usuario["estado"] ?? "Activo") !== "Activo") {
        responderPedido(["estado"=>false,"mensaje"=>"Usuario no disponible"], 403);
    }

    if (is_array($items) && count($items) > 0) {
        $conexion->begin_transaction();

        try {
            $lineas = [];
            $total = 0.0;

            foreach ($items as $item) {
                $idProducto = (int)($item["id_producto"] ?? 0);
                $cantidad = (int)($item["cantidad"] ?? 0);

                if ($idProducto <= 0 || $cantidad <= 0) {
                    throw new RuntimeException("Hay un producto con cantidad inválida");
                }

                $stmt = $conexion->prepare("
                    SELECT id_producto,nombre_producto,precio,stock
                    FROM producto
                    WHERE id_producto=?
                    FOR UPDATE
                ");
                $stmt->bind_param("i",$idProducto);
                $stmt->execute();
                $producto = $stmt->get_result()->fetch_assoc();

                if (!$producto) {
                    throw new RuntimeException("Producto no encontrado");
                }

                if ((int)$producto["stock"] < $cantidad) {
                    throw new RuntimeException(
                        "Stock insuficiente para " . $producto["nombre_producto"]
                    );
                }

                $precio = (float)$producto["precio"];
                $subtotal = round($precio * $cantidad, 2);
                $total += $subtotal;

                $lineas[] = [
                    "id_producto" => $idProducto,
                    "cantidad" => $cantidad,
                    "precio" => $precio,
                    "subtotal" => $subtotal,
                    "stock_anterior" => (int)$producto["stock"],
                    "stock_nuevo" => (int)$producto["stock"] - $cantidad,
                ];
            }

            $total = round($total, 2);

            if ($idDireccion !== null) {
                $stmt = $conexion->prepare("
                    INSERT INTO pedido
                    (id_usuario,fecha_pedido,estado_pedido,total,id_direccion,tipo_entrega)
                    VALUES (?,NOW(),?,?,?,?)
                ");
                $stmt->bind_param("isdis",$idUsuario,$estado,$total,$idDireccion,$tipoEntrega);
            } else {
                $stmt = $conexion->prepare("
                    INSERT INTO pedido
                    (id_usuario,fecha_pedido,estado_pedido,total,tipo_entrega)
                    VALUES (?,NOW(),?,?,?)
                ");
                $stmt->bind_param("isds",$idUsuario,$estado,$total,$tipoEntrega);
            }

            $stmt->execute();
            $idPedido = $conexion->insert_id;

            foreach ($lineas as $linea) {
                $stmt = $conexion->prepare("
                    INSERT INTO detalle_pedido
                    (id_pedido,id_producto,cantidad,precio_unitario,subtotal)
                    VALUES (?,?,?,?,?)
                ");
                $stmt->bind_param(
                    "iiidd",
                    $idPedido,
                    $linea["id_producto"],
                    $linea["cantidad"],
                    $linea["precio"],
                    $linea["subtotal"]
                );
                $stmt->execute();

                $stmt = $conexion->prepare("
                    UPDATE producto
                    SET stock=?
                    WHERE id_producto=?
                ");
                $stmt->bind_param("ii",$linea["stock_nuevo"],$linea["id_producto"]);
                $stmt->execute();

                $tipoSalida = "Salida";
                $motivo = "Pedido #" . $idPedido;
                $stmt = $conexion->prepare("
                    INSERT INTO movimiento_stock
                    (id_producto,tipo_movimiento,cantidad,motivo,fecha_movimiento,stock_anterior,stock_nuevo)
                    VALUES (?,?,?,?,NOW(),?,?)
                ");
                $stmt->bind_param(
                    "isisii",
                    $linea["id_producto"],
                    $tipoSalida,
                    $linea["cantidad"],
                    $motivo,
                    $linea["stock_anterior"],
                    $linea["stock_nuevo"]
                );
                $stmt->execute();
            }

            if (!empty($datos["metodo_pago"])) {
                $metodoPago = trim($datos["metodo_pago"]);
                $estadoPago = trim($datos["estado_pago"] ?? "Pendiente");

                $stmt = $conexion->prepare("
                    INSERT INTO pago
                    (id_pedido,metodo_pago,monto,fecha_pago,estado_pago)
                    VALUES (?,?,?,NOW(),?)
                ");
                $stmt->bind_param("isds",$idPedido,$metodoPago,$total,$estadoPago);
                $stmt->execute();
            }

            $conexion->commit();

            responderPedido([
                "estado" => true,
                "mensaje" => "Pedido registrado correctamente",
                "id_pedido" => $idPedido,
                "total" => $total
            ]);
        } catch (Throwable $e) {
            $conexion->rollback();
            responderPedido([
                "estado" => false,
                "mensaje" => $e->getMessage()
            ], 400);
        }
    }

    /* Compatibilidad con la versión anterior del frontend. */
    $total = (float)($datos["total"] ?? 0);

    if ($idUsuario <= 0 || $total < 0) {
        responderPedido(["estado"=>false,"mensaje"=>"Completa los datos del pedido"], 400);
    }

    $stmt = $conexion->prepare("
        INSERT INTO pedido
        (id_usuario,fecha_pedido,estado_pedido,total,tipo_entrega)
        VALUES (?,NOW(),?,?,?)
    ");
    $stmt->bind_param("isds",$idUsuario,$estado,$total,$tipoEntrega);

    if ($stmt->execute()) {
        responderPedido([
            "estado" => true,
            "mensaje" => "Pedido registrado",
            "id_pedido" => $conexion->insert_id,
            "total" => $total
        ]);
    }

    responderPedido(["estado"=>false,"mensaje"=>"Error al registrar pedido"], 500);
}

$idUsuarioFiltro = (int)($_GET["id_usuario"] ?? 0);

if ($idUsuarioFiltro > 0) {
    $stmt = $conexion->prepare("
        SELECT
            p.id_pedido,p.fecha_pedido,p.estado_pedido,p.total,p.tipo_entrega,p.id_direccion,
            u.id_usuario,u.nombres,u.apellidos
        FROM pedido p
        INNER JOIN usuario u ON p.id_usuario=u.id_usuario
        WHERE p.id_usuario=?
        ORDER BY p.id_pedido DESC
    ");
    $stmt->bind_param("i",$idUsuarioFiltro);
    $stmt->execute();
    $resultado = $stmt->get_result();
} else {
    $resultado = $conexion->query("
        SELECT
            p.id_pedido,p.fecha_pedido,p.estado_pedido,p.total,p.tipo_entrega,p.id_direccion,
            u.id_usuario,u.nombres,u.apellidos
        FROM pedido p
        INNER JOIN usuario u ON p.id_usuario=u.id_usuario
        ORDER BY p.id_pedido DESC
    ");
}

$pedidos = [];
while ($fila = $resultado->fetch_assoc()) {
    $pedidos[] = $fila;
}

echo json_encode($pedidos, JSON_UNESCAPED_UNICODE);
