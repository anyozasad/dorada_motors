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



def admin_api(opener, path, *, method="GET", body=None, csrf=None, status=200):
    data = None if body is None else json.dumps(body).encode("utf-8")
    headers = {"Accept": "application/json"}
    if data is not None:
        headers["Content-Type"] = "application/json"
    if csrf:
        headers["X-CSRF-Token"] = csrf
    req = urllib.request.Request(
        f"{BASE}/{path.lstrip('/')}", headers=headers,
        data=data, method=method,
    )
    try:
        with opener.open(req, timeout=20) as response:
            code = response.status
            raw = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        code = error.code
        raw = error.read().decode("utf-8")
    assert code == status, f"{method} {path}: HTTP {code} (esperado {status}) {raw[:350]}"
    return json.loads(raw)


def probar_pagos_api_administrativa(navegador, csrf, id_producto, cliente, token):
    # El endpoint JSON debe cumplir las mismas reglas financieras que el dashboard.
    pedido = api("pedidos.php", method="POST", token=token, status=201, body={
        "id_usuario": cliente,
        "tipo_entrega": "Recojo en tienda",
        "metodo_pago": "Efectivo",
        "items": [{"id_producto": id_producto, "cantidad": 1}],
    })
    id_pedido = int(pedido["id_pedido"])
    total_centimos = round(float(pedido["total"]) * 100)
    assert total_centimos >= 2
    mitad = total_centimos // 2
    restante = total_centimos - mitad

    datos = {
        "id_pedido": id_pedido, "metodo_pago": "Efectivo",
        "monto": round(mitad / 100, 2), "estado_pago": "Pagado",
    }
    assert admin_api(navegador, "pagos.php", method="POST", body=datos,
                     status=419)["estado"] is False
    assert admin_api(navegador, "pagos.php", method="POST", csrf=csrf,
                     body={**datos, "monto": 0}, status=422)["estado"] is False

    primer_abono = admin_api(navegador, "pagos.php", method="POST", csrf=csrf,
                            body=datos, status=201)
    assert primer_abono["saldo_pendiente"] > 0, primer_abono
    historial = api(f"pedidos.php?id_usuario={cliente}", token=token)
    estado = next(x for x in historial if int(x["id_pedido"]) == id_pedido)
    assert estado["estado_pedido"] == "Pendiente", estado

    final = admin_api(navegador, "pagos.php", method="POST", csrf=csrf, body={
        **datos, "monto": round(restante / 100, 2),
    }, status=201)
    assert final["saldo_pendiente"] == 0, final
    assert final["estado_pedido"] == "Pagado", final

    sobrepago = admin_api(navegador, "pagos.php", method="POST", csrf=csrf,
                         body=datos, status=409)
    assert sobrepago["estado"] is False, sobrepago

    otro = api("pedidos.php", method="POST", token=token, status=201, body={
        "id_usuario": cliente, "tipo_entrega": "Recojo en tienda",
        "metodo_pago": "Efectivo",
        "items": [{"id_producto": id_producto, "cantidad": 1}],
    })
    cancelado = api("cliente_cancelar_pedido.php", method="POST", token=token,
                   body={"id_pedido": int(otro["id_pedido"])})
    assert cancelado["estado"] is True
    imposible = admin_api(navegador, "pagos.php", method="POST", csrf=csrf,
                          body={**datos,"id_pedido":int(otro["id_pedido"])},
                          status=409)
    assert imposible["estado"] is False
    print("OK: API pagos rechaza CSRF, sobrepagos y cancelados; suma abonos parciales.")


def probar_productos_api(navegador, csrf):
    categorias = api("categorias.php")
    marcas = api("marcas.php")
    assert categorias and marcas
    base = {
        "id_categoria": int(categorias[0]["id_categoria"]),
        "id_marca": int(marcas[0]["id_marca"]),
        "nombre_producto": f"Producto API {uuid4().hex[:8]}",
        "descripcion": "Verifica transacciones de Kardex",
        "tipo_vehiculo": "Motocicleta",
        "compatibilidad": "Modelo de prueba",
        "precio": 25.0,
        "precio_oferta": 0,
        "stock": 4,
        "stock_minimo": 2,
        "imagen_url": "",
    }
    invalido = admin_api(navegador,"productos.php",method="POST",
                          csrf=csrf,body={**base,"precio":-9},status=422)
    assert invalido["estado"] is False
    oferta_invalida = admin_api(navegador,"productos.php",method="POST",
                          csrf=csrf,body={**base,"precio_oferta":30},status=422)
    assert oferta_invalida["estado"] is False
    referencia_invalida = admin_api(navegador,"productos.php",method="POST",
                          csrf=csrf,body={**base,"id_marca":999999},status=422)
    assert referencia_invalida["estado"] is False

    nuevo = admin_api(navegador,"productos.php",method="POST",
                      csrf=csrf,body=base,status=201)
    id_producto = int(nuevo["id_producto"])
    actual = api(f"productos.php?id={id_producto}")
    assert int(actual["stock"]) == 4, actual

    rechazada = admin_api(navegador,"productos.php",method="PUT",csrf=csrf,
                           body={**base,"id_producto":id_producto,"stock":-3},
                           status=422)
    assert rechazada["estado"] is False
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == 4

    cambiada = admin_api(navegador,"productos.php",method="PUT",csrf=csrf,body={
        **base, "id_producto":id_producto, "precio":31.50, "stock":7,
    })
    assert cambiada["estado"] is True
    actual = api(f"productos.php?id={id_producto}")
    assert float(actual["precio"]) == 31.50
    assert int(actual["stock"]) == 7

    eliminado = admin_api(navegador,"productos.php",method="DELETE",csrf=csrf,
                         body={"id_producto":id_producto})
    assert eliminado["estado"] is True
    assert api(f"productos.php?id={id_producto}",status=404)["estado"] is False
    print("OK: API productos con stock transaccional, límites, referencias y CRUD.")


def probar_revocacion_de_personal(navegador_admin, csrf):
    correo = f"vendedor-{uuid4().hex[:10]}@example.test"
    clave = "ClaveVendedor_2026"
    admin_page(navegador_admin, "dashboard.php", form={
        "csrf_token": csrf, "crear_usuario_admin": "1",
        "admin_nombres": "Vendedor", "admin_apellidos": "Temporal",
        "admin_correo": correo, "admin_contrasena": clave,
        "admin_rol": "Vendedor", "admin_telefono": "999888777",
    })

    personal = admin_page(navegador_admin, "dashboard.php")
    pos = personal.find(f"<td>{correo}</td>")
    assert pos >= 0, "No aparece el usuario vendedor en el panel"
    match = re.search(r'name="id_usuario_admin" value="(\d+)"', personal[pos:pos + 1800])
    assert match, "No se pudo leer el ID del vendedor"
    id_personal = int(match.group(1))

    navegador_vendedor = urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(CookieJar())
    )
    entrada = admin_page(navegador_vendedor, "admin_login.php")
    match = re.search(r'name="csrf_token" value="([a-f0-9]{64})"', entrada)
    assert match
    acceso = admin_page(navegador_vendedor, "admin_login.php", form={
        "csrf_token": match.group(1), "iniciar_admin": "1",
        "correo": correo, "contrasena": clave,
    })
    assert "Dashboard" in acceso or "Panel" in acceso
    assert isinstance(admin_api(navegador_vendedor, "pagos.php"), list)
    try:
        admin_page(navegador_vendedor, "exportar_csv.php?tipo=productos")
        raise AssertionError("Vendedor pudo exportar productos fuera de su permiso")
    except urllib.error.HTTPError as error:
        assert error.code == 403, error.code
    assert "Pedido;Fecha;Cliente" in admin_page(
        navegador_vendedor, "exportar_csv.php?tipo=pedidos"
    )

    cambiar = admin_page(navegador_admin, "dashboard.php", form={
        "csrf_token": csrf, "actualizar_usuario_admin": "1",
        "id_usuario_admin": str(id_personal),
        "rol_usuario_admin": "Almacen", "estado_usuario_admin": "Activo",
    })
    assert "Cuenta administrativa actualizada" in cambiar
    assert admin_api(navegador_vendedor, "pagos.php", status=403)["estado"] is False

    bloquear = admin_page(navegador_admin, "dashboard.php", form={
        "csrf_token": csrf, "actualizar_usuario_admin": "1",
        "id_usuario_admin": str(id_personal),
        "rol_usuario_admin": "Almacen", "estado_usuario_admin": "Bloqueado",
    })
    assert "Cuenta administrativa actualizada" in bloquear
    assert admin_api(navegador_vendedor, "dashboard_api.php", status=401)["estado"] is False
    print("OK: roles actualizados y sesión administrativa revocada al bloquear empleado.")


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
    for tipo, cabecera in [
        ("productos", "ID;Producto;Categoria;Marca"),
        ("clientes", "ID;Nombres;Apellidos;Correo"),
        ("pagos", "Pago;Pedido;Fecha;Metodo"),
        ("pedidos", "Pedido;Fecha;Cliente;Correo"),
        ("compras", "Compra;Fecha;Proveedor;Total"),
        ("kardex", "Movimiento;Fecha;Producto;Tipo"),
        ("ventas", "Fecha;Pedidos;Ventas"),
    ]:
        fechas = "&desde=2020-01-01&hasta=2030-12-31" if tipo == "ventas" else ""
        archivo = admin_page(navegador, f"exportar_csv.php?tipo={tipo}{fechas}")
        assert cabecera in archivo, (tipo, archivo[:180])
    archivo_pedidos = admin_page(navegador, "exportar_csv.php?tipo=pedidos")
    assert ";Fecha;Cliente;" in archivo_pedidos
    print("OK: siete exportaciones CSV completas, seguras y filtrables desde MySQL.")
    print("OK: categorías, marcas, proveedores, stock, Kardex,")
    print("    compras con varios productos, anulación, reactivación y reportes.")


def probar_dashboard_admin(id_pedido, id_usuario, token, id_producto, stock_original, otro_id, otro_token, id_solicitud, id_recuperacion, correo_recuperacion):
    navegador = urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(CookieJar())
    )
    instalador_publico = admin_page(navegador, "instalar.php")
    assert "Verificar / importar base de datos" not in instalador_publico, (
        "El instalador SQL no debe estar disponible sin iniciar sesión"
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
    assert "YP-45678123" in creada, "No se muestra la referencia en pagos administrativos"
    probar_revocacion_de_personal(navegador, csrf)
    probar_productos_api(navegador, csrf)
    instalar_get = admin_page(navegador, "instalar.php")
    assert "Verificar / importar base de datos" in instalar_get
    assert "Acceso administrativo comprobado" in instalar_get
    instalar_invalid = admin_page(navegador, "instalar.php", form={})
    assert "token de seguridad es inválido" in instalar_invalid

    # Los destinos oficiales son configurados por el administrador y leídos en Flutter.
    formulario_empresa = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf, "guardar_config_empresa": "1",
        "nombre_comercial": "Dorada Motors", "razon_social": "ADN Import's",
        "ruc": "20123456789", "telefono_empresa": "986543210",
        "correo_empresa": "empresa@example.test", "moneda": "S/",
        "direccion_empresa": "Pucallpa", "igv": "18", "costo_delivery": "5",
        "numero_yape": "987654321", "numero_plin": "977654321",
        "cuenta_transferencia": "Banco Pruebas CCI 12345678901234567890",
    })
    assert "Datos de la empresa actualizados correctamente" in formulario_empresa
    destinos = api("config_publica.php")
    assert destinos["numero_yape"] == "987654321", destinos
    assert destinos["numero_plin"] == "977654321", destinos
    assert "CCI" in destinos["cuenta_transferencia"], destinos
    assert float(destinos["costo_delivery"]) == 5.0, destinos
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

    for campos, error in [
        ({"precio": "-2.00", "precio_oferta": "0"}, "precio debe ser mayor"),
        ({"stock": "-3"}, "stock no puede ser negativo"),
        ({"precio_oferta": "200.00"}, "oferta debe ser mayor"),
    ]:
        invalido = admin_page(
            navegador, "dashboard.php",
            form={**formulario, **campos, "registrar_producto": "1"},
        )
        assert error in invalido, (campos, invalido[:250])

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
    kardex_inicial = nuevo.split('id="tablaKardex"',1)[1].split("</table>",1)[0]
    assert re.search(rf"{re.escape(nombre)}.*?Stock inicial desde dashboard", kardex_inicial, re.S), (
        "El stock inicial del producto no figura como entrada en el Kardex"
    )

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
    kardex_editado = actualizado.split('id="tablaKardex"',1)[1].split("</table>",1)[0]
    assert re.search(rf"{re.escape(nombre)}.*?Ajuste desde edición de producto", kardex_editado, re.S), (
        "Editar stock no registró movimiento de Kardex"
    )

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
    pagos_reactivados = json.loads(admin_page(navegador, "pagos.php"))
    pago_nuevo = [
        p for p in pagos_reactivados
        if int(p["id_pedido"]) == id_pedido and p["estado_pago"] == "Pendiente"
    ]
    assert len(pago_nuevo) == 1, pagos_reactivados
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
    regresion = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf, "actualizar_estado_pedido": "1",
        "id_pedido": str(id_otro_pedido), "estado_pedido": "Pendiente",
    })
    assert "Transición no permitida" in regresion
    despues = api(f"pedidos.php?id_usuario={otro_id}", token=otro_token)
    assert next(p for p in despues if int(p["id_pedido"]) == id_otro_pedido)["estado_pedido"] == "Pagado"

    cancelacion_admin_pagada = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf, "actualizar_estado_pedido": "1",
        "id_pedido": str(id_otro_pedido), "estado_pedido": "Cancelado",
    })
    assert "gestionar el reembolso" in cancelacion_admin_pagada
    assert api(f"pedidos.php?id_usuario={otro_id}", token=otro_token)[0]["estado_pedido"] == "Pagado"
    cancelacion_pagada = api("cliente_cancelar_pedido.php", method="POST",
                            token=otro_token, status=409,
                            body={"id_pedido": id_otro_pedido})
    assert cancelacion_pagada["estado"] is False
    assert api(f"pedidos.php?id_usuario={otro_id}", token=otro_token)[0]["estado_pedido"] == "Pagado"

    # Pago digital completo: Flutter informa referencia y el administrador valida.
    pedido_yape = api("pedidos.php", method="POST", token=otro_token, status=201, body={
        "id_usuario": otro_id, "tipo_entrega": "Recojo en tienda",
        "metodo_pago": "Yape",
        "items": [{"id_producto": id_producto, "cantidad": 1}],
    })
    id_yape = int(pedido_yape["id_pedido"])
    reporte = api("cliente_reportar_pago.php", method="POST", token=otro_token, body={
        "id_pedido": id_yape, "referencia": "YAPE-20261107",
    })
    assert reporte["estado_pago"] == "Pendiente", reporte
    pagos_antes = json.loads(admin_page(navegador, "pagos.php"))
    pago_yape = next(p for p in pagos_antes if int(p["id_pedido"]) == id_yape)
    assert pago_yape["referencia_cliente"] == "YAPE-20261107", pago_yape
    assert pago_yape["estado_pago"] == "Pendiente", pago_yape
    actualizado = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf,
        "actualizar_estado_pago": "1",
        "id_pago": str(pago_yape["id_pago"]), "estado_pago": "Pagado",
    })
    assert "Estado del pago actualizado" in actualizado
    historial_yape = api(f"pedidos.php?id_usuario={otro_id}", token=otro_token)
    pagado_yape = next(p for p in historial_yape if int(p["id_pedido"]) == id_yape)
    assert pagado_yape["estado_pedido"] == "Pagado", pagado_yape
    assert pagado_yape["estado_pago"] == "Pagado", pagado_yape
    assert pagado_yape["referencia_pago"] == "YAPE-20261107", pagado_yape
    print("OK: referencia de Yape, verificación administrativa y estado pagado en Flutter.")

    # Un comprobante todavía no emitido no debe mostrarse en Flutter.
    sin_emitir = api(
        f"cliente_comprobante.php?id_pedido={id_otro_pedido}",
        token=otro_token, status=404,
    )
    assert sin_emitir["estado"] is False, sin_emitir

    comprobante = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf, "registrar_comprobante": "1",
        "id_pedido_comprobante": str(id_otro_pedido),
        "tipo_comprobante": "Boleta", "numero_comprobante": "",
    })
    assert "Comprobante B001-" in comprobante, (
        "No se emitió la boleta de demostración"
    )
    # Flutter consulta la boleta de su propia compra; otro cliente no puede leerla.
    boleta_cliente = api(
        f"cliente_comprobante.php?id_pedido={id_otro_pedido}", token=otro_token,
    )
    assert boleta_cliente["estado"] is True, boleta_cliente
    assert boleta_cliente["comprobante"]["tipo_comprobante"] == "Boleta"
    assert boleta_cliente["items"] and float(boleta_cliente["comprobante"]["total"]) > 0
    assert api(
        f"cliente_comprobante.php?id_pedido={id_otro_pedido}",
        token=token, status=404,
    )["estado"] is False
    assert api(
        f"cliente_comprobante.php?id_pedido={id_otro_pedido}",
        status=401,
    )["estado"] is False
    print("OK: comprobantes del cliente visibles en Flutter, protegidos por sesión.")
    pagina_dashboard = admin_page(navegador, "dashboard.php")
    enlaces = re.findall(r'comprobante_print\.php\?id=(\d+)', pagina_dashboard)
    assert enlaces, "No se encontró enlace de impresión de comprobante"
    impresion = admin_page(navegador, f"comprobante_print.php?id={enlaces[0]}")
    assert "BOLETA" in impresion and "S/ " in impresion
    probar_administracion_integral(navegador, csrf, id_producto)
    probar_pagos_api_administrativa(navegador, csrf, id_producto, otro_id, otro_token)

    no_verificado = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf,
        "restablecer_clave_cliente": "1",
        "id_solicitud": id_recuperacion,
        "clave_temporal": "Temporal_2026_Verificada",
    })
    assert "verifica la identidad" in no_verificado
    assert api("cuenta.php", token=token)["estado"] is True

    recuperado = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf,
        "restablecer_clave_cliente": "1",
        "id_solicitud": id_recuperacion,
        "clave_temporal": "Temporal_2026_Verificada",
        "identidad_verificada": "1",
    })
    assert "Acceso restablecido" in recuperado, recuperado[:300]
    assert "Temporal_2026_Verificada" not in recuperado
    assert api("cuenta.php", token=token, status=401)["estado"] is False
    assert api("login.php", method="POST", body={
        "correo": correo_recuperacion,
        "contrasena": "NuevaClave_2026",
    })["estado"] is False
    nuevo_login = api("login.php", method="POST", body={
        "correo": correo_recuperacion,
        "contrasena": "Temporal_2026_Verificada",
    })
    assert nuevo_login["estado"] is True, nuevo_login

    print("OK: recuperación de acceso asistida, identidad confirmada y tokens revocados.")
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
    recuperacion = api("recuperacion.php", method="POST", status=202, body={
        "correo": nuevo_correo,
    })
    no_registrado = api("recuperacion.php", method="POST", status=202, body={
        "correo": f"desconocido-{uuid4().hex[:10]}@example.test",
    })
    assert recuperacion["mensaje"] == no_registrado["mensaje"]
    api("recuperacion.php", method="POST", status=202, body={"correo": nuevo_correo})

    lista = api("soporte.php", token=token)["solicitudes"]
    recuperaciones = [
        x for x in lista if x["asunto"] == "Recuperación de acceso"
    ]
    assert len(recuperaciones) == 1, recuperaciones
    id_recuperacion = int(recuperaciones[0]["id_solicitud"])
    print("OK: perfil editable, cambio de clave, correos únicos y soporte privado.")
    return id_solicitud, id_recuperacion, nuevo_correo


def crear_cliente(nombre):
    correo = f"ci-{uuid4().hex[:12]}@example.test"
    corta = api("usuarios.php",method="POST",status=200,body={
        "nombres":nombre,"apellidos":"Pruebas","correo":correo,
        "contrasena":"123456","telefono":"987654321",
    })
    assert corta["estado"] is False and "8" in corta["mensaje"], corta
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
    id_solicitud, id_recuperacion, correo_recuperacion = probar_cuenta_soporte(id_usuario, token, otro_token)

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

    # El cliente reporta un código Yape, pero la API nunca confirma el cobro.
    assert api("cliente_reportar_pago.php", method="POST", status=401,
               body={"id_pedido": id_pedido, "referencia": "YP-45678123"})["estado"] is False
    assert api("cliente_reportar_pago.php", method="POST", token=otro_token,
               status=404, body={"id_pedido": id_pedido,
                                 "referencia": "YP-45678123"})["estado"] is False
    referencia = api("cliente_reportar_pago.php", method="POST", token=token,
                     body={"id_pedido": id_pedido, "referencia": "YP-45678123"})
    assert referencia["estado"] is True, referencia
    assert referencia["estado_pago"] == "Pendiente", referencia
    con_referencia = api(f"pedidos.php?id_usuario={id_usuario}", token=token)
    reporte = next(p for p in con_referencia if int(p["id_pedido"]) == id_pedido)
    assert reporte["referencia_pago"] == "YP-45678123", reporte
    assert reporte["estado_pago"] == "Pendiente", reporte
    print("OK: referencia Yape privada, visible y pendiente de validación.")

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

    # Cancelación de un pedido pendiente iniciada desde el usuario móvil.
    stock_para_cancelar = int(api(f"productos.php?id={id_producto}")["stock"])
    pedido_cancelable = api("pedidos.php", method="POST", token=token, status=201, body={
        "id_usuario": id_usuario, "tipo_entrega": "Recojo en tienda",
        "metodo_pago": "Efectivo",
        "items": [{"id_producto": id_producto, "cantidad": 1}],
    })
    id_cancelable = int(pedido_cancelable["id_pedido"])
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_para_cancelar - 1
    assert api("cliente_cancelar_pedido.php", method="POST", token=otro_token,
               body={"id_pedido": id_cancelable}, status=404)["estado"] is False

    cancelacion_cliente = api("cliente_cancelar_pedido.php", method="POST", token=token,
                             body={"id_pedido": id_cancelable})
    assert cancelacion_cliente["estado"] is True
    assert cancelacion_cliente["estado_pedido"] == "Cancelado"
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_para_cancelar

    # Una petición repetida no puede reponer el stock dos veces.
    segunda_cancelacion = api("cliente_cancelar_pedido.php", method="POST",
                             token=token, body={"id_pedido": id_cancelable})
    assert segunda_cancelacion["estado"] is True
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_para_cancelar
    historial_cancelado = api(f"pedidos.php?id_usuario={id_usuario}", token=token)
    assert next(p for p in historial_cancelado if int(p["id_pedido"]) == id_cancelable)["estado_pedido"] == "Cancelado"
    print("OK: cancelación de pedido por cliente, stock, permisos e idempotencia.")

    # Petición duplicada por pérdida de conexión: un pedido y un movimiento de stock.
    stock_antes_reintento = int(api(f"productos.php?id={id_producto}")["stock"])
    clave = f"checkout-{uuid4().hex[:32]}"
    datos_compra = {
        "id_usuario": id_usuario, "tipo_entrega": "Recojo en tienda",
        "metodo_pago": "Efectivo",
        "clave_operacion": clave,
        "items": [{"id_producto": id_producto, "cantidad": 1}],
    }
    primera = api("pedidos.php", method="POST", token=token,
                  status=201, body=datos_compra)
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_antes_reintento - 1
    repetida = api("pedidos.php", method="POST", token=token,
                   status=200, body=datos_compra)
    assert repetida["estado"] is True and repetida.get("reutilizado") is True, repetida
    assert int(repetida["id_pedido"]) == int(primera["id_pedido"])
    assert float(repetida["total"]) == float(primera["total"])
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_antes_reintento - 1
    api("cliente_cancelar_pedido.php", method="POST", token=token, body={
        "id_pedido": int(primera["id_pedido"]),
    })
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_antes_reintento
    print("OK: reintentar checkout no duplica pedidos, pagos ni descuenta stock.")

    # Verificar las operaciones reales del dashboard sobre ese mismo pedido.
    probar_dashboard_admin(
        id_pedido, id_usuario, token, id_producto, stock_anterior,
        otro_id, otro_token, id_solicitud, id_recuperacion, correo_recuperacion,
    )

    # El cierre de sesión revoca el token y prohíbe futuras consultas.
    assert api("cliente_logout.php", method="POST", token=token)["estado"] is True
    assert api(f"pedidos.php?id_usuario={id_usuario}", token=token, status=401)["estado"] is False
    print("OK: catálogo, autenticación, aislamiento por usuario, favoritos, carrito,")
    print("    direcciones, pedido, stock, precio, delivery, historial y cierre de sesión.")


if __name__ == "__main__":
    main()
