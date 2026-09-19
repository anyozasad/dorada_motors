<?php
require_once "conexion.php";
header("Content-Type: text/html; charset=UTF-8");

function h($valor) {
    return htmlspecialchars((string)$valor, ENT_QUOTES, "UTF-8");
}

$mensaje = "";
$tipoMensaje = "ok";

/* =========================
   CRUD DE PRODUCTOS
   ========================= */
if ($_SERVER["REQUEST_METHOD"] === "POST") {
    try {
        if (isset($_POST["registrar_producto"])) {
            $idCategoria = (int)($_POST["id_categoria"] ?? 0);
            $idMarca = (int)($_POST["id_marca"] ?? 0);
            $nombre = trim($_POST["nombre_producto"] ?? "");
            $descripcion = trim($_POST["descripcion"] ?? "");
            $precio = (float)($_POST["precio"] ?? 0);
            $stock = (int)($_POST["stock"] ?? 0);
            $imagen = trim($_POST["imagen_url"] ?? "");

            $stmt = $conexion->prepare("
                INSERT INTO producto
                (id_categoria, id_marca, nombre_producto, descripcion, precio, stock, imagen_url)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ");
            $stmt->bind_param("iissdis", $idCategoria, $idMarca, $nombre, $descripcion, $precio, $stock, $imagen);
            $stmt->execute();

            header("Location: dashboard.php?msg=Producto registrado correctamente&tipo=ok#gestion-productos");
            exit;
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
                UPDATE producto SET
                    id_categoria = ?,
                    id_marca = ?,
                    nombre_producto = ?,
                    descripcion = ?,
                    precio = ?,
                    stock = ?,
                    imagen_url = ?
                WHERE id_producto = ?
            ");
            $stmt->bind_param("iissdisi", $idCategoria, $idMarca, $nombre, $descripcion, $precio, $stock, $imagen, $idProducto);
            $stmt->execute();

            header("Location: dashboard.php?msg=Producto actualizado correctamente&tipo=ok#gestion-productos");
            exit;
        }

        if (isset($_POST["eliminar_producto"])) {
            $idProducto = (int)($_POST["id_producto"] ?? 0);

            $stmt = $conexion->prepare("
                SELECT
                    (SELECT COUNT(*) FROM detalle_pedido WHERE id_producto = ?) +
                    (SELECT COUNT(*) FROM detalle_compra WHERE id_producto = ?) AS total
            ");
            $stmt->bind_param("ii", $idProducto, $idProducto);
            $stmt->execute();
            $referencias = (int)$stmt->get_result()->fetch_assoc()["total"];

            if ($referencias > 0) {
                header("Location: dashboard.php?msg=No se puede eliminar porque el producto ya tiene movimientos registrados&tipo=error#gestion-productos");
                exit;
            }

            foreach (["favorito", "carrito_favorito", "detalle_carrito", "movimiento_stock"] as $tabla) {
                $stmt = $conexion->prepare("DELETE FROM $tabla WHERE id_producto = ?");
                $stmt->bind_param("i", $idProducto);
                $stmt->execute();
            }

            $stmt = $conexion->prepare("DELETE FROM producto WHERE id_producto = ?");
            $stmt->bind_param("i", $idProducto);
            $stmt->execute();

            header("Location: dashboard.php?msg=Producto eliminado correctamente&tipo=ok#gestion-productos");
            exit;
        }
    } catch (Throwable $e) {
        $mensaje = "Error: " . $e->getMessage();
        $tipoMensaje = "error";
    }
}

if (isset($_GET["msg"])) {
    $mensaje = $_GET["msg"];
    $tipoMensaje = $_GET["tipo"] ?? "ok";
}

/* =========================
   MÉTRICAS DEL DASHBOARD
   ========================= */
$totalProductos = (int)$conexion->query("SELECT COUNT(*) AS total FROM producto")->fetch_assoc()["total"];
$totalUsuarios = (int)$conexion->query("SELECT COUNT(*) AS total FROM usuario")->fetch_assoc()["total"];
$totalPedidos = (int)$conexion->query("SELECT COUNT(*) AS total FROM pedido")->fetch_assoc()["total"];
$totalVentas = (float)$conexion->query("SELECT COALESCE(SUM(total),0) AS total FROM pedido")->fetch_assoc()["total"];

/* =========================
   VENTAS DE LOS ÚLTIMOS 7 DÍAS
   ========================= */
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

$diasCortos = ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"];
$ventas7 = [];
$maxVenta = 1;

for ($i = 6; $i >= 0; $i--) {
    $fecha = date("Y-m-d", strtotime("-$i day"));
    $total = $ventasPorFecha[$fecha] ?? 0;
    $maxVenta = max($maxVenta, $total);

    $ventas7[] = [
        "fecha" => $fecha,
        "dia" => $diasCortos[(int)date("w", strtotime($fecha))],
        "total" => $total
    ];
}

/* =========================
   PEDIDOS RECIENTES
   ========================= */
$pedidosRecientes = $conexion->query("
    SELECT
        p.id_pedido,
        p.fecha_pedido,
        p.estado_pedido,
        p.total,
        u.nombres,
        u.apellidos
    FROM pedido p
    INNER JOIN usuario u ON p.id_usuario = u.id_usuario
    ORDER BY p.id_pedido DESC
    LIMIT 5
")->fetch_all(MYSQLI_ASSOC);

/* =========================
   PRODUCTOS MÁS VENDIDOS
   ========================= */
$masVendidos = $conexion->query("
    SELECT
        p.nombre_producto,
        COALESCE(SUM(dp.cantidad),0) AS vendidos
    FROM producto p
    LEFT JOIN detalle_pedido dp ON p.id_producto = dp.id_producto
    GROUP BY p.id_producto, p.nombre_producto
    ORDER BY vendidos DESC, p.nombre_producto ASC
    LIMIT 5
")->fetch_all(MYSQLI_ASSOC);

/* =========================
   DATOS PARA CRUD
   ========================= */
$categorias = $conexion->query("SELECT * FROM categoria ORDER BY nombre_categoria")->fetch_all(MYSQLI_ASSOC);
$marcas = $conexion->query("SELECT * FROM marca ORDER BY nombre_marca")->fetch_all(MYSQLI_ASSOC);

$productos = $conexion->query("
    SELECT
        p.id_producto,
        p.id_categoria,
        p.id_marca,
        p.nombre_producto,
        p.descripcion,
        p.precio,
        p.stock,
        p.imagen_url,
        c.nombre_categoria,
        m.nombre_marca
    FROM producto p
    INNER JOIN categoria c ON p.id_categoria = c.id_categoria
    INNER JOIN marca m ON p.id_marca = m.id_marca
    ORDER BY p.id_producto DESC
")->fetch_all(MYSQLI_ASSOC);

$productoEditar = null;
if (isset($_GET["editar"])) {
    $idEditar = (int)$_GET["editar"];
    $stmt = $conexion->prepare("SELECT * FROM producto WHERE id_producto = ?");
    $stmt->bind_param("i", $idEditar);
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
    --navy:#0f2746;
    --navy2:#17395f;
    --gold:#d7a62a;
    --gold-soft:#fff4d6;
    --bg:#f4f7fb;
    --surface:#ffffff;
    --text:#13233a;
    --muted:#718096;
    --border:#e5eaf1;
    --green:#17a56b;
    --green-soft:#ddf7eb;
    --blue:#2878e6;
    --blue-soft:#e8f1ff;
    --purple:#7357e8;
    --purple-soft:#efeaff;
    --red:#df3848;
    --red-soft:#ffe8ea;
    --shadow:0 10px 30px rgba(15,39,70,.07);
}

*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{
    margin:0;
    font-family:Inter,Segoe UI,Arial,sans-serif;
    background:var(--bg);
    color:var(--text);
}
button,input,select,textarea{font:inherit}
a{text-decoration:none;color:inherit}
svg{display:block}

.app{
    min-height:100vh;
    display:grid;
    grid-template-columns:235px minmax(0,1fr);
}

/* SIDEBAR */
.sidebar{
    position:sticky;
    top:0;
    height:100vh;
    background:linear-gradient(180deg,#0b2745 0%,#0b2c4d 100%);
    color:white;
    padding:22px 16px;
    display:flex;
    flex-direction:column;
    overflow:auto;
}
.brand{
    display:flex;
    align-items:center;
    gap:11px;
    padding:0 7px 24px;
}
.brand-mark{
    width:38px;
    height:38px;
    border:2px solid var(--gold);
    border-radius:12px 4px 12px 4px;
    display:grid;
    place-items:center;
    color:var(--gold);
    font-weight:900;
    transform:rotate(45deg);
}
.brand-mark span{transform:rotate(-45deg);font-size:18px}
.brand-title{font-size:18px;font-weight:900;letter-spacing:.2px}
.brand-title b{color:var(--gold)}
.brand-sub{font-size:10px;color:#aebed0;margin-top:3px}

.nav{
    display:flex;
    flex-direction:column;
    gap:5px;
}
.nav a{
    display:flex;
    align-items:center;
    gap:12px;
    padding:11px 13px;
    border-radius:12px;
    color:#d7e2ee;
    font-weight:700;
    font-size:13px;
}
.nav a:hover,.nav a.active{
    background:linear-gradient(90deg,#d7a62a,#bc8920);
    color:#10233e;
}
.nav-icon{
    width:20px;height:20px;display:grid;place-items:center;
}
.sidebar-bottom{
    margin-top:auto;
    border-top:1px solid rgba(255,255,255,.10);
    padding-top:16px;
    color:#b8c7d7;
    font-size:11px;
}
.sidebar-bottom strong{display:block;color:white;margin-bottom:4px}
.motto{
    margin:18px 0;
    padding:14px;
    border-radius:15px;
    background:rgba(255,255,255,.05);
    color:#efc65b;
    text-align:center;
    font-style:italic;
    line-height:1.4;
}

/* MAIN */
.main{
    min-width:0;
}
.topbar{
    height:70px;
    background:white;
    border-bottom:1px solid var(--border);
    display:flex;
    align-items:center;
    gap:18px;
    padding:0 24px;
    position:sticky;
    top:0;
    z-index:20;
}
.mobile-menu{
    display:none;
    width:42px;height:42px;border:0;background:#f3f6fa;border-radius:12px;
}
.search{
    width:min(470px,45vw);
    position:relative;
}
.search input{
    width:100%;
    border:1px solid var(--border);
    background:#f7f9fc;
    border-radius:11px;
    padding:11px 14px 11px 40px;
    outline:none;
}
.search span{
    position:absolute;left:14px;top:50%;transform:translateY(-50%);color:var(--muted);
}
.top-actions{
    margin-left:auto;
    display:flex;
    align-items:center;
    gap:12px;
}
.icon-btn{
    width:40px;height:40px;border:1px solid var(--border);border-radius:12px;
    background:white;display:grid;place-items:center;position:relative;
}
.notification-dot{
    width:8px;height:8px;background:var(--red);border-radius:50%;
    position:absolute;right:7px;top:7px;border:2px solid white;
}
.admin{
    display:flex;align-items:center;gap:10px;
    padding-left:10px;border-left:1px solid var(--border);
}
.avatar{
    width:38px;height:38px;border-radius:50%;
    background:linear-gradient(135deg,var(--navy),var(--gold));
    color:white;display:grid;place-items:center;font-weight:900;
}
.admin small{display:block;color:var(--muted);font-size:10px}
.admin strong{font-size:12px}

.content{
    padding:24px;
    max-width:1480px;
    margin:auto;
}
.heading{
    display:flex;justify-content:space-between;align-items:flex-end;gap:20px;
    margin-bottom:18px;
}
.eyebrow{
    font-size:11px;font-weight:900;letter-spacing:1.2px;color:#a67a12;
    text-transform:uppercase;margin-bottom:5px;
}
.heading h1{font-size:27px;margin:0 0 5px;font-weight:900}
.heading p{margin:0;color:var(--muted);font-size:13px}
.date-chip{
    background:white;border:1px solid var(--border);border-radius:11px;
    padding:10px 13px;color:var(--muted);font-size:12px;font-weight:700;
}

/* KPI */
.metrics{
    display:grid;
    grid-template-columns:repeat(4,minmax(0,1fr));
    gap:14px;
    margin-bottom:16px;
}
.metric{
    background:white;border:1px solid var(--border);border-radius:16px;
    padding:18px;box-shadow:var(--shadow);
    display:flex;align-items:center;gap:13px;
}
.metric-icon{
    width:50px;height:50px;border-radius:14px;display:grid;place-items:center;flex:0 0 auto;
}
.metric-icon.blue{background:var(--blue-soft);color:var(--blue)}
.metric-icon.gold{background:var(--gold-soft);color:#a87500}
.metric-icon.purple{background:var(--purple-soft);color:var(--purple)}
.metric-icon.green{background:var(--green-soft);color:var(--green)}
.metric-label{color:var(--muted);font-size:12px;font-weight:700}
.metric-value{font-size:24px;font-weight:900;margin-top:3px;color:#10233e}

/* CARDS */
.grid-main{
    display:grid;
    grid-template-columns:minmax(0,1.35fr) minmax(320px,.75fr);
    gap:16px;
    margin-bottom:16px;
}
.grid-bottom{
    display:grid;
    grid-template-columns:minmax(0,1.25fr) minmax(280px,.75fr);
    gap:16px;
    margin-bottom:16px;
}
.card{
    background:white;border:1px solid var(--border);border-radius:17px;
    box-shadow:var(--shadow);padding:18px;min-width:0;
}
.card-head{
    display:flex;align-items:center;justify-content:space-between;gap:12px;
    margin-bottom:14px;
}
.card-head h2{font-size:15px;margin:0;font-weight:900}
.card-head a{font-size:11px;color:var(--blue);font-weight:800}

/* CHART */
.chart{
    height:220px;
    display:flex;
    align-items:flex-end;
    gap:12px;
    padding:16px 4px 0;
    border-bottom:1px solid var(--border);
    background:
      linear-gradient(to top, rgba(229,234,241,.65) 1px, transparent 1px);
    background-size:100% 25%;
}
.chart-item{
    flex:1;min-width:0;height:100%;
    display:flex;flex-direction:column;justify-content:flex-end;align-items:center;gap:7px;
}
.bar{
    width:min(44px,80%);
    min-height:4px;
    border-radius:9px 9px 3px 3px;
    background:linear-gradient(180deg,#e2b94e,#17395f);
    position:relative;
    transition:.2s;
}
.bar:hover{filter:brightness(1.08);transform:translateY(-2px)}
.bar-tip{
    opacity:0;pointer-events:none;
    position:absolute;left:50%;bottom:calc(100% + 7px);transform:translateX(-50%);
    background:#10233e;color:white;padding:6px 8px;border-radius:8px;
    font-size:10px;white-space:nowrap;
}
.bar:hover .bar-tip{opacity:1}
.day{font-size:10px;color:var(--muted);font-weight:700}

/* QUICK ACTIONS */
.quick-actions{
    display:grid;grid-template-columns:repeat(2,1fr);gap:10px;
}
.quick{
    border:1px solid var(--border);border-radius:14px;padding:15px 10px;
    min-height:89px;display:flex;flex-direction:column;align-items:center;justify-content:center;
    gap:8px;font-size:11px;font-weight:800;text-align:center;transition:.2s;
}
.quick:hover{transform:translateY(-2px);box-shadow:var(--shadow)}
.quick.blue{background:#eef5ff;color:#245fae}
.quick.gold{background:#fff5dd;color:#9d7108}
.quick.purple{background:#f1edff;color:#674bc9}
.quick.green{background:#e9f9f1;color:#158a5a}

/* TABLE */
.table-wrap{overflow:auto}
table{width:100%;border-collapse:collapse;min-width:620px}
th{
    text-transform:uppercase;font-size:9px;letter-spacing:.5px;color:var(--muted);
    text-align:left;background:#f7f9fc;padding:10px;border-bottom:1px solid var(--border)
}
td{padding:11px 10px;border-bottom:1px solid var(--border);font-size:11px;vertical-align:middle}
tbody tr:hover{background:#fafcff}
.status{
    display:inline-flex;padding:5px 9px;border-radius:20px;font-size:9px;font-weight:900;
}
.status.ok{background:var(--green-soft);color:var(--green)}
.status.info{background:var(--blue-soft);color:var(--blue)}
.status.warn{background:var(--gold-soft);color:#a26f00}
.status.danger{background:var(--red-soft);color:var(--red)}

.top-list{display:flex;flex-direction:column;gap:8px}
.top-product{
    display:grid;grid-template-columns:30px minmax(0,1fr) auto;align-items:center;gap:9px;
    padding:9px 0;border-bottom:1px solid var(--border)
}
.rank{
    width:26px;height:26px;border-radius:50%;background:var(--gold-soft);
    color:#9a6c00;display:grid;place-items:center;font-size:11px;font-weight:900
}
.top-product strong{font-size:11px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.top-product span{font-size:10px;color:var(--muted)}

/* CRUD */
.crud-section{
    margin-top:16px;
}
.crud-head{
    display:flex;justify-content:space-between;align-items:center;gap:12px;margin-bottom:14px
}
.crud-head h2{margin:0;font-size:17px}
.badge{
    background:var(--gold-soft);color:#8f6707;font-size:10px;font-weight:900;
    padding:7px 10px;border-radius:10px
}
.product-form{
    display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;
    padding:15px;background:#f8fafc;border:1px solid var(--border);border-radius:14px;margin-bottom:15px
}
.field{display:flex;flex-direction:column;gap:6px}
.field.full{grid-column:1/-1}
.field label{font-size:10px;color:var(--muted);font-weight:800}
.field input,.field select,.field textarea{
    width:100%;border:1px solid var(--border);border-radius:10px;background:white;
    padding:11px 12px;outline:none;color:var(--text)
}
.field input:focus,.field select:focus,.field textarea:focus{
    border-color:#d5aa3f;box-shadow:0 0 0 3px rgba(215,166,42,.12)
}
.field textarea{min-height:76px;resize:vertical}
.form-actions{grid-column:1/-1;display:flex;gap:9px;flex-wrap:wrap}
.btn{
    border:0;border-radius:10px;padding:10px 14px;font-weight:900;font-size:11px;
    cursor:pointer;display:inline-flex;align-items:center;gap:7px;justify-content:center
}
.btn-primary{background:var(--navy);color:white}
.btn-gold{background:var(--gold);color:#152642}
.btn-light{background:#eef1f5;color:#37465b}
.btn-danger{background:var(--red-soft);color:var(--red)}
.actions{display:flex;gap:6px}
.action-btn{
    width:31px;height:31px;border:1px solid var(--border);border-radius:8px;background:white;
    display:grid;place-items:center;cursor:pointer
}
.action-btn.edit{color:var(--blue)}
.action-btn.delete{color:var(--red)}
.stock{
    display:inline-flex;min-width:30px;justify-content:center;border-radius:8px;padding:5px 7px;
    font-size:10px;font-weight:900
}
.stock.good{background:var(--green-soft);color:var(--green)}
.stock.low{background:var(--gold-soft);color:#a06f00}
.stock.zero{background:var(--red-soft);color:var(--red)}
.price{font-weight:900;color:#112a4a}
.alert{
    border-radius:12px;padding:12px 14px;margin-bottom:15px;font-size:12px;font-weight:800
}
.alert.ok{background:var(--green-soft);color:var(--green)}
.alert.error{background:var(--red-soft);color:var(--red)}

/* MOBILE BOTTOM NAV */
.mobile-bottom{display:none}

/* RESPONSIVE */
@media(max-width:1100px){
    .metrics{grid-template-columns:repeat(2,1fr)}
    .grid-main,.grid-bottom{grid-template-columns:1fr}
}
@media(max-width:820px){
    body{padding-bottom:74px}
    .app{grid-template-columns:1fr}
    .sidebar{display:none}
    .topbar{height:64px;padding:0 14px}
    .mobile-menu{display:grid;place-items:center}
    .search{display:none}
    .admin div:last-child{display:none}
    .content{padding:15px}
    .heading{align-items:flex-start}
    .heading h1{font-size:22px}
    .date-chip{display:none}
    .metrics{grid-template-columns:repeat(2,1fr);gap:10px}
    .metric{padding:13px;gap:9px}
    .metric-icon{width:42px;height:42px;border-radius:12px}
    .metric-value{font-size:19px}
    .grid-main,.grid-bottom{gap:12px}
    .chart{height:180px;gap:6px}
    .card{padding:14px;border-radius:15px}
    .product-form{grid-template-columns:1fr}
    .field.full,.form-actions{grid-column:auto}
    .mobile-bottom{
        display:grid;grid-template-columns:repeat(4,1fr);
        position:fixed;left:0;right:0;bottom:0;height:68px;background:white;
        border-top:1px solid var(--border);z-index:40;
        box-shadow:0 -8px 22px rgba(15,39,70,.08)
    }
    .mobile-bottom a{
        display:flex;flex-direction:column;align-items:center;justify-content:center;
        gap:4px;color:var(--muted);font-size:9px;font-weight:800
    }
    .mobile-bottom a.active{color:#a7780a}
}
@media(max-width:480px){
    .metrics{grid-template-columns:1fr 1fr}
    .metric{align-items:flex-start}
    .metric-icon{width:38px;height:38px}
    .metric-value{font-size:17px}
    .metric-label{font-size:10px}
    .quick-actions{grid-template-columns:repeat(2,1fr)}
}
</style>
</head>
<body>
<div class="app">

<aside class="sidebar">
    <div class="brand">
        <div class="brand-mark"><span>D</span></div>
        <div>
            <div class="brand-title">Dorada <b>Motors</b></div>
            <div class="brand-sub">Panel de Administración</div>
        </div>
    </div>

    <nav class="nav">
        <a href="#inicio" class="active"><span class="nav-icon">⌂</span>Dashboard</a>
        <a href="#gestion-productos"><span class="nav-icon">◇</span>Productos</a>
        <a href="categorias.php" target="_blank"><span class="nav-icon">▦</span>Categorías</a>
        <a href="marcas.php" target="_blank"><span class="nav-icon">◆</span>Marcas</a>
        <a href="usuarios.php" target="_blank"><span class="nav-icon">♙</span>Usuarios</a>
        <a href="#pedidos"><span class="nav-icon">🛒</span>Pedidos</a>
        <a href="pagos.php" target="_blank"><span class="nav-icon">▣</span>Pagos</a>
        <a href="favoritos.php" target="_blank"><span class="nav-icon">♥</span>Favoritos</a>
        <a href="#ventas"><span class="nav-icon">▥</span>Reportes</a>
    </nav>

    <div class="motto">“Grandes caminos comienzan aquí”</div>

    <div class="sidebar-bottom">
        <strong>Dorada Motors</strong>
        Panel Administrativo v1.0<br>
        PHP · MySQL · Flutter
    </div>
</aside>

<main class="main">
    <header class="topbar">
        <button class="mobile-menu" aria-label="Menú">☰</button>

        <div class="search">
            <span>⌕</span>
            <input id="buscador" type="search" placeholder="Buscar producto en el sistema...">
        </div>

        <div class="top-actions">
            <div class="icon-btn">♢<span class="notification-dot"></span></div>
            <div class="admin">
                <div class="avatar">DM</div>
                <div>
                    <strong>Administrador</strong>
                    <small>Dorada Motors</small>
                </div>
            </div>
        </div>
    </header>

    <div class="content">

        <?php if ($mensaje !== ""): ?>
            <div class="alert <?= $tipoMensaje === "error" ? "error" : "ok" ?>">
                <?= h($mensaje) ?>
            </div>
        <?php endif; ?>

        <section id="inicio" class="heading">
            <div>
                <div class="eyebrow">Panel de administración</div>
                <h1>¡Bienvenido de nuevo, Administrador!</h1>
                <p>Aquí tienes un resumen general de la actividad de Dorada Motors.</p>
            </div>
            <div class="date-chip">📅 <?= h($fechaHoy) ?></div>
        </section>

        <section class="metrics">
            <article class="metric">
                <div class="metric-icon blue">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M4 7l8-4 8 4-8 4-8-4Z"/><path d="M4 7v10l8 4 8-4V7M12 11v10"/></svg>
                </div>
                <div><div class="metric-label">Productos</div><div class="metric-value"><?= $totalProductos ?></div></div>
            </article>

            <article class="metric">
                <div class="metric-icon gold">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="9" cy="8" r="3"/><circle cx="17" cy="8" r="2"/><path d="M3 20v-2c0-3 2.5-5 6-5s6 2 6 5v2M15 14c3 0 5 1.7 5 4v2"/></svg>
                </div>
                <div><div class="metric-label">Usuarios</div><div class="metric-value"><?= $totalUsuarios ?></div></div>
            </article>

            <article class="metric">
                <div class="metric-icon purple">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 4h2l2 11h10l3-8H6"/><circle cx="9" cy="20" r="1.5"/><circle cx="17" cy="20" r="1.5"/></svg>
                </div>
                <div><div class="metric-label">Pedidos</div><div class="metric-value"><?= $totalPedidos ?></div></div>
            </article>

            <article class="metric">
                <div class="metric-icon green">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="9"/><path d="M15 8.5c-.7-.7-1.7-1-3-1-1.7 0-3 1-3 2.4 0 3.4 6 1.4 6 4.5 0 1.4-1.2 2.6-3.2 2.6-1.3 0-2.5-.4-3.3-1.2M12 5v14"/></svg>
                </div>
                <div><div class="metric-label">Ventas</div><div class="metric-value">S/ <?= number_format($totalVentas,2) ?></div></div>
            </article>
        </section>

        <section class="grid-main">
            <article id="ventas" class="card">
                <div class="card-head">
                    <h2>Ventas de los últimos 7 días</h2>
                    <span class="badge">Últimos 7 días</span>
                </div>

                <div class="chart">
                    <?php foreach ($ventas7 as $dato):
                        $altura = $dato["total"] > 0 ? max(8, ($dato["total"] / $maxVenta) * 88) : 4;
                    ?>
                    <div class="chart-item">
                        <div class="bar" style="height:<?= number_format($altura,1,'.','') ?>%">
                            <div class="bar-tip">S/ <?= number_format($dato["total"],2) ?></div>
                        </div>
                        <div class="day"><?= h($dato["dia"]) ?></div>
                    </div>
                    <?php endforeach; ?>
                </div>
            </article>

            <article class="card">
                <div class="card-head">
                    <h2>Acciones rápidas</h2>
                </div>
                <div class="quick-actions">
                    <a class="quick blue" href="#gestion-productos">◇<span>Nuevo producto</span></a>
                    <a class="quick gold" href="categorias.php" target="_blank">◆<span>Categorías</span></a>
                    <a class="quick purple" href="usuarios.php" target="_blank">♙<span>Usuarios</span></a>
                    <a class="quick green" href="#pedidos">🛒<span>Ver pedidos</span></a>
                </div>
            </article>
        </section>

        <section class="grid-bottom">
            <article id="pedidos" class="card">
                <div class="card-head">
                    <h2>Pedidos recientes</h2>
                    <a href="pedidos.php" target="_blank">Ver todos →</a>
                </div>

                <div class="table-wrap">
                    <table>
                        <thead>
                            <tr><th>#</th><th>Cliente</th><th>Fecha</th><th>Estado</th><th>Total</th></tr>
                        </thead>
                        <tbody>
                        <?php if (!$pedidosRecientes): ?>
                            <tr><td colspan="5" style="text-align:center;color:#718096">Todavía no hay pedidos registrados.</td></tr>
                        <?php else: ?>
                            <?php foreach ($pedidosRecientes as $pedido):
                                $estado = strtolower($pedido["estado_pedido"]);
                                $clase = str_contains($estado,"cancel") ? "danger" : (str_contains($estado,"pend") || str_contains($estado,"proce") ? "info" : "ok");
                            ?>
                            <tr>
                                <td>#<?= h($pedido["id_pedido"]) ?></td>
                                <td><?= h($pedido["nombres"]." ".$pedido["apellidos"]) ?></td>
                                <td><?= h(date("d/m/Y",strtotime($pedido["fecha_pedido"]))) ?></td>
                                <td><span class="status <?= $clase ?>"><?= h($pedido["estado_pedido"]) ?></span></td>
                                <td class="price">S/ <?= number_format((float)$pedido["total"],2) ?></td>
                            </tr>
                            <?php endforeach; ?>
                        <?php endif; ?>
                        </tbody>
                    </table>
                </div>
            </article>

            <article class="card">
                <div class="card-head">
                    <h2>Productos más vendidos</h2>
                    <a href="#gestion-productos">Ver productos →</a>
                </div>
                <div class="top-list">
                    <?php if (!$masVendidos): ?>
                        <p style="font-size:12px;color:#718096">Todavía no hay productos registrados.</p>
                    <?php else: ?>
                        <?php foreach ($masVendidos as $i => $prod): ?>
                        <div class="top-product">
                            <div class="rank"><?= $i+1 ?></div>
                            <strong><?= h($prod["nombre_producto"]) ?></strong>
                            <span><?= (int)$prod["vendidos"] ?> vendidos</span>
                        </div>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </div>
            </article>
        </section>

        <section id="gestion-productos" class="card crud-section">
            <div class="crud-head">
                <div>
                    <div class="eyebrow">CRUD</div>
                    <h2><?= $productoEditar ? "Editar producto" : "Gestión de productos" ?></h2>
                </div>
                <span class="badge"><?= $productoEditar ? "UPDATE" : "CREATE · READ · UPDATE · DELETE" ?></span>
            </div>

            <form method="POST" class="product-form">
                <?php if ($productoEditar): ?>
                    <input type="hidden" name="id_producto" value="<?= h($productoEditar["id_producto"]) ?>">
                <?php endif; ?>

                <div class="field">
                    <label>NOMBRE DEL PRODUCTO</label>
                    <input type="text" name="nombre_producto" required value="<?= h($productoEditar["nombre_producto"] ?? "") ?>" placeholder="Ej. Kit de transmisión DTIEX">
                </div>

                <div class="field">
                    <label>CATEGORÍA</label>
                    <select name="id_categoria" required>
                        <option value="">Seleccione categoría</option>
                        <?php foreach ($categorias as $categoria): ?>
                            <option value="<?= h($categoria["id_categoria"]) ?>" <?= $productoEditar && (int)$productoEditar["id_categoria"] === (int)$categoria["id_categoria"] ? "selected" : "" ?>>
                                <?= h($categoria["nombre_categoria"]) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>

                <div class="field">
                    <label>MARCA</label>
                    <select name="id_marca" required>
                        <option value="">Seleccione marca</option>
                        <?php foreach ($marcas as $marca): ?>
                            <option value="<?= h($marca["id_marca"]) ?>" <?= $productoEditar && (int)$productoEditar["id_marca"] === (int)$marca["id_marca"] ? "selected" : "" ?>>
                                <?= h($marca["nombre_marca"]) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>

                <div class="field">
                    <label>PRECIO</label>
                    <input type="number" step="0.01" min="0" name="precio" required value="<?= h($productoEditar["precio"] ?? "") ?>" placeholder="0.00">
                </div>

                <div class="field">
                    <label>STOCK</label>
                    <input type="number" min="0" name="stock" required value="<?= h($productoEditar["stock"] ?? "") ?>" placeholder="0">
                </div>

                <div class="field">
                    <label>IMAGEN</label>
                    <input type="text" name="imagen_url" value="<?= h($productoEditar["imagen_url"] ?? "") ?>" placeholder="producto.png">
                </div>

                <div class="field full">
                    <label>DESCRIPCIÓN</label>
                    <textarea name="descripcion" placeholder="Descripción del repuesto"><?= h($productoEditar["descripcion"] ?? "") ?></textarea>
                </div>

                <div class="form-actions">
                    <?php if ($productoEditar): ?>
                        <button class="btn btn-gold" type="submit" name="actualizar_producto">Guardar cambios</button>
                        <a class="btn btn-light" href="dashboard.php#gestion-productos">Cancelar</a>
                    <?php else: ?>
                        <button class="btn btn-primary" type="submit" name="registrar_producto">+ Agregar producto</button>
                    <?php endif; ?>
                </div>
            </form>

            <div class="table-wrap">
                <table id="tablaProductos">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Producto</th>
                            <th>Categoría</th>
                            <th>Marca</th>
                            <th>Precio</th>
                            <th>Stock</th>
                            <th>Acciones</th>
                        </tr>
                    </thead>
                    <tbody>
                    <?php if (!$productos): ?>
                        <tr><td colspan="7" style="text-align:center;color:#718096">Todavía no existen productos.</td></tr>
                    <?php else: ?>
                        <?php foreach ($productos as $producto):
                            $stock = (int)$producto["stock"];
                            $stockClass = $stock <= 0 ? "zero" : ($stock <= 5 ? "low" : "good");
                        ?>
                        <tr data-search="<?= h(strtolower($producto["nombre_producto"]." ".$producto["nombre_categoria"]." ".$producto["nombre_marca"])) ?>">
                            <td>#P<?= str_pad((string)$producto["id_producto"],3,"0",STR_PAD_LEFT) ?></td>
                            <td><strong><?= h($producto["nombre_producto"]) ?></strong><br><span style="color:#718096;font-size:9px"><?= h($producto["descripcion"]) ?></span></td>
                            <td><?= h($producto["nombre_categoria"]) ?></td>
                            <td><?= h($producto["nombre_marca"]) ?></td>
                            <td class="price">S/ <?= number_format((float)$producto["precio"],2) ?></td>
                            <td><span class="stock <?= $stockClass ?>"><?= $stock ?></span></td>
                            <td>
                                <div class="actions">
                                    <a class="action-btn edit" title="Editar" href="dashboard.php?editar=<?= h($producto["id_producto"]) ?>#gestion-productos">✎</a>
                                    <form method="POST" onsubmit="return confirm('¿Seguro que deseas eliminar este producto?');">
                                        <input type="hidden" name="id_producto" value="<?= h($producto["id_producto"]) ?>">
                                        <button class="action-btn delete" title="Eliminar" type="submit" name="eliminar_producto">⌫</button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                    </tbody>
                </table>
            </div>
        </section>

    </div>
</main>
</div>

<nav class="mobile-bottom">
    <a href="#inicio" class="active"><span>⌂</span><b>Dashboard</b></a>
    <a href="#gestion-productos"><span>◇</span><b>Productos</b></a>
    <a href="#pedidos"><span>🛒</span><b>Pedidos</b></a>
    <a href="#ventas"><span>☰</span><b>Más</b></a>
</nav>

<script>
const buscador = document.getElementById('buscador');
const filas = document.querySelectorAll('#tablaProductos tbody tr[data-search]');

if (buscador) {
    buscador.addEventListener('input', function () {
        const texto = this.value.toLowerCase().trim();
        filas.forEach(fila => {
            fila.style.display = fila.dataset.search.includes(texto) ? '' : 'none';
        });
    });
}
</script>
</body>
</html>