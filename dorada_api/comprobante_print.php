<?php
require_once "conexion.php";
require_once "auth_admin.php";
header("Content-Type: text/html; charset=UTF-8");

requerirAdmin();

$id = (int)($_GET["id"] ?? 0);

$stmt = $conexion->prepare("
    SELECT
        c.*,
        p.fecha_pedido,
        p.tipo_entrega,
        u.nombres,
        u.apellidos,
        u.correo,
        u.telefono
    FROM comprobante c
    INNER JOIN pedido p ON c.id_pedido=p.id_pedido
    INNER JOIN usuario u ON p.id_usuario=u.id_usuario
    WHERE c.id_comprobante=?
    LIMIT 1
");
$stmt->bind_param("i",$id);
$stmt->execute();
$comprobante = $stmt->get_result()->fetch_assoc();

if (!$comprobante) {
    http_response_code(404);
    exit("Comprobante no encontrado");
}

$stmt = $conexion->prepare("
    SELECT dp.cantidad,dp.precio_unitario,pr.nombre_producto
    FROM detalle_pedido dp
    INNER JOIN producto pr ON dp.id_producto=pr.id_producto
    WHERE dp.id_pedido=?
    ORDER BY dp.id_detalle
");
$stmt->bind_param("i",$comprobante["id_pedido"]);
$stmt->execute();
$items = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

$config = $conexion->query("
    SELECT * FROM configuracion_empresa
    WHERE id_configuracion=1
")->fetch_assoc() ?: [];

registrarBitacora(
    $conexion,
    "comprobantes",
    "Imprimir comprobante",
    "Comprobante #" . $id . " - " . $comprobante["numero_comprobante"]
);

function e($v): string {
    return htmlspecialchars((string)$v, ENT_QUOTES, "UTF-8");
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title><?= e($comprobante["tipo_comprobante"]) ?> <?= e($comprobante["numero_comprobante"]) ?></title>
<style>
*{box-sizing:border-box}body{margin:0;background:#eef1f5;font-family:Arial,sans-serif;color:#171a20;padding:28px}.sheet{width:min(820px,100%);margin:auto;background:#fff;border-radius:18px;box-shadow:0 18px 55px rgba(20,25,35,.12);padding:34px}.head{display:flex;justify-content:space-between;gap:24px;align-items:flex-start;border-bottom:2px solid #f06a22;padding-bottom:22px}.brand{display:flex;gap:15px;align-items:center}.brand img{width:88px;height:88px;object-fit:cover;border-radius:16px}.brand h1{margin:0;font-size:24px}.brand p{margin:5px 0 0;color:#6f7782;font-size:12px;line-height:1.5}.doc{text-align:right}.doc span{display:inline-block;padding:7px 10px;border-radius:999px;background:#fff0e5;color:#c14417;font-size:10px;font-weight:800}.doc h2{margin:9px 0 3px;font-size:21px}.doc small{color:#747b86}.info{display:grid;grid-template-columns:1fr 1fr;gap:15px;margin:22px 0}.box{border:1px solid #e5e8ee;border-radius:13px;padding:14px}.box small{display:block;color:#818893;font-size:9px;font-weight:800;letter-spacing:.7px;margin-bottom:5px}.box strong{font-size:13px}.box p{margin:4px 0 0;color:#707782;font-size:11px}.table{width:100%;border-collapse:collapse;margin-top:12px}.table th{font-size:9px;text-transform:uppercase;letter-spacing:.6px;color:#707782;text-align:left;background:#f7f8fa;padding:11px}.table td{padding:12px 11px;border-bottom:1px solid #eceff3;font-size:11px}.num{text-align:right}.totals{margin-left:auto;margin-top:18px;width:min(320px,100%)}.total-row{display:flex;justify-content:space-between;padding:7px 0;font-size:12px}.total-row.final{margin-top:7px;padding-top:12px;border-top:2px solid #171a20;font-size:17px;font-weight:900}.footer{margin-top:28px;padding-top:16px;border-top:1px dashed #d8dce2;text-align:center;color:#737a84;font-size:10px;line-height:1.6}.actions{display:flex;justify-content:center;gap:10px;margin:20px auto 0}.btn{border:0;border-radius:11px;padding:11px 16px;font-weight:800;cursor:pointer;text-decoration:none}.print{background:#161a21;color:#fff}.back{background:#fff;border:1px solid #dfe3e8;color:#171a20}@media print{body{background:#fff;padding:0}.sheet{width:100%;box-shadow:none;border-radius:0;padding:12mm}.actions{display:none}}
</style>
</head>
<body>
<div class="sheet">
 <div class="head">
  <div class="brand">
   <img src="<?= e($config["logo"] ?? "logo_adn_imports.png") ?>" alt="Logo">
   <div>
    <h1><?= e($config["razon_social"] ?? "ADN Import's") ?></h1>
    <p><?= e($config["nombre_comercial"] ?? "Dorada Motors") ?><br>
    RUC: <?= e($config["ruc"] ?? "No configurado") ?><br>
    <?= e($config["direccion"] ?? "") ?></p>
   </div>
  </div>
  <div class="doc">
   <span><?= e(strtoupper($comprobante["tipo_comprobante"])) ?></span>
   <h2><?= e($comprobante["numero_comprobante"]) ?></h2>
   <small><?= e($comprobante["fecha_emision"]) ?></small>
  </div>
 </div>

 <div class="info">
  <div class="box"><small>CLIENTE</small><strong><?= e($comprobante["nombres"]." ".$comprobante["apellidos"]) ?></strong><p><?= e($comprobante["correo"]) ?><br><?= e($comprobante["telefono"]) ?></p></div>
  <div class="box"><small>PEDIDO</small><strong>#<?= e($comprobante["id_pedido"]) ?></strong><p>Fecha: <?= e($comprobante["fecha_pedido"]) ?><br>Entrega: <?= e($comprobante["tipo_entrega"] ?? "") ?></p></div>
 </div>

 <table class="table">
  <thead><tr><th>Producto</th><th>Cantidad</th><th class="num">Precio</th><th class="num">Subtotal</th></tr></thead>
  <tbody>
   <?php foreach($items as $item): ?>
   <tr><td><?= e($item["nombre_producto"]) ?></td><td><?= (int)$item["cantidad"] ?></td><td class="num">S/ <?= number_format((float)$item["precio_unitario"],2) ?></td><td class="num">S/ <?= number_format((float)$item["precio"]*(int)$item["cantidad"],2) ?></td></tr>
   <?php endforeach; ?>
  </tbody>
 </table>

 <div class="totals">
  <div class="total-row"><span>Subtotal</span><strong>S/ <?= number_format((float)$comprobante["subtotal"],2) ?></strong></div>
  <div class="total-row"><span>IGV <?= number_format((float)($config["igv"]??18),2) ?>%</span><strong>S/ <?= number_format((float)$comprobante["igv"],2) ?></strong></div>
  <div class="total-row final"><span>Total</span><span>S/ <?= number_format((float)$comprobante["total"],2) ?></span></div>
 </div>

 <div class="footer">
  <?= e($config["telefono"] ?? "") ?> · <?= e($config["correo"] ?? "") ?><br>
  Gracias por confiar en <?= e($config["nombre_comercial"] ?? "Dorada Motors") ?>.
 </div>
</div>
<div class="actions"><button class="btn print" onclick="window.print()">Imprimir / Guardar PDF</button><a class="btn back" href="dashboard.php#comprobantes">Volver</a></div>
</body>
</html>
