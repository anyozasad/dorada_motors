<?php
declare(strict_types=1);
/**
 * Ventas y compras del panel móvil. Cada modificación financiera se protege
 * por rol y se guarda atómicamente en MySQL/MariaDB.
 */
if (!isset($conexion,$u,$metodo,$accion)) {
    http_response_code(403);
    exit;
}
if ($metodo !== 'POST') return;

if ($accion === 'pedido_cancelar') {
    movilExigir($u,'pedidos');
    $id=movilEntero($datos['id_pedido'] ?? null);
    if ($id<=0) movilError('Pedido inválido');
    $conexion->begin_transaction();
    $s=$conexion->prepare("SELECT estado_pedido FROM pedido
         WHERE id_pedido=? FOR UPDATE");
    $s->bind_param('i',$id);
    $s->execute();
    $p=$s->get_result()->fetch_assoc();
    if (!$p) { $conexion->rollback(); movilError('Pedido no encontrado',404); }
    $estado=(string)$p['estado_pedido'];
    if ($estado==='Cancelado') {
        $conexion->rollback();
        movilError('El pedido ya se encuentra cancelado',409);
    }
    if (!in_array($estado,['Pendiente','Procesando','Pagado'],true)) {
        $conexion->rollback();
        movilError('Un pedido enviado o completado requiere una devolución',409);
    }
    $s=$conexion->prepare("SELECT COUNT(*) total FROM pago
      WHERE id_pedido=? AND estado_pago='Pagado'");
    $s->bind_param('i',$id);
    $s->execute();
    if ((int)$s->get_result()->fetch_assoc()['total']>0) {
        $conexion->rollback();
        movilError('No se puede cancelar dinero cobrado sin gestionar reembolso',409);
    }
    $s=$conexion->prepare("SELECT id_producto,cantidad FROM detalle_pedido
      WHERE id_pedido=? ORDER BY id_producto FOR UPDATE");
    $s->bind_param('i',$id);
    $s->execute();
    $lineas=$s->get_result()->fetch_all(MYSQLI_ASSOC);
    foreach ($lineas as $linea) {
        $prod=(int)$linea['id_producto'];
        $cantidad=(int)$linea['cantidad'];
        $s=$conexion->prepare('SELECT stock FROM producto WHERE id_producto=? FOR UPDATE');
        $s->bind_param('i',$prod);
        $s->execute();
        $fila=$s->get_result()->fetch_assoc();
        if (!$fila) throw new RuntimeException('Producto del pedido no encontrado');
        $antes=(int)$fila['stock'];
        $despues=$antes+$cantidad;
        $s=$conexion->prepare('UPDATE producto SET stock=? WHERE id_producto=?');
        $s->bind_param('ii',$despues,$prod);
        $s->execute();
        movilMovimiento($conexion,$prod,$antes,$despues,'Cancelar pedido #'.$id.' desde APK');
    }
    $s=$conexion->prepare("UPDATE pedido SET estado_pedido='Cancelado' WHERE id_pedido=?");
    $s->bind_param('i',$id);
    $s->execute();
    $s=$conexion->prepare("UPDATE pago SET estado_pago='Rechazado'
      WHERE id_pedido=? AND estado_pago='Pendiente'");
    $s->bind_param('i',$id);
    $s->execute();
    $conexion->commit();
    movilResponder(['estado'=>true,'mensaje'=>'Pedido cancelado y stock devuelto']);
}

if ($accion === 'compra_registrar') {
    movilExigir($u,'inventario');
    $proveedor=movilEntero($datos['id_proveedor'] ?? null);
    $items=$datos['items'] ?? null;
    if ($proveedor<=0 || !is_array($items) || count($items)<1 || count($items)>50) {
        movilError('Selecciona proveedor y uno o más productos');
    }
    $lineas=[];
    $idVistos=[];
    $total=0.0;
    foreach ($items as $item) {
        if (!is_array($item)) movilError('Detalle de compra inválido');
        $id=movilEntero($item['id_producto'] ?? null);
        $cantidad=movilEntero($item['cantidad'] ?? null);
        $raw=$item['precio_compra'] ?? null;
        $precio=is_numeric($raw) ? (float)$raw : -1.0;
        if ($id<=0 || $cantidad<1 || $cantidad>100000 ||
          !is_finite($precio) || $precio<0 || $precio>10000000 ||
          isset($idVistos[$id])) {
            movilError('Productos duplicados o cantidad y costos inválidos');
        }
        $idVistos[$id]=true;
        $subtotal=round($precio*$cantidad,2);
        $total+=$subtotal;
        $lineas[]=['id'=>$id,'cantidad'=>$cantidad,
            'precio'=>$precio,'subtotal'=>$subtotal];
    }
    if (!is_finite($total) || $total>999999999) movilError('Total excesivo');
    usort($lineas,fn($a,$b)=>$a['id']<=>$b['id']);
    $total=round($total,2);
    $conexion->begin_transaction();
    $s=$conexion->prepare("SELECT id_proveedor FROM proveedor
      WHERE id_proveedor=? AND estado='Activo' LIMIT 1");
    $s->bind_param('i',$proveedor);
    $s->execute();
    if (!$s->get_result()->fetch_assoc()) {
        $conexion->rollback();
        movilError('Proveedor no existe o está inactivo',409);
    }
    // Bloquear existencias antes de insertar la cabecera.
    $stock=[];
    foreach ($lineas as $linea) {
        $id=$linea['id'];
        $s=$conexion->prepare('SELECT stock FROM producto WHERE id_producto=? FOR UPDATE');
        $s->bind_param('i',$id);
        $s->execute();
        $p=$s->get_result()->fetch_assoc();
        if (!$p || (int)$p['stock']+$linea['cantidad']>2000000000) {
            $conexion->rollback();
            movilError('Producto inexistente o stock máximo alcanzado',409);
        }
        $stock[$id]=(int)$p['stock'];
    }
    $s=$conexion->prepare("INSERT INTO compra
      (id_proveedor,fecha_compra,total,estado)
      VALUES (?,NOW(),?,'Registrado')");
    $s->bind_param('id',$proveedor,$total);
    $s->execute();
    $idCompra=(int)$conexion->insert_id;
    foreach ($lineas as $linea) {
        $id=$linea['id'];
        $qty=$linea['cantidad'];
        $precio=$linea['precio'];
        $subtotal=$linea['subtotal'];
        $s=$conexion->prepare("INSERT INTO detalle_compra
          (id_compra,id_producto,cantidad,precio_compra,subtotal)
          VALUES (?,?,?,?,?)");
        $s->bind_param('iiidd',$idCompra,$id,$qty,$precio,$subtotal);
        $s->execute();
        $antes=$stock[$id];
        $nuevo=$antes+$qty;
        $s=$conexion->prepare('UPDATE producto SET stock=? WHERE id_producto=?');
        $s->bind_param('ii',$nuevo,$id);
        $s->execute();
        movilMovimiento($conexion,$id,$antes,$nuevo,'Compra #'.$idCompra.' desde APK');
    }
    $conexion->commit();
    movilResponder(['estado'=>true,'mensaje'=>'Compra registrada en MySQL',
        'id_compra'=>$idCompra,'total'=>$total]);
}

if ($accion === 'compra_estado') {
    movilExigir($u,'inventario');
    $id=movilEntero($datos['id_compra'] ?? null);
    $estado=(string)($datos['estado'] ?? '');
    if ($id<=0 || !in_array($estado,['Registrado','Anulado'],true)) {
        movilError('Compra o estado inválido');
    }
    $conexion->begin_transaction();
    $s=$conexion->prepare('SELECT estado FROM compra WHERE id_compra=? FOR UPDATE');
    $s->bind_param('i',$id);
    $s->execute();
    $compra=$s->get_result()->fetch_assoc();
    if (!$compra) { $conexion->rollback(); movilError('Compra no encontrada',404); }
    $anterior=(string)$compra['estado'];
    if ($anterior===$estado) {
        $conexion->rollback();
        movilError('La compra ya tiene ese estado',409);
    }
    $s=$conexion->prepare("SELECT id_producto,SUM(cantidad) cantidad
      FROM detalle_compra WHERE id_compra=?
      GROUP BY id_producto ORDER BY id_producto");
    $s->bind_param('i',$id);
    $s->execute();
    $lineas=$s->get_result()->fetch_all(MYSQLI_ASSOC);
    if (!$lineas) { $conexion->rollback(); movilError('Compra sin detalle',409); }
    $cambios=[];
    foreach ($lineas as $linea) {
        $prod=(int)$linea['id_producto'];
        $qty=(int)$linea['cantidad'];
        $s=$conexion->prepare('SELECT stock FROM producto WHERE id_producto=? FOR UPDATE');
        $s->bind_param('i',$prod);
        $s->execute();
        $p=$s->get_result()->fetch_assoc();
        if (!$p) { $conexion->rollback(); movilError('Producto no existe',409); }
        $antes=(int)$p['stock'];
        $nuevo=$antes+($estado==='Anulado' ? -$qty : $qty);
        if ($nuevo<0 || $nuevo>2000000000) {
            $conexion->rollback();
            movilError('Stock insuficiente para anular la compra',409);
        }
        $cambios[]=['id'=>$prod,'antes'=>$antes,'nuevo'=>$nuevo];
    }
    foreach ($cambios as $cambio) {
        $s=$conexion->prepare('UPDATE producto SET stock=? WHERE id_producto=?');
        $s->bind_param('ii',$cambio['nuevo'],$cambio['id']);
        $s->execute();
        movilMovimiento($conexion,$cambio['id'],$cambio['antes'],
          $cambio['nuevo'],($estado==='Anulado'?'Anular ':'Reactivar ').
          'compra #'.$id.' desde APK');
    }
    $s=$conexion->prepare('UPDATE compra SET estado=? WHERE id_compra=?');
    $s->bind_param('si',$estado,$id);
    $s->execute();
    $conexion->commit();
    movilResponder(['estado'=>true,'mensaje'=>'Compra actualizada y stock sincronizado']);
}

if ($accion === 'comprobante_emitir') {
    movilExigir($u,'pagos');
    $id=movilEntero($datos['id_pedido'] ?? null);
    $tipo=(string)($datos['tipo_comprobante'] ?? '');
    if ($id<=0 || !in_array($tipo,['Boleta','Factura'],true)) {
        movilError('Selecciona pedido y tipo de comprobante');
    }
    $conexion->begin_transaction();
    $s=$conexion->prepare("SELECT total,estado_pedido FROM pedido
       WHERE id_pedido=? FOR UPDATE");
    $s->bind_param('i',$id);
    $s->execute();
    $pedido=$s->get_result()->fetch_assoc();
    if (!$pedido) { $conexion->rollback(); movilError('Pedido no encontrado',404); }
    if ($pedido['estado_pedido']==='Cancelado') {
        $conexion->rollback();
        movilError('No se puede emitir para un pedido cancelado',409);
    }
    if (movilCuenta($conexion,'comprobante','id_pedido',$id)>0) {
        $conexion->rollback();
        movilError('Ya existe comprobante para este pedido',409);
    }
    $s=$conexion->prepare("SELECT COALESCE(SUM(monto),0) pagado FROM pago
        WHERE id_pedido=? AND estado_pago='Pagado'");
    $s->bind_param('i',$id);
    $s->execute();
    $pagado=(float)$s->get_result()->fetch_assoc()['pagado'];
    $total=(float)$pedido['total'];
    if ($pagado+0.009<$total) {
        $conexion->rollback();
        movilError('El pedido todavía tiene saldo por cobrar',409);
    }
    require_once __DIR__.'/empresa_config.php';
    $config=cargarConfigEmpresa();
    $porcentaje=(float)($config['igv'] ?? 18);
    $base=round($total/(1+$porcentaje/100),2);
    $igv=round($total-$base,2);
    $provisional='TMP-'.strtoupper(bin2hex(random_bytes(12)));
    $s=$conexion->prepare("INSERT INTO comprobante
       (id_pedido,tipo_comprobante,numero_comprobante,fecha_emision,
        subtotal,igv,total) VALUES (?,?,?,NOW(),?,?,?)");
    $s->bind_param('issddd',$id,$tipo,$provisional,$base,$igv,$total);
    $s->execute();
    $idComp=(int)$conexion->insert_id;
    $numero=($tipo==='Factura'?'F001-':'B001-').str_pad(
        (string)$idComp,6,'0',STR_PAD_LEFT);
    $s=$conexion->prepare("UPDATE comprobante SET numero_comprobante=?
      WHERE id_comprobante=?");
    $s->bind_param('si',$numero,$idComp);
    $s->execute();
    $conexion->commit();
    movilResponder(['estado'=>true,'mensaje'=>'Comprobante de demostración emitido',
        'id_comprobante'=>$idComp,'numero_comprobante'=>$numero]);
}
