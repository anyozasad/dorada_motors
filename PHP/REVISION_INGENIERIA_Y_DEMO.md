# Dorada Motors — revisión funcional de ingeniería y prueba de entrega

**Alcance:** aplicación Flutter de clientes, dashboard PHP de administración, API PHP y base de datos MySQL. Se ha preservado el diseño principal.

## Qué significa «funciona»

No se considera implementado un módulo por tener una tarjeta o botón. Para cada función se exige: **acción visible → validación → escritura o lectura de MySQL → resultado comprobable en el otro sistema**. Los 150 puntos de `CONTROL_150_FUNCIONES.txt` corresponden al panel administrativo. `VALIDAR_DASHBOARD_150.php` es un control estructural, **no 150 pruebas funcionales independientes**. Utilizar `MATRIZ_VALIDACION_FUNCIONAL_150.md` como lista de aceptación presencial.

## Recorridos automatizados en CI

El archivo `tests/integration_smoke.py` ejecuta contra PHP y una base MySQL temporal y prueba:

- Registro de cliente, contraseña robusta, login, protección de cuentas ajenas y cierre de sesión.
- Perfil, cambio de contraseña, recuperación asistida y revocación de tokens.
- Catálogo, CRUD administrativo y API, validaciones de precios, Kardex y control de stock.
- Carrito, favoritos y direcciones por cuenta, compra, costo de delivery, uso de ofertas e idempotencia al reintentar.
- Cancelación de pedidos pendientes con reposición de stock y rechazo de cancelación de ventas pagadas.
- Pago por abonos parciales sin marcar el pedido «Pagado» antes del saldo completo, bloqueo de sobrepago y pedido cancelado.
- Reporte de número de operación Yape, verificación por administración y actualización del estado en Flutter.
- Emisión de comprobante de demostración, vista privada del cliente y prohibición de lectura desde otras cuentas.
- Roles de Vendedor y Almacén, bloqueo de personal con sesión abierta, permisos y CSRF.
- Proveedores, categorías, marcas, compras de varias líneas, entradas y salidas, anulación y reactivación, reportes.
- Protección del instalador manual y ausencia de importación SQL al abrirlo sin confirmar.

Adicionalmente, GitHub Actions ejecuta análisis y pruebas Flutter, build de Flutter Web, compilación de APK Android de depuración y sintaxis PHP/PowerShell. Revisar **Actions** para ver la ejecución exacta correspondiente al commit que se entrega.

## Demostración en la PC del profesor

1. En XAMPP encender **Apache** y **MySQL**. Ejecutar `INICIAR_DEMO.ps1` desde la carpeta del repositorio. Comprobar que la API responde y que Flutter carga el catálogo.
2. Ingresar a `http://localhost/dorada_api/admin_login.php`, crear o usar el Administrador y abrir el dashboard. Registrar una marca, categoría y producto con una fotografía local; verificar la nueva fila en MySQL.
3. En Flutter crear un cliente, iniciar sesión, añadir el producto al carrito, elegir Recojo o Delivery y confirmar el pedido.
4. En el dashboard abrir **Pedidos** y **Inventario**. Comparar el ID del pedido y el movimiento de salida con phpMyAdmin. La cantidad de stock debe bajar exactamente una vez.
5. Antes de confirmar pagos, entrar en **Configuración y personal** y guardar los números oficiales de Yape/Plin o cuenta de transferencia, si la empresa los tiene. En Flutter se muestran esos datos y el cliente puede informar su referencia. Confirmar el pago manualmente en PHP solo después de comprobarlo.
6. Emitir la boleta de **demostración** en el dashboard. En Flutter > Perfil > Mis pedidos > Ver comprobante emitido, verificar los totales, IGV y artículos.
7. Crear otro pedido pendiente y cancelarlo desde Flutter. Confirmar que aparece como Cancelado en PHP y se repone el stock en MySQL. Repetir el intento y comprobar que no se duplica la reposición.
8. Crear una consulta desde **Ayuda y soporte** y responder desde el dashboard; comprobar la respuesta desde la misma cuenta Flutter.
9. Crear un Vendedor, comprobar que su menú está limitado, cambiar su rol a Almacén desde otra sesión administrativa y verificar que pierde el acceso a pagos de inmediato. Bloquearlo y confirmar que la sesión deja de acceder.
10. Usar `VERIFICAR_SISTEMA.ps1` y `MATRIZ_VALIDACION_FUNCIONAL_150.md` para registrar el resto de evidencias individuales del profesor.

## Requisitos de instalación para teléfono

- El teléfono y XAMPP deben poder comunicarse en la misma red local. En el login Flutter usar **Configurar conexión con PHP** e ingresar `http://IP_DE_LA_PC/dorada_api`.
- En el emulador Android se utiliza `http://10.0.2.2/dorada_api`. En Chrome de esa PC se usa `http://localhost/dorada_api`.
- El firewall de Windows y Apache deben permitir acceso desde el dispositivo. En otro equipo no funciona `localhost` apuntando a la PC del servidor.
- El APK de prueba se publica como artefacto en la ejecución exitosa **Flutter CI** de GitHub Actions; no equivale a una aplicación firmada para distribución comercial.

## Límites que no deben presentarse como resueltos

- **Yape, Plin y transferencias:** registro y confirmación **manual**, sin integración bancaria real ni débito automático.
- **Boletas/facturas:** comprobantes de **demostración**; la emisión tributaria oficial necesita integración y credenciales de SUNAT o un proveedor autorizado.
- **Seguridad de producción:** XAMPP con `root` local sin contraseña no es apto para exponer el negocio a Internet. Para producción se requiere HTTPS, hosting, usuario MySQL con privilegios limitados, backups seguros y dominio.
- Las pruebas de GitHub verifican recorridos reales automatizados sobre una base temporal, **no certifican que cada uno de los 150 requisitos haya sido probado manualmente en la computadora del profesor**.
- Los números reales de cobro, datos fiscales y el acceso del administrador deben configurarse por el propietario, no pueden inventarse en el repositorio.

**Criterio de aceptación:** solo marcar un requisito como «Verificado» cuando se haya ejecutado su operación, observado el efecto en MySQL y guardado evidencia, usando la matriz de 150 requisitos.
