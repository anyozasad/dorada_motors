// ignore_for_file: prefer_interpolation_to_compose_strings, curly_braces_in_flow_control_structures, use_null_aware_elements
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/local_store.dart';
import '../services/product_image_url.dart';
import '../theme/app_theme.dart';
import '../widgets/product_image.dart';
import 'admin_mobile_forms.dart';

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

  static Future<Map<String, dynamic>> consultar(String vista) =>
      _request('GET', vista, null, false);

  static Future<Map<String, dynamic>> operar(Map<String, dynamic> data) =>
      _request('POST', '', data, false);

  static Future<Map<String, dynamic>> _request(String method, String view,
      Map<String, dynamic>? data, bool login) async {
    final p = await SharedPreferences.getInstance();
    final token = login ? '' : p.getString(keyToken) ?? '';
    final uri = Uri.parse(ApiService.baseUrl + '/admin_movil.php')
        .replace(queryParameters: method == 'GET' ? {'vista': view} : null);
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
  const AdminMobileDashboardScreen({super.key, required this.onLogout});
  @override
  State<AdminMobileDashboardScreen> createState() =>
      _AdminMobileDashboardScreenState();
}

class _AdminMobileDashboardScreenState
    extends State<AdminMobileDashboardScreen> {
  String rol = '';
  String nombre = '';
  String vista = 'resumen';
  Map<String, dynamic> datos = {};
  bool cargando = true;
  bool guardando = false;
  String? error;

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
    final s = await AdminMobileApi.sesion();
    if (!mounted) return;
    setState(() {
      rol = s?['rol'] ?? '';
      nombre = s?['nombre'] ?? 'Administración';
    });
    await cargar();
  }

  Future<void> cargar() async {
    if (!mounted) return;
    if (vista == 'mas') {
      setState(() { cargando = false; error = null; });
      return;
    }
    setState(() { cargando = true; error = null; });
    try {
      final r = await AdminMobileApi.consultar(vista);
      if (!mounted) return;
      setState(() { datos = r; cargando = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        cargando = false;
        error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  void navegar(String destino) {
    setState(() { vista = destino; datos = {}; error = null; });
    cargar();
  }

  Future<void> salir() async {
    await AdminMobileApi.salir();
    if (mounted) widget.onLogout();
  }

  Future<void> ejecutar(Map<String, dynamic> args) async {
    if (guardando) return;
    setState(() => guardando = true);
    try {
      final r = await AdminMobileApi.operar(args);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r['mensaje']?.toString() ??
              'Actualizado en MySQL')));
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
      final data = await AdminMobileApi.consultar('catalogos');
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
            categorias: categorias, marcas: marcas));
      if (valores != null && mounted) {
        await ejecutar({'accion': 'producto_guardar', ...valores});
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))));
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
        '? Al bloquear se revocarán sus sesiones activas.') && mounted) {
      await ejecutar({'accion': 'cliente_estado',
        'id_usuario': actual['id_usuario'], 'estado': nuevo});
    }
  }

  Future<void> moverInventario() async {
    try {
      final data = await AdminMobileApi.consultar('productos');
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
      if (!await confirmar('El stock y el Kardex se actualizarán en MySQL. '
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
    _ => 'Más módulos',
  };

  @override
  Widget build(BuildContext context) {
    final menu = secciones;
    final seleccion = menu.contains(vista) ? vista : 'mas';
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo(vista) + ' · ' + rol),
        actions: [
          IconButton(tooltip: 'Actualizar', onPressed: cargando ? null : cargar,
              icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Cerrar sesión', onPressed: salir,
              icon: const Icon(Icons.logout)),
        ]),
      body: Column(children: [
        if (guardando) const LinearProgressIndicator(minHeight: 2),
        if (vista != 'resumen') Align(alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => navegar('resumen'),
            icon: const Icon(Icons.arrow_back), label: const Text('Inicio'))),
        Expanded(child: cargando ? const Center(
          child: CircularProgressIndicator()) : error != null
          ? Center(child: SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off, size: 50, color: AppColors.muted),
                const SizedBox(height: 12),
                const Text('No se puede consultar la base de datos',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(ApiService.baseUrl, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const Text('Enciende XAMPP y usa la misma red Wi-Fi. '
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
        onDestinationSelected: (i) => navegar(menu[i]),
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
          'Módulos conectados a la misma base de datos de PHP.'),
      if (permitido('productos')) modulo('Categorías',
          'Agregar, editar o eliminar', Icons.category_outlined, 'categorias'),
      if (permitido('productos')) modulo('Marcas',
          'Agregar, editar o eliminar', Icons.sell_outlined, 'marcas'),
      if (permitido('clientes')) modulo('Clientes',
          'Cuentas y estados', Icons.people_outline, 'clientes'),
      if (permitido('clientes')) modulo('Soporte',
          'Consultas de clientes', Icons.support_agent_outlined, 'soporte'),
      if (permitido('inventario')) modulo('Kardex',
          'Movimientos de stock', Icons.warehouse_outlined, 'inventario'),
      if (permitido('inventario')) modulo('Compras',
          'Historial de proveedores', Icons.shopping_cart_outlined, 'compras'),
      if (permitido('proveedores')) modulo('Proveedores',
          'Gestionar proveedores', Icons.local_shipping_outlined, 'proveedores'),
      modulo('Comprobantes', 'Boletas y facturas de demostración',
          Icons.description_outlined, 'comprobantes'),
      if (permitido('reportes')) modulo('Reportes',
          'Ventas y más vendidos', Icons.bar_chart, 'reportes'),
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
            'Información compartida con el dashboard PHP.'),
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
        encabezado('Últimos pedidos', 'Registros nuevos de MySQL.'),
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
          SizedBox(width: 75, height: 75, child: ProductImage(
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
                child: TextButton.icon(
                  onPressed: guardando ? null : () => editarProducto(p),
                  icon: const Icon(Icons.edit, size: 17),
                  label: const Text('Editar'))),
            ])),
        ]),
      )),
      if (items.isEmpty) const Text('No hay productos.'),
    ];
    if (vista == 'pedidos') return [
      encabezado('Pedidos', 'Modifica el estado de atención.'),
      for (final p in items) registro(
        'Pedido #' + p['id_pedido'].toString(),
        p['nombres'].toString() + ' ' + p['apellidos'].toString() +
        '\n' + p['estado_pedido'].toString() + ' · ' +
        p['fecha_pedido'].toString(),
        Icons.receipt_long_outlined,
        cifra: 'S/ ' + p['total'].toString(),
        accion: ['Pendiente', 'Pagado', 'Procesando', 'Enviado']
          .contains(p['estado_pedido']?.toString())
          ? TextButton(onPressed: guardando ? null : () => cambiarEstado(p),
              child: const Text('Cambiar estado')) : null),
      if (items.isEmpty) const Text('No hay pedidos.'),
    ];
    if (vista == 'pagos') return [
      encabezado('Pagos', 'Confirmación manual tras verificar el abono.'),
      for (final p in items) registro(
        'Pago #' + p['id_pago'].toString() +
        ' · Pedido #' + p['id_pedido'].toString(),
        p['metodo_pago'].toString() + ' · ' + p['estado_pago'].toString() +
        '\n' + p['nombres'].toString() + ' ' + p['apellidos'].toString(),
        Icons.payments_outlined, cifra: 'S/ ' + p['monto'].toString(),
        accion: p['estado_pago'] == 'Pendiente'
          ? TextButton(
              onPressed: guardando ? null : () async {
                if (await confirmar('¿Verificaste el pago de S/ ' +
                    p['monto'].toString() + '?') && mounted) {
                  await ejecutar({
                    'accion': 'pago_confirmar',
                    'id_pago': p['id_pago'],
                  });
                }
              }, child: const Text('Confirmar cobro')) : null),
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
          trailing: Wrap(mainAxisSize: MainAxisSize.min, children: [
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
      encabezado('Clientes', 'Cuentas reales. Activa o bloquea el acceso.'),
      for (final p in items) registro(
        p['nombres'].toString() + ' ' + p['apellidos'].toString(),
        p['correo'].toString() + '\n' +
        p['telefono'].toString() + ' · ' + p['estado'].toString(),
        Icons.person_outline, cifra: 'ID ' + p['id_usuario'].toString(),
        accion: TextButton(
          onPressed: guardando ? null : () => cambiarEstadoCliente(p),
          child: Text(p['estado'] == 'Activo' ? 'Bloquear' : 'Activar'))),
      if (items.isEmpty) const Text('No hay clientes.'),
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
      encabezado('Proveedores', 'Registrar o actualizar datos de MySQL.'),
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
      encabezado('Compras a proveedores',
          'Historial registrado en MySQL; los registros nuevos se '
          'gestionan desde el panel PHP.'),
      for (final p in items) registro(
        'Compra #' + p['id_compra'].toString() +
        ' · ' + p['razon_social'].toString(),
        p['estado'].toString() + ' · ' + p['fecha_compra'].toString(),
        Icons.shopping_cart_outlined, cifra: 'S/ ' + p['total'].toString()),
      if (items.isEmpty) const Text('Aún no hay compras.'),
    ];
    if (vista == 'comprobantes') return [
      encabezado('Comprobantes',
          'Boletas y facturas de demostración emitidas en PHP.'),
      for (final p in items) registro(
        p['tipo_comprobante'].toString() +
        ' ' + p['numero_comprobante'].toString(),
        'Pedido #' + p['id_pedido'].toString() + ' · ' +
        p['nombres'].toString() + ' ' + p['apellidos'].toString() +
        '\n' + p['fecha_emision'].toString(),
        Icons.description_outlined, cifra: 'S/ ' + p['total'].toString()),
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
            'Los valores se usan también en el checkout del cliente.'),
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
        encabezado('Ventas de 7 días', 'Pedidos no cancelados.'),
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
  const _ProductoEditor({required this.producto,
      required this.categorias, required this.marcas});
  @override
  State<_ProductoEditor> createState() => _ProductoEditorState();
}

class _ProductoEditorState extends State<_ProductoEditor> {
  final form = GlobalKey<FormState>();
  late final Map<String, dynamic> valores;

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
        if (numero && (double.tryParse(str) == null ||
            double.parse(str) < 0)) return 'Número incorrecto';
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
                campo('Precio oferta (opcional)', 'precio_oferta'),
                campo('Stock', 'stock', numero: true),
                campo('Stock mínimo', 'stock_minimo', numero: true),
                campo('Descripción', 'descripcion'),
                campo('Tipo de vehículo', 'tipo_vehiculo'),
                campo('Compatibilidad', 'compatibilidad'),
                campo('Ruta de imagen', 'imagen_url'),
              ]))),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  if (form.currentState?.validate() ?? false) {
                    Navigator.pop(context, valores);
                  }
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar en MySQL'))),
        ])),
      ),
    ));
}
