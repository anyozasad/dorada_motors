#!/usr/bin/env python3
"""Prueba real del dashboard PHP desde un navegador Chromium.

Requiere PHP/MySQL en http://127.0.0.1:8090 y Playwright:
  python -m pip install playwright
  python -m playwright install chromium
  python tests/browser_e2e.py
Se ejecuta también en GitHub Actions con una BD MySQL temporal.
"""
import os
import re
import uuid

from playwright.sync_api import sync_playwright, expect

BASE = os.getenv("DORADA_URL", "http://127.0.0.1:8090").rstrip("/")
NOMBRE = "UI-Repuesto-" + uuid.uuid4().hex[:9]


def seleccionar_producto(select, texto):
    for opcion in select.locator("option").all():
        if texto in (opcion.text_content() or ""):
            value = opcion.get_attribute("value")
            if value:
                select.select_option(value=value)
                return value
    raise AssertionError(f"Producto {texto} no disponible en la lista del formulario")


def main():
    errores_js = []
    os.makedirs("artifacts/ui", exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=["--no-sandbox"])
        page = browser.new_page(viewport={"width": 1366, "height": 900}, accept_downloads=True)
        page.on("pageerror", lambda exc: errores_js.append(str(exc)))
        page.goto(BASE + "/admin_login.php")
        expect(page.locator("h1")).to_contain_text("Dorada Motors")

        # Acceso inicial mediante el formulario verdadero que verá el profesor.
        page.locator('input[name="nombres"]').fill("Admin UI")
        page.locator('input[name="apellidos"]').fill("Verificación")
        page.locator('input[name="correo"]').fill("admin-ui-" + uuid.uuid4().hex[:10] + "@example.test")
        page.locator('input[name="contrasena"]').fill("ClaveUI_2026_Segura")
        page.locator('input[name="confirmar_contrasena"]').fill("ClaveUI_2026_Segura")
        page.get_by_role("button", name="Crear administrador y entrar").click()
        page.wait_for_url(re.compile(r".*/dashboard\.php.*"))
        expect(page.locator("#inicio")).to_have_class(re.compile("active"))
        expect(page.locator(".top-title")).to_contain_text("Dashboard")
        # Indicador IV: la caja real se presenta en tarjetas conectadas con MySQL.
        expect(page.locator("#metricCobrado")).to_contain_text("S/")
        expect(page.locator("#metricPorCobrar")).to_contain_text("S/")
        expect(page.locator("#cobrosBarra")).to_have_attribute("style", re.compile("width:"))
        expect(page.locator(".cashflow-strip .cashflow-card")).to_have_count(2)
        print("OK BROWSER: tarjetas de caja real y progreso financiero")
        page.screenshot(path="artifacts/ui/01_dashboard.png", full_page=True)
        print("OK BROWSER: alta del administrador y acceso a dashboard")

        # Abrir cada módulo por su enlace: no aceptar paneles estáticos.
        grupos = {
            "ventas": ["pedidos", "pagos", "comprobantes"],
            "catalogo": ["gestion-productos", "categorias", "marcas"],
            "inventario": ["inventario", "compras", "proveedores"],
            "clientes": ["clientes", "direcciones"],
        }
        for grupo, secciones in grupos.items():
            carpeta = page.locator(f'[data-nav-folder="{grupo}"]')
            boton = page.locator(f'button[data-nav-toggle="{grupo}"]')
            for seccion in secciones:
                if "open" not in (carpeta.get_attribute("class") or "").split():
                    boton.click()
                page.locator(f'#sidebar a[href="#{seccion}"]').click()
                expect(page.locator(f'#{seccion}')).to_have_class(re.compile("active"))
                assert page.url.endswith("#" + seccion), page.url
                assert page.locator("#topTitle").inner_text().strip() != "ADN Import's"
        for seccion, titulo in (
            ("soporte", "Atención al cliente"),
            ("reportes", "Reportes"),
        ):
            page.locator(f'#sidebar a[href="#{seccion}"]').click()
            expect(page.locator(f'#{seccion}')).to_have_class(re.compile("active"))
            expect(page.locator("#topTitle")).to_have_text(titulo)
        page.locator('a.admin[href="#configuracion"]').click()
        expect(page.locator("#configuracion")).to_have_class(re.compile("active"))
        expect(page.locator("#topTitle")).to_have_text("Configuración")
        page.locator('#sidebar a[href="#inicio"]').click()
        expect(page.locator("#inicio")).to_have_class(re.compile("active"))
        page.screenshot(path="artifacts/ui/00_menu_modulos.png", full_page=True)
        print("OK BROWSER: navegación de las 14 secciones administrativas")

        # Ejercitar de nuevo el enlace al catálogo antes de registrar el producto.
        page.locator('button[data-nav-toggle="catalogo"]').click()
        page.locator('.nav-submenu a[href="#gestion-productos"]').click()
        expect(page.locator("#gestion-productos")).to_have_class(re.compile("active"))

        formulario = page.locator("#gestion-productos form.product-form")
        formulario.locator('input[name="nombre_producto"]').fill(NOMBRE)
        formulario.locator('select[name="id_categoria"]').select_option(index=1)
        formulario.locator('select[name="id_marca"]').select_option(index=1)
        formulario.locator('[name="descripcion"]').fill("Producto creado en navegador por CI")
        formulario.locator('input[name="compatibilidad"]').fill("Motocar 200cc")
        formulario.locator('input[name="precio"]').fill("85.50")
        formulario.locator('input[name="precio_oferta"]').fill("79.90")
        formulario.locator('input[name="stock"]').fill("6")
        formulario.locator('input[name="stock_minimo"]').fill("2")
        # Una foto real cargada en el formulario debe guardarse en el
        # servidor, conservar su ruta en MySQL y visualizarse en el panel.
        formulario.locator('input[name="imagen_archivo"]').set_input_files(
            "PHP/dorada_api/assets/imagenes/01_kit_transmision_dtiex.png"
        )
        # El administrador debe ver exactamente la fotografía seleccionada
        # ANTES de guardar, evitando crear productos con imagen equivocada.
        expect(formulario.locator("#previewImagenProducto")).to_have_attribute(
            "src", re.compile(r"^blob:")
        )
        page.wait_for_function(
            "() => { const img = document.getElementById('previewImagenProducto'); "
            "return img && img.complete && img.naturalWidth > 0; }"
        )
        formulario.get_by_role("button", name="Agregar producto").click()
        expect(page.locator(".alert.ok")).to_contain_text("Producto registrado correctamente")
        expect(page.locator("#gestion-productos")).to_have_class(re.compile("active"))

        # Comprobar que tabla, búsqueda y paginación usan datos guardados.
        page.locator("#buscador").fill(NOMBRE)
        fila = page.locator("#tablaProductos tbody tr").filter(has_text=NOMBRE)
        expect(fila).to_be_visible()
        expect(fila.locator("td").nth(4)).to_contain_text("6")
        foto = fila.locator("img.product-thumb")
        expect(foto).to_be_visible()
        ruta_foto = foto.get_attribute("src")
        assert ruta_foto and ruta_foto.startswith("uploads/productos/"), ruta_foto
        respuesta_foto = page.request.get(BASE + "/" + ruta_foto)
        assert respuesta_foto.status == 200, "El servidor no publicó la foto del producto"
        assert "image/" in respuesta_foto.headers.get("content-type", ""), (
            "La imagen guardada no tiene un MIME correcto"
        )
        assert foto.evaluate("(img) => img.complete && img.naturalWidth > 0"), (
            "La fotografía no se visualiza realmente desde el navegador"
        )
        # Flutter consume la misma API pública: comprobar que recibe la URL
        # guardada en MySQL, el nombre correcto y el stock del administrador.
        productos_cliente = page.request.get(BASE + "/productos.php")
        assert productos_cliente.status == 200
        filas_cliente = productos_cliente.json()
        producto_cliente = next(
            (p for p in filas_cliente if p["nombre_producto"] == NOMBRE), None
        )
        assert producto_cliente is not None, "El producto no aparece en la API para Flutter"
        assert producto_cliente["imagen_url"] == ruta_foto, (
            "La fotografía del dashboard no coincide con la API del cliente"
        )
        assert int(producto_cliente["stock"]) == 6
        print("OK BROWSER: foto del administrador accesible desde API del cliente")
        page.locator("#buscador").fill("texto-que-no-existe-9999")
        expect(fila).to_be_hidden()
        page.locator("#buscador").fill("")
        expect(fila).to_be_visible()
        page.screenshot(path="artifacts/ui/02_producto.png", full_page=True)
        print("OK BROWSER: formulario producto, MySQL, búsqueda y filtros")
        # Actualizar desde cualquier módulo conserva la sección y vuelve a leer MySQL.
        page.locator("#refreshAllBtn").click()
        expect(page.locator("#gestion-productos")).to_have_class(re.compile("active"))
        expect(page.locator("#tablaProductos tbody tr").filter(has_text=NOMBRE)).to_be_visible()
        print("OK BROWSER: sincronización completa con MySQL sin salir del módulo")


        # Editar desde el enlace real, y comprobar la actualización de stock.
        fila.locator('a[title="Editar"]').click()
        formulario = page.locator("#gestion-productos form.product-form")
        expect(formulario.locator('input[name="stock_original"]')).to_have_value("6")
        formulario.locator('input[name="stock"]').fill("7")
        formulario.locator('input[name="precio"]').fill("92.50")
        formulario.locator('input[name="precio_oferta"]').fill("81.00")
        formulario.get_by_role("button", name="Guardar cambios").click()
        expect(page.locator(".alert.ok")).to_contain_text("Producto actualizado correctamente")

        # Movimiento desde el formulario Kardex y lectura de su resultado.
        page.goto(BASE + "/dashboard.php#inventario")
        expect(page.locator("#inventario")).to_have_class(re.compile("active"))
        mov = page.locator("#inventario form").first
        seleccionar_producto(mov.locator('select[name="id_producto_stock"]'), NOMBRE)
        mov.locator('select[name="tipo_movimiento"]').select_option("Entrada")
        mov.locator('input[name="cantidad_movimiento"]').fill("3")
        mov.locator('input[name="motivo_movimiento"]').fill("Entrada verificada desde Chromium")
        mov.get_by_role("button", name="Registrar movimiento").click()
        expect(page.locator(".alert.ok")).to_contain_text("Movimiento de stock registrado")
        expect(page.locator("#tablaKardex")).to_contain_text("Entrada verificada desde Chromium")
        page.screenshot(path="artifacts/ui/03_kardex.png", full_page=True)
        print("OK BROWSER: edición de producto e inventario/Kardex reales")

        # El informe y la descarga deben leer todos los registros, no solo la página visible.
        page.goto(BASE + "/dashboard.php#reportes")
        expect(page.locator("#reportes")).to_have_class(re.compile("active"))
        page.locator("#reportes input[name='desde']").fill("2026-01-01")
        page.locator("#reportes input[name='hasta']").fill("2026-12-31")
        page.locator("#reportes button:has-text('Aplicar periodo')").click()
        expect(page.locator("#reportes")).to_have_class(re.compile("active"))
        with page.expect_download() as info:
            page.locator("#reportes a[href^='exportar_csv.php?tipo=ventas']").click()
        descarga = info.value
        assert descarga.suggested_filename.endswith(".csv"), descarga.suggested_filename
        page.screenshot(path="artifacts/ui/04_reportes.png", full_page=True)
        print("OK BROWSER: reportes con fechas y exportación CSV real")

        # La versión móvil conserva una navegación interactiva.
        page.set_viewport_size({"width": 390, "height": 844})
        page.goto(BASE + "/dashboard.php#inicio")
        expect(page.locator("#inicio")).to_have_class(re.compile("active"))
        page.locator(".mobile-bottom a[href='#pedidos']").click()
        expect(page.locator("#pedidos")).to_have_class(re.compile("active"))
        page.screenshot(path="artifacts/ui/05_movil.png", full_page=True)
        print("OK BROWSER: navegación responsive del dashboard")

        # Integración real: el cliente se registra desde la API de Flutter
        # mientras el dashboard está abierto; el panel debe mostrarlo solo,
        # sin que el administrador tenga que cerrar sesión.
        page.set_viewport_size({"width": 1366, "height": 900})
        page.goto(BASE + "/dashboard.php#clientes")
        expect(page.locator("#clientes")).to_have_class(re.compile("active"))
        correo_cliente = "cliente-ui-" + uuid.uuid4().hex[:10] + "@example.test"
        respuesta_cliente = page.request.post(BASE + "/usuarios.php", data={
            "nombres": "Cliente desde Flutter",
            "apellidos": "Sincronizado",
            "correo": correo_cliente,
            "contrasena": "ClienteSeguro2026",
            "telefono": "999888777",
        })
        assert respuesta_cliente.status == 200, respuesta_cliente.text()
        assert respuesta_cliente.json()["estado"] is True
        assert page.locator("#tablaClientes").get_by_text(correo_cliente).count() == 0
        page.evaluate("() => { void actualizarDashboardEnVivo(false); }")
        expect(page.locator("#tablaClientes")).to_contain_text(
            correo_cliente, timeout=20000
        )
        expect(page.locator("#clientes")).to_have_class(re.compile("active"))
        print("OK BROWSER: nuevo cliente de Flutter aparece en el dashboard sin recarga manual")

        # Flujo completo entre el cliente del APK y el dashboard PHP:
        # compra autenticada -> MySQL -> nuevo pedido visible -> stock menor.
        token_cliente = respuesta_cliente.json()["token"]
        id_cliente = int(respuesta_cliente.json()["id_usuario"])
        auth_cliente = {"Authorization": "Bearer " + token_cliente}
        productos_antes = page.request.get(BASE + "/productos.php").json()
        disponible = next(
            p for p in productos_antes if p["nombre_producto"] == NOMBRE
        )
        id_producto = int(disponible["id_producto"])
        stock_antes = int(disponible["stock"])
        assert stock_antes >= 1
        clave_compra = "e2e_" + uuid.uuid4().hex
        datos_compra = {
            "id_usuario": id_cliente,
            "tipo_entrega": "Recojo en tienda",
            "metodo_pago": "Efectivo",
            "items": [{"id_producto": id_producto, "cantidad": 1}],
            "clave_operacion": clave_compra,
        }

        page.goto(BASE + "/dashboard.php#pedidos")
        expect(page.locator("#pedidos")).to_have_class(re.compile("active"))
        compra = page.request.post(
            BASE + "/pedidos.php", headers=auth_cliente, data=datos_compra
        )
        assert compra.status in (200, 201), compra.text()
        assert compra.json()["estado"] is True, compra.text()
        id_pedido = int(compra.json()["id_pedido"])

        # Repetir la misma compra durante una reconexión no debe descontar
        # stock dos veces ni generar otro pedido.
        repetida = page.request.post(
            BASE + "/pedidos.php", headers=auth_cliente, data=datos_compra
        )
        assert repetida.status in (200, 201), repetida.text()
        assert int(repetida.json()["id_pedido"]) == id_pedido
        assert repetida.json().get("reutilizado") is True

        productos_despues = page.request.get(BASE + "/productos.php").json()
        actualizado = next(
            p for p in productos_despues if int(p["id_producto"]) == id_producto
        )
        assert int(actualizado["stock"]) == stock_antes - 1, (
            "La compra del cliente debe descontar exactamente una unidad"
        )
        historial_cliente = page.request.get(
            BASE + f"/pedidos.php?id_usuario={id_cliente}",
            headers=auth_cliente,
        )
        assert historial_cliente.status == 200, historial_cliente.text()
        assert any(
            int(p["id_pedido"]) == id_pedido
            for p in historial_cliente.json()
        ), "El cliente debe ver su compra en Mis pedidos"

        # El dashboard abierto debe reflejar el pedido real creado por la API
        # del APK, no un registro ilustrativo ni una tabla estática.
        page.evaluate("() => { void actualizarDashboardEnVivo(false); }")
        expect(page.locator("#tablaPedidos")).to_contain_text(
            str(id_pedido), timeout=20000
        )
        expect(page.locator("#pedidos")).to_have_class(re.compile("active"))
        page.screenshot(
            path="artifacts/ui/06_pedido_del_cliente_en_dashboard.png",
            full_page=True,
        )
        print("OK BROWSER: compra del APK visible en PHP, stock -1, "
              "pedido de cliente, reintento sin venta duplicada")

        assert not errores_js, "Errores Javascript del dashboard: " + "; ".join(errores_js)
        print("OK BROWSER: sin errores Javascript no manejados")
        browser.close()


if __name__ == "__main__":
    main()
