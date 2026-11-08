<?php
declare(strict_types=1);

// Exportación real de registros MySQL. No exporta solamente las filas
// actualmente visibles ni permite abrir datos administrativos sin sesión.
require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/auth_admin.php";
requerirAdmin();

$tipo = (string)($_GET["tipo"] ?? "");
$definiciones = [
    "productos" => [
        "permiso"=>"gestion-productos",
        "sql"=>"SELECT p.id_producto AS ID,p.nombre_producto AS Producto,
                c.nombre_categoria AS Categoria,m.nombre_marca AS Marca,
                p.tipo_vehiculo AS Vehiculo,p.compatibilidad AS Compatibilidad,
                p.precio AS Precio,p.precio_oferta AS Oferta,
                p.stock AS Stock,p.stock_minimo AS Stock_minimo
                FROM producto p
                JOIN categoria c ON c.id_categoria=p.id_categoria
                JOIN marca m ON m.id_marca=p.id_marca
                ORDER BY p.id_producto DESC",
        "fecha"=>null
    ],
    "clientes" => [
        "permiso"=>"clientes",
        "sql"=>"SELECT id_usuario AS ID,nombres AS Nombres,apellidos AS Apellidos,
                correo AS Correo,telefono AS Telefono,estado AS Estado
                FROM usuario WHERE rol_sistema='Cliente' ORDER BY id_usuario DESC",
        "fecha"=>null
    ],
    "pedidos" => [
        "permiso"=>"pedidos",
        "sql"=>"SELECT p.id_pedido AS Pedido,p.fecha_pedido AS Fecha,
                CONCAT(u.nombres,' ',u.apellidos) AS Cliente,
                u.correo AS Correo,p.estado_pedido AS Estado,
                p.tipo_entrega AS Entrega,p.total AS Total
                FROM pedido p JOIN usuario u ON u.id_usuario=p.id_usuario",
        "fecha"=>"p.fecha_pedido",
        "orden"=>" ORDER BY p.id_pedido DESC"
    ],
    "pagos" => [
        "permiso"=>"pagos",
        "sql"=>"SELECT pg.id_pago AS Pago,pg.id_pedido AS Pedido,
                pg.fecha_pago AS Fecha,pg.metodo_pago AS Metodo,
                pg.monto AS Monto,pg.estado_pago AS Estado,
                pg.referencia_cliente AS Referencia,
                CONCAT(u.nombres,' ',u.apellidos) AS Cliente
                FROM pago pg JOIN pedido p ON p.id_pedido=pg.id_pedido
                JOIN usuario u ON u.id_usuario=p.id_usuario",
        "fecha"=>"pg.fecha_pago",
        "orden"=>" ORDER BY pg.id_pago DESC"
    ],
    "kardex" => [
        "permiso"=>"inventario",
        "sql"=>"SELECT m.id_movimiento AS Movimiento,m.fecha_movimiento AS Fecha,
                p.nombre_producto AS Producto,m.tipo_movimiento AS Tipo,
                m.cantidad AS Cantidad,m.stock_anterior AS Stock_anterior,
                m.stock_nuevo AS Stock_nuevo,m.motivo AS Motivo
                FROM movimiento_stock m JOIN producto p ON p.id_producto=m.id_producto",
        "fecha"=>"m.fecha_movimiento",
        "orden"=>" ORDER BY m.id_movimiento DESC"
    ],
    "compras" => [
        "permiso"=>"compras",
        "sql"=>"SELECT c.id_compra AS Compra,c.fecha_compra AS Fecha,
                pr.razon_social AS Proveedor,c.total AS Total,c.estado AS Estado
                FROM compra c JOIN proveedor pr ON pr.id_proveedor=c.id_proveedor",
        "fecha"=>"c.fecha_compra",
        "orden"=>" ORDER BY c.id_compra DESC"
    ],
    "ventas" => [
        "permiso"=>"reportes",
        "sql"=>"SELECT DATE(p.fecha_pedido) AS Fecha,
                COUNT(*) AS Pedidos,COALESCE(SUM(p.total),0) AS Ventas
                FROM pedido p",
        "fecha"=>"p.fecha_pedido",
        "predicado"=>"LOWER(p.estado_pedido)<>'cancelado'",
        "orden"=>" GROUP BY DATE(p.fecha_pedido) ORDER BY Fecha DESC"
    ]
];

if (!isset($definiciones[$tipo])) {
    http_response_code(404);
    exit("Exportación desconocida");
}
$def = $definiciones[$tipo];
if (!puede($def["permiso"])) {
    http_response_code(403);
    exit("No tienes permiso para exportar esta información");
}

function fechaExportable(string $fecha): bool {
    if ($fecha === "") return true;
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/',$fecha)) return false;
    [$anio,$mes,$dia]=array_map("intval",explode("-",$fecha));
    return checkdate($mes,$dia,$anio);
}

$desde=trim((string)($_GET["desde"] ?? ""));
$hasta=trim((string)($_GET["hasta"] ?? ""));
if (!fechaExportable($desde) || !fechaExportable($hasta)
    || ($desde!=="" && $hasta!=="" && $desde>$hasta)) {
    http_response_code(422);
    exit("Rango de fechas inválido");
}

$sql=$def["sql"];
$condiciones=[];
$parametros=[];
if (isset($def["predicado"])) $condiciones[]=$def["predicado"];
if ($def["fecha"] !== null && $desde !== "") {
    $condiciones[]="DATE(".$def["fecha"].")>=?";
    $parametros[]=$desde;
}
if ($def["fecha"] !== null && $hasta !== "") {
    $condiciones[]="DATE(".$def["fecha"].")<=?";
    $parametros[]=$hasta;
}
if ($condiciones) {
    $sql .= (str_contains(strtoupper($sql)," WHERE ") ? " AND " : " WHERE ")
        . implode(" AND ",$condiciones);
}
$sql .= $def["orden"] ?? "";
$stmt=$conexion->prepare($sql);
if ($parametros) {
    $stmt->bind_param(str_repeat("s",count($parametros)),...$parametros);
}
$stmt->execute();
$rows=$stmt->get_result();

$nombreArchivo="dorada_motors_".$tipo."_".date("Ymd_His").".csv";
header("Content-Type: text/csv; charset=UTF-8");
header("Content-Disposition: attachment; filename=\"".$nombreArchivo."\"");
header("Cache-Control: private, no-store");
header("X-Content-Type-Options: nosniff");

$salida=fopen("php://output","w");
echo "\xEF\xBB\xBF"; // Excel reconoce acentos y caracteres UTF-8.
$campos=$rows->fetch_fields();
fputcsv($salida,array_map(static fn($f)=>$f->name,$campos),";",'"',"");
while ($registro=$rows->fetch_assoc()) {
    $fila=[];
    foreach ($registro as $valor) {
        $texto=(string)($valor ?? "");
        // Evitar inyección de fórmulas en Excel al exportar textos de clientes.
        if ($texto!=="" && preg_match('/^\s*[=+@\-]/u',$texto)
            && !is_numeric($texto)) {
            $texto="'".$texto;
        }
        $fila[]=$texto;
    }
    fputcsv($salida,$fila,";",'"',"");
}
fclose($salida);
exit;
