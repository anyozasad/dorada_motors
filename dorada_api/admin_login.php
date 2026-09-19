<?php
require_once "conexion.php";
require_once "sistema_bootstrap.php";

if (session_status() !== PHP_SESSION_ACTIVE) {
    session_name("adn_admin_session");
    session_set_cookie_params([
        "httponly" => true,
        "secure" => (!empty($_SERVER["HTTPS"]) && $_SERVER["HTTPS"] !== "off"),
        "samesite" => "Lax",
        "path" => "/",
    ]);
    session_start();
}

if (!empty($_SESSION["admin"])) {
    header("Location: dashboard.php");
    exit;
}

$mensaje = "";
$tipo = "error";
$totalAdmins = (int)$conexion->query("SELECT COUNT(*) AS total FROM admin_usuario")->fetch_assoc()["total"];
$esPrimerAcceso = $totalAdmins === 0;

if (empty($_SESSION["csrf_login"])) {
    $_SESSION["csrf_login"] = bin2hex(random_bytes(32));
}

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $token = $_POST["csrf_token"] ?? "";
    if (!hash_equals($_SESSION["csrf_login"], (string)$token)) {
        $mensaje = "La sesión del formulario venció. Vuelve a intentarlo.";
    } elseif ($esPrimerAcceso && isset($_POST["crear_admin"])) {
        $nombres = trim($_POST["nombres"] ?? "");
        $correo = strtolower(trim($_POST["correo"] ?? ""));
        $clave = $_POST["contrasena"] ?? "";

        if ($nombres === "" || !filter_var($correo, FILTER_VALIDATE_EMAIL) || strlen($clave) < 8) {
            $mensaje = "Completa los datos. La contraseña debe tener mínimo 8 caracteres.";
        } else {
            $hash = password_hash($clave, PASSWORD_DEFAULT);
            $rol = "Administrador";
            $estado = "Activo";
            $stmt = $conexion->prepare("
                INSERT INTO admin_usuario (nombres,correo,contrasena,rol,estado)
                VALUES (?,?,?,?,?)
            ");
            $stmt->bind_param("sssss",$nombres,$correo,$hash,$rol,$estado);
            if ($stmt->execute()) {
                session_regenerate_id(true);
                $_SESSION["admin"] = [
                    "id_admin" => $conexion->insert_id,
                    "nombres" => $nombres,
                    "correo" => $correo,
                    "rol" => $rol,
                ];
                header("Location: dashboard.php");
                exit;
            }
            $mensaje = "No se pudo crear el administrador.";
        }
    } elseif (!$esPrimerAcceso && isset($_POST["iniciar_admin"])) {
        $correo = strtolower(trim($_POST["correo"] ?? ""));
        $clave = $_POST["contrasena"] ?? "";

        $stmt = $conexion->prepare("
            SELECT id_admin,nombres,correo,contrasena,rol,estado
            FROM admin_usuario
            WHERE correo=?
            LIMIT 1
        ");
        $stmt->bind_param("s",$correo);
        $stmt->execute();
        $admin = $stmt->get_result()->fetch_assoc();

        if (!$admin || $admin["estado"] !== "Activo" || !password_verify($clave, $admin["contrasena"])) {
            $mensaje = "Correo o contraseña incorrectos.";
        } else {
            session_regenerate_id(true);
            $_SESSION["admin"] = [
                "id_admin" => (int)$admin["id_admin"],
                "nombres" => $admin["nombres"],
                "correo" => $admin["correo"],
                "rol" => $admin["rol"],
            ];
            $conexion->query("UPDATE admin_usuario SET ultimo_acceso=NOW() WHERE id_admin=".(int)$admin["id_admin"]);
            header("Location: dashboard.php");
            exit;
        }
    }
}

$config = $conexion->query("SELECT * FROM configuracion_empresa WHERE id_configuracion=1")->fetch_assoc();
$logo = $config["logo"] ?? "logo_adn_imports.png";
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title><?= htmlspecialchars($config["nombre_comercial"] ?? "Dorada Motors") ?> | Acceso</title>
<style>
:root{--bg:#f3f5f8;--ink:#151820;--muted:#727986;--red:#c92b18;--orange:#ff6a00;--line:#e5e8ee}
*{box-sizing:border-box}body{margin:0;font-family:Inter,Segoe UI,Arial,sans-serif;background:radial-gradient(circle at 15% 15%,rgba(255,106,0,.11),transparent 24%),radial-gradient(circle at 90% 80%,rgba(201,43,24,.08),transparent 30%),var(--bg);color:var(--ink);min-height:100vh;display:grid;place-items:center;padding:24px}
.shell{width:min(980px,100%);display:grid;grid-template-columns:1.05fr .95fr;background:#fff;border:1px solid var(--line);border-radius:28px;overflow:hidden;box-shadow:0 24px 70px rgba(16,22,30,.12)}
.brand{background:linear-gradient(145deg,#11151b,#252a33);color:#fff;padding:44px;display:flex;flex-direction:column;justify-content:space-between;min-height:620px}
.logo{width:132px;height:132px;object-fit:cover;border-radius:24px;border:1px solid rgba(255,255,255,.14);box-shadow:0 20px 50px rgba(0,0,0,.28)}
.brand h1{font-size:38px;line-height:1;margin:22px 0 12px}.brand h1 span{color:var(--orange)}.brand p{color:#c8cdd5;line-height:1.6;max-width:420px}
.points{display:grid;gap:12px;margin-top:30px}.point{display:flex;gap:10px;align-items:center;font-size:13px;color:#e4e7ec}.dot{width:28px;height:28px;border-radius:9px;background:rgba(255,106,0,.15);color:#ff8a39;display:grid;place-items:center;font-weight:900}
.form-side{padding:44px;display:flex;flex-direction:column;justify-content:center}.eyebrow{font-size:11px;font-weight:900;letter-spacing:1px;color:var(--orange);text-transform:uppercase}.form-side h2{font-size:30px;margin:8px 0}.sub{color:var(--muted);margin:0 0 26px;line-height:1.5}
.alert{padding:12px 14px;border-radius:12px;background:#fff0ee;color:#9e281c;border:1px solid #ffd3ce;font-size:12px;margin-bottom:14px}
label{font-size:11px;font-weight:800;color:#4f5661;display:block;margin:12px 0 6px}input,select{width:100%;height:50px;border:1px solid var(--line);border-radius:13px;padding:0 14px;outline:none;background:#fafbfc}input:focus{border-color:#ff6a00;box-shadow:0 0 0 3px rgba(255,106,0,.09)}
button{width:100%;height:52px;border:0;border-radius:14px;background:linear-gradient(90deg,#ff6a00,#c92b18);color:#fff;font-weight:900;margin-top:18px;cursor:pointer}.hint{font-size:11px;color:var(--muted);line-height:1.5;margin-top:15px}.tag{display:inline-flex;margin-top:14px;padding:7px 10px;border-radius:999px;background:#fff0e5;color:#b34213;font-size:10px;font-weight:900}
@media(max-width:760px){body{padding:0}.shell{grid-template-columns:1fr;border-radius:0;min-height:100vh}.brand{min-height:auto;padding:28px}.brand .points{display:none}.logo{width:86px;height:86px}.brand h1{font-size:27px}.form-side{padding:28px}}
</style>
</head>
<body>
<div class="shell">
 <section class="brand">
  <div>
   <img class="logo" src="<?= htmlspecialchars($logo) ?>" alt="ADN Import's">
   <h1>ADN <span>IMPORT'S</span></h1>
   <p>Dorada Motors · Sistema de gestión de ventas, inventario y repuestos para moto y motokar.</p>
   <div class="points">
    <div class="point"><span class="dot">✓</span>Control de ventas y pedidos</div>
    <div class="point"><span class="dot">✓</span>Inventario y abastecimiento</div>
    <div class="point"><span class="dot">✓</span>Reportes y auditoría</div>
   </div>
  </div>
  <small>Panel administrativo protegido</small>
 </section>
 <section class="form-side">
  <?php if($esPrimerAcceso): ?>
   <div class="eyebrow">Primer acceso</div>
   <h2>Crea el administrador</h2>
   <p class="sub">Este usuario tendrá acceso total al panel. Después podrás crear cuentas de vendedor y almacén.</p>
  <?php else: ?>
   <div class="eyebrow">Acceso seguro</div>
   <h2>Bienvenido</h2>
   <p class="sub">Ingresa con una cuenta administrativa para continuar.</p>
  <?php endif; ?>

  <?php if($mensaje): ?><div class="alert"><?= htmlspecialchars($mensaje) ?></div><?php endif; ?>

  <form method="POST" autocomplete="on">
   <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION["csrf_login"]) ?>">
   <?php if($esPrimerAcceso): ?>
    <label>NOMBRE DEL ADMINISTRADOR</label>
    <input name="nombres" required placeholder="Administrador ADN">
   <?php endif; ?>
   <label>CORREO</label>
   <input type="email" name="correo" required placeholder="admin@adnimports.pe" autocomplete="username">
   <label>CONTRASEÑA</label>
   <input type="password" name="contrasena" required minlength="<?= $esPrimerAcceso ? 8 : 1 ?>" placeholder="••••••••" autocomplete="<?= $esPrimerAcceso ? "new-password" : "current-password" ?>">
   <button name="<?= $esPrimerAcceso ? "crear_admin" : "iniciar_admin" ?>">
    <?= $esPrimerAcceso ? "CREAR ADMINISTRADOR" : "INICIAR SESIÓN" ?>
   </button>
  </form>
  <div class="tag"><?= $esPrimerAcceso ? "Configuración inicial" : "PHP + MySQL" ?></div>
  <p class="hint">El acceso de clientes de Flutter es independiente del acceso administrativo de este panel.</p>
 </section>
</div>
</body>
</html>
