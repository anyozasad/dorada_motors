<?php
declare(strict_types=1);
/**
 * Extensiones del dashboard Android. Se carga DESPUÉS de comprobar el token
 * en admin_movil.php. No se publica como endpoint independiente.
 */
if (!isset($conexion, $u, $metodo)) {
    http_response_code(403);
    exit;
}
function movilError(string $mensaje, int $codigo=422): never {
    movilResponder(['estado'=>false,'mensaje'=>$mensaje],$codigo);
}
function movilCatalogo(mysqli $db, string $tipo): array {
    $tabla = $tipo==='categoria' ? 'categoria' : 'marca';
    $col = 'nombre_'.$tabla;
    $id = 'id_'.$tabla;
    return movilFilas($db,"SELECT $id,$col FROM $tabla ORDER BY $col");
}
function movilCuenta(mysqli $db, string $tabla, string $col, int $id): int {
    $stmt=$db->prepare("SELECT COUNT(*) total FROM $tabla WHERE $col=?");
    $stmt->bind_param('i',$id);
    $stmt->execute();
    return (int)$stmt->get_result()->fetch_assoc()['total'];
}

if ($metodo === 'GET') {
    $extra = (string)($_GET['vista'] ?? '');
    switch ($extra) {
        case 'categorias':
            movilExigir($u,'productos');
            movilResponder(['estado'=>true,'items'=>movilCatalogo($conexion,'categoria')]);
        case 'marcas':
            movilExigir($u,'productos');
            movilResponder(['estado'=>true,'items'=>movilCatalogo($conexion,'marca')]);
        case 'compras':
            movilExigir($u,'inventario');
            movilResponder(['estado'=>true,'items'=>movilFilas($conexion,
              "SELECT c.id_compra,c.id_proveedor,c.fecha_compra,c.total,c.estado,
              p.razon_social FROM compra c JOIN proveedor p
              ON p.id_proveedor=c.id_proveedor
              ORDER BY c.id_compra DESC LIMIT 200")]);
        case 'comprobantes':
            movilExigir($u,'resumen');
            movilResponder(['estado'=>true,'items'=>movilFilas($conexion,
              "SELECT c.id_comprobante,c.id_pedido,c.tipo_comprobante,
              c.numero_comprobante,c.fecha_emision,c.subtotal,c.igv,c.total,
              u.nombres,u.apellidos FROM comprobante c JOIN pedido p
              ON p.id_pedido=c.id_pedido JOIN usuario u ON u.id_usuario=p.id_usuario
              ORDER BY c.id_comprobante DESC LIMIT 200")]);
        case 'soporte':
            movilExigir($u,'clientes');
            movilResponder(['estado'=>true,'items'=>movilFilas($conexion,
              "SELECT s.id_solicitud,s.id_usuario,s.asunto,s.mensaje,s.estado,
              s.respuesta,s.fecha_creacion,u.nombres,u.apellidos
              FROM solicitud_soporte s JOIN usuario u ON u.id_usuario=s.id_usuario
              ORDER BY s.id_solicitud DESC LIMIT 200")]);
        case 'configuracion':
            if ($rol !== 'Administrador') movilError('Solo el administrador puede configurar la empresa',403);
            require_once __DIR__.'/empresa_config.php';
            movilResponder(['estado'=>true,'configuracion'=>cargarConfigEmpresa()]);
    }
}
if ($metodo !== 'POST') return;

if ($accion === 'catalogo_guardar' || $accion === 'catalogo_eliminar') {
    movilExigir($u,'productos');
    $tipo=(string)($datos['tipo'] ?? '');
    if (!in_array($tipo,['categoria','marca'],true)) movilError('Tipo de catálogo inválido');
    $tabla=$tipo;
    $idCol='id_'.$tipo;
    $nameCol='nombre_'.$tipo;
    $id=movilEntero($datos['id'] ?? 0);
    if ($id<0) movilError('Identificador inválido');
    if ($accion==='catalogo_eliminar') {
        if ($id<=0) movilError('Selecciona una categoría o marca');
        if (movilCuenta($conexion,'producto',$idCol,$id)>0) {
            movilError('No se puede eliminar: existen productos asociados',409);
        }
        $stmt=$conexion->prepare("DELETE FROM $tabla WHERE $idCol=?");
        $stmt->bind_param('i',$id);
        $stmt->execute();
        if ($stmt->affected_rows!==1) movilError('Registro no encontrado',404);
        movilResponder(['estado'=>true,'mensaje'=>'Registro eliminado']);
    }
    $nombre=trim((string)($datos['nombre'] ?? ''));
    if ($nombre==='' || mb_strlen($nombre)>120) movilError('Escribe un nombre de 1 a 120 caracteres');
    if ($id===0) {
        $stmt=$conexion->prepare("INSERT INTO $tabla ($nameCol) VALUES (?)");
        $stmt->bind_param('s',$nombre);
    } else {
        if (movilCuenta($conexion,$tabla,$idCol,$id)===0) movilError('Registro no encontrado',404);
        $stmt=$conexion->prepare("UPDATE $tabla SET $nameCol=? WHERE $idCol=?");
        $stmt->bind_param('si',$nombre,$id);
    }
    try { $stmt->execute(); }
    catch (mysqli_sql_exception $e) {
        if ((int)$e->getCode()===1062) movilError('Ya existe ese nombre',409);
        throw $e;
    }
    movilResponder(['estado'=>true,'mensaje'=>'Catálogo guardado en MySQL']);
}
if ($accion==='proveedor_guardar' || $accion==='proveedor_eliminar') {
    movilExigir($u,'proveedores');
    $id=movilEntero($datos['id_proveedor'] ?? 0);
    if ($id<0) movilError('ID de proveedor inválido');
    if ($accion==='proveedor_eliminar') {
        if ($id<=0) movilError('Proveedor inválido');
        if (movilCuenta($conexion,'compra','id_proveedor',$id)>0) {
            movilError('No se puede eliminar un proveedor con compras',409);
        }
        $s=$conexion->prepare('DELETE FROM proveedor WHERE id_proveedor=?');
        $s->bind_param('i',$id);
        $s->execute();
        if ($s->affected_rows!==1) movilError('Proveedor no encontrado',404);
        movilResponder(['estado'=>true,'mensaje'=>'Proveedor eliminado']);
    }
    $razon=trim((string)($datos['razon_social'] ?? ''));
    $ruc=trim((string)($datos['ruc'] ?? ''));
    $telefono=trim((string)($datos['telefono'] ?? ''));
    $correo=strtolower(trim((string)($datos['correo'] ?? '')));
    $direccion=trim((string)($datos['direccion'] ?? ''));
    $estado=(string)($datos['estado'] ?? 'Activo');
    if ($razon==='' || mb_strlen($razon)>180 || strlen($ruc)>20 ||
        strlen($telefono)>30 || mb_strlen($direccion)>255 ||
        !in_array($estado,['Activo','Inactivo'],true) ||
        ($correo!=='' && !filter_var($correo,FILTER_VALIDATE_EMAIL))) {
        movilError('Revisa nombre, correo, teléfono, dirección y estado');
    }
    if ($id===0) {
        $s=$conexion->prepare("INSERT INTO proveedor
          (razon_social,ruc,telefono,correo,direccion,estado)
          VALUES (?,?,?,?,?,?)");
        $s->bind_param('ssssss',$razon,$ruc,$telefono,$correo,$direccion,$estado);
    } else {
        if (movilCuenta($conexion,'proveedor','id_proveedor',$id)===0) movilError('Proveedor no encontrado',404);
        $s=$conexion->prepare("UPDATE proveedor SET razon_social=?,ruc=?,
          telefono=?,correo=?,direccion=?,estado=? WHERE id_proveedor=?");
        $s->bind_param('ssssssi',$razon,$ruc,$telefono,$correo,$direccion,$estado,$id);
    }
    $s->execute();
    movilResponder(['estado'=>true,'mensaje'=>'Proveedor guardado en MySQL']);
}
if ($accion==='cliente_estado') {
    movilExigir($u,'clientes');
    $id=movilEntero($datos['id_usuario'] ?? null);
    $estado=(string)($datos['estado'] ?? '');
    if ($id<=0 || !in_array($estado,['Activo','Bloqueado'],true)) movilError('Estado de cliente inválido');
    $conexion->begin_transaction();
    $s=$conexion->prepare("SELECT id_usuario FROM usuario WHERE id_usuario=?
      AND rol_sistema='Cliente' FOR UPDATE");
    $s->bind_param('i',$id);
    $s->execute();
    if (!$s->get_result()->fetch_assoc()) {
        $conexion->rollback();
        movilError('Cuenta de cliente no encontrada',404);
    }
    $s=$conexion->prepare("UPDATE usuario SET estado=? WHERE id_usuario=?
       AND rol_sistema='Cliente'");
    $s->bind_param('si',$estado,$id);
    $s->execute();
    if ($estado==='Bloqueado') {
        $s=$conexion->prepare('DELETE FROM sesion_cliente WHERE id_usuario=?');
        $s->bind_param('i',$id);
        $s->execute();
    }
    $conexion->commit();
    movilResponder(['estado'=>true,'mensaje'=>'Estado del cliente guardado']);
}
if ($accion==='inventario_movimiento') {
    movilExigir($u,'inventario');
    $id=movilEntero($datos['id_producto'] ?? null);
    $cantidad=movilEntero($datos['cantidad'] ?? null);
    $tipo=(string)($datos['tipo'] ?? '');
    $motivo=trim((string)($datos['motivo'] ?? ''));
    if ($id<=0 || $cantidad<=0 || $cantidad>100000 ||
        !in_array($tipo,['Entrada','Salida'],true) ||
        $motivo==='' || mb_strlen($motivo)>180) {
        movilError('Selecciona producto, tipo, cantidad y motivo válido');
    }
    $conexion->begin_transaction();
    $s=$conexion->prepare('SELECT stock FROM producto WHERE id_producto=? FOR UPDATE');
    $s->bind_param('i',$id);
    $s->execute();
    $item=$s->get_result()->fetch_assoc();
    if (!$item) {
        $conexion->rollback();
        movilError('Producto no encontrado',404);
    }
    $anterior=(int)$item['stock'];
    $nuevo=$anterior+($tipo==='Entrada' ? $cantidad : -$cantidad);
    if ($nuevo<0 || $nuevo>2000000000) {
        $conexion->rollback();
        movilError('Stock insuficiente o cantidad demasiado grande',409);
    }
    $s=$conexion->prepare('UPDATE producto SET stock=? WHERE id_producto=?');
    $s->bind_param('ii',$nuevo,$id);
    $s->execute();
    movilMovimiento($conexion,$id,$anterior,$nuevo,'Desde APK: '.$motivo);
    $conexion->commit();
    movilResponder(['estado'=>true,'mensaje'=>'Movimiento guardado en Kardex','stock'=>$nuevo]);
}
if ($accion==='configuracion_guardar') {
    if ($rol!=='Administrador') movilError('Solo el administrador puede cambiar los datos de empresa',403);
    require_once __DIR__.'/empresa_config.php';
    // Evitar sobreescribir campos que el usuario no envía.
    $nueva=guardarConfigEmpresa($datos);
    movilResponder(['estado'=>true,'mensaje'=>'Configuración de empresa guardada','configuracion'=>$nueva]);
}
if ($accion==='soporte_responder') {
    movilExigir($u,'clientes');
    $id=movilEntero($datos['id_solicitud'] ?? null);
    $estado=(string)($datos['estado_soporte'] ?? '');
    $respuesta=trim((string)($datos['respuesta_soporte'] ?? ''));
    if ($id<=0 || !in_array($estado,['Abierto','En proceso','Respondido'],true) ||
      mb_strlen($respuesta)>5000 || ($estado==='Respondido' && $respuesta==='')) {
        movilError('Escribe una respuesta válida y el estado de la solicitud');
    }
    $s=$conexion->prepare("UPDATE solicitud_soporte SET estado=?,
      respuesta=?,fecha_actualizacion=NOW() WHERE id_solicitud=?");
    $s->bind_param('ssi',$estado,$respuesta,$id);
    $s->execute();
    if ($s->affected_rows<1 && movilCuenta($conexion,'solicitud_soporte','id_solicitud',$id)===0) {
        movilError('Solicitud no encontrada',404);
    }
    movilResponder(['estado'=>true,'mensaje'=>'Respuesta enviada al cliente']);
}
