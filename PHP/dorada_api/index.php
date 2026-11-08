<?php
$host = getenv("DB_HOST") ?: "localhost";
$user = getenv("DB_USER") ?: "root";
$pass = getenv("DB_PASS") ?: "";
$port = (int)(getenv("DB_PORT") ?: 3306);

$destino = "instalar.php";

try {
    $db = @new mysqli($host,$user,$pass,"dorada_motors",$port);

    if (!$db->connect_error) {
        $db->set_charset("utf8mb4");
        $resultado = $db->query("SHOW TABLES LIKE 'producto'");

        if ($resultado && $resultado->num_rows > 0) {
            $destino = "dashboard.php";
        }
    }
} catch (Throwable $e) {
    $destino = "instalar.php";
}

header("Location: " . $destino);
exit;
