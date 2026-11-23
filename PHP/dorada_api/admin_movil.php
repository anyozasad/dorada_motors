<?php
declare(strict_types=1);
/**
 * API del dashboard móvil Dorada Motors.
 * Usa las mismas tablas del dashboard web. Sesiones Bearer separadas de los
 * clientes y permisos comprobados en cada petición; no reutiliza cookies PHP.
 */
require_once __DIR__ . '/conexion.php';
require_once __DIR__ . '/sistema_bootstrap.php';
header('Content-Type: application/json; charset=UTF-8');
header('Cache-Control: no-store, private, max-age=0');
header('X-Content-Type-Options: nosniff');

function movilResponder(array $datos, int $codigo=200): never {
    http_response_code($codigo);
    echo json_encode($datos, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}
function movilSesiones(mysqli $db): void {
    $db->query("CREATE TABLE IF NOT EXISTS sesion_admin_movil (
        token_hash CHAR(64) NOT NULL PRIMARY KEY,
        id_usuario INT NOT NULL,
        fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        fecha_expiracion DATETIME NOT NULL,
        INDEX idx_sesion_admin_movil_usuario (id_usuario),
        INDEX idx_sesion_admin_movil_expira (fecha_expiracion),
        CONSTRAINT fk_sesion_admin_movil_usuario FOREIGN KEY (id_usuario)
          REFERENCES usuario(id_usuario) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
function movilBearer(): string {
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if ($header === '' && function_exists('getallheaders')) {
        foreach (getallheaders() as $nombre=>$valor) {
            if (strcasecmp((string)$nombre,'Authorization') === 0) {
                $header = (string)$valor;
                break;
            }
        }
    }
    return preg_match('/^Bearer ([a-fA-F0-9]{64})$/',trim($header),$m) ? $m[1] : '';
}
function movilUsuario(mysqli $db): ?array {
    $token = movilBearer();
    if ($token === '') return null;
    $hash = hash('sha256',$token);
    $s = $db->prepare("SELECT u.id_usuario,u.nombres,u.apellidos,u.correo,u.rol_sistema
       FROM sesion_admin_movil t INNER JOIN usuario u ON u.id_usuario=t.id_usuario
       WHERE t.token_hash=? AND t.fecha_expiracion>NOW() AND u.estado='Activo'
         AND u.rol_sistema IN ('Administrador','Vendedor','Almacen') LIMIT 1");
    $s->bind_param('s',$hash);
    $s->execute();
    return $s->get_result()->fetch_assoc() ?: null;
}
function movilPuede(string $rol,string $modulo): bool {
    $permisos = [
        'Administrador'=>['resumen','productos','pedidos','pagos','clientes','inventario','reportes','proveedores'],
        'Vendedor'=>['resumen','pedidos','pagos','clientes','reportes'],
        'Almacen'=>['resumen','productos','inventario','reportes','proveedores']
    ];
    return in_array($modulo,$permisos[$rol] ?? [],true);
}
function movilExigir(array $usuario,string $modulo): void {
    if (!movilPuede((string)$usuario['rol_sistema'],$modulo)) {
        movilResponder(['estado'=>false,'mensaje'=>'Tu rol no tiene acceso a este módulo'],403);
    }
}
function movilFilas(mysqli $db,string $sql): array {
    return $db->query($sql)->fetch_all(MYSQLI_ASSOC);
}
function movilEntero(mixed $valor): int {
    return filter_var($valor,FILTER_VALIDATE_INT) === false ? -1 : (int)$valor;
}
function movilMovimiento(mysqli $db,int $id,int $anterior,int $nuevo,string $motivo): void {
    if ($anterior === $nuevo) return;
    $tipo = $nuevo > $anterior ? 'Entrada' : 'Salida';
    $cantidad = abs($nuevo-$anterior);
    $s = $db->prepare("INSERT INTO movimiento_stock
       (id_producto,tipo_movimiento,cantidad,motivo,fecha_movimiento,stock_anterior,stock_nuevo)
       VALUES (?,?,?,?,NOW(),?,?)");
    $s->bind_param('isisii',$id,$tipo,$cantidad,$motivo,$anterior,$nuevo);
    $s->execute();
}
try {
    movilSesiones($conexion);
    $metodo = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    $esMultipart = $metodo === 'POST' && str_starts_with(
        strtolower((string)($_SERVER['CONTENT_TYPE'] ?? '')), 'multipart/form-data;');
    $datos = $esMultipart ? $_POST
        : ($metodo === 'POST' ? json_decode(file_get_contents('php://input'),true) : null);
    if ($metodo === 'POST' && !is_array($datos)) {
        movilResponder(['estado'=>false,'mensaje'=>'JSON inválido'],400);
    }
    $accion = (string)($datos['accion'] ?? '');

    if ($metodo === 'POST' && $accion === 'login') {
        $correo = strtolower(trim((string)($datos['correo'] ?? '')));
        $clave = (string)($datos['contrasena'] ?? '');
        if (!filter_var($correo,FILTER_VALIDATE_EMAIL) || $clave === '') {
            movilResponder(['estado'=>false,'mensaje'=>'Ingresa correo y contraseña válidos'],422);
        }
        $s = $conexion->prepare("SELECT id_usuario,nombres,apellidos,correo,contrasena,rol_sistema
           FROM usuario WHERE correo=? AND estado='Activo'
             AND rol_sistema IN ('Administrador','Vendedor','Almacen') LIMIT 1");
        $s->bind_param('s',$correo);
        $s->execute();
        $u = $s->get_result()->fetch_assoc();
        if (!$u || !password_verify($clave,(string)$u['contrasena'])) {
            usleep(180000);
            movilResponder(['estado'=>false,'mensaje'=>'Credenciales administrativas incorrectas'],401);
        }
        $token = bin2hex(random_bytes(32));
        $hash = hash('sha256',$token);
        $id = (int)$u['id_usuario'];
        $s = $conexion->prepare("INSERT INTO sesion_admin_movil
           (token_hash,id_usuario,fecha_expiracion)
           VALUES (?,?,DATE_ADD(NOW(),INTERVAL 7 DAY))");
        $s->bind_param('si',$hash,$id);
        $s->execute();
        $conexion->query("DELETE FROM sesion_admin_movil WHERE fecha_expiracion<NOW()");
        $s = $conexion->prepare("UPDATE usuario SET ultimo_acceso=NOW() WHERE id_usuario=?");
        $s->bind_param('i',$id);
        $s->execute();
        unset($u['contrasena']);
        movilResponder(['estado'=>true,'token'=>$token,'usuario'=>$u]);
    }

    $u = movilUsuario($conexion);
    if (!$u) movilResponder(['estado'=>false,'mensaje'=>'Sesión administrativa vencida. Inicia sesión otra vez.'],401);
    $rol = (string)$u['rol_sistema'];
    // CRUD móvil adicional; aquí el token y rol ya están validados.
    require_once __DIR__ . '/admin_movil_ext.php';
    require_once __DIR__ . '/admin_movil_finanzas.php';
    if ($metodo === 'POST' && $accion === 'logout') {
        $hash = hash('sha256',movilBearer());
        $s = $conexion->prepare("DELETE FROM sesion_admin_movil WHERE token_hash=?");
        $s->bind_param('s',$hash);
        $s->execute();
        movilResponder(['estado'=>true]);
    }
    if ($metodo === 'GET' && ($_GET['vista'] ?? '') === 'sesion') {
        movilResponder(['estado'=>true,'usuario'=>$u]);
    }

    if ($metodo === 'GET') {
        $vista = (string)($_GET['vista'] ?? 'resumen');
        $mapa = [
            'resumen'=>'resumen','productos'=>'productos','pedidos'=>'pedidos',
            'pagos'=>'pagos','clientes'=>'clientes','inventario'=>'inventario',
            'catalogos'=>'productos','proveedores'=>'proveedores','reportes'=>'reportes'
        ];
        if (!isset($mapa[$vista])) movilResponder(['estado'=>false,'mensaje'=>'Sección desconocida'],404);
        movilExigir($u,$mapa[$vista]);

        switch ($vista) {
            case 'resumen':
                $cuentas = $conexion->query("SELECT
                    (SELECT COUNT(*) FROM producto) productos,
                    (SELECT COUNT(*) FROM usuario WHERE rol_sistema='Cliente') clientes,
                    (SELECT COUNT(*) FROM pedido) pedidos,
                    (SELECT COUNT(*) FROM pedido WHERE estado_pedido IN ('Pendiente','Procesando')) pendientes,
                    (SELECT COUNT(*) FROM producto WHERE stock<=stock_minimo) stock_bajo,
                    (SELECT COALESCE(SUM(total),0) FROM pedido WHERE estado_pedido<>'Cancelado') ventas,
                    (SELECT COALESCE(SUM(monto),0) FROM pago WHERE estado_pago='Pagado') cobrado")->fetch_assoc();
                movilResponder(['estado'=>true,'usuario'=>$u,'resumen'=>$cuentas,
                    'ultimos_pedidos'=>movilFilas($conexion,"SELECT p.id_pedido,p.estado_pedido,p.total,
                     p.fecha_pedido,u.nombres,u.apellidos
                     FROM pedido p JOIN usuario u ON u.id_usuario=p.id_usuario
                     ORDER BY p.id_pedido DESC LIMIT 8")]);
            case 'productos':
                movilResponder(['estado'=>true,'items'=>movilFilas($conexion,"SELECT p.*,
                    c.nombre_categoria,m.nombre_marca FROM producto p
                    JOIN categoria c ON c.id_categoria=p.id_categoria
                    JOIN marca m ON m.id_marca=p.id_marca
                    ORDER BY p.id_producto DESC LIMIT 300")]);
            case 'catalogos':
                movilResponder(['estado'=>true,
                    'categorias'=>movilFilas($conexion,'SELECT id_categoria,nombre_categoria FROM categoria ORDER BY nombre_categoria'),
                    'marcas'=>movilFilas($conexion,'SELECT id_marca,nombre_marca FROM marca ORDER BY nombre_marca')]);
            case 'pedidos':
                movilResponder(['estado'=>true,'items'=>movilFilas($conexion,"SELECT
                   p.id_pedido,p.fecha_pedido,p.estado_pedido,p.total,p.tipo_entrega,
                   u.nombres,u.apellidos,u.correo
                   FROM pedido p JOIN usuario u ON u.id_usuario=p.id_usuario
                   ORDER BY p.id_pedido DESC LIMIT 200")]);
            case 'pagos':
                movilResponder(['estado'=>true,'items'=>movilFilas($conexion,"SELECT
                    pg.id_pago,pg.id_pedido,pg.monto,pg.metodo_pago,pg.estado_pago,
                    pg.referencia_cliente,pg.fecha_pago,u.nombres,u.apellidos,p.total
                    FROM pago pg JOIN pedido p ON p.id_pedido=pg.id_pedido
                    JOIN usuario u ON u.id_usuario=p.id_usuario
                    ORDER BY pg.id_pago DESC LIMIT 200")]);
            case 'clientes':
                movilResponder(['estado'=>true,'items'=>movilFilas($conexion,"SELECT
                    id_usuario,nombres,apellidos,correo,telefono,estado,ultimo_acceso
                    FROM usuario WHERE rol_sistema='Cliente' ORDER BY id_usuario DESC LIMIT 200")]);
            case 'inventario':
                movilResponder(['estado'=>true,'items'=>movilFilas($conexion,"SELECT
                    ms.id_movimiento,ms.id_producto,ms.tipo_movimiento,ms.cantidad,
                    ms.motivo,ms.fecha_movimiento,ms.stock_anterior,ms.stock_nuevo,
                    p.nombre_producto FROM movimiento_stock ms
                    JOIN producto p ON p.id_producto=ms.id_producto
                    ORDER BY ms.id_movimiento DESC LIMIT 200")]);
            case 'proveedores':
                movilResponder(['estado'=>true,'items'=>movilFilas($conexion,"SELECT id_proveedor,
                    razon_social,ruc,telefono,correo,direccion,estado
                    FROM proveedor ORDER BY id_proveedor DESC LIMIT 200")]);
            case 'reportes':
                movilResponder(['estado'=>true,
                    'diario'=>movilFilas($conexion,"SELECT DATE(fecha_pedido) fecha,
                      COUNT(*) pedidos,ROUND(SUM(total),2) ventas FROM pedido
                      WHERE fecha_pedido>=CURDATE()-INTERVAL 6 DAY
                        AND estado_pedido<>'Cancelado'
                      GROUP BY DATE(fecha_pedido) ORDER BY fecha DESC"),
                    'top'=>movilFilas($conexion,"SELECT p.nombre_producto,
                      SUM(d.cantidad) cantidad,ROUND(SUM(d.subtotal),2) importe
                      FROM detalle_pedido d JOIN producto p ON p.id_producto=d.id_producto
                      JOIN pedido pe ON pe.id_pedido=d.id_pedido
                      WHERE pe.estado_pedido<>'Cancelado'
                      GROUP BY p.id_producto,p.nombre_producto
                      ORDER BY cantidad DESC LIMIT 10")]);
        }
    }

    if ($metodo !== 'POST') movilResponder(['estado'=>false,'mensaje'=>'Método no permitido'],405);
    if ($accion === 'pedido_estado') {
        movilExigir($u,'pedidos');
        $id = movilEntero($datos['id_pedido'] ?? null);
        $nuevo = (string)($datos['estado_pedido'] ?? '');
        $transiciones = [
            'Pendiente'=>['Procesando'],
            'Pagado'=>['Procesando','Enviado'],
            'Procesando'=>['Enviado'],
            'Enviado'=>['Completado'],
            'Completado'=>[]
        ];
        if ($id<=0) movilResponder(['estado'=>false,'mensaje'=>'Pedido inválido'],422);
        $conexion->begin_transaction();
        $s = $conexion->prepare('SELECT estado_pedido FROM pedido WHERE id_pedido=? FOR UPDATE');
        $s->bind_param('i',$id);
        $s->execute();
        $p = $s->get_result()->fetch_assoc();
        if (!$p) { $conexion->rollback(); movilResponder(['estado'=>false,'mensaje'=>'Pedido no encontrado'],404); }
        $estado = (string)$p['estado_pedido'];
        if (!in_array($nuevo,$transiciones[$estado] ?? [],true)) {
            $conexion->rollback();
            movilResponder(['estado'=>false,'mensaje'=>'El cambio de estado no está permitido'],409);
        }
        if (in_array($nuevo,['Pagado','Completado'],true)) {
            $s = $conexion->prepare("SELECT p.total,
              COALESCE(SUM(CASE WHEN pg.estado_pago='Pagado'
                THEN pg.monto ELSE 0 END),0) pagado
              FROM pedido p LEFT JOIN pago pg ON pg.id_pedido=p.id_pedido
              WHERE p.id_pedido=? GROUP BY p.id_pedido,p.total");
            $s->bind_param('i',$id);
            $s->execute();
            $finanzas = $s->get_result()->fetch_assoc();
            if (!$finanzas ||
              (float)$finanzas['pagado']+0.009 < (float)$finanzas['total']) {
                $conexion->rollback();
                movilResponder(['estado'=>false,'mensaje'=>
                  'No se puede completar: el pedido tiene saldo pendiente'],409);
            }
        }
        $s = $conexion->prepare('UPDATE pedido SET estado_pedido=? WHERE id_pedido=?');
        $s->bind_param('si',$nuevo,$id);
        $s->execute();
        $conexion->commit();
        movilResponder(['estado'=>true,'mensaje'=>'Estado del pedido actualizado']);
    }
    if ($accion === 'pago_confirmar') {
        movilExigir($u,'pagos');
        $id = movilEntero($datos['id_pago'] ?? null);
        if ($id<=0) movilResponder(['estado'=>false,'mensaje'=>'Pago inválido'],422);
        $conexion->begin_transaction();
        $s = $conexion->prepare("SELECT pg.id_pedido,pg.estado_pago,pg.monto,p.total,p.estado_pedido
           FROM pago pg JOIN pedido p ON p.id_pedido=pg.id_pedido
           WHERE pg.id_pago=? FOR UPDATE");
        $s->bind_param('i',$id);
        $s->execute();
        $p = $s->get_result()->fetch_assoc();
        if (!$p || $p['estado_pago'] !== 'Pendiente' || $p['estado_pedido']==='Cancelado') {
            $conexion->rollback();
            movilResponder(['estado'=>false,'mensaje'=>'Este pago no puede confirmarse'],409);
        }
        $pedido = (int)$p['id_pedido'];
        $s = $conexion->prepare("SELECT COALESCE(SUM(monto),0) AS cobrado
           FROM pago WHERE id_pedido=? AND estado_pago='Pagado'");
        $s->bind_param('i',$pedido);
        $s->execute();
        $cobrado = (float)$s->get_result()->fetch_assoc()['cobrado'];
        if ($cobrado+(float)$p['monto'] > (float)$p['total']+.009) {
            $conexion->rollback();
            movilResponder(['estado'=>false,'mensaje'=>'El pago excedería el total del pedido'],409);
        }
        $s = $conexion->prepare("UPDATE pago SET estado_pago='Pagado' WHERE id_pago=?");
        $s->bind_param('i',$id);
        $s->execute();
        if ($cobrado+(float)$p['monto']+0.009 >= (float)$p['total']
             && !in_array($p['estado_pedido'],['Enviado','Completado'],true)) {
            $s = $conexion->prepare("UPDATE pedido SET estado_pedido='Pagado' WHERE id_pedido=?");
            $s->bind_param('i',$pedido);
            $s->execute();
        }
        $conexion->commit();
        movilResponder(['estado'=>true,'mensaje'=>'Pago confirmado manualmente en MySQL']);
    }
    if ($accion === 'producto_guardar') {
        movilExigir($u,'productos');
        $id = movilEntero($datos['id_producto'] ?? 0);
        $nombre = trim((string)($datos['nombre_producto'] ?? ''));
        $precio = $datos['precio'] ?? null;
        $stock = movilEntero($datos['stock'] ?? null);
        $minimo = movilEntero($datos['stock_minimo'] ?? 5);
        $categoria = movilEntero($datos['id_categoria'] ?? null);
        $marca = movilEntero($datos['id_marca'] ?? null);
        $descripcion = trim((string)($datos['descripcion'] ?? ''));
        $compatibilidad = trim((string)($datos['compatibilidad'] ?? ''));
        $vehiculo = trim((string)($datos['tipo_vehiculo'] ?? 'Motocicleta / Motokar'));
        $imagen = trim((string)($datos['imagen_url'] ?? ''));
        $oferta = $datos['precio_oferta'] ?? null;
        $precioValor = is_numeric($precio) ? (float)$precio : -1;
        $ofertaValor = ($oferta === '' || $oferta === null) ? 0 : (is_numeric($oferta) ? (float)$oferta : -1);
        if ($id<0 || $nombre==='' || mb_strlen($nombre)>180 || $categoria<=0 || $marca<=0
          || !is_finite($precioValor) || $precioValor<=0
          || !is_finite($ofertaValor) || $ofertaValor<0
          || ($ofertaValor>0 && $ofertaValor>=$precioValor)
          || $stock<0 || $minimo<0 || mb_strlen($imagen)>255 || mb_strlen($vehiculo)>50
          || mb_strlen($compatibilidad)>255) {
            movilResponder(['estado'=>false,'mensaje'=>'Revisa nombre, categoría, marca, precios y existencias'],422);
        }
        if ($imagen !== '' && (str_contains($imagen,'..') || str_starts_with($imagen,'//') ||
            !preg_match('~^(assets/imagenes/|uploads/|https?://)~i',$imagen))) {
            movilResponder(['estado'=>false,'mensaje'=>'Ruta de imagen no admitida'],422);
        }
        $conexion->begin_transaction();
        if ($id>0) {
            $s = $conexion->prepare('SELECT stock FROM producto WHERE id_producto=? FOR UPDATE');
            $s->bind_param('i',$id);
            $s->execute();
            $actual = $s->get_result()->fetch_assoc();
            if (!$actual) { $conexion->rollback(); movilResponder(['estado'=>false,'mensaje'=>'Producto no encontrado'],404); }
            $anterior=(int)$actual['stock'];
            $s=$conexion->prepare("UPDATE producto SET nombre_producto=?,descripcion=?,tipo_vehiculo=?,
               compatibilidad=?,precio=?,precio_oferta=NULLIF(?,0),stock=?,stock_minimo=?,
               imagen_url=?,id_categoria=?,id_marca=? WHERE id_producto=?");
            $s->bind_param('ssssddiisiii',$nombre,$descripcion,$vehiculo,$compatibilidad,
                 $precioValor,$ofertaValor,$stock,$minimo,$imagen,$categoria,$marca,$id);
            $s->execute();
        } else {
            $anterior=0;
            $s=$conexion->prepare("INSERT INTO producto
               (nombre_producto,descripcion,tipo_vehiculo,compatibilidad,
                precio,precio_oferta,stock,stock_minimo,imagen_url,id_categoria,id_marca)
               VALUES (?,?,?,?,?,NULLIF(?,0),?,?,?,?,?)");
            $s->bind_param('ssssddiisii',$nombre,$descripcion,$vehiculo,$compatibilidad,
                $precioValor,$ofertaValor,$stock,$minimo,$imagen,$categoria,$marca);
            $s->execute();
            $id=(int)$conexion->insert_id;
        }
        movilMovimiento($conexion,$id,$anterior,$stock,$id>0 && $anterior!==0
            ? 'Ajuste desde dashboard APK' : 'Alta o ajuste desde dashboard APK');
        $conexion->commit();
        movilResponder(['estado'=>true,'mensaje'=>'Producto guardado en MySQL','id_producto'=>$id]);
    }
    movilResponder(['estado'=>false,'mensaje'=>'Acción desconocida'],404);
} catch (mysqli_sql_exception $e) {
    if ($conexion->errno || $conexion->connect_errno) { try { $conexion->rollback(); } catch (Throwable $ignore) {} }
    error_log('Dorada admin móvil SQL: '.$e->getMessage());
    movilResponder(['estado'=>false,'mensaje'=>'No se pudo completar la operación en MySQL'],500);
} catch (Throwable $e) {
    try { $conexion->rollback(); } catch (Throwable $ignore) {}
    error_log('Dorada admin móvil: '.$e->getMessage());
    movilResponder(['estado'=>false,'mensaje'=>'Error interno del servidor administrativo'],500);
}
