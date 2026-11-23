// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../data/productos_data.dart';
import 'offline_database.dart';

/// Dashboard 100% independiente de Internet y de XAMPP.
/// La base SQLite del Samsung NO es la base MySQL de la laptop.
/// Son espacios de datos diferentes: nunca marcar operaciones SQLite como
/// confirmadas en PHP/MySQL y no mezclar IDs de ambas instalaciones.
class AdminOfflineRepository {
  static const scope = 'admin-independiente-v1';
  static Future<void> _ultima = Future<void>.value();
  static const _authNombre = 'credenciales';
  static const _estadoNombre = 'dashboard';

  static void _soloDispositivo() {
    if (kIsWeb) {
      throw StateError('El dashboard local SQLite requiere Android.');
    }
  }

  static String _hash(String password, String salt) {
    List<int> bytes = utf8.encode('$salt:$password');
    for (var i = 0; i < 16000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Encode(bytes);
  }

  static Future<bool> estaConfigurado() async {
    _soloDispositivo();
    return await OfflineDatabase.leer(scope, _authNombre) is Map;
  }

  /// Sin credenciales por defecto: solo quien configura el teléfono puede
  /// acceder a los datos comerciales del dispositivo.
  static Future<void> crearAcceso(String contrasena) async {
    _soloDispositivo();
    if (contrasena.length < 8) {
      throw StateError('Usa una contraseña de al menos 8 caracteres.');
    }
    if (await estaConfigurado()) {
      throw StateError('Ya existe una cuenta local. No se puede reemplazar sin ella.');
    }
    final random = Random.secure();
    final salt = base64Encode(
        List<int>.generate(24, (_) => random.nextInt(256)));
    await OfflineDatabase.guardar(scope, _authNombre, {
      'salt': salt,
      'hash': _hash(contrasena, salt),
    });
    await estado();
  }

  static Future<bool> comprobarAcceso(String contrasena) async {
    _soloDispositivo();
    final guardado = await OfflineDatabase.leer(scope, _authNombre);
    if (guardado is! Map) return false;
    final salt = guardado['salt']?.toString() ?? '';
    final hashGuardado = guardado['hash']?.toString() ?? '';
    if (salt.isEmpty || hashGuardado.isEmpty) return false;
    final actual = _hash(contrasena, salt);
    // Comparación de todos los caracteres de la huella.
    final a = utf8.encode(actual), b = utf8.encode(hashGuardado);
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) { diff |= a[i] ^ b[i]; }
    return diff == 0;
  }

  static List<Map<String, dynamic>> _filas(
      Map<String, dynamic> estado, String tabla) {
    final datos = estado[tabla];
    if (datos is! List) return [];
    return datos.whereType<Map>()
        .map((v) => Map<String, dynamic>.from(v)).toList();
  }

  static int _entero(dynamic valor) =>
      int.tryParse(valor?.toString() ?? '') ?? -1;

  static double _decimal(dynamic valor) =>
      double.tryParse(valor?.toString() ?? '') ?? double.nan;

  static int _id(Map<String, dynamic> estado) {
    final nuevo = _entero(estado['siguiente_id']);
    estado['siguiente_id'] = nuevo + 1;
    return nuevo;
  }

  static Map<String, dynamic> _inicial() {
    final categorias = <Map<String, dynamic>>[];
    final marcas = <Map<String, dynamic>>[];
    final mapaCategorias = <String, int>{};
    final mapaMarcas = <String, int>{};
    var siguiente = 1000;
    final productos = <Map<String, dynamic>>[];
    for (final p in productosData) {
      final cat = mapaCategorias.putIfAbsent(p.categoria, () {
        final id = siguiente++;
        categorias.add({'id_categoria': id, 'nombre_categoria': p.categoria});
        return id;
      });
      final marca = mapaMarcas.putIfAbsent(p.marca, () {
        final id = siguiente++;
        marcas.add({'id_marca': id, 'nombre_marca': p.marca});
        return id;
      });
      productos.add({
        'id_producto': p.id,
        'id_categoria': cat,
        'id_marca': marca,
        'nombre_producto': p.nombre,
        'descripcion': p.descripcion,
        'tipo_vehiculo': p.tipoVehiculo,
        'compatibilidad': p.compatibilidad,
        'precio': p.precio,
        'precio_oferta': p.precioOferta,
        'stock': p.stock,
        'stock_minimo': 5,
        'imagen_url': p.imagen,
      });
    }
    return {
      'version': 1,
      'ejemplo': true,
      'siguiente_id': siguiente,
      'categorias': categorias, 'marcas': marcas,
      'productos': productos,
      'clientes': <Map<String, dynamic>>[],
      'direcciones': <Map<String, dynamic>>[],
      'proveedores': <Map<String, dynamic>>[],
      'pedidos': <Map<String, dynamic>>[],
      'detalle_pedido': <Map<String, dynamic>>[],
      'pagos': <Map<String, dynamic>>[],
      'inventario': <Map<String, dynamic>>[],
      'compras': <Map<String, dynamic>>[],
      'detalle_compra': <Map<String, dynamic>>[],
      'comprobantes': <Map<String, dynamic>>[],
      'configuracion': {
        'nombre_comercial': 'Dorada Motors',
        'razon_social': 'ADN Imports',
        'igv': 18, 'costo_delivery': 0,
        'telefono': '', 'direccion': '', 'ruc': '',
      },
    };
  }

  // Registro de clientes en el mismo SQLite del administrador local.
  // Las huellas de contraseña no se incluyen en las vistas comerciales.
  static Future<int> registrarComprador({
    required String nombres,
    required String apellidos,
    required String correo,
    required String telefono,
    required String contrasena,
  }) => _mutar((base) async {
    final email = correo.trim().toLowerCase();
    if (nombres.trim().isEmpty || !email.contains('@') ||
        contrasena.length < 8 || contrasena.length > 128) {
      throw StateError('Nombres, correo o contraseña local inválidos');
    }
    final usuarios = _filas(base, 'clientes');
    if (usuarios.any((p) => p['correo'] == email)) {
      throw StateError('Ya existe ese correo en la tienda local');
    }
    final random = Random.secure();
    final salt = base64Encode(List<int>.generate(24,
        (_) => random.nextInt(256)));
    final id = _id(base);
    usuarios.add({
      'id_usuario': id, 'nombres': nombres.trim(),
      'apellidos': apellidos.trim(),
      'correo': email, 'telefono': telefono.trim(), 'estado': 'Activo',
    });
    base['clientes'] = usuarios;
    final llaves = _filas(base, 'accesos_clientes');
    llaves.add({'id_usuario': id,
      'salt': salt, 'hash': _hash(contrasena, salt)});
    base['accesos_clientes'] = llaves;
    return id;
  });

  static Future<int?> autenticarComprador(String correo,
      String contrasena) async {
    final base = await estado();
    final email = correo.trim().toLowerCase();
    final usuarios = _filas(base, 'clientes');
    final filtro = usuarios.where((p) =>
        p['correo'] == email && p['estado'] == 'Activo');
    if (filtro.isEmpty) return null;
    final id = _entero(filtro.first['id_usuario']);
    final llaves = _filas(base,'accesos_clientes').where((p) =>
        _entero(p['id_usuario']) == id);
    if (llaves.isEmpty) return null;
    final salt = llaves.first['salt']?.toString() ?? '';
    final huella = llaves.first['hash']?.toString() ?? '';
    if (salt.isEmpty || huella.isEmpty) return null;
    final actual = _hash(contrasena, salt);
    final a = utf8.encode(actual);
    final b = utf8.encode(huella);
    if (a.length != b.length) return null;
    var diferencia = 0;
    for (var i=0; i<a.length; i++) {
      diferencia |= a[i] ^ b[i];
    }
    return diferencia == 0 ? id : null;
  }

  static Future<Map<String, dynamic>> estado() async {
    _soloDispositivo();
    final contenido = await OfflineDatabase.leer(scope, _estadoNombre);
    if (contenido is Map && contenido['version'] == 1) {
      return Map<String, dynamic>.from(contenido);
    }
    // No sobrescribir ventas, clientes ni productos si el formato es distinto.
    if (contenido != null) {
      throw StateError('La base SQLite contiene datos incompatibles. '
          'No se reemplazaron tus datos por el catálogo de ejemplo.');
    }
    final inicial = _inicial();
    await OfflineDatabase.guardar(scope, _estadoNombre, inicial);
    return inicial;
  }

  static Future<T> _mutar<T>(
      Future<T> Function(Map<String, dynamic>) funcion) async {
    _soloDispositivo();
    final previo = _ultima;
    final actual = Completer<void>();
    _ultima = actual.future;
    await previo;
    try {
      final base = await estado();
      final resultado = await funcion(base);
      await OfflineDatabase.guardar(scope, _estadoNombre, base);
      return resultado;
    } finally {
      actual.complete();
    }
  }

  static Map<String, dynamic> _productoEnriquecido(
      Map<String, dynamic> producto,
      List<Map<String, dynamic>> categorias,
      List<Map<String, dynamic>> marcas) {
    final cat = categorias.where((r) =>
        r['id_categoria'].toString() ==
          producto['id_categoria'].toString());
    final marca = marcas.where((r) =>
        r['id_marca'].toString() == producto['id_marca'].toString());
    return {
      ...producto,
      'nombre_categoria': cat.isEmpty ? 'Sin categoría'
          : cat.first['nombre_categoria'],
      'nombre_marca': marca.isEmpty ? 'Sin marca'
          : marca.first['nombre_marca'],
    };
  }

  static Future<Map<String, dynamic>> consultar(String vista,
      {int? id}) async {
    final base = await estado();
    final productos = _filas(base, 'productos')
        .where((p) => p['archivado'] != true).toList();
    final categorias = _filas(base, 'categorias');
    final marcas = _filas(base, 'marcas');
    final pedidos = _filas(base, 'pedidos');
    final clientes = _filas(base, 'clientes');
    final pagos = _filas(base, 'pagos');
    if (vista == 'catalogos') return {
      'estado': true, 'categorias': categorias, 'marcas': marcas,
    };
    if (vista == 'configuracion') return {
      'estado': true, 'configuracion': base['configuracion'],
    };
    if (vista == 'resumen') {
      final ventas = pedidos.where((p) => p['estado_pedido'] != 'Cancelado')
          .fold<double>(0, (a, p) => a + _decimal(p['total']));
      final cobrado = pagos.where((p) => p['estado_pago'] == 'Pagado')
          .fold<double>(0, (a, p) => a + _decimal(p['monto']));
      return {'estado': true, 'resumen': {
        'productos': productos.length,
        'clientes': clientes.length,
        'pedidos': pedidos.length,
        'pendientes': pedidos.where((p) =>
            p['estado_pedido'] == 'Pendiente').length,
        'stock_bajo': productos.where((p) =>
            _entero(p['stock']) <= _entero(p['stock_minimo'])).length,
        'ventas': double.parse(ventas.toStringAsFixed(2)),
        'cobrado': double.parse(cobrado.toStringAsFixed(2)),
      }, 'ultimos_pedidos': pedidos.reversed.take(8).toList()};
    }
    if (vista == 'productos') return {
      'estado': true,
      'items': productos.map((p) =>
          _productoEnriquecido(p, categorias, marcas)).toList(),
    };
    if (vista == 'mis_pedidos') return {
      'estado': true,
      'items': pedidos.where((p) => _entero(p['id_usuario']) == id)
          .toList().reversed.toList(),
    };
    if (vista == 'direcciones') return {'estado': true, 'items':
      _filas(base, 'direcciones').where((p) => id == null ||
          _entero(p['id_usuario']) == id).toList()};
    if (vista == 'pedido_detalle') {
      final pedido = pedidos.where((p) => _entero(p['id_pedido']) == id);
      if (pedido.isEmpty) throw StateError('Pedido no encontrado');
      return {'estado': true, 'pedido': pedido.first,
        'lineas': _filas(base, 'detalle_pedido')
            .where((p) => _entero(p['id_pedido']) == id).toList(),
        'pagos': pagos.where((p) => _entero(p['id_pedido']) == id).toList(),
      };
    }
    if (vista == 'reportes') {
      final diario = <String, Map<String, dynamic>>{};
      for (final p in pedidos) {
        if (p['estado_pedido'] == 'Cancelado') continue;
        final fecha = p['fecha_pedido'].toString().substring(0, 10);
        diario.putIfAbsent(fecha, () =>
          {'fecha': fecha, 'pedidos': 0, 'ventas': 0.0});
        diario[fecha]!['pedidos'] = (diario[fecha]!['pedidos'] as int) + 1;
        diario[fecha]!['ventas'] = (diario[fecha]!['ventas'] as double)
            + _decimal(p['total']);
      }
      final acumulados = <int, Map<String, dynamic>>{};
      final idsValidos = pedidos.where(
        (p) => p['estado_pedido'] != 'Cancelado')
        .map((p) => _entero(p['id_pedido'])).toSet();
      for (final linea in _filas(base, 'detalle_pedido')) {
        if (!idsValidos.contains(_entero(linea['id_pedido']))) continue;
        final idProd = _entero(linea['id_producto']);
        final registro = acumulados.putIfAbsent(idProd, () => {
          'nombre_producto': linea['nombre_producto'] ?? 'Producto',
          'cantidad': 0, 'importe': 0.0,
        });
        registro['cantidad'] = (registro['cantidad'] as int)
            + _entero(linea['cantidad']);
        registro['importe'] = (registro['importe'] as double)
            + _decimal(linea['subtotal']);
      }
      final top = acumulados.values.toList()
        ..sort((a,b) => (b['cantidad'] as int)
            .compareTo(a['cantidad'] as int));
      return {'estado': true, 'diario': diario.values.toList(),
        'top': top.take(10).toList()};
    }
    final tabla = switch (vista) {
      'categorias' => 'categorias', 'marcas' => 'marcas',
      'clientes' => 'clientes', 'proveedores' => 'proveedores',
      'pedidos' => 'pedidos', 'pagos' => 'pagos',
      'inventario' => 'inventario', 'compras' => 'compras',
      'comprobantes' => 'comprobantes',
      _ => '',
    };
    if (tabla.isEmpty) throw StateError('Módulo local no disponible');
    var registros = _filas(base, tabla).reversed.toList();
    if (vista == 'pagos') {
      registros = registros.map((p) {
        final pedido = pedidos.where((v) =>
          _entero(v['id_pedido']) == _entero(p['id_pedido']));
        return {...p,
          'nombres': pedido.isEmpty ? '' : pedido.first['nombres'],
          'apellidos': pedido.isEmpty ? '' : pedido.first['apellidos'],
        };
      }).toList();
    } else if (vista == 'inventario') {
      registros = registros.map((p) {
        final producto = productos.where((v) =>
          _entero(v['id_producto']) == _entero(p['id_producto']));
        return {...p,
          'nombre_producto': producto.isEmpty
              ? 'Producto' : producto.first['nombre_producto'],
        };
      }).toList();
    } else if (vista == 'compras') {
      final proveedores = _filas(base, 'proveedores');
      registros = registros.map((p) {
        final prov = proveedores.where((v) =>
          _entero(v['id_proveedor']) == _entero(p['id_proveedor']));
        return {...p, 'razon_social': prov.isEmpty
            ? 'Proveedor' : prov.first['razon_social']};
      }).toList();
    } else if (vista == 'comprobantes') {
      registros = registros.map((p) {
        final pedido = pedidos.where((v) =>
            _entero(v['id_pedido']) == _entero(p['id_pedido']));
        return {...p,
          'nombres': pedido.isEmpty ? '' : pedido.first['nombres'],
          'apellidos': pedido.isEmpty ? '' : pedido.first['apellidos'],
        };
      }).toList();
    }
    return {'estado': true, 'items': registros};
  }

  static void _movimiento(Map<String, dynamic> base,
      int id, int previo, int nuevo, String motivo) {
    if (previo == nuevo) return;
    final actual = _filas(base, 'inventario');
    actual.add({
      'id_movimiento': _id(base), 'id_producto': id,
      'tipo_movimiento': nuevo > previo ? 'Entrada' : 'Salida',
      'cantidad': (nuevo - previo).abs(),
      'motivo': motivo, 'stock_anterior': previo, 'stock_nuevo': nuevo,
      'fecha_movimiento': DateTime.now().toIso8601String(),
    });
    base['inventario'] = actual;
  }

  static void _sincronizarPago(Map<String, dynamic> base, int pedidoId) {
    final pedidos = _filas(base, 'pedidos');
    final index = pedidos.indexWhere((p) => _entero(p['id_pedido']) == pedidoId);
    if (index < 0) throw StateError('Pedido no encontrado');
    final pedido = pedidos[index];
    if (['Cancelado','Completado','Enviado']
        .contains(pedido['estado_pedido'])) return;
    final pagado = _filas(base, 'pagos').where((p) =>
        _entero(p['id_pedido']) == pedidoId &&
        p['estado_pago'] == 'Pagado').fold<double>(
        0, (a, p) => a + _decimal(p['monto']));
    final total = _decimal(pedido['total']);
    // No retroceder un pedido que ya está en preparación por un abono
    // nuevo o el cambio de estado de otro pago. El avance y los cobros
    // son procesos distintos.
    if (pedido['estado_pedido'] == 'Pendiente' && pagado + 0.009 >= total) {
      pedido['estado_pedido'] = 'Pagado';
    } else if (pedido['estado_pedido'] == 'Pagado' &&
        pagado + 0.009 < total) {
      pedido['estado_pedido'] = 'Pendiente';
    }
    pedidos[index] = pedido;
    base['pedidos'] = pedidos;
  }

  static Future<Map<String, dynamic>> operar(
      Map<String, dynamic> datos) => _mutar((base) async {
    final accion = datos['accion']?.toString() ?? '';
    final ahora = DateTime.now().toIso8601String();
    final mensaje = <String, dynamic>{
      'estado': true, 'mensaje': 'Guardado en SQLite del celular (no en MySQL)',
    };
    if (accion == 'catalogo_guardar') {
      final tipo = datos['tipo']?.toString() ?? '';
      final cat = tipo == 'categoria';
      final tabla = cat ? 'categorias' : 'marcas';
      final nombreCol = cat ? 'nombre_categoria' : 'nombre_marca';
      final idCol = cat ? 'id_categoria' : 'id_marca';
      final nuevoNombre = (datos[nombreCol] ?? datos['nombre'] ?? '')
          .toString().trim();
      if (nuevoNombre.isEmpty || nuevoNombre.length > 120) {
        throw StateError('Nombre inválido');
      }
      final id = _entero(datos[idCol] ?? datos['id'] ?? 0);
      final filas = _filas(base, tabla);
      if (filas.any((r) => r[nombreCol].toString().toLowerCase() ==
          nuevoNombre.toLowerCase() && _entero(r[idCol]) != id)) {
        throw StateError('Ese nombre ya existe');
      }
      if (id > 0) {
        final i = filas.indexWhere((r) => _entero(r[idCol]) == id);
        if (i < 0) throw StateError('Registro no encontrado');
        filas[i][nombreCol] = nuevoNombre;
      } else {
        filas.add({idCol: _id(base), nombreCol: nuevoNombre});
      }
      base[tabla] = filas;
      return mensaje;
    }
    if (accion == 'catalogo_eliminar') {
      final cat = datos['tipo'] == 'categoria';
      final tabla = cat ? 'categorias' : 'marcas';
      final idCol = cat ? 'id_categoria' : 'id_marca';
      final id = _entero(datos[idCol] ?? datos['id']);
      if (_filas(base,'productos').any((p) => _entero(p[idCol]) == id)) {
        throw StateError('Está asociado a productos');
      }
      final filas = _filas(base, tabla);
      filas.removeWhere((p) => _entero(p[idCol]) == id);
      base[tabla] = filas;
      return mensaje;
    }
    if (accion == 'producto_guardar') {
      final productos = _filas(base, 'productos');
      final id = _entero(datos['id_producto'] ?? 0);
      final nombre = (datos['nombre_producto'] ?? '').toString().trim();
      final precio = _decimal(datos['precio']);
      final ofertaRaw = datos['precio_oferta']?.toString().trim() ?? '';
      final oferta = ofertaRaw.isEmpty ? null : _decimal(ofertaRaw);
      final stock = _entero(datos['stock']);
      final stockMinimo = _entero(datos['stock_minimo']);
      final cat = _entero(datos['id_categoria']);
      final marca = _entero(datos['id_marca']);
      if (nombre.isEmpty || precio.isNaN || precio <= 0 || precio > 10000000 ||
          stock < 0 || stockMinimo < 0 ||
          (oferta != null && (oferta.isNaN || oferta <= 0 || oferta >= precio)) ||
          !_filas(base,'categorias').any((p) => _entero(p['id_categoria'])==cat) ||
          !_filas(base,'marcas').any((p) => _entero(p['id_marca'])==marca)) {
        throw StateError('Producto inválido: revisa precio, stock y categoría');
      }
      final i = productos.indexWhere((p) => _entero(p['id_producto'])==id);
      if (id > 0 && i < 0) throw StateError('Producto no encontrado');
      final idReal = i >= 0 ? id : _id(base);
      final previo = i >= 0 ? _entero(productos[i]['stock']) : 0;
      final producto = <String, dynamic>{
        'id_producto': idReal, 'id_categoria': cat, 'id_marca': marca,
        'nombre_producto': nombre,
        'descripcion': datos['descripcion'] ?? '',
        'tipo_vehiculo': datos['tipo_vehiculo'] ?? 'Motocicleta / Motokar',
        'compatibilidad': datos['compatibilidad'] ?? '',
        'precio': precio, 'precio_oferta': oferta,
        'stock': stock, 'stock_minimo': stockMinimo,
        'imagen_url': datos['imagen_url'] ?? '',
      };
      if (i < 0) { productos.add(producto); } else { productos[i] = producto; }
      base['productos'] = productos;
      _movimiento(base, idReal, previo, stock,
          i < 0 ? 'Nuevo producto local' : 'Edición de producto local');
      return mensaje;
    }
    if (accion == 'producto_archivar') {
      final id = _entero(datos['id_producto']);
      final productos = _filas(base,'productos');
      final index = productos.indexWhere((p)=>
          _entero(p['id_producto']) == id && p['archivado'] != true);
      if (index < 0) throw StateError('Producto no encontrado');
      productos[index]['archivado'] = true;
      base['productos'] = productos;
      return {...mensaje, 'mensaje': 'Producto archivado en SQLite'};
    }
    if (accion == 'inventario_movimiento') {
      final id = _entero(datos['id_producto']);
      final cambio = _entero(datos['cantidad']);
      final tipo = (datos['tipo_movimiento'] ?? datos['tipo'])
          ?.toString() ?? '';
      final lista = _filas(base, 'productos');
      final i = lista.indexWhere((p) => _entero(p['id_producto']) == id);
      if (i < 0 || cambio <= 0 || !['Entrada','Salida'].contains(tipo)) {
        throw StateError('Movimiento inválido');
      }
      final antes = _entero(lista[i]['stock']);
      final nuevo = tipo == 'Entrada' ? antes + cambio : antes - cambio;
      if (nuevo < 0) throw StateError('Stock insuficiente');
      lista[i]['stock'] = nuevo;
      base['productos'] = lista;
      _movimiento(base, id, antes, nuevo,
          (datos['motivo'] ?? 'Ajuste local').toString());
      return mensaje;
    }
    if (accion == 'cliente_guardar' || accion == 'proveedor_guardar') {
      final cliente = accion == 'cliente_guardar';
      final tabla = cliente ? 'clientes' : 'proveedores';
      final idCol = cliente ? 'id_usuario' : 'id_proveedor';
      final id = _entero(datos[idCol] ?? 0);
      final nombre = (datos[cliente ? 'nombres' : 'razon_social'] ?? '')
          .toString().trim();
      if (nombre.isEmpty) throw StateError('Completa el nombre');
      final lista = _filas(base, tabla);
      final i = lista.indexWhere((p) => _entero(p[idCol]) == id);
      if (id > 0 && i < 0) throw StateError('Registro no encontrado');
      if (cliente) {
        final email = (datos['correo'] ?? '').toString().trim().toLowerCase();
        if (!email.contains('@')) throw StateError('Correo no válido');
        if (lista.any((p) => p['correo']==email && _entero(p[idCol])!=id)) {
          throw StateError('Correo ya registrado');
        }
      }
      final nuevo = <String, dynamic>{
        ...?(i >= 0 ? lista[i] : null),
        ...datos,
        if (cliente) 'apellidos': datos['apellidos'] ?? '',
        if (cliente) 'telefono': datos['telefono'] ?? '',
        idCol: i >= 0 ? id : _id(base),
        'estado': (datos['estado'] ?? (i>=0 ? lista[i]['estado'] : 'Activo')),
      };
      nuevo.remove('accion');
      nuevo.remove('contrasena');
      if (cliente) {
        nuevo['correo'] = nuevo['correo'].toString().trim().toLowerCase();
        final contrasena = datos['contrasena']?.toString() ?? '';
        if (contrasena.isNotEmpty) {
          if (contrasena.length < 8 || contrasena.length > 128) {
            throw StateError('La contraseña local requiere entre 8 y 128 caracteres');
          }
          final random = Random.secure();
          final salt = base64Encode(List<int>.generate(24,
              (_) => random.nextInt(256)));
          final accesos = _filas(base, 'accesos_clientes');
          accesos.removeWhere((p) =>
              _entero(p['id_usuario']) == _entero(nuevo['id_usuario']));
          accesos.add({
            'id_usuario': nuevo['id_usuario'],
            'salt': salt, 'hash': _hash(contrasena, salt),
          });
          base['accesos_clientes'] = accesos;
        }
      }
      if (i < 0) { lista.add(nuevo); } else { lista[i] = nuevo; }
      base[tabla] = lista;
      return mensaje;
    }
    if (accion == 'cliente_estado') {
      final id = _entero(datos['id_usuario']);
      final estado = datos['estado'] ?? datos['estado_usuario'];
      if (!['Activo','Bloqueado'].contains(estado)) {
        throw StateError('Estado inválido');
      }
      final lista = _filas(base, 'clientes');
      final i = lista.indexWhere((p) => _entero(p['id_usuario'])==id);
      if (i < 0) throw StateError('Cliente no encontrado');
      lista[i]['estado'] = estado;
      base['clientes'] = lista;
      return mensaje;
    }
    if (accion == 'proveedor_eliminar') {
      final id = _entero(datos['id_proveedor']);
      if (_filas(base, 'compras').any((p) =>
          _entero(p['id_proveedor']) == id)) {
        throw StateError('Proveedor con compras asociadas');
      }
      final lista = _filas(base, 'proveedores');
      lista.removeWhere((p) => _entero(p['id_proveedor']) == id);
      base['proveedores'] = lista;
      return mensaje;
    }
    if (accion == 'direccion_guardar') {
      final id = _entero(datos['id_direccion'] ?? 0);
      final cliente = _entero(datos['id_usuario']);
      if (!_filas(base,'clientes').any((p) =>
          _entero(p['id_usuario']) == cliente)) {
        throw StateError('Cliente no encontrado');
      }
      final detalle = (datos['direccion_detalle'] ?? '').toString().trim();
      if (detalle.isEmpty) throw StateError('Escribe la dirección');
      final lista = _filas(base,'direcciones');
      final i = lista.indexWhere((p) => _entero(p['id_direccion'])==id);
      final nuevo = <String,dynamic>{...datos,
        'id_direccion': i>=0?id:_id(base)};
      nuevo.remove('accion');
      if (i < 0) { lista.add(nuevo); } else { lista[i]=nuevo; }
      base['direcciones']=lista;
      return {...mensaje, 'id_direccion': nuevo['id_direccion']};
    }
    if (accion == 'direccion_eliminar') {
      final id = _entero(datos['id_direccion']);
      if (_filas(base,'pedidos').any((p) =>
          _entero(p['id_direccion'])==id)) {
        throw StateError('Dirección asociada a un pedido');
      }
      final lista=_filas(base,'direcciones');
      lista.removeWhere((p)=>_entero(p['id_direccion'])==id);
      base['direcciones']=lista;
      return mensaje;
    }
    if (accion == 'pedido_manual' || accion == 'compra_registrar') {
      final compra = accion=='compra_registrar';
      final personaId = _entero(datos[compra ? 'id_proveedor':'id_usuario']);
      final tablaPersona = compra ? 'proveedores':'clientes';
      final idCol = compra ? 'id_proveedor':'id_usuario';
      if (!_filas(base,tablaPersona).any((p) =>
          _entero(p[idCol])==personaId && p['estado']=='Activo')) {
        throw StateError('Cliente o proveedor no disponible');
      }
      final items = datos['items'];
      if (items is! List || items.isEmpty || items.length>50) {
        throw StateError('Agrega al menos un repuesto');
      }
      final productos=_filas(base,'productos');
      final lineas=<Map<String,dynamic>>[];
      final distintos=<int>{};
      var total=0.0;
      for (final item in items) {
        if (item is! Map) throw StateError('Detalle inválido');
        final idProducto=_entero(item['id_producto']);
        final cantidad=_entero(item['cantidad']);
        final pos=productos.indexWhere((p) =>
          _entero(p['id_producto'])==idProducto &&
          p['archivado'] != true);
        if (cantidad<=0 || cantidad>100000 || pos<0 ||
          !distintos.add(idProducto)) {
          throw StateError('Repuesto o cantidad inválidos/duplicados');
        }
        final p=productos[pos];
        final anterior=_entero(p['stock']);
        if (!compra && anterior<cantidad) {
          throw StateError('Stock insuficiente: ' +
              p['nombre_producto'].toString());
        }
        final precio = compra ? _decimal(item['precio_compra'])
          : (_decimal(p['precio_oferta'])>0 &&
               _decimal(p['precio_oferta']) < _decimal(p['precio'])
            ? _decimal(p['precio_oferta']) : _decimal(p['precio']));
        if (precio.isNaN || precio < 0 || precio > 10000000) {
          throw StateError('Precio inválido');
        }
        final parcial=double.parse((precio*cantidad).toStringAsFixed(2));
        total+=parcial;
        lineas.add({
          'id_producto': idProducto, 'nombre_producto': p['nombre_producto'],
          'cantidad': cantidad, 'precio_unitario': precio,
          'precio_compra': precio, 'subtotal': parcial,
          'stock_anterior': anterior,
        });
      }
      final entrega=datos['tipo_entrega']??'Recojo en tienda';
      if (!compra && !['Delivery','Recojo en tienda'].contains(entrega)) {
        throw StateError('Tipo de entrega inválido');
      }
      if (!compra && !['Efectivo','Yape','Plin','Transferencia']
          .contains(datos['metodo_pago'])) {
        throw StateError('Método de pago inválido');
      }
      final direccionId=_entero(datos['id_direccion']??0);
      if (!compra && entrega=='Delivery') {
        if (!_filas(base,'direcciones').any((d)=>
            _entero(d['id_direccion'])==direccionId &&
            _entero(d['id_usuario'])==personaId)) {
          throw StateError('Elige una dirección válida del cliente');
        }
        final config=Map<String,dynamic>.from(base['configuracion'] as Map);
        final costo=_decimal(config['costo_delivery']);
        total+=costo.isNaN?0:costo;
      }
      total=double.parse(total.toStringAsFixed(2));
      final idPedido=_id(base);
      if (compra) {
        final compras=_filas(base,'compras');
        compras.add({'id_compra':idPedido,'id_proveedor':personaId,
          'fecha_compra':ahora, 'total':total,'estado':'Registrado'});
        base['compras']=compras;
      } else {
        final cliente=_filas(base,'clientes').firstWhere((p)=>
            _entero(p['id_usuario'])==personaId);
        final pedidos=_filas(base,'pedidos');
        pedidos.add({
          'id_pedido':idPedido,'id_usuario':personaId,
          'id_direccion':entrega=='Delivery'?direccionId:null,
          'fecha_pedido':ahora,'estado_pedido':'Pendiente','total':total,
          'tipo_entrega':entrega,'nombres':cliente['nombres'],
          'apellidos':cliente['apellidos']??'','correo':cliente['correo']??'',
        });
        base['pedidos']=pedidos;
        final pagos=_filas(base,'pagos');
        pagos.add({'id_pago':_id(base),'id_pedido':idPedido,'monto':total,
          'metodo_pago':datos['metodo_pago']??'Efectivo',
          'estado_pago':'Pendiente','fecha_pago':ahora});
        base['pagos']=pagos;
      }
      final detalles=_filas(base,compra?'detalle_compra':'detalle_pedido');
      for (final item in lineas) {
        final pos=productos.indexWhere((p)=>_entero(p['id_producto'])==
            _entero(item['id_producto']));
        final previo=_entero(productos[pos]['stock']);
        final nuevo=compra?previo+_entero(item['cantidad'])
            :previo-_entero(item['cantidad']);
        productos[pos]['stock']=nuevo;
        _movimiento(base,_entero(item['id_producto']),previo,nuevo,
          (compra?'Compra local #':'Venta local #')+idPedido.toString());
        detalles.add({...item,
          compra?'id_compra':'id_pedido':idPedido});
      }
      base['productos']=productos;
      base[compra?'detalle_compra':'detalle_pedido']=detalles;
      return {...mensaje, compra?'id_compra':'id_pedido':idPedido,
        'total':total};
    }
    if (accion == 'compra_estado') {
      final id = _entero(datos['id_compra']);
      final nuevo = (datos['estado'] ?? '').toString();
      if (!['Registrado', 'Anulado'].contains(nuevo)) {
        throw StateError('Estado de compra inválido');
      }
      final compras = _filas(base, 'compras');
      final index = compras.indexWhere((p) => _entero(p['id_compra'])==id);
      if (index < 0) throw StateError('Compra no encontrada');
      if (compras[index]['estado'] == nuevo) {
        throw StateError('La compra ya tiene ese estado');
      }
      final productos = _filas(base,'productos');
      final cambios = <Map<String,int>>[];
      for (final detalle in _filas(base,'detalle_compra')
          .where((p)=>_entero(p['id_compra'])==id)) {
        final prodId = _entero(detalle['id_producto']);
        final i = productos.indexWhere((p)=>
          _entero(p['id_producto'])==prodId);
        if (i < 0) throw StateError('Producto de compra no encontrado');
        final previo = _entero(productos[i]['stock']);
        final cambio = _entero(detalle['cantidad']);
        final actual = nuevo == 'Anulado'
            ? previo - cambio : previo + cambio;
        if (actual < 0) {
          throw StateError('Stock insuficiente para anular esta compra');
        }
        cambios.add({'id':prodId,'index':i,'antes':previo,'nuevo':actual});
      }
      for (final item in cambios) {
        productos[item['index']!]['stock']=item['nuevo']!;
        _movimiento(base,item['id']!,item['antes']!,item['nuevo']!,
          (nuevo=='Anulado'?'Anular compra local #'
            :'Reactivar compra local #')+id.toString());
      }
      compras[index]['estado']=nuevo;
      base['compras']=compras;
      base['productos']=productos;
      return mensaje;
    }
    if (accion == 'pedido_estado' || accion == 'pedido_cancelar') {
      final id=_entero(datos['id_pedido']);
      final pedidos=_filas(base,'pedidos');
      final index=pedidos.indexWhere((p)=>_entero(p['id_pedido'])==id);
      if (index<0) throw StateError('Pedido no encontrado');
      final pedido=pedidos[index];
      final anterior=pedido['estado_pedido'].toString();
      final nuevo=accion=='pedido_cancelar'?'Cancelado':
        datos['estado_pedido'].toString();
      final transiciones={
        'Pendiente':['Procesando','Cancelado'],
        'Pagado':['Procesando','Enviado'],
        'Procesando':['Enviado','Cancelado'],
        'Enviado':['Completado'],
      };
      if (!(transiciones[anterior]??[]).contains(nuevo)) {
        throw StateError('Cambio de estado no permitido');
      }
      if (nuevo=='Cancelado') {
        if (_filas(base,'pagos').any((p)=>
            _entero(p['id_pedido'])==id && p['estado_pago']=='Pagado')) {
          throw StateError('La venta ya recibió pagos');
        }
        final productos=_filas(base,'productos');
        for (final linea in _filas(base,'detalle_pedido').where(
            (l)=>_entero(l['id_pedido'])==id)) {
          final prodId=_entero(linea['id_producto']);
          final pos=productos.indexWhere((p)=>
              _entero(p['id_producto'])==prodId);
          if (pos<0) throw StateError('Producto no encontrado');
          final antes=_entero(productos[pos]['stock']);
          final despues=antes+_entero(linea['cantidad']);
          productos[pos]['stock']=despues;
          _movimiento(base,prodId,antes,despues,
            'Devolución por cancelación local #'+id.toString());
        }
        base['productos']=productos;
      }
      if (nuevo=='Completado') {
        final pagado=_filas(base,'pagos').where((p)=>
            _entero(p['id_pedido'])==id && p['estado_pago']=='Pagado')
          .fold<double>(0,(a,p)=>a+_decimal(p['monto']));
        if (pagado+0.009<_decimal(pedido['total'])) {
          throw StateError('Pedido tiene saldo sin pagar');
        }
      }
      pedidos[index]['estado_pedido']=nuevo;
      base['pedidos']=pedidos;
      return mensaje;
    }
    if (accion == 'pago_manual' || accion == 'pago_estado' ||
        accion == 'pago_confirmar') {
      final pagos=_filas(base,'pagos');
      final nuevo=accion=='pago_manual';
      final idPago=_entero(datos['id_pago']);
      final index=pagos.indexWhere((p)=>_entero(p['id_pago'])==idPago);
      if (!nuevo && index<0) throw StateError('Pago no encontrado');
      final pedidoId=nuevo?_entero(datos['id_pedido'])
          :_entero(pagos[index]['id_pedido']);
      final pedido=_filas(base,'pedidos').where((p)=>
          _entero(p['id_pedido'])==pedidoId);
      if (pedido.isEmpty || pedido.first['estado_pedido']=='Cancelado') {
        throw StateError('Pedido no encontrado o cancelado');
      }
      final estadoPago=accion=='pago_confirmar'?'Pagado':
          (datos['estado_pago']??'Pendiente').toString();
      if (!['Pendiente','Pagado','Rechazado'].contains(estadoPago)) {
        throw StateError('Estado inválido');
      }
      final monto=nuevo?_decimal(datos['monto']):_decimal(pagos[index]['monto']);
      if (monto.isNaN || monto<=0) throw StateError('Monto inválido');
      if (nuevo && !['Efectivo','Yape','Plin','Transferencia']
          .contains(datos['metodo_pago'])) {
        throw StateError('Método no válido');
      }
      final pagado=pagos.where((p)=>
          _entero(p['id_pedido'])==pedidoId &&
          p['estado_pago']=='Pagado' &&
          (nuevo || _entero(p['id_pago'])!=idPago))
        .fold<double>(0,(a,p)=>a+_decimal(p['monto']));
      if (estadoPago=='Pagado' &&
          pagado+monto>_decimal(pedido.first['total'])+0.009) {
        throw StateError('El pago excede el saldo');
      }
      if (nuevo) {
        pagos.add({'id_pago':_id(base),'id_pedido':pedidoId,
          'monto':monto,'metodo_pago':datos['metodo_pago'],
          'estado_pago':estadoPago,'fecha_pago':ahora});
      } else { pagos[index]['estado_pago']=estadoPago; }
      base['pagos']=pagos;
      _sincronizarPago(base,pedidoId);
      return mensaje;
    }
    if (accion == 'comprobante_emitir') {
      final idPedido = _entero(datos['id_pedido']);
      final tipo = datos['tipo_comprobante']?.toString() ?? '';
      if (idPedido <= 0 || !['Boleta','Factura'].contains(tipo)) {
        throw StateError('Selecciona un pedido y un tipo de comprobante');
      }
      final pedidos = _filas(base,'pedidos');
      final encontrados = pedidos.where((p) =>
          _entero(p['id_pedido']) == idPedido);
      if (encontrados.isEmpty ||
          encontrados.first['estado_pedido'] == 'Cancelado') {
        throw StateError('Pedido no disponible para comprobante');
      }
      final pedido = encontrados.first;
      final total = _decimal(pedido['total']);
      final abonado = _filas(base,'pagos').where((p) =>
          _entero(p['id_pedido']) == idPedido &&
          p['estado_pago'] == 'Pagado').fold<double>(0,
            (a,p) => a+_decimal(p['monto']));
      if (!total.isFinite || total <= 0 || abonado+0.009 < total) {
        throw StateError('Primero confirma el pago íntegro del pedido');
      }
      final comprobantes = _filas(base, 'comprobantes');
      if (comprobantes.any((p)=>
          _entero(p['id_pedido']) == idPedido &&
          p['tipo_comprobante'] == tipo)) {
        throw StateError('Ya existe un comprobante local de ese tipo');
      }
      final serie = tipo == 'Boleta' ? 'B001' : 'F001';
      var correlativo = 0;
      for (final p in comprobantes) {
        if (p['tipo_comprobante'] != tipo) continue;
        final numero = p['numero_comprobante']?.toString() ?? '';
        if (!numero.startsWith(serie + '-')) continue;
        final valor = int.tryParse(numero.substring(serie.length+1)) ?? 0;
        if (valor > correlativo) correlativo = valor;
      }
      final numero = serie + '-' +
          (correlativo+1).toString().padLeft(8,'0');
      final config = Map<String, dynamic>.from(base['configuracion'] as Map);
      final igvPorcentaje = _decimal(config['igv']);
      if (!igvPorcentaje.isFinite || igvPorcentaje < 0 ||
          igvPorcentaje > 100) {
        throw StateError('Configura un IGV válido entre 0 y 100');
      }
      final subtotal = double.parse(
        (total / (1 + igvPorcentaje / 100)).toStringAsFixed(2));
      final igvMonto = double.parse((total - subtotal).toStringAsFixed(2));
      comprobantes.add({
        'id_comprobante': _id(base), 'id_pedido': idPedido,
        'tipo_comprobante': tipo, 'numero_comprobante': numero,
        'subtotal': subtotal, 'igv_monto': igvMonto,
        'igv_porcentaje': igvPorcentaje,
        'total': total, 'fecha_emision': ahora,
        'observacion': 'Documento de demostración. Sin validez SUNAT.',
      });
      base['comprobantes'] = comprobantes;
      return {...mensaje, 'numero_comprobante':numero,
        'mensaje':'Comprobante DEMO local ' + numero +
            '. No emitido ante SUNAT.'};
    }
    if (accion == 'configuracion_guardar') {
      final actual=Map<String,dynamic>.from(base['configuracion'] as Map);
      final nuevo={...actual,...datos}..remove('accion');
      if (datos.containsKey('direccion_empresa')) {
        nuevo['direccion'] = datos['direccion_empresa'];
      }
      if (datos.containsKey('telefono_empresa')) {
        nuevo['telefono'] = datos['telefono_empresa'];
      }
      if (datos.containsKey('correo_empresa')) {
        nuevo['correo'] = datos['correo_empresa'];
      }
      final delivery=_decimal(nuevo['costo_delivery']);
      if (delivery.isNaN || delivery<0) throw StateError('Delivery inválido');
      base['configuracion']=nuevo;
      return mensaje;
    }
    throw StateError('Operación no disponible en el dashboard local');
  });

  static Future<String> guardarFoto(XFile foto) async {
    _soloDispositivo();
    final bytes=await foto.readAsBytes();
    if (bytes.length>3*1024*1024 || bytes.isEmpty) {
      throw StateError('La fotografía debe pesar menos de 3 MB');
    }
    final inicio=bytes.length>12 ? bytes.take(12).toList():bytes;
    final png=inicio.length>7 && inicio[0]==137 && inicio[1]==80 &&
        inicio[2]==78 && inicio[3]==71;
    final jpeg=inicio.length>2 && inicio[0]==255 && inicio[1]==216;
    final webp=inicio.length>11 &&
        ascii.decode(inicio.sublist(0,4),allowInvalid:true)=='RIFF' &&
        ascii.decode(inicio.sublist(8,12),allowInvalid:true)=='WEBP';
    if (!png && !jpeg && !webp) {
      throw StateError('Usa una foto JPEG, PNG o WebP');
    }
    final extension=png?'png':jpeg?'jpg':'webp';
    final directorio=Directory(path.join(await getDatabasesPath(),
      'dorada_fotos_locales'));
    await directorio.create(recursive:true);
    final random=Random.secure();
    final nombre=List<int>.generate(12,(_)=>random.nextInt(256))
      .map((n)=>n.toRadixString(16).padLeft(2,'0')).join();
    final archivo=File(path.join(directorio.path,'foto_$nombre.$extension'));
    await archivo.writeAsBytes(bytes,flush:true);
    return archivo.path;
  }
}
