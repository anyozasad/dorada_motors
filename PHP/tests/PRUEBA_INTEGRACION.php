<?php
declare(strict_types=1);

require_once __DIR__ . "/../dorada_api/conexion.php";
require_once __DIR__ . "/../dorada_api/sistema_bootstrap.php";

function fallo(string $mensaje): never {
    fwrite(STDERR, "[ERROR] " . $mensaje . PHP_EOL);
    exit(1);
}

function ok(string $mensaje): void {
    echo "[OK] " . $mensaje . PHP_EOL;
}

$conexion->begin_transaction();

try {
    $sufijo = date("YmdHis") . "_" . random_int(1000,9999);

    // 1. Categoria
    $nombreCategoria = "__TEST_CAT_" . $sufijo;
    $stmt = $conexion->prepare("INSERT INTO categoria(nombre_categoria) VALUES (?)");
    $stmt->bind_param("s",$nombreCategoria);
    $stmt->execute();
    $idCategoria = (int)$conexion->insert_id;
    if ($idCategoria <= 0) fallo("No se pudo crear categoria temporal");
    ok("categoria");

    // 2. Marca
    $nombreMarca = "__TEST_MAR_" . $sufijo;
    $stmt = $conexion->prepare("INSERT INTO marca(nombre_marca) VALUES (?)");
    $stmt->bind_param("s",$nombreMarca);
    $stmt->execute();
    $idMarca = (int)$conexion->insert_id;
    if ($idMarca <= 0) fallo("No se pudo crear marca temporal");
    ok("marca");

    // 3. Usuario
    $correo = "test_" . strtolower($sufijo) . "@doradamotors.local";
    $clave = password_hash("Prueba123", PASSWORD_DEFAULT);
    $nombres = "Cliente";
    $apellidos = "Prueba";
    $telefono = "999999999";
    $estadoUsuario = "Activo";
    $stmt = $conexion->prepare("
        INSERT INTO usuario(nombres,apellidos,correo,contrasena,telefono,estado)
        VALUES (?,?,?,?,?,?)
    ");
    $stmt->bind_param("ssssss",$nombres,$apellidos,$correo,$clave,$telefono,$estadoUsuario);
    $stmt->execute();
    $idUsuario = (int)$conexion->insert_id;
    if ($idUsuario <= 0) fallo("No se pudo crear usuario temporal");
    ok("usuario");

    // 4. Direccion
    $departamento = "Ucayali";
    $provincia = "Coronel Portillo";
    $distrito = "Calleria";
    $direccion = "Direccion temporal de prueba";
    $referencia = "Prueba automatica";
    $stmt = $conexion->prepare("
        INSERT INTO direccion(id_usuario,departamento,provincia,distrito,direccion_detalle,referencia)
        VALUES (?,?,?,?,?,?)
    ");
    $stmt->bind_param("isssss",$idUsuario,$departamento,$provincia,$distrito,$direccion,$referencia);
    $stmt->execute();
    $idDireccion = (int)$conexion->insert_id;
    if ($idDireccion <= 0) fallo("No se pudo crear direccion temporal");
    ok("direccion");

    // 5. Producto
    $nombreProducto = "__TEST_PRODUCTO_" . $sufijo;
    $descripcion = "Producto temporal para prueba de integracion";
    $precio = 50.00;
    $stockInicial = 20;
    $stockMinimo = 5;
    $imagen = "";
    $stmt = $conexion->prepare("
        INSERT INTO producto
        (id_categoria,id_marca,nombre_producto,descripcion,precio,stock,stock_minimo,imagen_url)
        VALUES (?,?,?,?,?,?,?,?)
    ");
    $stmt->bind_param("iissdiis",$idCategoria,$idMarca,$nombreProducto,$descripcion,$precio,$stockInicial,$stockMinimo,$imagen);
    $stmt->execute();
    $idProducto = (int)$conexion->insert_id;
    if ($idProducto <= 0) fallo("No se pudo crear producto temporal");
    ok("producto");

    // 6. Proveedor
    $razon = "__TEST_PROVEEDOR_" . $sufijo;
    $ruc = "20000000001";
    $correoProveedor = "proveedor_" . strtolower($sufijo) . "@test.local";
    $direccionProveedor = "Direccion proveedor temporal";
    $estadoProveedor = "Activo";
    $stmt = $conexion->prepare("
        INSERT INTO proveedor(razon_social,ruc,telefono,correo,direccion,estado)
        VALUES (?,?,?,?,?,?)
    ");
    $stmt->bind_param("ssssss",$razon,$ruc,$telefono,$correoProveedor,$direccionProveedor,$estadoProveedor);
    $stmt->execute();
    $idProveedor = (int)$conexion->insert_id;
    if ($idProveedor <= 0) fallo("No se pudo crear proveedor temporal");
    ok("proveedor");

    // 7. Compra
    $totalCompra = 60.00;
    $estadoCompra = "Registrado";
    $stmt = $conexion->prepare("
        INSERT INTO compra(id_proveedor,fecha_compra,total,estado)
        VALUES (?,NOW(),?,?)
    ");
    $stmt->bind_param("ids",$idProveedor,$totalCompra,$estadoCompra);
    $stmt->execute();
    $idCompra = (int)$conexion->insert_id;
    if ($idCompra <= 0) fallo("No se pudo crear compra temporal");
    ok("compra");

    // 8. Detalle compra
    $cantidadCompra = 3;
    $precioCompra = 20.00;
    $subtotalCompra = 60.00;
    $stmt = $conexion->prepare("
        INSERT INTO detalle_compra(id_compra,id_producto,cantidad,precio_compra,subtotal)
        VALUES (?,?,?,?,?)
    ");
    $stmt->bind_param("iiidd",$idCompra,$idProducto,$cantidadCompra,$precioCompra,$subtotalCompra);
    $stmt->execute();
    ok("detalle_compra");

    // 9. Movimiento entrada por compra
    $stockTrasCompra = $stockInicial + $cantidadCompra;
    $tipoEntrada = "Entrada";
    $motivoCompra = "Prueba compra #" . $idCompra;
    $stmt = $conexion->prepare("
        INSERT INTO movimiento_stock
        (id_producto,tipo_movimiento,cantidad,motivo,fecha_movimiento,stock_anterior,stock_nuevo)
        VALUES (?,?,?,?,NOW(),?,?)
    ");
    $stmt->bind_param("isisii",$idProducto,$tipoEntrada,$cantidadCompra,$motivoCompra,$stockInicial,$stockTrasCompra);
    $stmt->execute();

    $stmt = $conexion->prepare("UPDATE producto SET stock=? WHERE id_producto=?");
    $stmt->bind_param("ii",$stockTrasCompra,$idProducto);
    $stmt->execute();

    // 10. Pedido
    $estadoPedido = "Pendiente";
    $tipoEntrega = "Delivery";
    $cantidadPedido = 2;
    $precioPedido = 50.00;
    $subtotalPedido = 100.00;
    $totalPedido = 100.00;
    $stmt = $conexion->prepare("
        INSERT INTO pedido
        (id_usuario,id_direccion,fecha_pedido,estado_pedido,total,tipo_entrega)
        VALUES (?,?,NOW(),?,?,?)
    ");
    $stmt->bind_param("iisds",$idUsuario,$idDireccion,$estadoPedido,$totalPedido,$tipoEntrega);
    $stmt->execute();
    $idPedido = (int)$conexion->insert_id;
    if ($idPedido <= 0) fallo("No se pudo crear pedido temporal");
    ok("pedido");

    // 11. Detalle pedido
    $stmt = $conexion->prepare("
        INSERT INTO detalle_pedido(id_pedido,id_producto,cantidad,precio_unitario,subtotal)
        VALUES (?,?,?,?,?)
    ");
    $stmt->bind_param("iiidd",$idPedido,$idProducto,$cantidadPedido,$precioPedido,$subtotalPedido);
    $stmt->execute();
    ok("detalle_pedido");

    // 12. Salida stock por pedido
    $stockFinal = $stockTrasCompra - $cantidadPedido;
    $stmt = $conexion->prepare("UPDATE producto SET stock=? WHERE id_producto=?");
    $stmt->bind_param("ii",$stockFinal,$idProducto);
    $stmt->execute();

    $tipoSalida = "Salida";
    $motivoPedido = "Prueba pedido #" . $idPedido;
    $stmt = $conexion->prepare("
        INSERT INTO movimiento_stock
        (id_producto,tipo_movimiento,cantidad,motivo,fecha_movimiento,stock_anterior,stock_nuevo)
        VALUES (?,?,?,?,NOW(),?,?)
    ");
    $stmt->bind_param("isisii",$idProducto,$tipoSalida,$cantidadPedido,$motivoPedido,$stockTrasCompra,$stockFinal);
    $stmt->execute();
    ok("movimiento_stock");

    // 13. Pago
    $metodoPago = "Yape";
    $estadoPago = "Pagado";
    $stmt = $conexion->prepare("
        INSERT INTO pago(id_pedido,metodo_pago,monto,fecha_pago,estado_pago)
        VALUES (?,?,?,NOW(),?)
    ");
    $stmt->bind_param("isds",$idPedido,$metodoPago,$totalPedido,$estadoPago);
    $stmt->execute();
    $idPago = (int)$conexion->insert_id;
    if ($idPago <= 0) fallo("No se pudo crear pago temporal");
    ok("pago");

    // 14. Comprobante
    $tipoComprobante = "Boleta";
    $numero = "TEST-" . $sufijo;
    $subtotalComprobante = round($totalPedido / 1.18,2);
    $igv = round($totalPedido - $subtotalComprobante,2);
    $stmt = $conexion->prepare("
        INSERT INTO comprobante
        (id_pedido,tipo_comprobante,numero_comprobante,fecha_emision,subtotal,igv,total)
        VALUES (?,?,?,NOW(),?,?,?)
    ");
    $stmt->bind_param("issddd",$idPedido,$tipoComprobante,$numero,$subtotalComprobante,$igv,$totalPedido);
    $stmt->execute();
    $idComprobante = (int)$conexion->insert_id;
    if ($idComprobante <= 0) fallo("No se pudo crear comprobante temporal");
    ok("comprobante");

    // Verificaciones de relaciones y stock.
    $stmt = $conexion->prepare("
        SELECT
          p.stock,
          (SELECT COUNT(*) FROM detalle_pedido WHERE id_pedido=?) AS detalles_pedido,
          (SELECT COUNT(*) FROM detalle_compra WHERE id_compra=?) AS detalles_compra,
          (SELECT COUNT(*) FROM pago WHERE id_pedido=?) AS pagos,
          (SELECT COUNT(*) FROM comprobante WHERE id_pedido=?) AS comprobantes,
          (SELECT COUNT(*) FROM movimiento_stock WHERE id_producto=?) AS movimientos
        FROM producto p
        WHERE p.id_producto=?
    ");
    $stmt->bind_param("iiiiii",$idPedido,$idCompra,$idPedido,$idPedido,$idProducto,$idProducto);
    $stmt->execute();
    $ver = $stmt->get_result()->fetch_assoc();

    if (!$ver) fallo("No se pudo verificar producto temporal");
    if ((int)$ver["stock"] !== $stockFinal) fallo("Stock inconsistente");
    if ((int)$ver["detalles_pedido"] !== 1) fallo("Detalle de pedido inconsistente");
    if ((int)$ver["detalles_compra"] !== 1) fallo("Detalle de compra inconsistente");
    if ((int)$ver["pagos"] !== 1) fallo("Pago inconsistente");
    if ((int)$ver["comprobantes"] !== 1) fallo("Comprobante inconsistente");
    if ((int)$ver["movimientos"] < 2) fallo("Movimientos de stock incompletos");

    ok("relaciones y stock");

    $conexion->rollback();
    echo "INTEGRACION_OK" . PHP_EOL;
    exit(0);

} catch (Throwable $e) {
    @$conexion->rollback();
    fallo($e->getMessage());
}
