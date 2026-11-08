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
        print("OK BROWSER: alta del administrador y acceso a dashboard")

        # Navegación real del menú sin alterar plantilla ni Javascript.
        page.locator('button[data-nav-toggle="catalogo"]').click()
        page.locator('.nav-submenu a[href="#gestion-productos"]').click()
        expect(page.locator("#gestion-productos")).to_have_class(re.compile("active"))

        formulario = page.locator("#gestion-productos form.product-form")
        formulario.locator('input[name="nombre_producto"]').fill(NOMBRE)
        formulario.locator('select[name="id_categoria"]').select_option(index=1)
        formulario.locator('select[name="id_marca"]').select_option(index=1)
        formulario.locator('input[name="descripcion"]').fill("Producto creado en navegador por CI")
        formulario.locator('input[name="compatibilidad"]').fill("Motocar 200cc")
        formulario.locator('input[name="precio"]').fill("85.50")
        formulario.locator('input[name="precio_oferta"]').fill("79.90")
        formulario.locator('input[name="stock"]').fill("6")
        formulario.locator('input[name="stock_minimo"]').fill("2")
        formulario.get_by_role("button", name="Agregar producto").click()
        expect(page.locator(".alert.ok")).to_contain_text("Producto registrado correctamente")
        expect(page.locator("#gestion-productos")).to_have_class(re.compile("active"))

        # Comprobar que tabla, búsqueda y paginación usan datos guardados.
        page.locator("#buscador").fill(NOMBRE)
        fila = page.locator("#tablaProductos tbody tr").filter(has_text=NOMBRE)
        expect(fila).to_be_visible()
        expect(fila.locator("td").nth(4)).to_contain_text("6")
        page.locator("#buscador").fill("texto-que-no-existe-9999")
        expect(fila).to_be_hidden()
        page.locator("#buscador").fill("")
        expect(fila).to_be_visible()
        print("OK BROWSER: formulario producto, MySQL, búsqueda y filtros")

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
        print("OK BROWSER: edición de producto e inventario/Kardex reales")

        # El informe y la descarga deben leer todos los registros, no solo la página visible.
        page.goto(BASE + "/dashboard.php#reportes")
        expect(page.locator("#reportes")).to_have_class(re.compile("active"))
        page.locator("#reportes input[name='desde']").fill("2026-01-01")
        page.locator("#reportes input[name='hasta']").fill("2026-12-31")
        page.locator("#reportes button:has-text('Aplicar periodo')").click()
        expect(page.locator("#reportes")).to_have_class(re.compile("active"))
        with page.expect_download() as info:
            page.locator('a[href="exportar_csv.php?tipo=productos"]').click()
        descarga = info.value
        assert descarga.suggested_filename.endswith(".csv"), descarga.suggested_filename
        print("OK BROWSER: reportes con fechas y exportación CSV real")

        # La versión móvil conserva una navegación interactiva.
        page.set_viewport_size({"width": 390, "height": 844})
        page.goto(BASE + "/dashboard.php#inicio")
        expect(page.locator("#inicio")).to_have_class(re.compile("active"))
        page.locator(".mobile-bottom a[href='#pedidos']").click()
        expect(page.locator("#pedidos")).to_have_class(re.compile("active"))
        print("OK BROWSER: navegación responsive del dashboard")

        assert not errores_js, "Errores Javascript del dashboard: " + "; ".join(errores_js)
        print("OK BROWSER: sin errores Javascript no manejados")
        browser.close()


if __name__ == "__main__":
    main()
