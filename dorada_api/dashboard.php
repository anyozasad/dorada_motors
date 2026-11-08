<?php
require_once "conexion.php";
require_once "auth_admin.php";
require_once "empresa_config.php";

requerirAdmin();

header("Content-Type: text/html; charset=UTF-8");

function h($valor) {
    return htmlspecialchars((string)$valor, ENT_QUOTES, "UTF-8");
}

function sincronizarEstadoFinancieroPedido(mysqli $conexion, int $idPedido): void {
    $stmt = $conexion->prepare("
        SELECT
            p.total,
            p.estado_pedido,
            COALESCE(SUM(CASE WHEN pg.estado_pago='Pagado' THEN pg.monto ELSE 0 END),0) AS pagado
        FROM pedido p
        LEFT JOIN pago pg ON pg.id_pedido=p.id_pedido
        WHERE p.id_pedido=?
        GROUP BY p.id_pedido,p.total,p.estado_pedido
    ");
    $stmt->bind_param("i",$idPedido);
    $stmt->execute();
    $fila = $stmt->get_result()->fetch_assoc();
    if (!$fila) return;

    $estadoActual = (string)$fila["estado_pedido"];
    if (in_array($estadoActual, ["Cancelado","Completado"], true)) return;

    $total = (float)$fila["total"];
    $pagado = (float)$fila["pagado"];
    $nuevoEstado = $pagado + 0.009 >= $total ? "Pagado" : ($estadoActual === "Pagado" ? "Procesando" : $estadoActual);

    if ($nuevoEstado !== $estadoActual) {
        $stmt = $conexion->prepare("UPDATE pedido SET estado_pedido=? WHERE id_pedido=?");
        $stmt->bind_param("si",$nuevoEstado,$idPedido);
        $stmt->execute();
    }
}

function guardarImagenProducto(?array $archivo, string $actual = ""): string {
    if (!$archivo || ($archivo["error"] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_NO_FILE) {
        return $actual;
    }

    if (($archivo["error"] ?? UPLOAD_ERR_OK) !== UPLOAD_ERR_OK) {
        throw new RuntimeException("No se pudo subir la imagen del producto.");
    }

    if (($archivo["size"] ?? 0) > 3 * 1024 * 1024) {
        throw new RuntimeException("La imagen no puede superar los 3 MB.");
    }

    $temporal = $archivo["tmp_name"] ?? "";
    $mime = $temporal && function_exists("mime_content_type")
        ? mime_content_type($temporal)
        : ($archivo["type"] ?? "");

    $permitidos = [
        "image/jpeg" => "jpg",
        "image/png" => "png",
        "image/webp" => "webp",
    ];

    if (!isset($permitidos[$mime])) {
        throw new RuntimeException("Usa una imagen JPG, PNG o WEBP.");
    }

    $directorio = __DIR__ . "/uploads/productos";
    if (!is_dir($directorio) && !mkdir($directorio, 0775, true) && !is_dir($directorio)) {
        throw new RuntimeException("No se pudo crear la carpeta de imágenes.");
    }

    $nombre = "producto_" . bin2hex(random_bytes(8)) . "." . $permitidos[$mime];
    $destino = $directorio . "/" . $nombre;

    if (!move_uploaded_file($temporal, $destino)) {
        throw new RuntimeException("No se pudo guardar la imagen.");
    }

    return "uploads/productos/" . $nombre;
}

$adminSesion = adminActual();
$configEmpresa = cargarConfigEmpresa();
$igvEmpresa = (float)($configEmpresa["igv"] ?? 18);

$accionesSistema = [
    "responder_soporte" => ["soporte", "Atender solicitud del cliente"],
    "restablecer_clave_cliente" => ["soporte", "Restablecer acceso verificado"],
    "registrar_producto" => ["gestion-productos", "Crear producto"],
    "actualizar_producto" => ["gestion-productos", "Actualizar producto"],
    "eliminar_producto" => ["gestion-productos", "Eliminar producto"],
    "registrar_categoria" => ["categorias", "Crear categoría"],
    "actualizar_categoria" => ["categorias", "Actualizar categoría"],
    "eliminar_categoria" => ["categorias", "Eliminar categoría"],
    "registrar_marca" => ["marcas", "Crear marca"],
    "actualizar_marca" => ["marcas", "Actualizar marca"],
    "eliminar_marca" => ["marcas", "Eliminar marca"],
    "registrar_usuario" => ["clientes", "Crear cliente"],
    "actualizar_usuario" => ["clientes", "Actualizar cliente"],
    "actualizar_estado_usuario" => ["clientes", "Cambiar estado de cliente"],
    "registrar_direccion" => ["clientes", "Registrar dirección"],
    "actualizar_direccion" => ["clientes", "Actualizar dirección"],
    "eliminar_direccion" => ["clientes", "Eliminar dirección"],
    "registrar_pedido_manual" => ["pedidos", "Registrar pedido"],
    "actualizar_estado_pedido" => ["pedidos", "Cambiar estado de pedido"],
    "registrar_pago_manual" => ["pagos", "Registrar pago"],
    "actualizar_estado_pago" => ["pagos", "Cambiar estado de pago"],
    "registrar_proveedor" => ["proveedores", "Crear proveedor"],
    "actualizar_proveedor" => ["proveedores", "Actualizar proveedor"],
    "eliminar_proveedor" => ["proveedores", "Eliminar proveedor"],
    "registrar_movimiento" => ["inventario", "Registrar movimiento de stock"],
    "registrar_compra" => ["compras", "Registrar compra"],
    "actualizar_estado_compra" => ["compras", "Cambiar estado de compra"],
    "registrar_comprobante" => ["comprobantes", "Emitir comprobante"],
    "eliminar_comprobante" => ["comprobantes", "Eliminar comprobante"],
    "guardar_config_empresa" => ["configuracion", "Actualizar datos de empresa"],
    "crear_usuario_admin" => ["configuracion", "Crear usuario administrativo"],
    "actualizar_usuario_admin" => ["configuracion", "Actualizar usuario administrativo"],
    "cambiar_clave_admin" => ["configuracion", "Cambiar contraseña administrativa"],
];

$accionAuditoriaPendiente = null;

function redir($msg, $tipo = "ok", $ancla = "inicio") {
    global $conexion, $accionAuditoriaPendiente;

    if ($tipo === "ok" && is_array($accionAuditoriaPendiente)) {
        registrarBitacora(
            $conexion,
            $accionAuditoriaPendiente[0],
            $accionAuditoriaPendiente[1],
            $msg
        );
    }

    header("Location: dashboard.php?msg=" . urlencode($msg) . "&tipo=" . urlencode($tipo) . "#" . $ancla);
    exit;
}

$mensaje = $_GET["msg"] ?? "";
$tipoMensaje = $_GET["tipo"] ?? "ok";

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    if (!csrfValido($_POST["csrf_token"] ?? null)) {
        redir("La sesión del formulario venció. Actualiza la página e inténtalo otra vez.", "error", "inicio");
    }

    foreach ($accionesSistema as $campo => $meta) {
        if (isset($_POST[$campo])) {
            $accionAuditoriaPendiente = $meta;
            if (!puede($meta[0]) && rolActual() !== "Administrador") {
                redir("Tu rol no tiene permiso para realizar esta acción.", "error", "inicio");
            }
            break;
        }
    }

    try {
        /* ================= ATENCIÓN AL CLIENTE ================= */
        if (isset($_POST["responder_soporte"])) {
            $idSolicitud = (int)($_POST["id_solicitud"] ?? 0);
            $estadoSoporte = trim((string)($_POST["estado_soporte"] ?? ""));
            $respuestaSoporte = trim((string)($_POST["respuesta_soporte"] ?? ""));
            $estadosSoporte = ["Abierto", "En proceso", "Respondido", "Cerrado"];

            if ($idSolicitud <= 0 || !in_array($estadoSoporte, $estadosSoporte, true)) {
                redir("Solicitud o estado inválido.", "error", "soporte");
            }
            if (in_array($estadoSoporte, ["Respondido", "Cerrado"], true)
                && strlen($respuestaSoporte) < 5) {
                redir("Escribe una respuesta de al menos 5 caracteres.", "error", "soporte");
            }
            if (strlen($respuestaSoporte) > 5000) {
                redir("La respuesta supera los 5000 caracteres.", "error", "soporte");
            }

            $stmt = $conexion->prepare(
                "UPDATE solicitud_soporte
                 SET estado=?,respuesta=?,fecha_actualizacion=NOW()
                 WHERE id_solicitud=?"
            );
            $stmt->bind_param("ssi", $estadoSoporte, $respuestaSoporte, $idSolicitud);
            $stmt->execute();
            if ($stmt->affected_rows === 0) {
                $stmt = $conexion->prepare(
                    "SELECT id_solicitud FROM solicitud_soporte WHERE id_solicitud=? LIMIT 1"
                );
                $stmt->bind_param("i", $idSolicitud);
                $stmt->execute();
                if (!$stmt->get_result()->fetch_assoc()) {
                    redir("Solicitud de soporte no encontrada.", "error", "soporte");
                }
            }
            redir("Solicitud #".$idSolicitud." actualizada correctamente.", "ok", "soporte");
        }

        if (isset($_POST["restablecer_clave_cliente"])) {
            if (rolActual() !== "Administrador") {
                redir("Solo el Administrador puede restablecer accesos.", "error", "soporte");
            }
            $idSolicitud = (int)($_POST["id_solicitud"] ?? 0);
            $claveTemporal = (string)($_POST["clave_temporal"] ?? "");
            if (($_POST["identidad_verificada"] ?? "") !== "1") {
                redir("Primero verifica la identidad del cliente por un canal confiable.", "error", "soporte");
            }
            if (strlen($claveTemporal) < 8 || strlen($claveTemporal) > 128) {
                redir("La clave temporal debe tener entre 8 y 128 caracteres.", "error", "soporte");
            }
            $stmt = $conexion->prepare(
                "SELECT id_usuario,asunto FROM solicitud_soporte WHERE id_solicitud=? LIMIT 1"
            );
            $stmt->bind_param("i", $idSolicitud);
            $stmt->execute();
            $solicitudRecuperacion = $stmt->get_result()->fetch_assoc();
            if (!$solicitudRecuperacion || $solicitudRecuperacion["asunto"] !== "Recuperación de acceso") {
                redir("No existe una solicitud de recuperación válida.", "error", "soporte");
            }
            $idCliente = (int)$solicitudRecuperacion["id_usuario"];
            $hashNueva = password_hash($claveTemporal, PASSWORD_DEFAULT);

            $conexion->begin_transaction();
            try {
                $stmt = $conexion->prepare(
                    "UPDATE usuario SET contrasena=? WHERE id_usuario=? AND rol_sistema='Cliente'"
                );
                $stmt->bind_param("si", $hashNueva, $idCliente);
                $stmt->execute();

                $stmt = $conexion->prepare("DELETE FROM sesion_cliente WHERE id_usuario=?");
                $stmt->bind_param("i", $idCliente);
                $stmt->execute();

                $respuesta = "Solicitud atendida. La identidad fue validada por el administrador. La clave temporal debe comunicarse por un canal verificado; no está incluida en esta respuesta.";
                $estado = "Respondido";
                $stmt = $conexion->prepare(
                    "UPDATE solicitud_soporte SET estado=?,respuesta=?,fecha_actualizacion=NOW() WHERE id_solicitud=?"
                );
                $stmt->bind_param("ssi", $estado, $respuesta, $idSolicitud);
                $stmt->execute();
                $conexion->commit();
            } catch (Throwable $e) {
                $conexion->rollback();
                error_log("Restablecimiento asistido: " . $e->getMessage());
                redir("No se pudo restablecer el acceso.", "error", "soporte");
            }
            redir("Acceso restablecido; comunica la clave temporal por un canal verificado.", "ok", "soporte");
        }

        /* ================= PRODUCTOS ================= */
        if (isset($_POST["registrar_producto"])) {
            $idCategoria = (int)($_POST["id_categoria"] ?? 0);
            $idMarca = (int)($_POST["id_marca"] ?? 0);
            $nombre = trim($_POST["nombre_producto"] ?? "");
            $descripcion = trim($_POST["descripcion"] ?? "");
            $tipoVehiculo = trim($_POST["tipo_vehiculo"] ?? "Motocicleta / Motokar");
            $compatibilidad = trim($_POST["compatibilidad"] ?? "");
            $precio = (float)($_POST["precio"] ?? 0);
            $precioOferta = (float)($_POST["precio_oferta"] ?? 0);
            if ($precioOferta < 0 || ($precioOferta > 0 && $precioOferta >= $precio)) {
                redir("La oferta debe ser mayor que cero y menor al precio normal", "error", "gestion-productos");
            }
            $stock = (int)($_POST["stock"] ?? 0);
            $stockMinimo = max(0, (int)($_POST["stock_minimo"] ?? 5));
            if ($precio <= 0 || $stock < 0) {
                redir("El precio debe ser mayor a cero y el stock no puede ser negativo", "error", "gestion-productos");
            }
            $imagenBase = trim($_POST["imagen_url"] ?? "");
            $imagen = guardarImagenProducto($_FILES["imagen_archivo"] ?? null, $imagenBase);

            if ($idCategoria <= 0 || $idMarca <= 0 || $nombre === "") {
                redir("Completa los datos obligatorios del producto", "error", "gestion-productos");
            }

            $stmt = $conexion->prepare("
                INSERT INTO producto
                (id_categoria, id_marca, nombre_producto, descripcion, tipo_vehiculo, compatibilidad, precio, precio_oferta, stock, stock_minimo, imagen_url)
                VALUES (?, ?, ?, ?, ?, ?, ?, NULLIF(?,0), ?, ?, ?)
            ");
            $stmt->bind_param("iissssddiis", $idCategoria, $idMarca, $nombre, $descripcion, $tipoVehiculo, $compatibilidad, $precio, $precioOferta, $stock, $stockMinimo, $imagen);
            $stmt->execute();
            redir("Producto registrado correctamente", "ok", "gestion-productos");
        }

        if (isset($_POST["actualizar_producto"])) {
            $idProducto = (int)($_POST["id_producto"] ?? 0);

            $stmt = $conexion->prepare("SELECT stock FROM producto WHERE id_producto=? LIMIT 1");
            $stmt->bind_param("i", $idProducto);
            $stmt->execute();
            $productoStockAnterior = $stmt->get_result()->fetch_assoc();
            if (!$productoStockAnterior) {
                redir("Producto no encontrado", "error", "gestion-productos");
            }
            $stockAntesEdicion = (int)$productoStockAnterior["stock"];
            $idCategoria = (int)($_POST["id_categoria"] ?? 0);
            $idMarca = (int)($_POST["id_marca"] ?? 0);
            $nombre = trim($_POST["nombre_producto"] ?? "");
            $descripcion = trim($_POST["descripcion"] ?? "");
            $tipoVehiculo = trim($_POST["tipo_vehiculo"] ?? "Motocicleta / Motokar");
            $compatibilidad = trim($_POST["compatibilidad"] ?? "");
            $precio = (float)($_POST["precio"] ?? 0);
            $precioOferta = (float)($_POST["precio_oferta"] ?? 0);
            if ($precioOferta < 0 || ($precioOferta > 0 && $precioOferta >= $precio)) {
                redir("La oferta debe ser mayor que cero y menor al precio normal", "error", "gestion-productos");
            }
            $stock = (int)($_POST["stock"] ?? 0);
            $stockMinimo = max(0, (int)($_POST["stock_minimo"] ?? 5));
            if ($precio <= 0 || $stock < 0) {
                redir("El precio debe ser mayor a cero y el stock no puede ser negativo", "error", "gestion-productos");
            }
            $imagenActual = trim($_POST["imagen_actual"] ?? "");
            $imagenManual = trim($_POST["imagen_url"] ?? "");
            $imagenBase = $imagenManual !== "" ? $imagenManual : $imagenActual;
            $imagen = guardarImagenProducto($_FILES["imagen_archivo"] ?? null, $imagenBase);

            $stmt = $conexion->prepare("
                UPDATE producto
                SET id_categoria=?, id_marca=?, nombre_producto=?, descripcion=?, tipo_vehiculo=?, compatibilidad=?,
                    precio=?, precio_oferta=NULLIF(?,0), stock=?, stock_minimo=?, imagen_url=?
                WHERE id_producto=?
            ");
            $stmt->bind_param("iissssddiisi", $idCategoria, $idMarca, $nombre, $descripcion, $tipoVehiculo, $compatibilidad, $precio, $precioOferta, $stock, $stockMinimo, $imagen, $idProducto);
            $stmt->execute();

            if ($stock !== $stockAntesEdicion) {
                $tipoMovimiento = $stock > $stockAntesEdicion ? "Entrada" : "Salida";
                $cantidadMovimiento = abs($stock - $stockAntesEdicion);
                $motivoMovimiento = "Ajuste desde edición de producto";

                $stmt = $conexion->prepare("
                    INSERT INTO movimiento_stock
                    (id_producto,tipo_movimiento,cantidad,motivo,fecha_movimiento,stock_anterior,stock_nuevo)
                    VALUES (?,?,?,?,NOW(),?,?)
                ");
                $stmt->bind_param(
                    "isisii",
                    $idProducto,
                    $tipoMovimiento,
                    $cantidadMovimiento,
                    $motivoMovimiento,
                    $stockAntesEdicion,
                    $stock
                );
                $stmt->execute();
            }

            redir("Producto actualizado correctamente", "ok", "gestion-productos");
        }

        if (isset($_POST["eliminar_producto"])) {
            $idProducto = (int)($_POST["id_producto"] ?? 0);

            $stmt = $conexion->prepare("
                SELECT
                    (SELECT COUNT(*) FROM detalle_pedido WHERE id_producto=?) +
                    (SELECT COUNT(*) FROM detalle_compra WHERE id_producto=?) AS total
            ");
            $stmt->bind_param("ii", $idProducto, $idProducto);
            $stmt->execute();
            $usos = (int)$stmt->get_result()->fetch_assoc()["total"];

            if ($usos > 0) {
                redir("No se puede eliminar: el producto ya tiene movimientos registrados", "error", "gestion-productos");
            }

            $stmt = $conexion->prepare("DELETE FROM movimiento_stock WHERE id_producto=?");
            $stmt->bind_param("i", $idProducto);
            $stmt->execute();

            $stmt = $conexion->prepare("DELETE FROM producto WHERE id_producto=?");
            $stmt->bind_param("i", $idProducto);
            $stmt->execute();
            redir("Producto eliminado correctamente", "ok", "gestion-productos");
        }

        /* ================= CATEGORÍAS ================= */
        if (isset($_POST["registrar_categoria"])) {
            $nombre = trim($_POST["nombre_categoria"] ?? "");
            if ($nombre === "") redir("Escribe el nombre de la categoría", "error", "categorias");

            $stmt = $conexion->prepare("INSERT INTO categoria (nombre_categoria) VALUES (?)");
            $stmt->bind_param("s", $nombre);
            $stmt->execute();
            redir("Categoría registrada correctamente", "ok", "categorias");
        }

        if (isset($_POST["actualizar_categoria"])) {
            $id = (int)($_POST["id_categoria"] ?? 0);
            $nombre = trim($_POST["nombre_categoria"] ?? "");

            if ($id <= 0 || $nombre === "") {
                redir("Completa el nombre de la categoría", "error", "categorias");
            }

            $stmt = $conexion->prepare("UPDATE categoria SET nombre_categoria=? WHERE id_categoria=?");
            $stmt->bind_param("si", $nombre, $id);
            $stmt->execute();
            redir("Categoría actualizada correctamente", "ok", "categorias");
        }

        if (isset($_POST["eliminar_categoria"])) {
            $id = (int)($_POST["id_categoria"] ?? 0);

            $stmt = $conexion->prepare("SELECT COUNT(*) AS total FROM producto WHERE id_categoria=?");
            $stmt->bind_param("i", $id);
            $stmt->execute();
            $total = (int)$stmt->get_result()->fetch_assoc()["total"];

            if ($total > 0) redir("No se puede eliminar: la categoría tiene productos", "error", "categorias");

            $stmt = $conexion->prepare("DELETE FROM categoria WHERE id_categoria=?");
            $stmt->bind_param("i", $id);
            $stmt->execute();
            redir("Categoría eliminada", "ok", "categorias");
        }

        /* ================= MARCAS ================= */
        if (isset($_POST["registrar_marca"])) {
            $nombre = trim($_POST["nombre_marca"] ?? "");
            if ($nombre === "") redir("Escribe el nombre de la marca", "error", "marcas");

            $stmt = $conexion->prepare("INSERT INTO marca (nombre_marca) VALUES (?)");
            $stmt->bind_param("s", $nombre);
            $stmt->execute();
            redir("Marca registrada correctamente", "ok", "marcas");
        }

        if (isset($_POST["actualizar_marca"])) {
            $id = (int)($_POST["id_marca"] ?? 0);
            $nombre = trim($_POST["nombre_marca"] ?? "");

            if ($id <= 0 || $nombre === "") {
                redir("Completa el nombre de la marca", "error", "marcas");
            }

            $stmt = $conexion->prepare("UPDATE marca SET nombre_marca=? WHERE id_marca=?");
            $stmt->bind_param("si", $nombre, $id);
            $stmt->execute();
            redir("Marca actualizada correctamente", "ok", "marcas");
        }

        if (isset($_POST["eliminar_marca"])) {
            $id = (int)($_POST["id_marca"] ?? 0);

            $stmt = $conexion->prepare("SELECT COUNT(*) AS total FROM producto WHERE id_marca=?");
            $stmt->bind_param("i", $id);
            $stmt->execute();
            $total = (int)$stmt->get_result()->fetch_assoc()["total"];

            if ($total > 0) redir("No se puede eliminar: la marca tiene productos", "error", "marcas");

            $stmt = $conexion->prepare("DELETE FROM marca WHERE id_marca=?");
            $stmt->bind_param("i", $id);
            $stmt->execute();
            redir("Marca eliminada", "ok", "marcas");
        }

        /* ================= USUARIOS ================= */
        if (isset($_POST["registrar_usuario"])) {
            $nombres = trim($_POST["nombres"] ?? "");
            $apellidos = trim($_POST["apellidos"] ?? "");
            $correo = strtolower(trim($_POST["correo"] ?? ""));
            $telefono = trim($_POST["telefono"] ?? "");
            $contrasenaPlano = $_POST["contrasena"] ?? "";

            if ($nombres === "" || !filter_var($correo, FILTER_VALIDATE_EMAIL) || strlen($contrasenaPlano) < 6) {
                redir("Completa los datos. La contraseña debe tener mínimo 6 caracteres", "error", "clientes");
            }

            $stmt = $conexion->prepare("SELECT id_usuario FROM usuario WHERE correo=? LIMIT 1");
            $stmt->bind_param("s",$correo);
            $stmt->execute();
            if ($stmt->get_result()->fetch_assoc()) {
                redir("Ese correo ya está registrado", "error", "clientes");
            }

            $contrasena = password_hash($contrasenaPlano, PASSWORD_DEFAULT);

            $stmt = $conexion->prepare("
                INSERT INTO usuario (nombres, apellidos, correo, contrasena, telefono)
                VALUES (?, ?, ?, ?, ?)
            ");
            $stmt->bind_param("sssss", $nombres, $apellidos, $correo, $contrasena, $telefono);
            $stmt->execute();
            redir("Usuario registrado correctamente", "ok", "clientes");
        }

        if (isset($_POST["actualizar_usuario"])) {
            $idUsuario = (int)($_POST["id_usuario"] ?? 0);
            $nombres = trim($_POST["nombres"] ?? "");
            $apellidos = trim($_POST["apellidos"] ?? "");
            $correo = strtolower(trim($_POST["correo"] ?? ""));
            $telefono = trim($_POST["telefono"] ?? "");

            if ($idUsuario <= 0 || $nombres === "" || !filter_var($correo, FILTER_VALIDATE_EMAIL)) {
                redir("Completa correctamente los datos del cliente", "error", "clientes");
            }

            $stmt = $conexion->prepare("SELECT id_usuario FROM usuario WHERE correo=? AND id_usuario<>? LIMIT 1");
            $stmt->bind_param("si", $correo, $idUsuario);
            $stmt->execute();
            if ($stmt->get_result()->fetch_assoc()) {
                redir("Ese correo ya pertenece a otro usuario", "error", "clientes");
            }

            $stmt = $conexion->prepare("
                UPDATE usuario
                SET nombres=?,apellidos=?,correo=?,telefono=?
                WHERE id_usuario=?
            ");
            $stmt->bind_param("ssssi", $nombres, $apellidos, $correo, $telefono, $idUsuario);
            $stmt->execute();
            redir("Cliente actualizado correctamente", "ok", "clientes");
        }

        if (isset($_POST["actualizar_estado_usuario"])) {
            $idUsuario = (int)($_POST["id_usuario"] ?? 0);
            $estadoUsuario = trim($_POST["estado_usuario"] ?? "Activo");

            if (!in_array($estadoUsuario, ["Activo","Bloqueado"], true)) {
                redir("Estado de usuario inválido", "error", "clientes");
            }

            $stmt = $conexion->prepare("UPDATE usuario SET estado=? WHERE id_usuario=?");
            $stmt->bind_param("si", $estadoUsuario, $idUsuario);
            $stmt->execute();
            redir("Estado del usuario actualizado", "ok", "clientes");
        }

        /* ================= DIRECCIONES ================= */
        if (isset($_POST["registrar_direccion"])) {
            $idUsuario = (int)($_POST["id_usuario_direccion"] ?? 0);
            $departamento = trim($_POST["departamento"] ?? "");
            $provincia = trim($_POST["provincia"] ?? "");
            $distrito = trim($_POST["distrito"] ?? "");
            $detalle = trim($_POST["direccion_detalle"] ?? "");
            $referencia = trim($_POST["referencia"] ?? "");

            if ($idUsuario <= 0 || $departamento === "" || $provincia === "" || $distrito === "" || $detalle === "") {
                redir("Completa los datos de la dirección", "error", "direcciones");
            }

            $stmt = $conexion->prepare("
                INSERT INTO direccion
                (id_usuario,departamento,provincia,distrito,direccion_detalle,referencia)
                VALUES (?,?,?,?,?,?)
            ");
            $stmt->bind_param("isssss",$idUsuario,$departamento,$provincia,$distrito,$detalle,$referencia);
            $stmt->execute();
            redir("Dirección registrada correctamente", "ok", "direcciones");
        }

        if (isset($_POST["actualizar_direccion"])) {
            $idDireccion = (int)($_POST["id_direccion"] ?? 0);
            $idUsuario = (int)($_POST["id_usuario_direccion"] ?? 0);
            $departamento = trim($_POST["departamento"] ?? "");
            $provincia = trim($_POST["provincia"] ?? "");
            $distrito = trim($_POST["distrito"] ?? "");
            $detalle = trim($_POST["direccion_detalle"] ?? "");
            $referencia = trim($_POST["referencia"] ?? "");

            if ($idDireccion <= 0 || $idUsuario <= 0 || $detalle === "") {
                redir("Datos de dirección inválidos", "error", "direcciones");
            }

            $stmt = $conexion->prepare("
                UPDATE direccion
                SET id_usuario=?,departamento=?,provincia=?,distrito=?,direccion_detalle=?,referencia=?
                WHERE id_direccion=?
            ");
            $stmt->bind_param("isssssi",$idUsuario,$departamento,$provincia,$distrito,$detalle,$referencia,$idDireccion);
            $stmt->execute();
            redir("Dirección actualizada correctamente", "ok", "direcciones");
        }

        if (isset($_POST["eliminar_direccion"])) {
            $idDireccion = (int)($_POST["id_direccion"] ?? 0);

            $stmt = $conexion->prepare("SELECT COUNT(*) AS total FROM pedido WHERE id_direccion=?");
            $stmt->bind_param("i",$idDireccion);
            $stmt->execute();
            $usosDireccion = (int)$stmt->get_result()->fetch_assoc()["total"];

            if ($usosDireccion > 0) {
                redir("No se puede eliminar: la dirección ya está asociada a pedidos", "error", "direcciones");
            }

            $stmt = $conexion->prepare("DELETE FROM direccion WHERE id_direccion=?");
            $stmt->bind_param("i",$idDireccion);
            $stmt->execute();
            redir("Dirección eliminada correctamente", "ok", "direcciones");
        }

        /* ================= PEDIDOS ================= */
        if (isset($_POST["registrar_pedido_manual"])) {
            $idUsuario = (int)($_POST["id_usuario_pedido"] ?? 0);
            $productosPedido = $_POST["id_producto_pedido"] ?? [];
            $cantidadesPedido = $_POST["cantidad_pedido"] ?? [];
            $tipoEntrega = trim($_POST["tipo_entrega_pedido"] ?? "Recojo en tienda");
            $metodoPago = trim($_POST["metodo_pago_pedido"] ?? "Efectivo");
            $idDireccion = (int)($_POST["id_direccion_pedido"] ?? 0);

            if (!is_array($productosPedido)) $productosPedido = [$productosPedido];
            if (!is_array($cantidadesPedido)) $cantidadesPedido = [$cantidadesPedido];

            if ($idUsuario <= 0 || !$productosPedido || count($productosPedido) !== count($cantidadesPedido)) {
                redir("Completa correctamente los productos del pedido", "error", "pedidos");
            }

            if (!in_array($tipoEntrega, ["Recojo en tienda","Delivery"], true)) {
                redir("Tipo de entrega inválido", "error", "pedidos");
            }

            if (!in_array($metodoPago, ["Efectivo","Yape","Plin","Transferencia"], true)) {
                redir("Método de pago inválido", "error", "pedidos");
            }

            if ($tipoEntrega === "Delivery" && $idDireccion <= 0) {
                redir("Selecciona una dirección para el delivery", "error", "pedidos");
            }

            $cantidadesPorProducto = [];
            foreach ($productosPedido as $idx => $idProductoRaw) {
                $idProducto = (int)$idProductoRaw;
                $cantidad = (int)($cantidadesPedido[$idx] ?? 0);
                if ($idProducto <= 0 || $cantidad <= 0) {
                    redir("Todos los productos deben tener una cantidad válida", "error", "pedidos");
                }
                $cantidadesPorProducto[$idProducto] = ($cantidadesPorProducto[$idProducto] ?? 0) + $cantidad;
            }

            $conexion->begin_transaction();

            try {
                $stmt = $conexion->prepare("SELECT id_usuario FROM usuario WHERE id_usuario=? AND estado='Activo' LIMIT 1");
                $stmt->bind_param("i", $idUsuario);
                $stmt->execute();
                if (!$stmt->get_result()->fetch_assoc()) {
                    throw new RuntimeException("Cliente no disponible");
                }

                if ($idDireccion > 0) {
                    $stmt = $conexion->prepare("SELECT id_direccion FROM direccion WHERE id_direccion=? AND id_usuario=? LIMIT 1");
                    $stmt->bind_param("ii", $idDireccion, $idUsuario);
                    $stmt->execute();
                    if (!$stmt->get_result()->fetch_assoc()) {
                        throw new RuntimeException("La dirección no pertenece al cliente seleccionado");
                    }
                }

                $itemsValidados = [];
                $total = 0.0;

                foreach ($cantidadesPorProducto as $idProducto => $cantidad) {
                    $stmt = $conexion->prepare("
                        SELECT
                            nombre_producto,
                            stock,
                            CASE
                                WHEN precio_oferta IS NOT NULL AND precio_oferta>0 AND precio_oferta<precio
                                THEN precio_oferta
                                ELSE precio
                            END AS precio_venta
                        FROM producto
                        WHERE id_producto=?
                        FOR UPDATE
                    ");
                    $stmt->bind_param("i", $idProducto);
                    $stmt->execute();
                    $productoPedido = $stmt->get_result()->fetch_assoc();

                    if (!$productoPedido) {
                        throw new RuntimeException("Producto no encontrado");
                    }

                    if ((int)$productoPedido["stock"] < $cantidad) {
                        throw new RuntimeException("Stock insuficiente para " . $productoPedido["nombre_producto"]);
                    }

                    $precioUnitario = (float)$productoPedido["precio_venta"];
                    $subtotal = round($precioUnitario * $cantidad, 2);
                    $total += $subtotal;

                    $itemsValidados[] = [
                        "id_producto" => (int)$idProducto,
                        "cantidad" => (int)$cantidad,
                        "precio" => $precioUnitario,
                        "subtotal" => $subtotal,
                        "stock" => (int)$productoPedido["stock"],
                    ];
                }

                $total = round($total, 2);
                $estadoPedido = "Pendiente";

                if ($idDireccion > 0) {
                    $stmt = $conexion->prepare("
                        INSERT INTO pedido
                        (id_usuario,id_direccion,tipo_entrega,fecha_pedido,estado_pedido,total)
                        VALUES (?,?,?,NOW(),?,?)
                    ");
                    $stmt->bind_param("iissd", $idUsuario, $idDireccion, $tipoEntrega, $estadoPedido, $total);
                } else {
                    $stmt = $conexion->prepare("
                        INSERT INTO pedido
                        (id_usuario,tipo_entrega,fecha_pedido,estado_pedido,total)
                        VALUES (?,?,NOW(),?,?)
                    ");
                    $stmt->bind_param("issd", $idUsuario, $tipoEntrega, $estadoPedido, $total);
                }
                $stmt->execute();
                $idPedidoNuevo = (int)$conexion->insert_id;

                foreach ($itemsValidados as $item) {
                    $idProducto = $item["id_producto"];
                    $cantidad = $item["cantidad"];
                    $precioUnitario = $item["precio"];
                    $subtotal = $item["subtotal"];
                    $stockAnteriorPedido = $item["stock"];
                    $stockNuevoPedido = $stockAnteriorPedido - $cantidad;

                    $stmt = $conexion->prepare("
                        INSERT INTO detalle_pedido
                        (id_pedido,id_producto,cantidad,precio_unitario,subtotal)
                        VALUES (?,?,?,?,?)
                    ");
                    $stmt->bind_param("iiidd", $idPedidoNuevo, $idProducto, $cantidad, $precioUnitario, $subtotal);
                    $stmt->execute();

                    $stmt = $conexion->prepare("UPDATE producto SET stock=? WHERE id_producto=?");
                    $stmt->bind_param("ii", $stockNuevoPedido, $idProducto);
                    $stmt->execute();

                    $tipoSalida = "Salida";
                    $motivoSalida = "Pedido manual #" . $idPedidoNuevo;
                    $stmt = $conexion->prepare("
                        INSERT INTO movimiento_stock
                        (id_producto,tipo_movimiento,cantidad,motivo,fecha_movimiento,stock_anterior,stock_nuevo)
                        VALUES (?,?,?,?,NOW(),?,?)
                    ");
                    $stmt->bind_param("isisii", $idProducto, $tipoSalida, $cantidad, $motivoSalida, $stockAnteriorPedido, $stockNuevoPedido);
                    $stmt->execute();
                }

                $estadoPago = "Pendiente";
                $stmt = $conexion->prepare("
                    INSERT INTO pago
                    (id_pedido,metodo_pago,monto,fecha_pago,estado_pago)
                    VALUES (?,?,?,NOW(),?)
                ");
                $stmt->bind_param("isds", $idPedidoNuevo, $metodoPago, $total, $estadoPago);
                $stmt->execute();

                $conexion->commit();
                redir("Pedido #".$idPedidoNuevo." registrado con ".count($itemsValidados)." producto(s)", "ok", "pedidos");
            } catch (Throwable $e) {
                $conexion->rollback();
                redir($e->getMessage(), "error", "pedidos");
            }
        }

        if (isset($_POST["actualizar_estado_pedido"])) {
            $idPedido = (int)($_POST["id_pedido"] ?? 0);
            $estado = trim($_POST["estado_pedido"] ?? "Pendiente");
            $estadosValidos = ["Pendiente","Procesando","Pagado","Enviado","Completado","Cancelado"];

            if (!in_array($estado, $estadosValidos, true)) {
                redir("Estado de pedido inválido", "error", "pedidos");
            }

            $conexion->begin_transaction();

            try {
                $stmt = $conexion->prepare("SELECT estado_pedido FROM pedido WHERE id_pedido=? FOR UPDATE");
                $stmt->bind_param("i",$idPedido);
                $stmt->execute();
                $pedidoActual = $stmt->get_result()->fetch_assoc();

                if (!$pedidoActual) {
                    throw new RuntimeException("Pedido no encontrado");
                }

                $estadoAnterior = (string)$pedidoActual["estado_pedido"];

                if (in_array($estado, ["Pagado","Completado"], true)) {
                    $stmt = $conexion->prepare("
                        SELECT
                            p.total,
                            COALESCE(SUM(CASE WHEN pg.estado_pago='Pagado' THEN pg.monto ELSE 0 END),0) AS pagado
                        FROM pedido p
                        LEFT JOIN pago pg ON pg.id_pedido=p.id_pedido
                        WHERE p.id_pedido=?
                        GROUP BY p.id_pedido,p.total
                    ");
                    $stmt->bind_param("i",$idPedido);
                    $stmt->execute();
                    $finanzasPedido = $stmt->get_result()->fetch_assoc();
                    $saldoPedido = max(0, round((float)$finanzasPedido["total"] - (float)$finanzasPedido["pagado"], 2));
                    if ($saldoPedido > 0.009) {
                        throw new RuntimeException("No se puede marcar el pedido como " . $estado . ": tiene saldo pendiente de S/ " . number_format($saldoPedido,2));
                    }
                }

                $stmt = $conexion->prepare("
                    SELECT id_producto,cantidad
                    FROM detalle_pedido
                    WHERE id_pedido=?
                ");
                $stmt->bind_param("i",$idPedido);
                $stmt->execute();
                $lineasPedido = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

                if ($estado === "Cancelado" && $estadoAnterior !== "Cancelado") {
                    if (in_array($estadoAnterior, ["Enviado","Completado"], true)) {
                        throw new RuntimeException("Un pedido enviado o completado necesita un proceso de devolución antes de cancelarse");
                    }
                    $stmt = $conexion->prepare(
                        "SELECT COUNT(*) AS total FROM pago
                         WHERE id_pedido=? AND estado_pago='Pagado'"
                    );
                    $stmt->bind_param("i", $idPedido);
                    $stmt->execute();
                    $pagosConfirmados = (int)$stmt->get_result()->fetch_assoc()["total"];
                    if ($pagosConfirmados > 0) {
                        throw new RuntimeException("No se puede cancelar un pedido con dinero recibido sin gestionar el reembolso");
                    }

                    foreach ($lineasPedido as $linea) {
                        $idProductoPedido = (int)$linea["id_producto"];
                        $cantidadPedido = (int)$linea["cantidad"];

                        $stmt = $conexion->prepare("SELECT stock FROM producto WHERE id_producto=? FOR UPDATE");
                        $stmt->bind_param("i",$idProductoPedido);
                        $stmt->execute();
                        $filaProducto = $stmt->get_result()->fetch_assoc();
                        if (!$filaProducto) continue;

                        $stockAnterior = (int)$filaProducto["stock"];
                        $stockNuevo = $stockAnterior + $cantidadPedido;

                        $stmt = $conexion->prepare("UPDATE producto SET stock=? WHERE id_producto=?");
                        $stmt->bind_param("ii",$stockNuevo,$idProductoPedido);
                        $stmt->execute();

                        $tipoMovimiento = "Entrada";
                        $motivoMovimiento = "Cancelación pedido #" . $idPedido;
                        $stmt = $conexion->prepare("
                            INSERT INTO movimiento_stock
                            (id_producto,tipo_movimiento,cantidad,motivo,fecha_movimiento,stock_anterior,stock_nuevo)
                            VALUES (?,?,?,?,NOW(),?,?)
                        ");
                        $stmt->bind_param("isisii",$idProductoPedido,$tipoMovimiento,$cantidadPedido,$motivoMovimiento,$stockAnterior,$stockNuevo);
                        $stmt->execute();
                    }
                }

                if ($estadoAnterior === "Cancelado" && $estado !== "Cancelado") {
                    foreach ($lineasPedido as $linea) {
                        $idProductoPedido = (int)$linea["id_producto"];
                        $cantidadPedido = (int)$linea["cantidad"];

                        $stmt = $conexion->prepare("SELECT stock,nombre_producto FROM producto WHERE id_producto=? FOR UPDATE");
                        $stmt->bind_param("i",$idProductoPedido);
                        $stmt->execute();
                        $filaProducto = $stmt->get_result()->fetch_assoc();

                        if (!$filaProducto || (int)$filaProducto["stock"] < $cantidadPedido) {
                            throw new RuntimeException("No hay stock suficiente para reactivar el pedido");
                        }

                        $stockAnterior = (int)$filaProducto["stock"];
                        $stockNuevo = $stockAnterior - $cantidadPedido;

                        $stmt = $conexion->prepare("UPDATE producto SET stock=? WHERE id_producto=?");
                        $stmt->bind_param("ii",$stockNuevo,$idProductoPedido);
                        $stmt->execute();

                        $tipoMovimiento = "Salida";
                        $motivoMovimiento = "Reactivación pedido #" . $idPedido;
                        $stmt = $conexion->prepare("
                            INSERT INTO movimiento_stock
                            (id_producto,tipo_movimiento,cantidad,motivo,fecha_movimiento,stock_anterior,stock_nuevo)
                            VALUES (?,?,?,?,NOW(),?,?)
                        ");
                        $stmt->bind_param("isisii",$idProductoPedido,$tipoMovimiento,$cantidadPedido,$motivoMovimiento,$stockAnterior,$stockNuevo);
                        $stmt->execute();
                    }
                }

                if ($estadoAnterior === "Cancelado" && $estado !== "Cancelado") {
                    // El pago original queda rechazado como historial del cierre anterior.
                    // Se abre un nuevo pago pendiente solo si no existe uno actual.
                    $stmt = $conexion->prepare(
                        "SELECT COUNT(*) AS total FROM pago
                         WHERE id_pedido=? AND estado_pago='Pendiente'"
                    );
                    $stmt->bind_param("i", $idPedido);
                    $stmt->execute();
                    $pendientes = (int)$stmt->get_result()->fetch_assoc()["total"];
                    if ($pendientes === 0) {
                        $stmt = $conexion->prepare(
                            "SELECT metodo_pago FROM pago
                             WHERE id_pedido=? ORDER BY id_pago DESC LIMIT 1"
                        );
                        $stmt->bind_param("i", $idPedido);
                        $stmt->execute();
                        $metodoPagoReactivado = (string)(
                            $stmt->get_result()->fetch_assoc()["metodo_pago"] ?? "Efectivo"
                        );

                        $stmt = $conexion->prepare(
                            "SELECT total FROM pedido WHERE id_pedido=?"
                        );
                        $stmt->bind_param("i", $idPedido);
                        $stmt->execute();
                        $saldoReactivado = (float)$stmt->get_result()->fetch_assoc()["total"];

                        $stmt = $conexion->prepare(
                            "INSERT INTO pago (id_pedido,metodo_pago,monto,fecha_pago,estado_pago)
                             VALUES (?,?,?,NOW(),'Pendiente')"
                        );
                        $stmt->bind_param(
                            "isd", $idPedido, $metodoPagoReactivado, $saldoReactivado
                        );
                        $stmt->execute();
                    }
                }

                $stmt = $conexion->prepare("UPDATE pedido SET estado_pedido=? WHERE id_pedido=?");
                $stmt->bind_param("si", $estado, $idPedido);
                $stmt->execute();

                if ($estado === "Cancelado") {
                    $stmt = $conexion->prepare("
                        UPDATE pago
                        SET estado_pago='Rechazado'
                        WHERE id_pedido=? AND estado_pago='Pendiente'
                    ");
                    $stmt->bind_param("i",$idPedido);
                    $stmt->execute();
                }

                $conexion->commit();
                redir("Estado del pedido actualizado", "ok", "pedidos");
            } catch (Throwable $e) {
                $conexion->rollback();
                redir($e->getMessage(), "error", "pedidos");
            }
        }

        /* ================= PAGOS ================= */
        if (isset($_POST["registrar_pago_manual"])) {
            $idPedido = (int)($_POST["id_pedido_pago"] ?? 0);
            $metodoPago = trim($_POST["metodo_pago_manual"] ?? "Efectivo");
            $monto = (float)($_POST["monto_pago"] ?? 0);
            $estadoPago = trim($_POST["estado_pago_manual"] ?? "Pendiente");

            if ($idPedido <= 0 || $monto <= 0) {
                redir("Completa correctamente el pago", "error", "pagos");
            }

            if (!in_array($metodoPago, ["Efectivo","Yape","Plin","Transferencia"], true) ||
                !in_array($estadoPago, ["Pendiente","Pagado","Rechazado"], true)) {
                redir("Método o estado de pago inválido", "error", "pagos");
            }

            $conexion->begin_transaction();
            try {
                $stmt = $conexion->prepare("
                    SELECT
                        p.total,
                        p.estado_pedido,
                        COALESCE(SUM(CASE WHEN pg.estado_pago='Pagado' THEN pg.monto ELSE 0 END),0) AS pagado
                    FROM pedido p
                    LEFT JOIN pago pg ON pg.id_pedido=p.id_pedido
                    WHERE p.id_pedido=?
                    GROUP BY p.id_pedido,p.total,p.estado_pedido
                    FOR UPDATE
                ");
                $stmt->bind_param("i",$idPedido);
                $stmt->execute();
                $pedidoPago = $stmt->get_result()->fetch_assoc();

                if (!$pedidoPago) {
                    throw new RuntimeException("Pedido no encontrado");
                }

                if ((string)$pedidoPago["estado_pedido"] === "Cancelado") {
                    throw new RuntimeException("No se puede registrar pago a un pedido cancelado");
                }

                $totalPedidoPago = (float)$pedidoPago["total"];
                $pagadoActual = (float)$pedidoPago["pagado"];
                $saldoActual = max(0, round($totalPedidoPago - $pagadoActual, 2));

                if ($monto > $totalPedidoPago + 0.009) {
                    throw new RuntimeException("El monto no puede superar el total del pedido");
                }

                if ($estadoPago === "Pagado" && $monto > $saldoActual + 0.009) {
                    throw new RuntimeException("El abono supera el saldo pendiente de S/ " . number_format($saldoActual,2));
                }

                $stmt = $conexion->prepare("
                    INSERT INTO pago(id_pedido,metodo_pago,monto,fecha_pago,estado_pago)
                    VALUES (?,?,?,NOW(),?)
                ");
                $stmt->bind_param("isds",$idPedido,$metodoPago,$monto,$estadoPago);
                $stmt->execute();

                sincronizarEstadoFinancieroPedido($conexion,$idPedido);

                $conexion->commit();
                redir("Pago registrado correctamente", "ok", "pagos");
            } catch (Throwable $e) {
                $conexion->rollback();
                redir($e->getMessage(), "error", "pagos");
            }
        }

        if (isset($_POST["actualizar_estado_pago"])) {
            $idPago = (int)($_POST["id_pago"] ?? 0);
            $estado = trim($_POST["estado_pago"] ?? "Pendiente");

            if (!in_array($estado, ["Pendiente","Pagado","Rechazado"], true)) {
                redir("Estado de pago inválido", "error", "pagos");
            }

            $conexion->begin_transaction();
            try {
                $stmt = $conexion->prepare("
                    SELECT pg.id_pedido,pg.monto,pg.estado_pago,p.total,p.estado_pedido
                    FROM pago pg
                    INNER JOIN pedido p ON pg.id_pedido=p.id_pedido
                    WHERE pg.id_pago=?
                    FOR UPDATE
                ");
                $stmt->bind_param("i", $idPago);
                $stmt->execute();
                $pagoActual = $stmt->get_result()->fetch_assoc();

                if (!$pagoActual) {
                    throw new RuntimeException("Pago no encontrado");
                }

                if ((string)$pagoActual["estado_pedido"] === "Cancelado" && $estado === "Pagado") {
                    throw new RuntimeException("No se puede confirmar un pago de un pedido cancelado");
                }

                $idPedidoPago = (int)$pagoActual["id_pedido"];

                if ($estado === "Pagado" && (string)$pagoActual["estado_pago"] !== "Pagado") {
                    $stmt = $conexion->prepare("
                        SELECT COALESCE(SUM(monto),0) AS pagado
                        FROM pago
                        WHERE id_pedido=? AND estado_pago='Pagado' AND id_pago<>?
                    ");
                    $stmt->bind_param("ii",$idPedidoPago,$idPago);
                    $stmt->execute();
                    $pagadoOtros = (float)$stmt->get_result()->fetch_assoc()["pagado"];
                    $nuevoTotalPagado = $pagadoOtros + (float)$pagoActual["monto"];

                    if ($nuevoTotalPagado > (float)$pagoActual["total"] + 0.009) {
                        throw new RuntimeException("Confirmar este pago excedería el total del pedido");
                    }
                }

                $stmt = $conexion->prepare("UPDATE pago SET estado_pago=? WHERE id_pago=?");
                $stmt->bind_param("si", $estado, $idPago);
                $stmt->execute();

                sincronizarEstadoFinancieroPedido($conexion,$idPedidoPago);

                $conexion->commit();
                redir("Estado del pago actualizado", "ok", "pagos");
            } catch (Throwable $e) {
                $conexion->rollback();
                redir($e->getMessage(), "error", "pagos");
            }
        }



        /* ================= PROVEEDORES ================= */
        if (isset($_POST["registrar_proveedor"])) {
            $razon = trim($_POST["razon_social"] ?? "");
            $ruc = trim($_POST["ruc"] ?? "");
            $telefono = trim($_POST["telefono_proveedor"] ?? "");
            $correo = trim($_POST["correo_proveedor"] ?? "");
            $direccion = trim($_POST["direccion_proveedor"] ?? "");

            if ($razon === "") redir("Escribe la razón social del proveedor", "error", "proveedores");

            $stmt = $conexion->prepare("
                INSERT INTO proveedor (razon_social, ruc, telefono, correo, direccion, estado)
                VALUES (?, ?, ?, ?, ?, 'Activo')
            ");
            $stmt->bind_param("sssss", $razon, $ruc, $telefono, $correo, $direccion);
            $stmt->execute();
            redir("Proveedor registrado correctamente", "ok", "proveedores");
        }

        if (isset($_POST["actualizar_proveedor"])) {
            $id = (int)($_POST["id_proveedor"] ?? 0);
            $razon = trim($_POST["razon_social"] ?? "");
            $ruc = trim($_POST["ruc"] ?? "");
            $telefono = trim($_POST["telefono_proveedor"] ?? "");
            $correo = trim($_POST["correo_proveedor"] ?? "");
            $direccion = trim($_POST["direccion_proveedor"] ?? "");
            $estado = trim($_POST["estado_proveedor"] ?? "Activo");

            if ($id <= 0 || $razon === "" || !in_array($estado, ["Activo","Inactivo"], true)) {
                redir("Completa correctamente los datos del proveedor", "error", "proveedores");
            }

            $stmt = $conexion->prepare("
                UPDATE proveedor
                SET razon_social=?,ruc=?,telefono=?,correo=?,direccion=?,estado=?
                WHERE id_proveedor=?
            ");
            $stmt->bind_param("ssssssi", $razon, $ruc, $telefono, $correo, $direccion, $estado, $id);
            $stmt->execute();
            redir("Proveedor actualizado correctamente", "ok", "proveedores");
        }

        if (isset($_POST["eliminar_proveedor"])) {
            $id = (int)($_POST["id_proveedor"] ?? 0);

            $stmt = $conexion->prepare("SELECT COUNT(*) AS total FROM compra WHERE id_proveedor=?");
            $stmt->bind_param("i", $id);
            $stmt->execute();
            $total = (int)$stmt->get_result()->fetch_assoc()["total"];

            if ($total > 0) redir("No se puede eliminar: el proveedor tiene compras registradas", "error", "proveedores");

            $stmt = $conexion->prepare("DELETE FROM proveedor WHERE id_proveedor=?");
            $stmt->bind_param("i", $id);
            $stmt->execute();
            redir("Proveedor eliminado", "ok", "proveedores");
        }

        /* ================= INVENTARIO / STOCK ================= */
        if (isset($_POST["registrar_movimiento"])) {
            $idProducto = (int)($_POST["id_producto_stock"] ?? 0);
            $tipo = trim($_POST["tipo_movimiento"] ?? "Entrada");
            $cantidad = (int)($_POST["cantidad_movimiento"] ?? 0);
            $motivo = trim($_POST["motivo_movimiento"] ?? "");

            if ($idProducto <= 0 || $cantidad <= 0 || !in_array($tipo, ["Entrada","Salida"], true)) {
                redir("Completa correctamente el movimiento de stock", "error", "inventario");
            }

            $conexion->begin_transaction();

            $stmt = $conexion->prepare("SELECT stock FROM producto WHERE id_producto=? FOR UPDATE");
            $stmt->bind_param("i", $idProducto);
            $stmt->execute();
            $filaStock = $stmt->get_result()->fetch_assoc();

            if (!$filaStock) {
                $conexion->rollback();
                redir("Producto no encontrado", "error", "inventario");
            }

            $stockActual = (int)$filaStock["stock"];
            $nuevoStock = $tipo === "Entrada" ? $stockActual + $cantidad : $stockActual - $cantidad;

            if ($nuevoStock < 0) {
                $conexion->rollback();
                redir("No hay stock suficiente para registrar esa salida", "error", "inventario");
            }

            $stmt = $conexion->prepare("UPDATE producto SET stock=? WHERE id_producto=?");
            $stmt->bind_param("ii", $nuevoStock, $idProducto);
            $stmt->execute();

            $stmt = $conexion->prepare("
                INSERT INTO movimiento_stock
                (id_producto, tipo_movimiento, cantidad, motivo, fecha_movimiento, stock_anterior, stock_nuevo)
                VALUES (?, ?, ?, ?, NOW(), ?, ?)
            ");
            $stmt->bind_param("isisii", $idProducto, $tipo, $cantidad, $motivo, $stockActual, $nuevoStock);
            $stmt->execute();

            $conexion->commit();
            redir("Movimiento de stock registrado correctamente", "ok", "inventario");
        }

        /* ================= COMPRAS ================= */
        if (isset($_POST["registrar_compra"])) {
            $idProveedor = (int)($_POST["id_proveedor_compra"] ?? 0);
            $productosCompra = $_POST["id_producto_compra"] ?? [];
            $cantidadesCompra = $_POST["cantidad_compra"] ?? [];
            $preciosCompra = $_POST["precio_compra"] ?? [];

            if (!is_array($productosCompra)) $productosCompra = [$productosCompra];
            if (!is_array($cantidadesCompra)) $cantidadesCompra = [$cantidadesCompra];
            if (!is_array($preciosCompra)) $preciosCompra = [$preciosCompra];

            if ($idProveedor <= 0 || !$productosCompra ||
                count($productosCompra) !== count($cantidadesCompra) ||
                count($productosCompra) !== count($preciosCompra)) {
                redir("Completa correctamente los datos de la compra", "error", "compras");
            }

            $itemsCompra = [];
            $totalCompraNueva = 0.0;

            foreach ($productosCompra as $idx => $idProductoRaw) {
                $idProducto = (int)$idProductoRaw;
                $cantidad = (int)($cantidadesCompra[$idx] ?? 0);
                $precioCompra = (float)($preciosCompra[$idx] ?? 0);

                if ($idProducto <= 0 || $cantidad <= 0 || $precioCompra < 0) {
                    redir("Cada producto de la compra debe tener cantidad y costo válidos", "error", "compras");
                }

                $subtotal = round($cantidad * $precioCompra, 2);
                $totalCompraNueva += $subtotal;
                $itemsCompra[] = [
                    "id_producto"=>$idProducto,
                    "cantidad"=>$cantidad,
                    "precio"=>$precioCompra,
                    "subtotal"=>$subtotal,
                ];
            }

            $totalCompraNueva = round($totalCompraNueva, 2);
            $conexion->begin_transaction();

            try {
                $stmt = $conexion->prepare("SELECT id_proveedor FROM proveedor WHERE id_proveedor=? AND estado='Activo' LIMIT 1");
                $stmt->bind_param("i",$idProveedor);
                $stmt->execute();
                if (!$stmt->get_result()->fetch_assoc()) {
                    throw new RuntimeException("Proveedor no disponible");
                }

                $stmt = $conexion->prepare("
                    INSERT INTO compra (id_proveedor, fecha_compra, total, estado)
                    VALUES (?, NOW(), ?, 'Registrado')
                ");
                $stmt->bind_param("id", $idProveedor, $totalCompraNueva);
                $stmt->execute();
                $idCompra = (int)$conexion->insert_id;

                foreach ($itemsCompra as $item) {
                    $idProducto = $item["id_producto"];
                    $cantidad = $item["cantidad"];
                    $precioCompra = $item["precio"];
                    $subtotal = $item["subtotal"];

                    $stmt = $conexion->prepare("SELECT stock FROM producto WHERE id_producto=? FOR UPDATE");
                    $stmt->bind_param("i", $idProducto);
                    $stmt->execute();
                    $filaStockCompra = $stmt->get_result()->fetch_assoc();
                    if (!$filaStockCompra) {
                        throw new RuntimeException("Producto no encontrado en la compra");
                    }

                    $stmt = $conexion->prepare("
                        INSERT INTO detalle_compra
                        (id_compra,id_producto,cantidad,precio_compra,subtotal)
                        VALUES (?,?,?,?,?)
                    ");
                    $stmt->bind_param("iiidd", $idCompra, $idProducto, $cantidad, $precioCompra, $subtotal);
                    $stmt->execute();

                    $stockAnteriorCompra = (int)$filaStockCompra["stock"];
                    $stockNuevoCompra = $stockAnteriorCompra + $cantidad;

                    $stmt = $conexion->prepare("UPDATE producto SET stock=? WHERE id_producto=?");
                    $stmt->bind_param("ii", $stockNuevoCompra, $idProducto);
                    $stmt->execute();

                    $motivo = "Compra #" . $idCompra;
                    $tipoEntrada = "Entrada";
                    $stmt = $conexion->prepare("
                        INSERT INTO movimiento_stock
                        (id_producto,tipo_movimiento,cantidad,motivo,fecha_movimiento,stock_anterior,stock_nuevo)
                        VALUES (?,?,?,?,NOW(),?,?)
                    ");
                    $stmt->bind_param("isisii", $idProducto, $tipoEntrada, $cantidad, $motivo, $stockAnteriorCompra, $stockNuevoCompra);
                    $stmt->execute();
                }

                $conexion->commit();
                redir("Compra #".$idCompra." registrada con ".count($itemsCompra)." producto(s)", "ok", "compras");
            } catch (Throwable $e) {
                $conexion->rollback();
                redir($e->getMessage(), "error", "compras");
            }
        }

        if (isset($_POST["actualizar_estado_compra"])) {
            $idCompra = (int)($_POST["id_compra"] ?? 0);
            $nuevoEstado = trim($_POST["estado_compra"] ?? "Registrado");

            if (!in_array($nuevoEstado, ["Registrado","Anulado"], true)) {
                redir("Estado de compra inválido", "error", "compras");
            }

            $conexion->begin_transaction();
            try {
                $stmt = $conexion->prepare("SELECT estado FROM compra WHERE id_compra=? FOR UPDATE");
                $stmt->bind_param("i",$idCompra);
                $stmt->execute();
                $compraActual = $stmt->get_result()->fetch_assoc();
                if (!$compraActual) {
                    throw new RuntimeException("Compra no encontrada");
                }

                $estadoAnteriorCompra = (string)$compraActual["estado"];

                $stmt = $conexion->prepare("
                    SELECT dc.id_producto,dc.cantidad,p.nombre_producto
                    FROM detalle_compra dc
                    INNER JOIN producto p ON dc.id_producto=p.id_producto
                    WHERE dc.id_compra=?
                ");
                $stmt->bind_param("i",$idCompra);
                $stmt->execute();
                $detallesCompraEstado = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

                if ($nuevoEstado === "Anulado" && $estadoAnteriorCompra !== "Anulado") {
                    foreach ($detallesCompraEstado as $detalleCompra) {
                        $idProductoCompra = (int)$detalleCompra["id_producto"];
                        $cantidadCompraEstado = (int)$detalleCompra["cantidad"];

                        $stmt = $conexion->prepare("SELECT stock FROM producto WHERE id_producto=? FOR UPDATE");
                        $stmt->bind_param("i",$idProductoCompra);
                        $stmt->execute();
                        $productoCompraEstado = $stmt->get_result()->fetch_assoc();

                        if (!$productoCompraEstado || (int)$productoCompraEstado["stock"] < $cantidadCompraEstado) {
                            throw new RuntimeException("No se puede anular: el stock actual no permite retirar la mercadería de " . $detalleCompra["nombre_producto"]);
                        }

                        $stockAnteriorCompra = (int)$productoCompraEstado["stock"];
                        $stockNuevoCompra = $stockAnteriorCompra - $cantidadCompraEstado;

                        $stmt = $conexion->prepare("UPDATE producto SET stock=? WHERE id_producto=?");
                        $stmt->bind_param("ii",$stockNuevoCompra,$idProductoCompra);
                        $stmt->execute();

                        $tipo = "Salida";
                        $motivo = "Anulación compra #" . $idCompra;
                        $stmt = $conexion->prepare("
                            INSERT INTO movimiento_stock
                            (id_producto,tipo_movimiento,cantidad,motivo,fecha_movimiento,stock_anterior,stock_nuevo)
                            VALUES (?,?,?,?,NOW(),?,?)
                        ");
                        $stmt->bind_param("isisii",$idProductoCompra,$tipo,$cantidadCompraEstado,$motivo,$stockAnteriorCompra,$stockNuevoCompra);
                        $stmt->execute();
                    }
                }

                if ($estadoAnteriorCompra === "Anulado" && $nuevoEstado === "Registrado") {
                    foreach ($detallesCompraEstado as $detalleCompra) {
                        $idProductoCompra = (int)$detalleCompra["id_producto"];
                        $cantidadCompraEstado = (int)$detalleCompra["cantidad"];

                        $stmt = $conexion->prepare("SELECT stock FROM producto WHERE id_producto=? FOR UPDATE");
                        $stmt->bind_param("i",$idProductoCompra);
                        $stmt->execute();
                        $productoCompraEstado = $stmt->get_result()->fetch_assoc();
                        if (!$productoCompraEstado) continue;

                        $stockAnteriorCompra = (int)$productoCompraEstado["stock"];
                        $stockNuevoCompra = $stockAnteriorCompra + $cantidadCompraEstado;

                        $stmt = $conexion->prepare("UPDATE producto SET stock=? WHERE id_producto=?");
                        $stmt->bind_param("ii",$stockNuevoCompra,$idProductoCompra);
                        $stmt->execute();

                        $tipo = "Entrada";
                        $motivo = "Reactivación compra #" . $idCompra;
                        $stmt = $conexion->prepare("
                            INSERT INTO movimiento_stock
                            (id_producto,tipo_movimiento,cantidad,motivo,fecha_movimiento,stock_anterior,stock_nuevo)
                            VALUES (?,?,?,?,NOW(),?,?)
                        ");
                        $stmt->bind_param("isisii",$idProductoCompra,$tipo,$cantidadCompraEstado,$motivo,$stockAnteriorCompra,$stockNuevoCompra);
                        $stmt->execute();
                    }
                }

                $stmt = $conexion->prepare("UPDATE compra SET estado=? WHERE id_compra=?");
                $stmt->bind_param("si",$nuevoEstado,$idCompra);
                $stmt->execute();

                $conexion->commit();
                redir("Estado de compra actualizado", "ok", "compras");
            } catch (Throwable $e) {
                $conexion->rollback();
                redir($e->getMessage(), "error", "compras");
            }
        }

        /* ================= COMPROBANTES ================= */
        if (isset($_POST["registrar_comprobante"])) {
            $idPedido = (int)($_POST["id_pedido_comprobante"] ?? 0);
            $tipo = trim($_POST["tipo_comprobante"] ?? "Boleta");
            $numero = strtoupper(trim($_POST["numero_comprobante"] ?? ""));

            if ($idPedido <= 0 || !in_array($tipo, ["Boleta","Factura"], true)) {
                redir("Selecciona un pedido y tipo de comprobante válido", "error", "comprobantes");
            }

            $stmt = $conexion->prepare("SELECT id_comprobante FROM comprobante WHERE id_pedido=? LIMIT 1");
            $stmt->bind_param("i", $idPedido);
            $stmt->execute();
            if ($stmt->get_result()->fetch_assoc()) {
                redir("Ya existe un comprobante para este pedido", "error", "comprobantes");
            }

            $stmt = $conexion->prepare("
                SELECT
                    p.total,
                    p.estado_pedido,
                    COALESCE(SUM(CASE WHEN pg.estado_pago='Pagado' THEN pg.monto ELSE 0 END),0) AS pagado
                FROM pedido p
                LEFT JOIN pago pg ON pg.id_pedido=p.id_pedido
                WHERE p.id_pedido=?
                GROUP BY p.id_pedido,p.total,p.estado_pedido
            ");
            $stmt->bind_param("i", $idPedido);
            $stmt->execute();
            $pedidoComprobante = $stmt->get_result()->fetch_assoc();

            if (!$pedidoComprobante) {
                redir("Pedido no encontrado", "error", "comprobantes");
            }

            if ((string)$pedidoComprobante["estado_pedido"] === "Cancelado") {
                redir("No se puede emitir comprobante de un pedido cancelado", "error", "comprobantes");
            }

            $total = (float)$pedidoComprobante["total"];
            $pagado = (float)$pedidoComprobante["pagado"];
            if ($pagado + 0.009 < $total) {
                redir("El pedido todavía tiene saldo pendiente de S/ " . number_format($total-$pagado,2), "error", "comprobantes");
            }

            if ($numero === "") {
                $siguiente = (int)$conexion->query("SELECT COALESCE(MAX(id_comprobante),0)+1 AS n FROM comprobante")->fetch_assoc()["n"];
                $numero = ($tipo === "Factura" ? "F001-" : "B001-") . str_pad((string)$siguiente, 6, "0", STR_PAD_LEFT);
            }

            $factorIgv = 1 + ($igvEmpresa / 100);
            $subtotal = $factorIgv > 0 ? round($total / $factorIgv, 2) : $total;
            $igv = round($total - $subtotal, 2);

            $stmt = $conexion->prepare("
                INSERT INTO comprobante
                (id_pedido, tipo_comprobante, numero_comprobante, fecha_emision, subtotal, igv, total)
                VALUES (?, ?, ?, NOW(), ?, ?, ?)
            ");
            $stmt->bind_param("issddd", $idPedido, $tipo, $numero, $subtotal, $igv, $total);
            $stmt->execute();
            redir("Comprobante ".$numero." registrado correctamente", "ok", "comprobantes");
        }

        if (isset($_POST["eliminar_comprobante"])) {
            $id = (int)($_POST["id_comprobante"] ?? 0);
            $stmt = $conexion->prepare("DELETE FROM comprobante WHERE id_comprobante=?");
            $stmt->bind_param("i", $id);
            $stmt->execute();
            redir("Comprobante eliminado", "ok", "comprobantes");
        }


        /* ================= CONFIGURACIÓN Y PERSONAL ================= */
        if (isset($_POST["guardar_config_empresa"])) {
            if (rolActual() !== "Administrador") {
                redir("Solo el Administrador puede modificar los datos de la empresa.", "error", "configuracion");
            }

            $configEmpresa = guardarConfigEmpresa($_POST);
            $igvEmpresa = (float)$configEmpresa["igv"];
            redir("Datos de la empresa actualizados correctamente", "ok", "configuracion");
        }

        if (isset($_POST["crear_usuario_admin"])) {
            if (rolActual() !== "Administrador") {
                redir("Solo el Administrador puede crear cuentas del personal.", "error", "configuracion");
            }

            $nombres = trim($_POST["admin_nombres"] ?? "");
            $apellidos = trim($_POST["admin_apellidos"] ?? "");
            $correo = strtolower(trim($_POST["admin_correo"] ?? ""));
            $clave = (string)($_POST["admin_contrasena"] ?? "");
            $rol = trim($_POST["admin_rol"] ?? "Vendedor");

            if ($nombres === "" || !filter_var($correo,FILTER_VALIDATE_EMAIL) || strlen($clave) < 8 ||
                !in_array($rol,["Administrador","Vendedor","Almacen"],true)) {
                redir("Completa correctamente la cuenta administrativa. La contraseña debe tener mínimo 8 caracteres.", "error", "configuracion");
            }

            $stmt = $conexion->prepare("SELECT id_usuario FROM usuario WHERE correo=? LIMIT 1");
            $stmt->bind_param("s",$correo);
            $stmt->execute();
            if ($stmt->get_result()->fetch_assoc()) {
                redir("Ese correo ya está registrado.", "error", "configuracion");
            }

            $hash = password_hash($clave,PASSWORD_DEFAULT);
            $telefono = trim($_POST["admin_telefono"] ?? "");
            $estado = "Activo";
            $stmt = $conexion->prepare("
                INSERT INTO usuario
                (nombres,apellidos,correo,contrasena,telefono,estado,rol_sistema)
                VALUES (?,?,?,?,?,?,?)
            ");
            $stmt->bind_param("sssssss",$nombres,$apellidos,$correo,$hash,$telefono,$estado,$rol);
            $stmt->execute();

            redir("Cuenta de ".$rol." creada correctamente", "ok", "configuracion");
        }

        if (isset($_POST["actualizar_usuario_admin"])) {
            if (rolActual() !== "Administrador") {
                redir("Solo el Administrador puede cambiar roles del personal.", "error", "configuracion");
            }

            $idPersonal = (int)($_POST["id_usuario_admin"] ?? 0);
            $rol = trim($_POST["rol_usuario_admin"] ?? "");
            $estado = trim($_POST["estado_usuario_admin"] ?? "");

            if ($idPersonal <= 0 ||
                !in_array($rol,["Administrador","Vendedor","Almacen"],true) ||
                !in_array($estado,["Activo","Bloqueado"],true)) {
                redir("Rol o estado administrativo inválido.", "error", "configuracion");
            }

            $idSesion = (int)($adminSesion["id_usuario"] ?? $adminSesion["id_admin"] ?? 0);
            if ($idPersonal === $idSesion && ($rol !== "Administrador" || $estado !== "Activo")) {
                redir("No puedes quitarte tu propio acceso de Administrador.", "error", "configuracion");
            }

            $stmt = $conexion->prepare("
                UPDATE usuario
                SET rol_sistema=?,estado=?
                WHERE id_usuario=? AND rol_sistema<>'Cliente'
            ");
            $stmt->bind_param("ssi",$rol,$estado,$idPersonal);
            $stmt->execute();

            redir("Cuenta administrativa actualizada", "ok", "configuracion");
        }

        if (isset($_POST["cambiar_clave_admin"])) {
            $claveActual = (string)($_POST["clave_actual"] ?? "");
            $claveNueva = (string)($_POST["clave_nueva"] ?? "");
            $claveConfirmar = (string)($_POST["clave_confirmar"] ?? "");
            $idSesion = (int)($adminSesion["id_usuario"] ?? $adminSesion["id_admin"] ?? 0);

            if (strlen($claveNueva) < 8 || $claveNueva !== $claveConfirmar) {
                redir("La nueva contraseña debe tener mínimo 8 caracteres y coincidir.", "error", "configuracion");
            }

            $stmt = $conexion->prepare("SELECT contrasena FROM usuario WHERE id_usuario=? LIMIT 1");
            $stmt->bind_param("i",$idSesion);
            $stmt->execute();
            $filaClave = $stmt->get_result()->fetch_assoc();

            if (!$filaClave || !password_verify($claveActual,(string)$filaClave["contrasena"])) {
                redir("La contraseña actual es incorrecta.", "error", "configuracion");
            }

            $hashNueva = password_hash($claveNueva,PASSWORD_DEFAULT);
            $stmt = $conexion->prepare("UPDATE usuario SET contrasena=? WHERE id_usuario=?");
            $stmt->bind_param("si",$hashNueva,$idSesion);
            $stmt->execute();

            redir("Contraseña administrativa actualizada", "ok", "configuracion");
        }

        /* ================= CONFIGURACIÓN ================= */

    } catch (Throwable $e) {
        $mensaje = "Error: " . $e->getMessage();
        $tipoMensaje = "error";
    }
}

/* ================= ATENCIÓN AL CLIENTE ================= */
$solicitudesSoporte = [];
$totalSoportePendiente = 0;
if (puede("soporte")) {
    $resultadoSoporte = $conexion->query(
        "SELECT s.id_solicitud,s.id_usuario,s.asunto,s.mensaje,s.respuesta,s.estado,
                s.fecha_creacion,s.fecha_actualizacion,
                u.nombres,u.apellidos,u.correo
         FROM solicitud_soporte s
         INNER JOIN usuario u ON u.id_usuario=s.id_usuario
         ORDER BY CASE WHEN s.estado IN ('Abierto','En proceso') THEN 0 ELSE 1 END,
                  s.id_solicitud DESC
         LIMIT 200"
    );
    $solicitudesSoporte = $resultadoSoporte->fetch_all(MYSQLI_ASSOC);
    $totalSoportePendiente = (int)$conexion->query(
        "SELECT COUNT(*) AS total FROM solicitud_soporte
         WHERE estado IN ('Abierto','En proceso')"
    )->fetch_assoc()["total"];
}

/* ================= MÉTRICAS ================= */
$totalProductos = (int)$conexion->query("SELECT COUNT(*) AS total FROM producto")->fetch_assoc()["total"];
$totalUsuarios = (int)$conexion->query("SELECT COUNT(*) AS total FROM usuario WHERE rol_sistema='Cliente'")->fetch_assoc()["total"];
$totalPedidos = (int)$conexion->query("SELECT COUNT(*) AS total FROM pedido")->fetch_assoc()["total"];
$totalVentas = (float)$conexion->query("
    SELECT COALESCE(SUM(total),0) AS total
    FROM pedido
    WHERE LOWER(estado_pedido) <> 'cancelado'
")->fetch_assoc()["total"];
$totalPagos = (float)$conexion->query("SELECT COALESCE(SUM(monto),0) AS total FROM pago WHERE estado_pago='Pagado'")->fetch_assoc()["total"];
$totalCategorias = (int)$conexion->query("SELECT COUNT(*) AS total FROM categoria")->fetch_assoc()["total"];
$totalMarcas = (int)$conexion->query("SELECT COUNT(*) AS total FROM marca")->fetch_assoc()["total"];

$totalProveedores = (int)$conexion->query("SELECT COUNT(*) AS total FROM proveedor")->fetch_assoc()["total"];
$totalCompras = (float)$conexion->query("
    SELECT COALESCE(SUM(total),0) AS total
    FROM compra
    WHERE LOWER(estado)<>'anulado'
")->fetch_assoc()["total"];
$stockBajo = (int)$conexion->query("SELECT COUNT(*) AS total FROM producto WHERE stock <= stock_minimo")->fetch_assoc()["total"];
$unidadesStock = (int)$conexion->query("SELECT COALESCE(SUM(stock),0) AS total FROM producto")->fetch_assoc()["total"];
$pedidosPendientes = (int)$conexion->query("
    SELECT COUNT(*) AS total
    FROM pedido
    WHERE LOWER(estado_pedido) IN ('pendiente','procesando')
")->fetch_assoc()["total"];
$ventasHoy = (float)$conexion->query("
    SELECT COALESCE(SUM(total),0) AS total
    FROM pedido
    WHERE DATE(fecha_pedido)=CURDATE()
      AND LOWER(estado_pedido) <> 'cancelado'
")->fetch_assoc()["total"];
$ventasMes = (float)$conexion->query("
    SELECT COALESCE(SUM(total),0) AS total
    FROM pedido
    WHERE YEAR(fecha_pedido)=YEAR(CURDATE())
      AND MONTH(fecha_pedido)=MONTH(CURDATE())
      AND LOWER(estado_pedido) <> 'cancelado'
")->fetch_assoc()["total"];

$gananciaEstimada = (float)$conexion->query("
    SELECT COALESCE(SUM(
        dp.cantidad * (
            dp.precio_unitario - COALESCE(costos.costo_promedio, dp.precio_unitario)
        )
    ),0) AS ganancia
    FROM detalle_pedido dp
    INNER JOIN pedido pe ON dp.id_pedido=pe.id_pedido
    LEFT JOIN (
        SELECT dc.id_producto,
               CASE WHEN SUM(dc.cantidad)>0 THEN SUM(dc.subtotal)/SUM(dc.cantidad) ELSE 0 END AS costo_promedio
        FROM detalle_compra dc
        INNER JOIN compra co ON dc.id_compra=co.id_compra
        WHERE LOWER(co.estado)<>'anulado'
        GROUP BY dc.id_producto
    ) costos ON dp.id_producto=costos.id_producto
    WHERE LOWER(pe.estado_pedido) <> 'cancelado'
")->fetch_assoc()["ganancia"];
$stockCritico = (int)$conexion->query("
    SELECT COUNT(*) AS total
    FROM producto
    WHERE stock <= LEAST(stock_minimo,2)
")->fetch_assoc()["total"];

/* ================= VENTAS 7 DÍAS ================= */
$ventasConsulta = $conexion->query("
    SELECT DATE(fecha_pedido) AS fecha, COALESCE(SUM(total),0) AS total
    FROM pedido
    WHERE DATE(fecha_pedido) >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
      AND LOWER(estado_pedido)<>'cancelado'
    GROUP BY DATE(fecha_pedido)
    ORDER BY fecha
");

$ventasPorFecha = [];
while ($fila = $ventasConsulta->fetch_assoc()) {
    $ventasPorFecha[$fila["fecha"]] = (float)$fila["total"];
}

$diasCortos = ["Dom","Lun","Mar","Mié","Jue","Vie","Sáb"];
$ventas7 = [];
$maxVenta = 1;
for ($i=6; $i>=0; $i--) {
    $fecha = date("Y-m-d", strtotime("-$i day"));
    $total = $ventasPorFecha[$fecha] ?? 0;
    $maxVenta = max($maxVenta, $total);
    $ventas7[] = [
        "fecha"=>$fecha,
        "dia"=>$diasCortos[(int)date("w", strtotime($fecha))],
        "total"=>$total
    ];
}

$pedidosConsulta = $conexion->query("
    SELECT DATE(fecha_pedido) AS fecha, COUNT(*) AS total
    FROM pedido
    WHERE DATE(fecha_pedido) >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
      AND LOWER(estado_pedido)<>'cancelado'
    GROUP BY DATE(fecha_pedido)
    ORDER BY fecha
");
$pedidosPorFecha = [];
while ($fila = $pedidosConsulta->fetch_assoc()) {
    $pedidosPorFecha[$fila["fecha"]] = (int)$fila["total"];
}
$pedidos7 = [];
$maxPedidos = 1;
for ($i=6; $i>=0; $i--) {
    $fecha = date("Y-m-d", strtotime("-$i day"));
    $total = $pedidosPorFecha[$fecha] ?? 0;
    $maxPedidos = max($maxPedidos, $total);
    $pedidos7[] = [
        "fecha"=>$fecha,
        "dia"=>$diasCortos[(int)date("w", strtotime($fecha))],
        "total"=>$total
    ];
}

/* ================= DATOS ================= */
$categorias = $conexion->query("SELECT * FROM categoria ORDER BY nombre_categoria")->fetch_all(MYSQLI_ASSOC);
$marcas = $conexion->query("SELECT * FROM marca ORDER BY nombre_marca")->fetch_all(MYSQLI_ASSOC);

$productos = $conexion->query("
    SELECT p.*, c.nombre_categoria, m.nombre_marca
    FROM producto p
    INNER JOIN categoria c ON p.id_categoria=c.id_categoria
    INNER JOIN marca m ON p.id_marca=m.id_marca
    ORDER BY p.id_producto DESC
")->fetch_all(MYSQLI_ASSOC);

$usuarios = $conexion->query("
    SELECT id_usuario,nombres,apellidos,correo,telefono,estado
    FROM usuario
    WHERE rol_sistema='Cliente'
    ORDER BY id_usuario DESC
")->fetch_all(MYSQLI_ASSOC);

$direcciones = $conexion->query("
    SELECT d.*,u.nombres,u.apellidos,u.correo
    FROM direccion d
    INNER JOIN usuario u ON d.id_usuario=u.id_usuario
    ORDER BY d.id_direccion DESC
")->fetch_all(MYSQLI_ASSOC);

$pedidos = $conexion->query("
    SELECT p.*, u.nombres,u.apellidos
    FROM pedido p
    INNER JOIN usuario u ON p.id_usuario=u.id_usuario
    ORDER BY p.id_pedido DESC
")->fetch_all(MYSQLI_ASSOC);

$pagos = $conexion->query("
    SELECT
        pg.*,
        p.id_usuario,
        p.total AS total_pedido,
        u.nombres,
        u.apellidos,
        COALESCE((
            SELECT SUM(pg2.monto)
            FROM pago pg2
            WHERE pg2.id_pedido=p.id_pedido
              AND pg2.estado_pago='Pagado'
        ),0) AS total_pagado,
        GREATEST(
            p.total - COALESCE((
                SELECT SUM(pg3.monto)
                FROM pago pg3
                WHERE pg3.id_pedido=p.id_pedido
                  AND pg3.estado_pago='Pagado'
            ),0),
            0
        ) AS saldo
    FROM pago pg
    INNER JOIN pedido p ON pg.id_pedido=p.id_pedido
    INNER JOIN usuario u ON p.id_usuario=u.id_usuario
    ORDER BY pg.id_pago DESC
")->fetch_all(MYSQLI_ASSOC);

$proveedores = $conexion->query("
    SELECT * FROM proveedor
    ORDER BY id_proveedor DESC
")->fetch_all(MYSQLI_ASSOC);

$usuariosAdmin = $conexion->query("
    SELECT id_usuario,nombres,apellidos,correo,telefono,estado,rol_sistema,ultimo_acceso
    FROM usuario
    WHERE rol_sistema IN ('Administrador','Vendedor','Almacen')
    ORDER BY FIELD(rol_sistema,'Administrador','Vendedor','Almacen'),nombres,apellidos
")->fetch_all(MYSQLI_ASSOC);

$compras = $conexion->query("
    SELECT
        c.id_compra,c.fecha_compra,c.total,c.estado,
        p.razon_social,
        COALESCE(SUM(dc.cantidad),0) AS cantidad,
        GROUP_CONCAT(
            CONCAT(pr.nombre_producto,' x',dc.cantidad,' @ S/ ',FORMAT(dc.precio_compra,2))
            ORDER BY dc.id_detalle_compra
            SEPARATOR ' | '
        ) AS nombre_producto
    FROM compra c
    INNER JOIN proveedor p ON c.id_proveedor=p.id_proveedor
    LEFT JOIN detalle_compra dc ON c.id_compra=dc.id_compra
    LEFT JOIN producto pr ON dc.id_producto=pr.id_producto
    GROUP BY c.id_compra,c.fecha_compra,c.total,c.estado,p.razon_social
    ORDER BY c.id_compra DESC
")->fetch_all(MYSQLI_ASSOC);

$movimientos = $conexion->query("
    SELECT ms.*,p.nombre_producto
    FROM movimiento_stock ms
    INNER JOIN producto p ON ms.id_producto=p.id_producto
    ORDER BY ms.id_movimiento DESC
    LIMIT 30
")->fetch_all(MYSQLI_ASSOC);

$comprobantes = $conexion->query("
    SELECT c.*,p.id_usuario,u.nombres,u.apellidos
    FROM comprobante c
    INNER JOIN pedido p ON c.id_pedido=p.id_pedido
    INNER JOIN usuario u ON p.id_usuario=u.id_usuario
    ORDER BY c.id_comprobante DESC
")->fetch_all(MYSQLI_ASSOC);

$productosStockBajo = $conexion->query("
    SELECT id_producto,nombre_producto,stock,stock_minimo,precio
    FROM producto
    WHERE stock <= stock_minimo
    ORDER BY stock ASC,nombre_producto ASC
    LIMIT 8
")->fetch_all(MYSQLI_ASSOC);

$masVendidos = $conexion->query("
    SELECT p.nombre_producto, COALESCE(SUM(CASE WHEN pe.id_pedido IS NOT NULL THEN dp.cantidad ELSE 0 END),0) AS vendidos
    FROM producto p
    LEFT JOIN detalle_pedido dp ON p.id_producto=dp.id_producto
    LEFT JOIN pedido pe ON dp.id_pedido=pe.id_pedido AND LOWER(pe.estado_pedido)<>'cancelado'
    GROUP BY p.id_producto,p.nombre_producto
    ORDER BY vendidos DESC,p.nombre_producto ASC
    LIMIT 5
")->fetch_all(MYSQLI_ASSOC);

$clientes = $conexion->query("
    SELECT
        u.id_usuario,
        u.nombres,
        u.apellidos,
        u.correo,
        u.telefono,
        u.estado,
        COUNT(DISTINCT p.id_pedido) AS total_pedidos,
        COALESCE(SUM(p.total),0) AS total_comprado,
        MAX(p.fecha_pedido) AS ultima_compra
    FROM usuario u
    LEFT JOIN pedido p ON u.id_usuario=p.id_usuario AND LOWER(p.estado_pedido)<>'cancelado'
    WHERE u.rol_sistema='Cliente'
    GROUP BY u.id_usuario,u.nombres,u.apellidos,u.correo,u.telefono,u.estado
    ORDER BY total_comprado DESC,u.id_usuario DESC
")->fetch_all(MYSQLI_ASSOC);

$pedidoDetalle = null;
$pedidoDetalleItems = [];
if (isset($_GET["pedido_detalle"])) {
    $idPedidoDetalle = (int)$_GET["pedido_detalle"];

    $stmt = $conexion->prepare("
        SELECT p.*,u.nombres,u.apellidos,u.correo,u.telefono
        FROM pedido p
        INNER JOIN usuario u ON p.id_usuario=u.id_usuario
        WHERE p.id_pedido=?
        LIMIT 1
    ");
    $stmt->bind_param("i",$idPedidoDetalle);
    $stmt->execute();
    $pedidoDetalle = $stmt->get_result()->fetch_assoc();

    if ($pedidoDetalle) {
        $stmt = $conexion->prepare("
            SELECT dp.*,pr.nombre_producto,pr.imagen_url
            FROM detalle_pedido dp
            INNER JOIN producto pr ON dp.id_producto=pr.id_producto
            WHERE dp.id_pedido=?
            ORDER BY dp.id_detalle
        ");
        $stmt->bind_param("i",$idPedidoDetalle);
        $stmt->execute();
        $pedidoDetalleItems = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    }
}

$clienteDetalle = null;
$clientePedidos = [];
if (isset($_GET["cliente"])) {
    $idCliente = (int)$_GET["cliente"];

    $stmt = $conexion->prepare("
        SELECT id_usuario,nombres,apellidos,correo,telefono,estado
        FROM usuario
        WHERE id_usuario=?
        LIMIT 1
    ");
    $stmt->bind_param("i",$idCliente);
    $stmt->execute();
    $clienteDetalle = $stmt->get_result()->fetch_assoc();

    if ($clienteDetalle) {
        $stmt = $conexion->prepare("
            SELECT id_pedido,fecha_pedido,estado_pedido,total,tipo_entrega
            FROM pedido
            WHERE id_usuario=?
            ORDER BY id_pedido DESC
        ");
        $stmt->bind_param("i",$idCliente);
        $stmt->execute();
        $clientePedidos = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    }
}

$reporteDesde = $_GET["desde"] ?? date("Y-m-01");
$reporteHasta = $_GET["hasta"] ?? date("Y-m-d");

if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $reporteDesde)) $reporteDesde = date("Y-m-01");
if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $reporteHasta)) $reporteHasta = date("Y-m-d");
if ($reporteDesde > $reporteHasta) {
    [$reporteDesde,$reporteHasta] = [$reporteHasta,$reporteDesde];
}

$stmt = $conexion->prepare("
    SELECT
        COUNT(*) AS pedidos,
        COALESCE(SUM(total),0) AS ventas,
        COALESCE(AVG(total),0) AS ticket_promedio
    FROM pedido
    WHERE DATE(fecha_pedido) BETWEEN ? AND ?
      AND LOWER(estado_pedido)<>'cancelado'
");
$stmt->bind_param("ss",$reporteDesde,$reporteHasta);
$stmt->execute();
$reporteResumen = $stmt->get_result()->fetch_assoc();

$stmt = $conexion->prepare("
    SELECT
        pr.nombre_producto,
        COALESCE(SUM(dp.cantidad),0) AS unidades,
        COALESCE(SUM(dp.cantidad * dp.precio_unitario),0) AS importe
    FROM detalle_pedido dp
    INNER JOIN pedido pe ON dp.id_pedido=pe.id_pedido
    INNER JOIN producto pr ON dp.id_producto=pr.id_producto
    WHERE DATE(pe.fecha_pedido) BETWEEN ? AND ?
      AND LOWER(pe.estado_pedido)<>'cancelado'
    GROUP BY pr.id_producto,pr.nombre_producto
    ORDER BY unidades DESC,importe DESC
    LIMIT 10
");
$stmt->bind_param("ss",$reporteDesde,$reporteHasta);
$stmt->execute();
$reporteTopProductos = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

$productoEditar = null;
if (isset($_GET["editar"])) {
    $idEditar = (int)$_GET["editar"];
    $stmt = $conexion->prepare("SELECT * FROM producto WHERE id_producto=?");
    $stmt->bind_param("i",$idEditar);
    $stmt->execute();
    $productoEditar = $stmt->get_result()->fetch_assoc();
}

$categoriaEditar = null;
if (isset($_GET["editar_categoria"])) {
    $idEditarCategoria = (int)$_GET["editar_categoria"];
    $stmt = $conexion->prepare("SELECT * FROM categoria WHERE id_categoria=?");
    $stmt->bind_param("i", $idEditarCategoria);
    $stmt->execute();
    $categoriaEditar = $stmt->get_result()->fetch_assoc();
}

$marcaEditar = null;
if (isset($_GET["editar_marca"])) {
    $idEditarMarca = (int)$_GET["editar_marca"];
    $stmt = $conexion->prepare("SELECT * FROM marca WHERE id_marca=?");
    $stmt->bind_param("i", $idEditarMarca);
    $stmt->execute();
    $marcaEditar = $stmt->get_result()->fetch_assoc();
}

$clienteEditar = null;
if (isset($_GET["editar_cliente"])) {
    $idEditarCliente = (int)$_GET["editar_cliente"];
    $stmt = $conexion->prepare("SELECT id_usuario,nombres,apellidos,correo,telefono,estado FROM usuario WHERE id_usuario=?");
    $stmt->bind_param("i", $idEditarCliente);
    $stmt->execute();
    $clienteEditar = $stmt->get_result()->fetch_assoc();
}

$proveedorEditar = null;
if (isset($_GET["editar_proveedor"])) {
    $idEditarProveedor = (int)$_GET["editar_proveedor"];
    $stmt = $conexion->prepare("SELECT * FROM proveedor WHERE id_proveedor=?");
    $stmt->bind_param("i", $idEditarProveedor);
    $stmt->execute();
    $proveedorEditar = $stmt->get_result()->fetch_assoc();
}

$direccionEditar = null;
if (isset($_GET["editar_direccion"])) {
    $idEditarDireccion = (int)$_GET["editar_direccion"];
    $stmt = $conexion->prepare("SELECT * FROM direccion WHERE id_direccion=?");
    $stmt->bind_param("i",$idEditarDireccion);
    $stmt->execute();
    $direccionEditar = $stmt->get_result()->fetch_assoc();
}

$fechaHoy = date("d/m/Y");
$adminNombre = trim((string)($adminSesion["nombres"] ?? "Administrador"));
$adminRol = (string)($adminSesion["rol"] ?? "Administrador");
$partesAdmin = preg_split('/\s+/', $adminNombre) ?: ["A"];
$inicialesAdmin = strtoupper(substr($partesAdmin[0] ?? "A",0,1) . substr($partesAdmin[count($partesAdmin)-1] ?? "",0,1));
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Dorada Motors | Panel Administrativo</title>
<style>
:root{
 --navy:#151820;--navy2:#242933;--gold:#ff6a00;--gold2:#c92b18;--gold-soft:#fff0e5;
 --bg:#f4f7fb;--surface:#fff;--text:#13233a;--muted:#718096;--border:#e5eaf1;
 --green:#17a56b;--green-soft:#ddf7eb;--blue:#2878e6;--blue-soft:#e8f1ff;
 --purple:#7357e8;--purple-soft:#efeaff;--red:#df3848;--red-soft:#ffe8ea;
 --shadow:0 10px 30px rgba(15,39,70,.07);
}
*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{margin:0;font-family:Inter,Segoe UI,Arial,sans-serif;background:var(--bg);color:var(--text)}
button,input,select,textarea{font:inherit}
button{cursor:pointer}
a{text-decoration:none;color:inherit}
.app{min-height:100vh;display:grid;grid-template-columns:218px minmax(0,1fr)}
.sidebar{position:sticky;top:0;height:100vh;background:linear-gradient(180deg,#11151b,#1b2028);color:#fff;padding:18px 14px;display:flex;flex-direction:column;overflow:auto;z-index:50;border-right:1px solid rgba(255,255,255,.05)}
.brand{display:flex;align-items:center;gap:11px;padding:0 7px 24px}
.brand-logo{width:52px;height:52px;object-fit:cover;border-radius:14px;border:1px solid rgba(255,106,0,.5);box-shadow:0 8px 24px rgba(0,0,0,.25)}
.mobile-brand-logo{display:none;width:42px;height:42px;object-fit:cover;border-radius:10px}
.top-title{font-size:13px;font-weight:900;color:var(--text);white-space:nowrap}
.search kbd{position:absolute;right:9px;top:50%;transform:translateY(-50%);padding:3px 6px;border:1px solid var(--border);border-bottom-width:2px;border-radius:6px;background:#fff;color:var(--muted);font-size:9px;font-family:inherit}
.notify-wrap{position:relative}.notification-count{position:absolute;right:-5px;top:-6px;min-width:18px;height:18px;padding:0 4px;border-radius:999px;background:#e22f22;color:#fff;border:2px solid #fff;font-size:9px;font-weight:900;display:grid;place-items:center}
.notify-menu{display:none;position:absolute;right:0;top:48px;width:310px;background:#fff;border:1px solid var(--border);border-radius:15px;box-shadow:0 18px 45px rgba(15,24,35,.18);padding:9px;z-index:100}
.notify-menu.show{display:block}.notify-head{display:flex;align-items:center;justify-content:space-between;padding:8px 9px 10px}.notify-head span{font-size:9px;color:var(--muted)}
.notify-menu a{display:flex;flex-direction:column;gap:3px;padding:10px;border-radius:10px}.notify-menu a:hover{background:#f7f8fa}.notify-menu b{font-size:11px}.notify-menu small{font-size:10px;color:var(--muted)}
.brand-hero{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:20px;align-items:center;margin-bottom:16px;padding:22px 24px;border-radius:20px;background:radial-gradient(circle at 80% 20%,rgba(255,106,0,.28),transparent 30%),linear-gradient(135deg,#11141a,#262a31);color:#fff;box-shadow:0 14px 40px rgba(17,20,26,.16);overflow:hidden}
.brand-hero h1{margin:3px 0 7px;font-size:28px;line-height:1.05}.brand-hero p{margin:0;color:#d5d8dd;font-size:13px}.hero-tags{display:flex;gap:7px;flex-wrap:wrap;margin-top:13px}.hero-tags span{font-size:9px;font-weight:800;padding:6px 9px;border-radius:999px;background:rgba(255,255,255,.08);color:#e8edf2}.hero-tags span::first-letter{color:#42c77a}
.live-refresh-btn{border:1px solid rgba(255,255,255,.16);background:rgba(255,255,255,.08);color:#fff;border-radius:999px;padding:6px 10px;font-size:9px;font-weight:900;cursor:pointer}
.live-refresh-btn:hover{background:rgba(255,106,0,.24);border-color:rgba(255,129,53,.45)}
.live-refresh-btn.is-loading{opacity:.65;pointer-events:none}
.hero-brand{display:flex;align-items:center;gap:12px}.hero-brand img{width:100px;height:100px;object-fit:cover;border-radius:18px;border:1px solid rgba(255,255,255,.12);box-shadow:0 12px 30px rgba(0,0,0,.28)}.hero-brand small{display:none}
.metric small{display:block;margin-top:3px;font-size:9px;color:var(--muted);font-weight:700}.metric-icon.red{background:#ffe9e6;color:#d43122}.metric-icon.orange{background:#fff0e5;color:#ef6200}
.home-tools{display:grid;grid-template-columns:1.05fr 1fr 1fr;gap:16px}.compact-list{display:flex;flex-direction:column}.compact-row{display:grid;grid-template-columns:34px minmax(0,1fr) auto;align-items:center;gap:9px;padding:10px 3px;border-bottom:1px solid var(--border)}.compact-row:hover{background:#fafbfc}.compact-row strong{display:block;font-size:10px}.compact-row small{display:block;margin-top:2px;font-size:9px;color:var(--muted)}.compact-row>b{font-size:10px}.product-dot{width:28px;height:28px;border-radius:9px;background:linear-gradient(135deg,#ff6a00,#c92b18)}.payment-dot{width:28px;height:28px;border-radius:9px;background:#e9f8f0;color:#168a5c;display:grid;place-items:center;font-size:9px;font-weight:900}.critical-text{color:#d53124}.warning-text{color:#c47d00}.empty-state{padding:18px;text-align:center;color:var(--muted);font-size:11px}
.section-actions{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.system-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px}.system-card{display:flex;align-items:flex-start;gap:11px;padding:16px;border:1px solid var(--border);border-radius:14px;background:#fafbfc}.system-card small{display:block;font-size:9px;color:var(--muted);font-weight:900;letter-spacing:.5px}.system-card strong{display:block;margin-top:3px;font-size:13px}.system-card p{margin:3px 0 0;font-size:10px;color:var(--muted);line-height:1.35}.system-icon{width:34px;height:34px;border-radius:10px;display:grid;place-items:center;font-weight:900;flex:0 0 auto}.system-icon.ok{background:#e7f7ee;color:#13885a}.system-icon.warn{background:#fff0e4;color:#e05e00}.help-card{display:flex;align-items:center;justify-content:space-between;gap:16px;margin-top:14px;padding:16px;border-radius:14px;background:linear-gradient(135deg,#fff5ed,#fff);border:1px solid #ffd7be}.help-card strong{font-size:13px}.help-card p{margin:4px 0 0;color:var(--muted);font-size:10px}
.order-bar{background:linear-gradient(180deg,#ff6a00,#c92b18)}
.line-item-row{display:grid;grid-template-columns:minmax(0,1fr) 110px auto;gap:8px;align-items:center;margin-bottom:8px}
.purchase-line{grid-template-columns:minmax(0,1fr) 100px 130px auto}
.line-item-row select,.line-item-row input{min-width:0}
@media(max-width:760px){.line-item-row,.purchase-line{grid-template-columns:1fr}.line-item-row .btn{width:100%}}

.brand-mark{width:38px;height:38px;border:2px solid var(--gold);border-radius:12px 4px;display:grid;place-items:center;color:var(--gold);font-weight:900;transform:rotate(45deg)}
.brand-mark span{transform:rotate(-45deg)}
.brand-title{font-size:18px;font-weight:900}.brand-title b{color:var(--gold)}
.brand-sub{font-size:10px;color:#aebed0;margin-top:3px}
.nav{display:flex;flex-direction:column;gap:5px}
.nav-group{font-size:8px;letter-spacing:1.25px;font-weight:900;color:#738091;padding:13px 12px 3px;margin-top:2px}
.logout-btn{padding:9px 11px;border-radius:10px;background:#fff1ee;color:#bb321f;font-size:10px;font-weight:900;border:1px solid #ffd7d0}
.logout-btn:hover{background:#ffe7e2}

.nav-simple{gap:7px}
.nav-main{width:100%;min-height:44px;display:flex!important;align-items:center;gap:12px;padding:11px 13px!important;border-radius:12px!important;color:#d7e2ee!important;font-weight:800!important;font-size:13px!important;background:transparent;border:0;text-align:left;cursor:pointer}
.nav-main>span:nth-child(2){flex:1}
.nav-main:hover,.nav-main.active,.nav-folder.open>.nav-main{background:linear-gradient(90deg,#ff6a00,#c92b18)!important;color:#fff!important}
.nav-folder{display:flex;flex-direction:column;gap:4px}
.nav-chevron{margin-left:auto;font-size:18px;line-height:1;transition:transform .18s;color:inherit}
.nav-folder.open .nav-chevron{transform:rotate(90deg)}
.nav-submenu{display:none;margin:0 0 3px 40px;padding-left:10px;border-left:1px solid rgba(255,255,255,.12)}
.nav-folder.open .nav-submenu{display:flex;flex-direction:column;gap:3px}
.nav-submenu a{padding:8px 10px!important;border-radius:9px!important;color:#aeb9c7!important;font-size:11px!important;font-weight:700!important}
.nav-submenu a:hover,.nav-submenu a.active{background:rgba(255,106,0,.14)!important;color:#ff9a58!important}
.nav-group{display:none}
.quick-actions-clean{grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}
.nav a{display:flex;align-items:center;gap:12px;padding:11px 13px;border-radius:12px;color:#d7e2ee;font-weight:700;font-size:13px}
.nav a:hover,.nav a.active{background:linear-gradient(90deg,#ff6a00,#c92b18);color:#fff}
.nav-icon{width:20px;text-align:center}
.motto{margin:18px 0;padding:14px;border-radius:15px;background:rgba(255,255,255,.05);color:#efc65b;text-align:center;font-style:italic;line-height:1.4}
.sidebar-bottom{margin-top:auto;border-top:1px solid rgba(255,255,255,.1);padding-top:16px;color:#b8c7d7;font-size:11px}
.sidebar-bottom strong{display:block;color:#fff;margin-bottom:4px}
.main{min-width:0}
.topbar{height:70px;background:#fff;border-bottom:1px solid var(--border);display:flex;align-items:center;gap:18px;padding:0 24px;position:sticky;top:0;z-index:30}
.mobile-menu{display:none;width:42px;height:42px;border:0;background:#f3f6fa;border-radius:12px}
.search{width:min(470px,45vw);position:relative}
.search input{width:100%;border:1px solid var(--border);background:#f7f9fc;border-radius:11px;padding:11px 14px 11px 40px;outline:none}
.search span{position:absolute;left:14px;top:50%;transform:translateY(-50%);color:var(--muted)}
.top-actions{margin-left:auto;display:flex;align-items:center;gap:12px}
.icon-btn{width:40px;height:40px;border:1px solid var(--border);border-radius:12px;background:#fff;display:grid;place-items:center;position:relative}
.notification-dot{width:8px;height:8px;background:var(--red);border-radius:50%;position:absolute;right:7px;top:7px;border:2px solid #fff}
.admin{display:flex;align-items:center;gap:10px;padding-left:10px;border-left:1px solid var(--border)}
.avatar{width:38px;height:38px;border-radius:50%;background:linear-gradient(135deg,var(--navy),var(--gold));color:#fff;display:grid;place-items:center;font-weight:900}
.admin small{display:block;color:var(--muted);font-size:10px}.admin strong{font-size:12px}
.content{padding:22px;max-width:1380px;margin:auto}
.heading{display:flex;justify-content:space-between;align-items:flex-end;gap:20px;margin-bottom:18px}
.eyebrow{font-size:11px;font-weight:900;letter-spacing:1.2px;color:#a67a12;text-transform:uppercase;margin-bottom:5px}
.heading h1{font-size:25px;margin:0 0 5px;font-weight:900}.heading p{margin:0;color:var(--muted);font-size:13px}
.date-chip{background:#fff;border:1px solid var(--border);border-radius:11px;padding:10px 13px;color:var(--muted);font-size:12px;font-weight:700}
.metrics{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:14px;margin-bottom:16px}
.metric{background:#fff;border:1px solid var(--border);border-radius:16px;padding:18px;box-shadow:var(--shadow);display:flex;align-items:center;gap:13px}
.metric-icon{width:50px;height:50px;border-radius:14px;display:grid;place-items:center;font-size:22px}
.metric-icon.blue{background:var(--blue-soft);color:var(--blue)}.metric-icon.gold{background:var(--gold-soft);color:#a87500}.metric-icon.purple{background:var(--purple-soft);color:var(--purple)}.metric-icon.green{background:var(--green-soft);color:var(--green)}
.metric-label{color:var(--muted);font-size:12px;font-weight:700}.metric-value{font-size:24px;font-weight:900;margin-top:3px;color:#10233e}
.grid-main{display:grid;grid-template-columns:minmax(0,1.35fr) minmax(320px,.75fr);gap:16px;margin-bottom:16px}
.grid-bottom{display:grid;grid-template-columns:minmax(0,1.25fr) minmax(280px,.75fr);gap:16px;margin-bottom:16px}
.card{background:#fff;border:1px solid var(--border);border-radius:17px;box-shadow:var(--shadow);padding:18px;min-width:0;margin-bottom:16px}
.card-head{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:14px}
.card-head h2{font-size:15px;margin:0;font-weight:900}.card-head a{font-size:11px;color:var(--blue);font-weight:800}
.chart{height:190px;display:flex;align-items:flex-end;gap:12px;padding:16px 4px 0;border-bottom:1px solid var(--border);background:linear-gradient(to top,rgba(229,234,241,.65) 1px,transparent 1px);background-size:100% 25%}
.chart-item{flex:1;height:100%;display:flex;flex-direction:column;justify-content:flex-end;align-items:center;gap:7px}
.bar{width:min(44px,80%);min-height:4px;border-radius:9px 9px 3px 3px;background:linear-gradient(180deg,#e2b94e,#17395f);position:relative}
.bar-tip{opacity:0;position:absolute;left:50%;bottom:calc(100% + 7px);transform:translateX(-50%);background:#10233e;color:#fff;padding:6px 8px;border-radius:8px;font-size:10px;white-space:nowrap}
.bar:hover .bar-tip{opacity:1}.day{font-size:10px;color:var(--muted);font-weight:700}
.quick-actions{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}
.quick{border:1px solid var(--border);border-radius:14px;padding:13px 10px;min-height:74px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;font-size:11px;font-weight:800;text-align:center;transition:.2s}
.quick:hover{transform:translateY(-2px);box-shadow:var(--shadow)}
.quick.blue{background:#eef5ff;color:#245fae}.quick.gold{background:#fff5dd;color:#9d7108}.quick.purple{background:#f1edff;color:#674bc9}.quick.green{background:#e9f9f1;color:#158a5a}
.table-wrap{overflow:auto}
table{width:100%;border-collapse:collapse;min-width:640px}
th{text-transform:uppercase;font-size:9px;letter-spacing:.5px;color:var(--muted);text-align:left;background:#f7f9fc;padding:10px;border-bottom:1px solid var(--border)}
td{padding:11px 10px;border-bottom:1px solid var(--border);font-size:11px;vertical-align:middle}
tbody tr:hover{background:#fafcff}
.status{display:inline-flex;padding:5px 9px;border-radius:20px;font-size:9px;font-weight:900}.status.ok{background:var(--green-soft);color:var(--green)}.status.info{background:var(--blue-soft);color:var(--blue)}.status.warn{background:var(--gold-soft);color:#a26f00}.status.danger{background:var(--red-soft);color:var(--red)}
.top-list{display:flex;flex-direction:column;gap:8px}.top-product{display:grid;grid-template-columns:30px minmax(0,1fr) auto;align-items:center;gap:9px;padding:9px 0;border-bottom:1px solid var(--border)}
.rank{width:26px;height:26px;border-radius:50%;background:var(--gold-soft);color:#9a6c00;display:grid;place-items:center;font-size:11px;font-weight:900}
.top-product strong{font-size:11px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.top-product span{font-size:10px;color:var(--muted)}
.section-title{display:flex;justify-content:space-between;align-items:center;gap:12px;margin-bottom:14px}.section-title h2{margin:0;font-size:18px}
.badge{background:var(--gold-soft);color:#8f6707;font-size:10px;font-weight:900;padding:7px 10px;border-radius:10px}
.form-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;padding:15px;background:#f8fafc;border:1px solid var(--border);border-radius:14px;margin-bottom:15px}
.field{display:flex;flex-direction:column;gap:6px}.field.full{grid-column:1/-1}
.field label{font-size:10px;color:var(--muted);font-weight:800}.field input,.field select,.field textarea{width:100%;border:1px solid var(--border);border-radius:10px;background:#fff;padding:11px 12px;outline:none;color:var(--text)}
.field input:focus,.field select:focus,.field textarea:focus{border-color:#d5aa3f;box-shadow:0 0 0 3px rgba(215,166,42,.12)}.field textarea{min-height:76px;resize:vertical}
.form-actions{grid-column:1/-1;display:flex;gap:9px;flex-wrap:wrap}
.btn{border:0;border-radius:10px;padding:10px 14px;font-weight:900;font-size:11px;display:inline-flex;align-items:center;gap:7px;justify-content:center}
.btn-primary{background:var(--navy);color:#fff}.btn-gold{background:var(--gold);color:#152642}.btn-light{background:#eef1f5;color:#37465b}.btn-danger{background:var(--red-soft);color:var(--red)}
.actions{display:flex;gap:6px;align-items:center}.action-btn{width:31px;height:31px;border:1px solid var(--border);border-radius:8px;background:#fff;display:grid;place-items:center}.action-btn.edit{color:var(--blue)}.action-btn.delete{color:var(--red)}
.stock{display:inline-flex;min-width:30px;justify-content:center;border-radius:8px;padding:5px 7px;font-size:10px;font-weight:900}.stock.good{background:var(--green-soft);color:var(--green)}.stock.low{background:var(--gold-soft);color:#a06f00}.stock.zero{background:var(--red-soft);color:var(--red)}
.price{font-weight:900;color:#112a4a}.alert{border-radius:12px;padding:12px 14px;margin-bottom:15px;font-size:12px;font-weight:800}.alert.ok{background:var(--green-soft);color:var(--green)}.alert.error{background:var(--red-soft);color:var(--red)}
.inline-form{display:flex;gap:8px;align-items:center;flex-wrap:wrap}.inline-form input,.inline-form select{border:1px solid var(--border);border-radius:9px;padding:8px 10px}
.stats-row{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}.mini-stat{background:#f8fafc;border:1px solid var(--border);padding:15px;border-radius:13px}.mini-stat small{color:var(--muted);font-weight:800}.mini-stat strong{display:block;font-size:20px;margin-top:5px}
.toast{position:fixed;right:18px;top:84px;background:#10233e;color:#fff;padding:12px 15px;border-radius:12px;box-shadow:var(--shadow);z-index:100;display:none;font-size:12px}
.overlay{display:none}
.mobile-bottom{display:none}



.ops-strip{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin-bottom:16px}
.ops-card{background:#fff;border:1px solid var(--border);border-radius:15px;padding:14px 15px;display:grid;grid-template-columns:42px minmax(0,1fr) auto;align-items:center;gap:12px;box-shadow:var(--shadow);transition:.18s}
.ops-card:hover{transform:translateY(-2px);border-color:#d8c07a}
.ops-card small{font-size:9px;letter-spacing:.7px;color:var(--muted);font-weight:900}
.ops-card strong{display:block;font-size:18px;margin-top:2px;color:#10233e}
.ops-card p{margin:2px 0 0;font-size:10px;color:var(--muted)}
.ops-icon{width:38px;height:38px;border-radius:12px;display:grid;place-items:center;font-weight:900}
.ops-icon.warn{background:#fff1d4;color:#a56d00}.ops-icon.blue2{background:#e8f1ff;color:#2878e6}.ops-icon.green2{background:#ddf7eb;color:#16885b}
.section-intro{display:flex;justify-content:space-between;align-items:center;gap:14px;margin-bottom:14px;padding:16px 18px;background:radial-gradient(circle at 85% 20%,rgba(255,106,0,.25),transparent 32%),linear-gradient(135deg,#171b22,#2a3039);border-radius:16px;color:#fff}
.section-intro h2{margin:0 0 4px;font-size:18px}.section-intro p{margin:0;color:#d3d7dd;font-size:11px;line-height:1.45}
.section-intro .badge{background:rgba(255,255,255,.12);color:#f5d57c}
.two-col{display:grid;grid-template-columns:minmax(300px,.72fr) minmax(0,1.28fr);gap:14px}
.kpi-inline{display:flex;gap:8px;flex-wrap:wrap}.pill{padding:6px 9px;border-radius:999px;background:#f4f7fb;border:1px solid var(--border);font-size:10px;font-weight:800;color:var(--muted)}


.product-cell{display:flex;align-items:center;gap:10px;min-width:220px}.product-cell>div{min-width:0}.product-cell strong{display:block}.product-cell small,.table-sub{display:block;margin-top:3px;color:var(--muted);font-size:9px;max-width:280px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.product-thumb,.product-placeholder{width:42px;height:42px;border-radius:11px;flex:0 0 auto}.product-thumb{object-fit:cover;border:1px solid var(--border);background:#fff}.product-placeholder{display:grid;place-items:center;background:linear-gradient(135deg,#ff6a00,#c92b18);color:#fff;font-size:9px;font-weight:900}
.filter-toolbar{display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin:4px 0 12px;padding:11px 12px;border:1px solid var(--border);border-radius:13px;background:#fff}.filter-toolbar select{border:1px solid var(--border);border-radius:10px;background:#f8fafc;padding:9px 10px;font-size:10px;color:var(--text)}.filter-title{margin-right:auto;min-width:180px}.filter-title strong{display:block;font-size:12px}.filter-title small{display:block;margin-top:2px;font-size:9px;color:var(--muted)}
.action-bar{padding:12px;background:#f8fafc;border:1px solid var(--border);border-radius:13px;margin-bottom:14px}.action-bar input{min-width:260px;flex:1}
.btn-small{padding:7px 9px;font-size:9px}.order-actions{display:flex;align-items:center;gap:7px;flex-wrap:wrap}.link-action{color:#d54e1b;font-weight:900}.link-action:hover{text-decoration:underline}
.status-pill{display:inline-flex;align-items:center;justify-content:center;padding:5px 9px;border-radius:999px;background:#eef1f5;color:#556274;font-size:9px;font-weight:900;white-space:nowrap}.status-pill.success{background:#ddf7eb;color:#13875a}.status-pill.warning{background:#fff0d6;color:#a76f00}.status-pill.danger{background:#ffe8ea;color:#c92f3d}.status-pill.info{background:#e8f1ff;color:#286fc2}
.empty-cell{text-align:center!important;color:var(--muted);padding:22px!important}
.detail-card{margin:0 0 15px;padding:16px;border:1px solid #ffd4bd;background:linear-gradient(135deg,#fff9f5,#fff);border-radius:15px}.detail-head{display:flex;align-items:flex-start;justify-content:space-between;gap:14px;margin-bottom:14px}.detail-head small{font-size:9px;letter-spacing:.8px;color:#d3541d;font-weight:900}.detail-head h3{margin:3px 0 4px;font-size:20px}.detail-head p{margin:0;color:var(--muted);font-size:10px}.detail-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:9px;margin-bottom:14px}.detail-grid>div{padding:11px;border-radius:11px;background:#fff;border:1px solid var(--border)}.detail-grid small{display:block;font-size:8px;color:var(--muted);font-weight:900;letter-spacing:.6px}.detail-grid strong{display:block;margin-top:4px;font-size:12px}.mini-table{border:1px solid var(--border);border-radius:12px}
.order-progress{display:flex;align-items:flex-start;gap:4px;margin:8px 0 16px;overflow:auto}.progress-step{position:relative;flex:1;min-width:90px;text-align:center;color:#a0a7b1}.progress-step:before{content:"";position:absolute;top:13px;left:-50%;right:50%;height:2px;background:#e5e8ec}.progress-step:first-child:before{display:none}.progress-step span{position:relative;z-index:1;margin:auto;width:28px;height:28px;border-radius:50%;display:grid;place-items:center;background:#eef1f4;color:#7c8490;font-size:9px;font-weight:900}.progress-step small{display:block;margin-top:6px;font-size:8px;font-weight:800}.progress-step.done{color:#d54f1b}.progress-step.done:before{background:#ff7a2e}.progress-step.done span{background:linear-gradient(135deg,#ff6a00,#c92b18);color:#fff}
.info-panel{padding:22px;border-radius:16px;background:linear-gradient(145deg,#171b22,#2a3039);color:#fff;align-self:start}.info-icon{width:48px;height:48px;border-radius:14px;background:rgba(255,106,0,.15);color:#ff8135;display:grid;place-items:center;font-size:22px;font-weight:900}.info-panel h3{margin:14px 0 7px}.info-panel p{margin:0;color:#cfd4db;font-size:11px;line-height:1.55}
.inventory-summary{display:grid;gap:6px;margin-top:10px}.inventory-summary>div{display:grid;grid-template-columns:12px minmax(0,1fr) auto;gap:8px;align-items:center;padding:9px;border-radius:10px;background:#fff;border:1px solid var(--border)}.inventory-summary strong{font-size:10px}.inventory-summary small{font-size:9px;color:var(--muted)}.stock-dot{width:9px;height:9px;border-radius:50%}.stock-dot.warning{background:#e0a126}.stock-dot.danger{background:#d43c32}.danger-soft{background:#fff0ed!important;color:#b23f23!important;border-color:#ffd2c7!important}
.report-filter{display:flex;align-items:end;gap:10px;flex-wrap:wrap;padding:12px;border:1px solid var(--border);border-radius:13px;background:#f8fafc;margin-bottom:14px}.report-filter .field{min-width:170px}.report-stats{grid-template-columns:repeat(3,1fr);margin-bottom:14px}.report-actions-card{padding:20px;border-radius:16px;background:linear-gradient(145deg,#171b22,#2b3039);color:#fff;display:flex;flex-direction:column;align-items:flex-start;gap:9px}.report-actions-card h3{margin:0}.report-actions-card p{margin:0 0 4px;color:#cdd2d9;font-size:11px;line-height:1.5}.report-actions-card .btn{width:100%}.report-icon{width:44px;height:44px;border-radius:13px;background:rgba(255,106,0,.15);color:#ff8135;display:grid;place-items:center;font-size:20px}
.config-grid{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-top:14px}.config-card{padding:16px;border:1px solid var(--border);border-radius:15px;background:#fff}.config-card .form-grid{margin-bottom:0}.backup-card{margin-top:14px}
.pagination{display:flex;align-items:center;justify-content:flex-end;gap:6px;padding-top:10px}.pagination button{width:32px;height:30px;border:1px solid var(--border);background:#fff;border-radius:8px;font-size:9px;font-weight:900}.pagination button.active{background:#171b22;color:#fff;border-color:#171b22}.pagination span{font-size:9px;color:var(--muted);margin-right:auto}


.page-panel{display:none;animation:panelIn .34s cubic-bezier(.2,.75,.2,1)}
.page-panel.active{display:block}
@keyframes panelIn{
 from{opacity:0;transform:translateY(12px) scale(.994)}
 to{opacity:1;transform:translateY(0) scale(1)}
}
@keyframes heroGlow{
 0%,100%{background-position:0% 50%}
 50%{background-position:100% 50%}
}
@keyframes livePulse{
 0%,100%{opacity:.72;transform:scale(.98)}
 50%{opacity:1;transform:scale(1.02)}
}
.brand-hero{
 background-size:180% 180%;
 animation:heroGlow 11s ease-in-out infinite;
}
.hero-brand img{
 transition:transform .45s cubic-bezier(.2,.75,.2,1),filter .45s ease;
}
.brand-hero:hover .hero-brand img{
 transform:rotate(-2deg) scale(1.035);
 filter:drop-shadow(0 14px 24px rgba(255,106,0,.18));
}
#liveStatus{animation:livePulse 2.2s ease-in-out infinite}
.card,.metric,.ops-card,.quick,.detail-card,.action-bar,.filter-toolbar,.report-filter{
 transition:transform .22s cubic-bezier(.2,.75,.2,1),box-shadow .22s ease,border-color .22s ease;
}
.card:hover{
 border-color:#dfe4ea;
 box-shadow:0 14px 34px rgba(15,39,70,.09);
}
.metric:hover,.ops-card:hover,.quick:hover{
 transform:translateY(-4px);
 box-shadow:0 16px 34px rgba(15,39,70,.12);
 border-color:#f2c1a8;
}
.btn,.action-btn,.icon-btn,.nav-main,.nav-submenu a,.mobile-bottom a{
 transition:transform .14s ease,box-shadow .18s ease,background .18s ease,color .18s ease,border-color .18s ease;
}
.btn:hover,.action-btn:hover,.icon-btn:hover{
 transform:translateY(-1px);
}
.btn:active,.action-btn:active,.icon-btn:active{
 transform:translateY(1px) scale(.985);
}
.btn-primary:hover{
 box-shadow:0 9px 20px rgba(201,43,24,.20);
}
.nav-main:hover,.nav-submenu a:hover{
 transform:translateX(3px);
}
.table-wrap tbody tr{
 transition:background .16s ease,transform .16s ease;
}
.table-wrap tbody tr:hover{
 background:#fff9f5;
}
.product-thumb{
 transition:transform .22s ease,box-shadow .22s ease;
}
.table-wrap tbody tr:hover .product-thumb{
 transform:scale(1.055);
 box-shadow:0 7px 16px rgba(15,39,70,.10);
}
input,select,textarea{
 transition:border-color .16s ease,box-shadow .16s ease,background .16s ease;
}
input:focus,select:focus,textarea:focus{
 box-shadow:0 0 0 3px rgba(255,106,0,.10);
}
@media (prefers-reduced-motion:reduce){
 *,*::before,*::after{animation-duration:.001ms!important;animation-iteration-count:1!important;transition-duration:.001ms!important;scroll-behavior:auto!important}
}
.page-panel.card{margin-bottom:0}
.nav a.active{box-shadow:0 6px 16px rgba(215,166,42,.16)}
.metric{transition:.18s}.metric:hover{transform:translateY(-2px);box-shadow:0 12px 28px rgba(15,39,70,.10)}
.quick span{line-height:1.2}
.section-title{position:sticky;top:70px;background:#fff;z-index:8;padding:4px 0 10px}

@media(max-width:1180px){.metrics{grid-template-columns:repeat(3,1fr)}.grid-main,.grid-bottom,.two-col{grid-template-columns:1fr}.ops-strip{grid-template-columns:1fr 1fr}.quick-actions{grid-template-columns:repeat(3,1fr)}.home-tools{grid-template-columns:1fr 1fr}.system-grid{grid-template-columns:1fr 1fr}}
@media(max-width:900px){.home-tools{grid-template-columns:1fr}.quick-actions{grid-template-columns:repeat(3,1fr)}.config-grid{grid-template-columns:1fr}.detail-grid{grid-template-columns:1fr 1fr}.report-stats{grid-template-columns:1fr 1fr}}
@media(max-width:820px){
 body{padding-bottom:74px}.app{grid-template-columns:1fr}.sidebar{position:fixed;left:-260px;width:235px;transition:.25s}.sidebar.open{left:0}.overlay.show{display:block;position:fixed;inset:0;background:rgba(0,0,0,.35);z-index:45}
 .topbar{height:64px;padding:0 14px}.mobile-menu{display:grid;place-items:center}.mobile-brand-logo{display:block}.top-title{display:none}.search{display:none}.admin div:last-child{display:none}.content{padding:15px}.heading{align-items:flex-start}.heading h1{font-size:22px}.date-chip{display:none}
 .brand-hero{grid-template-columns:1fr;padding:18px}.hero-brand{position:absolute;opacity:.13;right:24px}.hero-brand img{width:100px;height:100px}.metrics{grid-template-columns:repeat(2,1fr);gap:10px}.metric{padding:13px;gap:9px}.metric-icon{width:42px;height:42px}.metric-value{font-size:19px}.grid-main,.grid-bottom{gap:12px}.chart{height:180px;gap:6px}
 .card{padding:14px}.form-grid{grid-template-columns:1fr}.field.full,.form-actions{grid-column:auto}.logout-btn{display:none}.filter-toolbar{align-items:stretch}.filter-toolbar select{flex:1}.detail-head{flex-direction:column}.order-actions{align-items:stretch}.order-actions .inline-form{width:100%}
 .mobile-bottom{display:grid;grid-template-columns:repeat(4,1fr);position:fixed;left:0;right:0;bottom:0;height:68px;background:#fff;border-top:1px solid var(--border);z-index:40;box-shadow:0 -8px 22px rgba(15,39,70,.08)}
 .mobile-bottom a{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;color:var(--muted);font-size:9px;font-weight:800}.mobile-bottom a.active{color:#a7780a}
}
@media(max-width:480px){.ops-strip{grid-template-columns:1fr}.quick-actions{grid-template-columns:1fr 1fr}.system-grid,.detail-grid,.report-stats{grid-template-columns:1fr}.metrics{grid-template-columns:1fr 1fr}.metric-icon{width:38px;height:38px}.metric-value{font-size:17px}.metric-label{font-size:10px}.quick-actions{grid-template-columns:repeat(2,1fr)}.stats-row{grid-template-columns:1fr}}
@media print{.sidebar,.topbar,.mobile-bottom,.btn,.section-actions{display:none!important}.app{display:block}.content{padding:0;max-width:none}.page-panel{display:none!important}#reportes{display:block!important;box-shadow:none;border:0}.card{box-shadow:none}.stats-row{grid-template-columns:repeat(3,1fr)}}
</style>
</head>
<body>

<div class="toast" id="toast">Panel actualizado correctamente.</div>
<div class="overlay" id="overlay"></div>

<div class="app">
<aside class="sidebar" id="sidebar">
 <div class="brand">
  <img src="logo_adn_imports.png" alt="ADN Import's" class="brand-logo">
  <div><div class="brand-title">ADN <b>IMPORT'S</b></div><div class="brand-sub">Dorada Motors · Administración</div></div>
 </div>
 <nav class="nav nav-simple" id="nav">
  <a href="#inicio" class="nav-main active"><span class="nav-icon">⌂</span><span>Dashboard</span></a>

  <?php if(puede("pedidos") || puede("pagos") || puede("comprobantes")): ?>
  <div class="nav-folder" data-nav-folder="ventas">
   <button type="button" class="nav-main nav-toggle" data-nav-toggle="ventas">
    <span class="nav-icon">🛒</span><span>Ventas</span><b class="nav-chevron">›</b>
   </button>
   <div class="nav-submenu">
    <?php if(puede("pedidos")): ?><a href="#pedidos">Pedidos</a><?php endif; ?>
    <?php if(puede("pagos")): ?><a href="#pagos">Pagos</a><?php endif; ?>
    <?php if(puede("comprobantes")): ?><a href="#comprobantes">Comprobantes</a><?php endif; ?>
   </div>
  </div>
  <?php endif; ?>

  <?php if(puede("gestion-productos") || puede("categorias") || puede("marcas")): ?>
  <div class="nav-folder" data-nav-folder="catalogo">
   <button type="button" class="nav-main nav-toggle" data-nav-toggle="catalogo">
    <span class="nav-icon">◇</span><span>Catálogo</span><b class="nav-chevron">›</b>
   </button>
   <div class="nav-submenu">
    <?php if(puede("gestion-productos")): ?><a href="#gestion-productos">Productos</a><?php endif; ?>
    <?php if(puede("categorias")): ?><a href="#categorias">Categorías</a><?php endif; ?>
    <?php if(puede("marcas")): ?><a href="#marcas">Marcas</a><?php endif; ?>
   </div>
  </div>
  <?php endif; ?>

  <?php if(puede("inventario") || puede("compras") || puede("proveedores")): ?>
  <div class="nav-folder" data-nav-folder="inventario">
   <button type="button" class="nav-main nav-toggle" data-nav-toggle="inventario">
    <span class="nav-icon">▤</span><span>Inventario</span><b class="nav-chevron">›</b>
   </button>
   <div class="nav-submenu">
    <?php if(puede("inventario")): ?><a href="#inventario">Stock / Kardex</a><?php endif; ?>
    <?php if(puede("compras")): ?><a href="#compras">Compras</a><?php endif; ?>
    <?php if(puede("proveedores")): ?><a href="#proveedores">Proveedores</a><?php endif; ?>
   </div>
  </div>
  <?php endif; ?>

  <?php if(puede("clientes")): ?>
  <div class="nav-folder" data-nav-folder="clientes">
   <button type="button" class="nav-main nav-toggle" data-nav-toggle="clientes">
    <span class="nav-icon">👤</span><span>Clientes</span><b class="nav-chevron">›</b>
   </button>
   <div class="nav-submenu">
     <a href="#clientes">Clientes e historial</a>
     <a href="#direcciones">Direcciones</a>
   </div>
  </div>
  <?php endif; ?>

  <?php if(puede("soporte")): ?>
  <a href="#soporte" class="nav-main"><span class="nav-icon">✉</span><span>Atención al cliente</span></a>
  <?php endif; ?>

  <?php if(puede("reportes")): ?>
  <a href="#reportes" class="nav-main"><span class="nav-icon">▥</span><span>Reportes</span></a>
  <?php endif; ?>

 </nav>
 <div class="motto">“Potencia, Calidad y Confianza en Cada Repuesto”</div>
 <div class="sidebar-bottom"><strong>ADN Import's</strong>Dorada Motors · Panel v4.0<br>PHP · MySQL · Flutter · UI dinámica</div>
</aside>

<main class="main">
<header class="topbar">
 <button class="mobile-menu" id="menuBtn" aria-label="Abrir menú">☰</button>
 <img src="logo_adn_imports.png" alt="ADN" class="mobile-brand-logo">
 <div class="top-title" id="topTitle">Dashboard</div>
 <div class="search"><span>⌕</span><input id="buscador" type="search" placeholder="Buscar en la sección actual..."><kbd>Ctrl K</kbd></div>
 <div class="top-actions">
  <div class="notify-wrap">
   <button class="icon-btn" id="notiBtn" title="Notificaciones">🔔<span class="notification-count" id="notificationCount" <?= ($stockBajo+$pedidosPendientes+$totalSoportePendiente)>0 ? "" : "hidden" ?>><?= $stockBajo+$pedidosPendientes+$totalSoportePendiente ?></span></button>
   <div class="notify-menu" id="notifyMenu">
    <div class="notify-head"><strong>Notificaciones</strong><span>En tiempo real</span></div>
    <?php if(puede("inventario")): ?><a href="#inventario"><b>⚠ Stock bajo</b><small id="notifStock"><?= $stockBajo ?> producto(s) requieren atención</small></a><?php endif; ?>
    <?php if(puede("pedidos")): ?><a href="#pedidos"><b>🛒 Pedidos por atender</b><small id="notifPedidos"><?= $pedidosPendientes ?> pendiente(s) o en proceso</small></a><?php endif; ?>
    <?php if(puede("soporte")): ?><a href="#soporte"><b>✉ Soporte por atender</b><small id="notifSoporte"><?= $totalSoportePendiente ?> consulta(s) abiertas</small></a><?php endif; ?>
    <?php if(puede("reportes")): ?><a href="#reportes"><b>💰 Ventas de hoy</b><small id="notifVentasHoy">S/ <?= number_format($ventasHoy,2) ?></small></a><?php endif; ?>
   </div>
  </div>
  <a class="admin" href="<?= puede("configuracion") ? "#configuracion" : "#inicio" ?>" title="Cuenta administrativa"><div class="avatar"><?= h($inicialesAdmin) ?></div><div><strong><?= h($adminNombre) ?></strong><small><?= h($adminRol) ?></small></div></a>
  <a class="icon-btn" href="admin_logout.php" title="Cerrar sesión">↪</a>

 </div>
</header>

<div class="content">
<?php if ($mensaje !== ""): ?><div class="alert <?= $tipoMensaje === "error" ? "error" : "ok" ?>"><?= h($mensaje) ?></div><?php endif; ?>

<div id="inicio" class="page-panel active">
<section class="brand-hero">
 <div class="hero-copy">
  <div class="eyebrow">Panel de administración</div>
  <h1>¡Bienvenido, <?= h(explode(" ", $adminNombre)[0] ?: "Administrador") ?>!</h1>
  <p>Gestiona clientes, ventas, catálogo, inventario, compras y reportes desde un solo lugar.</p>
  <div class="hero-tags">
   <span>● PHP conectado</span><span>● MySQL activo</span><span>● API lista para Flutter</span><span id="liveStatus">● Datos en vivo</span><button type="button" class="live-refresh-btn" id="liveRefreshBtn" title="Actualizar dashboard ahora">↻ Actualizar</button>
  </div>
 </div>
 <div class="hero-brand">
  <img src="logo_adn_imports.png" alt="Logo ADN Import's">
  <small><?= h($fechaHoy) ?></small>
 </div>
</section>

<section class="metrics">
 <?php if(puede("gestion-productos")): ?><a class="metric" href="#gestion-productos"><div class="metric-icon blue">📦</div><div><div class="metric-label">Productos</div><div class="metric-value" id="metricProductos"><?= $totalProductos ?></div><small>Catálogo activo</small></div></a><?php endif; ?>
 <?php if(puede("clientes")): ?><a class="metric" href="#clientes"><div class="metric-icon gold">👥</div><div><div class="metric-label">Clientes</div><div class="metric-value" id="metricClientes"><?= $totalUsuarios ?></div><small>Cuentas registradas</small></div></a><?php endif; ?>
 <?php if(puede("pedidos")): ?><a class="metric" href="#pedidos"><div class="metric-icon purple">🛒</div><div><div class="metric-label">Pedidos</div><div class="metric-value" id="metricPedidos"><?= $totalPedidos ?></div><small id="metricPedidosSub"><?= $pedidosPendientes ?> por atender</small></div></a><?php endif; ?>
 <?php if(puede("reportes")): ?><a class="metric" href="#reportes"><div class="metric-icon green">S/</div><div><div class="metric-label">Ventas</div><div class="metric-value" id="metricVentas">S/ <?= number_format($totalVentas,2) ?></div><small id="metricVentasSub">Mes: S/ <?= number_format($ventasMes,2) ?> · Hoy: S/ <?= number_format($ventasHoy,2) ?></small></div></a><?php endif; ?>
 <?php if(puede("inventario")): ?><a class="metric" href="#inventario"><div class="metric-icon red">!</div><div><div class="metric-label">Stock bajo</div><div class="metric-value" id="metricStockBajo"><?= $stockBajo ?></div><small id="metricStockSub"><?= $stockCritico ?> crítico(s)</small></div></a><?php endif; ?>
 <?php if(puede("reportes")): ?><a class="metric" href="#reportes"><div class="metric-icon orange">↗</div><div><div class="metric-label">Margen estimado</div><div class="metric-value">S/ <?= number_format($gananciaEstimada,2) ?></div><small>Según costos registrados</small></div></a><?php endif; ?>
</section>

<section class="ops-strip">
 <?php if(puede("inventario")): ?><a href="#inventario" class="ops-card"><span class="ops-icon warn">!</span><div><small>STOCK BAJO</small><strong id="opsStockValue"><?= $stockBajo ?></strong><p>Productos bajo su stock mínimo</p></div><b>→</b></a><?php endif; ?>
 <?php if(puede("proveedores")): ?><a href="#proveedores" class="ops-card"><span class="ops-icon blue2">P</span><div><small>PROVEEDORES</small><strong id="opsProveedoresValue"><?= $totalProveedores ?></strong><p>Proveedores registrados</p></div><b>→</b></a><?php endif; ?>
 <?php if(puede("compras")): ?><a href="#compras" class="ops-card"><span class="ops-icon green2">S/</span><div><small>COMPRAS</small><strong id="opsComprasValue">S/ <?= number_format($totalCompras,2) ?></strong><p>Total de abastecimiento</p></div><b>→</b></a><?php endif; ?>
</section>

<section class="grid-main">
 <article class="card">
  <div class="card-head"><h2>Ventas de los últimos 7 días</h2><span class="badge">Últimos 7 días</span></div>
  <div class="chart" id="chartVentas7">
   <?php foreach($ventas7 as $dato): $altura=$dato["total"]>0?max(8,($dato["total"]/$maxVenta)*88):4; ?>
   <div class="chart-item"><div class="bar" style="height:<?= number_format($altura,1,'.','') ?>%"><div class="bar-tip">S/ <?= number_format($dato["total"],2) ?></div></div><div class="day"><?= h($dato["dia"]) ?></div></div>
   <?php endforeach; ?>
  </div>
 </article>
 <article class="card">
  <div class="card-head"><h2>Tendencia de pedidos</h2><span class="badge" id="pedidosPendientesBadge"><?= $pedidosPendientes ?> por atender</span></div>
  <div class="chart line-bars" id="chartPedidos7">
   <?php foreach($pedidos7 as $dato): $altura=$dato["total"]>0?max(8,($dato["total"]/$maxPedidos)*88):4; ?>
   <div class="chart-item"><div class="bar order-bar" style="height:<?= number_format($altura,1,'.','') ?>%"><div class="bar-tip"><?= (int)$dato["total"] ?> pedido(s)</div></div><div class="day"><?= h($dato["dia"]) ?></div></div>
   <?php endforeach; ?>
  </div>
 </article>
</section>

<section class="grid-bottom">
 <article class="card">
  <div class="card-head"><h2>Pedidos recientes</h2><a href="#pedidos">Ver todos →</a></div>
  <div class="table-wrap"><table><thead><tr><th>#</th><th>Cliente</th><th>Fecha</th><th>Estado</th><th>Total</th></tr></thead><tbody id="tablaPedidosRecientesBody">
   <?php if(!$pedidos): ?><tr><td colspan="5" style="text-align:center;color:#718096">Todavía no hay pedidos.</td></tr><?php else: foreach(array_slice($pedidos,0,5) as $p): ?>
   <tr><td>#<?= h($p["id_pedido"]) ?></td><td><?= h($p["nombres"]." ".$p["apellidos"]) ?></td><td><?= h(date("d/m/Y",strtotime($p["fecha_pedido"]))) ?></td><td><?= h($p["estado_pedido"]) ?></td><td class="price">S/ <?= number_format((float)$p["total"],2) ?></td></tr>
   <?php endforeach; endif; ?>
  </tbody></table></div>
 </article>
 <article class="card">
  <div class="card-head"><h2>Productos más vendidos</h2><a href="#gestion-productos">Ver productos →</a></div>
  <div class="top-list" id="listaTopProductos">
   <?php if(!$masVendidos): ?><p style="font-size:12px;color:#718096">No hay datos.</p><?php else: foreach($masVendidos as $i=>$prod): ?>
   <div class="top-product"><div class="rank"><?= $i+1 ?></div><strong><?= h($prod["nombre_producto"]) ?></strong><span><?= (int)$prod["vendidos"] ?> vendidos</span></div>
   <?php endforeach; endif; ?>
  </div>
 </article>
</section>

<section class="home-tools">
 <article class="card">
  <div class="card-head"><h2>Acciones rápidas</h2><span class="badge">1 clic</span></div>
  <div class="quick-actions quick-actions-clean">
   <?php if(puede("gestion-productos")): ?><a class="quick blue" href="#gestion-productos">📦<span>Nuevo producto</span></a><?php endif; ?>
   <?php if(puede("pedidos")): ?><a class="quick purple" href="#pedidos">🛒<span>Gestionar pedidos</span></a><?php endif; ?>
   <?php if(puede("compras")): ?><a class="quick gold" href="#compras">＋<span>Registrar compra</span></a><?php endif; ?>
   <?php if(puede("inventario")): ?><a class="quick green" href="#inventario">↕<span>Ajustar stock</span></a><?php endif; ?>
  </div>
 </article>

 <article class="card">
  <div class="card-head"><h2>Stock bajo / alertas</h2><a href="#inventario">Ver inventario →</a></div>
  <div class="compact-list" id="listaStockAlertas">
   <?php if(!$productosStockBajo): ?><div class="empty-state">✓ Todo el inventario está en buen nivel.</div><?php else: foreach(array_slice($productosStockBajo,0,5) as $sb): ?>
    <a href="#inventario" class="compact-row"><span class="product-dot"></span><div><strong><?= h($sb["nombre_producto"]) ?></strong><small>Stock actual</small></div><b class="<?= (int)$sb["stock"]<=2?"critical-text":"warning-text" ?>"><?= (int)$sb["stock"] ?></b></a>
   <?php endforeach; endif; ?>
  </div>
 </article>

 <article class="card">
  <div class="card-head"><h2>Últimos pagos</h2><a href="#pagos">Ver todos →</a></div>
  <div class="compact-list" id="listaPagosRecientes">
   <?php if(!$pagos): ?><div class="empty-state">Aún no hay pagos registrados.</div><?php else: foreach(array_slice($pagos,0,5) as $pg): ?>
    <a href="#pagos" class="compact-row"><span class="payment-dot">S/</span><div><strong><?= h($pg["nombres"]." ".$pg["apellidos"]) ?></strong><small><?= h($pg["metodo_pago"]) ?> · <?= h($pg["estado_pago"]) ?></small></div><b>S/ <?= number_format((float)$pg["monto"],2) ?></b></a>
   <?php endforeach; endif; ?>
  </div>
 </article>
</section>
</div>

<?php if(puede("gestion-productos")): ?>
<section id="gestion-productos" class="card page-panel">
 <div class="section-intro">
  <div><h2><?= $productoEditar ? "Editar producto" : "Productos" ?></h2><p>Administra catálogo, precios, imágenes y niveles mínimos de inventario.</p></div>
  <div class="section-actions"><button type="button" class="btn btn-light" onclick="exportarTabla('tablaProductos','productos_adn.csv')">Exportar CSV</button><span class="badge"><?= $totalProductos ?> productos</span></div>
 </div>

 <form method="POST" enctype="multipart/form-data" class="form-grid product-form">
  <?php if($productoEditar): ?>
   <input type="hidden" name="id_producto" value="<?= h($productoEditar["id_producto"]) ?>">
   <input type="hidden" name="imagen_actual" value="<?= h($productoEditar["imagen_url"]??"") ?>">
  <?php endif; ?>

  <div class="field"><label>NOMBRE DEL PRODUCTO</label><input type="text" name="nombre_producto" required value="<?= h($productoEditar["nombre_producto"]??"") ?>" placeholder="Ej. Kit de transmisión DTIEX"></div>
  <div class="field"><label>CATEGORÍA</label><select name="id_categoria" required><option value="">Seleccione</option><?php foreach($categorias as $cat): ?><option value="<?= h($cat["id_categoria"]) ?>" <?= $productoEditar && (int)$productoEditar["id_categoria"]===(int)$cat["id_categoria"]?"selected":"" ?>><?= h($cat["nombre_categoria"]) ?></option><?php endforeach; ?></select></div>
  <div class="field"><label>MARCA</label><select name="id_marca" required><option value="">Seleccione</option><?php foreach($marcas as $mar): ?><option value="<?= h($mar["id_marca"]) ?>" <?= $productoEditar && (int)$productoEditar["id_marca"]===(int)$mar["id_marca"]?"selected":"" ?>><?= h($mar["nombre_marca"]) ?></option><?php endforeach; ?></select></div>
  <div class="field"><label>TIPO DE VEHÍCULO</label><select name="tipo_vehiculo"><option value="Motocicleta / Motokar" <?= ($productoEditar["tipo_vehiculo"]??"Motocicleta / Motokar")==="Motocicleta / Motokar"?"selected":"" ?>>Motocicleta / Motokar</option><option value="Motocicleta" <?= ($productoEditar["tipo_vehiculo"]??"")==="Motocicleta"?"selected":"" ?>>Motocicleta</option><option value="Motokar" <?= ($productoEditar["tipo_vehiculo"]??"")==="Motokar"?"selected":"" ?>>Motokar</option></select></div>
<div class="field"><label>COMPATIBILIDAD</label><input type="text" name="compatibilidad" value="<?= h($productoEditar["compatibilidad"]??"") ?>" placeholder="Ej. Honda, Wanxin, Zongshen"></div>
<div class="field"><label>PRECIO DE VENTA</label><input type="number" step="0.01" min="0" name="precio" required value="<?= h($productoEditar["precio"]??"") ?>" placeholder="0.00"></div>
<div class="field"><label>PRECIO OFERTA</label><input type="number" step="0.01" min="0" name="precio_oferta" value="<?= h($productoEditar["precio_oferta"]??"") ?>" placeholder="Opcional"></div>
  <div class="field"><label>STOCK ACTUAL</label><input type="number" min="0" name="stock" required value="<?= h($productoEditar["stock"]??"") ?>" placeholder="0"></div>
  <div class="field"><label>STOCK MÍNIMO</label><input type="number" min="0" name="stock_minimo" required value="<?= h($productoEditar["stock_minimo"]??5) ?>" placeholder="5"></div>
  <div class="field"><label>SUBIR IMAGEN</label><input type="file" name="imagen_archivo" accept=".jpg,.jpeg,.png,.webp,image/jpeg,image/png,image/webp"></div>
  <div class="field"><label>RUTA / URL DE IMAGEN</label><input type="text" name="imagen_url" value="<?= h($productoEditar["imagen_url"]??"") ?>" placeholder="Opcional: uploads/productos/..."></div>
  <div class="field full"><label>DESCRIPCIÓN</label><textarea name="descripcion" placeholder="Describe compatibilidad, modelo, medida o características."><?= h($productoEditar["descripcion"]??"") ?></textarea></div>

  <div class="form-actions">
   <?php if($productoEditar): ?>
    <button class="btn btn-gold" name="actualizar_producto">Guardar cambios</button>
    <a class="btn btn-light" href="dashboard.php#gestion-productos">Cancelar</a>
   <?php else: ?>
    <button class="btn btn-primary" name="registrar_producto">+ Agregar producto</button>
   <?php endif; ?>
  </div>
 </form>

 <div class="filter-toolbar">
  <div class="filter-title"><strong>Catálogo</strong><small>Filtra sin perderte entre los registros.</small></div>
  <select id="filtroCategoriaProducto"><option value="">Todas las categorías</option><?php foreach($categorias as $cat): ?><option value="<?= h(strtolower($cat["nombre_categoria"])) ?>"><?= h($cat["nombre_categoria"]) ?></option><?php endforeach; ?></select>
  <select id="filtroStockProducto"><option value="">Todo el stock</option><option value="good">Disponible</option><option value="low">Stock bajo</option><option value="zero">Agotado</option></select>
 </div>

 <div class="table-wrap"><table id="tablaProductos"><thead><tr><th>Producto</th><th>Categoría</th><th>Marca</th><th>Precio</th><th>Stock</th><th>Mínimo</th><th>Acciones</th></tr></thead><tbody>
 <?php foreach($productos as $p): $s=(int)$p["stock"];$min=(int)($p["stock_minimo"]??5);$sc=$s<=0?"zero":($s<=$min?"low":"good"); ?>
  <tr data-category="<?= h(strtolower($p["nombre_categoria"])) ?>" data-stock="<?= h($sc) ?>">
   <td>
    <div class="product-cell">
     <?php if(trim((string)($p["imagen_url"]??""))!==""): ?><img src="<?= h($p["imagen_url"]) ?>" alt="" class="product-thumb" onerror="this.style.display='none'"><?php else: ?><span class="product-placeholder">DM</span><?php endif; ?>
     <div><strong><?= h($p["nombre_producto"]) ?></strong><small>#P<?= str_pad((string)$p["id_producto"],3,"0",STR_PAD_LEFT) ?> · <?= h($p["descripcion"]) ?></small></div>
    </div>
   </td>
   <td><?= h($p["nombre_categoria"]) ?></td><td><?= h($p["nombre_marca"]) ?></td><td class="price"><?php if(!empty($p["precio_oferta"])): ?><small class="table-sub" style="text-decoration:line-through">S/ <?= number_format((float)$p["precio"],2) ?></small>S/ <?= number_format((float)$p["precio_oferta"],2) ?><?php else: ?>S/ <?= number_format((float)$p["precio"],2) ?><?php endif; ?></td>
   <td><span class="stock <?= $sc ?>"><?= $s ?></span></td><td><?= $min ?></td>
   <td><div class="actions"><a class="action-btn edit" title="Editar" href="dashboard.php?editar=<?= h($p["id_producto"]) ?>#gestion-productos">✎</a><form method="POST" onsubmit="return confirm('¿Eliminar este producto?');"><input type="hidden" name="id_producto" value="<?= h($p["id_producto"]) ?>"><button class="action-btn delete" title="Eliminar" name="eliminar_producto">⌫</button></form></div></td>
  </tr>
 <?php endforeach; ?>
 </tbody></table></div>
</section>
<?php endif; ?>

<?php if(puede("categorias")): ?>
<section id="categorias" class="card page-panel">
 <div class="section-intro"><div><h2>Categorías</h2><p>Organiza el catálogo para que productos y búsquedas sean fáciles de entender.</p></div><span class="badge"><?= $totalCategorias ?> registradas</span></div>
 <form method="POST" class="inline-form action-bar">
  <?php if($categoriaEditar): ?><input type="hidden" name="id_categoria" value="<?= h($categoriaEditar["id_categoria"]) ?>"><?php endif; ?>
  <input type="text" name="nombre_categoria" value="<?= h($categoriaEditar["nombre_categoria"]??"") ?>" placeholder="Nombre de la categoría" required>
  <button class="btn btn-primary" name="<?= $categoriaEditar ? "actualizar_categoria" : "registrar_categoria" ?>"><?= $categoriaEditar ? "Guardar cambios" : "+ Agregar categoría" ?></button>
  <?php if($categoriaEditar): ?><a class="btn btn-light" href="dashboard.php#categorias">Cancelar</a><?php endif; ?>
 </form>
 <div class="table-wrap"><table><thead><tr><th>ID</th><th>Categoría</th><th>Acción</th></tr></thead><tbody>
 <?php foreach($categorias as $cat): ?><tr><td>#<?= h($cat["id_categoria"]) ?></td><td><strong><?= h($cat["nombre_categoria"]) ?></strong></td><td><div class="actions"><a class="btn btn-light btn-small" href="dashboard.php?editar_categoria=<?= h($cat["id_categoria"]) ?>#categorias">Editar</a><form method="POST" onsubmit="return confirm('¿Eliminar categoría?');"><input type="hidden" name="id_categoria" value="<?= h($cat["id_categoria"]) ?>"><button class="btn btn-danger btn-small" name="eliminar_categoria">Eliminar</button></form></div></td></tr><?php endforeach; ?>
 </tbody></table></div>
</section>
<?php endif; ?>

<?php if(puede("marcas")): ?>
<section id="marcas" class="card page-panel">
 <div class="section-intro"><div><h2>Marcas</h2><p>Controla las marcas disponibles en el catálogo de repuestos.</p></div><span class="badge"><?= $totalMarcas ?> registradas</span></div>
 <form method="POST" class="inline-form action-bar">
  <?php if($marcaEditar): ?><input type="hidden" name="id_marca" value="<?= h($marcaEditar["id_marca"]) ?>"><?php endif; ?>
  <input type="text" name="nombre_marca" value="<?= h($marcaEditar["nombre_marca"]??"") ?>" placeholder="Nombre de la marca" required>
  <button class="btn btn-primary" name="<?= $marcaEditar ? "actualizar_marca" : "registrar_marca" ?>"><?= $marcaEditar ? "Guardar cambios" : "+ Agregar marca" ?></button>
  <?php if($marcaEditar): ?><a class="btn btn-light" href="dashboard.php#marcas">Cancelar</a><?php endif; ?>
 </form>
 <div class="table-wrap"><table><thead><tr><th>ID</th><th>Marca</th><th>Acción</th></tr></thead><tbody>
 <?php foreach($marcas as $mar): ?><tr><td>#<?= h($mar["id_marca"]) ?></td><td><strong><?= h($mar["nombre_marca"]) ?></strong></td><td><div class="actions"><a class="btn btn-light btn-small" href="dashboard.php?editar_marca=<?= h($mar["id_marca"]) ?>#marcas">Editar</a><form method="POST" onsubmit="return confirm('¿Eliminar marca?');"><input type="hidden" name="id_marca" value="<?= h($mar["id_marca"]) ?>"><button class="btn btn-danger btn-small" name="eliminar_marca">Eliminar</button></form></div></td></tr><?php endforeach; ?>
 </tbody></table></div>
</section>
<?php endif; ?>

<?php if(puede("clientes")): ?>
<section id="clientes" class="card page-panel">
 <div class="section-intro"><div><h2>Clientes</h2><p>Administra las cuentas que ingresan desde Flutter y consulta su historial de compras.</p></div><span class="badge"><?= count($clientes) ?> clientes</span></div>

 <details class="detail-card" style="margin-bottom:16px" <?= $clienteEditar ? "open" : "" ?>>
  <summary style="cursor:pointer;font-weight:900"><?= $clienteEditar ? "Editar cliente" : "+ Registrar nuevo cliente" ?></summary>
  <form method="POST" class="form-grid" style="margin-top:14px">
   <?php if($clienteEditar): ?><input type="hidden" name="id_usuario" value="<?= h($clienteEditar["id_usuario"]) ?>"><?php endif; ?>
   <div class="field"><label>NOMBRES</label><input name="nombres" value="<?= h($clienteEditar["nombres"]??"") ?>" required></div>
   <div class="field"><label>APELLIDOS</label><input name="apellidos" value="<?= h($clienteEditar["apellidos"]??"") ?>"></div>
   <div class="field"><label>CORREO</label><input type="email" name="correo" value="<?= h($clienteEditar["correo"]??"") ?>" required></div>
   <div class="field"><label>TELÉFONO</label><input name="telefono" value="<?= h($clienteEditar["telefono"]??"") ?>"></div>
   <?php if(!$clienteEditar): ?><div class="field"><label>CONTRASEÑA</label><input type="password" name="contrasena" minlength="6" required></div><?php endif; ?>
   <div class="form-actions"><button class="btn btn-primary" name="<?= $clienteEditar ? "actualizar_usuario" : "registrar_usuario" ?>"><?= $clienteEditar ? "Guardar cambios" : "Registrar cliente" ?></button><?php if($clienteEditar): ?><a class="btn btn-light" href="dashboard.php#clientes">Cancelar</a><?php endif; ?></div>
  </form>
 </details>

 <?php if($clienteDetalle): ?>
 <div class="detail-card">
  <div class="detail-head">
   <div><small>CLIENTE #<?= h($clienteDetalle["id_usuario"]) ?></small><h3><?= h($clienteDetalle["nombres"]." ".$clienteDetalle["apellidos"]) ?></h3><p><?= h($clienteDetalle["correo"]) ?> · <?= h($clienteDetalle["telefono"]) ?></p></div>
   <a class="btn btn-light" href="dashboard.php#clientes">Cerrar detalle</a>
  </div>
  <div class="detail-grid">
   <div><small>ESTADO</small><strong><?= h($clienteDetalle["estado"]) ?></strong></div>
   <div><small>PEDIDOS</small><strong><?= count($clientePedidos) ?></strong></div>
   <div><small>TOTAL COMPRADO</small><strong>S/ <?= number_format(array_sum(array_map(fn($x)=>(float)$x["total"],$clientePedidos)),2) ?></strong></div>
  </div>
  <div class="table-wrap mini-table"><table><thead><tr><th>Pedido</th><th>Fecha</th><th>Entrega</th><th>Estado</th><th>Total</th></tr></thead><tbody>
   <?php if(!$clientePedidos): ?><tr><td colspan="5">Este cliente todavía no tiene pedidos.</td></tr><?php else: foreach($clientePedidos as $cped): ?><tr><td><a class="link-action" href="dashboard.php?pedido_detalle=<?= h($cped["id_pedido"]) ?>#pedidos">#<?= h($cped["id_pedido"]) ?></a></td><td><?= h($cped["fecha_pedido"]) ?></td><td><?= h($cped["tipo_entrega"]??"") ?></td><td><span class="status-pill"><?= h($cped["estado_pedido"]) ?></span></td><td class="price">S/ <?= number_format((float)$cped["total"],2) ?></td></tr><?php endforeach; endif; ?>
  </tbody></table></div>
 </div>
 <?php endif; ?>

 <div class="table-wrap"><table id="tablaClientes"><thead><tr><th>Cliente</th><th>Contacto</th><th>Pedidos</th><th>Total comprado</th><th>Última compra</th><th>Estado</th><th>Acciones</th></tr></thead><tbody>
 <?php foreach($clientes as $cl): ?><tr>
  <td><strong><?= h($cl["nombres"]." ".$cl["apellidos"]) ?></strong><small class="table-sub">Cliente #<?= h($cl["id_usuario"]) ?></small></td>
  <td><?= h($cl["correo"]) ?><small class="table-sub"><?= h($cl["telefono"]) ?></small></td>
  <td><?= (int)$cl["total_pedidos"] ?></td>
  <td class="price">S/ <?= number_format((float)$cl["total_comprado"],2) ?></td>
  <td><?= $cl["ultima_compra"] ? h(date("d/m/Y",strtotime($cl["ultima_compra"]))) : "Sin compras" ?></td>
  <td><span class="status-pill <?= strtolower($cl["estado"])==="activo"?"success":"danger" ?>"><?= h($cl["estado"]) ?></span></td>
  <td><div class="order-actions"><a class="btn btn-light btn-small" href="dashboard.php?editar_cliente=<?= h($cl["id_usuario"]) ?>#clientes">Editar</a><a class="btn btn-light btn-small" href="dashboard.php?cliente=<?= h($cl["id_usuario"]) ?>#clientes">Historial</a><form method="POST" class="inline-form"><input type="hidden" name="id_usuario" value="<?= h($cl["id_usuario"]) ?>"><select name="estado_usuario"><option value="Activo" <?= $cl["estado"]==="Activo"?"selected":"" ?>>Activo</option><option value="Bloqueado" <?= $cl["estado"]==="Bloqueado"?"selected":"" ?>>Bloqueado</option></select><button class="btn btn-light btn-small" name="actualizar_estado_usuario">Guardar</button></form></div></td>
 </tr><?php endforeach; ?>
 </tbody></table></div>
</section>
<?php endif; ?>


<?php if(puede("pedidos")): ?>
<section id="pedidos" class="card page-panel">
 <div class="section-intro"><div><h2>Pedidos</h2><p>Consulta el detalle y actualiza el avance de cada venta.</p></div><div class="section-actions"><button type="button" class="btn btn-light" onclick="exportarTabla('tablaPedidos','pedidos_adn.csv')">Exportar CSV</button><span class="badge"><?= $totalPedidos ?> registrados</span></div></div>

 <details class="detail-card" style="margin-bottom:16px">
  <summary style="cursor:pointer;font-weight:900">+ Registrar nuevo pedido</summary>
  <form method="POST" class="form-grid" style="margin-top:14px">
   <div class="field"><label>CLIENTE</label><select name="id_usuario_pedido" required><option value="">Seleccione cliente</option><?php foreach($usuarios as $usr): if(($usr["estado"]??"Activo")!=="Activo") continue; ?><option value="<?= h($usr["id_usuario"]) ?>"><?= h($usr["nombres"]." ".$usr["apellidos"]) ?> — <?= h($usr["correo"]) ?></option><?php endforeach; ?></select></div>
   <div class="field full"><label>PRODUCTOS DEL PEDIDO</label>
    <div id="pedidoItems">
     <div class="line-item-row">
      <select name="id_producto_pedido[]" required><option value="">Seleccione producto</option><?php foreach($productos as $prod): ?><option value="<?= h($prod["id_producto"]) ?>" <?= (int)$prod["stock"]<=0?"disabled":"" ?>><?= h($prod["nombre_producto"]) ?> — Stock <?= (int)$prod["stock"] ?> — S/ <?= number_format((float)($prod["precio_oferta"] ?: $prod["precio"]),2) ?></option><?php endforeach; ?></select>
      <input type="number" min="1" name="cantidad_pedido[]" value="1" required>
      <button type="button" class="btn btn-light btn-small" onclick="quitarLinea(this)">Quitar</button>
     </div>
    </div>
    <button type="button" class="btn btn-light btn-small" style="margin-top:8px" onclick="agregarLineaPedido()">+ Agregar otro producto</button>
   </div>
   <div class="field"><label>ENTREGA</label><select name="tipo_entrega_pedido"><option value="Recojo en tienda">Recojo en tienda</option><option value="Delivery">Delivery</option></select></div>
   <div class="field"><label>DIRECCIÓN PARA DELIVERY</label><select name="id_direccion_pedido"><option value="0">No aplica / Recojo en tienda</option><?php foreach($direcciones as $dir): ?><option value="<?= h($dir["id_direccion"]) ?>">#<?= h($dir["id_usuario"]) ?> — <?= h($dir["nombres"]." ".$dir["apellidos"]) ?> — <?= h($dir["direccion_detalle"]) ?></option><?php endforeach; ?></select></div>
   <div class="field"><label>MÉTODO DE PAGO</label><select name="metodo_pago_pedido"><option>Efectivo</option><option>Yape</option><option>Plin</option><option>Transferencia</option></select></div>
   <div class="form-actions"><button class="btn btn-primary" name="registrar_pedido_manual">Registrar pedido</button></div>
  </form>
 </details>

 <?php if($pedidoDetalle): ?>
 <div class="detail-card order-detail">
  <div class="detail-head">
   <div><small>PEDIDO #<?= h($pedidoDetalle["id_pedido"]) ?></small><h3><?= h($pedidoDetalle["nombres"]." ".$pedidoDetalle["apellidos"]) ?></h3><p><?= h($pedidoDetalle["correo"]) ?> · <?= h($pedidoDetalle["telefono"]) ?></p></div>
   <a class="btn btn-light" href="dashboard.php#pedidos">Cerrar detalle</a>
  </div>
  <div class="order-progress">
   <?php $pasos=["Pendiente","Procesando","Pagado","Enviado","Completado"]; $indiceActual=array_search($pedidoDetalle["estado_pedido"],$pasos,true); foreach($pasos as $idx=>$paso): ?>
    <div class="progress-step <?= $indiceActual!==false && $idx<=$indiceActual?"done":"" ?>"><span><?= $idx+1 ?></span><small><?= h($paso) ?></small></div>
   <?php endforeach; ?>
  </div>
  <div class="detail-grid">
   <div><small>FECHA</small><strong><?= h($pedidoDetalle["fecha_pedido"]) ?></strong></div>
   <div><small>ENTREGA</small><strong><?= h($pedidoDetalle["tipo_entrega"]??"No definido") ?></strong></div>
   <div><small>ESTADO</small><strong><?= h($pedidoDetalle["estado_pedido"]) ?></strong></div>
   <div><small>TOTAL</small><strong>S/ <?= number_format((float)$pedidoDetalle["total"],2) ?></strong></div>
  </div>
  <div class="table-wrap mini-table"><table><thead><tr><th>Producto</th><th>Cantidad</th><th>Precio</th><th>Subtotal</th></tr></thead><tbody>
   <?php foreach($pedidoDetalleItems as $item): ?><tr><td><strong><?= h($item["nombre_producto"]) ?></strong></td><td><?= (int)$item["cantidad"] ?></td><td>S/ <?= number_format((float)$item["precio_unitario"],2) ?></td><td class="price">S/ <?= number_format((float)$item["precio_unitario"]*(int)$item["cantidad"],2) ?></td></tr><?php endforeach; ?>
  </tbody></table></div>
 </div>
 <?php endif; ?>

 <div class="filter-toolbar">
  <div class="filter-title"><strong>Listado de pedidos</strong><small>Filtra por estado para atender primero lo pendiente.</small></div>
  <select id="filtroEstadoPedido"><option value="">Todos los estados</option><?php foreach(["Pendiente","Procesando","Pagado","Enviado","Completado","Cancelado"] as $est): ?><option value="<?= h(strtolower($est)) ?>"><?= h($est) ?></option><?php endforeach; ?></select>
 </div>

 <div class="table-wrap"><table id="tablaPedidos"><thead><tr><th>#</th><th>Cliente</th><th>Fecha</th><th>Total</th><th>Estado</th><th>Acciones</th></tr></thead><tbody>
 <?php foreach($pedidos as $ped): ?><tr data-status="<?= h(strtolower($ped["estado_pedido"])) ?>"><td>#<?= h($ped["id_pedido"]) ?></td><td><strong><?= h($ped["nombres"]." ".$ped["apellidos"]) ?></strong></td><td><?= h(date("d/m/Y H:i",strtotime($ped["fecha_pedido"]))) ?></td><td class="price">S/ <?= number_format((float)$ped["total"],2) ?></td><td><span class="status-pill"><?= h($ped["estado_pedido"]) ?></span></td><td><div class="order-actions"><a class="btn btn-light btn-small" href="dashboard.php?pedido_detalle=<?= h($ped["id_pedido"]) ?>#pedidos">Ver detalle</a><form method="POST" class="inline-form"><input type="hidden" name="id_pedido" value="<?= h($ped["id_pedido"]) ?>"><select name="estado_pedido"><?php foreach(["Pendiente","Procesando","Pagado","Enviado","Completado","Cancelado"] as $est): ?><option value="<?= h($est) ?>" <?= $ped["estado_pedido"]===$est?"selected":"" ?>><?= h($est) ?></option><?php endforeach; ?></select><button class="btn btn-primary btn-small" name="actualizar_estado_pedido">Actualizar</button></form></div></td></tr><?php endforeach; ?>
 </tbody></table></div>
</section>
<?php endif; ?>

<?php if(puede("pagos")): ?>
<section id="pagos" class="card page-panel">
 <div class="section-intro"><div><h2>Pagos</h2><p>Controla montos y confirma el estado de cada pago recibido.</p></div><div class="section-actions"><button type="button" class="btn btn-light" onclick="exportarTabla('tablaPagos','pagos_adn.csv')">Exportar CSV</button><span class="badge">S/ <?= number_format($totalPagos,2) ?> confirmados</span></div></div>
 <details class="detail-card" style="margin-bottom:16px">
  <summary style="cursor:pointer;font-weight:900">+ Registrar pago manual</summary>
  <form method="POST" class="form-grid" style="margin-top:14px">
   <div class="field"><label>PEDIDO</label><select name="id_pedido_pago" required><option value="">Seleccione pedido</option><?php foreach($pedidos as $ped): if(($ped["estado_pedido"]??"") === "Cancelado") continue; ?><option value="<?= h($ped["id_pedido"]) ?>">#<?= h($ped["id_pedido"]) ?> — <?= h($ped["nombres"]." ".$ped["apellidos"]) ?> — S/ <?= number_format((float)$ped["total"],2) ?></option><?php endforeach; ?></select></div>
   <div class="field"><label>MÉTODO</label><select name="metodo_pago_manual"><option>Efectivo</option><option>Yape</option><option>Plin</option><option>Transferencia</option></select></div>
   <div class="field"><label>MONTO</label><input type="number" min="0.01" step="0.01" name="monto_pago" required></div>
   <div class="field"><label>ESTADO</label><select name="estado_pago_manual"><option>Pendiente</option><option>Pagado</option><option>Rechazado</option></select></div>
   <div class="form-actions"><button class="btn btn-primary" name="registrar_pago_manual">Registrar pago</button></div>
  </form>
 </details>
 <div class="table-wrap"><table id="tablaPagos"><thead><tr><th>ID</th><th>Pedido</th><th>Cliente</th><th>Método</th><th>Monto</th><th>Pagado</th><th>Saldo</th><th>Estado</th><th>Acción</th></tr></thead><tbody>
 <?php if(!$pagos): ?><tr><td colspan="7" class="empty-cell">Todavía no hay pagos.</td></tr><?php else: foreach($pagos as $pg): ?><tr>
  <td>#<?= h($pg["id_pago"]) ?></td><td><a class="link-action" href="dashboard.php?pedido_detalle=<?= h($pg["id_pedido"]) ?>#pedidos">#<?= h($pg["id_pedido"]) ?></a></td><td><strong><?= h($pg["nombres"]." ".$pg["apellidos"]) ?></strong></td><td><?= h($pg["metodo_pago"]) ?></td><td class="price">S/ <?= number_format((float)$pg["monto"],2) ?></td><td><span class="status-pill"><?= h($pg["estado_pago"]) ?></span></td>
  <td><form method="POST" class="inline-form"><input type="hidden" name="id_pago" value="<?= h($pg["id_pago"]) ?>"><select name="estado_pago"><?php foreach(["Pendiente","Pagado","Rechazado"] as $estPago): ?><option value="<?= h($estPago) ?>" <?= $pg["estado_pago"]===$estPago?"selected":"" ?>><?= h($estPago) ?></option><?php endforeach; ?></select><button class="btn btn-primary btn-small" name="actualizar_estado_pago">Actualizar</button></form></td>
 </tr><?php endforeach; endif; ?>
 </tbody></table></div>
</section>
<?php endif; ?>

<?php if(puede("comprobantes")): ?>
<section id="comprobantes" class="card page-panel">
 <div class="section-intro"><div><h2>Comprobantes</h2><p>Emite boletas o facturas usando el IGV configurado de <?= number_format($igvEmpresa,2) ?>%.</p></div><span class="badge"><?= count($comprobantes) ?> emitidos</span></div>
 <form method="POST" class="form-grid">
  <div class="field"><label>PEDIDO</label><select name="id_pedido_comprobante" required><option value="">Seleccione pedido</option><?php foreach($pedidos as $ped): ?><option value="<?= h($ped["id_pedido"]) ?>">#<?= h($ped["id_pedido"]) ?> — <?= h($ped["nombres"]." ".$ped["apellidos"]) ?> — S/ <?= number_format((float)$ped["total"],2) ?></option><?php endforeach; ?></select></div>
  <div class="field"><label>TIPO</label><select name="tipo_comprobante"><option>Boleta</option><option>Factura</option></select></div>
  <div class="field"><label>NÚMERO</label><input name="numero_comprobante" placeholder="Automático si lo dejas vacío"></div>
  <div class="form-actions"><button class="btn btn-primary" name="registrar_comprobante">+ Emitir comprobante</button></div>
 </form>
 <div class="table-wrap"><table><thead><tr><th>ID</th><th>Pedido</th><th>Cliente</th><th>Tipo</th><th>Número</th><th>Subtotal</th><th>IGV</th><th>Total</th><th></th></tr></thead><tbody>
 <?php if(!$comprobantes): ?><tr><td colspan="9" class="empty-cell">No hay comprobantes.</td></tr><?php else: foreach($comprobantes as $cp): ?><tr><td>#<?= h($cp["id_comprobante"]) ?></td><td>#<?= h($cp["id_pedido"]) ?></td><td><?= h($cp["nombres"]." ".$cp["apellidos"]) ?></td><td><?= h($cp["tipo_comprobante"]) ?></td><td><strong><?= h($cp["numero_comprobante"]) ?></strong></td><td>S/ <?= number_format((float)$cp["subtotal"],2) ?></td><td>S/ <?= number_format((float)$cp["igv"],2) ?></td><td class="price">S/ <?= number_format((float)$cp["total"],2) ?></td><td><div class="actions"><a class="btn btn-light btn-small" target="_blank" href="comprobante_print.php?id=<?= h($cp["id_comprobante"]) ?>">Imprimir</a><form method="POST" onsubmit="return confirm('¿Eliminar comprobante?');"><input type="hidden" name="id_comprobante" value="<?= h($cp["id_comprobante"]) ?>"><button class="btn btn-danger btn-small" name="eliminar_comprobante">Eliminar</button></form></div></td></tr><?php endforeach; endif; ?>
 </tbody></table></div>
</section>
<?php endif; ?>


<?php if(puede("clientes")): ?>
<section id="direcciones" class="card page-panel">
 <div class="section-intro"><div><h2>Direcciones de clientes</h2><p>Registra, edita y controla las direcciones usadas en pedidos con delivery.</p></div><span class="badge"><?= count($direcciones) ?> registradas</span></div>

 <details class="detail-card" style="margin-bottom:16px" <?= $direccionEditar ? "open" : "" ?>>
  <summary style="cursor:pointer;font-weight:900"><?= $direccionEditar ? "Editar dirección" : "+ Registrar dirección" ?></summary>
  <form method="POST" class="form-grid" style="margin-top:14px">
   <?php if($direccionEditar): ?><input type="hidden" name="id_direccion" value="<?= h($direccionEditar["id_direccion"]) ?>"><?php endif; ?>
   <div class="field"><label>CLIENTE</label><select name="id_usuario_direccion" required><option value="">Seleccione cliente</option><?php foreach($usuarios as $usr): ?><option value="<?= h($usr["id_usuario"]) ?>" <?= (int)($direccionEditar["id_usuario"]??0)===(int)$usr["id_usuario"]?"selected":"" ?>><?= h($usr["nombres"]." ".$usr["apellidos"]) ?> — <?= h($usr["correo"]) ?></option><?php endforeach; ?></select></div>
   <div class="field"><label>DEPARTAMENTO</label><input name="departamento" required value="<?= h($direccionEditar["departamento"]??"Ucayali") ?>"></div>
   <div class="field"><label>PROVINCIA</label><input name="provincia" required value="<?= h($direccionEditar["provincia"]??"Coronel Portillo") ?>"></div>
   <div class="field"><label>DISTRITO</label><input name="distrito" required value="<?= h($direccionEditar["distrito"]??"Callería") ?>"></div>
   <div class="field full"><label>DIRECCIÓN</label><input name="direccion_detalle" required value="<?= h($direccionEditar["direccion_detalle"]??"") ?>" placeholder="Jr., Av., Mz., Lt."></div>
   <div class="field full"><label>REFERENCIA</label><input name="referencia" value="<?= h($direccionEditar["referencia"]??"") ?>" placeholder="Referencia opcional"></div>
   <div class="form-actions"><button class="btn btn-primary" name="<?= $direccionEditar ? "actualizar_direccion" : "registrar_direccion" ?>"><?= $direccionEditar ? "Guardar cambios" : "Registrar dirección" ?></button><?php if($direccionEditar): ?><a class="btn btn-light" href="dashboard.php#direcciones">Cancelar</a><?php endif; ?></div>
  </form>
 </details>

 <div class="table-wrap"><table id="tablaDirecciones"><thead><tr><th>ID</th><th>Cliente</th><th>Ubicación</th><th>Dirección</th><th>Referencia</th><th>Acciones</th></tr></thead><tbody>
 <?php if(!$direcciones): ?><tr><td colspan="6" class="empty-cell">Todavía no hay direcciones registradas.</td></tr><?php else: foreach($direcciones as $dir): ?><tr><td>#<?= h($dir["id_direccion"]) ?></td><td><strong><?= h($dir["nombres"]." ".$dir["apellidos"]) ?></strong><small class="table-sub"><?= h($dir["correo"]) ?></small></td><td><?= h($dir["distrito"]) ?>, <?= h($dir["provincia"]) ?>, <?= h($dir["departamento"]) ?></td><td><?= h($dir["direccion_detalle"]) ?></td><td><?= h($dir["referencia"]) ?></td><td><div class="actions"><a class="btn btn-light btn-small" href="dashboard.php?editar_direccion=<?= h($dir["id_direccion"]) ?>#direcciones">Editar</a><form method="POST" onsubmit="return confirm('¿Eliminar dirección?');"><input type="hidden" name="id_direccion" value="<?= h($dir["id_direccion"]) ?>"><button class="btn btn-danger btn-small" name="eliminar_direccion">Eliminar</button></form></div></td></tr><?php endforeach; endif; ?>
 </tbody></table></div>
</section>
<?php endif; ?>

<?php if(puede("inventario")): ?>
<section id="inventario" class="card page-panel">
 <div class="section-intro">
  <div><h2>Inventario y Kardex</h2><p>Controla existencias y conserva el historial de cada entrada y salida.</p></div>
  <div class="kpi-inline"><span class="pill"><?= $unidadesStock ?> unidades</span><span class="pill danger-soft"><?= $stockBajo ?> bajo mínimo</span></div>
 </div>
 <div class="two-col inventory-layout">
  <div>
   <form method="POST" class="form-grid" style="grid-template-columns:1fr">
    <div class="field"><label>PRODUCTO</label><select name="id_producto_stock" required><option value="">Seleccione producto</option><?php foreach($productos as $prod): ?><option value="<?= h($prod["id_producto"]) ?>"><?= h($prod["nombre_producto"]) ?> — Stock: <?= (int)$prod["stock"] ?> / Mín: <?= (int)($prod["stock_minimo"]??5) ?></option><?php endforeach; ?></select></div>
    <div class="field"><label>TIPO DE MOVIMIENTO</label><select name="tipo_movimiento"><option>Entrada</option><option>Salida</option></select></div>
    <div class="field"><label>CANTIDAD</label><input type="number" min="1" name="cantidad_movimiento" required></div>
    <div class="field"><label>MOTIVO</label><input type="text" name="motivo_movimiento" placeholder="Ej. Ajuste, pérdida, ingreso manual"></div>
    <div class="form-actions"><button class="btn btn-primary" name="registrar_movimiento">Registrar movimiento</button></div>
   </form>
   <div class="inventory-summary">
    <?php foreach(array_slice($productosStockBajo,0,5) as $sb): ?><div><span class="stock-dot <?= (int)$sb["stock"]<=0?"danger":"warning" ?>"></span><strong><?= h($sb["nombre_producto"]) ?></strong><small><?= (int)$sb["stock"] ?> / mín. <?= (int)$sb["stock_minimo"] ?></small></div><?php endforeach; ?>
    <?php if(!$productosStockBajo): ?><div class="empty-state">✓ No hay productos debajo del mínimo.</div><?php endif; ?>
   </div>
  </div>
  <div class="table-wrap"><table id="tablaKardex"><thead><tr><th>Fecha</th><th>Producto</th><th>Tipo</th><th>Cant.</th><th>Anterior</th><th>Nuevo</th><th>Motivo</th></tr></thead><tbody>
   <?php if(!$movimientos): ?><tr><td colspan="7" class="empty-cell">No hay movimientos de stock.</td></tr><?php else: foreach($movimientos as $mv): ?><tr><td><?= h($mv["fecha_movimiento"]) ?></td><td><strong><?= h($mv["nombre_producto"]) ?></strong></td><td><span class="status-pill <?= $mv["tipo_movimiento"]==="Entrada"?"success":"warning" ?>"><?= h($mv["tipo_movimiento"]) ?></span></td><td><?= (int)$mv["cantidad"] ?></td><td><?= $mv["stock_anterior"]!==null?(int)$mv["stock_anterior"]:"-" ?></td><td><strong><?= $mv["stock_nuevo"]!==null?(int)$mv["stock_nuevo"]:"-" ?></strong></td><td><?= h($mv["motivo"]) ?></td></tr><?php endforeach; endif; ?>
  </tbody></table></div>
 </div>
</section>
<?php endif; ?>

<?php if(puede("proveedores")): ?>
<section id="proveedores" class="card page-panel">
 <div class="section-intro"><div><h2>Proveedores</h2><p>Empresas que abastecen los repuestos de <?= h($configEmpresa["nombre_comercial"]??"Dorada Motors") ?>.</p></div><span class="badge"><?= $totalProveedores ?> registrados</span></div>
 <form method="POST" class="form-grid">
  <?php if($proveedorEditar): ?><input type="hidden" name="id_proveedor" value="<?= h($proveedorEditar["id_proveedor"]) ?>"><?php endif; ?>
  <div class="field"><label>RAZÓN SOCIAL</label><input name="razon_social" value="<?= h($proveedorEditar["razon_social"]??"") ?>" required placeholder="Nombre del proveedor"></div>
  <div class="field"><label>RUC</label><input name="ruc" value="<?= h($proveedorEditar["ruc"]??"") ?>" placeholder="RUC"></div>
  <div class="field"><label>TELÉFONO</label><input name="telefono_proveedor" value="<?= h($proveedorEditar["telefono"]??"") ?>"></div>
  <div class="field"><label>CORREO</label><input type="email" name="correo_proveedor" value="<?= h($proveedorEditar["correo"]??"") ?>"></div>
  <div class="field"><label>ESTADO</label><select name="estado_proveedor"><option value="Activo" <?= ($proveedorEditar["estado"]??"Activo")==="Activo"?"selected":"" ?>>Activo</option><option value="Inactivo" <?= ($proveedorEditar["estado"]??"")==="Inactivo"?"selected":"" ?>>Inactivo</option></select></div>
  <div class="field full"><label>DIRECCIÓN</label><input name="direccion_proveedor" value="<?= h($proveedorEditar["direccion"]??"") ?>"></div>
  <div class="form-actions"><button class="btn btn-primary" name="<?= $proveedorEditar ? "actualizar_proveedor" : "registrar_proveedor" ?>"><?= $proveedorEditar ? "Guardar cambios" : "+ Registrar proveedor" ?></button><?php if($proveedorEditar): ?><a class="btn btn-light" href="dashboard.php#proveedores">Cancelar</a><?php endif; ?></div>
 </form>
 <div class="table-wrap"><table><thead><tr><th>ID</th><th>Proveedor</th><th>RUC</th><th>Teléfono</th><th>Correo</th><th>Estado</th><th>Acción</th></tr></thead><tbody>
 <?php if(!$proveedores): ?><tr><td colspan="7" class="empty-cell">No hay proveedores registrados.</td></tr><?php else: foreach($proveedores as $pr): ?><tr><td>#<?= h($pr["id_proveedor"]) ?></td><td><strong><?= h($pr["razon_social"]) ?></strong></td><td><?= h($pr["ruc"]) ?></td><td><?= h($pr["telefono"]) ?></td><td><?= h($pr["correo"]) ?></td><td><span class="status-pill <?= strtolower((string)$pr["estado"])==="activo"?"success":"danger" ?>"><?= h($pr["estado"]) ?></span></td><td><div class="actions"><a class="btn btn-light btn-small" href="dashboard.php?editar_proveedor=<?= h($pr["id_proveedor"]) ?>#proveedores">Editar</a><form method="POST" onsubmit="return confirm('¿Eliminar proveedor?');"><input type="hidden" name="id_proveedor" value="<?= h($pr["id_proveedor"]) ?>"><button class="btn btn-danger btn-small" name="eliminar_proveedor">Eliminar</button></form></div></td></tr><?php endforeach; endif; ?>
 </tbody></table></div>
</section>
<?php endif; ?>

<?php if(puede("compras")): ?>
<section id="compras" class="card page-panel">
 <div class="section-intro"><div><h2>Compras y abastecimiento</h2><p>Registra la reposición de mercadería; el stock aumenta automáticamente.</p></div><span class="badge">S/ <?= number_format($totalCompras,2) ?></span></div>
 <form method="POST" class="form-grid">
  <div class="field"><label>PROVEEDOR</label><select name="id_proveedor_compra" required><option value="">Seleccione proveedor</option><?php foreach($proveedores as $pr): ?><option value="<?= h($pr["id_proveedor"]) ?>"><?= h($pr["razon_social"]) ?></option><?php endforeach; ?></select></div>
  <div class="field full"><label>PRODUCTOS DE LA COMPRA</label>
   <div id="compraItems">
    <div class="line-item-row purchase-line">
     <select name="id_producto_compra[]" required><option value="">Seleccione producto</option><?php foreach($productos as $prod): ?><option value="<?= h($prod["id_producto"]) ?>"><?= h($prod["nombre_producto"]) ?> · Stock <?= (int)$prod["stock"] ?></option><?php endforeach; ?></select>
     <input type="number" min="1" name="cantidad_compra[]" placeholder="Cantidad" required>
     <input type="number" min="0" step="0.01" name="precio_compra[]" placeholder="Costo unitario" required>
     <button type="button" class="btn btn-light btn-small" onclick="quitarLinea(this)">Quitar</button>
    </div>
   </div>
   <button type="button" class="btn btn-light btn-small" style="margin-top:8px" onclick="agregarLineaCompra()">+ Agregar otro producto</button>
  </div>
  <div class="form-actions"><button class="btn btn-primary" name="registrar_compra">+ Registrar compra</button></div>
 </form>
 <div class="table-wrap"><table id="tablaCompras"><thead><tr><th>ID</th><th>Proveedor</th><th>Productos</th><th>Unidades</th><th>Total</th><th>Fecha</th><th>Estado</th><th>Acción</th></tr></thead><tbody>
 <?php if(!$compras): ?><tr><td colspan="8" class="empty-cell">No hay compras registradas.</td></tr><?php else: foreach($compras as $co): ?><tr data-status="<?= h(strtolower((string)$co["estado"])) ?>"><td>#<?= h($co["id_compra"]) ?></td><td><strong><?= h($co["razon_social"]) ?></strong></td><td><?= h($co["nombre_producto"]??"-") ?></td><td><?= (int)($co["cantidad"]??0) ?></td><td class="price">S/ <?= number_format((float)$co["total"],2) ?></td><td><?= h($co["fecha_compra"]) ?></td><td><span class="status-pill <?= strtolower((string)$co["estado"])==="anulado"?"danger":"success" ?>"><?= h($co["estado"]) ?></span></td><td><form method="POST" class="inline-form"><input type="hidden" name="id_compra" value="<?= h($co["id_compra"]) ?>"><select name="estado_compra"><option value="Registrado" <?= $co["estado"]==="Registrado"?"selected":"" ?>>Registrado</option><option value="Anulado" <?= $co["estado"]==="Anulado"?"selected":"" ?>>Anulado</option></select><button class="btn btn-light btn-small" name="actualizar_estado_compra">Guardar</button></form></td></tr><?php endforeach; endif; ?>
 </tbody></table></div>
</section>
<?php endif; ?>

<?php if(puede("reportes")): ?>
<section id="reportes" class="card page-panel">
 <div class="section-intro"><div><h2>Reportes y análisis</h2><p>Selecciona un periodo y revisa ventas, pedidos y productos más vendidos.</p></div><div class="section-actions"><button type="button" class="btn btn-light" onclick="window.print()">Imprimir</button><span class="badge"><?= h($reporteDesde) ?> → <?= h($reporteHasta) ?></span></div></div>

 <form method="GET" action="dashboard.php#reportes" class="report-filter">
  <div class="field"><label>DESDE</label><input type="date" name="desde" value="<?= h($reporteDesde) ?>"></div>
  <div class="field"><label>HASTA</label><input type="date" name="hasta" value="<?= h($reporteHasta) ?>"></div>
  <button class="btn btn-primary">Aplicar periodo</button>
 </form>

 <div class="stats-row report-stats">
  <div class="mini-stat"><small>VENTAS DEL PERIODO</small><strong>S/ <?= number_format((float)$reporteResumen["ventas"],2) ?></strong></div>
  <div class="mini-stat"><small>PEDIDOS DEL PERIODO</small><strong><?= (int)$reporteResumen["pedidos"] ?></strong></div>
  <div class="mini-stat"><small>TICKET PROMEDIO</small><strong>S/ <?= number_format((float)$reporteResumen["ticket_promedio"],2) ?></strong></div>
  <div class="mini-stat"><small>UNIDADES EN STOCK</small><strong><?= $unidadesStock ?></strong></div>
  <div class="mini-stat"><small>STOCK BAJO</small><strong><?= $stockBajo ?></strong></div>
  <div class="mini-stat"><small>COMPRAS ACUMULADAS</small><strong>S/ <?= number_format($totalCompras,2) ?></strong></div>
 </div>

 <div class="two-col report-grid">
  <div class="table-wrap"><table id="tablaReporteProductos"><thead><tr><th>Producto</th><th>Unidades</th><th>Importe</th></tr></thead><tbody>
   <?php if(!$reporteTopProductos): ?><tr><td colspan="3" class="empty-cell">No hay ventas en el periodo.</td></tr><?php else: foreach($reporteTopProductos as $rp): ?><tr><td><strong><?= h($rp["nombre_producto"]) ?></strong></td><td><?= (int)$rp["unidades"] ?></td><td class="price">S/ <?= number_format((float)$rp["importe"],2) ?></td></tr><?php endforeach; endif; ?>
  </tbody></table></div>
  <div class="report-actions-card">
   <span class="report-icon">▥</span><h3>Exportar información</h3><p>Puedes imprimir el reporte o exportar las tablas principales para trabajar en Excel.</p>
   <button type="button" class="btn btn-light" onclick="exportarTabla('tablaReporteProductos','reporte_productos_adn.csv')">Exportar productos CSV</button>
   <button type="button" class="btn btn-light" onclick="exportarTabla('tablaPedidos','pedidos_adn.csv')">Exportar pedidos CSV</button>
  </div>
 </div>
</section>
<?php endif; ?>

<?php if(puede("soporte")): ?>
<section id="soporte" class="card page-panel">
 <div class="section-intro">
  <div><h2>Atención al cliente</h2><p>Consultas enviadas desde Flutter. Responde aquí y el cliente verá el seguimiento en su aplicación.</p></div>
  <span class="badge"><?= $totalSoportePendiente ?> por atender</span>
 </div>
 <div class="table-wrap">
  <table>
   <thead><tr><th>N.º</th><th>Cliente</th><th>Consulta</th><th>Estado</th><th>Atender</th></tr></thead>
   <tbody>
    <?php if(!$solicitudesSoporte): ?>
     <tr><td colspan="5" class="empty-cell">Todavía no se han recibido consultas.</td></tr>
    <?php else: foreach($solicitudesSoporte as $sol): ?>
     <tr>
      <td>#<?= (int)$sol["id_solicitud"] ?><small class="table-sub"><?= h($sol["fecha_creacion"]) ?></small></td>
      <td><strong><?= h(trim($sol["nombres"]." ".$sol["apellidos"])) ?></strong><small class="table-sub"><?= h($sol["correo"]) ?></small></td>
      <td><strong><?= h($sol["asunto"]) ?></strong><p style="max-width:350px;white-space:pre-wrap;overflow-wrap:anywhere"><?= h($sol["mensaje"]) ?></p></td>
      <td><span class="status-pill"><?= h($sol["estado"]) ?></span></td>
      <td>
       <form method="POST" style="min-width:230px;display:grid;gap:8px">
        <?= csrfInput() ?>
        <input type="hidden" name="id_solicitud" value="<?= (int)$sol["id_solicitud"] ?>">
        <label for="estado_s_<?= (int)$sol["id_solicitud"] ?>">Estado</label>
        <select id="estado_s_<?= (int)$sol["id_solicitud"] ?>" name="estado_soporte">
         <?php foreach(["Abierto","En proceso","Respondido","Cerrado"] as $estadoItem): ?>
          <option value="<?= h($estadoItem) ?>" <?= $sol["estado"]===$estadoItem?"selected":"" ?>><?= h($estadoItem) ?></option>
         <?php endforeach; ?>
        </select>
        <label for="respuesta_s_<?= (int)$sol["id_solicitud"] ?>">Respuesta</label>
        <textarea id="respuesta_s_<?= (int)$sol["id_solicitud"] ?>" name="respuesta_soporte" rows="3" maxlength="5000" placeholder="Respuesta para el cliente"><?= h($sol["respuesta"]??"") ?></textarea>
        <button class="btn btn-primary btn-small" name="responder_soporte" type="submit">Guardar respuesta</button>
       </form>
       <?php if(rolActual()==="Administrador" && $sol["asunto"]==="Recuperación de acceso"): ?>
       <form method="POST" style="margin-top:10px;display:grid;gap:8px">
        <?= csrfInput() ?>
        <input type="hidden" name="id_solicitud" value="<?= (int)$sol["id_solicitud"] ?>">
        <label>Clave temporal nueva (mínimo 8 caracteres)</label>
        <input type="password" name="clave_temporal" minlength="8" maxlength="128" required autocomplete="new-password">
        <label style="display:flex;gap:6px;align-items:flex-start;font-size:11px">
         <input type="checkbox" name="identidad_verificada" value="1" required>
         Confirmo que verifiqué la identidad del cliente por un canal confiable.
        </label>
        <button class="btn btn-light btn-small" name="restablecer_clave_cliente" type="submit">Restablecer acceso</button>
        <small>Comunica la clave por un canal verificado. Nunca se enviará automáticamente ni se mostrará en el historial.</small>
       </form>
       <?php endif; ?>
      </td>
     </tr>
    <?php endforeach; endif; ?>
   </tbody>
  </table>
 </div>
</section>
<?php endif; ?>

<?php if(puede("configuracion")): ?>
<section id="configuracion" class="card page-panel">
 <div class="section-intro">
  <div><h2>Configuración y personal</h2><p>Administra los datos de Dorada Motors y las cuentas que pueden ingresar al panel.</p></div>
  <span class="badge"><?= count($usuariosAdmin) ?> cuenta(s) administrativas</span>
 </div>

 <div class="two-col">
  <div class="detail-card">
   <h3 style="margin-top:0">Datos de la empresa</h3>
   <form method="POST" class="form-grid">
    <div class="field"><label>NOMBRE COMERCIAL</label><input name="nombre_comercial" required value="<?= h($configEmpresa["nombre_comercial"]) ?>"></div>
    <div class="field"><label>RAZÓN SOCIAL</label><input name="razon_social" required value="<?= h($configEmpresa["razon_social"]) ?>"></div>
    <div class="field"><label>RUC</label><input name="ruc" maxlength="11" value="<?= h($configEmpresa["ruc"]) ?>" placeholder="11 dígitos"></div>
    <div class="field"><label>TELÉFONO</label><input name="telefono_empresa" value="<?= h($configEmpresa["telefono"]) ?>"></div>
    <div class="field"><label>CORREO</label><input type="email" name="correo_empresa" value="<?= h($configEmpresa["correo"]) ?>"></div>
    <div class="field"><label>MONEDA</label><input name="moneda" value="<?= h($configEmpresa["moneda"]) ?>"></div>
    <div class="field full"><label>DIRECCIÓN</label><input name="direccion_empresa" value="<?= h($configEmpresa["direccion"]) ?>"></div>
    <div class="field"><label>IGV (%)</label><input type="number" min="0" max="100" step="0.01" name="igv" value="<?= h($configEmpresa["igv"]) ?>"></div>
    <div class="field"><label>COSTO DELIVERY</label><input type="number" min="0" step="0.01" name="costo_delivery" value="<?= h($configEmpresa["costo_delivery"] ?? 0) ?>"></div>
    <div class="form-actions"><button class="btn btn-primary" name="guardar_config_empresa">Guardar empresa</button></div>
   </form>
  </div>

  <div class="detail-card">
   <h3 style="margin-top:0">Cambiar mi contraseña</h3>
   <form method="POST" class="form-grid" style="grid-template-columns:1fr">
    <div class="field"><label>CONTRASEÑA ACTUAL</label><input type="password" name="clave_actual" required autocomplete="current-password"></div>
    <div class="field"><label>NUEVA CONTRASEÑA</label><input type="password" name="clave_nueva" minlength="8" required autocomplete="new-password"></div>
    <div class="field"><label>CONFIRMAR NUEVA CONTRASEÑA</label><input type="password" name="clave_confirmar" minlength="8" required autocomplete="new-password"></div>
    <div class="form-actions"><button class="btn btn-primary" name="cambiar_clave_admin">Cambiar contraseña</button></div>
   </form>
  </div>
 </div>

 <div class="detail-card" style="margin-top:16px">
  <h3 style="margin-top:0">Crear cuenta del personal</h3>
  <form method="POST" class="form-grid">
   <div class="field"><label>NOMBRES</label><input name="admin_nombres" required></div>
   <div class="field"><label>APELLIDOS</label><input name="admin_apellidos"></div>
   <div class="field"><label>CORREO</label><input type="email" name="admin_correo" required></div>
   <div class="field"><label>TELÉFONO</label><input name="admin_telefono"></div>
   <div class="field"><label>ROL</label><select name="admin_rol"><option>Vendedor</option><option>Almacen</option><option>Administrador</option></select></div>
   <div class="field"><label>CONTRASEÑA</label><input type="password" name="admin_contrasena" minlength="8" required></div>
   <div class="form-actions"><button class="btn btn-primary" name="crear_usuario_admin">Crear cuenta</button></div>
  </form>
 </div>

 <div class="table-wrap" style="margin-top:16px"><table id="tablaPersonal"><thead><tr><th>Personal</th><th>Correo</th><th>Rol</th><th>Estado</th><th>Último acceso</th><th>Acción</th></tr></thead><tbody>
 <?php foreach($usuariosAdmin as $ua): ?><tr>
  <td><strong><?= h($ua["nombres"]." ".$ua["apellidos"]) ?></strong></td>
  <td><?= h($ua["correo"]) ?></td>
  <td><?= h($ua["rol_sistema"]) ?></td>
  <td><span class="status-pill <?= $ua["estado"]==="Activo"?"success":"danger" ?>"><?= h($ua["estado"]) ?></span></td>
  <td><?= h($ua["ultimo_acceso"] ?: "Sin ingreso") ?></td>
  <td>
   <form method="POST" class="inline-form">
    <input type="hidden" name="id_usuario_admin" value="<?= h($ua["id_usuario"]) ?>">
    <select name="rol_usuario_admin"><?php foreach(["Administrador","Vendedor","Almacen"] as $rolOp): ?><option value="<?= h($rolOp) ?>" <?= $ua["rol_sistema"]===$rolOp?"selected":"" ?>><?= h($rolOp) ?></option><?php endforeach; ?></select>
    <select name="estado_usuario_admin"><option value="Activo" <?= $ua["estado"]==="Activo"?"selected":"" ?>>Activo</option><option value="Bloqueado" <?= $ua["estado"]==="Bloqueado"?"selected":"" ?>>Bloqueado</option></select>
    <button class="btn btn-light btn-small" name="actualizar_usuario_admin">Guardar</button>
   </form>
  </td>
 </tr><?php endforeach; ?>
 </tbody></table></div>

 <div class="help-card">
  <div><strong>Permisos por rol</strong><p>Administrador: acceso completo · Vendedor: clientes, pedidos, pagos, comprobantes y reportes · Almacén: productos, inventario, compras, proveedores y reportes.</p></div>
  <a class="btn btn-danger" href="admin_logout.php">Cerrar sesión</a>
 </div>
</section>
<?php endif; ?>


</div>
</main>
</div>

<nav class="mobile-bottom">
 <a href="#inicio" class="active">⌂<b>Inicio</b></a>
 <?php if(puede("gestion-productos")): ?><a href="#gestion-productos">◇<b>Productos</b></a><?php elseif(puede("clientes")): ?><a href="#clientes">👤<b>Clientes</b></a><?php endif; ?>
 <?php if(puede("pedidos")): ?><a href="#pedidos">🛒<b>Pedidos</b></a><?php elseif(puede("inventario")): ?><a href="#inventario">▤<b>Stock</b></a><?php endif; ?>
 <?php if(puede("reportes")): ?><a href="#reportes">▥<b>Reportes</b></a><?php else: ?><a href="#inicio">⌂<b>Inicio</b></a><?php endif; ?>
</nav>

<script>
const csrfToken=<?= json_encode(csrfToken()) ?>;
const buscador=document.getElementById('buscador');
const sidebar=document.getElementById('sidebar');
const overlay=document.getElementById('overlay');
const menuBtn=document.getElementById('menuBtn');
const navLinks=document.querySelectorAll('.nav a');
const mobileLinks=document.querySelectorAll('.mobile-bottom a');
const panels=document.querySelectorAll('.page-panel');
const topTitle=document.getElementById('topTitle');

document.querySelectorAll('[data-nav-toggle]').forEach(btn=>{
 btn.addEventListener('click',()=>{
  const folder=btn.closest('.nav-folder');
  const estabaAbierto=folder?.classList.contains('open');
  document.querySelectorAll('.nav-folder').forEach(f=>f.classList.remove('open'));
  if(folder && !estabaAbierto) folder.classList.add('open');
 });
});

function actualizarMenuAgrupado(id){
 document.querySelectorAll('.nav-submenu a').forEach(a=>{
  a.classList.toggle('active',a.getAttribute('href')==='#'+id);
 });
 document.querySelectorAll('.nav-folder').forEach(folder=>{
  const contiene=[...folder.querySelectorAll('.nav-submenu a')].some(a=>a.getAttribute('href')==='#'+id);
  folder.classList.toggle('open',contiene);
  folder.querySelector('.nav-main')?.classList.toggle('active',contiene);
 });
}

const filtroCategoriaProducto=document.getElementById('filtroCategoriaProducto');
const filtroStockProducto=document.getElementById('filtroStockProducto');
const filtroEstadoPedido=document.getElementById('filtroEstadoPedido');

document.querySelectorAll('form[method="POST"],form[method="post"]').forEach(form=>{
 if(!form.querySelector('input[name="csrf_token"]')){
  const input=document.createElement('input');
  input.type='hidden';
  input.name='csrf_token';
  input.value=csrfToken;
  form.appendChild(input);
 }
});

const nombresPanel={
 inicio:'Dashboard',
 'gestion-productos':'Productos',
 inventario:'Inventario / Kardex',
 proveedores:'Proveedores',
 compras:'Compras',
 categorias:'Categorías',
 marcas:'Marcas',
 clientes:'Clientes',
 direcciones:'Direcciones',
 pedidos:'Pedidos',
 pagos:'Pagos',
 comprobantes:'Comprobantes',
 reportes:'Reportes',
 configuracion:'Configuración',
 };

function cerrarMenu(){
 sidebar?.classList.remove('open');
 overlay?.classList.remove('show');
}

function filaCoincide(fila,tabla){
 const texto=(buscador?.value||'').toLowerCase().trim();
 if(texto && !fila.innerText.toLowerCase().includes(texto)) return false;

 if(tabla.id==='tablaProductos'){
  const categoria=filtroCategoriaProducto?.value||'';
  const stock=filtroStockProducto?.value||'';
  if(categoria && fila.dataset.category!==categoria) return false;
  if(stock && fila.dataset.stock!==stock) return false;
 }

 if(tabla.id==='tablaPedidos'){
  const estado=filtroEstadoPedido?.value||'';
  if(estado && fila.dataset.status!==estado) return false;
 }

 return true;
}

function renderTabla(tabla,reset=false){
 if(!tabla?.tBodies?.length) return;
 const filas=[...tabla.tBodies[0].rows].filter(f=>!f.querySelector('.empty-cell'));
 if(filas.length===0) return;

 const porPagina=10;
 tabla._pagina=reset ? 1 : (tabla._pagina||1);
 const coinciden=filas.filter(f=>filaCoincide(f,tabla));
 const totalPaginas=Math.max(1,Math.ceil(coinciden.length/porPagina));
 if(tabla._pagina>totalPaginas) tabla._pagina=totalPaginas;

 filas.forEach(f=>f.style.display='none');
 const inicio=(tabla._pagina-1)*porPagina;
 coinciden.slice(inicio,inicio+porPagina).forEach(f=>f.style.display='');

 let pag=tabla.parentElement?.nextElementSibling;
 if(!pag || !pag.classList.contains('pagination')){
  pag=document.createElement('div');
  pag.className='pagination';
  tabla.parentElement?.insertAdjacentElement('afterend',pag);
 }

 pag.innerHTML='';
 if(coinciden.length<=porPagina){
  if(coinciden.length>0) pag.innerHTML='<span>'+coinciden.length+' registro(s)</span>';
  else pag.innerHTML='<span>Sin resultados para el filtro actual</span>';
  return;
 }

 const info=document.createElement('span');
 info.textContent=coinciden.length+' registros · Página '+tabla._pagina+' de '+totalPaginas;
 pag.appendChild(info);

 const crearBoton=(texto,pagina,activo=false)=>{
  const b=document.createElement('button');
  b.type='button';
  b.textContent=texto;
  if(activo) b.classList.add('active');
  b.addEventListener('click',()=>{tabla._pagina=pagina;renderTabla(tabla,false);});
  return b;
 };

 if(tabla._pagina>1) pag.appendChild(crearBoton('‹',tabla._pagina-1));
 const desde=Math.max(1,tabla._pagina-2);
 const hasta=Math.min(totalPaginas,desde+4);
 for(let p=desde;p<=hasta;p++) pag.appendChild(crearBoton(String(p),p,p===tabla._pagina));
 if(tabla._pagina<totalPaginas) pag.appendChild(crearBoton('›',tabla._pagina+1));
}

function refrescarTablas(reset=true){
 const activo=document.querySelector('.page-panel.active');
 if(!activo) return;
 activo.querySelectorAll('.table-wrap table').forEach(t=>renderTabla(t,reset));
}

buscador?.addEventListener('input',()=>refrescarTablas(true));
filtroCategoriaProducto?.addEventListener('change',()=>renderTabla(document.getElementById('tablaProductos'),true));
filtroStockProducto?.addEventListener('change',()=>renderTabla(document.getElementById('tablaProductos'),true));
filtroEstadoPedido?.addEventListener('change',()=>renderTabla(document.getElementById('tablaPedidos'),true));

document.addEventListener('keydown',e=>{
 if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='k'){
  e.preventDefault();
  buscador?.focus();
  buscador?.select();
 }
});

function mostrarPanel(id,actualizarHash=true){
 const destino=document.getElementById(id) || document.getElementById('inicio');
 panels.forEach(p=>p.classList.remove('active'));
 destino.classList.add('active');

 navLinks.forEach(a=>{
  if(!a.closest('.nav-submenu')) a.classList.toggle('active',a.getAttribute('href')==='#'+destino.id);
 });
 mobileLinks.forEach(a=>a.classList.toggle('active',a.getAttribute('href')==='#'+destino.id));
 actualizarMenuAgrupado(destino.id);

 if(topTitle) topTitle.textContent=nombresPanel[destino.id]||'ADN Import\'s';
 if(buscador) buscador.value='';
 if(actualizarHash) history.replaceState(null,'','#'+destino.id);

 window.scrollTo({top:0,behavior:'smooth'});
 cerrarMenu();
 setTimeout(()=>refrescarTablas(true),20);
}

document.querySelectorAll('a[href^="#"]').forEach(a=>{
 a.addEventListener('click',e=>{
  const id=a.getAttribute('href').substring(1);
  if(document.getElementById(id)){
   e.preventDefault();
   mostrarPanel(id,true);
   document.getElementById('notifyMenu')?.classList.remove('show');
  }
 });
});

menuBtn?.addEventListener('click',()=>{
 sidebar?.classList.toggle('open');
 overlay?.classList.toggle('show');
});
overlay?.addEventListener('click',cerrarMenu);

const notiBtn=document.getElementById('notiBtn');
const notifyMenu=document.getElementById('notifyMenu');
notiBtn?.addEventListener('click',e=>{
 e.stopPropagation();
 notifyMenu?.classList.toggle('show');
});
document.addEventListener('click',e=>{
 if(notifyMenu && !notifyMenu.contains(e.target) && e.target!==notiBtn) notifyMenu.classList.remove('show');
});

document.querySelectorAll('.status-pill').forEach(el=>{
 const t=el.textContent.toLowerCase().trim();
 if(['activo','pagado','completado','entregado','aprobada','registrado','entrada'].includes(t)) el.classList.add('success');
 else if(['pendiente','procesando','enviado','salida'].includes(t)) el.classList.add('warning');
 else if(['cancelado','rechazado','bloqueado','agotado'].includes(t)) el.classList.add('danger');
 else el.classList.add('info');
});

function exportarTabla(id,nombre){
 const tabla=document.getElementById(id);
 if(!tabla) return;

 const cabecera=[...tabla.querySelectorAll('thead tr')];
 const datos=[...tabla.querySelectorAll('tbody tr')].filter(f=>!f.querySelector('.empty-cell') && filaCoincide(f,tabla));
 const filas=[...cabecera,...datos];

 const csv=filas.map(f=>[...f.querySelectorAll('th,td')].map(celda=>{
  let texto=celda.innerText.replace(/"/g,'""').replace(/\n/g,' ').trim();
  return '"'+texto+'"';
 }).join(',')).join('\n');

 const blob=new Blob(['\ufeff'+csv],{type:'text/csv;charset=utf-8;'});
 const url=URL.createObjectURL(blob);
 const a=document.createElement('a');
 a.href=url;
 a.download=nombre;
 document.body.appendChild(a);
 a.click();
 a.remove();
 URL.revokeObjectURL(url);
}

function escaparHTML(valor){
 return String(valor??'')
  .replace(/&/g,'&amp;')
  .replace(/</g,'&lt;')
  .replace(/>/g,'&gt;')
  .replace(/"/g,'&quot;')
  .replace(/'/g,'&#039;');
}

function moneda(valor){
 return 'S/ '+Number(valor||0).toFixed(2);
}

function renderSerieBarras(id,datos,claseBarra='',esMoneda=false){
 const cont=document.getElementById(id);
 if(!cont || !Array.isArray(datos)) return;
 const max=Math.max(1,...datos.map(x=>Number(x.total||0)));
 cont.innerHTML=datos.map(d=>{
  const total=Number(d.total||0);
  const altura=total>0?Math.max(8,(total/max)*88):4;
  const tip=esMoneda?moneda(total):Math.round(total)+' pedido(s)';
  return '<div class="chart-item"><div class="bar '+claseBarra+'" style="height:'+altura.toFixed(1)+'%"><div class="bar-tip">'+escaparHTML(tip)+'</div></div><div class="day">'+escaparHTML(d.dia||'')+'</div></div>';
 }).join('');
}

function renderPedidosRecientes(datos){
 const body=document.getElementById('tablaPedidosRecientesBody');
 if(!body || !Array.isArray(datos)) return;
 if(!datos.length){
  body.innerHTML='<tr><td colspan="5" style="text-align:center;color:#718096">Todavía no hay pedidos.</td></tr>';
  return;
 }
 body.innerHTML=datos.map(p=>{
  const fecha=p.fecha_pedido?new Date(String(p.fecha_pedido).replace(' ','T')):null;
  const fechaTxt=fecha && !Number.isNaN(fecha.getTime())?fecha.toLocaleDateString('es-PE'):'-';
  return '<tr><td>#'+escaparHTML(p.id_pedido)+'</td><td>'+escaparHTML((p.nombres||'')+' '+(p.apellidos||''))+'</td><td>'+escaparHTML(fechaTxt)+'</td><td><span class="status-pill">'+escaparHTML(p.estado_pedido||'')+'</span></td><td class="price">'+escaparHTML(moneda(p.total))+'</td></tr>';
 }).join('');
 aplicarClasesEstado();
}

function renderTopProductos(datos){
 const cont=document.getElementById('listaTopProductos');
 if(!cont || !Array.isArray(datos)) return;
 if(!datos.length){
  cont.innerHTML='<p style="font-size:12px;color:#718096">No hay datos.</p>';
  return;
 }
 cont.innerHTML=datos.map((p,i)=>
  '<div class="top-product"><div class="rank">'+(i+1)+'</div><strong>'+escaparHTML(p.nombre_producto||'Producto')+'</strong><span>'+Number(p.vendidos||0)+' vendidos</span></div>'
 ).join('');
}

function renderStockAlertas(datos){
 const cont=document.getElementById('listaStockAlertas');
 if(!cont || !Array.isArray(datos)) return;
 if(!datos.length){
  cont.innerHTML='<div class="empty-state">✓ Todo el inventario está en buen nivel.</div>';
  return;
 }
 cont.innerHTML=datos.map(p=>{
  const stock=Number(p.stock||0);
  return '<a href="#inventario" class="compact-row"><span class="product-dot"></span><div><strong>'+escaparHTML(p.nombre_producto||'Producto')+'</strong><small>Stock actual · mínimo '+Number(p.stock_minimo||0)+'</small></div><b class="'+(stock<=2?'critical-text':'warning-text')+'">'+stock+'</b></a>';
 }).join('');
 enlazarNavegacionDinamica(cont);
}

function renderPagosRecientes(datos){
 const cont=document.getElementById('listaPagosRecientes');
 if(!cont || !Array.isArray(datos)) return;
 if(!datos.length){
  cont.innerHTML='<div class="empty-state">Aún no hay pagos registrados.</div>';
  return;
 }
 cont.innerHTML=datos.map(p=>
  '<a href="#pagos" class="compact-row"><span class="payment-dot">S/</span><div><strong>'+escaparHTML((p.nombres||'')+' '+(p.apellidos||''))+'</strong><small>'+escaparHTML(p.metodo_pago||'')+' · '+escaparHTML(p.estado_pago||'')+'</small></div><b>'+escaparHTML(moneda(p.monto))+'</b></a>'
 ).join('');
 enlazarNavegacionDinamica(cont);
}

function enlazarNavegacionDinamica(contenedor){
 contenedor?.querySelectorAll('a[href^="#"]').forEach(a=>{
  a.addEventListener('click',e=>{
   const id=a.getAttribute('href').substring(1);
   if(document.getElementById(id)){
    e.preventDefault();
    mostrarPanel(id,true);
   }
  });
 });
}

function aplicarClasesEstado(){
 document.querySelectorAll('.status-pill').forEach(el=>{
  el.classList.remove('success','warning','danger','info');
  const t=el.textContent.toLowerCase().trim();
  if(['activo','pagado','completado','entregado','aprobada','registrado','entrada'].includes(t)) el.classList.add('success');
  else if(['pendiente','procesando','enviado','salida'].includes(t)) el.classList.add('warning');
  else if(['cancelado','rechazado','bloqueado','agotado'].includes(t)) el.classList.add('danger');
  else el.classList.add('info');
 });
}

async function actualizarDashboardEnVivo(manual=false){
 const refreshBtn=document.getElementById('liveRefreshBtn');
 if(manual){
  refreshBtn?.classList.add('is-loading');
  if(refreshBtn) refreshBtn.textContent='↻ Actualizando...';
 }
 try{
  const respuesta=await fetch('dashboard_api.php?ts='+Date.now(),{cache:'no-store'});
  if(!respuesta.ok) throw new Error('HTTP '+respuesta.status);
  const data=await respuesta.json();
  if(!data.estado) throw new Error(data.mensaje||'API no disponible');

  const poner=(id,valor)=>{
   const el=document.getElementById(id);
   if(el) el.textContent=valor;
  };

  poner('metricProductos',data.productos);
  poner('metricClientes',data.usuarios);
  poner('metricPedidos',data.pedidos);
  poner('metricPedidosSub',Number(data.pedidos_pendientes||0)+' por atender');
  poner('metricVentas',moneda(data.ventas));
  poner('metricVentasSub','Mes: '+moneda(data.ventas_mes)+' · Hoy: '+moneda(data.ventas_hoy));
  poner('metricStockBajo',data.stock_bajo);
  poner('metricStockSub',Number(data.stock_critico||0)+' crítico(s)');
  poner('opsStockValue',data.stock_bajo);
  poner('opsProveedoresValue',data.proveedores);
  poner('opsComprasValue',moneda(data.compras));
  poner('pedidosPendientesBadge',Number(data.pedidos_pendientes||0)+' por atender');
  poner('notifStock',Number(data.stock_bajo||0)+' producto(s) requieren atención');
  poner('notifPedidos',Number(data.pedidos_pendientes||0)+' pendiente(s) o en proceso');
  poner('notifVentasHoy',moneda(data.ventas_hoy));
  poner('notifSoporte',Number(data.soporte_pendiente||0)+' consulta(s) abiertas');

  const totalAlertas=Number(data.stock_bajo||0)+Number(data.pedidos_pendientes||0)+Number(data.soporte_pendiente||0);
  const count=document.getElementById('notificationCount');
  if(count){
   count.textContent=String(totalAlertas);
   count.hidden=totalAlertas===0;
  }

  renderSerieBarras('chartVentas7',data.ventas_7_dias,'',true);
  renderSerieBarras('chartPedidos7',data.pedidos_7_dias,'order-bar',false);
  renderPedidosRecientes(data.ultimos_pedidos);
  renderTopProductos(data.productos_mas_vendidos);
  renderStockAlertas(data.alertas_stock);
  renderPagosRecientes(data.pagos_recientes);

  const estado=document.getElementById('liveStatus');
  if(estado){
   estado.textContent='● Datos en vivo · '+new Date().toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'});
   estado.style.opacity='1';
  }

  if(manual){
   const toast=document.getElementById('toast');
   if(toast){
    toast.textContent='Dashboard actualizado con datos reales.';
    toast.classList.add('show');
    setTimeout(()=>toast.classList.remove('show'),2200);
   }
  }
 }catch(e){
  const estado=document.getElementById('liveStatus');
  if(estado){
   estado.textContent='● Sin conexión en vivo';
   estado.style.opacity='.65';
  }
 }finally{
  if(manual){
   refreshBtn?.classList.remove('is-loading');
   if(refreshBtn) refreshBtn.textContent='↻ Actualizar';
  }
 }
}

document.getElementById('liveRefreshBtn')?.addEventListener('click',()=>actualizarDashboardEnVivo(true));

actualizarDashboardEnVivo();
setInterval(()=>actualizarDashboardEnVivo(false),15000);

const inicial=location.hash ? location.hash.substring(1) : 'inicio';
mostrarPanel(inicial,false);
</script>
</body>
</html>