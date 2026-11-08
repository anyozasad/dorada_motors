# Matriz de verificación funcional — Dorada Motors

Este documento permite al profesor evaluar **los 150 requisitos del panel PHP uno por uno**. La lista del proyecto indica implementación en código, pero **una etiqueta «implementado» no es una prueba funcional**. Las casillas se dejan sin marcar para registrar la demostración presencial.

**Pruebas automatizadas:** `.github/workflows/quality-check.yml` ejecuta PHP sintáctico, Flutter y operaciones reales contra MySQL temporal en `tests/integration_smoke.py`. La etiqueta *Prueba automatizada parcial* significa que se verificó parte del flujo; no certifica todas las variantes ni los 150 ítems por separado.

**Antes de marcar:** Iniciar Apache/MySQL (XAMPP) y Flutter, crear un dato desde el formulario, confirmar su registro en phpMyAdmin y comprobar las consecuencias en el otro sistema. Mantener capturas con fecha y sin contraseñas.

| ID | Requisito del dashboard | Área | Verificación | Estado presencial |
|---|---|---|---|---|
| 001 | Dashboard carga métricas desde MySQL | Dashboard y seguridad | Comprobar en formulario y BD | ☐ |
| 002 | Dashboard muestra total de productos | Dashboard y seguridad | Comprobar en formulario y BD | ☐ |
| 003 | Dashboard muestra total de clientes | Dashboard y seguridad | Comprobar en formulario y BD | ☐ |
| 004 | Dashboard muestra total de pedidos | Dashboard y seguridad | Comprobar en formulario y BD | ☐ |
| 005 | Dashboard muestra total de ventas | Dashboard y seguridad | Comprobar en formulario y BD | ☐ |
| 006 | Dashboard muestra productos con stock bajo | Dashboard y seguridad | Comprobar en formulario y BD | ☐ |
| 007 | Dashboard muestra ventas del día | Dashboard y seguridad | Comprobar en formulario y BD | ☐ |
| 008 | Dashboard muestra pedidos pendientes | Dashboard y seguridad | Comprobar en formulario y BD | ☐ |
| 009 | Dashboard muestra total de proveedores | Dashboard y seguridad | Comprobar en formulario y BD | ☐ |
| 010 | Dashboard muestra total de compras | Dashboard y seguridad | Comprobar en formulario y BD | ☐ |
| 011 | Dashboard actualiza métricas automáticamente | Dashboard y seguridad | Comprobar en formulario y BD | ☐ |
| 012 | Seguridad: dashboard protegido por login administrativo | Dashboard y seguridad | Integración parcial + comprobar manual | ☐ |
| 013 | Seguridad: primera configuración crea administrador inicial | Dashboard y seguridad | Integración parcial + comprobar manual | ☐ |
| 014 | Seguridad: formularios administrativos protegidos con CSRF | Dashboard y seguridad | Integración parcial + comprobar manual | ☐ |
| 015 | Seguridad: cierre de sesión administrativo | Dashboard y seguridad | Comprobar en formulario y BD | ☐ |
| 016 | Productos: listar productos | Productos | Integración parcial + comprobar manual | ☐ |
| 017 | Productos: registrar producto | Productos | Integración parcial + comprobar manual | ☐ |
| 018 | Productos: editar producto | Productos | Integración parcial + comprobar manual | ☐ |
| 019 | Productos: eliminar producto sin movimientos | Productos | Integración parcial + comprobar manual | ☐ |
| 020 | Productos: impedir eliminar producto con movimientos | Productos | Comprobar en formulario y BD | ☐ |
| 021 | Productos: registrar precio de oferta | Productos | Integración parcial + comprobar manual | ☐ |
| 022 | Productos: validar oferta menor al precio | Productos | Integración parcial + comprobar manual | ☐ |
| 023 | Seguridad: sesión administrativa expira por inactividad | Productos | Comprobar en formulario y BD | ☐ |
| 024 | Seguridad: auditoría registra acciones administrativas | Productos | Comprobar en formulario y BD | ☐ |
| 025 | Productos: filtrar por categoría | Productos | Comprobar en formulario y BD | ☐ |
| 026 | Productos: filtrar por nivel de stock | Productos | Comprobar en formulario y BD | ☐ |
| 027 | Seguridad: clientes y personal usan accesos separados | Productos | Comprobar en formulario y BD | ☐ |
| 028 | Seguridad: roles Administrador, Vendedor y Almacén | Productos | Comprobar en formulario y BD | ☐ |
| 029 | Productos: registrar ajuste de stock en Kardex | Productos | Comprobar en formulario y BD | ☐ |
| 030 | Categorías: listar categorías | Categorías | Integración parcial + comprobar manual | ☐ |
| 031 | Categorías: registrar categoría | Categorías | Integración parcial + comprobar manual | ☐ |
| 032 | Categorías: editar categoría | Categorías | Integración parcial + comprobar manual | ☐ |
| 033 | Categorías: eliminar categoría sin productos | Categorías | Integración parcial + comprobar manual | ☐ |
| 034 | Categorías: impedir eliminar categoría usada | Categorías | Comprobar en formulario y BD | ☐ |
| 035 | Marcas: listar marcas | Marcas | Integración parcial + comprobar manual | ☐ |
| 036 | Marcas: registrar marca | Marcas | Integración parcial + comprobar manual | ☐ |
| 037 | Marcas: editar marca | Marcas | Integración parcial + comprobar manual | ☐ |
| 038 | Marcas: eliminar marca sin productos | Marcas | Integración parcial + comprobar manual | ☐ |
| 039 | Marcas: impedir eliminar marca usada | Marcas | Comprobar en formulario y BD | ☐ |
| 040 | Clientes: listar clientes | Clientes y personal | Comprobar en formulario y BD | ☐ |
| 041 | Clientes: registrar cliente | Clientes y personal | Comprobar en formulario y BD | ☐ |
| 042 | Clientes: editar cliente | Clientes y personal | Comprobar en formulario y BD | ☐ |
| 043 | Clientes: validar correo | Clientes y personal | Comprobar en formulario y BD | ☐ |
| 044 | Clientes: impedir correo duplicado | Clientes y personal | Comprobar en formulario y BD | ☐ |
| 045 | Clientes: guardar contraseña cifrada | Clientes y personal | Comprobar en formulario y BD | ☐ |
| 046 | Clientes: activar cliente | Clientes y personal | Comprobar en formulario y BD | ☐ |
| 047 | Clientes: bloquear cliente | Clientes y personal | Comprobar en formulario y BD | ☐ |
| 048 | Clientes: ver historial del cliente | Clientes y personal | Comprobar en formulario y BD | ☐ |
| 049 | Personal: crear cuentas administrativas | Clientes y personal | Comprobar en formulario y BD | ☐ |
| 050 | Personal: cambiar rol y estado del personal | Clientes y personal | Comprobar en formulario y BD | ☐ |
| 051 | Direcciones: listar direcciones | Direcciones | Comprobar en formulario y BD | ☐ |
| 052 | Direcciones: registrar dirección | Direcciones | Comprobar en formulario y BD | ☐ |
| 053 | Direcciones: editar dirección | Direcciones | Comprobar en formulario y BD | ☐ |
| 054 | Direcciones: eliminar dirección sin pedidos | Direcciones | Comprobar en formulario y BD | ☐ |
| 055 | Direcciones: impedir eliminar dirección usada | Direcciones | Comprobar en formulario y BD | ☐ |
| 056 | Pedidos: listar pedidos | Pedidos | Integración parcial + comprobar manual | ☐ |
| 057 | Pedidos: registrar pedido manual | Pedidos | Integración parcial + comprobar manual | ☐ |
| 058 | Pedidos: seleccionar cliente activo | Pedidos | Integración parcial + comprobar manual | ☐ |
| 059 | Pedidos: seleccionar producto | Pedidos | Integración parcial + comprobar manual | ☐ |
| 060 | Pedidos: validar cantidad | Pedidos | Integración parcial + comprobar manual | ☐ |
| 061 | Pedidos: validar stock disponible | Pedidos | Integración parcial + comprobar manual | ☐ |
| 062 | Pedidos: calcular subtotal | Pedidos | Integración parcial + comprobar manual | ☐ |
| 063 | Pedidos: calcular total | Pedidos | Integración parcial + comprobar manual | ☐ |
| 064 | Pedidos: crear detalle de pedido | Pedidos | Integración parcial + comprobar manual | ☐ |
| 065 | Pedidos: descontar stock | Pedidos | Integración parcial + comprobar manual | ☐ |
| 066 | Pedidos: registrar salida en Kardex | Pedidos | Integración parcial + comprobar manual | ☐ |
| 067 | Pedidos: registrar pago inicial | Pedidos | Integración parcial + comprobar manual | ☐ |
| 068 | Pedidos: usar transacción MySQL | Pedidos | Integración parcial + comprobar manual | ☐ |
| 069 | Pedidos: hacer rollback si falla | Pedidos | Integración parcial + comprobar manual | ☐ |
| 070 | Pedidos: ver detalle | Pedidos | Integración parcial + comprobar manual | ☐ |
| 071 | Pedidos: mostrar productos del pedido | Pedidos | Comprobar en formulario y BD | ☐ |
| 072 | Pedidos: agregar varios productos en una venta | Pedidos | Comprobar en formulario y BD | ☐ |
| 073 | Pedidos: mostrar tipo de entrega | Pedidos | Comprobar en formulario y BD | ☐ |
| 074 | Pedidos: filtrar por estado | Pedidos | Comprobar en formulario y BD | ☐ |
| 075 | Pedidos: pasar a Procesando | Pedidos | Integración parcial + comprobar manual | ☐ |
| 076 | Pedidos: pasar a Pagado | Pedidos | Comprobar en formulario y BD | ☐ |
| 077 | Pedidos: pasar a Enviado | Pedidos | Comprobar en formulario y BD | ☐ |
| 078 | Pedidos: pasar a Completado | Pedidos | Comprobar en formulario y BD | ☐ |
| 079 | Pedidos: cancelar pedido | Pedidos | Integración parcial + comprobar manual | ☐ |
| 080 | Pedidos: devolver stock al cancelar | Pedidos | Integración parcial + comprobar manual | ☐ |
| 081 | Pedidos: reactivar pedido cancelado | Pedidos | Integración parcial + comprobar manual | ☐ |
| 082 | Pedidos: validar stock al reactivar | Pedidos | Integración parcial + comprobar manual | ☐ |
| 083 | Pedidos: volver a descontar stock al reactivar | Pedidos | Integración parcial + comprobar manual | ☐ |
| 084 | Pedidos: registrar Kardex al cancelar | Pedidos | Integración parcial + comprobar manual | ☐ |
| 085 | Pedidos: registrar Kardex al reactivar | Pedidos | Integración parcial + comprobar manual | ☐ |
| 086 | Pedidos: impedir estado inválido | Pedidos | Comprobar en formulario y BD | ☐ |
| 087 | Pedidos: exportar CSV | Pedidos | Comprobar en formulario y BD | ☐ |
| 088 | Pedidos: mostrar avance del pedido | Pedidos | Comprobar en formulario y BD | ☐ |
| 089 | Pedidos: permitir Recojo en tienda | Pedidos | Comprobar en formulario y BD | ☐ |
| 090 | Pedidos: permitir Delivery | Pedidos | Comprobar en formulario y BD | ☐ |
| 091 | Pagos: listar pagos | Pagos | Integración parcial + comprobar manual | ☐ |
| 092 | Pagos: registrar pago manual | Pagos | Comprobar en formulario y BD | ☐ |
| 093 | Pagos: controlar saldo pendiente del pedido | Pagos | Comprobar en formulario y BD | ☐ |
| 094 | Pagos: validar monto mayor a cero | Pagos | Comprobar en formulario y BD | ☐ |
| 095 | Pagos: marcar Pendiente | Pagos | Integración parcial + comprobar manual | ☐ |
| 096 | Pagos: marcar Pagado | Pagos | Integración parcial + comprobar manual | ☐ |
| 097 | Pagos: marcar Rechazado | Pagos | Integración parcial + comprobar manual | ☐ |
| 098 | Pagos: sincronizar pedido al pagar | Pagos | Integración parcial + comprobar manual | ☐ |
| 099 | Pagos: impedir pago a pedido cancelado | Pagos | Integración parcial + comprobar manual | ☐ |
| 100 | Pagos: impedir sobrepago del pedido | Pagos | Comprobar en formulario y BD | ☐ |
| 101 | Comprobantes: listar comprobantes | Comprobantes | Comprobar en formulario y BD | ☐ |
| 102 | Comprobantes: emitir boleta | Comprobantes | Integración parcial + comprobar manual | ☐ |
| 103 | Comprobantes: emitir factura | Comprobantes | Comprobar en formulario y BD | ☐ |
| 104 | Comprobantes: exigir pedido totalmente pagado | Comprobantes | Integración parcial + comprobar manual | ☐ |
| 105 | Comprobantes: generar numeración automática | Comprobantes | Integración parcial + comprobar manual | ☐ |
| 106 | Comprobantes: impedir duplicado por pedido | Comprobantes | Integración parcial + comprobar manual | ☐ |
| 107 | Comprobantes: calcular subtotal sin IGV | Comprobantes | Integración parcial + comprobar manual | ☐ |
| 108 | Comprobantes: calcular IGV | Comprobantes | Integración parcial + comprobar manual | ☐ |
| 109 | Comprobantes: calcular total | Comprobantes | Integración parcial + comprobar manual | ☐ |
| 110 | Comprobantes: imprimir comprobante | Comprobantes | Integración parcial + comprobar manual | ☐ |
| 111 | Comprobantes: eliminar comprobante | Comprobantes | Comprobar en formulario y BD | ☐ |
| 112 | Inventario: listar Kardex | Inventario | Integración parcial + comprobar manual | ☐ |
| 113 | Inventario: registrar entrada manual | Inventario | Integración parcial + comprobar manual | ☐ |
| 114 | Inventario: registrar salida manual | Inventario | Integración parcial + comprobar manual | ☐ |
| 115 | Inventario: validar salida contra stock | Inventario | Integración parcial + comprobar manual | ☐ |
| 116 | Inventario: guardar motivo | Inventario | Integración parcial + comprobar manual | ☐ |
| 117 | Inventario: guardar stock anterior | Inventario | Integración parcial + comprobar manual | ☐ |
| 118 | Inventario: guardar stock nuevo | Inventario | Integración parcial + comprobar manual | ☐ |
| 119 | Inventario: actualizar producto tras movimiento | Inventario | Integración parcial + comprobar manual | ☐ |
| 120 | Inventario: mostrar alertas de stock mínimo | Inventario | Comprobar en formulario y BD | ☐ |
| 121 | Inventario: mostrar productos agotados | Inventario | Comprobar en formulario y BD | ☐ |
| 122 | Proveedores: listar proveedores | Proveedores | Integración parcial + comprobar manual | ☐ |
| 123 | Proveedores: registrar proveedor | Proveedores | Integración parcial + comprobar manual | ☐ |
| 124 | Proveedores: editar proveedor | Proveedores | Integración parcial + comprobar manual | ☐ |
| 125 | Proveedores: activar proveedor | Proveedores | Integración parcial + comprobar manual | ☐ |
| 126 | Proveedores: inactivar proveedor | Proveedores | Integración parcial + comprobar manual | ☐ |
| 127 | Proveedores: eliminar proveedor sin compras | Proveedores | Comprobar en formulario y BD | ☐ |
| 128 | Proveedores: impedir eliminar proveedor usado | Proveedores | Integración parcial + comprobar manual | ☐ |
| 129 | Compras: listar compras | Compras | Integración parcial + comprobar manual | ☐ |
| 130 | Compras: registrar compra | Compras | Integración parcial + comprobar manual | ☐ |
| 131 | Compras: registrar múltiples productos en una compra | Compras | Integración parcial + comprobar manual | ☐ |
| 132 | Compras: calcular subtotal | Compras | Integración parcial + comprobar manual | ☐ |
| 133 | Compras: calcular total | Compras | Integración parcial + comprobar manual | ☐ |
| 134 | Compras: aumentar stock | Compras | Integración parcial + comprobar manual | ☐ |
| 135 | Compras: registrar entrada en Kardex | Compras | Integración parcial + comprobar manual | ☐ |
| 136 | Compras: anular compra | Compras | Integración parcial + comprobar manual | ☐ |
| 137 | Compras: retirar stock al anular | Compras | Integración parcial + comprobar manual | ☐ |
| 138 | Compras: reactivar compra | Compras | Integración parcial + comprobar manual | ☐ |
| 139 | Compras: devolver stock al reactivar | Compras | Integración parcial + comprobar manual | ☐ |
| 140 | Compras: impedir anulación si stock insuficiente | Compras | Integración parcial + comprobar manual | ☐ |
| 141 | Reportes: filtrar por fecha desde | Reportes | Integración parcial + comprobar manual | ☐ |
| 142 | Reportes: filtrar por fecha hasta | Reportes | Integración parcial + comprobar manual | ☐ |
| 143 | Reportes: mostrar ventas del periodo | Reportes | Comprobar en formulario y BD | ☐ |
| 144 | Reportes: mostrar pedidos del periodo | Reportes | Comprobar en formulario y BD | ☐ |
| 145 | Reportes: calcular ticket promedio | Reportes | Comprobar en formulario y BD | ☐ |
| 146 | Reportes: mostrar productos más vendidos | Reportes | Comprobar en formulario y BD | ☐ |
| 147 | Reportes: mostrar unidades vendidas | Reportes | Comprobar en formulario y BD | ☐ |
| 148 | Reportes: mostrar importe por producto | Reportes | Comprobar en formulario y BD | ☐ |
| 149 | Configuración: guardar datos fiscales y contacto de la empresa | Configuración | Comprobar en formulario y BD | ☐ |
| 150 | Configuración: guardar IGV, moneda y costo de delivery | Configuración | Comprobar en formulario y BD | ☐ |

## Recorridos funcionales sugeridos para evidencias

1. **Acceso y roles:** crear administrador inicial, ingresar, cambiar rol, probar permisos y cerrar sesión.
2. **Catálogo:** registrar categoría, marca, producto y fotografía; modificar stock/precio y buscar en Flutter.
3. **Cliente móvil:** registrar cuenta, actualizar datos/contraseña, guardar direcciones, favoritos y carrito.
4. **Ventas:** confirmar compra desde Flutter, revisar pedido, pago, stock y movimiento en PHP/MySQL.
5. **Estados:** confirmar pago, generar boleta de demostración, cancelar otro pedido y comprobar reversión de stock.
6. **Compras y proveedores:** registrar proveedor, compra de varias líneas, anular/reactivar y comprobar Kardex.
7. **Reportes:** filtrar fechas y contrastar ventas, pedidos, unidades y ticket promedio con registros de prueba.
8. **Soporte:** enviar consulta desde Flutter, responderla desde Administración y verla al volver a actualizar.
10. **Recuperación:** solicitar ayuda desde el login, confirmar el caso en soporte, verificar identidad y restablecer con clave temporal; comprobar revocación de la sesión anterior.
9. **Errores esperados:** intentar pedidos sin stock, usuarios duplicados, eliminar productos en uso y acceder a cuentas ajenas.

## Alcance y límites

- Los 150 requisitos del archivo de control se refieren al **panel PHP**. Las pantallas móviles constituyen funciones adicionales, no deben contarse dos veces.
- `PHP/tests/VALIDAR_DASHBOARD_150.php` comprueba estructura y palabras clave, **no** ejecuta 150 casos de prueba.
- `tests/integration_smoke.py` comprueba transacciones reales sobre un MySQL de pruebas; no modifica la base de la empresa.
- La emisión imprimible de boletas/facturas es **demostrativa**; no se afirma integración oficial con SUNAT.
- Yape y Plin figuran como medios de pago registrados: no existe confirmación automática por esas plataformas.
- Sin evidencias manuales y pruebas en la PC del profesor, no debe declararse cero fallos en todas las funciones.
