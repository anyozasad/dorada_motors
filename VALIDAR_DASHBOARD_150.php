<?php
declare(strict_types=1);

$archivo = __DIR__ . "/dorada_api/dashboard.php";
$control = __DIR__ . "/CONTROL_150_FUNCIONES.txt";

if (!is_file($archivo) || !is_file($control)) {
    fwrite(STDERR, "[ERROR] Faltan archivos del dashboard o control 150\n");
    exit(1);
}

$codigo = file_get_contents($archivo);
$lista = file_get_contents($control);

$checks = [
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
    "tablaProductos","tablaClientes","tablaDirecciones","tablaPedidos",
    "tablaPagos","tablaKardex","tablaCompras","tablaReporteProductos",
    "actualizarDashboardEnVivo","exportarTabla","filtroEstadoPedido",
    "filtroCategoriaProducto","filtroStockProducto",
    "Cancelado","Procesando","Pagado","Enviado","Completado",
    "Anulado","Delivery","Recojo en tienda","GROUP_CONCAT","precio_oferta","saldo","sincronizarEstadoFinancieroPedido","compraItems","pedidoItems"
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
echo "REQUERIMIENTOS_DASHBOARD: 150/150" . PHP_EOL;
exit(0);
