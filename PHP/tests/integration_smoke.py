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
from pathlib import Path
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
    caja_antes = admin_api(navegador, "dashboard_api.php")
    assert float(caja_antes["por_cobrar"]) >= total_centimos/100 - 0.01
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
    assert estado["estado_pago"] == "Pendiente", estado
    assert abs(float(estado["monto_pagado"]) - (mitad / 100)) < 0.01, estado
    assert abs(float(estado["saldo_pendiente"]) - (restante / 100)) < 0.01, estado

    final = admin_api(navegador, "pagos.php", method="POST", csrf=csrf, body={
        **datos, "monto": round(restante / 100, 2),
    }, status=201)
    assert final["saldo_pendiente"] == 0, final
    assert final["estado_pedido"] == "Pagado", final
    final_flu = api(f"pedidos.php?id_usuario={cliente}", token=token)
    saldado = next(x for x in final_flu if int(x["id_pedido"]) == id_pedido)
    assert saldado["estado_pago"] == "Pagado", saldado
    assert abs(float(saldado["monto_pagado"]) - (total_centimos / 100)) < 0.01
    assert abs(float(saldado["saldo_pendiente"])) < 0.01
    caja_despues = admin_api(navegador, "dashboard_api.php")
    assert abs((float(caja_despues["cobrado"]) -
                float(caja_antes["cobrado"])) - total_centimos/100) < 0.02
    assert abs((float(caja_antes["por_cobrar"]) -
                float(caja_despues["por_cobrar"])) - total_centimos/100) < 0.02

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


def probar_productos_api(navegador, csrf, id_cliente, token_cliente):
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

    # El usuario no puede quedarse atrapado en un carrito antiguo cuando
    # administración baja el inventario. Reducir siempre debe funcionar.
    api("carrito.php",method="POST",token=token_cliente,body={
        "id_usuario":id_cliente,"id_producto":id_producto,"cantidad":5,
    })
    bajado = admin_api(navegador,"productos.php",method="PUT",csrf=csrf,
                       body={**base,"id_producto":id_producto,"precio":31.50,"stock":1})
    assert bajado["estado"] is True
    mayor = api("carrito.php",method="POST",token=token_cliente,status=409,body={
        "id_usuario":id_cliente,"id_producto":id_producto,"cantidad":6,
    })
    assert mayor["estado"] is False
    for cantidad in (4,3,2,1):
        respuesta = api("carrito.php",method="POST",token=token_cliente,body={
            "id_usuario":id_cliente,"id_producto":id_producto,"cantidad":cantidad,
        })
        assert respuesta["estado"] is True
    carrito = api(f"carrito.php?id_usuario={id_cliente}",token=token_cliente)
    item = next(x for x in carrito["items"] if int(x["id_producto"])==id_producto)
    assert int(item["cantidad"]) == 1
    api(f"carrito.php?id_usuario={id_cliente}&id_producto={id_producto}",
        method="DELETE",token=token_cliente)
    restaurar = admin_api(navegador,"productos.php",method="PUT",csrf=csrf,
                          body={**base,"id_producto":id_producto,"precio":31.50,"stock":7})
    assert restaurar["estado"] is True
    print("OK: botón reducir carrito funciona tras bajar stock y no permite aumentos.")

    # Requisito 020: el Kardex conserva el registro de altas y ajustes.
    protegido = admin_api(navegador,"productos.php",method="DELETE",csrf=csrf,
                           body={"id_producto":id_producto},status=409)
    assert "sin existencias" in protegido["mensaje"]
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == 7
    ajustado_cero = admin_api(navegador,"productos.php",method="PUT",csrf=csrf,
                             body={**base,"id_producto":id_producto,"stock":0})
    assert ajustado_cero["estado"] is True
    conservado = admin_api(navegador,"productos.php",method="DELETE",csrf=csrf,
                          body={"id_producto":id_producto},status=409)
    assert "movimientos de inventario" in conservado["mensaje"]
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == 0

    # Requisito 019: un producto con stock cero y sin historial sí se elimina.
    sin_movimientos = admin_api(navegador,"productos.php",method="POST",
        csrf=csrf,body={
            **base, "nombre_producto":f"Sin historial API {uuid4().hex[:8]}",
            "stock":0,
        },status=201)
    id_vacio = int(sin_movimientos["id_producto"])
    eliminado = admin_api(navegador,"productos.php",method="DELETE",csrf=csrf,
                          body={"id_producto":id_vacio})
    assert eliminado["estado"] is True
    assert api(f"productos.php?id={id_vacio}",status=404)["estado"] is False
    print("OK: API conserva Kardex; solo borra producto sin movimientos.")


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
    form_vendedor=admin_page(navegador_vendedor, "dashboard.php")
    csrf_vendedor=re.search(r'name="csrf_token" value="([a-f0-9]{64})"',form_vendedor)
    assert csrf_vendedor
    token_vendedor=csrf_vendedor.group(1)

    intento_bloqueo=admin_page(navegador_vendedor,"dashboard.php",form={
        "csrf_token":token_vendedor,"actualizar_estado_usuario":"1",
        "id_usuario":str(id_personal),"estado_usuario":"Bloqueado",
    })
    assert "Solo se puede cambiar el estado de cuentas de clientes" in intento_bloqueo
    intento_cambio=admin_page(navegador_vendedor,"dashboard.php",form={
        "csrf_token":token_vendedor,"actualizar_usuario":"1",
        "id_usuario":str(id_personal),"nombres":"Ataque","apellidos":"Prueba",
        "correo":correo,"telefono":"977000111",
    })
    assert "cuenta administrativa protegida" in intento_cambio
    intento_direccion=admin_page(navegador_vendedor,"dashboard.php",form={
        "csrf_token":token_vendedor,"registrar_direccion":"1",
        "id_usuario_direccion":str(id_personal),"departamento":"Ucayali",
        "provincia":"Coronel Portillo","distrito":"Calleria",
        "direccion_detalle":"Jr. No cliente","referencia":"",
    })
    assert "dirección debe pertenecer a un cliente" in intento_direccion
    id_producto_valido=int(api("productos.php")[0]["id_producto"])
    intento_pedido=admin_page(navegador_vendedor,"dashboard.php",form={
        "csrf_token":token_vendedor,"registrar_pedido_manual":"1",
        "id_usuario_pedido":str(id_personal),"id_producto_pedido[]":[id_producto_valido],
        "cantidad_pedido[]":[1],"tipo_entrega_pedido":"Recojo en tienda",
        "metodo_pago_pedido":"Efectivo",
    })
    assert "Cliente no disponible" in intento_pedido
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
    # Un dato inválido del formulario NO debe cambiar stock ni crear Kardex.
    enviar("registrar_movimiento", {
        "id_producto_stock": id_producto, "tipo_movimiento": "Entrada",
        "cantidad_movimiento": 5,
        "motivo_movimiento": "A" * 350,
    }, "El motivo del movimiento no puede superar 255 caracteres")
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
    correo_admin_movil = f"admin-{uuid4().hex[:10]}@example.test"
    creada = admin_page(navegador, "admin_login.php", form={
        "csrf_token": csrf, "crear_admin_inicial": "1",
        "nombres": "Administración", "apellidos": "Pruebas",
        "correo": correo_admin_movil,
        "contrasena": "ClaveAdmin_2026",
        "confirmar_contrasena": "ClaveAdmin_2026",
    })
    assert "YP-45678123" in creada, "No se muestra la referencia en pagos administrativos"

    # El APK debe iniciar como administrador con el MISMO usuario que PHP.
    assert api("admin_movil.php?vista=resumen", status=401)["estado"] is False
    assert api("admin_movil.php?vista=resumen", token=token,
               status=401)["estado"] is False, "Un cliente no puede ser admin"
    acceso_movil = api("admin_movil.php", method="POST", body={
        "accion": "login", "correo": correo_admin_movil,
        "contrasena": "ClaveAdmin_2026"
    })
    token_admin = acceso_movil["token"]
    assert len(token_admin) == 64
    assert acceso_movil["usuario"]["rol_sistema"] == "Administrador"
    assert api("admin_movil.php?vista=sesion", token=token_admin)["usuario"]["correo"] == correo_admin_movil
    resumen_movil = api("admin_movil.php?vista=resumen", token=token_admin)
    assert resumen_movil["estado"] is True and "productos" in resumen_movil["resumen"]
    assert isinstance(api("admin_movil.php?vista=clientes", token=token_admin)["items"], list)
    assert isinstance(api("admin_movil.php?vista=pedidos", token=token_admin)["items"], list)
    assert isinstance(api("admin_movil.php?vista=pagos", token=token_admin)["items"], list)
    assert isinstance(api("admin_movil.php?vista=inventario", token=token_admin)["items"], list)
    assert isinstance(api("admin_movil.php?vista=reportes", token=token_admin)["diario"], list)
    catalogos_movil = api("admin_movil.php?vista=catalogos", token=token_admin)
    assert catalogos_movil["categorias"] and catalogos_movil["marcas"]
    nuevo_movil = api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "producto_guardar",
        "nombre_producto": "Repuesto verificado en APK",
        "id_producto": 0,
        "id_categoria": catalogos_movil["categorias"][0]["id_categoria"],
        "id_marca": catalogos_movil["marcas"][0]["id_marca"],
        "precio": 36.5, "stock": 3, "stock_minimo": 1,
        "descripcion": "Prueba de integración PHP y Flutter",
        "tipo_vehiculo": "Motocicleta", "compatibilidad": "125cc",
        "imagen_url": "assets/imagenes/01_kit_transmision_dtiex.png",
    })
    id_movil = int(nuevo_movil["id_producto"])
    producto_movil = api(f"productos.php?id={id_movil}")
    assert producto_movil["nombre_producto"] == "Repuesto verificado en APK"
    assert int(producto_movil["stock"]) == 3
    cambio_movil = api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "producto_guardar",
        **{k: producto_movil[k] for k in (
            "nombre_producto", "id_categoria", "id_marca", "descripcion",
            "tipo_vehiculo", "compatibilidad", "precio", "stock_minimo",
            "imagen_url")},
        "id_producto": id_movil, "stock": 5, "precio_oferta": "",
    })
    assert cambio_movil["estado"] is True
    assert int(api(f"productos.php?id={id_movil}")["stock"]) == 5
    assert api("admin_movil.php", method="POST", token=token,
               body={"accion": "producto_guardar", "id_producto": id_movil},
               status=401)["estado"] is False
    # CRUD catálogo: operaciones reales, verificación de duplicados y borrado.
    assert isinstance(api("admin_movil.php?vista=categorias",
                          token=token_admin)["items"], list)
    assert isinstance(api("admin_movil.php?vista=marcas",
                          token=token_admin)["items"], list)
    tipo_nombre = "Categoria APK " + uuid4().hex[:8]
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "catalogo_guardar", "tipo": "categoria", "id": 0,
        "nombre": tipo_nombre,
    })
    lista_cat = api("admin_movil.php?vista=categorias", token=token_admin)["items"]
    id_cat = next(int(x["id_categoria"]) for x in lista_cat
                  if x["nombre_categoria"] == tipo_nombre)
    nuevo_nombre = tipo_nombre + " editada"
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "catalogo_guardar", "tipo": "categoria", "id": id_cat,
        "nombre": nuevo_nombre,
    })
    assert any(x["nombre_categoria"] == nuevo_nombre for x in
               api("admin_movil.php?vista=categorias", token=token_admin)["items"])
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "catalogo_eliminar", "tipo": "categoria", "id": id_cat,
    })
    assert all(x["id_categoria"] != id_cat for x in
               api("admin_movil.php?vista=categorias", token=token_admin)["items"])
    assert api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "catalogo_eliminar", "tipo": "categoria",
        "id": producto_movil["id_categoria"],
    }, status=409)["estado"] is False

    # Proveedor CRUD y límites de acceso.
    prov_nombre = "Proveedor APK " + uuid4().hex[:8]
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "proveedor_guardar", "id_proveedor": 0,
        "razon_social": prov_nombre, "ruc": "20601234567",
        "telefono": "987654321", "correo": "proveedor@example.com",
        "direccion": "Pucallpa", "estado": "Activo",
    })
    lista_prov = api("admin_movil.php?vista=proveedores", token=token_admin)["items"]
    id_prov = next(int(p["id_proveedor"]) for p in lista_prov
                   if p["razon_social"] == prov_nombre)
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "proveedor_guardar", "id_proveedor": id_prov,
        "razon_social": prov_nombre, "ruc": "20601234567",
        "telefono": "987654321", "correo": "proveedor@example.com",
        "direccion": "Pucallpa", "estado": "Inactivo",
    })
    assert next(p for p in api("admin_movil.php?vista=proveedores",
                 token=token_admin)["items"] if int(p["id_proveedor"]) == id_prov
               )["estado"] == "Inactivo"
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "proveedor_eliminar", "id_proveedor": id_prov,
    })

    # Movimientos de stock: transacción, Kardex, rechazo por insuficiencia.
    assert api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "inventario_movimiento", "id_producto": id_movil,
        "tipo": "Salida", "cantidad": 999999,
        "motivo": "Validar protección de stock",
    }, status=422)["estado"] is False
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "inventario_movimiento", "id_producto": id_movil,
        "tipo": "Salida", "cantidad": 2, "motivo": "Salida de ensayo",
    })
    assert int(api(f"productos.php?id={id_movil}")["stock"]) == 3
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "inventario_movimiento", "id_producto": id_movil,
        "tipo": "Entrada", "cantidad": 2, "motivo": "Reposición de ensayo",
    })
    assert int(api(f"productos.php?id={id_movil}")["stock"]) == 5
    assert any(x["motivo"] == "Desde APK: Salida de ensayo"
               for x in api("admin_movil.php?vista=inventario",
                           token=token_admin)["items"])
    assert api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "cliente_estado",
        "id_usuario": acceso_movil["usuario"]["id_usuario"],
        "estado": "Bloqueado",
    }, status=404)["estado"] is False
    for vista in ("compras", "comprobantes", "soporte"):
        assert isinstance(api(f"admin_movil.php?vista={vista}",
                              token=token_admin)["items"], list)
    assert api("admin_movil.php?vista=configuracion",
               token=token_admin)["configuracion"]["nombre_comercial"]
    print("OK APK ADMIN: CRUD catalogo, proveedor, Kardex, permisos y módulos.")

    # Compra multiproducto, anulación/reactivación y Kardex compensatorio.
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "proveedor_guardar", "id_proveedor": 0,
        "razon_social": "Proveedor de compras APK",
        "ruc": "20601234567", "estado": "Activo",
    })
    compra_prov = api("admin_movil.php?vista=proveedores", token=token_admin)
    proveedor_compra = next(p["id_proveedor"] for p in compra_prov["items"]
                            if p["razon_social"] == "Proveedor de compras APK")
    stock_repuesto = int(api(f"productos.php?id={id_movil}")["stock"])
    compra = api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "compra_registrar", "id_proveedor": proveedor_compra,
        "items": [
            {"id_producto": id_movil, "cantidad": 3, "precio_compra": 10},
            {"id_producto": id_producto, "cantidad": 2, "precio_compra": 9.50},
        ],
    })
    id_compra_movil = int(compra["id_compra"])
    assert abs(float(compra["total"]) - 49) < .01
    assert int(api(f"productos.php?id={id_movil}")["stock"]) == stock_repuesto + 3
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "compra_estado", "id_compra": id_compra_movil,
        "estado": "Anulado",
    })
    assert int(api(f"productos.php?id={id_movil}")["stock"]) == stock_repuesto
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "compra_estado", "id_compra": id_compra_movil,
        "estado": "Registrado",
    })
    assert int(api(f"productos.php?id={id_movil}")["stock"]) == stock_repuesto + 3
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "compra_estado", "id_compra": id_compra_movil,
        "estado": "Anulado",
    })
    assert int(api(f"productos.php?id={id_movil}")["stock"]) == stock_repuesto
    print("OK APK ADMIN: compra multiproducto y restauración de existencias.")

    # Pedidos cancelados desde administración móvil deben devolver stock.
    pedido_cancelar = api("pedidos.php", method="POST", token=token,
        status=201, body={"id_usuario": id_usuario, "tipo_entrega": "Recojo en tienda",
        "metodo_pago": "Efectivo",
        "items": [{"id_producto": id_movil, "cantidad": 1}]})
    id_cancelar = int(pedido_cancelar["id_pedido"])
    assert int(api(f"productos.php?id={id_movil}")["stock"]) == stock_repuesto-1
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "pedido_cancelar", "id_pedido": id_cancelar})
    assert int(api(f"productos.php?id={id_movil}")["stock"]) == stock_repuesto
    assert api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "pedido_cancelar", "id_pedido": id_cancelar
    }, status=409)["estado"] is False

    # Comprobantes solo para pedidos cobrados y sin doble emisión.
    pedido_pagado = api("pedidos.php", method="POST", token=token,
        status=201, body={"id_usuario": id_usuario, "tipo_entrega": "Recojo en tienda",
        "metodo_pago": "Efectivo",
        "items": [{"id_producto": id_movil, "cantidad": 1}]})
    id_pagado = int(pedido_pagado["id_pedido"])
    assert api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "comprobante_emitir", "id_pedido": id_pagado,
        "tipo_comprobante": "Boleta",
    }, status=409)["estado"] is False
    pagos_compra = api("admin_movil.php?vista=pagos", token=token_admin)
    id_pago_movil = next(p["id_pago"] for p in pagos_compra["items"]
                         if int(p["id_pedido"]) == id_pagado)
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "pago_confirmar", "id_pago": id_pago_movil})
    documento = api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "comprobante_emitir", "id_pedido": id_pagado,
        "tipo_comprobante": "Boleta",
    })
    assert documento["numero_comprobante"].startswith("B001-")
    assert api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "comprobante_emitir", "id_pedido": id_pagado,
        "tipo_comprobante": "Boleta",
    }, status=409)["estado"] is False
    assert api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "pedido_cancelar", "id_pedido": id_pagado
    }, status=409)["estado"] is False
    assert any(int(p["id_pedido"]) == id_pagado for p in
               api("admin_movil.php?vista=comprobantes", token=token_admin)["items"])
    print("OK APK ADMIN: cancelar pedido y emitir comprobante solo si está pagado.")

    # Clientes y direcciones: CRUD con rol, claves seguras y prevención de
    # eliminación de domicilios asociados a pedidos reales.
    correo_nuevo = f"app-admin-cliente-{uuid4().hex[:8]}@example.test"
    cliente_nuevo = api("admin_movil.php", method="POST",
        token=token_admin, body={
            "accion": "cliente_guardar", "id_usuario": 0,
            "nombres": "Cliente", "apellidos": "Desde APK",
            "correo": correo_nuevo, "telefono": "987123123",
            "contrasena": "ClaveMovil_2026",
        })
    id_nuevo_cliente = int(cliente_nuevo["id_usuario"])
    assert any(int(p["id_usuario"]) == id_nuevo_cliente for p in
               api("admin_movil.php?vista=clientes", token=token_admin)["items"])
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "cliente_guardar", "id_usuario": id_nuevo_cliente,
        "nombres": "Cliente editado", "apellidos": "Desde APK",
        "correo": correo_nuevo, "telefono": "999111222",
        "contrasena": "",
    })
    assert api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "cliente_guardar", "id_usuario": 0,
        "nombres": "Repetido", "correo": correo_nuevo,
        "contrasena": "OtraClave_2026",
    }, status=409)["estado"] is False
    assert api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "cliente_guardar", "id_usuario": acceso_movil["usuario"]["id_usuario"],
        "nombres": "Intrusión", "correo": correo_nuevo,
    }, status=404)["estado"] is False
    datos_dir = {
        "accion": "direccion_guardar", "id_usuario": id_nuevo_cliente,
        "id_direccion": 0, "departamento": "Ucayali",
        "provincia": "Coronel Portillo", "distrito": "Callería",
        "direccion_detalle": "Jr. de prueba 100", "referencia": "Al costado",
    }
    api("admin_movil.php", method="POST", token=token_admin, body=datos_dir)
    lista_dir = api(f"admin_movil.php?vista=direcciones&id_usuario={id_nuevo_cliente}",
                    token=token_admin)["items"]
    id_dir = int(lista_dir[0]["id_direccion"])
    api("admin_movil.php", method="POST", token=token_admin,
        body={**datos_dir, "id_direccion": id_dir,
              "direccion_detalle": "Jr. actualizado 101"})
    assert api(f"admin_movil.php?vista=direcciones&id_usuario={id_nuevo_cliente}",
               token=token_admin)["items"][0]["direccion_detalle"] == "Jr. actualizado 101"
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "direccion_eliminar", "id_direccion": id_dir,
        "id_usuario": id_nuevo_cliente,
    })
    assert api(f"admin_movil.php?vista=direcciones&id_usuario={id_nuevo_cliente}",
               token=token_admin)["items"] == []
    print("OK APK ADMIN: clientes y direcciones CRUD en MySQL.")

    # Personal de PHP comparte cuenta con login administrativo Android. Los
    # permisos se leen de MySQL en cada petición, incluso tras cambios de rol.
    empleado_correo = f"app-vendedor-{uuid4().hex[:8]}@example.test"
    empleado = api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "personal_guardar", "id_usuario": 0,
        "nombres": "Vendedor", "apellidos": "Movil",
        "correo": empleado_correo, "telefono": "999555222",
        "rol_sistema": "Vendedor", "estado": "Activo",
        "contrasena": "ClaveVendedor_2026",
    })
    id_empleado = int(empleado["id_usuario"])
    entrada_empleado = api("admin_movil.php", method="POST", body={
        "accion": "login", "correo": empleado_correo,
        "contrasena": "ClaveVendedor_2026",
    })
    token_empleado = entrada_empleado["token"]
    assert api("admin_movil.php?vista=productos", token=token_empleado,
               status=403)["estado"] is False
    assert api("admin_movil.php?vista=clientes", token=token_empleado)["estado"] is True
    assert api("admin_movil.php?vista=personal", token=token_empleado,
               status=403)["estado"] is False
    assert api("admin_movil.php", method="POST", token=token_empleado, body={
        "accion": "personal_guardar", "id_usuario": id_empleado,
        "rol_sistema": "Administrador",
    }, status=403)["estado"] is False
    assert api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "personal_guardar",
        "id_usuario": acceso_movil["usuario"]["id_usuario"],
        "nombres": "Administracion", "apellidos": "Pruebas",
        "correo": correo_admin_movil,
        "rol_sistema": "Vendedor", "estado": "Activo",
    }, status=409)["estado"] is False
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "personal_guardar", "id_usuario": id_empleado,
        "nombres": "Vendedor", "apellidos": "Movil",
        "correo": empleado_correo, "telefono": "999555222",
        "rol_sistema": "Almacen", "estado": "Activo",
    })
    assert api("admin_movil.php?vista=productos", token=token_empleado)["estado"] is True
    assert api("admin_movil.php?vista=clientes", token=token_empleado,
               status=403)["estado"] is False
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "personal_guardar", "id_usuario": id_empleado,
        "nombres": "Vendedor", "apellidos": "Movil",
        "correo": empleado_correo, "telefono": "999555222",
        "rol_sistema": "Almacen", "estado": "Bloqueado",
    })
    assert api("admin_movil.php?vista=productos", token=token_empleado,
               status=401)["estado"] is False
    print("OK APK ADMIN: personal, roles, bloqueo y revocación de tokens.")

    # Subida multipart de una imagen auténtica: PHP valida el contenido y
    # almacena una ruta usada por los mismos clientes Flutter.
    foto_bytes = Path("PHP/dorada_api/assets/imagenes/01_kit_transmision_dtiex.png").read_bytes()
    boundary = "----Dorada" + uuid4().hex
    data_foto = (
        ("--" + boundary + "\r\nContent-Disposition: form-data; "
          "name=\"accion\"\r\n\r\nimagen_producto\r\n").encode("ascii")
        + ("--" + boundary + "\r\nContent-Disposition: form-data; "
           "name=\"imagen\"; filename=\"foto.png\"\r\n"
           "Content-Type: image/png\r\n\r\n").encode("ascii")
        + foto_bytes + ("\r\n--" + boundary + "--\r\n").encode("ascii")
    )
    req_foto = urllib.request.Request(BASE + "/admin_movil.php", data=data_foto,
        method="POST", headers={
            "Authorization": "Bearer " + token_admin,
            "Content-Type": "multipart/form-data; boundary=" + boundary,
            "Accept": "application/json",
        })
    with urllib.request.urlopen(req_foto, timeout=25) as response:
        foto_subida = json.loads(response.read().decode("utf-8"))
    assert foto_subida["estado"] is True, foto_subida
    ruta_subida = foto_subida["imagen_url"]
    assert ruta_subida.startswith("uploads/productos/"), foto_subida
    with urllib.request.urlopen(BASE + "/" + ruta_subida, timeout=20) as response:
        assert response.status == 200
        assert response.headers.get("Content-Type", "").startswith("image/")
        assert response.read() == foto_bytes

    ficha = api(f"productos.php?id={id_movil}")
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "producto_guardar",
        "id_producto": id_movil,
        "nombre_producto": ficha["nombre_producto"],
        "descripcion": ficha["descripcion"],
        "tipo_vehiculo": ficha["tipo_vehiculo"],
        "compatibilidad": ficha["compatibilidad"],
        "precio": ficha["precio"],
        "precio_oferta": ficha["precio_oferta"],
        "stock": ficha["stock"], "stock_minimo": ficha["stock_minimo"],
        "id_categoria": ficha["id_categoria"], "id_marca": ficha["id_marca"],
        "imagen_url": ruta_subida,
    })
    assert api(f"productos.php?id={id_movil}")["imagen_url"] == ruta_subida
    print("OK APK ADMIN: imagen real subida, publicada y visible en API cliente.")

    # Caja / venta manual desde el administrador Android.
    stock_antes_venta = int(api(f"productos.php?id={id_movil}")["stock"])
    pedido_mostrador = api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "pedido_manual", "id_usuario": id_nuevo_cliente,
        "tipo_entrega": "Recojo en tienda", "metodo_pago": "Efectivo",
        "items": [{"id_producto": id_movil, "cantidad": 2}],
    })
    id_venta_manual = int(pedido_mostrador["id_pedido"])
    total_venta_manual = float(pedido_mostrador["total"])
    assert total_venta_manual > 5
    assert int(api(f"productos.php?id={id_movil}")["stock"]) == stock_antes_venta - 2
    detalle_manual = api("admin_movil.php?vista=pedido_detalle&id_pedido=" +
                         str(id_venta_manual), token=token_admin)
    assert int(detalle_manual["pedido"]["id_usuario"]) == id_nuevo_cliente
    assert len(detalle_manual["lineas"]) == 1
    assert int(detalle_manual["lineas"][0]["cantidad"]) == 2
    assert detalle_manual["pagos"][0]["estado_pago"] == "Pendiente"
    assert api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "pedido_manual", "id_usuario": id_nuevo_cliente,
        "tipo_entrega": "Recojo en tienda", "metodo_pago": "Efectivo",
        "items": [{"id_producto": id_movil, "cantidad": stock_antes_venta + 100}],
    }, status=409)["estado"] is False
    assert int(api(f"productos.php?id={id_movil}")["stock"]) == stock_antes_venta - 2
    print("OK APK ADMIN: registrar venta manual, detalle y descuento de stock.")

    # Abonos con balance financiero y prevención de sobrepago.
    abono = api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "pago_manual", "id_pedido": id_venta_manual,
        "monto": 5.00, "metodo_pago": "Yape", "estado_pago": "Pagado",
    })
    id_abono_manual = int(abono["id_pago"])
    assert api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "pago_manual", "id_pedido": id_venta_manual,
        "monto": total_venta_manual, "metodo_pago": "Plin",
        "estado_pago": "Pagado",
    }, status=409)["estado"] is False
    assert api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "pago_estado", "id_pago": id_abono_manual,
        "estado_pago": "Rechazado",
    })["estado"] is True
    api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "pago_estado", "id_pago": id_abono_manual,
        "estado_pago": "Pagado",
    })
    restante = round(total_venta_manual - 5.0, 2)
    segundo = api("admin_movil.php", method="POST", token=token_admin, body={
        "accion": "pago_manual", "id_pedido": id_venta_manual,
        "monto": restante, "metodo_pago": "Efectivo", "estado_pago": "Pagado",
    })
    assert int(segundo["id_pago"]) != id_abono_manual
    assert api("admin_movil.php?vista=pedido_detalle&id_pedido=" +
               str(id_venta_manual), token=token_admin)["pedido"]["estado_pedido"] == "Pagado"
    print("OK APK ADMIN: pagos, abonos, control de saldo y cambio de estado.")

    assert api("admin_movil.php", method="POST", token=token_admin,
               body={"accion": "logout"})["estado"] is True
    assert api("admin_movil.php?vista=resumen", token=token_admin,
               status=401)["estado"] is False
    print("OK APK ADMIN: login compartido, permisos, productos, stock, consultas y cierre de sesión.")
    probar_revocacion_de_personal(navegador, csrf)
    probar_productos_api(navegador, csrf, id_usuario, token)
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

    # Admin y Flutter deben usar la misma tarifa para un pedido con Delivery.
    direcciones_cliente = api(f"direcciones.php?id_usuario={id_usuario}", token=token)
    assert direcciones_cliente, "El cliente no tiene dirección para el pedido manual"
    direccion_manual = int(direcciones_cliente[0]["id_direccion"])
    producto_manual = api(f"productos.php?id={id_producto}")
    precio_base = float(producto_manual["precio"])
    oferta = float(producto_manual["precio_oferta"] or 0)
    precio_aplicable = oferta if 0 < oferta < precio_base else precio_base
    stock_antes_manual = int(producto_manual["stock"])
    respuesta_manual = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf, "registrar_pedido_manual": "1",
        "id_usuario_pedido": str(id_usuario),
        "id_direccion_pedido": str(direccion_manual),
        "id_producto_pedido[]": [id_producto],
        "cantidad_pedido[]": [1],
        "tipo_entrega_pedido": "Delivery",
        "metodo_pago_pedido": "Efectivo",
    })
    creado_manual = re.search(r"Pedido #(\d+) registrado", respuesta_manual)
    assert creado_manual, "El administrador no pudo registrar un pedido Delivery"
    id_manual = int(creado_manual.group(1))
    pedidos_cliente = api(f"pedidos.php?id_usuario={id_usuario}", token=token)
    pedido_manual = next(p for p in pedidos_cliente if int(p["id_pedido"]) == id_manual)
    assert abs(float(pedido_manual["total"]) -
               (precio_aplicable + float(destinos["costo_delivery"]))) < 0.01, pedido_manual
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_antes_manual - 1
    anulado_manual = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf, "actualizar_estado_pedido": "1",
        "id_pedido": str(id_manual), "estado_pedido": "Cancelado",
    })
    assert "Estado del pedido actualizado" in anulado_manual
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_antes_manual
    print("OK: Delivery manual del administrador coincide con Flutter y repone stock al anular.")

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
    assert "cobrado" in metricas and "por_cobrar" in metricas, metricas
    assert "cobros_7_dias" in metricas and len(metricas["cobros_7_dias"]) == 7
    assert abs(float(metricas["ventas"]) -
               (float(metricas["cobrado"]) + float(metricas["por_cobrar"]))) < 0.02, metricas
    assert "Cobros confirmados" in creada and "Saldo por cobrar" in creada

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
    edicion_obsoleta = admin_page(navegador, "dashboard.php", form={
        **formulario, "actualizar_producto": "1",
        "id_producto": str(id_nuevo), "stock_original": "9",
        "stock": "10",
    })
    assert "El stock cambió mientras editabas" in edicion_obsoleta
    assert int(api(f"productos.php?id={id_nuevo}")["stock"]) == 12, (
        "Un formulario viejo sobreescribió el inventario actualizado"
    )
    kardex_editado = actualizado.split('id="tablaKardex"',1)[1].split("</table>",1)[0]
    assert re.search(rf"{re.escape(nombre)}.*?Ajuste desde edición de producto", kardex_editado, re.S), (
        "Editar stock no registró movimiento de Kardex"
    )

    bloqueado = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf, "eliminar_producto": "1",
        "id_producto": str(id_nuevo),
    })
    assert "sin existencias" in bloqueado
    assert int(api(f"productos.php?id={id_nuevo}")["stock"]) == 12
    stock_a_cero = admin_page(navegador, "dashboard.php", form={
        **formulario, "actualizar_producto": "1", "id_producto": str(id_nuevo),
        "stock_original": "12", "stock": "0",
    })
    assert "Producto actualizado correctamente" in stock_a_cero
    bloqueado_kardex = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf, "eliminar_producto": "1",
        "id_producto": str(id_nuevo),
    })
    assert "movimientos de inventario" in bloqueado_kardex
    assert int(api(f"productos.php?id={id_nuevo}")["stock"]) == 0

    nuevo_sin_movimientos = f"Producto eliminable {uuid4().hex[:8]}"
    creado = admin_page(navegador, "dashboard.php", form={
        **formulario, "nombre_producto": nuevo_sin_movimientos,
        "stock": "0", "registrar_producto": "1",
    })
    assert "Producto registrado correctamente" in creado
    id_vacio = next(int(p["id_producto"]) for p in api("productos.php")
                    if p["nombre_producto"] == nuevo_sin_movimientos)
    borrado = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf, "eliminar_producto": "1",
        "id_producto": str(id_vacio),
    })
    assert "Producto eliminado correctamente" in borrado
    assert api(f"productos.php?id={id_vacio}", status=404)["estado"] is False
    print("OK: requisitos 019 y 020; eliminar sin historial y conservar Kardex.")

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

    # Venta contra entrega: confirmar el abono no retrocede una entrega Enviada.
    pedido_contraentrega = api("pedidos.php", method="POST", token=otro_token,
                              status=201, body={
        "id_usuario": otro_id,"tipo_entrega":"Recojo en tienda",
        "metodo_pago":"Efectivo",
        "items":[{"id_producto":id_producto,"cantidad":1}],
    })
    id_contraentrega = int(pedido_contraentrega["id_pedido"])
    for estado in ["Procesando","Enviado"]:
        respuesta = admin_page(navegador,"dashboard.php",form={
            "csrf_token":csrf,"actualizar_estado_pedido":"1",
            "id_pedido":id_contraentrega,"estado_pedido":estado,
        })
        assert "Estado del pedido actualizado" in respuesta, respuesta[:250]
    cobrado = admin_page(navegador,"dashboard.php",form={
        "csrf_token":csrf,"registrar_pago_manual":"1",
        "id_pedido_pago":id_contraentrega,"metodo_pago_manual":"Efectivo",
        "monto_pago":str(pedido_contraentrega["total"]),
        "estado_pago_manual":"Pagado",
    })
    assert "Pago registrado correctamente" in cobrado, cobrado[:250]
    historial_envio = api(f"pedidos.php?id_usuario={otro_id}",token=otro_token)
    enviado = next(p for p in historial_envio if int(p["id_pedido"])==id_contraentrega)
    assert enviado["estado_pedido"] == "Enviado", enviado
    completado = admin_page(navegador,"dashboard.php",form={
        "csrf_token":csrf,"actualizar_estado_pedido":"1",
        "id_pedido":id_contraentrega,"estado_pedido":"Completado",
    })
    assert "Estado del pedido actualizado" in completado, completado[:250]
    assert next(p for p in api(f"pedidos.php?id_usuario={otro_id}",token=otro_token)
                if int(p["id_pedido"])==id_contraentrega)["estado_pedido"]=="Completado"
    print("OK: envío, pago contraentrega y finalización sin regresión de estado.")

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
    repetido = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf, "registrar_comprobante": "1",
        "id_pedido_comprobante": str(id_otro_pedido),
        "tipo_comprobante": "Boleta", "numero_comprobante": "",
    })
    assert "Ya existe un comprobante para este pedido" in repetido, (
        "La emisión duplicada debería rechazarse"
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

    # Comprobar también Factura, numeración F001, impresión y eliminación
    # (estos requisitos no estaban cubiertos por la prueba anterior).
    factura = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf, "registrar_comprobante": "1",
        "id_pedido_comprobante": str(id_contraentrega),
        "tipo_comprobante": "Factura", "numero_comprobante": "",
    })
    assert "Comprobante F001-" in factura, factura[:400]
    factura_cliente = api(
        f"cliente_comprobante.php?id_pedido={id_contraentrega}",
        token=otro_token,
    )
    assert factura_cliente["comprobante"]["tipo_comprobante"] == "Factura"
    id_factura = int(factura_cliente["comprobante"]["id_comprobante"])
    impresion_factura = admin_page(
        navegador, f"comprobante_print.php?id={id_factura}"
    )
    assert "FACTURA" in impresion_factura and "S/ " in impresion_factura
    borrado_factura = admin_page(navegador, "dashboard.php", form={
        "csrf_token": csrf, "eliminar_comprobante": "1",
        "id_comprobante": str(id_factura),
    })
    assert "Comprobante eliminado" in borrado_factura
    assert api(
        f"cliente_comprobante.php?id_pedido={id_contraentrega}",
        token=otro_token, status=404,
    )["estado"] is False
    print("OK: factura de demostración, numeración, impresión y eliminación")

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
    repetido = api("usuarios.php", method="POST", status=200, body={
        "nombres": nombre, "apellidos": "Pruebas",
        "correo": correo, "contrasena": "DemoSeguro_2026",
        "telefono": "987654321",
    })
    assert repetido["estado"] is False and "registrado" in repetido["mensaje"]
    return identificador, token


def main():
    # La prueba del APK debe verificar que se conecta a NUESTRA API PHP,
    # no únicamente a una web o al ejemplo de Registro de Personas.
    for intento in range(25):
        try:
            productos = api("productos.php")
            break
        except (urllib.error.URLError, ConnectionError):
            if intento == 24:
                raise
            time.sleep(1)
    estado_api = api("conexion_estado.php")
    assert estado_api["estado"] is True
    assert estado_api["api"] == "dorada_motors"
    assert int(estado_api["tablas_verificadas"]) >= 10
    assert api("conexion_estado.php", method="POST", status=405)["estado"] is False
    print("OK: APK apunta a la API Dorada Motors y tablas reales de MySQL.")
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

    # PRUEBA DE PERSISTENCIA REAL: acceder de nuevo con otro token,
    # sin reutilizar datos locales de Flutter ni la sesión original.
    acceso_nuevo = api("login.php", method="POST", body={
        "correo": correo_recuperacion, "contrasena": "NuevaClave_2026",
    })
    assert acceso_nuevo["estado"] is True, acceso_nuevo
    token_nuevo = acceso_nuevo["token"]
    assert token_nuevo != token
    perfil_bd = api("cuenta.php", token=token_nuevo)["usuario"]
    assert int(perfil_bd["id_usuario"]) == id_usuario
    assert perfil_bd["nombres"] == "Cliente Actualizado"
    assert perfil_bd["telefono"] == "988776655"
    direcciones_bd = api(f"direcciones.php?id_usuario={id_usuario}", token=token_nuevo)
    assert any(int(d["id_direccion"]) == id_direccion and
               d["direccion_detalle"] == "Jr. Pruebas 101" for d in direcciones_bd)
    compras_bd = api(f"pedidos.php?id_usuario={id_usuario}", token=token_nuevo)
    compra_bd = next(p for p in compras_bd if int(p["id_pedido"]) == id_pedido)
    assert compra_bd["referencia_pago"] == "YP-45678123"
    assert compra_bd["items"] and int(compra_bd["items"][0]["cantidad"]) == 2
    solicitudes_bd = api("soporte.php", token=token_nuevo)["solicitudes"]
    assert any(int(s["id_solicitud"]) == id_solicitud for s in solicitudes_bd)
    api("favoritos.php", method="POST", token=token, body={
        "id_usuario": id_usuario, "id_producto": id_producto, "accion": "agregar",
    })
    favoritos_bd = api(f"favoritos.php?id_usuario={id_usuario}", token=token_nuevo)
    assert any(int(f["id_producto"]) == id_producto for f in favoritos_bd)
    api("favoritos.php", method="POST", token=token_nuevo, body={
        "id_usuario": id_usuario, "id_producto": id_producto, "accion": "quitar",
    })
    print("OK: datos del celular persistidos en MySQL; "
          "otra sesión recupera perfil, dirección, compra, pago, favorito y soporte.")

    # Si una respuesta se pierde sin internet, reintentar la misma operación
    # no debe duplicar datos del cliente en MySQL.
    clave_dir = uuid4().hex
    registro_dir = {
        "id_usuario": id_usuario, "departamento": "Ucayali",
        "provincia": "Coronel Portillo", "distrito": "Callería",
        "direccion_detalle": "Jr. Sincronización Offline 123",
        "referencia": "Prueba de reconexión",
        "clave_operacion": clave_dir,
    }
    creada_dir = api("direcciones.php", method="POST", token=token_nuevo,
                     body=registro_dir, status=201)
    repetida_dir = api("direcciones.php", method="POST", token=token_nuevo,
                       body=registro_dir, status=201)
    assert creada_dir["id_direccion"] == repetida_dir["id_direccion"]
    lista_dir = api(f"direcciones.php?id_usuario={id_usuario}", token=token_nuevo)
    assert sum(int(d["id_direccion"]) == creada_dir["id_direccion"]
               for d in lista_dir) == 1

    clave_soporte = uuid4().hex
    mensaje_soporte = {
        "asunto": "Consulta offline desde celular",
        "mensaje": "Guardada en SQLite y enviada después de recuperar la conexión.",
        "clave_operacion": clave_soporte,
    }
    creada_sol = api("soporte.php", method="POST", token=token_nuevo,
                     body=mensaje_soporte, status=201)
    repetida_sol = api("soporte.php", method="POST", token=token_nuevo,
                       body=mensaje_soporte, status=201)
    assert creada_sol["id_solicitud"] == repetida_sol["id_solicitud"]
    consultas = api("soporte.php", token=token_nuevo)["solicitudes"]
    assert sum(int(x["id_solicitud"]) == creada_sol["id_solicitud"]
               for x in consultas) == 1
    print("OK: reintentos offline no duplican direcciones ni consultas de soporte.")


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
    assert api(f"direcciones.php?id={id_direccion}",
               method="DELETE", token=otro_token, status=404)["estado"] is False
    assert api("direcciones.php", method="PUT", token=otro_token, status=403, body={
        "id_usuario": id_usuario,
        "id_direccion": id_direccion,
        "direccion_detalle": "Manipulación externa",
    })["estado"] is False
    assert api("direcciones.php", method="PUT", token=otro_token, status=404, body={
        "id_usuario": otro_id,
        "id_direccion": id_direccion,
        "direccion_detalle": "Manipulación externa",
    })["estado"] is False

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
    producto_actual = api(f"productos.php?id={id_producto}")
    precio_base = float(producto_actual["precio"])
    oferta = float(producto_actual["precio_oferta"] or 0)
    precio_real = oferta if 0 < oferta < precio_base else precio_base
    datos_compra = {
        "id_usuario": id_usuario, "tipo_entrega": "Recojo en tienda",
        "metodo_pago": "Efectivo",
        "clave_operacion": clave,
        "total_esperado": round(precio_real, 2),
        "items": [{"id_producto": id_producto, "cantidad": 1}],
    }
    # Entre mostrar y confirmar, el administrador puede variar precios.
    # Un total desactualizado NO crea pedidos ni descuenta stock.
    antes_precio = len(api(f"pedidos.php?id_usuario={id_usuario}", token=token))
    discrepancia = api("pedidos.php", method="POST", token=token,
                      status=409,
                      body={**datos_compra, "total_esperado":0.01})
    assert discrepancia["estado"] is False
    assert "total de la compra cambió" in discrepancia["mensaje"]
    assert int(api(f"productos.php?id={id_producto}")["stock"]) == stock_antes_reintento
    assert len(api(f"pedidos.php?id_usuario={id_usuario}", token=token)) == antes_precio
    print("OK: precio cambiado entre pantalla y MySQL no crea compra ni altera stock.")

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
