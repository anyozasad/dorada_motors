#!/usr/bin/env python3
"""Prueba integral real de la API PHP contra MySQL temporal de GitHub Actions."""
import json
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from http.cookiejar import CookieJar
from uuid import uuid4

BASE = os.getenv("DORADA_API_URL", "http://127.0.0.1:8090").rstrip("/")


def api(path, *, method="GET", body=None, token=None, status=200):
    payload = None if body is None else json.dumps(body).encode("utf-8")
    headers = {"Accept": "application/json"}
    if payload is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        f"{BASE}/{path.lstrip('/')}", headers=headers,
        method=method, data=payload,
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            code = response.status
            raw = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        code = error.code
        raw = error.read().decode("utf-8")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as error:
        raise AssertionError(
            f"{method} {path}: respuesta que no es JSON, HTTP {code}: {raw[:400]}"
        ) from error
    assert code == status, (
        f"{method} {path}: esperado HTTP {status}, recibido {code}: {data}"
    )
    return data


def admin_page(opener, path, form=None):
    headers = {"Accept": "text/html, application/json"}
    data = None
    if form is not None:
        data = urllib.parse.urlencode(form, doseq=True).encode("utf-8")
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    request = urllib.request.Request(
        f"{BASE}/{path.lstrip('/')}", headers=headers,
        method="POST" if form is not None else "GET", data=data,
    )
    with opener.open(request, timeout=20) as response:
        return response.read().decode("utf-8")


def probar_administracion_integral(navegador, csrf, id_producto):
    def enviar(accion, datos, mensaje):
        html = admin_page(navegador, "dashboard.php", form={
            "csrf_token": csrf, accion: "1", **datos,
        })
        assert mensaje in html, (
            f"{accion}: se esperaba '{mensaje}' en el resultado del dashboard"
        )
        return html

    # CRUD real de categorías y marcas, con datos que pueden verse en la API.
    sufijo = uuid4().hex[:8]
    nombre_categoria = f"Categoria Prueba {sufijo}"
    nombre_marca = f"Marca Prueba {sufijo}"
    enviar("registrar_categoria",
           {"nombre_categoria": nombre_categoria}, "Categoría registrada correctamente")
    id_categoria = next(
        int(c["id_categoria"]) for c in api("categorias.php")
        if c["nombre_categoria"] == nombre_categoria
    )
    enviar("actualizar_categoria", {
        "id_categoria": id_categoria, "nombre_categoria": nombre_categoria + " Editada",
    }, "Categoría actualizada correctamente")
    assert any(c["nombre_categoria"] == nombre_categoria + " Editada"
               for c in api("categorias.php"))
    enviar("eliminar_categoria", {"id_categoria": id_categoria}, "Categoría eliminada")
    assert not any(int(c["id_categoria"]) == id_categoria for c in api("categorias.php"))

    enviar("registrar_marca",
           {"nombre_marca": nombre_marca}, "Marca registrada correctamente")
    id_marca = next(
        int(m["id_marca"]) for m in api("marcas.php")
        if m["nombre_marca"] == nombre_marca
    )
    enviar("actualizar_marca", {
        "id_marca": id_marca, "nombre_marca": nombre_marca + " Editada",
    }, "Marca actualizada correctamente")
    assert any(m["nombre_marca"] == nombre_marca + " Editada"
               for m in api("marcas.php"))
    enviar("eliminar_marca", {"id_marca": id_marca}, "Marca eliminada")
    assert not any(int(m["id_marca"]) == id_marca for m in api("marcas.php"))

    # Proveedor y estados: la vista administrativa debe reflejar los cambios.
    razon = f"Proveedor Pruebas {sufijo}"
    enviar("registrar_proveedor", {
        "razon_social": razon, "ruc": "20123456789",
        "telefono_proveedor": "987654321",
        "correo_proveedor": "proveedor@example.test",
        "direccion_proveedor": "Jr. Comercio 100",
    }, "Proveedor registrado correctamente")
    html = admin_page(navegador, "dashboard.php")
    match = re.search(
        rf"<td>#(\d+)</td><td><strong>{re.escape(razon)}</strong>", html
    )
    assert match, "No aparece el nuevo proveedor en el dashboard"
    id_proveedor = int(match.group(1))

    datos_proveedor = {
        "id_proveedor": id_proveedor,
        "razon_social": razon, "ruc": "20123456789",
        "telefono_proveedor": "987654321",
        "correo_proveedor": "proveedor@example.test",
        "direccion_proveedor": "Jr. Comercio 101",
    }
    enviar("actualizar_proveedor", {
        **datos_proveedor, "estado_proveedor": "Inactivo",
    }, "Proveedor actualizado correctamente")
    enviar("actualizar_proveedor", {
        **datos_proveedor, "estado_proveedor": "Activo",
    }, "Proveedor actualizado correctamente")

    # Inventario/Kardex con validación de stock real.
    inventario = api(f"productos.php?id={id_producto}")
    stock_base = int(inventario["stock"])
    enviar("registrar_movimiento", {
        "id_producto_stock": id_producto, "tipo_movimiento": "Entrada",
        "cantidad_movimiento": 7, "motivo_movimiento": "Prueba ingreso",
    }, "Movimiento de stock registrado correctamente")
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_base + 7
    enviar("registrar_movimiento", {
        "id_producto_stock": id_producto, "tipo_movimiento": "Salida",
        "cantidad_movimiento": 2, "motivo_movimiento": "Prueba salida",
    }, "Movimiento de stock registrado correctamente")
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_base + 5
    enviar("registrar_movimiento", {
        "id_producto_stock": id_producto, "tipo_movimiento": "Salida",
        "cantidad_movimiento": stock_base + 900,
        "motivo_movimiento": "Salida excedida debe fallar",
    }, "No hay stock suficiente")
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_base + 5

    # Compra de varios artículos y anulación/rehabilitación de mercadería.
    id_segundo = next(
        int(x["id_producto"]) for x in api("productos.php")
        if int(x["id_producto"]) != id_producto
    )
    stock_segundo = int(api(f"productos.php?id={id_segundo}")["stock"])
    html = enviar("registrar_compra", {
        "id_proveedor_compra": id_proveedor,
        "id_producto_compra[]": [id_producto, id_segundo],
        "cantidad_compra[]": [3, 2],
        "precio_compra[]": ["11.00", "12.50"],
    }, "registrada con 2 producto(s)")
    match = re.search(r"Compra #(\d+) registrada", html)
    assert match, "No se encontró identificador de la compra creada"
    id_compra = int(match.group(1))
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_base + 8
    assert int(api(f"productos.php?id={id_segundo}")["stock"]) == stock_segundo + 2

    enviar("actualizar_estado_compra", {
        "id_compra": id_compra, "estado_compra": "Anulado",
    }, "Estado de compra actualizado")
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_base + 5
    assert int(api(f"productos.php?id={id_segundo}")["stock"]) == stock_segundo
    enviar("actualizar_estado_compra", {
        "id_compra": id_compra, "estado_compra": "Registrado",
    }, "Estado de compra actualizado")
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_base + 8
    assert int(api(f"productos.php?id={id_segundo}")["stock"]) == stock_segundo + 2

    enviar("eliminar_proveedor", {
        "id_proveedor": id_proveedor,
    }, "No se puede eliminar: el proveedor tiene compras")

    # Reporte de ventas real, con periodo seleccionable y resumen calculado.
    pagina = admin_page(
        navegador,
        "dashboard.php?desde=2020-01-01&hasta=2030-12-31",
    )
    assert "Reportes y análisis" in pagina
    assert "TICKET PROMEDIO" in pagina
    print("OK: categorías, marcas, proveedores, stock, Kardex,")
    print("    compras con varios productos, anulación, reactivación y reportes.")


def probar_dashboard_admin(id_pedido, id_usuario, token, id_producto, stock_original, otro_id, otro_token, id_solicitud):
    navegador = urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(CookieJar())
    )
    inicio = admin_page(navegador, "admin_login.php")
    match = re.search(r'name="csrf_token" value="([a-f0-9]{64})"', inicio)
    assert match, "No se encontró el token CSRF del formulario administrativo"
    csrf = match.group(1)

    # Primera instalación: crear un administrador desde el formulario real.
    creada = admin_page(navegador, "admin_login.php", form={
        "csrf_token": csrf, "crear_admin_inicial": "1",
        "nombres": "Administración", "apellidos": "Pruebas",
        "correo": f"admin-{uuid4().hex[:10]}@example.test",
        "contrasena": "ClaveAdmin_2026",
        "confirmar_contrasena": "ClaveAdmin_2026",
    })
    assert "Producto" in creada and "Pedidos" in creada, (
        "No se abrió el dashboard tras crear el administrador"
    )
    assert "Atención al cliente" in creada, "El dashboard no muestra el módulo de soporte"
    atendido = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf,
        "responder_soporte": "1",
        "id_solicitud": str(id_solicitud),
        "estado_soporte": "Respondido",
        "respuesta_soporte": "Tu consulta fue revisada. Puedes continuar con la compra.",
    })
    assert f"Solicitud #{id_solicitud} actualizada correctamente" in atendido, (
        "El administrador no pudo responder la solicitud"
    )
    solicitudes = api("soporte.php", token=token)
    caso = next(x for x in solicitudes["solicitudes"] if int(x["id_solicitud"]) == id_solicitud)
    assert caso["estado"] == "Respondido", caso
    assert "Tu consulta fue revisada" in caso["respuesta"], caso

    metricas = json.loads(admin_page(navegador, "dashboard_api.php"))
    assert metricas["estado"] is True, metricas

    categorias = api("categorias.php")
    marcas = api("marcas.php")
    assert categorias and marcas
    id_categoria = int(categorias[0]["id_categoria"])
    id_marca = int(marcas[0]["id_marca"])
    nombre = f"Repuesto de control {uuid4().hex[:8]}"
    formulario = {
        "csrf_token": csrf, "id_categoria": id_categoria,
        "id_marca": id_marca, "nombre_producto": nombre,
        "descripcion": "Artículo creado desde el dashboard PHP",
        "tipo_vehiculo": "Motocicleta", "compatibilidad": "125cc",
        "precio": "24.50", "precio_oferta": "22.00",
        "stock": "9", "stock_minimo": "2", "imagen_url": "",
    }

    nuevo = admin_page(
        navegador, "dashboard.php",
        form={**formulario, "registrar_producto": "1"},
    )
    assert "Producto registrado correctamente" in nuevo, (
        "No se registró el producto desde el dashboard"
    )
    productos = api("productos.php")
    encontrados = [p for p in productos if p["nombre_producto"] == nombre]
    assert len(encontrados) == 1, encontrados
    id_nuevo = int(encontrados[0]["id_producto"])

    actualizado = admin_page(
        navegador, "dashboard.php",
        form={**formulario, "actualizar_producto": "1",
              "id_producto": str(id_nuevo), "precio": "28.00",
              "stock": "12"},
    )
    assert "Producto actualizado correctamente" in actualizado
    registro = api(f"productos.php?id={id_nuevo}")
    assert float(registro["precio"]) == 28.0, registro
    assert int(registro["stock"]) == 12, registro

    borrado = admin_page(
        navegador, "dashboard.php",
        form={"csrf_token": csrf, "eliminar_producto": "1",
              "id_producto": str(id_nuevo)},
    )
    assert "Producto eliminado correctamente" in borrado
    assert api(f"productos.php?id={id_nuevo}", status=404)["estado"] is False

    # Cancelar desde el dashboard revierte el stock descontado por Flutter.
    cancelado = admin_page(
        navegador, "dashboard.php",
        form={"csrf_token": csrf, "actualizar_estado_pedido": "1",
              "id_pedido": str(id_pedido), "estado_pedido": "Cancelado"},
    )
    assert "Estado del pedido actualizado" in cancelado, (
        "No se canceló el pedido desde PHP"
    )
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_original
    historial = api(f"pedidos.php?id_usuario={id_usuario}", token=token)
    registro_pedido = next(p for p in historial if int(p["id_pedido"]) == id_pedido)
    assert registro_pedido["estado_pedido"] == "Cancelado", registro_pedido

    reactivado = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf, "actualizar_estado_pedido": "1",
        "id_pedido": str(id_pedido), "estado_pedido": "Procesando",
    })
    assert "Estado del pedido actualizado" in reactivado
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_original - 2
    cancelado_otra_vez = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf, "actualizar_estado_pedido": "1",
        "id_pedido": str(id_pedido), "estado_pedido": "Cancelado",
    })
    assert "Estado del pedido actualizado" in cancelado_otra_vez
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_original

    pagos = json.loads(admin_page(navegador, "pagos.php"))
    assert any(
        int(p["id_pedido"]) == id_pedido and p["estado_pago"] == "Rechazado"
        for p in pagos
    ), pagos
    # Confirmación de pago y emisión de comprobante imprimible.
    otro_pedido = api("pedidos.php", method="POST", token=otro_token, status=201, body={
        "id_usuario": otro_id, "tipo_entrega": "Recojo en tienda",
        "metodo_pago": "Efectivo",
        "items": [{"id_producto": id_producto, "cantidad": 1}],
    })
    id_otro_pedido = int(otro_pedido["id_pedido"])
    pagos = json.loads(admin_page(navegador, "pagos.php"))
    pago_pendiente = next(x for x in pagos if int(x["id_pedido"]) == id_otro_pedido)
    assert pago_pendiente["estado_pago"] == "Pendiente", pago_pendiente

    confirmado = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf, "actualizar_estado_pago": "1",
        "id_pago": str(pago_pendiente["id_pago"]), "estado_pago": "Pagado",
    })
    assert "Estado del pago actualizado" in confirmado, confirmado[:350]
    nuevos_pedidos = api(f"pedidos.php?id_usuario={otro_id}", token=otro_token)
    actual = next(p for p in nuevos_pedidos if int(p["id_pedido"]) == id_otro_pedido)
    assert actual["estado_pedido"] == "Pagado", actual

    comprobante = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf, "registrar_comprobante": "1",
        "id_pedido_comprobante": str(id_otro_pedido),
        "tipo_comprobante": "Boleta", "numero_comprobante": "",
    })
    assert "Comprobante B001-" in comprobante, (
        "No se emitió la boleta de demostración"
    )
    pagina_dashboard = admin_page(navegador, "dashboard.php")
    enlaces = re.findall(r'comprobante_print\.php\?id=(\d+)', pagina_dashboard)
    assert enlaces, "No se encontró enlace de impresión de comprobante"
    impresion = admin_page(navegador, f"comprobante_print.php?id={enlaces[0]}")
    assert "BOLETA" in impresion and "S/ " in impresion
    probar_administracion_integral(navegador, csrf, id_producto)
    print("OK: confirmar pago, actualizar estado y emitir boleta imprimible.")
    print("OK: dashboard PHP, sesión admin, CSRF, CRUD producto,")
    print("    métricas, cancelación de pedido, reversión stock y pago.")


def verificar_cors_web():
    origen = "http://localhost:8080"
    request = urllib.request.Request(
        f"{BASE}/config_publica.php", headers={"Origin": origen},
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        assert response.status == 200
        assert response.headers.get("Access-Control-Allow-Origin") == origen

    preflight = urllib.request.Request(
        f"{BASE}/pedidos.php",
        method="OPTIONS",
        headers={
            "Origin": origen,
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "content-type,authorization",
        },
    )
    with urllib.request.urlopen(preflight, timeout=20) as response:
        assert response.status == 204
        assert response.headers.get("Access-Control-Allow-Origin") == origen
        allowed = response.headers.get("Access-Control-Allow-Headers", "").lower()
        assert "authorization" in allowed and "content-type" in allowed
    print("OK: CORS Flutter Web (GET y preflight autenticado).")


def probar_cuenta_soporte(id_usuario, token, otro_token):
    assert api("cuenta.php", status=401)["estado"] is False
    assert api("soporte.php", status=401)["estado"] is False

    cuenta = api("cuenta.php", token=token)["usuario"]
    assert int(cuenta["id_usuario"]) == id_usuario, cuenta
    nuevo_correo = f"perfil-{uuid4().hex[:12]}@example.test"
    perfil = api("cuenta.php", method="PUT", token=token, body={
        "accion": "perfil",
        "nombres": "Cliente Actualizado",
        "apellidos": "Pruebas",
        "correo": nuevo_correo,
        "telefono": "988776655",
    })
    assert perfil["estado"] is True, perfil
    cuenta = api("cuenta.php", token=token)["usuario"]
    assert cuenta["correo"] == nuevo_correo, cuenta
    assert cuenta["telefono"] == "988776655", cuenta

    otro = api("cuenta.php", method="PUT", token=otro_token, status=409, body={
        "accion": "perfil",
        "nombres": "Otro",
        "apellidos": "Pruebas",
        "correo": nuevo_correo,
        "telefono": "977654321",
    })
    assert otro["estado"] is False, otro

    clave_mala = api("cuenta.php", method="PUT", token=token, status=403, body={
        "accion": "clave",
        "contrasena_actual": "contraseña-incorrecta",
        "contrasena_nueva": "NuevaClave_2026",
    })
    assert clave_mala["estado"] is False
    cambio = api("cuenta.php", method="PUT", token=token, body={
        "accion": "clave",
        "contrasena_actual": "DemoSeguro_2026",
        "contrasena_nueva": "NuevaClave_2026",
    })
    assert cambio["estado"] is True
    assert api("login.php", method="POST", body={
        "correo": nuevo_correo,
        "contrasena": "DemoSeguro_2026",
    })["estado"] is False
    assert api("login.php", method="POST", body={
        "correo": nuevo_correo,
        "contrasena": "NuevaClave_2026",
    })["estado"] is True

    caso = api("soporte.php", method="POST", token=token, status=201, body={
        "asunto": "Consulta por repuesto",
        "mensaje": "Necesito consultar compatibilidad de una pieza de motor.",
    })
    assert caso["estado"] is True, caso
    id_solicitud = int(caso["id_solicitud"])
    mis_casos = api("soporte.php", token=token)["solicitudes"]
    assert any(int(x["id_solicitud"]) == id_solicitud for x in mis_casos)
    casos_otra_cuenta = api("soporte.php", token=otro_token)["solicitudes"]
    assert not any(int(x["id_solicitud"]) == id_solicitud for x in casos_otra_cuenta)
    print("OK: perfil editable, cambio de clave, correos únicos y soporte privado.")
    return id_solicitud


def crear_cliente(nombre):
    correo = f"ci-{uuid4().hex[:12]}@example.test"
    respuesta = api("usuarios.php", method="POST", status=200, body={
        "nombres": nombre, "apellidos": "Pruebas",
        "correo": correo, "contrasena": "DemoSeguro_2026",
        "telefono": "987654321",
    })
    assert respuesta.get("estado") is True, respuesta
    token = respuesta.get("token")
    identificador = int(respuesta.get("id_usuario", 0))
    assert isinstance(token, str) and len(token) == 64, respuesta
    assert identificador > 0, respuesta
    autenticado = api("login.php", method="POST", body={
        "correo": correo, "contrasena": "DemoSeguro_2026",
    })
    assert autenticado.get("estado") is True, autenticado
    assert int(autenticado["usuario"]["id_usuario"]) == identificador
    assert len(autenticado["token"]) == 64
    return identificador, token


def main():
    # La API inicia MySQL y precarga catálogo en una instalación vacía.
    for intento in range(25):
        try:
            productos = api("productos.php")
            break
        except (urllib.error.URLError, ConnectionError):
            if intento == 24:
                raise
            time.sleep(1)
    assert isinstance(productos, list) and len(productos) >= 19, productos
    product = productos[0]
    id_producto = int(product["id_producto"])
    precio_base = float(product["precio"])
    oferta = float(product.get("precio_oferta") or 0)
    precio = oferta if 0 < oferta < precio_base else precio_base
    stock_anterior = int(product["stock"])
    assert stock_anterior >= 3

    configuracion = api("config_publica.php")
    assert configuracion["estado"] is True
    costo_delivery = float(configuracion["costo_delivery"])
    assert costo_delivery == 5.0, configuracion
    verificar_cors_web()

    # Los datos de compra y otros clientes no son públicos.
    assert api("pedidos.php?id_usuario=1", status=401)["estado"] is False
    assert api("carrito.php?id_usuario=1", status=401)["estado"] is False
    assert api("dashboard_api.php", status=401)["estado"] is False
    assert api("productos.php", method="POST", body={}, status=403)["estado"] is False

    id_usuario, token = crear_cliente("Cliente Uno")
    otro_id, otro_token = crear_cliente("Cliente Dos")
    id_solicitud = probar_cuenta_soporte(id_usuario, token, otro_token)

    # Un token no permite suplantar otra cuenta a través de id_usuario.
    assert api(f"pedidos.php?id_usuario={id_usuario}", token=otro_token, status=403)["estado"] is False
    assert api(f"favoritos.php?id_usuario={id_usuario}", token=otro_token, status=403)["estado"] is False

    # CRUD de favoritos guardado en la base.
    api("favoritos.php", method="POST", token=token, body={
        "id_usuario": id_usuario, "id_producto": id_producto, "accion": "agregar",
    })
    favoritos = api(f"favoritos.php?id_usuario={id_usuario}", token=token)
    assert any(int(x["id_producto"]) == id_producto for x in favoritos), favoritos
    api("favoritos.php", method="POST", token=token, body={
        "id_usuario": id_usuario, "id_producto": id_producto, "accion": "quitar",
    })
    assert api(f"favoritos.php?id_usuario={id_usuario}", token=token) == []

    # El carrito se guarda en MySQL y usa el precio con descuento.
    api("carrito.php", method="POST", token=token, body={
        "id_usuario": id_usuario, "id_producto": id_producto, "cantidad": 2,
    })
    carrito = api(f"carrito.php?id_usuario={id_usuario}", token=token)
    assert carrito["estado"] is True and len(carrito["items"]) == 1, carrito
    assert int(carrito["items"][0]["cantidad"]) == 2, carrito
    assert abs(float(carrito["total"]) - 2 * precio) < 0.01, carrito

    # Dirección de delivery: insertar, consultar, editar y proteger.
    direccion = api("direcciones.php", method="POST", token=token, status=201, body={
        "id_usuario": id_usuario, "departamento": "Ucayali",
        "provincia": "Coronel Portillo", "distrito": "Callería",
        "direccion_detalle": "Jr. Pruebas 100", "referencia": "Portón azul",
    })
    id_direccion = int(direccion["id_direccion"])
    api("direcciones.php", method="PUT", token=token, body={
        "id_usuario": id_usuario, "id_direccion": id_direccion,
        "departamento": "Ucayali", "provincia": "Coronel Portillo",
        "distrito": "Callería", "direccion_detalle": "Jr. Pruebas 101",
        "referencia": "Portón azul",
    })
    actualizada = api(f"direcciones.php?id={id_direccion}", token=token)
    assert actualizada["direccion_detalle"] == "Jr. Pruebas 101", actualizada
    assert api(f"direcciones.php?id={id_direccion}", token=otro_token, status=404)["estado"] is False

    # Pedido real con stock, transacción, pago pendiente y delivery configurado.
    pedido = api("pedidos.php", method="POST", token=token, status=201, body={
        "id_usuario": id_usuario,
        "id_direccion": id_direccion,
        "tipo_entrega": "Delivery",
        "metodo_pago": "Yape",
        "items": [{"id_producto": id_producto, "cantidad": 2}],
    })
    assert pedido["estado"] is True, pedido
    assert abs(float(pedido["total"]) - (2 * precio + costo_delivery)) < 0.01, pedido
    id_pedido = int(pedido["id_pedido"])

    inventario = api(f"productos.php?id={id_producto}")
    assert int(inventario["stock"]) == stock_anterior - 2, inventario
    historial = api(f"pedidos.php?id_usuario={id_usuario}", token=token)
    assert any(int(x["id_pedido"]) == id_pedido for x in historial), historial
    registrado = next(x for x in historial if int(x["id_pedido"]) == id_pedido)
    assert registrado["estado_pedido"] == "Pendiente", registrado
    assert registrado["metodo_pago"] == "Yape", registrado
    assert int(registrado["items"][0]["cantidad"]) == 2, registrado

    # La compra vacía el carrito del servidor.
    carrito_final = api(f"carrito.php?id_usuario={id_usuario}", token=token)
    assert carrito_final["items"] == [], carrito_final

    # Stock insuficiente: transacción rechazada sin perder existencias.
    falla = api("pedidos.php", method="POST", token=token, status=400, body={
        "id_usuario": id_usuario,
        "tipo_entrega": "Recojo en tienda",
        "metodo_pago": "Efectivo",
        "items": [{"id_producto": id_producto, "cantidad": stock_anterior + 500}],
    })
    assert falla["estado"] is False, falla
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_anterior - 2

    # No se pueden eliminar direcciones ligadas a pedidos; las otras sí.
    vinculada = api(
        f"direcciones.php?id={id_direccion}", method="DELETE",
        token=token, status=409,
    )
    assert vinculada["estado"] is False, vinculada

    nueva = api("direcciones.php", method="POST", token=token, status=201, body={
        "id_usuario": id_usuario, "departamento": "Ucayali",
        "provincia": "Coronel Portillo", "distrito": "Callería",
        "direccion_detalle": "Av. Prueba 202", "referencia": "",
    })
    eliminada = api(
        f"direcciones.php?id={nueva['id_direccion']}",
        method="DELETE", token=token,
    )
    assert eliminada["estado"] is True, eliminada

    # Verificar las operaciones reales del dashboard sobre ese mismo pedido.
    probar_dashboard_admin(
        id_pedido, id_usuario, token, id_producto, stock_anterior,
        otro_id, otro_token, id_solicitud,
    )

    # El cierre de sesión revoca el token y prohíbe futuras consultas.
    assert api("cliente_logout.php", method="POST", token=token)["estado"] is True
    assert api(f"pedidos.php?id_usuario={id_usuario}", token=token, status=401)["estado"] is False
    print("OK: catálogo, autenticación, aislamiento por usuario, favoritos, carrito,")
    print("    direcciones, pedido, stock, precio, delivery, historial y cierre de sesión.")


if __name__ == "__main__":
    main()
