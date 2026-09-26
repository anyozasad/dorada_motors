<?php
header("Content-Type: text/html; charset=UTF-8");

$host = getenv("DB_HOST") ?: "localhost";
$user = getenv("DB_USER") ?: "root";
$pass = getenv("DB_PASS") ?: "";
$port = (int)(getenv("DB_PORT") ?: 3306);

$ok = false;
$error = "";

try {
    $db = new mysqli($host,$user,$pass,"",$port);

    if ($db->connect_error) {
        throw new RuntimeException("No se pudo conectar con MySQL: " . $db->connect_error);
    }

    $db->set_charset("utf8mb4");

    $sql = file_get_contents(__DIR__ . "/dorada_motors.sql");
    if ($sql === false) {
        throw new RuntimeException("No se encontró dorada_motors.sql");
    }

    if (!$db->multi_query($sql)) {
        throw new RuntimeException($db->error);
    }

    do {
        if ($resultado = $db->store_result()) {
            $resultado->free();
        }
    } while ($db->more_results() && $db->next_result());

    if ($db->errno) {
        throw new RuntimeException($db->error);
    }

    $ok = true;
} catch (Throwable $e) {
    $error = $e->getMessage();
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Dorada Motors | Instalación</title>
<style>
*{box-sizing:border-box}body{margin:0;font-family:Inter,Segoe UI,Arial,sans-serif;background:#f4f6f9;color:#171b22;min-height:100vh;display:grid;place-items:center;padding:24px}.card{width:min(650px,100%);background:#fff;border:1px solid #e4e7ec;border-radius:22px;padding:30px;box-shadow:0 22px 65px rgba(20,26,35,.1)}.logo{width:84px;height:84px;border-radius:18px;object-fit:cover}.eyebrow{margin-top:18px;color:#e35e19;font-weight:900;font-size:11px;letter-spacing:.9px}.title{font-size:28px;margin:6px 0}.msg{padding:15px;border-radius:13px;margin:18px 0;line-height:1.5}.ok{background:#e9f8f0;color:#147a52;border:1px solid #cbeedc}.error{background:#fff0ee;color:#aa3525;border:1px solid #ffd6cf}.btn{display:inline-flex;text-decoration:none;padding:12px 17px;border-radius:11px;background:linear-gradient(90deg,#ff6a00,#c92b18);color:#fff;font-weight:900}.list{margin:18px 0;padding:0;list-style:none;display:grid;gap:8px}.list li{padding:10px 12px;border:1px solid #e6e9ee;border-radius:10px;background:#fafbfc;font-size:12px}.small{color:#747c87;font-size:11px;line-height:1.5}
</style>
</head>
<body>
<div class="card">
 <img class="logo" src="logo_adn_imports.png" alt="ADN Import's">
 <div class="eyebrow">ADN IMPORT'S · DORADA MOTORS</div>
 <h1 class="title">Preparar base de datos</h1>

 <?php if($ok): ?>
  <div class="msg ok"><strong>✓ Base de datos lista.</strong><br>Se creó/verificó <b>dorada_motors</b> con 13 tablas principales, categorías y marcas iniciales.</div>
  <ul class="list">
   <li>✓ Usuarios y direcciones</li>
   <li>✓ Productos, categorías y marcas</li>
   <li>✓ Pedidos, detalle y pagos</li>
   <li>✓ Proveedores, compras y detalle de compra</li>
   <li>✓ Movimientos de stock / Kardex</li>
   <li>✓ Comprobantes</li>
  </ul>
  <a class="btn" href="dashboard.php">Abrir Dashboard</a>
 <?php else: ?>
  <div class="msg error"><strong>No se pudo preparar la base.</strong><br><?= htmlspecialchars($error,ENT_QUOTES,"UTF-8") ?></div>
  <p class="small">Verifica que MySQL esté encendido en XAMPP y que el usuario local sea root sin contraseña, o configura las variables DB_USER y DB_PASS.</p>
 <?php endif; ?>
</div>
</body>
</html>
