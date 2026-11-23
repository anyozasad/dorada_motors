// ignore_for_file: prefer_interpolation_to_compose_strings, curly_braces_in_flow_control_structures, use_null_aware_elements
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/admin_offline_repository.dart';
import '../services/local_store.dart';
import '../services/product_image_url.dart';
import '../theme/app_theme.dart';
import '../widgets/product_image.dart';
import 'admin_mobile_forms.dart';
import 'admin_mobile_purchase_form.dart';
import 'admin_mobile_order_form.dart';

class AdminMobileApi {
  static const keyToken = 'adm_token';
  static const keyUrl = 'adm_url';
  static const keyId = 'adm_id';
  static const keyRole = 'adm_role';
  static const keyName = 'adm_name';

  static Future<Map<String, String>?> sesion() async {
    final p = await SharedPreferences.getInstance();
    if ((p.getString(keyToken) ?? '').isEmpty ||
        p.getString(keyUrl) != ApiService.baseUrl) return null;
    return {
      'id': p.getString(keyId) ?? '',
      'rol': p.getString(keyRole) ?? '',
      'nombre': p.getString(keyName) ?? '',
    };
  }

  static Future<Map<String, dynamic>> consultar(String vista,
      {Map<String, String> parametros = const {}}) =>
      _request('GET', vista, null, false, parametros);

  static Future<Map<String, dynamic>> operar(Map<String, dynamic> data) =>
      _request('POST', '', data, false);

  static Future<Map<String, dynamic>> _request(String method, String view,
      Map<String, dynamic>? data, bool login,
      [Map<String, String> parametros = const {}]) async {
    final p = await SharedPreferences.getInstance();
    final token = login ? '' : p.getString(keyToken) ?? '';
    final uri = Uri.parse(ApiService.baseUrl + '/admin_movil.php')
        .replace(queryParameters: method == 'GET'
            ? {'vista': view, ...parametros} : null);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (method == 'POST') 'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer ' + token,
    };
    final http.Response response;
    if (method == 'GET') {
      response = await http.get(uri, headers: headers)
          .timeout(const Duration(seconds: 9));
    } else {
      response = await http.post(uri, headers: headers, body: jsonEncode(data))
          .timeout(const Duration(seconds: 12));
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw StateError('PHP no devolvió datos JSON. Revisa Apache y MySQL.');
    }
    if (decoded is! Map) throw StateError('Respuesta de PHP inválida');
    final result = Map<String, dynamic>.from(decoded);
    if (response.statusCode == 401) {
      throw AdminMobileUnauthorized(
          result['mensaje']?.toString() ?? 'Sesión vencida');
    }
    if (response.statusCode < 200 || response.statusCode >= 300 ||
        result['estado'] != true) {
      throw StateError(result['mensaje']?.toString() ??
          'HTTP ' + response.statusCode.toString());
    }
    return result;
  }


  static Future<String> subirFotografia(XFile foto) async {
    final bytes = await foto.readAsBytes();
    if (bytes.isEmpty || bytes.length > 3 * 1024 * 1024) {
      throw StateError('La fotografía debe pesar menos de 3 MB');
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(keyToken) ?? '';
    if (token.isEmpty || prefs.getString(keyUrl) != ApiService.baseUrl) {
      throw const AdminMobileUnauthorized('Inicia sesión como administrador');
    }
    final peticion = http.MultipartRequest('POST',
        Uri.parse(ApiService.baseUrl + '/admin_movil.php'));
    peticion.headers['Accept'] = 'application/json';
    peticion.headers['Authorization'] = 'Bearer ' + token;
    peticion.fields['accion'] = 'imagen_producto';
    peticion.files.add(http.MultipartFile.fromBytes('imagen', bytes,
        filename: foto.name));
    final enviada = await peticion.send().timeout(const Duration(seconds: 25));
    final response = await http.Response.fromStream(enviada);
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw StateError('No se pudo leer la respuesta de subida');
    }
    if (decoded is! Map) throw StateError('Respuesta de imagen inválida');
    if (response.statusCode == 401) {
      throw const AdminMobileUnauthorized('Vuelve a iniciar sesión');
    }
    if (response.statusCode != 200 || decoded['estado'] != true) {
      throw StateError(decoded['mensaje']?.toString() ??
          'No se pudo subir la fotografía');
    }
    final ruta = decoded['imagen_url']?.toString() ?? '';
    if (!ruta.startsWith('uploads/productos/')) {
      throw StateError('El servidor no guardó la ruta de imagen');
    }
    return ruta;
  }

  static Future<void> ingresar(String email, String pass) async {
    final r = await _request('POST', '', {
      'accion': 'login', 'correo': email.trim().toLowerCase(),
      'contrasena': pass,
    }, true);
    final u = r['usuario'];
    final token = r['token']?.toString() ?? '';
    if (u is! Map || token.length != 64 ||
        !['Administrador', 'Vendedor', 'Almacen']
            .contains(u['rol_sistema']?.toString())) {
      throw StateError('PHP no confirmó los permisos administrativos');
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(keyToken, token);
    await p.setString(keyUrl, ApiService.baseUrl);
    await p.setString(keyId, u['id_usuario'].toString());
    await p.setString(keyRole, u['rol_sistema'].toString());
    await p.setString(keyName,
        (u['nombres'].toString() + ' ' + u['apellidos'].toString()).trim());
    // Nunca dejar la sesión de comprador abierta al cambiar de rol.
    await LocalStore.logout();
    await LocalStore.clearCart();
    await LocalStore.saveFavorites(<int>{});
  }

  static Future<bool?> verificar() async {
    final local = await sesion();
    if (local == null) return false;
    try {
      final r = await consultar('sesion');
      final u = r['usuario'];
      return u is Map &&
          u['id_usuario'].toString() == local['id'] &&
          u['rol_sistema'].toString() == local['rol'];
    } on AdminMobileUnauthorized {
      return false;
    } catch (_) {
      return null;
    }
  }

  static Future<void> salir() async {
    try {
      await operar({'accion': 'logout'});
    } catch (_) {}
    await limpiar();
  }

  static Future<void> limpiar() async {
    final p = await SharedPreferences.getInstance();
    for (final k in [keyToken, keyUrl, keyId, keyRole, keyName]) {
      await p.remove(k);
    }
  }
}

class AdminMobileUnauthorized implements Exception {
  final String mensaje;
  const AdminMobileUnauthorized(this.mensaje);
  @override
  String toString() => mensaje;
}

class AdminMobileLoginScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const AdminMobileLoginScreen({super.key, required this.onAuthenticated});
  @override
  State<AdminMobileLoginScreen> createState() => _AdminMobileLoginScreenState();
}

class _AdminMobileLoginScreenState extends State<AdminMobileLoginScreen> {
  final correo = TextEditingController();
  final clave = TextEditingController();
  bool procesando = false;
  bool ocultar = true;

  @override
  void dispose() {
    correo.dispose();
    clave.dispose();
    super.dispose();
  }

  Future<void> entrar() async {
    if (procesando) return;
    if (correo.text.trim().isEmpty || clave.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completa correo y contraseña')));
      return;
    }
    setState(() => procesando = true);
    try {
      await AdminMobileApi.ingresar(correo.text, clave.text);
      if (mounted) widget.onAuthenticated();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))));
    } finally {
      if (mounted) setState(() => procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Acceso administrador')),
    body: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.admin_panel_settings_rounded,
              size: 70, color: AppColors.goldDark),
          const SizedBox(height: 12),
          const Text('Dashboard Dorada Motors',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text('Usa tu cuenta del dashboard PHP.\nServidor: ' +
              ApiService.baseUrl, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          TextField(controller: correo,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo',
                  prefixIcon: Icon(Icons.mail_outline))),
          const SizedBox(height: 12),
          TextField(controller: clave, obscureText: ocultar,
              onSubmitted: (_) => entrar(),
              decoration: InputDecoration(labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                      icon: Icon(ocultar ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => ocultar = !ocultar)))),
          const SizedBox(height: 22),
          FilledButton.icon(
              onPressed: procesando ? null : entrar,
              icon: const Icon(Icons.login),
              label: Text(procesando ? 'Verificando...' :
                  'ENTRAR AL DASHBOARD')),
          const SizedBox(height: 12),
          const Text('Acceso exclusivo a Administrador, Vendedor y Almacén.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
      ),
    )),
  );
}

class AdminMobileDashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final bool modoLocal;
  const AdminMobileDashboardScreen({super.key, required this.onLogout,
      this.modoLocal = false});
  @override
  State<AdminMobileDashboardScreen> createState() =>
      _AdminMobileDashboardScreenState();
}

class _AdminMobileDashboardScreenState
    extends State<AdminMobileDashboardScreen> {
  String rol = '';
  String nombre = '';
  String vista = 'resumen';
  int? clienteDirecciones;
  Map<String, dynamic> datos = {};
  bool cargando = true;
  bool guardando = false;
  String? error;
  int _versionCarga = 0;

  Future<Map<String, dynamic>> consultar(String vista,
      {Map<String, String> parametros = const {}}) async {
    if (widget.modoLocal) {
      return AdminOfflineRepository.consultar(vista,
        id: int.tryParse(parametros['id_usuario'] ??
            parametros['id_pedido'] ?? ''));
    }
    return AdminMobileApi.consultar(vista, parametros: parametros);
  }

  Future<Map<String, dynamic>> operar(Map<String, dynamic> args) async {
    if (widget.modoLocal) return AdminOfflineRepository.operar(args);
    return AdminMobileApi.operar(args);
  }

  bool permitido(String modulo) {
    if (rol == 'Administrador') return true;
    if (rol == 'Vendedor') {
      return ['resumen', 'clientes', 'pedidos', 'pagos', 'reportes']
          .contains(modulo);
    }
    return ['resumen', 'productos', 'inventario', 'proveedores', 'reportes']
        .contains(modulo);
  }

  List<String> get secciones => [
    'resumen',
    if (permitido('productos')) 'productos',
    if (permitido('pedidos')) 'pedidos',
    if (permitido('pagos')) 'pagos',
    'mas',
  ];

  @override
  void initState() {
    super.initState();
    iniciar();
  }

  Future<void> iniciar() async {
    final s = widget.modoLocal ? <String, String>{
      'rol': 'Administrador', 'nombre': 'Administrador local',
    } : await AdminMobileApi.sesion();
    if (!mounted) return;
    setState(() {
      rol = s?['rol'] ?? '';
      nombre = s?['nombre'] ?? 'Administración';
    });
    await cargar();
  }

  Future<void> cargar() async {
    if (!mounted) return;
    final version = ++_versionCarga;
    final modulo = vista;
    if (modulo == 'mas') {
      setState(() { cargando = false; error = null; });
      return;
    }
    setState(() { cargando = true; error = null; });
    try {
      final r = await consultar(modulo,
          parametros: modulo == 'direcciones' && clienteDirecciones != null
              ? {'id_usuario': clienteDirecciones.toString()} : const {});
      if (!mounted || version != _versionCarga) return;
      setState(() { datos = r; cargando = false; });
    } catch (e) {
      if (!mounted || version != _versionCarga) return;
      setState(() {
        cargando = false;
        error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  void navegar(String destino) {
    if (guardando || destino == vista) return;
    setState(() { vista = destino; datos = {}; error = null; });
    cargar();
  }

  void abrirDirecciones(Map<String, dynamic> cliente) {
    clienteDirecciones = int.tryParse(cliente['id_usuario'].toString());
    navegar('direcciones');
  }

  Future<void> salir() async {
    if (widget.modoLocal) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await AdminMobileApi.salir();
    if (mounted) widget.onLogout();
  }

  Future<void> ejecutar(Map<String, dynamic> args) async {
    if (guardando) return;
    setState(() => guardando = true);
    try {
      final r = await operar(args);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r['mensaje']?.toString() ??
              (widget.modoLocal ? 'Guardado en SQLite de este celular' :
              'Actualizado en MySQL'))));
      await cargar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))));
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  Future<bool> confirmar(String mensaje) async =>
      await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar acción'), content: Text(mensaje),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Volver')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmar')),
          ],
        )) == true;

  Future<void> cambiarEstado(Map<String, dynamic> pedido) async {
    final actual = pedido['estado_pedido']?.toString() ?? '';
    final opciones = switch (actual) {
      'Pendiente' => ['Procesando'],
      'Pagado' => ['Procesando', 'Enviado'],
      'Procesando' => ['Enviado'],
      'Enviado' => ['Completado'],
      _ => <String>[],
    };
    if (opciones.isEmpty) return;
    final nuevo = await showDialog<String>(context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Pedido #' + pedido['id_pedido'].toString()),
        children: [
          for (final item in opciones)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, item),
                child: Text('Cambiar a ' + item)),
        ],
      ));
    if (nuevo != null && mounted) {
      await ejecutar({'accion': 'pedido_estado',
        'id_pedido': pedido['id_pedido'], 'estado_pedido': nuevo});
    }
  }

  Future<void> editarProducto([Map<String, dynamic>? producto]) async {
    try {
      final data = await consultar('catalogos');
      if (!mounted) return;
      final categorias = ((data['categorias'] as List?) ?? const [])
          .whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
      final marcas = ((data['marcas'] as List?) ?? const [])
          .whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
      if (categorias.isEmpty || marcas.isEmpty) {
        throw StateError('Registra categorías y marcas desde PHP primero');
      }
      final valores = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => _ProductoEditor(producto: producto,
            categorias: categorias, marcas: marcas,
            modoLocal: widget.modoLocal));
      if (valores != null && mounted) {
        await ejecutar({'accion': 'producto_guardar', ...valores});
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))));
    }
  }




  Future<void> registrarVenta() async {
    try {
      final respuestas = await Future.wait([
        consultar('clientes'),
        consultar('productos'),
      ]);
      if (!mounted) return;
      final clientes = ((respuestas[0]['items'] as List?) ?? const [])
          .whereType<Map>().map((p) => Map<String, dynamic>.from(p))
          .where((p) => p['estado'] == 'Activo').toList();
      final productos = ((respuestas[1]['items'] as List?) ?? const [])
          .whereType<Map>().map((p) => Map<String, dynamic>.from(p)).toList();
      if (clientes.isEmpty || productos.isEmpty) {
        throw StateError('Primero necesitas clientes activos y productos.');
      }
      final formulario = await AdminMobileOrderForm.abrir(context,
        clientes: clientes, productos: productos,
        cargarDirecciones: (id) async {
          final datos = await consultar('direcciones',
              parametros: {'id_usuario': id});
          return ((datos['items'] as List?) ?? const [])
              .whereType<Map>()
              .map((p) => Map<String, dynamic>.from(p)).toList();
        });
      if (formulario == null || !mounted) return;
      if (!await confirmar(widget.modoLocal
          ? 'Se guardará esta venta y descontará el stock '
            'solo en SQLite del celular. ¿Confirmar?'
          : 'Se registrará la venta, el detalle, '
            'el pago pendiente y se descontará el stock. ¿Confirmas?')
          || !mounted) return;
      await ejecutar({'accion': 'pedido_manual', ...formulario});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))));
    }
  }

  Future<void> verDetallePedido(Map<String, dynamic> pedido) async {
    try {
      final respuesta = await consultar('pedido_detalle',
        parametros: {'id_pedido': pedido['id_pedido'].toString()});
      if (!mounted) return;
      final cabecera = Map<String, dynamic>.from(respuesta['pedido'] as Map);
      final detalles = ((respuesta['lineas'] as List?) ?? const [])
          .whereType<Map>();
      final pagos = ((respuesta['pagos'] as List?) ?? const [])
          .whereType<Map>();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text('Pedido #' + pedido['id_pedido'].toString()),
        content: SizedBox(width: 490,
          child: SingleChildScrollView(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Cliente: ' + cabecera['nombres'].toString() + ' ' +
                  cabecera['apellidos'].toString()),
              Text('Estado: ' + cabecera['estado_pedido'].toString()),
              Text('Entrega: ' + cabecera['tipo_entrega'].toString()),
              const Divider(),
              const Text('Artículos',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              for (final p in detalles) ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p['nombre_producto'].toString()),
                subtitle: Text('Cantidad: ' + p['cantidad'].toString() +
                  ' · Unitario: S/ ' + p['precio_unitario'].toString()),
                trailing: Text('S/ ' + p['subtotal'].toString()),
              ),
              const Divider(),
              const Text('Pagos',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              for (final p in pagos) ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p['metodo_pago'].toString()),
                subtitle: Text(p['estado_pago'].toString()),
                trailing: Text('S/ ' + p['monto'].toString()),
              ),
              const Divider(),
              Text('TOTAL S/ ' + cabecera['total'].toString(),
                style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ))),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))));
    }
  }

  Future<void> registrarAbono() async {
    try {
      final datosPedidos = await consultar('pedidos');
      if (!mounted) return;
      final pedidos = ((datosPedidos['items'] as List?) ?? const [])
          .whereType<Map>().where((p) => p['estado_pedido'] != 'Cancelado');
      if (pedidos.isEmpty) throw StateError('No hay pedidos habilitados');
      final form = await AdminMobileForm.open(context,
        title: 'Registrar pago o abono',
        fields: [
          AdminMobileField('id_pedido', 'Pedido', requiredValue: true,
            choices: [for (final p in pedidos)
              DropdownMenuItem(value: p['id_pedido'].toString(),
                child: Text('Pedido #' + p['id_pedido'].toString() +
                  ' · S/ ' + p['total'].toString(),
                    overflow: TextOverflow.ellipsis))]),
          AdminMobileField('monto', 'Monto en soles',
              requiredValue: true, numeric: true),
          AdminMobileField('metodo_pago', 'Método', requiredValue: true,
            choices: const [
              DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
              DropdownMenuItem(value: 'Yape', child: Text('Yape')),
              DropdownMenuItem(value: 'Plin', child: Text('Plin')),
              DropdownMenuItem(value: 'Transferencia',
                child: Text('Transferencia')),
            ]),
          AdminMobileField('estado_pago', 'Estado', requiredValue: true,
            choices: const [
              DropdownMenuItem(value: 'Pendiente', child: Text('Pendiente')),
              DropdownMenuItem(value: 'Pagado', child: Text('Pagado')),
              DropdownMenuItem(value: 'Rechazado', child: Text('Rechazado')),
            ]),
        ]);
      if (form == null || !mounted) return;
      if (!await confirmar('Confirma que verificaste el abono '
          'antes de marcarlo como Pagado. ¿Guardar?') || !mounted) return;
      await ejecutar({'accion': 'pago_manual', ...form});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))));
    }
  }

  Future<void> cambiarEstadoPago(Map<String, dynamic> pago) async {
    final opciones = ['Pendiente', 'Pagado', 'Rechazado']
        .where((v) => v != pago['estado_pago']).toList();
    final estado = await showDialog<String>(context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Estado del pago #' + pago['id_pago'].toString()),
        children: [
          for (final op in opciones) SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, op),
            child: Padding(padding: const EdgeInsets.all(10),
                child: Text(op))),
        ],
      ));
    if (estado == null || !mounted) return;
    if (!await confirmar(estado == 'Pagado'
        ? 'Confirma que recibiste realmente S/ ' +
          pago['monto'].toString() + ' y verificaste el pago.'
        : '¿Cambiar el pago a ' + estado + '?') || !mounted) return;
    await ejecutar({'accion': 'pago_estado', 'id_pago': pago['id_pago'],
       'estado_pago': estado});
  }

  Future<void> guardarCliente([Map<String, dynamic>? cliente]) async {
    final form = await AdminMobileForm.open(context,
      title: cliente == null ? 'Registrar cliente' : 'Editar cliente',
      initial: Map<String, dynamic>.from(cliente ?? {}),
      fields: [
        AdminMobileField('nombres', 'Nombres', requiredValue: true),
        AdminMobileField('apellidos', 'Apellidos'),
        AdminMobileField('correo', 'Correo', requiredValue: true),
        AdminMobileField('telefono', 'Teléfono'),
        AdminMobileField('contrasena', cliente == null
            ? (widget.modoLocal ? 'Contraseña local para la tienda (mínimo 8)'
                : 'Contraseña (mínimo 8)')
            : 'Nueva contraseña (dejar vacío para mantener)',
            requiredValue: cliente == null),
      ]);
    if (form != null && mounted) {
      await ejecutar({'accion': 'cliente_guardar',
        'id_usuario': cliente?['id_usuario'] ?? 0, ...form});
    }
  }

  Future<void> guardarPersonal([Map<String, dynamic>? empleado]) async {
    if (rol != 'Administrador' || widget.modoLocal) return;
    final form = await AdminMobileForm.open(context,
      title: empleado == null ? 'Crear cuenta de personal' : 'Editar empleado',
      initial: {
        ...?empleado,
        if (empleado == null) 'rol_sistema': 'Vendedor',
        if (empleado == null) 'estado': 'Activo',
      },
      fields: [
        AdminMobileField('nombres', 'Nombres', requiredValue: true),
        AdminMobileField('apellidos', 'Apellidos'),
        AdminMobileField('correo', 'Correo', requiredValue: true),
        AdminMobileField('telefono', 'Teléfono'),
        AdminMobileField('rol_sistema', 'Rol',
          requiredValue: true, choices: const [
            DropdownMenuItem(value: 'Administrador', child: Text('Administrador')),
            DropdownMenuItem(value: 'Vendedor', child: Text('Vendedor')),
            DropdownMenuItem(value: 'Almacen', child: Text('Almacén')),
          ]),
        AdminMobileField('estado', 'Estado', requiredValue: true,
          choices: const [
            DropdownMenuItem(value: 'Activo', child: Text('Activo')),
            DropdownMenuItem(value: 'Bloqueado', child: Text('Bloqueado')),
          ]),
        AdminMobileField('contrasena', empleado == null
            ? 'Contraseña (mínimo 8)' : 'Nueva contraseña (opcional)',
            requiredValue: empleado == null),
      ]);
    if (form != null && mounted) {
      if (empleado?['id_usuario'].toString() ==
          (await AdminMobileApi.sesion())?['id'] &&
          (form['rol_sistema'] != 'Administrador' ||
              form['estado'] != 'Activo')) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No puedes quitarte tu propio acceso')));
        return;
      }
      await ejecutar({'accion': 'personal_guardar',
          'id_usuario': empleado?['id_usuario'] ?? 0, ...form});
    }
  }

  Future<void> guardarDireccion([Map<String, dynamic>? direccion]) async {
    if (clienteDirecciones == null) return;
    final form = await AdminMobileForm.open(context,
      title: direccion == null ? 'Nueva dirección' : 'Editar dirección',
      initial: Map<String, dynamic>.from(direccion ?? {}),
      fields: [
        AdminMobileField('departamento', 'Departamento', requiredValue: true),
        AdminMobileField('provincia', 'Provincia', requiredValue: true),
        AdminMobileField('distrito', 'Distrito', requiredValue: true),
        AdminMobileField('direccion_detalle', 'Dirección completa',
            requiredValue: true),
        AdminMobileField('referencia', 'Referencia'),
      ]);
    if (form != null && mounted) {
      await ejecutar({'accion': 'direccion_guardar',
        'id_usuario': clienteDirecciones,
        'id_direccion': direccion?['id_direccion'] ?? 0, ...form});
    }
  }

  Future<void> eliminarDireccion(Map<String, dynamic> direccion) async {
    if (clienteDirecciones == null) return;
    if (await confirmar('¿Eliminar esta dirección? No se permitirá '
        'si está vinculada con una compra.') && mounted) {
      await ejecutar({'accion': 'direccion_eliminar',
        'id_direccion': direccion['id_direccion'],
        'id_usuario': clienteDirecciones});
    }
  }

  Future<void> guardarCatalogo(String tipo,
      [Map<String, dynamic>? actual]) async {
    final esCategoria = tipo == 'categoria';
    final idCampo = esCategoria ? 'id_categoria' : 'id_marca';
    final nombreCampo = esCategoria ? 'nombre_categoria' : 'nombre_marca';
    final valores = await AdminMobileForm.open(context,
      title: actual == null ? 'Agregar ' + tipo : 'Editar ' + tipo,
      fields: [AdminMobileField('nombre', 'Nombre',
          requiredValue: true)],
      initial: {'nombre': actual?[nombreCampo] ?? ''});
    if (valores != null && mounted) {
      await ejecutar({
        'accion': 'catalogo_guardar', 'tipo': tipo,
        'id': actual?[idCampo] ?? 0, ...valores,
      });
    }
  }

  Future<void> eliminarCatalogo(String tipo,
      Map<String, dynamic> actual) async {
    final idCampo = tipo == 'categoria' ? 'id_categoria' : 'id_marca';
    if (await confirmar('¿Eliminar este registro del catálogo? '
        'No se permitirá si tiene productos.') && mounted) {
      await ejecutar({'accion': 'catalogo_eliminar', 'tipo': tipo,
          'id': actual[idCampo]});
    }
  }

  Future<void> guardarProveedor([Map<String, dynamic>? actual]) async {
    final valores = await AdminMobileForm.open(context,
      title: actual == null ? 'Nuevo proveedor' : 'Editar proveedor',
      initial: Map<String, dynamic>.from(actual ?? {}),
      fields: [
        AdminMobileField('razon_social', 'Razón social', requiredValue: true),
        AdminMobileField('ruc', 'RUC'),
        AdminMobileField('telefono', 'Teléfono'),
        AdminMobileField('correo', 'Correo'),
        AdminMobileField('direccion', 'Dirección'),
        AdminMobileField('estado', 'Estado', choices: const [
          DropdownMenuItem(value: 'Activo', child: Text('Activo')),
          DropdownMenuItem(value: 'Inactivo', child: Text('Inactivo')),
        ]),
      ]);
    if (valores != null && mounted) {
      await ejecutar({'accion': 'proveedor_guardar',
        'id_proveedor': actual?['id_proveedor'] ?? 0, ...valores});
    }
  }

  Future<void> eliminarProveedor(Map<String, dynamic> actual) async {
    if (await confirmar('¿Eliminar proveedor? No se permitirá si '
        'existen compras vinculadas.') && mounted) {
      await ejecutar({'accion': 'proveedor_eliminar',
          'id_proveedor': actual['id_proveedor']});
    }
  }

  Future<void> cambiarEstadoCliente(Map<String, dynamic> actual) async {
    final nuevo = actual['estado'] == 'Activo' ? 'Bloqueado' : 'Activo';
    if (await confirmar('¿Cambiar cliente a ' + nuevo +
        (widget.modoLocal ? '? (Solo afecta este teléfono)' :
          '? Al bloquear se revocarán sus sesiones activas.')) && mounted) {
      await ejecutar({'accion': 'cliente_estado',
        'id_usuario': actual['id_usuario'], 'estado': nuevo});
    }
  }

  Future<void> moverInventario() async {
    try {
      final data = await consultar('productos');
      if (!mounted) return;
      final productos = ((data['items'] as List?) ?? const [])
          .whereType<Map>().toList();
      if (productos.isEmpty) {
        throw StateError('Primero registra productos');
      }
      final form = await AdminMobileForm.open(context,
        title: 'Movimiento de inventario',
        fields: [
          AdminMobileField('id_producto', 'Producto',
            requiredValue: true,
            choices: [
              for (final p in productos)
                DropdownMenuItem<String>(
                  value: p['id_producto'].toString(),
                  child: Text(p['nombre_producto'].toString() +
                      ' (stock ' + p['stock'].toString() + ')',
                      overflow: TextOverflow.ellipsis),
                ),
            ]),
          AdminMobileField('tipo', 'Tipo', requiredValue: true, choices: const [
            DropdownMenuItem(value: 'Entrada', child: Text('Entrada')),
            DropdownMenuItem(value: 'Salida', child: Text('Salida')),
          ]),
          AdminMobileField('cantidad', 'Cantidad',
              requiredValue: true, numeric: true),
          AdminMobileField('motivo', 'Motivo', requiredValue: true),
        ],
      );
      if (form == null || !mounted) return;
      if (!await confirmar(widget.modoLocal
          ? 'El stock y el Kardex se guardarán en SQLite de este teléfono.'
          : 'El stock y el Kardex se actualizarán en MySQL. '
            '¿Confirmas el movimiento?') || !mounted) return;
      await ejecutar({'accion': 'inventario_movimiento', ...form});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))));
    }
  }

  Future<void> guardarEmpresa() async {
    final config = datos['configuracion'] is Map
        ? Map<String, dynamic>.from(datos['configuracion'] as Map)
        : <String, dynamic>{};
    final initial = Map<String, dynamic>.from(config);
    initial['direccion_empresa'] = config['direccion'] ?? '';
    initial['telefono_empresa'] = config['telefono'] ?? '';
    initial['correo_empresa'] = config['correo'] ?? '';
    final form = await AdminMobileForm.open(context,
      title: 'Datos de la empresa',
      initial: initial,
      fields: [
        AdminMobileField('nombre_comercial', 'Nombre comercial',
            requiredValue: true),
        AdminMobileField('razon_social', 'Razón social',
            requiredValue: true),
        AdminMobileField('ruc', 'RUC'),
        AdminMobileField('direccion_empresa', 'Dirección'),
        AdminMobileField('telefono_empresa', 'Teléfono'),
        AdminMobileField('correo_empresa', 'Correo'),
        AdminMobileField('igv', 'IGV (%)', numeric: true, requiredValue: true),
        AdminMobileField('costo_delivery', 'Delivery (S/)',
            numeric: true, requiredValue: true),
        AdminMobileField('numero_yape', 'Número Yape'),
        AdminMobileField('numero_plin', 'Número Plin'),
        AdminMobileField('cuenta_transferencia', 'Cuenta bancaria'),
      ]);
    if (form != null && mounted) {
      await ejecutar({'accion': 'configuracion_guardar', ...form});
    }
  }

  Future<void> responderSoporte(Map<String, dynamic> actual) async {
    final form = await AdminMobileForm.open(context,
      title: 'Responder solicitud #' + actual['id_solicitud'].toString(),
      initial: {
        'estado_soporte': actual['estado'] ?? 'Abierto',
        'respuesta_soporte': actual['respuesta'] ?? '',
      },
      fields: [
        AdminMobileField('estado_soporte', 'Estado',
          requiredValue: true, choices: const [
            DropdownMenuItem(value: 'Abierto', child: Text('Abierto')),
            DropdownMenuItem(value: 'En proceso', child: Text('En proceso')),
            DropdownMenuItem(value: 'Respondido', child: Text('Respondido')),
          ]),
        AdminMobileField('respuesta_soporte', 'Respuesta al cliente',
            requiredValue: true),
      ]);
    if (form != null && mounted) {
      await ejecutar({'accion': 'soporte_responder',
          'id_solicitud': actual['id_solicitud'], ...form});
    }
  }


  Future<void> registrarCompra() async {
    try {
      final respuestas = await Future.wait([
        consultar('proveedores'),
        consultar('productos'),
      ]);
      if (!mounted) return;
      final proveedores = ((respuestas[0]['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['estado'] == 'Activo').toList();
      final productos = ((respuestas[1]['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e)).toList();
      if (proveedores.isEmpty || productos.isEmpty) {
        throw StateError('Necesitas proveedores activos y productos registrados.');
      }
      final form = await AdminMobilePurchaseForm.abrir(context,
        proveedores: proveedores, productos: productos);
      if (form == null || !mounted) return;
      if (!await confirmar('Registrar la compra aumentará el stock de '
          'todos los productos seleccionados. ¿Confirmas?') || !mounted) {
        return;
      }
      await ejecutar({'accion': 'compra_registrar', ...form});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))));
    }
  }

  Future<void> cambiarCompra(Map<String, dynamic> compra) async {
    final nuevo = compra['estado'] == 'Anulado' ? 'Registrado' : 'Anulado';
    final mensaje = nuevo == 'Anulado'
      ? 'Al anular esta compra se retirará el stock recibido. '
        'Si se vendió ese stock, la operación se rechazará.'
      : 'Al reactivar la compra se añadirá el stock nuevamente.';
    if (!await confirmar(mensaje) || !mounted) return;
    await ejecutar({'accion': 'compra_estado',
      'id_compra': compra['id_compra'], 'estado': nuevo});
  }

  Future<void> emitirComprobante() async {
    try {
      final resp = await consultar('pedidos');
      if (!mounted) return;
      final pedidos = ((resp['items'] as List?) ?? const [])
          .whereType<Map>().where((p) => p['estado_pedido'] != 'Cancelado')
          .toList();
      if (pedidos.isEmpty) {
        throw StateError('No hay pedidos disponibles para emitir comprobantes.');
      }
      final form = await AdminMobileForm.open(context,
        title: 'Emitir comprobante de demostración',
        fields: [
          AdminMobileField('id_pedido', 'Pedido', requiredValue: true,
            choices: [
              for (final p in pedidos) DropdownMenuItem<String>(
                value: p['id_pedido'].toString(),
                child: Text('Pedido #' + p['id_pedido'].toString() +
                    ' · S/ ' + p['total'].toString(),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          AdminMobileField('tipo_comprobante', 'Tipo',
            requiredValue: true, choices: const [
              DropdownMenuItem(value: 'Boleta', child: Text('Boleta')),
              DropdownMenuItem(value: 'Factura', child: Text('Factura')),
            ]),
        ]);
      if (form == null || !mounted) return;
      if (!await confirmar('La emisión requiere que el pedido esté '
          'completamente pagado. Es un documento de demostración, '
          'no un comprobante registrado ante SUNAT.') || !mounted) return;
      await ejecutar({'accion': 'comprobante_emitir', ...form});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))));
    }
  }

  Future<void> verComprobante(Map<String,dynamic> p) async {
    try {
      final respuesta = await consultar('configuracion');
      if (!mounted) return;
      final config = respuesta['configuracion'] is Map
          ? Map<String,dynamic>.from(respuesta['configuracion'] as Map)
          : <String,dynamic>{};
      final total=double.tryParse(p['total']?.toString()??'')??0;
      final tasa=double.tryParse(p['igv_porcentaje']?.toString()??
          config['igv']?.toString()??'18')??18;
      final subtotal=double.tryParse(p['subtotal']?.toString()??'')??
          double.parse((total/(1+tasa/100)).toStringAsFixed(2));
      final impuesto=double.tryParse(p['igv_monto']?.toString()??'')??
          double.parse((total-subtotal).toStringAsFixed(2));
      if (!mounted) return;
      await showDialog<void>(context:context,
        builder:(ctx)=>AlertDialog(
          title:const Text('Comprobante de demostración'),
          content:SingleChildScrollView(child:Column(
            mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.stretch,
            children:[
              const Text('SIN VALIDEZ SUNAT',
                textAlign:TextAlign.center,
                style:TextStyle(fontWeight:FontWeight.w900,
                    color:Color(0xFF98462B))),
              const SizedBox(height:12),
              Text(config['nombre_comercial']?.toString()??'Dorada Motors',
                textAlign:TextAlign.center,
                style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
              Text(config['razon_social']?.toString()??'',
                textAlign:TextAlign.center),
              const Divider(),
              Text(p['tipo_comprobante'].toString()+' '+
                  p['numero_comprobante'].toString(),
                style:const TextStyle(fontWeight:FontWeight.bold)),
              Text('Pedido #'+p['id_pedido'].toString()),
              Text('Cliente: '+(p['nombres']??'').toString()+' '+
                  (p['apellidos']??'').toString()),
              Text('Fecha: '+(p['fecha_emision']??'').toString()),
              const Divider(),
              Text('Subtotal: S/ '+subtotal.toStringAsFixed(2)),
              Text('IGV de referencia ('+tasa.toStringAsFixed(0)+'%): S/ '+
                  impuesto.toStringAsFixed(2)),
              const SizedBox(height:5),
              Text('TOTAL: S/ '+total.toStringAsFixed(2),
                style:const TextStyle(fontSize:18,
                    fontWeight:FontWeight.bold)),
              const SizedBox(height:12),
              const Text('Documento académico de prueba, sin emisión '
                  'electrónica registrada en SUNAT.',
                style:TextStyle(fontSize:12)),
            ],
          )),
          actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),
            child:const Text('Cerrar'))],
        ));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(error.toString())));
    }
  }

  Future<void> cancelarPedido(Map<String, dynamic> pedido) async {
    if (!await confirmar('Cancelar pedido #' +
      pedido['id_pedido'].toString() +
      ' devolverá el stock. No se permite cancelar si hubo dinero '
      'confirmado o ya fue enviado.') || !mounted) return;
    await ejecutar({'accion': 'pedido_cancelar',
        'id_pedido': pedido['id_pedido']});
  }

  Widget botonAgregar(String texto, VoidCallback alPulsar) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Align(alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        onPressed: guardando ? null : alPulsar,
        icon: const Icon(Icons.add),
        label: Text(texto),
      ),
    ),
  );

  String titulo(String v) => switch (v) {
    'resumen' => 'Dashboard', 'productos' => 'Productos',
    'pedidos' => 'Pedidos', 'pagos' => 'Pagos',
    'inventario' => 'Inventario', 'clientes' => 'Clientes',
    'proveedores' => 'Proveedores', 'reportes' => 'Reportes',
    'categorias' => 'Categorías', 'marcas' => 'Marcas',
    'compras' => 'Compras', 'comprobantes' => 'Comprobantes',
    'soporte' => 'Soporte', 'configuracion' => 'Configuración',
    'personal' => 'Personal', 'direcciones' => 'Direcciones',
    _ => 'Más módulos',
  };

  @override
  Widget build(BuildContext context) {
    final menu = secciones;
    final seleccion = menu.contains(vista) ? vista : 'mas';
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo(vista) +
          (widget.modoLocal ? ' · SQLite local' : ' · ' + rol)),
        actions: [
          IconButton(tooltip: 'Actualizar', onPressed: cargando ? null : cargar,
              icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Cerrar sesión', onPressed: salir,
              icon: const Icon(Icons.logout)),
        ]),
      body: Column(children: [
        if (widget.modoLocal) Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          color: const Color(0xFFFFF1D5),
          child: const Text('SIN LAPTOP · SQLite en este celular. '
            'No se ha enviado información a MySQL.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        if (guardando) const LinearProgressIndicator(minHeight: 2),
        if (vista != 'resumen') Align(alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: guardando ? null : () =>
                navegar(secciones.contains(vista) ? 'resumen' : 'mas'),
            icon: const Icon(Icons.arrow_back),
            label: Text(secciones.contains(vista)
                ? 'Volver al inicio' : 'Volver a opciones'))),
        Expanded(child: cargando ? const Center(
          child: CircularProgressIndicator()) : error != null
          ? Center(child: SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off, size: 50, color: AppColors.muted),
                const SizedBox(height: 12),
                Text(widget.modoLocal
                  ? 'No se pudo leer la base SQLite'
                  : 'No se puede consultar la base de datos',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                if (!widget.modoLocal) Text(ApiService.baseUrl,
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                if (!widget.modoLocal) const Text(
                    'Enciende XAMPP y usa la misma red Wi-Fi. '
                    'Los cambios administrativos necesitan conexión al servidor.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 15),
                FilledButton(onPressed: cargar,
                    child: const Text('Reintentar')),
                TextButton(onPressed: salir,
                    child: const Text('Cerrar sesión')),
              ]),
            )) : RefreshIndicator(onRefresh: cargar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 36),
                children: contenido(),
              ))),
      ]),
      floatingActionButton: vista == 'productos' &&
              error == null && !cargando
          ? FloatingActionButton.extended(
              onPressed: guardando ? null : () => editarProducto(),
              icon: const Icon(Icons.add), label: const Text('Producto'))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: menu.indexOf(seleccion),
        onDestinationSelected: guardando ? null : (i) => navegar(menu[i]),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard_outlined),
              label: 'Inicio'),
          if (permitido('productos')) const NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined), label: 'Productos'),
          if (permitido('pedidos')) const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: 'Pedidos'),
          if (permitido('pagos')) const NavigationDestination(
              icon: Icon(Icons.payments_outlined), label: 'Pagos'),
          const NavigationDestination(icon: Icon(Icons.apps_outlined),
              label: 'Más'),
        ]),
    );
  }

  List<Map<String, dynamic>> get items =>
      ((datos['items'] as List?) ?? const []).whereType<Map>()
          .map((x) => Map<String, dynamic>.from(x)).toList();

  Widget encabezado(String heading, String detalle) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(heading, style: const TextStyle(fontSize: 21,
          fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text(detalle, style: const TextStyle(color: AppColors.muted)),
    ]));

  Widget graficaVentas(List<Map<String,dynamic>> puntos) {
    if (puntos.isEmpty) return const SizedBox.shrink();
    final importes=puntos.map((p)=>double.tryParse(
      p['ventas']?.toString()??'')??0.0).toList();
    final maximo=importes.fold<double>(1,(a,b)=>b>a?b:a);
    return Card(child:Padding(padding:const EdgeInsets.all(12),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Ventas por día (S/)',
          style:TextStyle(fontWeight:FontWeight.w800)),
        const SizedBox(height:10),
        SizedBox(height:148,child:ListView(
          scrollDirection:Axis.horizontal,children:[
          for(var i=0;i<puntos.length;i++)
            Padding(padding:const EdgeInsets.only(right:12),
              child:SizedBox(width:64,child:Column(
                mainAxisAlignment:MainAxisAlignment.end,children:[
                  Text('S/ '+importes[i].toStringAsFixed(0),
                    style:const TextStyle(fontSize:11),
                    maxLines:1,overflow:TextOverflow.ellipsis),
                  const SizedBox(height:4),
                  Container(width:34,
                    height:82.0*(importes[i]/maximo).clamp(0.04,1.0).toDouble(),
                    decoration:BoxDecoration(
                      color:AppColors.goldDark,
                      borderRadius:const BorderRadius.vertical(
                        top:Radius.circular(5)))),
                  const SizedBox(height:5),
                  Text(puntos[i]['fecha'].toString().length>=10
                    ? puntos[i]['fecha'].toString().substring(5,10)
                    : puntos[i]['fecha'].toString(),
                    style:const TextStyle(fontSize:11)),
                ]))),
        ])),
      ])));
  }

  Widget registro(String heading, String detalle, IconData icon,
      {String? cifra, Widget? accion}) => Card(
    child: Padding(padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, color: AppColors.goldDark),
          const SizedBox(width: 8),
          Expanded(child: Text(heading,
              style: const TextStyle(fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 7),
        Text(detalle, style: const TextStyle(fontSize: 12)),
        if (cifra != null || accion != null)
          Row(children: [
            if (cifra != null) Expanded(child: Text(cifra,
                style: const TextStyle(fontWeight: FontWeight.bold))),
            if (accion != null) accion,
          ]),
      ])));

  Widget metrica(String heading, Object? valor, IconData icon) => SizedBox(
    width: 156, height: 113,
    child: Card(child: Padding(padding: const EdgeInsets.all(11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.goldDark),
        const Spacer(),
        Text((valor ?? 0).toString(), maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(heading, style: const TextStyle(
          color: AppColors.muted, fontSize: 12)),
      ]))));

  Widget modulo(String nombre, String detalle, IconData icon,
      String destino) => Card(child: ListTile(
        leading: Icon(icon, color: AppColors.goldDark),
        title: Text(nombre), subtitle: Text(detalle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => navegar(destino)));

  List<Widget> contenido() {
    if (vista == 'mas') return [
      encabezado('Opciones de administrador',
          widget.modoLocal
            ? 'Los módulos guardan sus datos exclusivamente en SQLite.'
            : 'Módulos conectados a la misma base de datos de PHP.'),
      if (permitido('productos')) modulo('Categorías',
          'Agregar, editar o eliminar', Icons.category_outlined, 'categorias'),
      if (permitido('productos')) modulo('Marcas',
          'Agregar, editar o eliminar', Icons.sell_outlined, 'marcas'),
      if (permitido('clientes')) modulo('Clientes',
          'Cuentas y estados', Icons.people_outline, 'clientes'),
      if (!widget.modoLocal && permitido('clientes')) modulo('Soporte',
          'Consultas de clientes', Icons.support_agent_outlined, 'soporte'),
      if (permitido('inventario')) modulo('Kardex',
          'Movimientos de stock', Icons.warehouse_outlined, 'inventario'),
      if (permitido('inventario')) modulo('Compras',
          'Historial de proveedores', Icons.shopping_cart_outlined, 'compras'),
      if (permitido('proveedores')) modulo('Proveedores',
          'Gestionar proveedores', Icons.local_shipping_outlined, 'proveedores'),
      if (permitido('pagos')) modulo('Comprobantes',
          'Boletas y facturas de demostración',
          Icons.description_outlined, 'comprobantes'),
      if (permitido('reportes')) modulo('Reportes',
          'Ventas y más vendidos', Icons.bar_chart, 'reportes'),
      if (!widget.modoLocal && rol == 'Administrador') modulo('Personal',
          'Cuentas, roles y permisos', Icons.manage_accounts_outlined,
          'personal'),
      if (rol == 'Administrador') modulo('Configuración',
          'Datos de empresa y delivery', Icons.settings_outlined,
          'configuracion'),
    ];
    if (vista == 'resumen') {
      final r = datos['resumen'] is Map
        ? Map<String, dynamic>.from(datos['resumen'] as Map)
        : <String, dynamic>{};
      final ultimos = ((datos['ultimos_pedidos'] as List?) ?? const [])
          .whereType<Map>();
      return [
        encabezado('Bienvenido, ' + nombre,
            widget.modoLocal
              ? 'Información persistente en la base SQLite de este Samsung.'
              : 'Información compartida con el dashboard PHP.'),
        Wrap(spacing: 7, runSpacing: 7, children: [
          metrica('Productos', r['productos'], Icons.inventory_2_outlined),
          metrica('Clientes', r['clientes'], Icons.people_outline),
          metrica('Pedidos', r['pedidos'], Icons.receipt_long_outlined),
          metrica('Pendientes', r['pendientes'], Icons.pending_outlined),
          metrica('Stock bajo', r['stock_bajo'], Icons.warning_amber),
          metrica('Ventas S/', r['ventas'], Icons.trending_up),
          metrica('Cobrado S/', r['cobrado'], Icons.payments_outlined),
        ]),
        const SizedBox(height: 19),
        encabezado('Últimos pedidos',
          widget.modoLocal ? 'Ventas registradas en este teléfono.'
              : 'Registros nuevos de MySQL.'),
        for (final p in ultimos) registro('Pedido #' +
            p['id_pedido'].toString(), p['nombres'].toString() + ' ' +
            p['apellidos'].toString() + ' · ' +
            p['estado_pedido'].toString(), Icons.receipt_long_outlined,
            cifra: 'S/ ' + p['total'].toString()),
        if (ultimos.isEmpty) const Text('Sin pedidos.'),
      ];
    }
    if (vista == 'productos') return [
      encabezado('Catálogo de productos',
          'Agrega artículos o edita precios, fotos y stock.'),
      for (final p in items) Card(child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          SizedBox(width: 75, height: 75, child:
            widget.modoLocal && !kIsWeb &&
              (p['imagen_url']?.toString() ?? '').startsWith('/')
            ? Image.file(File(p['imagen_url'].toString()),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported))
            : ProductImage(
                source: ProductImageUrl.resolver(
                  p['imagen_url']?.toString(), ApiService.baseUrl))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p['nombre_producto']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(p['nombre_marca'].toString() + ' · ' +
                  p['nombre_categoria'].toString(),
                  style: const TextStyle(fontSize: 12)),
              Text('S/ ' + p['precio'].toString() +
                  ' · Stock: ' + p['stock'].toString()),
              Align(alignment: Alignment.centerRight,
                child: Wrap(spacing: 4, children: [
                  TextButton.icon(
                    onPressed: guardando ? null : () => editarProducto(p),
                    icon: const Icon(Icons.edit, size: 17),
                    label: const Text('Editar')),
                  if (widget.modoLocal) TextButton.icon(
                    onPressed: guardando ? null : () async {
                      if (await confirmar('¿Archivar este producto local? '
                          'Conservará su historial de movimientos.') && mounted) {
                        await ejecutar({'accion': 'producto_archivar',
                            'id_producto': p['id_producto']});
                      }
                    },
                    icon: const Icon(Icons.archive_outlined, size: 17),
                    label: const Text('Archivar')),
                ])),
            ])),
        ]),
      )),
      if (items.isEmpty) const Text('No hay productos.'),
    ];
    if (vista == 'pedidos') return [
      encabezado('Pedidos', 'Registra ventas, revisa detalles y estados.'),
      botonAgregar('Registrar venta', registrarVenta),
      for (final p in items) registro(
        'Pedido #' + p['id_pedido'].toString(),
        p['nombres'].toString() + ' ' + p['apellidos'].toString() +
        '\n' + p['estado_pedido'].toString() + ' · ' +
        p['fecha_pedido'].toString(),
        Icons.receipt_long_outlined,
        cifra: 'S/ ' + p['total'].toString(),
        accion: Wrap(spacing: 4, children: [
          TextButton(onPressed: guardando ? null : () => verDetallePedido(p),
            child: const Text('Detalle')),
          if (['Pendiente', 'Pagado', 'Procesando'].contains(
              p['estado_pedido']?.toString()))
            TextButton(
              onPressed: guardando ? null : () => cancelarPedido(p),
              child: const Text('Cancelar')),
          if (['Pendiente', 'Pagado', 'Procesando', 'Enviado']
              .contains(p['estado_pedido']?.toString()))
            TextButton(
              onPressed: guardando ? null : () => cambiarEstado(p),
              child: const Text('Estado')),
        ])),
      if (items.isEmpty) const Text('No hay pedidos.'),
    ];
    if (vista == 'pagos') return [
      encabezado('Pagos', 'Registrar abonos y verificar los estados de cobro.'),
      botonAgregar('Registrar pago o abono', registrarAbono),
      for (final p in items) registro(
        'Pago #' + p['id_pago'].toString() +
        ' · Pedido #' + p['id_pedido'].toString(),
        p['metodo_pago'].toString() + ' · ' + p['estado_pago'].toString() +
        '\n' + p['nombres'].toString() + ' ' + p['apellidos'].toString(),
        Icons.payments_outlined, cifra: 'S/ ' + p['monto'].toString(),
        accion: TextButton(
          onPressed: guardando ? null : () => cambiarEstadoPago(p),
          child: const Text('Cambiar estado'))),
      if (items.isEmpty) const Text('No hay pagos.'),
    ];
    if (vista == 'categorias' || vista == 'marcas') {
      final tipo = vista == 'categorias' ? 'categoria' : 'marca';
      final nombreCampo = tipo == 'categoria'
          ? 'nombre_categoria' : 'nombre_marca';
      final idCampo = tipo == 'categoria' ? 'id_categoria' : 'id_marca';
      return [
        encabezado(titulo(vista), 'Registros disponibles para los productos.'),
        botonAgregar('Agregar ' + tipo,
            () => guardarCatalogo(tipo)),
        for (final item in items) Card(child: ListTile(
          title: Text(item[nombreCampo]?.toString() ?? ''),
          subtitle: Text('Código ' + item[idCampo].toString()),
          trailing: Wrap(spacing: 4, children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: guardando ? null : () => guardarCatalogo(tipo, item)),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar',
              onPressed: guardando ? null : () => eliminarCatalogo(tipo, item)),
          ]),
        )),
        if (items.isEmpty) const Text('No hay registros.'),
      ];
    }
    if (vista == 'clientes') return [
      encabezado('Clientes', widget.modoLocal
          ? 'Clientes locales de este celular, sin cuenta PHP/MySQL.'
          : 'Registra, edita, bloquea y revisa direcciones.'),
      botonAgregar('Registrar cliente', () => guardarCliente()),
      for (final p in items) registro(
        p['nombres'].toString() + ' ' + p['apellidos'].toString(),
        p['correo'].toString() + '\n' +
        (p['telefono']?.toString() ?? '') + ' · ' + p['estado'].toString(),
        Icons.person_outline, cifra: 'ID ' + p['id_usuario'].toString(),
        accion: PopupMenuButton<String>(
          tooltip: 'Acciones del cliente',
          onSelected: (opcion) {
            if (opcion == 'editar') {
              guardarCliente(p);
            } else if (opcion == 'direcciones') {
              abrirDirecciones(p);
            } else if (opcion == 'estado') {
              cambiarEstadoCliente(p);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'editar', child: Text('Editar datos')),
            const PopupMenuItem(value: 'direcciones', child: Text('Direcciones')),
            PopupMenuItem(value: 'estado',
                child: Text(p['estado'] == 'Activo' ? 'Bloquear' : 'Activar')),
          ],
          icon: const Icon(Icons.more_vert),
        )),
      if (items.isEmpty) const Text('No hay clientes.'),
    ];
    if (vista == 'direcciones') return [
      encabezado('Direcciones del cliente',
          'Registra y actualiza direcciones de entrega.'),
      botonAgregar('Nueva dirección', () => guardarDireccion()),
      for (final p in items) Card(child: ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: Text(p['direccion_detalle']?.toString() ?? ''),
        subtitle: Text(
          p['distrito'].toString() + ', ' +
          p['provincia'].toString() + ', ' +
          p['departamento'].toString() +
          '\n' + (p['referencia']?.toString() ?? '')),
        trailing: PopupMenuButton<String>(
          onSelected: (opcion) {
            if (opcion == 'editar') guardarDireccion(p);
            if (opcion == 'eliminar') eliminarDireccion(p);
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'editar', child: Text('Editar')),
            PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
          ],
        ),
      )),
      if (items.isEmpty) const Text('El cliente no tiene direcciones.'),
    ];
    if (vista == 'personal') return [
      encabezado('Personal administrativo',
          'Gestiona roles y accesos de empleados desde el celular.'),
      botonAgregar('Crear empleado', () => guardarPersonal()),
      for (final p in items) registro(
        p['nombres'].toString() + ' ' + p['apellidos'].toString(),
        p['correo'].toString() + '\n' +
        p['rol_sistema'].toString() + ' · ' + p['estado'].toString(),
        Icons.manage_accounts_outlined,
        accion: TextButton.icon(
          onPressed: guardando ? null : () => guardarPersonal(p),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar')),
      ),
      if (items.isEmpty) const Text('No hay personal administrativo.'),
    ];
    if (vista == 'inventario') return [
      encabezado('Kardex', 'Stock anterior, stock nuevo y motivo del cambio.'),
      botonAgregar('Registrar entrada o salida', moverInventario),
      for (final p in items) registro(
        p['nombre_producto'].toString(),
        p['tipo_movimiento'].toString() + ' · ' +
        (p['motivo']?.toString() ?? '') + '\n' +
        p['fecha_movimiento'].toString(),
        Icons.compare_arrows,
        cifra: p['stock_anterior'].toString() + ' → ' +
            p['stock_nuevo'].toString()),
      if (items.isEmpty) const Text('Sin movimientos.'),
    ];
    if (vista == 'proveedores') return [
      encabezado('Proveedores', widget.modoLocal
          ? 'Proveedores guardados en este teléfono.'
          : 'Registrar o actualizar datos de MySQL.'),
      botonAgregar('Nuevo proveedor', () => guardarProveedor()),
      for (final p in items) Card(child: Column(children: [
        ListTile(
          title: Text(p['razon_social']?.toString() ?? ''),
          subtitle: Text((p['ruc']?.toString() ?? '') + ' · ' +
            (p['telefono']?.toString() ?? '') + '\n' +
            (p['correo']?.toString() ?? '') + ' · ' +
            p['estado'].toString()),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton.icon(
            icon: const Icon(Icons.edit_outlined),
            onPressed: guardando ? null : () => guardarProveedor(p),
            label: const Text('Editar')),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline),
            onPressed: guardando ? null : () => eliminarProveedor(p),
            label: const Text('Eliminar')),
        ]),
      ])),
      if (items.isEmpty) const Text('No hay proveedores.'),
    ];
    if (vista == 'compras') return [
      encabezado('Compras a proveedores', widget.modoLocal
          ? 'Compras y existencias guardadas en la base SQLite.'
          : 'Registra compras y gestiona el stock con transacciones MySQL.'),
      botonAgregar('Registrar compra', registrarCompra),
      for (final p in items) registro(
        'Compra #' + p['id_compra'].toString() +
        ' · ' + p['razon_social'].toString(),
        p['estado'].toString() + ' · ' + p['fecha_compra'].toString(),
        Icons.shopping_cart_outlined, cifra: 'S/ ' + p['total'].toString(),
        accion: TextButton(
          onPressed: guardando ? null : () => cambiarCompra(p),
          child: Text(p['estado'] == 'Anulado' ?
              'Reactivar' : 'Anular'))),
      if (items.isEmpty) const Text('Aún no hay compras.'),
    ];
    if (vista == 'comprobantes') return [
      encabezado('Comprobantes',
          'Boletas y facturas de demostración. No equivale a SUNAT.'),
      botonAgregar('Emitir comprobante', emitirComprobante),
      for (final p in items) registro(
        p['tipo_comprobante'].toString() +
        ' ' + p['numero_comprobante'].toString(),
        'Pedido #' + p['id_pedido'].toString() + ' · ' +
        p['nombres'].toString() + ' ' + p['apellidos'].toString() +
        '\n' + p['fecha_emision'].toString(),
        Icons.description_outlined, cifra: 'S/ ' + p['total'].toString(),
        accion:TextButton.icon(
          onPressed:guardando?null:()=>verComprobante(p),
          icon:const Icon(Icons.visibility_outlined,size:17),
          label:const Text('Ver'))),
      if (items.isEmpty) const Text('No hay comprobantes.'),
    ];
    if (vista == 'soporte') return [
      encabezado('Atención al cliente',
          'Responde las consultas recibidas desde la aplicación móvil.'),
      for (final p in items) registro(
        'Solicitud #' + p['id_solicitud'].toString() +
        ' · ' + p['asunto'].toString(),
        p['nombres'].toString() + ' ' + p['apellidos'].toString() +
        '\n' + p['mensaje'].toString() +
        '\nEstado: ' + p['estado'].toString() +
        '\nRespuesta: ' + (p['respuesta']?.toString() ?? 'Pendiente'),
        Icons.support_agent_outlined,
        accion: TextButton(
          onPressed: guardando ? null : () => responderSoporte(p),
          child: const Text('Responder'))),
      if (items.isEmpty) const Text('No hay consultas.'),
    ];
    if (vista == 'configuracion') {
      final d = datos['configuracion'] is Map
        ? Map<String, dynamic>.from(datos['configuracion'] as Map)
        : <String, dynamic>{};
      return [
        encabezado('Configuración de la empresa',
            widget.modoLocal
              ? 'Estos valores afectan únicamente las ventas locales.'
              : 'Los valores se usan también en el checkout del cliente.'),
        registro(d['nombre_comercial']?.toString() ?? 'Dorada Motors',
            'Razón social: ' + (d['razon_social']?.toString() ?? '') +
            '\nIGV: ' + (d['igv']?.toString() ?? '-') + '%' +
            ' · Delivery: S/ ' + (d['costo_delivery']?.toString() ?? '-'),
            Icons.store_outlined),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: guardando ? null : guardarEmpresa,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar datos de la empresa')),
      ];
    }
    if (vista == 'reportes') {
      final diario = ((datos['diario'] as List?) ?? const []).whereType<Map>();
      final top = ((datos['top'] as List?) ?? const []).whereType<Map>();
      return [
        encabezado('Ventas', 'Pedidos no cancelados de esta base de datos.'),
        if (diario.isNotEmpty) graficaVentas(
          diario.map((p)=>Map<String,dynamic>.from(p)).toList()),
        for (final p in diario) registro(p['fecha'].toString(),
            p['pedidos'].toString() + ' pedidos', Icons.calendar_month,
            cifra: 'S/ ' + p['ventas'].toString()),
        if (diario.isEmpty) const Text('Sin ventas recientes.'),
        const SizedBox(height: 18),
        encabezado('Productos más vendidos', 'Cantidad e importe.'),
        for (final p in top) registro(p['nombre_producto'].toString(),
            p['cantidad'].toString() + ' unidades', Icons.trending_up,
            cifra: 'S/ ' + p['importe'].toString()),
        if (top.isEmpty) const Text('No hay ventas de productos.'),
      ];
    }
    return [const Text('Sección no disponible')];
  }
}

class _ProductoEditor extends StatefulWidget {
  final Map<String, dynamic>? producto;
  final List<Map<String, dynamic>> categorias, marcas;
  final bool modoLocal;
  const _ProductoEditor({required this.producto,
      required this.categorias, required this.marcas,
      this.modoLocal = false});
  @override
  State<_ProductoEditor> createState() => _ProductoEditorState();
}

class _ProductoEditorState extends State<_ProductoEditor> {
  final form = GlobalKey<FormState>();
  late final Map<String, dynamic> valores;
  XFile? fotoNueva;
  Uint8List? imagenPrevia;
  bool subiendo = false;

  Future<void> elegirFoto() async {
    try {
      final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        imageQuality: 83,
      );
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      if (bytes.length > 3 * 1024 * 1024) {
        throw StateError('La foto debe ser menor de 3 MB');
      }
      if (!mounted) return;
      setState(() { fotoNueva = archivo; imagenPrevia = bytes; });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    }
  }

  Future<void> guardarProducto() async {
    if (subiendo || !(form.currentState?.validate() ?? false)) return;
    setState(() => subiendo = true);
    try {
      if (fotoNueva != null) {
        valores['imagen_url'] = widget.modoLocal
            ? await AdminOfflineRepository.guardarFoto(fotoNueva!)
            : await AdminMobileApi.subirFotografia(fotoNueva!);
      }
      if (!mounted) return;
      Navigator.of(context).pop(valores);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    } finally {
      if (mounted) setState(() => subiendo = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final p = widget.producto ?? {};
    valores = {
      'id_producto': p['id_producto'] ?? 0,
      'nombre_producto': p['nombre_producto'] ?? '',
      'descripcion': p['descripcion'] ?? '',
      'precio': p['precio']?.toString() ?? '',
      'precio_oferta': p['precio_oferta']?.toString() ?? '',
      'stock': p['stock']?.toString() ?? '0',
      'stock_minimo': p['stock_minimo']?.toString() ?? '5',
      'id_categoria': p['id_categoria']?.toString() ??
          widget.categorias.first['id_categoria'].toString(),
      'id_marca': p['id_marca']?.toString() ??
          widget.marcas.first['id_marca'].toString(),
      'tipo_vehiculo': p['tipo_vehiculo'] ?? 'Motocicleta / Motokar',
      'compatibilidad': p['compatibilidad'] ?? '',
      'imagen_url': p['imagen_url'] ?? '',
    };
  }

  Widget campo(String label, String key, {bool numero = false,
      bool requerido = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      initialValue: valores[key]?.toString() ?? '',
      decoration: InputDecoration(labelText: label),
      keyboardType: numero ? const TextInputType.numberWithOptions(
          decimal: true) : TextInputType.text,
      onChanged: (valor) => valores[key] = valor,
      validator: (v) {
        final str = (v ?? '').trim();
        if (requerido && str.isEmpty) return 'Obligatorio';
        if (numero && str.isNotEmpty &&
            (double.tryParse(str) == null || double.parse(str) < 0)) {
          return 'Ingrese un número válido';
        }
        if ((key == 'stock' || key == 'stock_minimo') &&
            int.tryParse(str) == null) {
          return 'Ingrese unidades enteras';
        }
        if (key == 'precio' && (double.tryParse(str) ?? 0) <= 0) {
          return 'Precio debe ser mayor a cero';
        }
        return null;
      },
    ));

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 690, maxWidth: 500),
      child: Padding(padding: const EdgeInsets.all(16),
        child: Form(key: form, child: Column(children: [
          Row(children: [
            Expanded(child: Text(widget.producto == null ?
                'Agregar producto' : 'Editar producto',
                style: const TextStyle(fontSize: 20,
                    fontWeight: FontWeight.bold))),
            IconButton(onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ]),
          Expanded(child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                campo('Nombre', 'nombre_producto', requerido: true),
                DropdownButtonFormField<String>(
                  initialValue: valores['id_categoria'].toString(),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    for (final c in widget.categorias)
                      DropdownMenuItem(
                        value: c['id_categoria'].toString(),
                        child: Text(c['nombre_categoria'].toString())),
                  ],
                  onChanged: (v) => valores['id_categoria'] = v),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: valores['id_marca'].toString(),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Marca'),
                  items: [
                    for (final m in widget.marcas)
                      DropdownMenuItem(
                        value: m['id_marca'].toString(),
                        child: Text(m['nombre_marca'].toString())),
                  ],
                  onChanged: (v) => valores['id_marca'] = v),
                const SizedBox(height: 12),
                campo('Precio S/', 'precio', numero: true, requerido: true),
                campo('Precio oferta (opcional)', 'precio_oferta',
                    numero: true),
                campo('Stock', 'stock', numero: true),
                campo('Stock mínimo', 'stock_minimo', numero: true),
                campo('Descripción', 'descripcion'),
                campo('Tipo de vehículo', 'tipo_vehiculo'),
                campo('Compatibilidad', 'compatibilidad'),
                const SizedBox(height: 8),
                if (imagenPrevia != null) ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(imagenPrevia!,
                    height: 148, fit: BoxFit.contain),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: subiendo ? null : elegirFoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(fotoNueva == null
                    ? 'Elegir fotografía de la galería'
                    : 'Cambiar fotografía seleccionada'),
                ),
                const SizedBox(height: 10),
                campo('Ruta de imagen existente (opcional)', 'imagen_url'),
              ]))),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
              child: FilledButton.icon(
                onPressed: subiendo ? null : guardarProducto,
                icon: const Icon(Icons.save_outlined),
                label: Text(subiendo ? 'Guardando foto...'
                  : (widget.modoLocal ? 'Guardar en el celular'
                  : 'Guardar en MySQL')))),
        ])),
      ),
    ));
}
