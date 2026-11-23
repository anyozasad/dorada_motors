<?php
declare(strict_types=1);
/**
 * Gestión de clientes, direcciones y empleados desde el APK.
 * Solo se incluye desde admin_movil.php con sesión y rol comprobados.
 */
if (!isset($conexion,$u,$metodo,$rol)) {
    http_response_code(403);
    exit;
}
if ($metodo==='GET') {
    $vista=(string)($_GET['vista'] ?? '');
    if ($vista==='personal') {
        if ($rol!=='Administrador') movilError('Solo el administrador gestiona al personal',403);
        movilResponder(['estado'=>true,'items'=>movilFilas($conexion,
          "SELECT id_usuario,nombres,apellidos,correo,telefono,rol_sistema,
           estado,ultimo_acceso FROM usuario
           WHERE rol_sistema IN ('Administrador','Vendedor','Almacen')
           ORDER BY id_usuario DESC LIMIT 200")]);
    }
    if ($vista==='direcciones') {
        movilExigir($u,'clientes');
        $id=movilEntero($_GET['id_usuario'] ?? null);
        if ($id<=0) movilError('Selecciona un cliente');
        $s=$conexion->prepare("SELECT id_usuario FROM usuario
            WHERE id_usuario=? AND rol_sistema='Cliente' LIMIT 1");
        $s->bind_param('i',$id);
        $s->execute();
        if (!$s->get_result()->fetch_assoc()) movilError('Cliente no encontrado',404);
        $s=$conexion->prepare("SELECT id_direccion,id_usuario,departamento,
          provincia,distrito,direccion_detalle,referencia FROM direccion
          WHERE id_usuario=? ORDER BY id_direccion DESC");
        $s->bind_param('i',$id);
        $s->execute();
        movilResponder(['estado'=>true,'items'=>$s->get_result()->fetch_all(MYSQLI_ASSOC)]);
    }
}
if ($metodo!=='POST') return;

if ($accion==='cliente_guardar') {
    movilExigir($u,'clientes');
    $id=movilEntero($datos['id_usuario'] ?? 0);
    $nombres=trim((string)($datos['nombres'] ?? ''));
    $apellidos=trim((string)($datos['apellidos'] ?? ''));
    $correo=strtolower(trim((string)($datos['correo'] ?? '')));
    $telefono=trim((string)($datos['telefono'] ?? ''));
    $clave=(string)($datos['contrasena'] ?? '');
    if ($id<0 || $nombres==='' || mb_strlen($nombres)>120 ||
        mb_strlen($apellidos)>120 || !filter_var($correo,FILTER_VALIDATE_EMAIL) ||
        mb_strlen($correo)>160 || mb_strlen($telefono)>30 ||
        ($id===0 && strlen($clave)<8) ||
        ($clave!=='' && strlen($clave)<8)) {
        movilError('Revisa nombre, apellidos, correo, teléfono y contraseña (mín. 8)');
    }
    if ($id===0) {
        $hash=password_hash($clave,PASSWORD_DEFAULT);
        $s=$conexion->prepare("INSERT INTO usuario
         (nombres,apellidos,correo,contrasena,telefono,estado,rol_sistema)
         VALUES (?,?,?,?,?,'Activo','Cliente')");
        $s->bind_param('sssss',$nombres,$apellidos,$correo,$hash,$telefono);
    } else {
        $s=$conexion->prepare("SELECT id_usuario FROM usuario
          WHERE id_usuario=? AND rol_sistema='Cliente'");
        $s->bind_param('i',$id);
        $s->execute();
        if (!$s->get_result()->fetch_assoc()) movilError('Cliente no encontrado',404);
        if ($clave!=='') {
            $hash=password_hash($clave,PASSWORD_DEFAULT);
            $s=$conexion->prepare("UPDATE usuario SET nombres=?,apellidos=?,
              correo=?,telefono=?,contrasena=?
              WHERE id_usuario=? AND rol_sistema='Cliente'");
            $s->bind_param('sssssi',$nombres,$apellidos,$correo,$telefono,$hash,$id);
        } else {
            $s=$conexion->prepare("UPDATE usuario SET nombres=?,apellidos=?,
              correo=?,telefono=? WHERE id_usuario=? AND rol_sistema='Cliente'");
            $s->bind_param('ssssi',$nombres,$apellidos,$correo,$telefono,$id);
        }
    }
    try { $s->execute(); }
    catch (mysqli_sql_exception $e) {
        if ((int)$e->getCode()===1062) movilError('El correo ya está registrado',409);
        throw $e;
    }
    if ($id>0 && $clave!=='') {
        $s=$conexion->prepare('DELETE FROM sesion_cliente WHERE id_usuario=?');
        $s->bind_param('i',$id);
        $s->execute();
    }
    movilResponder(['estado'=>true,'mensaje'=>'Datos del cliente guardados',
        'id_usuario'=>$id>0?$id:(int)$conexion->insert_id]);
}

if ($accion==='direccion_guardar' || $accion==='direccion_eliminar') {
    movilExigir($u,'clientes');
    $id=movilEntero($datos['id_direccion'] ?? 0);
    $idUsuario=movilEntero($datos['id_usuario'] ?? null);
    if ($id<0 || $idUsuario<=0) movilError('Cliente o dirección inválidos');
    $s=$conexion->prepare("SELECT id_usuario FROM usuario
       WHERE id_usuario=? AND rol_sistema='Cliente'");
    $s->bind_param('i',$idUsuario);
    $s->execute();
    if (!$s->get_result()->fetch_assoc()) movilError('Cliente no encontrado',404);
    if ($accion==='direccion_eliminar') {
        if ($id<=0) movilError('Selecciona una dirección');
        if (movilCuenta($conexion,'pedido','id_direccion',$id)>0) {
            movilError('Dirección asociada a pedidos: no se puede eliminar',409);
        }
        $s=$conexion->prepare("DELETE FROM direccion
          WHERE id_direccion=? AND id_usuario=?");
        $s->bind_param('ii',$id,$idUsuario);
        $s->execute();
        if ($s->affected_rows!==1) movilError('Dirección no encontrada',404);
        movilResponder(['estado'=>true,'mensaje'=>'Dirección eliminada']);
    }
    $departamento=trim((string)($datos['departamento'] ?? ''));
    $provincia=trim((string)($datos['provincia'] ?? ''));
    $distrito=trim((string)($datos['distrito'] ?? ''));
    $detalle=trim((string)($datos['direccion_detalle'] ?? ''));
    $referencia=trim((string)($datos['referencia'] ?? ''));
    if ($departamento==='' || $provincia==='' || $distrito==='' || $detalle==='' ||
        mb_strlen($departamento)>100 || mb_strlen($provincia)>100 ||
        mb_strlen($distrito)>100 || mb_strlen($detalle)>255 ||
        mb_strlen($referencia)>255) {
        movilError('Completa departamento, provincia, distrito y dirección');
    }
    if ($id===0) {
        $s=$conexion->prepare("INSERT INTO direccion
           (id_usuario,departamento,provincia,distrito,direccion_detalle,referencia)
           VALUES (?,?,?,?,?,?)");
        $s->bind_param('isssss',$idUsuario,$departamento,$provincia,$distrito,$detalle,$referencia);
    } else {
        $s=$conexion->prepare("SELECT id_direccion FROM direccion
           WHERE id_direccion=? AND id_usuario=?");
        $s->bind_param('ii',$id,$idUsuario);
        $s->execute();
        if (!$s->get_result()->fetch_assoc()) movilError('Dirección no encontrada',404);
        $s=$conexion->prepare("UPDATE direccion
           SET departamento=?,provincia=?,distrito=?,direccion_detalle=?,referencia=?
           WHERE id_direccion=? AND id_usuario=?");
        $s->bind_param('sssssii',$departamento,$provincia,$distrito,$detalle,$referencia,$id,$idUsuario);
    }
    $s->execute();
    movilResponder(['estado'=>true,'mensaje'=>'Dirección guardada en MySQL']);
}

if ($accion==='personal_guardar') {
    if ($rol!=='Administrador') movilError('No tienes permisos para el personal',403);
    $id=movilEntero($datos['id_usuario'] ?? 0);
    $nombres=trim((string)($datos['nombres'] ?? ''));
    $apellidos=trim((string)($datos['apellidos'] ?? ''));
    $correo=strtolower(trim((string)($datos['correo'] ?? '')));
    $telefono=trim((string)($datos['telefono'] ?? ''));
    $clave=(string)($datos['contrasena'] ?? '');
    $nuevoRol=(string)($datos['rol_sistema'] ?? 'Vendedor');
    $estado=(string)($datos['estado'] ?? 'Activo');
    if ($id<0 || $nombres==='' || mb_strlen($nombres)>120 ||
        mb_strlen($apellidos)>120 || !filter_var($correo,FILTER_VALIDATE_EMAIL) ||
        mb_strlen($correo)>160 || mb_strlen($telefono)>30 ||
        !in_array($nuevoRol,['Administrador','Vendedor','Almacen'],true) ||
        !in_array($estado,['Activo','Bloqueado'],true) ||
        ($id===0 && strlen($clave)<8) ||
        ($clave!=='' && strlen($clave)<8)) {
        movilError('Revisa los datos del empleado, rol y contraseña (mín. 8)');
    }
    if ($id===(int)$u['id_usuario'] &&
        ($nuevoRol!=='Administrador' || $estado!=='Activo')) {
        movilError('No puedes quitarte tu propio acceso de administrador',409);
    }
    if ($id===0) {
        $hash=password_hash($clave,PASSWORD_DEFAULT);
        $s=$conexion->prepare("INSERT INTO usuario
          (nombres,apellidos,correo,contrasena,telefono,estado,rol_sistema)
          VALUES (?,?,?,?,?,?,?)");
        $s->bind_param('sssssss',$nombres,$apellidos,$correo,$hash,$telefono,$estado,$nuevoRol);
    } else {
        $s=$conexion->prepare("SELECT id_usuario FROM usuario WHERE id_usuario=?
          AND rol_sistema IN ('Administrador','Vendedor','Almacen')");
        $s->bind_param('i',$id);
        $s->execute();
        if (!$s->get_result()->fetch_assoc()) movilError('Empleado no encontrado',404);
        if ($clave!=='') {
            $hash=password_hash($clave,PASSWORD_DEFAULT);
            $s=$conexion->prepare("UPDATE usuario SET nombres=?,apellidos=?,
              correo=?,telefono=?,estado=?,rol_sistema=?,contrasena=?
              WHERE id_usuario=? AND rol_sistema<>'Cliente'");
            $s->bind_param('sssssssi',$nombres,$apellidos,$correo,$telefono,$estado,$nuevoRol,$hash,$id);
        } else {
            $s=$conexion->prepare("UPDATE usuario SET nombres=?,apellidos=?,
              correo=?,telefono=?,estado=?,rol_sistema=?
              WHERE id_usuario=? AND rol_sistema<>'Cliente'");
            $s->bind_param('ssssssi',$nombres,$apellidos,$correo,$telefono,$estado,$nuevoRol,$id);
        }
    }
    try { $s->execute(); }
    catch (mysqli_sql_exception $e) {
        if ((int)$e->getCode()===1062) movilError('El correo ya existe',409);
        throw $e;
    }
    if ($id>0 && ($estado==='Bloqueado' || $clave!=='')) {
        $s=$conexion->prepare('DELETE FROM sesion_admin_movil WHERE id_usuario=?');
        $s->bind_param('i',$id);
        $s->execute();
    }
    movilResponder(['estado'=>true,'mensaje'=>'Personal administrativo guardado',
        'id_usuario'=>$id>0?$id:(int)$conexion->insert_id]);
}
