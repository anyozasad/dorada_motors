# AUDITORÍA DE INGENIERÍA — INDICADOR IV
**Proyecto:** Dorada Motors (Flutter + PHP + MySQL)  
**Fecha:** 8 de noviembre de 2026  
**Estado:** sistema funcional de demostración; no afirmar puesta en producción ni 150 pruebas individuales aprobadas.

## 1. Dictamen técnico
El repositorio contiene una aplicación Flutter de cliente, un dashboard administrativo PHP, API JSON, base de datos MySQL, imágenes locales y scripts de instalación. No es una plantilla visual vacía: existen formularios y operaciones que leen y escriben en MySQL.

Los pipelines de la versión anterior a esta revisión finalizaron correctamente:
- PHP, MySQL, seguridad, stock, pagos parciales, pedidos, roles y otros flujos: [Quality Check](https://github.com/anyozasad/dorada_motors/actions/runs/42496845137).
- Análisis Flutter, pruebas de widgets, compilación Web y APK de depuración: [Flutter CI](https://github.com/anyozasad/dorada_motors/actions/runs/42496845190).
Los pipelines **del commit que se entrega** deben revisarse nuevamente en la pestaña **Actions** para no confundir evidencia de otra revisión con la actual.

## 2. Módulos examinados
| Área | Existe en código | Prueba automatizada | Aceptación en PC del profesor |
| --- | --- | --- | --- |
| Registro, login, tokens y sesiones | Sí | Integración PHP/MySQL | Pendiente |
| Catálogo, fotos, categorías y marcas | Sí | Integración + pruebas de navegador | Pendiente |
| Búsqueda, filtros y favoritos | Sí | Integración parcial | Pendiente |
| Carrito y checkout | Sí | Integración transaccional | Pendiente |
| Pedidos y cancelación con devolución de stock | Sí | Integración transaccional | Pendiente |
| Cobros manuales, abonos y saldo pendiente | Sí | Integración transaccional | Pendiente |
| Dashboard: métricas, gráficos y alertas | Sí | Navegador + consulta a API | Pendiente |
| CRUD de productos, clientes, proveedores y compras | Sí | Integración + navegador parcial | Pendiente |
| Kardex, reportes y exportación CSV | Sí | Integración + navegador | Pendiente |
| Comprobantes y soporte | Sí, demostrativos | Integración | Pendiente |
| 150 requisitos administrativos individuales | Enumerados | Verificación estructural, no 150 pruebas independientes | Pendiente |

## 3. Mejoras de esta revisión
1. Metadatos de Flutter Web: título, nombre instalable, descripción y colores institucionales de Dorada Motors.
2. Protección del esquema `dorada_motors.sql` y archivos de respaldo/configuración para Apache/XAMPP mediante `PHP/dorada_api/.htaccess`; ya existía protección para `data/`.
3. Copia explícita de ambas reglas de protección al iniciar la demo.
4. Bloqueo de caché para descargas de respaldo de MySQL.
5. Prueba local adicional: la URL del archivo SQL y de configuración debe responder HTTP 403 o 404, nunca HTTP 200.
6. El empaquetador conserva `Flutter/` y `PHP/` únicamente dentro del ZIP y comprueba los archivos de protección.
7. Comprobaciones automáticas de identidad web y archivos protegidos en Quality Check.

## 4. Riesgos y límites vigentes
- **Pagos:** Yape, Plin y transferencias quedan pendientes hasta validación administrativa; no se conectan directamente a una pasarela bancaria.
- **Comprobantes:** el PDF/boleta de demostración no constituye un comprobante electrónico autorizado por SUNAT.
- **Android:** el APK generado es de prueba, no está preparado para publicación oficial y conserva un identificador de paquete genérico.
- **Seguridad y alojamiento:** el uso de HTTP local en XAMPP y de usuario MySQL `root` sin contraseña es solo para desarrollo; antes de producción requiere HTTPS, usuario SQL de permisos mínimos, almacenamiento seguro del token y gestión de backups.
- **Evidencias:** no se han ejecutado los 150 casos individualmente en el equipo del profesor, ni una instalación real en todos los modelos de Android.
- **Mantenibilidad:** `dashboard.php` y `main_shell.dart` son archivos grandes; conviene modularizarlos posteriormente, sin cambiar la interfaz para esta entrega.

## 5. Protocolo de aceptación presencial (XAMPP)
1. Actualizar la carpeta `dorada_motors` sin perder el respaldo local; comprobar las dos carpetas `Flutter/` y `PHP/`.
2. Iniciar Apache y MySQL; ejecutar `powershell -ExecutionPolicy Bypass -File .\PHP\tests\scripts\INICIAR_DEMO.ps1`.
3. Crear administrador, entrar al dashboard y dar de alta un producto; comprobar en phpMyAdmin.
4. Registrar un cliente desde Flutter; buscar el producto, agregarlo al carrito y crear un pedido.
5. Verificar el mismo pedido en PHP, comprobar la reducción de stock/Kardex y registrar abonos parciales; confirmar cambios de saldo sin duplicación.
6. Emitir comprobante de demostración, consultar desde Flutter y confirmar que la cuenta ajena no puede leerlo.
7. Cancelar otro pedido pendiente; confirmar que el stock vuelve exactamente una vez.
8. Exportar CSV, revisar alertas y ejecutar `powershell -ExecutionPolicy Bypass -File .\PHP\tests\scripts\VERIFICAR_SISTEMA.ps1`.
9. Completar **`PHP/tests/documentacion/MATRIZ_VALIDACION_FUNCIONAL_150.md`** con evidencia de cada punto del profesor; no marcar los pendientes como aprobados por la mera presencia de código.

## 6. Archivo de entrega
En la raíz del repositorio, ejecutar `powershell -ExecutionPolicy Bypass -File .\PHP\tests\scripts\PREPARAR_ENTREGA_INDICADOR_IV.ps1`. El ZIP del Escritorio contiene dos carpetas principales y no incluye base de datos privada real.

**Criterio de cierre para la tarea:** demostrar los flujos principales con MySQL, adjuntar las capturas de Actions, presentar ZIP ejecutable y reconocer los límites demostrativos. El criterio para comercialización es distinto y requiere trabajo adicional.
