<?php
include("conexion.php");
require_once "sistema_bootstrap.php";
require_once "empresa_config.php";
require_once __DIR__ . "/cliente_auth.php";

header("Content-Type: application/json; charset=UTF-8");

function responderPedido(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function pedidoRegistradoPorClave(mysqli $conexion, int $idUsuario, ?string $clave): ?array {
    if ($clave === null) return null;
    $stmt = $conexion->prepare(
        "SELECT p.id_pedido,p.total,
                COALESCE(SUM(dp.subtotal),0) AS subtotal
         FROM pedido p
         LEFT JOIN detalle_pedido dp ON dp.id_pedido=p.id_pedido
         WHERE p.id_usuario=? AND p.clave_operacion=?
         GROUP BY p.id_pedido,p.total LIMIT 1"
    );
    $stmt->bind_param("is", $idUsuario, $clave);
    $stmt->execute();
    $fila = $stmt->get_result()->fetch_assoc();
    if (!$fila) return null;
    return [
        "estado" => true,
        "mensaje" => "Pedido registrado anteriormente; no se repitió la compra",
        "id_pedido" => (int)$fila["id_pedido"],
        "subtotal_productos" => round((float)$fila["subtotal"],2),
        "costo_entrega" => round((float)$fila["total"] - (float)$fila["subtotal"],2),
        "total" => (float)$fila["total"],
        "reutilizado" => true
    ];
}

$metodo = $_SERVER["REQUEST_METHOD"];

if ($metodo === "POST") {
    $datos = json_decode(file_get_contents("php://input"), true);

    if (!is_array($datos)) {
        responderPedido(["estado"=>false,"mensaje"=>"Datos de pedido inválidos"], 400);
    }

    $idUsuario = (int)($datos["id_usuario"] ?? 0);
    requerirClienteApi($conexion, $idUsuario);
    $claveOperacion = isset($datos["clave_operacion"])
        ? trim((string)$datos["clave_operacion"]) : null;
    if ($claveOperacion === "") $claveOperacion = null;
    if ($claveOperacion !== null && !preg_match('/^[a-zA-Z0-9_-]{16,64}$/', $claveOperacion)) {
        responderPedido(["estado"=>false,"mensaje"=>"Identificador de compra inválido"],422);
    }
    $pedidoAnterior = pedidoRegistradoPorClave($conexion,$idUsuario,$claveOperacion);
    if ($pedidoAnterior !== null) responderPedido($pedidoAnterior);

    $idDireccion = !empty($datos["id_direccion"]) ? (int)$datos["id_direccion"] : null;
    $tipoEntrega = trim((string)($datos["tipo_entrega"] ?? "Recojo en tienda"));
    $items = $datos["items"] ?? [];
    $metodoPago = trim((string)($datos["metodo_pago"] ?? "Efectivo"));

    if ($idUsuario <= 0 || !is_array($items) || count($items) === 0) {
        responderPedido(["estado"=>false,"mensaje"=>"El pedido debe incluir cliente y productos"], 400);
    }

    if (!in_array($tipoEntrega, ["Recojo en tienda","Delivery"], true)) {
        responderPedido(["estado"=>false,"mensaje"=>"Tipo de entrega inválido"], 400);
    }

    if (!in_array($metodoPago, ["Efectivo","Yape","Plin","Transferencia"], true)) {
        responderPedido(["estado"=>false,"mensaje"=>"Método de pago inválido"], 400);
    }

    $stmt = $conexion->prepare("
        SELECT id_usuario,estado
        FROM usuario
        WHERE id_usuario=?
          AND rol_sistema='Cliente'
        LIMIT 1
    ");
    $stmt->bind_param("i",$idUsuario);
    $stmt->execute();
    $usuario = $stmt->get_result()->fetch_assoc();

    if (!$usuario || (string)$usuario["estado"] !== "Activo") {
        responderPedido(["estado"=>false,"mensaje"=>"Cliente no disponible"], 403);
    }

    if ($tipoEntrega === "Delivery") {
        if (!$idDireccion) {
            responderPedido(["estado"=>false,"mensaje"=>"Selecciona una dirección para el delivery"], 400);
        }

        $stmt = $conexion->prepare("
            SELECT id_direccion
            FROM direccion
            WHERE id_direccion=? AND id_usuario=?
            LIMIT 1
        ");
        $stmt->bind_param("ii",$idDireccion,$idUsuario);
        $stmt->execute();

        if (!$stmt->get_result()->fetch_assoc()) {
            responderPedido(["estado"=>false,"mensaje"=>"La dirección no pertenece al cliente"], 400);
        }
    } else {
        $idDireccion = null;
    }

    $cantidadesPorProducto = [];
    foreach ($items as $item) {
        if (!is_array($item)) {
            responderPedido(["estado"=>false,"mensaje"=>"Producto de pedido inválido"], 400);
        }

        $idProducto = (int)($item["id_producto"] ?? 0);
        $cantidad = (int)($item["cantidad"] ?? 0);

        if ($idProducto <= 0 || $cantidad <= 0) {
            responderPedido(["estado"=>false,"mensaje"=>"Hay un producto con cantidad inválida"], 400);
        }

        $cantidadesPorProducto[$idProducto] = ($cantidadesPorProducto[$idProducto] ?? 0) + $cantidad;
    }

    $config = cargarConfigEmpresa();
    $costoEntrega = $tipoEntrega === "Delivery"
        ? max(0, (float)($config["costo_delivery"] ?? 0))
        : 0.0;

    $conexion->begin_transaction();

    try {
        $lineas = [];
        $totalProductos = 0.0;

        foreach ($cantidadesPorProducto as $idProducto => $cantidad) {
            $stmt = $conexion->prepare("
                SELECT
                    id_producto,
                    nombre_producto,
                    precio,
                    precio_oferta,
                    stock
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
                throw new RuntimeException("Stock insuficiente para " . $producto["nombre_producto"]);
            }

            $precioBase = (float)$producto["precio"];
            $precioOferta = isset($producto["precio_oferta"]) ? (float)$producto["precio_oferta"] : 0;
            $precio = ($precioOferta > 0 && $precioOferta < $precioBase) ? $precioOferta : $precioBase;
            $subtotal = round($precio * $cantidad, 2);
            $totalProductos += $subtotal;

            $lineas[] = [
                "id_producto" => (int)$idProducto,
                "cantidad" => (int)$cantidad,
                "precio" => $precio,
                "subtotal" => $subtotal,
                "stock_anterior" => (int)$producto["stock"],
                "stock_nuevo" => (int)$producto["stock"] - $cantidad,
            ];
        }

        $total = round($totalProductos + $costoEntrega, 2);
        $estadoPedido = "Pendiente";

        if ($idDireccion !== null) {
            $stmt = $conexion->prepare("
                INSERT INTO pedido
                (id_usuario,clave_operacion,fecha_pedido,estado_pedido,total,id_direccion,tipo_entrega)
                VALUES (?,?,NOW(),?,?,?,?)
            ");
            $stmt->bind_param("issdis",$idUsuario,$claveOperacion,$estadoPedido,$total,$idDireccion,$tipoEntrega);
        } else {
            $stmt = $conexion->prepare("
                INSERT INTO pedido
                (id_usuario,clave_operacion,fecha_pedido,estado_pedido,total,tipo_entrega)
                VALUES (?,?,NOW(),?,?,?)
            ");
            $stmt->bind_param("issds",$idUsuario,$claveOperacion,$estadoPedido,$total,$tipoEntrega);
        }

        $stmt->execute();
        $idPedido = (int)$conexion->insert_id;

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

            $stmt = $conexion->prepare("UPDATE producto SET stock=? WHERE id_producto=?");
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

        $estadoPago = "Pendiente";
        $stmt = $conexion->prepare("
            INSERT INTO pago
            (id_pedido,metodo_pago,monto,fecha_pago,estado_pago)
            VALUES (?,?,?,NOW(),?)
        ");
        $stmt->bind_param("isds",$idPedido,$metodoPago,$total,$estadoPago);
        $stmt->execute();

        // La compra comprende todo el carrito del cliente: se vacía dentro
        // de la misma transacción que guarda pedido, pago y movimientos.
        $stmtVaciar = $conexion->prepare(
            "DELETE dc FROM detalle_carrito dc
             INNER JOIN carrito c ON c.id_carrito=dc.id_carrito
             WHERE c.id_usuario=? AND c.estado='Activo'"
        );
        $stmtVaciar->bind_param("i", $idUsuario);
        $stmtVaciar->execute();

        $conexion->commit();

        responderPedido([
            "estado" => true,
            "mensaje" => "Pedido registrado correctamente",
            "id_pedido" => $idPedido,
            "subtotal_productos" => round($totalProductos,2),
            "costo_entrega" => round($costoEntrega,2),
            "total" => $total
        ], 201);
    } catch (Throwable $e) {
        $conexion->rollback();
        // Si la primera solicitud se guardó pero Chrome no recibió respuesta,
        // la repetición devuelve el mismo pedido, sin cobrar ni restar stock 2 veces.
        $pedidoAnterior = pedidoRegistradoPorClave($conexion,$idUsuario,$claveOperacion);
        if ($pedidoAnterior !== null) responderPedido($pedidoAnterior);
        error_log("Crear pedido: " . $e->getMessage());
        responderPedido(["estado"=>false,"mensaje"=>$e instanceof RuntimeException
            ? $e->getMessage() : "No se pudo guardar el pedido"],400);
    }
}

if ($metodo !== "GET") {
    responderPedido(["estado"=>false,"mensaje"=>"Método no permitido"], 405);
}

$idUsuarioFiltro = (int)($_GET["id_usuario"] ?? 0);
$idAutenticado = requerirClienteApi($conexion);
if ($idUsuarioFiltro <= 0) $idUsuarioFiltro = $idAutenticado;
requerirClienteApi($conexion, $idUsuarioFiltro);

if ($idUsuarioFiltro <= 0) {
    echo json_encode([], JSON_UNESCAPED_UNICODE);
    exit;
}

$stmt = $conexion->prepare("
    SELECT id_usuario
    FROM usuario
    WHERE id_usuario=?
      AND rol_sistema='Cliente'
    LIMIT 1
");
$stmt->bind_param("i",$idUsuarioFiltro);
$stmt->execute();
if (!$stmt->get_result()->fetch_assoc()) {
    responderPedido(["estado"=>false,"mensaje"=>"Cliente no encontrado"], 404);
}

$stmt = $conexion->prepare("
    SELECT
        p.id_pedido,
        p.fecha_pedido,
        p.estado_pedido,
        p.total,
        p.tipo_entrega,
        p.id_direccion,
        (SELECT co.id_comprobante
         FROM comprobante co WHERE co.id_pedido=p.id_pedido
         ORDER BY co.id_comprobante DESC LIMIT 1) AS id_comprobante,
        u.id_usuario,
        u.nombres,
        u.apellidos,
        u.telefono,
        d.direccion_detalle,
        (
            SELECT pg.metodo_pago
            FROM pago pg
            WHERE pg.id_pedido=p.id_pedido
            ORDER BY pg.id_pago DESC
            LIMIT 1
        ) AS metodo_pago,
        COALESCE(resumen_pago.pagado,0) AS monto_pagado,
        GREATEST(0,ROUND(p.total-COALESCE(resumen_pago.pagado,0),2)) AS saldo_pendiente,
        CASE
            WHEN p.estado_pedido='Cancelado' THEN 'Rechazado'
            WHEN COALESCE(resumen_pago.pagado,0)>=p.total-0.009 THEN 'Pagado'
            ELSE 'Pendiente'
        END AS estado_pago,
        (
            SELECT pg.referencia_cliente
            FROM pago pg WHERE pg.id_pedido=p.id_pedido
            ORDER BY pg.id_pago DESC LIMIT 1
        ) AS referencia_pago
    FROM pedido p
    INNER JOIN usuario u ON p.id_usuario=u.id_usuario
    LEFT JOIN direccion d ON p.id_direccion=d.id_direccion
    LEFT JOIN (
        SELECT id_pedido, SUM(CASE WHEN estado_pago='Pagado' THEN monto ELSE 0 END) AS pagado
        FROM pago GROUP BY id_pedido
    ) resumen_pago ON resumen_pago.id_pedido=p.id_pedido
    WHERE p.id_usuario=?
    ORDER BY p.id_pedido DESC
");
$stmt->bind_param("i",$idUsuarioFiltro);
$stmt->execute();
$resultado = $stmt->get_result();

$pedidos = [];

while ($fila = $resultado->fetch_assoc()) {
    $idPedido = (int)$fila["id_pedido"];

    $stmtItems = $conexion->prepare("
        SELECT
            dp.id_producto,
            dp.cantidad,
            dp.precio_unitario,
            dp.subtotal,
            pr.nombre_producto
        FROM detalle_pedido dp
        INNER JOIN producto pr ON dp.id_producto=pr.id_producto
        WHERE dp.id_pedido=?
        ORDER BY dp.id_detalle ASC
    ");
    $stmtItems->bind_param("i",$idPedido);
    $stmtItems->execute();
    $itemsResultado = $stmtItems->get_result();

    $itemsPedido = [];
    while ($item = $itemsResultado->fetch_assoc()) {
        $itemsPedido[] = [
            "id_producto" => (int)$item["id_producto"],
            "cantidad" => (int)$item["cantidad"],
            "precio" => (float)$item["precio_unitario"],
            "subtotal" => (float)$item["subtotal"],
            "nombre_producto" => $item["nombre_producto"],
        ];
    }

    $fila["items"] = $itemsPedido;
    $pedidos[] = $fila;
}

echo json_encode($pedidos, JSON_UNESCAPED_UNICODE);
