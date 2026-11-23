# Dorada Motors — guía práctica de sustentación

**Proyecto:** sistema de ventas e inventario de repuestos para motocicletas y motokar.  
**Modalidades:** Flutter Android + SQLite local, Flutter conectado a API PHP/MySQL, panel PHP + XAMPP.  
**Fecha de revisión:** 23/11/2026.  
**Objetivo:** mostrar acciones funcionales, consecuencias verificables y evidencia, no una plantilla estática.

> La lista de 150 puntos del dashboard PHP es una matriz de verificación estructural. No equivale a 150 pruebas independientes aprobadas. Deben marcarse en presencia del profesor los casos que se demuestren. Los comprobantes locales son **DEMO** y no se emiten en SUNAT. Las operaciones locales no se sincronizan automáticamente con MySQL.

## Preparación previa

1. Instalar **Dorada Motors Local** en un teléfono Android. No desinstalar otra variante que contenga datos sin hacer antes copia de seguridad. En el primer inicio del administrador local crear una contraseña propia de mínimo 8 caracteres.
2. Comprobar que la aplicación inicia con la laptop apagada y datos móviles/Wi-Fi desactivados.
3. No crear ni compartir contraseñas de prueba reales en capturas o el video. Tener un correo de demostración ficticio.
4. Si se va a mostrar el dashboard PHP adicionalmente: iniciar XAMPP (Apache y MySQL), instalar el proyecto y disponer de datos en la base. El modo local SQLite del teléfono **no** comparte sus datos con este MySQL.
5. Comprobar previamente la cámara/galería, espacio libre del teléfono, carga de batería y que los productos iniciales con fotos sean visibles.
6. La APK se obtiene desde el último workflow **Flutter CI** que tenga todos los jobs en verde. No utilizar una APK de una revisión más antigua.

## Demostración propuesta — 9 a 10 minutos

| Tiempo | Pantalla/acción | Qué demostrar |
| --- | --- | --- |
| 0:00–0:50 | Entrada al APK → Administrador sin laptop | Acceso con contraseña local, sin IP ni XAMPP. Enseñar que el teléfono está desconectado |
| 0:50–2:00 | Productos | Ver imágenes y marcas. Crear/editar un repuesto de prueba con precio, categoría, foto y stock; confirmar que permanece al volver |
| 2:00–2:50 | Clientes | Registrar cliente desde el dashboard local, con correo ficticio y contraseña local |
| 2:50–4:20 | Tienda del cliente sin internet | Ingresar con ese cliente, ver **el mismo** producto, agregalo al carrito, registrar pedido con recojo y efectivo |
| 4:20–5:40 | Dashboard → Pedidos | Ver el pedido del cliente, detalle, cantidades y descuento en stock/Kardex; verificar que no permite vender más unidades de las existentes |
| 5:40–6:35 | Pagos | Registrar/verificar el cobro manual y revisar el pedido. Aclarar que elegir Yape o Plin no realiza cobros automáticos |
| 6:35–7:30 | Comprobantes → Boleta DEMO | Emitir documento solo del pedido pagado y abrirlo para mostrar subtotal, IGV, total y leyenda **SIN VALIDEZ SUNAT** |
| 7:30–8:30 | Reportes | Mostrar ventas por día, gráfica de montos y productos más vendidos con datos de la operación recién realizada |
| 8:30–9:20 | Reabrir la aplicación | Comprobar que las ventas, productos y cliente siguen en la base SQLite, sin Wi-Fi |
| 9:20–10:00 | Conclusión técnica | Diferenciar el sistema local en el teléfono de PHP/MySQL en XAMPP; indicar que un servidor en línea sería necesario para sincronización entre dispositivos |

## Si el profesor solicita MySQL y dashboard PHP

1. Iniciar Apache + MySQL en XAMPP. Cargar **http://localhost/dorada_api/admin_login.php**.
2. Crear o utilizar el administrador que ya esté configurado en esa instalación.
3. Registrar un producto en el panel PHP y comprobar su fila e imagen en phpMyAdmin.
4. Desde la modalidad **con servidor** del APK y una red que llegue a PHP, iniciar sesión con una cuenta de MySQL. Ver el mismo producto, efectuar una operación y confirmar su registro en PHP.
5. Mostrar la actualización de stock y el detalle del pedido. No afirmar que los registros de SQLite autónomo aparecen en MySQL; son bases distintas.

## Pruebas y evidencias

- Código y scripts: `Flutter/`, `PHP/`, `ACTUALIZAR_DORADA_MOTORS.ps1`.
- Matriz de 150 requisitos: `PHP/tests/documentacion/MATRIZ_VALIDACION_FUNCIONAL_150.md`. Los 150 puntos corresponden al panel PHP; se requiere validación presencial de cada uno.
- Pruebas Android/Flutter: GitHub Actions → **Flutter CI**, incluyendo análisis, pruebas, compilación web y APK.
- Pruebas de PHP + MySQL/MariaDB + navegador: GitHub Actions → **Dorada Motors Quality Check**.
- Evidencias mínimas: acceso administrador, productos y fotografía, cliente registrado, carrito, pedido, pago, stock antes/después, Kardex, comprobante demo y reporte gráfico.
- Las evidencias deberían provenir del dispositivo y la versión que se expone, no de imágenes artificiales.

## Límites que deben declararse de forma correcta

- SQLite permite operar al administrador y cliente **dentro de un mismo teléfono** sin internet ni computadora. No es una base MySQL y no realiza sincronización automática con otros teléfonos.
- PHP/MySQL en la laptop requiere que el servidor esté encendido y accesible para registrar datos de otros equipos.
- Los pagos digitales se anotan/verifican manualmente. Las boletas y facturas del modo local son demostraciones; no corresponden a comprobantes electrónicos SUNAT.
- Las pruebas automáticas son verificaciones parciales de la aplicación; no reemplazan la prueba real sobre el Samsung, ni certifican 150 casos individuales.
