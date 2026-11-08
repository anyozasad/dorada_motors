<?php
require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/auth_admin.php";

header("Content-Type: text/html; charset=UTF-8");

if (adminActual()) {
    header("Location: dashboard.php");
    exit;
}

$mensaje = "";
$tipo = "error";
$next = limpiarNext((string)($_GET["next"] ?? $_POST["next"] ?? "dashboard.php"));

$totalAdmins = (int)$conexion->query("
    SELECT COUNT(*) AS total
    FROM usuario
    WHERE rol_sistema IN ('Administrador','Vendedor','Almacen')
")->fetch_assoc()["total"];

$modoInicial = $totalAdmins === 0;

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    if (!csrfValido($_POST["csrf_token"] ?? null)) {
        $mensaje = "La sesión del formulario venció. Actualiza la página.";
    } elseif ($modoInicial && isset($_POST["crear_admin_inicial"])) {
        $nombres = trim((string)($_POST["nombres"] ?? ""));
        $apellidos = trim((string)($_POST["apellidos"] ?? ""));
        $correo = strtolower(trim((string)($_POST["correo"] ?? "")));
        $clave = (string)($_POST["contrasena"] ?? "");
        $confirmar = (string)($_POST["confirmar_contrasena"] ?? "");

        if ($nombres === "" || !filter_var($correo, FILTER_VALIDATE_EMAIL)) {
            $mensaje = "Completa nombre y correo válidos.";
        } elseif (strlen($clave) < 8) {
            $mensaje = "La contraseña debe tener mínimo 8 caracteres.";
        } elseif ($clave !== $confirmar) {
            $mensaje = "Las contraseñas no coinciden.";
        } else {
            $stmt = $conexion->prepare("SELECT id_usuario FROM usuario WHERE correo=? LIMIT 1");
            $stmt->bind_param("s",$correo);
            $stmt->execute();

            if ($stmt->get_result()->fetch_assoc()) {
                $mensaje = "Ese correo ya está registrado. Usa otro para el administrador.";
            } else {
                $hash = password_hash($clave, PASSWORD_DEFAULT);
                $telefono = "";
                $estado = "Activo";
                $rol = "Administrador";

                $stmt = $conexion->prepare("
                    INSERT INTO usuario
                    (nombres,apellidos,correo,contrasena,telefono,estado,rol_sistema,ultimo_acceso)
                    VALUES (?,?,?,?,?,?,?,NOW())
                ");
                $stmt->bind_param("sssssss",$nombres,$apellidos,$correo,$hash,$telefono,$estado,$rol);
                $stmt->execute();
                $id = (int)$conexion->insert_id;

                session_regenerate_id(true);
                $_SESSION["admin_last_activity"] = time();
                $_SESSION["admin"] = [
                    "id_admin" => $id,
                    "id_usuario" => $id,
                    "nombres" => trim($nombres . " " . $apellidos),
                    "correo" => $correo,
                    "rol" => $rol,
                ];

                header("Location: dashboard.php?msg=" . urlencode("Administrador inicial creado correctamente") . "&tipo=ok");
                exit;
            }
        }
    } elseif (!$modoInicial && isset($_POST["iniciar_admin"])) {
        $correo = strtolower(trim((string)($_POST["correo"] ?? "")));
        $clave = (string)($_POST["contrasena"] ?? "");

        $stmt = $conexion->prepare("
            SELECT id_usuario,nombres,apellidos,correo,contrasena,estado,rol_sistema
            FROM usuario
            WHERE correo=?
              AND rol_sistema IN ('Administrador','Vendedor','Almacen')
            LIMIT 1
        ");
        $stmt->bind_param("s",$correo);
        $stmt->execute();
        $admin = $stmt->get_result()->fetch_assoc();

        if (!$admin || (string)$admin["estado"] !== "Activo" || !password_verify($clave,(string)$admin["contrasena"])) {
            $mensaje = "Correo o contraseña incorrectos.";
        } else {
            $id = (int)$admin["id_usuario"];
            $stmt = $conexion->prepare("UPDATE usuario SET ultimo_acceso=NOW() WHERE id_usuario=?");
            $stmt->bind_param("i",$id);
            $stmt->execute();

            session_regenerate_id(true);
            $_SESSION["admin_last_activity"] = time();
            $_SESSION["admin"] = [
                "id_admin" => $id,
                "id_usuario" => $id,
                "nombres" => trim($admin["nombres"] . " " . $admin["apellidos"]),
                "correo" => $admin["correo"],
                "rol" => $admin["rol_sistema"],
            ];

            header("Location: " . $next);
            exit;
        }
    }
}

if (isset($_GET["logout"])) {
    $mensaje = "Sesión cerrada correctamente.";
    $tipo = "ok";
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Dorada Motors | Acceso administrativo</title>
<style>
*{box-sizing:border-box}body{margin:0;min-height:100vh;display:grid;place-items:center;background:#f4f7fb;font-family:Inter,Segoe UI,Arial,sans-serif;color:#18243a;padding:24px}.box{width:min(440px,100%);background:#fff;border:1px solid #e5eaf1;border-radius:20px;box-shadow:0 20px 55px rgba(15,39,70,.12);padding:28px}.brand{display:flex;align-items:center;gap:13px;margin-bottom:24px}.brand img{width:62px;height:62px;object-fit:cover;border-radius:15px}.brand h1{margin:0;font-size:21px}.brand p{margin:4px 0 0;color:#718096;font-size:12px}.notice{padding:11px 13px;border-radius:11px;margin-bottom:15px;font-size:12px;background:#ffe8ea;color:#b42335}.notice.ok{background:#ddf7eb;color:#117a52}.field{margin-bottom:13px}.field label{display:block;font-size:10px;font-weight:900;margin-bottom:6px;color:#5f6c80}.field input{width:100%;border:1px solid #dfe5ec;border-radius:11px;padding:12px 13px;outline:none}.field input:focus{border-color:#ff6a00;box-shadow:0 0 0 3px rgba(255,106,0,.10)}button{width:100%;border:0;border-radius:12px;padding:13px;background:#151820;color:#fff;font-weight:900;cursor:pointer}.hint{font-size:11px;color:#718096;line-height:1.5;margin:0 0 18px}.secure{margin-top:14px;text-align:center;font-size:10px;color:#8b95a5}
</style>
</head>
<body>
<div class="box">
 <div class="brand">
  <img src="logo_adn_imports.png" alt="ADN Import's">
  <div><h1>Dorada Motors</h1><p>Panel administrativo seguro</p></div>
 </div>

 <?php if($mensaje!==""): ?><div class="notice <?= $tipo==="ok"?"ok":"" ?>"><?= htmlspecialchars($mensaje,ENT_QUOTES,"UTF-8") ?></div><?php endif; ?>

 <?php if($modoInicial): ?>
  <p class="hint">Primera configuración: crea la cuenta principal del administrador. Esta cuenta tendrá acceso completo al dashboard.</p>
  <form method="POST">
   <?= csrfInput() ?>
   <input type="hidden" name="next" value="<?= htmlspecialchars($next,ENT_QUOTES,"UTF-8") ?>">
   <div class="field"><label>NOMBRES</label><input name="nombres" required autocomplete="given-name"></div>
   <div class="field"><label>APELLIDOS</label><input name="apellidos" autocomplete="family-name"></div>
   <div class="field"><label>CORREO ADMINISTRATIVO</label><input type="email" name="correo" required autocomplete="username"></div>
   <div class="field"><label>CONTRASEÑA</label><input type="password" name="contrasena" minlength="8" required autocomplete="new-password"></div>
   <div class="field"><label>CONFIRMAR CONTRASEÑA</label><input type="password" name="confirmar_contrasena" minlength="8" required autocomplete="new-password"></div>
   <button name="crear_admin_inicial">Crear administrador y entrar</button>
  </form>
 <?php else: ?>
  <p class="hint">Ingresa con una cuenta de Administrador, Vendedor o Almacén.</p>
  <form method="POST">
   <?= csrfInput() ?>
   <input type="hidden" name="next" value="<?= htmlspecialchars($next,ENT_QUOTES,"UTF-8") ?>">
   <div class="field"><label>CORREO</label><input type="email" name="correo" required autocomplete="username"></div>
   <div class="field"><label>CONTRASEÑA</label><input type="password" name="contrasena" required autocomplete="current-password"></div>
   <button name="iniciar_admin">Iniciar sesión</button>
  </form>
 <?php endif; ?>

 <div class="secure">Sesión protegida · CSRF · Roles administrativos</div>
</div>
</body>
</html>
