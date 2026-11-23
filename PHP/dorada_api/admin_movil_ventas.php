<?php
declare(strict_types=1);
/**
 * Pedidos de mostrador, abonos y detalle de ventas desde el dashboard móvil.
 * Se carga únicamente después de validar el Bearer administrativo.
 */
if (!isset($conexion,$u,$metodo,$accion)) {
    http_response_code(403);
    exit;
}

function movilSincronizarPedido(mysqli $db, int $id): void {
    $s=$db->prepare("SELECT p.total,p.estado_pedido,
      COALESCE(SUM(CASE WHEN pg.estado_pago='Pagado' THEN pg.monto ELSE 0 END),0) pagado
      FROM pedido p LEFT JOIN pago pg ON pg.id_pedido=p.id_pedido
      WHERE p.id_pedido=? GROUP BY p.id_pedido,p.total,p.estado_pedido");
    $s->bind_param('i',$id);
    $s->execute();
    $pedido=$s->get_result()->fetch_assoc();
    if (!$pedido) throw new RuntimeException('Pedido inexistente');
    $actual=(string)$pedido['estado_pedido'];
    if (in_array($actual,['Cancelado','Enviado','Completado'],true)) return;
    $nuevo=(float)$pedido['pagado']+0.009>=(float)$pedido['total']
      ? 'Pagado' : ($actual==='Pagado' ? 'Procesando' : $actual);
    if ($nuevo!==$actual) {
        $s=$db->prepare('UPDATE pedido SET estado_pedido=? WHERE id_pedido=?');
        $s->bind_param('si',$nuevo,$id);
        $s->execute();
    }
}
if ($metodo==='GET' && ($_GET['vista']??'')==='pedido_detalle') {
    movilExigir($u,'pedidos');
    $id=movilEntero($_GET['id_pedido']??null);
    if ($id<=0) movilError('Pedido inválido');
    $s=$conexion->prepare("SELECT p.id_pedido,p.id_usuario,p.id_direccion,
      p.fecha_pedido,p.estado_pedido,p.total,p.tipo_entrega,
      u.nombres,u.apellidos,u.correo
      FROM pedido p JOIN usuario u ON u.id_usuario=p.id_usuario
      WHERE p.id_pedido=? LIMIT 1");
    $s->bind_param('i',$id);
    $s->execute();
    $cabecera=$s->get_result()->fetch_assoc();
    if (!$cabecera) movilError('Pedido no encontrado',404);
    $s=$conexion->prepare("SELECT d.id_producto,p.nombre_producto,
      d.cantidad,d.precio_unitario,d.subtotal
      FROM detalle_pedido d JOIN producto p ON p.id_producto=d.id_producto
      WHERE d.id_pedido=? ORDER BY d.id_detalle");
    $s->bind_param('i',$id);
    $s->execute();
    $detalle=$s->get_result()->fetch_all(MYSQLI_ASSOC);
    $s=$conexion->prepare("SELECT id_pago,metodo_pago,monto,estado_pago,fecha_pago
       FROM pago WHERE id_pedido=? ORDER BY id_pago DESC");
    $s->bind_param('i',$id);
    $s->execute();
    movilResponder(['estado'=>true,'pedido'=>$cabecera,'lineas'=>$detalle,
        'pagos'=>$s->get_result()->fetch_all(MYSQLI_ASSOC)]);
}
if ($metodo!=='POST') return;

if ($accion==='pedido_manual') {
    movilExigir($u,'pedidos');
    $idCliente=movilEntero($datos['id_usuario']??null);
    $entrega=trim((string)($datos['tipo_entrega']??'Recojo en tienda'));
    $metodo=trim((string)($datos['metodo_pago']??'Efectivo'));
    $idDireccion=movilEntero($datos['id_direccion']??0);
    $lineas=$datos['items']??null;
    if ($idCliente<=0 || $idDireccion<0 ||
        !in_array($entrega,['Recojo en tienda','Delivery'],true) ||
        !in_array($metodo,['Efectivo','Yape','Plin','Transferencia'],true) ||
        ($entrega==='Delivery' && $idDireccion<=0) ||
        !is_array($lineas) || count($lineas)<1 || count($lineas)>50) {
        movilError('Selecciona cliente, productos, entrega y pago válidos');
    }
    $cantidades=[];
    foreach ($lineas as $linea) {
        if (!is_array($linea)) movilError('Detalle inválido');
        $idProducto=movilEntero($linea['id_producto']??null);
        $qty=movilEntero($linea['cantidad']??null);
        if ($idProducto<=0 || $qty<=0 || $qty>100000) movilError('Producto o cantidad inválidos');
        $cantidades[$idProducto]=($cantidades[$idProducto]??0)+$qty;
        if ($cantidades[$idProducto]>100000) movilError('Demasiadas unidades de un producto');
    }
    ksort($cantidades,SORT_NUMERIC);
    $conexion->begin_transaction();
    $s=$conexion->prepare("SELECT id_usuario FROM usuario
      WHERE id_usuario=? AND rol_sistema='Cliente' AND estado='Activo'");
    $s->bind_param('i',$idCliente);
    $s->execute();
    if (!$s->get_result()->fetch_assoc()) {
        $conexion->rollback();
        movilError('Cliente no disponible',409);
    }
    if ($entrega==='Delivery') {
        $s=$conexion->prepare("SELECT id_direccion FROM direccion
           WHERE id_direccion=? AND id_usuario=?");
        $s->bind_param('ii',$idDireccion,$idCliente);
        $s->execute();
        if (!$s->get_result()->fetch_assoc()) {
            $conexion->rollback();
            movilError('La dirección no pertenece al cliente',409);
        }
    }
    $filas=[];
    $subtotal=0.0;
    foreach ($cantidades as $idProducto=>$qty) {
        $s=$conexion->prepare("SELECT stock,precio,precio_oferta,nombre_producto
          FROM producto WHERE id_producto=? FOR UPDATE");
        $s->bind_param('i',$idProducto);
        $s->execute();
        $p=$s->get_result()->fetch_assoc();
        if (!$p || (int)$p['stock']<$qty) {
            $conexion->rollback();
            movilError('Stock insuficiente o producto no encontrado',409);
        }
        $precio=(float)$p['precio'];
        $oferta=$p['precio_oferta']!==null?(float)$p['precio_oferta']:0;
        if ($oferta>0 && $oferta<$precio) $precio=$oferta;
        $parcial=round($precio*$qty,2);
        $subtotal+=$parcial;
        $filas[]=['id'=>(int)$idProducto,'qty'=>$qty,'price'=>$precio,
          'subtotal'=>$parcial,'stock'=>(int)$p['stock']];
    }
    require_once __DIR__.'/empresa_config.php';
    $config=cargarConfigEmpresa();
    $delivery=$entrega==='Delivery' ? max(0,(float)($config['costo_delivery']??0)) : 0;
    $total=round($subtotal+$delivery,2);
    if (!is_finite($total) || $total>99999999) {
        $conexion->rollback();
        movilError('Importe de venta excesivo');
    }
    $estado='Pendiente';
    if ($entrega==='Delivery') {
        $s=$conexion->prepare("INSERT INTO pedido
         (id_usuario,id_direccion,tipo_entrega,fecha_pedido,estado_pedido,total)
         VALUES (?,?,?,NOW(),?,?)");
        $s->bind_param('iissd',$idCliente,$idDireccion,$entrega,$estado,$total);
    } else {
        $s=$conexion->prepare("INSERT INTO pedido
         (id_usuario,tipo_entrega,fecha_pedido,estado_pedido,total)
         VALUES (?,?,NOW(),?,?)");
        $s->bind_param('issd',$idCliente,$entrega,$estado,$total);
    }
    $s->execute();
    $idPedido=(int)$conexion->insert_id;
    foreach ($filas as $fila) {
        $idProducto=$fila['id'];
        $qty=$fila['qty'];
        $price=$fila['price'];
        $importe=$fila['subtotal'];
        $antes=$fila['stock'];
        $nuevo=$antes-$qty;
        $s=$conexion->prepare("INSERT INTO detalle_pedido
           (id_pedido,id_producto,cantidad,precio_unitario,subtotal)
           VALUES (?,?,?,?,?)");
        $s->bind_param('iiidd',$idPedido,$idProducto,$qty,$price,$importe);
        $s->execute();
        $s=$conexion->prepare('UPDATE producto SET stock=? WHERE id_producto=?');
        $s->bind_param('ii',$nuevo,$idProducto);
        $s->execute();
        movilMovimiento($conexion,$idProducto,$antes,$nuevo,
          'Venta de mostrador #'.$idPedido.' desde APK');
    }
    $s=$conexion->prepare("INSERT INTO pago
      (id_pedido,metodo_pago,monto,fecha_pago,estado_pago)
      VALUES (?,?,?,NOW(),'Pendiente')");
    $s->bind_param('isd',$idPedido,$metodo,$total);
    $s->execute();
    $conexion->commit();
    movilResponder(['estado'=>true,'mensaje'=>'Pedido registrado en MySQL',
       'id_pedido'=>$idPedido,'subtotal'=>round($subtotal,2),
       'costo_entrega'=>$delivery,'total'=>$total]);
}

if ($accion==='pago_manual') {
    movilExigir($u,'pagos');
    $idPedido=movilEntero($datos['id_pedido']??null);
    $metodo=(string)($datos['metodo_pago']??'');
    $estado=(string)($datos['estado_pago']??'Pendiente');
    $raw=$datos['monto']??null;
    $monto=is_numeric($raw)?(float)$raw:-1;
    if ($idPedido<=0 || !is_finite($monto) || $monto<=0 || $monto>99999999 ||
      !in_array($metodo,['Efectivo','Yape','Plin','Transferencia'],true) ||
      !in_array($estado,['Pendiente','Pagado','Rechazado'],true)) {
        movilError('Completa pedido, monto, método y estado de pago válidos');
    }
    $monto=round($monto,2);
    $conexion->begin_transaction();
    $s=$conexion->prepare('SELECT total,estado_pedido FROM pedido WHERE id_pedido=? FOR UPDATE');
    $s->bind_param('i',$idPedido);
    $s->execute();
    $p=$s->get_result()->fetch_assoc();
    if (!$p || $p['estado_pedido']==='Cancelado') {
        $conexion->rollback();
        movilError('Pedido no encontrado o cancelado',409);
    }
    $s=$conexion->prepare("SELECT COALESCE(SUM(monto),0) AS total FROM pago
        WHERE id_pedido=? AND estado_pago='Pagado'");
    $s->bind_param('i',$idPedido);
    $s->execute();
    $pagado=(float)$s->get_result()->fetch_assoc()['total'];
    if ($monto>(float)$p['total']+0.009 ||
        ($estado==='Pagado' && $pagado+$monto>(float)$p['total']+0.009)) {
        $conexion->rollback();
        movilError('El pago excedería el total o el saldo pendiente',409);
    }
    $s=$conexion->prepare("INSERT INTO pago
      (id_pedido,metodo_pago,monto,fecha_pago,estado_pago)
      VALUES (?,?,?,NOW(),?)");
    $s->bind_param('isds',$idPedido,$metodo,$monto,$estado);
    $s->execute();
    $idPago=(int)$conexion->insert_id;
    movilSincronizarPedido($conexion,$idPedido);
    $conexion->commit();
    movilResponder(['estado'=>true,'mensaje'=>'Pago registrado en MySQL',
      'id_pago'=>$idPago]);
}

if ($accion==='pago_estado') {
    movilExigir($u,'pagos');
    $id=movilEntero($datos['id_pago']??null);
    $estado=(string)($datos['estado_pago']??'');
    if ($id<=0 || !in_array($estado,['Pendiente','Pagado','Rechazado'],true)) {
        movilError('Pago o estado inválido');
    }
    $conexion->begin_transaction();
    $s=$conexion->prepare("SELECT pg.id_pedido,pg.monto,pg.estado_pago,
      p.total,p.estado_pedido FROM pago pg
      JOIN pedido p ON p.id_pedido=pg.id_pedido
      WHERE pg.id_pago=? FOR UPDATE");
    $s->bind_param('i',$id);
    $s->execute();
    $p=$s->get_result()->fetch_assoc();
    if (!$p) { $conexion->rollback(); movilError('Pago no encontrado',404); }
    if ($p['estado_pedido']==='Cancelado' && $estado==='Pagado') {
        $conexion->rollback();
        movilError('No puedes confirmar dinero para un pedido cancelado',409);
    }
    if ($p['estado_pago']===$estado) {
        $conexion->rollback();
        movilError('El pago ya tiene ese estado',409);
    }
    $idPedido=(int)$p['id_pedido'];
    if ($estado==='Pagado') {
        $s=$conexion->prepare("SELECT COALESCE(SUM(monto),0) AS total FROM pago
          WHERE id_pedido=? AND estado_pago='Pagado' AND id_pago<>?");
        $s->bind_param('ii',$idPedido,$id);
        $s->execute();
        $pagado=(float)$s->get_result()->fetch_assoc()['total'];
        if ($pagado+(float)$p['monto']>(float)$p['total']+0.009) {
            $conexion->rollback();
            movilError('La operación supera el total del pedido',409);
        }
    }
    $s=$conexion->prepare('UPDATE pago SET estado_pago=? WHERE id_pago=?');
    $s->bind_param('si',$estado,$id);
    $s->execute();
    movilSincronizarPedido($conexion,$idPedido);
    $conexion->commit();
    movilResponder(['estado'=>true,'mensaje'=>'Estado del pago guardado en MySQL']);
}
