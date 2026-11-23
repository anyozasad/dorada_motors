// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/admin_offline_repository.dart';
import '../services/offline_database.dart';

/// Tienda y administrador usan exactamente el mismo catálogo SQLite.
/// Esta pantalla no necesita red, Apache ni la base MySQL de una laptop.
class LocalCustomerScreen extends StatefulWidget {
  const LocalCustomerScreen({super.key});
  @override
  State<LocalCustomerScreen> createState() => _LocalCustomerScreenState();
}

class _LocalCustomerScreenState extends State<LocalCustomerScreen> {
  final correo = TextEditingController();
  final clave = TextEditingController();
  final nombre = TextEditingController();
  final apellido = TextEditingController();
  final telefono = TextEditingController();
  final buscar = TextEditingController();
  int? idCliente;
  int tab = 0;
  bool nuevo = false;
  bool trabajando = false;
  List<Map<String,dynamic>> productos = [];
  List<Map<String,dynamic>> pedidos = [];
  Map<int,int> carrito = {};

  @override
  void dispose() {
    for (final c in [correo,clave,nombre,apellido,telefono,buscar]) {
      c.dispose();
    }
    super.dispose();
  }

  void aviso(String mensaje) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)));
  }

  Future<void> autenticar() async {
    if (trabajando) return;
    setState(() => trabajando = true);
    try {
      final int? id = nuevo
        ? await AdminOfflineRepository.registrarComprador(
            nombres: nombre.text, apellidos: apellido.text,
            correo: correo.text, telefono: telefono.text,
            contrasena: clave.text)
        : await AdminOfflineRepository.autenticarComprador(
            correo.text, clave.text);
      if (id == null) throw StateError('Correo o contraseña incorrectos');
      final copia = await OfflineDatabase.leer('carrito-cliente-local:$id',
        'carrito');
      final recuperado = <int,int>{};
      if (copia is Map) {
        for (final e in copia.entries) {
          final pid = int.tryParse(e.key.toString());
          final qty = int.tryParse(e.value.toString());
          if (pid != null && qty != null && qty > 0) recuperado[pid] = qty;
        }
      }
      if (!mounted) return;
      setState(() {
        idCliente = id;
        carrito = recuperado;
        tab = 0;
      });
      await cargar();
    } catch (e) {
      aviso(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => trabajando = false);
    }
  }

  Future<void> cargar() async {
    try {
      final catalogo = await AdminOfflineRepository.consultar('productos');
      final lista = idCliente == null ? [] :
        (await AdminOfflineRepository.consultar(
          'mis_pedidos',id:idCliente))['items'] as List;
      if (mounted) setState(() {
        productos = ((catalogo['items'] as List?) ?? const [])
          .whereType<Map>().map((p)=>Map<String,dynamic>.from(p)).toList();
        pedidos = lista.whereType<Map>()
          .map((p)=>Map<String,dynamic>.from(p)).toList();
      });
    } catch(e) {
      aviso(e.toString().replaceFirst('Bad state: ', ''));
    }
  }

  double precio(Map<String,dynamic> p) {
    final base = double.tryParse(p['precio']?.toString() ?? '') ?? 0;
    final oferta = double.tryParse(p['precio_oferta']?.toString() ?? '') ?? 0;
    return oferta > 0 && oferta < base ? oferta : base;
  }

  int stock(Map<String,dynamic> p) =>
    int.tryParse(p['stock']?.toString() ?? '') ?? 0;

  Future<void> cambiar(Map<String,dynamic> p,int delta) async {
    if (idCliente == null || trabajando) return;
    final id = int.tryParse(p['id_producto'].toString()) ?? 0;
    final qty = (carrito[id] ?? 0) + delta;
    if (qty < 0 || qty > stock(p)) {
      aviso('Cantidad no disponible en el inventario local');
      return;
    }
    final anterior = Map<int,int>.from(carrito);
    final nuevos = Map<int,int>.from(carrito);
    if (qty == 0) { nuevos.remove(id); } else { nuevos[id] = qty; }
    setState(() => carrito = nuevos);
    try {
      await OfflineDatabase.guardar('carrito-cliente-local:$idCliente',
        'carrito',{
          for (final e in nuevos.entries) e.key.toString():e.value,
        });
    } catch (_) {
      if (mounted) setState(() => carrito = anterior);
      aviso('No se pudo guardar el carrito en SQLite');
    }
  }

  double get total => productos.fold<double>(0,(s,p) =>
      s + precio(p)*(carrito[p['id_producto']] ?? 0));

  Future<void> confirmarCompra() async {
    if (idCliente == null || trabajando || carrito.isEmpty) return;
    final opciones = await Navigator.push<Map<String,dynamic>>(context,
      MaterialPageRoute(builder: (_) => const _LocalCheckout()));
    if (opciones == null || !mounted) return;
    setState(() => trabajando = true);
    try {
      var idDireccion = 0;
      if (opciones['tipo_entrega'] == 'Delivery') {
        final d = await AdminOfflineRepository.operar({
          'accion':'direccion_guardar','id_usuario':idCliente!,
          'id_direccion':0,
          'departamento':opciones['departamento'],
          'provincia':opciones['provincia'],
          'distrito':opciones['distrito'],
          'direccion_detalle':opciones['direccion_detalle'],
          'referencia':opciones['referencia'],
        });
        idDireccion = int.tryParse(d['id_direccion'].toString()) ?? 0;
        if (idDireccion <= 0) throw StateError('Dirección no guardada');
      }
      final r = await AdminOfflineRepository.operar({
        'accion':'pedido_manual',
        'id_usuario':idCliente!,'id_direccion':idDireccion,
        'tipo_entrega':opciones['tipo_entrega'],
        'metodo_pago':opciones['metodo_pago'],
        'items':[
          for (final e in carrito.entries)
            {'id_producto':e.key,'cantidad':e.value},
        ],
      });
      // Pedido y descuento de inventario son un cambio atómico de SQLite.
      // El carrito se vacía al confirmarse la venta, nunca antes.
      carrito = {};
      await OfflineDatabase.guardar('carrito-cliente-local:$idCliente',
        'carrito',{});
      await cargar();
      if (mounted) setState(() => tab=2);
      aviso('Pedido #' + r['id_pedido'].toString() +
        ' guardado en el celular. Pago pendiente de verificación.');
    } catch(e) {
      aviso(e.toString().replaceFirst('Bad state: ', ''));
      await cargar();
    } finally {
      if (mounted) setState(() => trabajando = false);
    }
  }

  void salir() {
    setState(() {
      idCliente=null;tab=0;carrito={};productos=[];pedidos=[];
      correo.clear();clave.clear();nombre.clear();apellido.clear();
      telefono.clear();buscar.clear();nuevo=false;
    });
  }

  Widget foto(String valor) {
    if (valor.startsWith('assets/')) {
      return Image.asset(valor,fit:BoxFit.contain,
        errorBuilder:(_,__,___)=>const Icon(Icons.image_not_supported));
    }
    if (!kIsWeb && valor.startsWith('/')) {
      return Image.file(File(valor),fit:BoxFit.contain,
        errorBuilder:(_,__,___)=>const Icon(Icons.image_not_supported));
    }
    return const Icon(Icons.inventory_2_outlined);
  }

  Widget repuesto(Map<String,dynamic> p) {
    final id = int.tryParse(p['id_producto'].toString()) ?? 0;
    final qty = carrito[id] ?? 0;
    return Card(child: Padding(padding:const EdgeInsets.all(10),
      child:Row(children:[
        SizedBox(width:72,height:72,
          child:foto(p['imagen_url']?.toString() ?? '')),
        const SizedBox(width:8),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Text(p['nombre_producto'].toString(),
              style:const TextStyle(fontWeight:FontWeight.bold)),
            Text(p['nombre_marca'].toString() + ' · ' +
              p['nombre_categoria'].toString(),
              style:const TextStyle(fontSize:12)),
            Text('S/ ' + precio(p).toStringAsFixed(2) +
              ' · Stock: ' + stock(p).toString()),
            Row(children:[
              IconButton(tooltip:'Quitar',onPressed:!trabajando && qty>0
                ?()=>cambiar(p,-1):null,
                icon:const Icon(Icons.remove_circle_outline)),
              Text(qty.toString()),
              IconButton(tooltip:'Agregar',onPressed:!trabajando && qty<stock(p)
                ?()=>cambiar(p,1):null,
                icon:const Icon(Icons.add_circle_outline)),
            ]),
          ])),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (idCliente == null) {
      return Scaffold(
        appBar:AppBar(title:const Text('Tienda local · sin laptop')),
        body:Center(child:SingleChildScrollView(
          padding:const EdgeInsets.all(20),
          child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),
            child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,
              children:[
                const Icon(Icons.storefront_outlined,size:56),
                const SizedBox(height:12),
                const Text('Compra sin internet',
                  textAlign:TextAlign.center,
                  style:TextStyle(fontSize:23,fontWeight:FontWeight.bold)),
                const SizedBox(height:10),
                const Text('El comprador y el administrador comparten '
                  'los productos, stock y pedidos en SQLite de este celular. '
                  'No se trata de una cuenta de MySQL.',
                  textAlign:TextAlign.center),
                const SizedBox(height:16),
                SegmentedButton<bool>(
                  segments:const [
                    ButtonSegment(value:false,label:Text('Ingresar')),
                    ButtonSegment(value:true,label:Text('Registrarme')),
                  ],
                  selected:{nuevo},
                  onSelectionChanged:(v)=>setState(()=>nuevo=v.first)),
                if (nuevo)...[
                  TextField(controller:nombre,
                    decoration:const InputDecoration(labelText:'Nombres')),
                  TextField(controller:apellido,
                    decoration:const InputDecoration(labelText:'Apellidos')),
                  TextField(controller:telefono,
                    keyboardType:TextInputType.phone,
                    decoration:const InputDecoration(labelText:'Teléfono')),
                ],
                TextField(controller:correo,
                  keyboardType:TextInputType.emailAddress,
                  decoration:const InputDecoration(labelText:'Correo')),
                TextField(controller:clave,obscureText:true,
                  decoration:const InputDecoration(
                    labelText:'Contraseña local (mínimo 8)')),
                const SizedBox(height:18),
                FilledButton.icon(onPressed:trabajando?null:autenticar,
                  icon:const Icon(Icons.login),
                  label:Text(trabajando?'Verificando...':
                    nuevo?'Crear cuenta y entrar':'Abrir mi tienda local')),
              ])))));
    }
    return Scaffold(
      appBar:AppBar(title:const Text('Dorada Motors · tienda local'),
        actions:[
          IconButton(tooltip:'Actualizar',onPressed:cargar,
            icon:const Icon(Icons.refresh)),
          IconButton(tooltip:'Cerrar sesión local',onPressed:salir,
            icon:const Icon(Icons.logout)),
        ]),
      body:Column(children:[
        Container(width:double.infinity,color:const Color(0xFFFFF1D5),
          padding:const EdgeInsets.all(9),
          child:const Text('SIN INTERNET · Stock y ventas compartidos '
            'con el administrador local. No se envían a MySQL.',
            textAlign:TextAlign.center,
            style:TextStyle(fontSize:12,fontWeight:FontWeight.bold))),
        Expanded(child:ListView(padding:const EdgeInsets.all(12),
          children:switch(tab) {
            0 => [
              TextField(controller:buscar,
                decoration:const InputDecoration(
                  labelText:'Buscar repuesto',prefixIcon:Icon(Icons.search)),
                onChanged:(_)=>setState((){})),
              const SizedBox(height:10),
              for (final p in productos.where((p)=>
                p['nombre_producto'].toString().toLowerCase().contains(
                  buscar.text.trim().toLowerCase())))
                repuesto(p),
              if (productos.isEmpty)const Text('No hay productos locales.'),
            ],
            1 => [
              const Text('Carrito',style:TextStyle(
                fontWeight:FontWeight.bold,fontSize:22)),
              for (final p in productos.where((p)=>
                carrito.containsKey(p['id_producto'])))
                repuesto(p),
              if (carrito.isEmpty)const Text('Tu carrito está vacío.'),
              const SizedBox(height:16),
              Text('Total: S/ '+total.toStringAsFixed(2),
                style:const TextStyle(fontSize:22,
                  fontWeight:FontWeight.bold)),
              const SizedBox(height:10),
              FilledButton.icon(
                onPressed:carrito.isEmpty || trabajando?null:confirmarCompra,
                icon:const Icon(Icons.shopping_bag_outlined),
                label:const Text('Registrar pedido local')),
              const Text('El pago se confirma manualmente '
                'desde el dashboard local del administrador.'),
            ],
            _ => [
              const Text('Mis pedidos',style:TextStyle(
                fontWeight:FontWeight.bold,fontSize:22)),
              for (final p in pedidos)Card(child:ListTile(
                leading:const Icon(Icons.receipt_long_outlined),
                title:Text('Pedido #'+p['id_pedido'].toString()),
                subtitle:Text('Estado: '+p['estado_pedido'].toString()+
                  '\nEntrega: '+p['tipo_entrega'].toString()),
                trailing:Text('S/ '+p['total'].toString()))),
              if (pedidos.isEmpty)const Text('Aún no hay pedidos.'),
            ],
          })),
      ]),
      bottomNavigationBar:NavigationBar(
        selectedIndex:tab,
        onDestinationSelected:(v)=>setState(()=>tab=v),
        destinations:const [
          NavigationDestination(icon:Icon(Icons.storefront_outlined),
            label:'Productos'),
          NavigationDestination(icon:Icon(Icons.shopping_cart_outlined),
            label:'Carrito'),
          NavigationDestination(icon:Icon(Icons.receipt_long_outlined),
            label:'Pedidos'),
        ]),
    );
  }
}

class _LocalCheckout extends StatefulWidget {
  const _LocalCheckout();
  @override
  State<_LocalCheckout> createState()=>_LocalCheckoutState();
}

class _LocalCheckoutState extends State<_LocalCheckout> {
  String entrega='Recojo en tienda', metodo='Efectivo';
  final departamento=TextEditingController(text:'Ucayali');
  final provincia=TextEditingController(text:'Coronel Portillo');
  final distrito=TextEditingController(text:'Callería');
  final direccion=TextEditingController();
  final referencia=TextEditingController();
  @override
  void dispose() {
    for(final c in [departamento,provincia,distrito,direccion,referencia]) {
      c.dispose();
    }
    super.dispose();
  }
  void aceptar() {
    if(entrega=='Delivery' &&
      [departamento,provincia,distrito,direccion]
        .any((c)=>c.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Completa la dirección de entrega')));
      return;
    }
    Navigator.pop(context,<String,dynamic>{
      'tipo_entrega':entrega,'metodo_pago':metodo,
      'departamento':departamento.text.trim(),
      'provincia':provincia.text.trim(),
      'distrito':distrito.text.trim(),
      'direccion_detalle':direccion.text.trim(),
      'referencia':referencia.text.trim(),
    });
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Confirmar pedido local')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('Tu pedido se guardará en este celular, sin MySQL.'),
      const SizedBox(height:15),
      DropdownButtonFormField<String>(
        initialValue:entrega,
        decoration:const InputDecoration(labelText:'Entrega',
          border:OutlineInputBorder()),
        items:const [
          DropdownMenuItem(value:'Recojo en tienda',child:Text('Recojo en tienda')),
          DropdownMenuItem(value:'Delivery',child:Text('Delivery')),
        ],onChanged:(v){if(v!=null)setState(()=>entrega=v);}),
      if (entrega=='Delivery')...[
        for (final campo in [
          (departamento,'Departamento'),(provincia,'Provincia'),
          (distrito,'Distrito'),(direccion,'Dirección'),
          (referencia,'Referencia'),
        ]) Padding(padding:const EdgeInsets.only(top:10),
          child:TextField(controller:campo.$1,
            decoration:InputDecoration(labelText:campo.$2,
              border:const OutlineInputBorder()))),
      ],
      const SizedBox(height:15),
      DropdownButtonFormField<String>(
        initialValue:metodo,
        decoration:const InputDecoration(labelText:'Método de pago',
          border:OutlineInputBorder()),
        items:const [
          DropdownMenuItem(value:'Efectivo',child:Text('Efectivo')),
          DropdownMenuItem(value:'Yape',child:Text('Yape')),
          DropdownMenuItem(value:'Plin',child:Text('Plin')),
          DropdownMenuItem(value:'Transferencia',child:Text('Transferencia')),
        ],onChanged:(v){if(v!=null)setState(()=>metodo=v);}),
      const SizedBox(height:12),
      const Text('Elegir un método de pago NO cobra automáticamente. '
        'El administrador deberá verificarlo.'),
      const SizedBox(height:24),
      FilledButton.icon(onPressed:aceptar,
        icon:const Icon(Icons.check_circle_outline),
        label:const Text('Confirmar pedido en SQLite')),
    ]),
  );
}
