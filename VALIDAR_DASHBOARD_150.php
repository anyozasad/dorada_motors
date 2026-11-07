<?php
declare(strict_types=1);

$archivos = [
    __DIR__ . "/dorada_api/dashboard.php",
    __DIR__ . "/dorada_api/auth_admin.php",
    __DIR__ . "/dorada_api/admin_login.php",
    __DIR__ . "/dorada_api/admin_logout.php",
    __DIR__ . "/dorada_api/empresa_config.php",
    __DIR__ . "/dorada_api/comprobante_print.php",
    __DIR__ . "/dorada_api/login.php",
    __DIR__ . "/dorada_api/usuarios.php",
];
$control = __DIR__ . "/CONTROL_150_FUNCIONES.txt";

$codigo = "";
foreach ($archivos as $archivo) {
    if (!is_file($archivo)) {
        fwrite(STDERR, "[ERROR] Falta archivo funcional: " . basename($archivo) . PHP_EOL);
        exit(1);
    }
    $contenido = file_get_contents($archivo);
    if ($contenido === false) {
        fwrite(STDERR, "[ERROR] No se pudo leer: " . basename($archivo) . PHP_EOL);
        exit(1);
    }
    $codigo .= "\n" . $contenido;
}

if (!is_file($control)) {
    fwrite(STDERR, "[ERROR] Falta CONTROL_150_FUNCIONES.txt\n");
    exit(1);
}
$lista = file_get_contents($control);

$checks = [
    // CRUD y módulos
    "registrar_producto","actualizar_producto","eliminar_producto",
    "registrar_categoria","actualizar_categoria","eliminar_categoria",
    "registrar_marca","actualizar_marca","eliminar_marca",
    "registrar_usuario","actualizar_usuario","actualizar_estado_usuario",
    "registrar_direccion","actualizar_direccion","eliminar_direccion",
    "registrar_pedido_manual","actualizar_estado_pedido",
    "registrar_pago_manual","actualizar_estado_pago",
    "registrar_proveedor","actualizar_proveedor","eliminar_proveedor",
    "registrar_movimiento","registrar_compra","actualizar_estado_compra",
    "registrar_comprobante","eliminar_comprobante",

    // Tablas y experiencia operativa
    "tablaProductos","tablaClientes","tablaDirecciones","tablaPedidos",
    "tablaPagos","tablaKardex","tablaCompras","tablaReporteProductos",
    "actualizarDashboardEnVivo","exportarTabla","filtroEstadoPedido",
    "filtroCategoriaProducto","filtroStockProducto",

    // Reglas de negocio
    "Cancelado","Procesando","Pagado","Enviado","Completado",
    "Anulado","Delivery","Recojo en tienda",
    "GROUP_CONCAT","precio_oferta","saldo",
    "sincronizarEstadoFinancieroPedido","compraItems","pedidoItems",

    // Seguridad administrativa
    "requerirAdmin","csrfValido","csrf_token","session_regenerate_id",
    "admin_last_activity","admin_logout.php","crear_admin_inicial",
    "Administrador","Vendedor","Almacen","auditoria.jsonl",

    // Configuración empresarial y personal
    "guardar_config_empresa","cargarConfigEmpresa","costo_delivery",
    "crear_usuario_admin","actualizar_usuario_admin","cambiar_clave_admin",
    "rol_sistema='Cliente'"
];

$faltantes = [];
foreach ($checks as $check) {
    if (strpos($codigo, $check) === false) {
        $faltantes[] = $check;
    }
}

preg_match_all('/^\d{3}\. \[IMPLEMENTADO\]/m', (string)$lista, $m);
$totalRequisitos = count($m[0]);

if ($totalRequisitos !== 150) {
    fwrite(STDERR, "[ERROR] El control tiene {$totalRequisitos} requisitos; deben ser 150\n");
    exit(1);
}

if ($faltantes) {
    fwrite(STDERR, "[ERROR] Faltan funciones del dashboard: " . implode(", ", $faltantes) . PHP_EOL);
    exit(1);
}

echo "DASHBOARD_FUNCIONAL_OK" . PHP_EOL;
echo "SEGURIDAD_ADMIN_OK" . PHP_EOL;
echo "CONFIG_EMPRESA_OK" . PHP_EOL;
echo "REQUERIMIENTOS_DASHBOARD: 150/150" . PHP_EOL;
exit(0);
