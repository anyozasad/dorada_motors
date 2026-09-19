<?php
require_once "conexion.php";
header("Content-Type: text/html; charset=UTF-8");

function h($valor) {
    return htmlspecialchars((string)$valor, ENT_QUOTES, "UTF-8");
}

function redir($msg, $tipo = "ok", $ancla = "inicio") {
    header("Location: dashboard.php?msg=" . urlencode($msg) . "&tipo=" . urlencode($tipo) . "#" . $ancla);
    exit;
}

$mensaje = $_GET["msg"] ?? "";
$tipoMensaje = $_GET["tipo"] ?? "ok";

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    try {
        /* ================= PRODUCTOS ================= */
        if (isset($_POST["registrar_producto"])) {
            $idCategoria = (int)($_POST["id_categoria"] ?? 0);
            $idMarca = (int)($_POST["id_marca"] ?? 0);
            $nombre = trim($_POST["nombre_producto"] ?? "");
            $descripcion = trim($_POST["descripcion"] ?? "");
            $precio = (float)($_POST["precio"] ?? 0);
            $stock = (int)($_POST["stock"] ?? 0);
            $imagen = trim($_POST["imagen_url"] ?? "");

            if ($idCategoria <= 0 || $idMarca <= 0 || $nombre === "") {
                redir("Completa los datos obligatorios del producto", "error", "gestion-productos");
            }

            $stmt = $conexion->prepare("
                INSERT INTO producto
                (id_categoria, id_marca, nombre_producto, descripcion, precio, stock, imagen_url)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ");
            $stmt->bind_param("iissdis", $idCategoria, $idMarca, $nombre, $descripcion, $precio, $stock, $imagen);
            $stmt->execute();
            redir("Producto registrado correctamente", "ok", "gestion-productos");
        }

        if (isset($_POST["actualizar_producto"])) {
            $idProducto = (int)($_POST["id_producto"] ?? 0);
            $idCategoria = (int)($_POST["id_categoria"] ?? 0);
            $idMarca = (int)($_POST["id_marca"] ?? 0);
            $nombre = trim($_POST["nombre_producto"] ?? "");
            $descripcion = trim($_POST["descripcion"] ?? "");
            $precio = (float)($_POST["precio"] ?? 0);
            $stock = (int)($_POST["stock"] ?? 0);
            $imagen = trim($_POST["imagen_url"] ?? "");

            $stmt = $conexion->prepare("
                UPDATE producto
                SET id_categoria=?, id_marca=?, nombre_producto=?, descripcion=?, precio=?, stock=?, imagen_url=?
                WHERE id_producto=?
            ");
            $stmt->bind_param("iissdisi", $idCategoria, $idMarca, $nombre, $descripcion, $precio, $stock, $imagen, $idProducto);
            $stmt->execute();
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

            foreach (["favorito", "carrito_favorito", "detalle_carrito", "movimiento_stock"] as $tabla) {
                $stmt = $conexion->prepare("DELETE FROM $tabla WHERE id_producto=?");
                $stmt->bind_param("i", $idProducto);
                $stmt->execute();
            }

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
            $correo = trim($_POST["correo"] ?? "");
            $telefono = trim($_POST["telefono"] ?? "");
            $contrasenaPlano = $_POST["contrasena"] ?? "";

            if ($nombres === "" || $correo === "" || $contrasenaPlano === "") {
                redir("Completa nombres, correo y contraseña", "error", "usuarios");
            }

            $contrasena = password_hash($contrasenaPlano, PASSWORD_DEFAULT);

            $stmt = $conexion->prepare("
                INSERT INTO usuario (nombres, apellidos, correo, contrasena, telefono)
                VALUES (?, ?, ?, ?, ?)
            ");
            $stmt->bind_param("sssss", $nombres, $apellidos, $correo, $contrasena, $telefono);
            $stmt->execute();
            redir("Usuario registrado correctamente", "ok", "usuarios");
        }

        /* ================= PEDIDOS ================= */
        if (isset($_POST["actualizar_estado_pedido"])) {
            $idPedido = (int)($_POST["id_pedido"] ?? 0);
            $estado = trim($_POST["estado_pedido"] ?? "Pendiente");

            $stmt = $conexion->prepare("UPDATE pedido SET estado_pedido=? WHERE id_pedido=?");
            $stmt->bind_param("si", $estado, $idPedido);
            $stmt->execute();
            redir("Estado del pedido actualizado", "ok", "pedidos");
        }

        /* ================= PAGOS ================= */
        if (isset($_POST["actualizar_estado_pago"])) {
            $idPago = (int)($_POST["id_pago"] ?? 0);
            $estado = trim($_POST["estado_pago"] ?? "Pendiente");

            $stmt = $conexion->prepare("UPDATE pago SET estado_pago=? WHERE id_pago=?");
            $stmt->bind_param("si", $estado, $idPago);
            $stmt->execute();
            redir("Estado del pago actualizado", "ok", "pagos");
        }

        /* ================= FAVORITOS ================= */
        if (isset($_POST["eliminar_favorito"])) {
            $idFavorito = (int)($_POST["id_favorito"] ?? 0);
            $stmt = $conexion->prepare("DELETE FROM favorito WHERE id_favorito=?");
            $stmt->bind_param("i", $idFavorito);
            $stmt->execute();
            redir("Favorito eliminado", "ok", "favoritos");
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
                INSERT INTO movimiento_stock (id_producto, tipo_movimiento, cantidad, motivo, fecha_movimiento)
                VALUES (?, ?, ?, ?, NOW())
            ");
            $stmt->bind_param("isis", $idProducto, $tipo, $cantidad, $motivo);
            $stmt->execute();

            $conexion->commit();
            redir("Movimiento de stock registrado correctamente", "ok", "inventario");
        }

        /* ================= COMPRAS ================= */
        if (isset($_POST["registrar_compra"])) {
            $idProveedor = (int)($_POST["id_proveedor_compra"] ?? 0);
            $idProducto = (int)($_POST["id_producto_compra"] ?? 0);
            $cantidad = (int)($_POST["cantidad_compra"] ?? 0);
            $precioCompra = (float)($_POST["precio_compra"] ?? 0);

            if ($idProveedor <= 0 || $idProducto <= 0 || $cantidad <= 0 || $precioCompra < 0) {
                redir("Completa correctamente los datos de la compra", "error", "compras");
            }

            $subtotal = $cantidad * $precioCompra;
            $conexion->begin_transaction();

            $stmt = $conexion->prepare("
                INSERT INTO compra (id_proveedor, fecha_compra, total, estado)
                VALUES (?, NOW(), ?, 'Registrado')
            ");
            $stmt->bind_param("id", $idProveedor, $subtotal);
            $stmt->execute();
            $idCompra = $conexion->insert_id;

            $stmt = $conexion->prepare("
                INSERT INTO detalle_compra (id_compra, id_producto, cantidad, precio_compra, subtotal)
                VALUES (?, ?, ?, ?, ?)
            ");
            $stmt->bind_param("iiidd", $idCompra, $idProducto, $cantidad, $precioCompra, $subtotal);
            $stmt->execute();

            $stmt = $conexion->prepare("UPDATE producto SET stock=stock+? WHERE id_producto=?");
            $stmt->bind_param("ii", $cantidad, $idProducto);
            $stmt->execute();

            $motivo = "Compra #" . $idCompra;
            $tipoEntrada = "Entrada";
            $stmt = $conexion->prepare("
                INSERT INTO movimiento_stock (id_producto, tipo_movimiento, cantidad, motivo, fecha_movimiento)
                VALUES (?, ?, ?, ?, NOW())
            ");
            $stmt->bind_param("isis", $idProducto, $tipoEntrada, $cantidad, $motivo);
            $stmt->execute();

            $conexion->commit();
            redir("Compra registrada y stock actualizado", "ok", "compras");
        }

        /* ================= COMPROBANTES ================= */
        if (isset($_POST["registrar_comprobante"])) {
            $idPedido = (int)($_POST["id_pedido_comprobante"] ?? 0);
            $tipo = trim($_POST["tipo_comprobante"] ?? "Boleta");
            $numero = trim($_POST["numero_comprobante"] ?? "");

            if ($idPedido <= 0 || $numero === "") {
                redir("Selecciona un pedido e ingresa el número de comprobante", "error", "comprobantes");
            }

            $stmt = $conexion->prepare("SELECT total FROM pedido WHERE id_pedido=?");
            $stmt->bind_param("i", $idPedido);
            $stmt->execute();
            $pedidoComprobante = $stmt->get_result()->fetch_assoc();

            if (!$pedidoComprobante) redir("Pedido no encontrado", "error", "comprobantes");

            $total = (float)$pedidoComprobante["total"];
            $subtotal = round($total / 1.18, 2);
            $igv = round($total - $subtotal, 2);

            $stmt = $conexion->prepare("
                INSERT INTO comprobante
                (id_pedido, tipo_comprobante, numero_comprobante, fecha_emision, subtotal, igv, total)
                VALUES (?, ?, ?, NOW(), ?, ?, ?)
            ");
            $stmt->bind_param("issddd", $idPedido, $tipo, $numero, $subtotal, $igv, $total);
            $stmt->execute();
            redir("Comprobante registrado correctamente", "ok", "comprobantes");
        }

        if (isset($_POST["eliminar_comprobante"])) {
            $id = (int)($_POST["id_comprobante"] ?? 0);
            $stmt = $conexion->prepare("DELETE FROM comprobante WHERE id_comprobante=?");
            $stmt->bind_param("i", $id);
            $stmt->execute();
            redir("Comprobante eliminado", "ok", "comprobantes");
        }

    } catch (Throwable $e) {
        $mensaje = "Error: " . $e->getMessage();
        $tipoMensaje = "error";
    }
}

/* ================= MÉTRICAS ================= */
$totalProductos = (int)$conexion->query("SELECT COUNT(*) AS total FROM producto")->fetch_assoc()["total"];
$totalUsuarios = (int)$conexion->query("SELECT COUNT(*) AS total FROM usuario")->fetch_assoc()["total"];
$totalPedidos = (int)$conexion->query("SELECT COUNT(*) AS total FROM pedido")->fetch_assoc()["total"];
$totalVentas = (float)$conexion->query("SELECT COALESCE(SUM(total),0) AS total FROM pedido")->fetch_assoc()["total"];
$totalPagos = (float)$conexion->query("SELECT COALESCE(SUM(monto),0) AS total FROM pago WHERE estado_pago='Pagado'")->fetch_assoc()["total"];
$totalCategorias = (int)$conexion->query("SELECT COUNT(*) AS total FROM categoria")->fetch_assoc()["total"];
$totalMarcas = (int)$conexion->query("SELECT COUNT(*) AS total FROM marca")->fetch_assoc()["total"];

$totalProveedores = (int)$conexion->query("SELECT COUNT(*) AS total FROM proveedor")->fetch_assoc()["total"];
$totalCompras = (float)$conexion->query("SELECT COALESCE(SUM(total),0) AS total FROM compra")->fetch_assoc()["total"];
$stockBajo = (int)$conexion->query("SELECT COUNT(*) AS total FROM producto WHERE stock <= 5")->fetch_assoc()["total"];
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
")->fetch_assoc()["total"];
$stockCritico = (int)$conexion->query("
    SELECT COUNT(*) AS total
    FROM producto
    WHERE stock <= 2
")->fetch_assoc()["total"];

/* ================= VENTAS 7 DÍAS ================= */
$ventasConsulta = $conexion->query("
    SELECT DATE(fecha_pedido) AS fecha, COALESCE(SUM(total),0) AS total
    FROM pedido
    WHERE DATE(fecha_pedido) >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
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
}

$pedidosConsulta = $conexion->query("
    SELECT DATE(fecha_pedido) AS fecha, COUNT(*) AS total
    FROM pedido
    WHERE DATE(fecha_pedido) >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
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
    SELECT id_usuario,nombres,apellidos,correo,telefono
    FROM usuario
    ORDER BY id_usuario DESC
")->fetch_all(MYSQLI_ASSOC);

$pedidos = $conexion->query("
    SELECT p.*, u.nombres,u.apellidos
    FROM pedido p
    INNER JOIN usuario u ON p.id_usuario=u.id_usuario
    ORDER BY p.id_pedido DESC
")->fetch_all(MYSQLI_ASSOC);

$pagos = $conexion->query("
    SELECT pg.*, p.id_usuario, u.nombres, u.apellidos
    FROM pago pg
    INNER JOIN pedido p ON pg.id_pedido=p.id_pedido
    INNER JOIN usuario u ON p.id_usuario=u.id_usuario
    ORDER BY pg.id_pago DESC
")->fetch_all(MYSQLI_ASSOC);

$favoritos = $conexion->query("
    SELECT f.id_favorito,f.fecha_registro,u.nombres,u.apellidos,p.nombre_producto,p.precio
    FROM favorito f
    INNER JOIN usuario u ON f.id_usuario=u.id_usuario
    INNER JOIN producto p ON f.id_producto=p.id_producto
    ORDER BY f.id_favorito DESC
")->fetch_all(MYSQLI_ASSOC);


$proveedores = $conexion->query("
    SELECT * FROM proveedor
    ORDER BY id_proveedor DESC
")->fetch_all(MYSQLI_ASSOC);

$compras = $conexion->query("
    SELECT c.id_compra,c.fecha_compra,c.total,c.estado,p.razon_social
    FROM compra c
    INNER JOIN proveedor p ON c.id_proveedor=p.id_proveedor
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
    SELECT id_producto,nombre_producto,stock,precio
    FROM producto
    WHERE stock <= 5
    ORDER BY stock ASC,nombre_producto ASC
    LIMIT 8
")->fetch_all(MYSQLI_ASSOC);

$masVendidos = $conexion->query("
    SELECT p.nombre_producto, COALESCE(SUM(dp.cantidad),0) AS vendidos
    FROM producto p
    LEFT JOIN detalle_pedido dp ON p.id_producto=dp.id_producto
    GROUP BY p.id_producto,p.nombre_producto
    ORDER BY vendidos DESC,p.nombre_producto ASC
    LIMIT 5
")->fetch_all(MYSQLI_ASSOC);

$productoEditar = null;
if (isset($_GET["editar"])) {
    $idEditar = (int)$_GET["editar"];
    $stmt = $conexion->prepare("SELECT * FROM producto WHERE id_producto=?");
    $stmt->bind_param("i",$idEditar);
    $stmt->execute();
    $productoEditar = $stmt->get_result()->fetch_assoc();
}

$fechaHoy = date("d/m/Y");
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
.hero-brand{display:flex;align-items:center;gap:12px}.hero-brand img{width:100px;height:100px;object-fit:cover;border-radius:18px;border:1px solid rgba(255,255,255,.12);box-shadow:0 12px 30px rgba(0,0,0,.28)}.hero-brand small{display:none}
.metric small{display:block;margin-top:3px;font-size:9px;color:var(--muted);font-weight:700}.metric-icon.red{background:#ffe9e6;color:#d43122}.metric-icon.orange{background:#fff0e5;color:#ef6200}
.home-tools{display:grid;grid-template-columns:1.05fr 1fr 1fr;gap:16px}.compact-list{display:flex;flex-direction:column}.compact-row{display:grid;grid-template-columns:34px minmax(0,1fr) auto;align-items:center;gap:9px;padding:10px 3px;border-bottom:1px solid var(--border)}.compact-row:hover{background:#fafbfc}.compact-row strong{display:block;font-size:10px}.compact-row small{display:block;margin-top:2px;font-size:9px;color:var(--muted)}.compact-row>b{font-size:10px}.product-dot{width:28px;height:28px;border-radius:9px;background:linear-gradient(135deg,#ff6a00,#c92b18)}.payment-dot{width:28px;height:28px;border-radius:9px;background:#e9f8f0;color:#168a5c;display:grid;place-items:center;font-size:9px;font-weight:900}.critical-text{color:#d53124}.warning-text{color:#c47d00}.empty-state{padding:18px;text-align:center;color:var(--muted);font-size:11px}
.section-actions{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.system-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px}.system-card{display:flex;align-items:flex-start;gap:11px;padding:16px;border:1px solid var(--border);border-radius:14px;background:#fafbfc}.system-card small{display:block;font-size:9px;color:var(--muted);font-weight:900;letter-spacing:.5px}.system-card strong{display:block;margin-top:3px;font-size:13px}.system-card p{margin:3px 0 0;font-size:10px;color:var(--muted);line-height:1.35}.system-icon{width:34px;height:34px;border-radius:10px;display:grid;place-items:center;font-weight:900;flex:0 0 auto}.system-icon.ok{background:#e7f7ee;color:#13885a}.system-icon.warn{background:#fff0e4;color:#e05e00}.help-card{display:flex;align-items:center;justify-content:space-between;gap:16px;margin-top:14px;padding:16px;border-radius:14px;background:linear-gradient(135deg,#fff5ed,#fff);border:1px solid #ffd7be}.help-card strong{font-size:13px}.help-card p{margin:4px 0 0;color:var(--muted);font-size:10px}
.order-bar{background:linear-gradient(180deg,#ff6a00,#c92b18)}

.brand-mark{width:38px;height:38px;border:2px solid var(--gold);border-radius:12px 4px;display:grid;place-items:center;color:var(--gold);font-weight:900;transform:rotate(45deg)}
.brand-mark span{transform:rotate(-45deg)}
.brand-title{font-size:18px;font-weight:900}.brand-title b{color:var(--gold)}
.brand-sub{font-size:10px;color:#aebed0;margin-top:3px}
.nav{display:flex;flex-direction:column;gap:5px}
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
.section-intro{display:flex;justify-content:space-between;align-items:center;gap:14px;margin-bottom:14px;padding:14px 16px;background:linear-gradient(135deg,#102d50,#18436f);border-radius:14px;color:#fff}
.section-intro h2{margin:0 0 4px;font-size:18px}.section-intro p{margin:0;color:#c8d7e7;font-size:11px}
.section-intro .badge{background:rgba(255,255,255,.12);color:#f5d57c}
.two-col{display:grid;grid-template-columns:minmax(300px,.72fr) minmax(0,1.28fr);gap:14px}
.kpi-inline{display:flex;gap:8px;flex-wrap:wrap}.pill{padding:6px 9px;border-radius:999px;background:#f4f7fb;border:1px solid var(--border);font-size:10px;font-weight:800;color:var(--muted)}

.page-panel{display:none;animation:panelIn .18s ease}
.page-panel.active{display:block}
@keyframes panelIn{from{opacity:.35;transform:translateY(4px)}to{opacity:1;transform:none}}
.page-panel.card{margin-bottom:0}
.nav a.active{box-shadow:0 6px 16px rgba(215,166,42,.16)}
.metric{transition:.18s}.metric:hover{transform:translateY(-2px);box-shadow:0 12px 28px rgba(15,39,70,.10)}
.quick span{line-height:1.2}
.section-title{position:sticky;top:70px;background:#fff;z-index:8;padding:4px 0 10px}

@media(max-width:1180px){.metrics{grid-template-columns:repeat(3,1fr)}.grid-main,.grid-bottom,.two-col{grid-template-columns:1fr}.ops-strip{grid-template-columns:1fr 1fr}.quick-actions{grid-template-columns:repeat(3,1fr)}.home-tools{grid-template-columns:1fr 1fr}.system-grid{grid-template-columns:1fr 1fr}}
@media(max-width:900px){.home-tools{grid-template-columns:1fr}.quick-actions{grid-template-columns:repeat(3,1fr)}}
@media(max-width:820px){
 body{padding-bottom:74px}.app{grid-template-columns:1fr}.sidebar{position:fixed;left:-260px;width:235px;transition:.25s}.sidebar.open{left:0}.overlay.show{display:block;position:fixed;inset:0;background:rgba(0,0,0,.35);z-index:45}
 .topbar{height:64px;padding:0 14px}.mobile-menu{display:grid;place-items:center}.mobile-brand-logo{display:block}.top-title{display:none}.search{display:none}.admin div:last-child{display:none}.content{padding:15px}.heading{align-items:flex-start}.heading h1{font-size:22px}.date-chip{display:none}
 .brand-hero{grid-template-columns:1fr;padding:18px}.hero-brand{position:absolute;opacity:.13;right:24px}.hero-brand img{width:100px;height:100px}.metrics{grid-template-columns:repeat(2,1fr);gap:10px}.metric{padding:13px;gap:9px}.metric-icon{width:42px;height:42px}.metric-value{font-size:19px}.grid-main,.grid-bottom{gap:12px}.chart{height:180px;gap:6px}
 .card{padding:14px}.form-grid{grid-template-columns:1fr}.field.full,.form-actions{grid-column:auto}
 .mobile-bottom{display:grid;grid-template-columns:repeat(4,1fr);position:fixed;left:0;right:0;bottom:0;height:68px;background:#fff;border-top:1px solid var(--border);z-index:40;box-shadow:0 -8px 22px rgba(15,39,70,.08)}
 .mobile-bottom a{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;color:var(--muted);font-size:9px;font-weight:800}.mobile-bottom a.active{color:#a7780a}
}
@media(max-width:480px){.ops-strip{grid-template-columns:1fr}.quick-actions{grid-template-columns:1fr 1fr}.system-grid{grid-template-columns:1fr}.metrics{grid-template-columns:1fr 1fr}.metric-icon{width:38px;height:38px}.metric-value{font-size:17px}.metric-label{font-size:10px}.quick-actions{grid-template-columns:repeat(2,1fr)}.stats-row{grid-template-columns:1fr}}
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
 <nav class="nav" id="nav">
  <a href="#inicio" class="active"><span class="nav-icon">⌂</span>Dashboard</a>
  <a href="#gestion-productos"><span class="nav-icon">◇</span>Productos</a>
  <a href="#inventario"><span class="nav-icon">▤</span>Inventario</a>
  <a href="#proveedores"><span class="nav-icon">▣</span>Proveedores</a>
  <a href="#compras"><span class="nav-icon">＋</span>Compras</a>
  <a href="#categorias"><span class="nav-icon">▦</span>Categorías</a>
  <a href="#marcas"><span class="nav-icon">◆</span>Marcas</a>
  <a href="#usuarios"><span class="nav-icon">♙</span>Usuarios</a>
  <a href="#pedidos"><span class="nav-icon">🛒</span>Pedidos</a>
  <a href="#pagos"><span class="nav-icon">▣</span>Pagos</a>
  <a href="#comprobantes"><span class="nav-icon">▧</span>Comprobantes</a>
  <a href="#favoritos"><span class="nav-icon">♥</span>Favoritos</a>
  <a href="#reportes"><span class="nav-icon">▥</span>Reportes</a>
  <a href="#configuracion"><span class="nav-icon">⚙</span>Configuración</a>
 </nav>
 <div class="motto">“Potencia, Calidad y Confianza en Cada Repuesto”</div>
 <div class="sidebar-bottom"><strong>ADN Import's</strong>Dorada Motors · Panel v2.0<br>PHP · MySQL · Flutter</div>
</aside>

<main class="main">
<header class="topbar">
 <button class="mobile-menu" id="menuBtn" aria-label="Abrir menú">☰</button>
 <img src="logo_adn_imports.png" alt="ADN" class="mobile-brand-logo">
 <div class="top-title" id="topTitle">Dashboard</div>
 <div class="search"><span>⌕</span><input id="buscador" type="search" placeholder="Buscar en la sección actual..."><kbd>Ctrl K</kbd></div>
 <div class="top-actions">
  <div class="notify-wrap">
   <button class="icon-btn" id="notiBtn" title="Notificaciones">🔔<?php if($stockBajo+$pedidosPendientes>0): ?><span class="notification-count"><?= $stockBajo+$pedidosPendientes ?></span><?php endif; ?></button>
   <div class="notify-menu" id="notifyMenu">
    <div class="notify-head"><strong>Notificaciones</strong><span>En tiempo real</span></div>
    <a href="#inventario"><b>⚠ Stock bajo</b><small><?= $stockBajo ?> producto(s) requieren atención</small></a>
    <a href="#pedidos"><b>🛒 Pedidos por atender</b><small><?= $pedidosPendientes ?> pendiente(s) o en proceso</small></a>
    <a href="#reportes"><b>💰 Ventas de hoy</b><small>S/ <?= number_format($ventasHoy,2) ?></small></a>
   </div>
  </div>
  <a class="admin" href="#configuracion" title="Configuración"><div class="avatar">AI</div><div><strong>Administrador</strong><small>ADN Import's</small></div></a>
 </div>
</header>

<div class="content">
<?php if ($mensaje !== ""): ?><div class="alert <?= $tipoMensaje === "error" ? "error" : "ok" ?>"><?= h($mensaje) ?></div><?php endif; ?>

<div id="inicio" class="page-panel active">
<section class="brand-hero">
 <div class="hero-copy">
  <div class="eyebrow">Panel de administración</div>
  <h1>¡Bienvenido, Administrador!</h1>
  <p>Gestiona ventas, productos, stock, pedidos y proveedores desde un solo lugar.</p>
  <div class="hero-tags">
   <span>● PHP conectado</span><span>● MySQL activo</span><span>● API lista para Flutter</span>
  </div>
 </div>
 <div class="hero-brand">
  <img src="logo_adn_imports.png" alt="Logo ADN Import's">
  <small><?= h($fechaHoy) ?></small>
 </div>
</section>

<section class="metrics">
 <a class="metric" href="#gestion-productos"><div class="metric-icon blue">📦</div><div><div class="metric-label">Productos</div><div class="metric-value"><?= $totalProductos ?></div><small>Catálogo activo</small></div></a>
 <a class="metric" href="#usuarios"><div class="metric-icon gold">👥</div><div><div class="metric-label">Usuarios</div><div class="metric-value"><?= $totalUsuarios ?></div><small>Clientes registrados</small></div></a>
 <a class="metric" href="#pedidos"><div class="metric-icon purple">🛒</div><div><div class="metric-label">Pedidos</div><div class="metric-value"><?= $totalPedidos ?></div><small><?= $pedidosPendientes ?> por atender</small></div></a>
 <a class="metric" href="#reportes"><div class="metric-icon green">S/</div><div><div class="metric-label">Ventas</div><div class="metric-value">S/ <?= number_format($totalVentas,2) ?></div><small>Hoy: S/ <?= number_format($ventasHoy,2) ?></small></div></a>
 <a class="metric" href="#inventario"><div class="metric-icon red">!</div><div><div class="metric-label">Stock bajo</div><div class="metric-value"><?= $stockBajo ?></div><small><?= $stockCritico ?> crítico(s)</small></div></a>
 <a class="metric" href="#proveedores"><div class="metric-icon orange">🚚</div><div><div class="metric-label">Proveedores</div><div class="metric-value"><?= $totalProveedores ?></div><small>Abastecimiento</small></div></a>
</section>

<section class="ops-strip">
 <a href="#inventario" class="ops-card"><span class="ops-icon warn">!</span><div><small>STOCK BAJO</small><strong><?= $stockBajo ?></strong><p>Productos con 5 unidades o menos</p></div><b>→</b></a>
 <a href="#proveedores" class="ops-card"><span class="ops-icon blue2">P</span><div><small>PROVEEDORES</small><strong><?= $totalProveedores ?></strong><p>Proveedores registrados</p></div><b>→</b></a>
 <a href="#compras" class="ops-card"><span class="ops-icon green2">S/</span><div><small>COMPRAS</small><strong>S/ <?= number_format($totalCompras,2) ?></strong><p>Total de abastecimiento</p></div><b>→</b></a>
</section>

<section class="grid-main">
 <article class="card">
  <div class="card-head"><h2>Ventas de los últimos 7 días</h2><span class="badge">Últimos 7 días</span></div>
  <div class="chart">
   <?php foreach($ventas7 as $dato): $altura=$dato["total"]>0?max(8,($dato["total"]/$maxVenta)*88):4; ?>
   <div class="chart-item"><div class="bar" style="height:<?= number_format($altura,1,'.','') ?>%"><div class="bar-tip">S/ <?= number_format($dato["total"],2) ?></div></div><div class="day"><?= h($dato["dia"]) ?></div></div>
   <?php endforeach; ?>
  </div>
 </article>
 <article class="card">
  <div class="card-head"><h2>Tendencia de pedidos</h2><span class="badge"><?= $pedidosPendientes ?> por atender</span></div>
  <div class="chart line-bars">
   <?php foreach($pedidos7 as $dato): $altura=$dato["total"]>0?max(8,($dato["total"]/$maxPedidos)*88):4; ?>
   <div class="chart-item"><div class="bar order-bar" style="height:<?= number_format($altura,1,'.','') ?>%"><div class="bar-tip"><?= (int)$dato["total"] ?> pedido(s)</div></div><div class="day"><?= h($dato["dia"]) ?></div></div>
   <?php endforeach; ?>
  </div>
 </article>
</section>

<section class="grid-bottom">
 <article class="card">
  <div class="card-head"><h2>Pedidos recientes</h2><a href="#pedidos">Ver todos →</a></div>
  <div class="table-wrap"><table><thead><tr><th>#</th><th>Cliente</th><th>Fecha</th><th>Estado</th><th>Total</th></tr></thead><tbody>
   <?php if(!$pedidos): ?><tr><td colspan="5" style="text-align:center;color:#718096">Todavía no hay pedidos.</td></tr><?php else: foreach(array_slice($pedidos,0,5) as $p): ?>
   <tr><td>#<?= h($p["id_pedido"]) ?></td><td><?= h($p["nombres"]." ".$p["apellidos"]) ?></td><td><?= h(date("d/m/Y",strtotime($p["fecha_pedido"]))) ?></td><td><?= h($p["estado_pedido"]) ?></td><td class="price">S/ <?= number_format((float)$p["total"],2) ?></td></tr>
   <?php endforeach; endif; ?>
  </tbody></table></div>
 </article>
 <article class="card">
  <div class="card-head"><h2>Productos más vendidos</h2><a href="#gestion-productos">Ver productos →</a></div>
  <div class="top-list">
   <?php if(!$masVendidos): ?><p style="font-size:12px;color:#718096">No hay datos.</p><?php else: foreach($masVendidos as $i=>$prod): ?>
   <div class="top-product"><div class="rank"><?= $i+1 ?></div><strong><?= h($prod["nombre_producto"]) ?></strong><span><?= (int)$prod["vendidos"] ?> vendidos</span></div>
   <?php endforeach; endif; ?>
  </div>
 </article>
</section>

<section class="home-tools">
 <article class="card">
  <div class="card-head"><h2>Acciones rápidas</h2><span class="badge">1 clic</span></div>
  <div class="quick-actions">
   <a class="quick blue" href="#gestion-productos">📦<span>Nuevo producto</span></a>
   <a class="quick gold" href="#compras">＋<span>Registrar compra</span></a>
   <a class="quick purple" href="#pedidos">🛒<span>Ver pedidos</span></a>
   <a class="quick green" href="#inventario">↕<span>Mover stock</span></a>
   <a class="quick gold" href="#proveedores">🚚<span>Proveedor</span></a>
   <a class="quick blue" href="#comprobantes">🧾<span>Comprobante</span></a>
  </div>
 </article>

 <article class="card">
  <div class="card-head"><h2>Stock bajo / alertas</h2><a href="#inventario">Ver inventario →</a></div>
  <div class="compact-list">
   <?php if(!$productosStockBajo): ?><div class="empty-state">✓ Todo el inventario está en buen nivel.</div><?php else: foreach(array_slice($productosStockBajo,0,5) as $sb): ?>
    <a href="#inventario" class="compact-row"><span class="product-dot"></span><div><strong><?= h($sb["nombre_producto"]) ?></strong><small>Stock actual</small></div><b class="<?= (int)$sb["stock"]<=2?"critical-text":"warning-text" ?>"><?= (int)$sb["stock"] ?></b></a>
   <?php endforeach; endif; ?>
  </div>
 </article>

 <article class="card">
  <div class="card-head"><h2>Últimos pagos</h2><a href="#pagos">Ver todos →</a></div>
  <div class="compact-list">
   <?php if(!$pagos): ?><div class="empty-state">Aún no hay pagos registrados.</div><?php else: foreach(array_slice($pagos,0,5) as $pg): ?>
    <a href="#pagos" class="compact-row"><span class="payment-dot">S/</span><div><strong><?= h($pg["nombres"]." ".$pg["apellidos"]) ?></strong><small><?= h($pg["metodo_pago"]) ?> · <?= h($pg["estado_pago"]) ?></small></div><b>S/ <?= number_format((float)$pg["monto"],2) ?></b></a>
   <?php endforeach; endif; ?>
  </div>
 </article>
</section>
</div>

<section id="gestion-productos" class="card page-panel">
 <div class="section-title"><div><div class="eyebrow">CRUD</div><h2><?= $productoEditar ? "Editar producto" : "Gestión de productos" ?></h2></div><div class="section-actions"><button type="button" class="btn btn-light" onclick="exportarTabla('tablaProductos','productos_adn.csv')">Exportar CSV</button><span class="badge">CREATE · READ · UPDATE · DELETE</span></div></div>
 <form method="POST" class="form-grid">
  <?php if($productoEditar): ?><input type="hidden" name="id_producto" value="<?= h($productoEditar["id_producto"]) ?>"><?php endif; ?>
  <div class="field"><label>NOMBRE</label><input type="text" name="nombre_producto" required value="<?= h($productoEditar["nombre_producto"]??"") ?>"></div>
  <div class="field"><label>CATEGORÍA</label><select name="id_categoria" required><option value="">Seleccione</option><?php foreach($categorias as $c): ?><option value="<?= h($c["id_categoria"]) ?>" <?= $productoEditar && (int)$productoEditar["id_categoria"]===(int)$c["id_categoria"]?"selected":"" ?>><?= h($c["nombre_categoria"]) ?></option><?php endforeach; ?></select></div>
  <div class="field"><label>MARCA</label><select name="id_marca" required><option value="">Seleccione</option><?php foreach($marcas as $m): ?><option value="<?= h($m["id_marca"]) ?>" <?= $productoEditar && (int)$productoEditar["id_marca"]===(int)$m["id_marca"]?"selected":"" ?>><?= h($m["nombre_marca"]) ?></option><?php endforeach; ?></select></div>
  <div class="field"><label>PRECIO</label><input type="number" step="0.01" min="0" name="precio" required value="<?= h($productoEditar["precio"]??"") ?>"></div>
  <div class="field"><label>STOCK</label><input type="number" min="0" name="stock" required value="<?= h($productoEditar["stock"]??"") ?>"></div>
  <div class="field"><label>IMAGEN</label><input type="text" name="imagen_url" value="<?= h($productoEditar["imagen_url"]??"") ?>" placeholder="producto.png"></div>
  <div class="field full"><label>DESCRIPCIÓN</label><textarea name="descripcion"><?= h($productoEditar["descripcion"]??"") ?></textarea></div>
  <div class="form-actions"><?php if($productoEditar): ?><button class="btn btn-gold" name="actualizar_producto">Guardar cambios</button><a class="btn btn-light" href="dashboard.php#gestion-productos">Cancelar</a><?php else: ?><button class="btn btn-primary" name="registrar_producto">+ Agregar producto</button><?php endif; ?></div>
 </form>
 <div class="table-wrap"><table id="tablaProductos"><thead><tr><th>ID</th><th>Producto</th><th>Categoría</th><th>Marca</th><th>Precio</th><th>Stock</th><th>Acciones</th></tr></thead><tbody>
 <?php foreach($productos as $p): $s=(int)$p["stock"];$sc=$s<=0?"zero":($s<=5?"low":"good"); ?>
  <tr data-search="<?= h(strtolower($p["nombre_producto"]." ".$p["nombre_categoria"]." ".$p["nombre_marca"])) ?>"><td>#P<?= str_pad((string)$p["id_producto"],3,"0",STR_PAD_LEFT) ?></td><td><strong><?= h($p["nombre_producto"]) ?></strong><br><span style="color:#718096;font-size:9px"><?= h($p["descripcion"]) ?></span></td><td><?= h($p["nombre_categoria"]) ?></td><td><?= h($p["nombre_marca"]) ?></td><td class="price">S/ <?= number_format((float)$p["precio"],2) ?></td><td><span class="stock <?= $sc ?>"><?= $s ?></span></td><td><div class="actions"><a class="action-btn edit" href="dashboard.php?editar=<?= h($p["id_producto"]) ?>#gestion-productos">✎</a><form method="POST" onsubmit="return confirm('¿Eliminar este producto?');"><input type="hidden" name="id_producto" value="<?= h($p["id_producto"]) ?>"><button class="action-btn delete" name="eliminar_producto">⌫</button></form></div></td></tr>
 <?php endforeach; ?>
 </tbody></table></div>
</section>

<section id="categorias" class="card page-panel">
 <div class="section-title"><h2>Categorías</h2><span class="badge"><?= $totalCategorias ?> registradas</span></div>
 <form method="POST" class="inline-form" style="margin-bottom:14px"><input type="text" name="nombre_categoria" placeholder="Nueva categoría" required><button class="btn btn-primary" name="registrar_categoria">+ Agregar categoría</button></form>
 <div class="table-wrap"><table><thead><tr><th>ID</th><th>Categoría</th><th>Acción</th></tr></thead><tbody>
 <?php foreach($categorias as $c): ?><tr><td><?= h($c["id_categoria"]) ?></td><td><?= h($c["nombre_categoria"]) ?></td><td><form method="POST" onsubmit="return confirm('¿Eliminar categoría?');"><input type="hidden" name="id_categoria" value="<?= h($c["id_categoria"]) ?>"><button class="btn btn-danger" name="eliminar_categoria">Eliminar</button></form></td></tr><?php endforeach; ?>
 </tbody></table></div>
</section>

<section id="marcas" class="card page-panel">
 <div class="section-title"><h2>Marcas</h2><span class="badge"><?= $totalMarcas ?> registradas</span></div>
 <form method="POST" class="inline-form" style="margin-bottom:14px"><input type="text" name="nombre_marca" placeholder="Nueva marca" required><button class="btn btn-primary" name="registrar_marca">+ Agregar marca</button></form>
 <div class="table-wrap"><table><thead><tr><th>ID</th><th>Marca</th><th>Acción</th></tr></thead><tbody>
 <?php foreach($marcas as $m): ?><tr><td><?= h($m["id_marca"]) ?></td><td><?= h($m["nombre_marca"]) ?></td><td><form method="POST" onsubmit="return confirm('¿Eliminar marca?');"><input type="hidden" name="id_marca" value="<?= h($m["id_marca"]) ?>"><button class="btn btn-danger" name="eliminar_marca">Eliminar</button></form></td></tr><?php endforeach; ?>
 </tbody></table></div>
</section>

<section id="usuarios" class="card page-panel">
 <div class="section-title"><h2>Usuarios</h2><span class="badge"><?= $totalUsuarios ?> registrados</span></div>
 <form method="POST" class="form-grid">
  <div class="field"><label>NOMBRES</label><input name="nombres" required></div><div class="field"><label>APELLIDOS</label><input name="apellidos"></div><div class="field"><label>CORREO</label><input type="email" name="correo" required></div><div class="field"><label>TELÉFONO</label><input name="telefono"></div><div class="field"><label>CONTRASEÑA</label><input type="password" name="contrasena" required></div><div class="form-actions"><button class="btn btn-primary" name="registrar_usuario">+ Registrar usuario</button></div>
 </form>
 <div class="table-wrap"><table><thead><tr><th>ID</th><th>Nombre</th><th>Correo</th><th>Teléfono</th></tr></thead><tbody>
 <?php foreach($usuarios as $u): ?><tr><td><?= h($u["id_usuario"]) ?></td><td><?= h($u["nombres"]." ".$u["apellidos"]) ?></td><td><?= h($u["correo"]) ?></td><td><?= h($u["telefono"]) ?></td></tr><?php endforeach; ?>
 </tbody></table></div>
</section>

<section id="pedidos" class="card page-panel">
 <div class="section-title"><h2>Pedidos</h2><div class="section-actions"><button type="button" class="btn btn-light" onclick="exportarTabla('tablaPedidos','pedidos_adn.csv')">Exportar CSV</button><span class="badge"><?= $totalPedidos ?> registrados</span></div></div>
 <div class="table-wrap"><table id="tablaPedidos"><thead><tr><th>#</th><th>Cliente</th><th>Fecha</th><th>Total</th><th>Estado</th><th>Acción</th></tr></thead><tbody>
 <?php foreach($pedidos as $p): ?><tr><td>#<?= h($p["id_pedido"]) ?></td><td><?= h($p["nombres"]." ".$p["apellidos"]) ?></td><td><?= h($p["fecha_pedido"]) ?></td><td class="price">S/ <?= number_format((float)$p["total"],2) ?></td><td><?= h($p["estado_pedido"]) ?></td><td><form method="POST" class="inline-form"><input type="hidden" name="id_pedido" value="<?= h($p["id_pedido"]) ?>"><select name="estado_pedido"><option>Pendiente</option><option>Procesando</option><option>Pagado</option><option>Enviado</option><option>Completado</option><option>Cancelado</option></select><button class="btn btn-primary" name="actualizar_estado_pedido">Actualizar</button></form></td></tr><?php endforeach; ?>
 </tbody></table></div>
</section>

<section id="pagos" class="card page-panel">
 <div class="section-title"><h2>Pagos</h2><span class="badge">S/ <?= number_format($totalPagos,2) ?> pagados</span></div>
 <div class="table-wrap"><table id="tablaPagos"><thead><tr><th>ID</th><th>Pedido</th><th>Cliente</th><th>Método</th><th>Monto</th><th>Estado</th><th>Acción</th></tr></thead><tbody>
 <?php if(!$pagos): ?><tr><td colspan="7" style="text-align:center;color:#718096">Todavía no hay pagos.</td></tr><?php else: foreach($pagos as $pg): ?><tr><td><?= h($pg["id_pago"]) ?></td><td>#<?= h($pg["id_pedido"]) ?></td><td><?= h($pg["nombres"]." ".$pg["apellidos"]) ?></td><td><?= h($pg["metodo_pago"]) ?></td><td class="price">S/ <?= number_format((float)$pg["monto"],2) ?></td><td><?= h($pg["estado_pago"]) ?></td><td><form method="POST" class="inline-form"><input type="hidden" name="id_pago" value="<?= h($pg["id_pago"]) ?>"><select name="estado_pago"><option>Pendiente</option><option>Pagado</option><option>Rechazado</option></select><button class="btn btn-primary" name="actualizar_estado_pago">Actualizar</button></form></td></tr><?php endforeach; endif; ?>
 </tbody></table></div>
</section>

<section id="favoritos" class="card page-panel">
 <div class="section-title"><h2>Favoritos</h2><span class="badge"><?= count($favoritos) ?> registros</span></div>
 <div class="table-wrap"><table><thead><tr><th>ID</th><th>Usuario</th><th>Producto</th><th>Precio</th><th>Fecha</th><th>Acción</th></tr></thead><tbody>
 <?php if(!$favoritos): ?><tr><td colspan="6" style="text-align:center;color:#718096">No hay favoritos registrados.</td></tr><?php else: foreach($favoritos as $f): ?><tr><td><?= h($f["id_favorito"]) ?></td><td><?= h($f["nombres"]." ".$f["apellidos"]) ?></td><td><?= h($f["nombre_producto"]) ?></td><td class="price">S/ <?= number_format((float)$f["precio"],2) ?></td><td><?= h($f["fecha_registro"]) ?></td><td><form method="POST"><input type="hidden" name="id_favorito" value="<?= h($f["id_favorito"]) ?>"><button class="btn btn-danger" name="eliminar_favorito">Eliminar</button></form></td></tr><?php endforeach; endif; ?>
 </tbody></table></div>
</section>


<section id="inventario" class="card page-panel">
 <div class="section-intro">
  <div><h2>Inventario y stock</h2><p>Controla entradas, salidas y existencias reales de tus repuestos.</p></div>
  <span class="badge"><?= $unidadesStock ?> unidades</span>
 </div>
 <div class="two-col">
  <div>
   <form method="POST" class="form-grid" style="grid-template-columns:1fr">
    <div class="field"><label>PRODUCTO</label><select name="id_producto_stock" required><option value="">Seleccione producto</option><?php foreach($productos as $p): ?><option value="<?= h($p["id_producto"]) ?>"><?= h($p["nombre_producto"]) ?> — Stock: <?= (int)$p["stock"] ?></option><?php endforeach; ?></select></div>
    <div class="field"><label>TIPO DE MOVIMIENTO</label><select name="tipo_movimiento"><option>Entrada</option><option>Salida</option></select></div>
    <div class="field"><label>CANTIDAD</label><input type="number" min="1" name="cantidad_movimiento" required></div>
    <div class="field"><label>MOTIVO</label><input type="text" name="motivo_movimiento" placeholder="Ej. Ajuste de inventario"></div>
    <div class="form-actions"><button class="btn btn-primary" name="registrar_movimiento">Registrar movimiento</button></div>
   </form>
  </div>
  <div class="table-wrap"><table><thead><tr><th>ID</th><th>Producto</th><th>Tipo</th><th>Cantidad</th><th>Motivo</th><th>Fecha</th></tr></thead><tbody>
   <?php if(!$movimientos): ?><tr><td colspan="6" style="text-align:center;color:#718096">No hay movimientos de stock.</td></tr><?php else: foreach($movimientos as $mv): ?><tr><td><?= h($mv["id_movimiento"]) ?></td><td><?= h($mv["nombre_producto"]) ?></td><td><span class="status <?= $mv["tipo_movimiento"]==="Entrada"?"ok":"warn" ?>"><?= h($mv["tipo_movimiento"]) ?></span></td><td><?= (int)$mv["cantidad"] ?></td><td><?= h($mv["motivo"]) ?></td><td><?= h($mv["fecha_movimiento"]) ?></td></tr><?php endforeach; endif; ?>
  </tbody></table></div>
 </div>
</section>

<section id="proveedores" class="card page-panel">
 <div class="section-intro"><div><h2>Proveedores</h2><p>Registra las empresas que abastecen los productos de Dorada Motors.</p></div><span class="badge"><?= $totalProveedores ?> registrados</span></div>
 <form method="POST" class="form-grid">
  <div class="field"><label>RAZÓN SOCIAL</label><input name="razon_social" required placeholder="Nombre del proveedor"></div>
  <div class="field"><label>RUC</label><input name="ruc" placeholder="RUC"></div>
  <div class="field"><label>TELÉFONO</label><input name="telefono_proveedor"></div>
  <div class="field"><label>CORREO</label><input type="email" name="correo_proveedor"></div>
  <div class="field full"><label>DIRECCIÓN</label><input name="direccion_proveedor"></div>
  <div class="form-actions"><button class="btn btn-primary" name="registrar_proveedor">+ Registrar proveedor</button></div>
 </form>
 <div class="table-wrap"><table><thead><tr><th>ID</th><th>Proveedor</th><th>RUC</th><th>Teléfono</th><th>Correo</th><th>Estado</th><th>Acción</th></tr></thead><tbody>
 <?php if(!$proveedores): ?><tr><td colspan="7" style="text-align:center;color:#718096">No hay proveedores registrados.</td></tr><?php else: foreach($proveedores as $pr): ?><tr><td><?= h($pr["id_proveedor"]) ?></td><td><strong><?= h($pr["razon_social"]) ?></strong></td><td><?= h($pr["ruc"]) ?></td><td><?= h($pr["telefono"]) ?></td><td><?= h($pr["correo"]) ?></td><td><span class="status ok"><?= h($pr["estado"]) ?></span></td><td><form method="POST" onsubmit="return confirm('¿Eliminar proveedor?');"><input type="hidden" name="id_proveedor" value="<?= h($pr["id_proveedor"]) ?>"><button class="btn btn-danger" name="eliminar_proveedor">Eliminar</button></form></td></tr><?php endforeach; endif; ?>
 </tbody></table></div>
</section>

<section id="compras" class="card page-panel">
 <div class="section-intro"><div><h2>Compras y abastecimiento</h2><p>Registra compras a proveedores y aumenta automáticamente el stock.</p></div><span class="badge">S/ <?= number_format($totalCompras,2) ?></span></div>
 <form method="POST" class="form-grid">
  <div class="field"><label>PROVEEDOR</label><select name="id_proveedor_compra" required><option value="">Seleccione proveedor</option><?php foreach($proveedores as $pr): ?><option value="<?= h($pr["id_proveedor"]) ?>"><?= h($pr["razon_social"]) ?></option><?php endforeach; ?></select></div>
  <div class="field"><label>PRODUCTO</label><select name="id_producto_compra" required><option value="">Seleccione producto</option><?php foreach($productos as $p): ?><option value="<?= h($p["id_producto"]) ?>"><?= h($p["nombre_producto"]) ?></option><?php endforeach; ?></select></div>
  <div class="field"><label>CANTIDAD</label><input type="number" min="1" name="cantidad_compra" required></div>
  <div class="field"><label>PRECIO DE COMPRA</label><input type="number" min="0" step="0.01" name="precio_compra" required></div>
  <div class="form-actions"><button class="btn btn-primary" name="registrar_compra">+ Registrar compra</button></div>
 </form>
 <div class="table-wrap"><table><thead><tr><th>ID</th><th>Proveedor</th><th>Fecha</th><th>Total</th><th>Estado</th></tr></thead><tbody>
 <?php if(!$compras): ?><tr><td colspan="5" style="text-align:center;color:#718096">No hay compras registradas.</td></tr><?php else: foreach($compras as $co): ?><tr><td>#<?= h($co["id_compra"]) ?></td><td><?= h($co["razon_social"]) ?></td><td><?= h($co["fecha_compra"]) ?></td><td class="price">S/ <?= number_format((float)$co["total"],2) ?></td><td><span class="status ok"><?= h($co["estado"]) ?></span></td></tr><?php endforeach; endif; ?>
 </tbody></table></div>
</section>

<section id="comprobantes" class="card page-panel">
 <div class="section-intro"><div><h2>Comprobantes</h2><p>Genera el registro de boletas o facturas vinculadas a un pedido.</p></div><span class="badge"><?= count($comprobantes) ?> emitidos</span></div>
 <form method="POST" class="form-grid">
  <div class="field"><label>PEDIDO</label><select name="id_pedido_comprobante" required><option value="">Seleccione pedido</option><?php foreach($pedidos as $p): ?><option value="<?= h($p["id_pedido"]) ?>">#<?= h($p["id_pedido"]) ?> — <?= h($p["nombres"]." ".$p["apellidos"]) ?> — S/ <?= number_format((float)$p["total"],2) ?></option><?php endforeach; ?></select></div>
  <div class="field"><label>TIPO</label><select name="tipo_comprobante"><option>Boleta</option><option>Factura</option></select></div>
  <div class="field"><label>NÚMERO</label><input name="numero_comprobante" required placeholder="B001-000001"></div>
  <div class="form-actions"><button class="btn btn-primary" name="registrar_comprobante">+ Emitir comprobante</button></div>
 </form>
 <div class="table-wrap"><table><thead><tr><th>ID</th><th>Pedido</th><th>Cliente</th><th>Tipo</th><th>Número</th><th>IGV</th><th>Total</th><th>Acción</th></tr></thead><tbody>
 <?php if(!$comprobantes): ?><tr><td colspan="8" style="text-align:center;color:#718096">No hay comprobantes.</td></tr><?php else: foreach($comprobantes as $cp): ?><tr><td><?= h($cp["id_comprobante"]) ?></td><td>#<?= h($cp["id_pedido"]) ?></td><td><?= h($cp["nombres"]." ".$cp["apellidos"]) ?></td><td><?= h($cp["tipo_comprobante"]) ?></td><td><?= h($cp["numero_comprobante"]) ?></td><td>S/ <?= number_format((float)$cp["igv"],2) ?></td><td class="price">S/ <?= number_format((float)$cp["total"],2) ?></td><td><form method="POST" onsubmit="return confirm('¿Eliminar comprobante?');"><input type="hidden" name="id_comprobante" value="<?= h($cp["id_comprobante"]) ?>"><button class="btn btn-danger" name="eliminar_comprobante">Eliminar</button></form></td></tr><?php endforeach; endif; ?>
 </tbody></table></div>
</section>

<section id="configuracion" class="card page-panel">
 <div class="section-intro"><div><h2>Configuración del sistema</h2><p>Información clara para comprobar que frontend, backend y base de datos están comunicados.</p></div><span class="badge">Sistema activo</span></div>
 <div class="system-grid">
  <div class="system-card"><span class="system-icon ok">✓</span><div><small>BACKEND</small><strong>PHP conectado</strong><p>API disponible en /dorada_api/</p></div></div>
  <div class="system-card"><span class="system-icon ok">✓</span><div><small>BASE DE DATOS</small><strong>MySQL conectado</strong><p>Base: dorada_motors</p></div></div>
  <div class="system-card"><span class="system-icon ok">✓</span><div><small>FRONTEND</small><strong>Flutter preparado</strong><p>Consume endpoints JSON del backend</p></div></div>
  <div class="system-card"><span class="system-icon warn">!</span><div><small>ALERTAS</small><strong><?= $stockBajo ?> stock bajo</strong><p><?= $pedidosPendientes ?> pedidos por atender</p></div></div>
 </div>
 <div class="help-card">
  <div><strong>Flujo del sistema</strong><p>Flutter → PHP/API → MySQL. El panel web administra los mismos datos que utiliza la aplicación.</p></div>
  <button type="button" class="btn btn-primary" onclick="mostrarPanel('inicio',true)">Volver al dashboard</button>
 </div>
</section>

<section id="reportes" class="card page-panel">
 <div class="section-title"><div><div class="eyebrow">Análisis</div><h2>Reportes rápidos</h2></div><div class="section-actions"><button type="button" class="btn btn-light" onclick="window.print()">Imprimir reporte</button><span class="badge">Resumen actual</span></div></div>
 <div class="stats-row">
  <div class="mini-stat"><small>VENTAS REGISTRADAS</small><strong>S/ <?= number_format($totalVentas,2) ?></strong></div>
  <div class="mini-stat"><small>PAGOS CONFIRMADOS</small><strong>S/ <?= number_format($totalPagos,2) ?></strong></div>
  <div class="mini-stat"><small>PRODUCTOS EN CATÁLOGO</small><strong><?= $totalProductos ?></strong></div>
  <div class="mini-stat"><small>UNIDADES EN STOCK</small><strong><?= $unidadesStock ?></strong></div>
  <div class="mini-stat"><small>STOCK BAJO</small><strong><?= $stockBajo ?></strong></div>
  <div class="mini-stat"><small>COMPRAS</small><strong>S/ <?= number_format($totalCompras,2) ?></strong></div>
 </div>
</section>

</div>
</main>
</div>

<nav class="mobile-bottom">
 <a href="#inicio" class="active">⌂<b>Dashboard</b></a>
 <a href="#gestion-productos">◇<b>Productos</b></a>
 <a href="#inventario">▤<b>Stock</b></a>
 <a href="#pedidos">🛒<b>Pedidos</b></a>
</nav>

<script>
const buscador=document.getElementById('buscador');
const sidebar=document.getElementById('sidebar');
const overlay=document.getElementById('overlay');
const menuBtn=document.getElementById('menuBtn');
const navLinks=document.querySelectorAll('.nav a');
const mobileLinks=document.querySelectorAll('.mobile-bottom a');
const panels=document.querySelectorAll('.page-panel');
const topTitle=document.getElementById('topTitle');

const nombresPanel={
 inicio:'Dashboard',
 'gestion-productos':'Productos',
 inventario:'Inventario',
 proveedores:'Proveedores',
 compras:'Compras',
 categorias:'Categorías',
 marcas:'Marcas',
 usuarios:'Usuarios',
 pedidos:'Pedidos',
 pagos:'Pagos',
 comprobantes:'Comprobantes',
 favoritos:'Favoritos',
 reportes:'Reportes',
 configuracion:'Configuración'
};

function cerrarMenu(){
 sidebar.classList.remove('open');
 overlay.classList.remove('show');
}

function filtrarPanel(texto){
 const activo=document.querySelector('.page-panel.active');
 if(!activo) return;
 const t=texto.toLowerCase().trim();
 activo.querySelectorAll('tbody tr').forEach(fila=>{
  fila.style.display=!t || fila.innerText.toLowerCase().includes(t)?'':'none';
 });
}

buscador?.addEventListener('input',()=>filtrarPanel(buscador.value));

document.addEventListener('keydown',e=>{
 if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='k'){
  e.preventDefault();
  buscador?.focus();
  buscador?.select();
 }
});

function mostrarPanel(id, actualizarHash=true){
 const destino=document.getElementById(id) || document.getElementById('inicio');
 panels.forEach(p=>p.classList.remove('active'));
 destino.classList.add('active');

 navLinks.forEach(a=>a.classList.toggle('active',a.getAttribute('href')==='#'+destino.id));
 mobileLinks.forEach(a=>a.classList.toggle('active',a.getAttribute('href')==='#'+destino.id));

 if(topTitle) topTitle.textContent=nombresPanel[destino.id]||'ADN Import\'s';
 if(buscador){buscador.value='';filtrarPanel('');}
 if(actualizarHash) history.replaceState(null,'','#'+destino.id);

 window.scrollTo({top:0,behavior:'smooth'});
 cerrarMenu();
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
 sidebar.classList.toggle('open');
 overlay.classList.toggle('show');
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

function exportarTabla(id,nombre){
 const tabla=document.getElementById(id);
 if(!tabla) return;
 const filas=[...tabla.querySelectorAll('tr')].filter(f=>f.style.display!=='none');
 const csv=filas.map(f=>[...f.querySelectorAll('th,td')].map(c=>'"'+c.innerText.replace(/"/g,'""').replace(/\n/g,' ')+'"').join(',')).join('\n');
 const blob=new Blob(['\ufeff'+csv],{type:'text/csv;charset=utf-8;'});
 const url=URL.createObjectURL(blob);
 const a=document.createElement('a');
 a.href=url;a.download=nombre;document.body.appendChild(a);a.click();a.remove();URL.revokeObjectURL(url);
}

const inicial=location.hash ? location.hash.substring(1) : 'inicio';
mostrarPanel(inicial,false);
</script>
</body>
</html>