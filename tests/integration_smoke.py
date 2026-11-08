#!/usr/bin/env python3
"""Prueba integral real de la API PHP contra MySQL temporal de GitHub Actions."""
import json
import os
import time
import urllib.error
import urllib.request
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

    # Los datos de compra y otros clientes no son públicos.
    assert api("pedidos.php?id_usuario=1", status=401)["estado"] is False
    assert api("carrito.php?id_usuario=1", status=401)["estado"] is False
    assert api("dashboard_api.php", status=401)["estado"] is False
    assert api("productos.php", method="POST", body={}, status=403)["estado"] is False

    id_usuario, token = crear_cliente("Cliente Uno")
    otro_id, otro_token = crear_cliente("Cliente Dos")

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

    # El cierre de sesión revoca el token y prohíbe futuras consultas.
    assert api("cliente_logout.php", method="POST", token=token)["estado"] is True
    assert api(f"pedidos.php?id_usuario={id_usuario}", token=token, status=401)["estado"] is False
    print("OK: catálogo, autenticación, aislamiento por usuario, favoritos, carrito,")
    print("    direcciones, pedido, stock, precio, delivery, historial y cierre de sesión.")


if __name__ == "__main__":
    main()
