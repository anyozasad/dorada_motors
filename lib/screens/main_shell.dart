import 'package:flutter/material.dart';

import '../models/producto.dart';
import '../services/api_service.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import '../widgets/product_image.dart';
import '../widgets/ui_motion.dart';
import 'checkout_screen.dart';
import 'orders_screen.dart';
import 'direcciones_screen.dart';
import 'cuenta_screen.dart';
import 'soporte_screen.dart';

class MainShell extends StatefulWidget {
  final bool isGuest;
  final String? userName;
  final String? userEmail;
  final VoidCallback onLoginRequested;
  final VoidCallback onLogout;
  final VoidCallback onProfileUpdated;

  const MainShell({
    super.key,
    required this.isGuest,
    this.userName,
    this.userEmail,
    required this.onLoginRequested,
    required this.onLogout,
    required this.onProfileUpdated,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _page = 0;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  String _category = 'Todos';
  String _brand = 'Todas';
  String _vehicle = 'Todos';
  String _ordenCatalogo = 'Relevancia';
  bool _soloDisponibles = false;
  Set<int> _favorites = {};
  Map<int, int> _cart = {};
  List<Producto> _productos = [];
  List<String> _categorias = [];
  List<String> _marcas = [];
  bool _cargandoProductosApi = false;
  bool _cargandoMisDatos = false;
  final Set<int> _carritoEnProceso = <int>{};
  final Set<int> _favoritosEnProceso = <int>{};
  String? _errorProductosApi;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    _loadCatalogoApi();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<int> _idCliente() async {
    final session = await LocalStore.getSession();
    return int.tryParse(session?['id'] ?? '') ?? 0;
  }

  Future<void> _loadLocalData() async {
    // Invitados mantienen únicamente un carrito local. Para clientes,
    // MySQL es la fuente de verdad, incluso al cambiar de dispositivo.
    if (widget.isGuest) {
      final cart = await LocalStore.getGuestCart();
      if (!mounted) return;
      setState(() {
        _favorites = {};
        _cart = cart;
      });
      return;
    }

    if (mounted) setState(() => _cargandoMisDatos = true);
    try {
      final idUsuario = await _idCliente();
      if (idUsuario <= 0) throw Exception('Inicia sesión nuevamente.');
      final respuestaCarrito = await ApiService.obtenerCarritoUsuario(idUsuario);
      final respuestaFavoritos = await ApiService.obtenerFavoritosUsuario(idUsuario);

      final carrito = <int, int>{};
      for (final item in (respuestaCarrito['items'] as List? ?? const [])) {
        if (item is! Map) continue;
        final id = int.tryParse(item['id_producto']?.toString() ?? '') ?? 0;
        final cantidad = int.tryParse(item['cantidad']?.toString() ?? '') ?? 0;
        if (id > 0 && cantidad > 0) carrito[id] = cantidad;
      }
      // Los productos agregados como invitado se incorporan al servidor
      // al iniciar sesión. Se elimina cada pendiente solo tras confirmarse.
      final pendientesInvitado = await LocalStore.getGuestCart();
      var invitadoSinSincronizar = false;
      for (final entry in pendientesInvitado.entries) {
        final cantidad = (carrito[entry.key] ?? 0) + entry.value;
        try {
          await ApiService.guardarCantidadCarrito(
            idUsuario: idUsuario,
            idProducto: entry.key,
            cantidad: cantidad,
          );
          carrito[entry.key] = cantidad;
          final restantes = await LocalStore.getGuestCart();
          restantes.remove(entry.key);
          await LocalStore.saveGuestCart(restantes);
        } catch (_) {
          invitadoSinSincronizar = true;
        }
      }
      if (invitadoSinSincronizar && mounted) {
        _message('Algunos productos de invitado no se pudieron agregar. Revisa el stock.');
      }

      final favoritos = <int>{};
      for (final item in respuestaFavoritos) {
        if (item is! Map) continue;
        final id = int.tryParse(item['id_producto']?.toString() ?? '') ?? 0;
        if (id > 0) favoritos.add(id);
      }

      if (!mounted) return;
      setState(() {
        _cart = carrito;
        _favorites = favoritos;
        _cargandoMisDatos = false;
      });
      await LocalStore.saveCart(carrito);
      await LocalStore.saveFavorites(favoritos);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoMisDatos = false;
        _cart = {};
        _favorites = {};
      });
      _message('No se pudo sincronizar carrito y favoritos. Revisa la conexión.');
    }
  }
  Future<void> _loadCatalogoApi() async {
    if (mounted) {
      setState(() {
        _cargandoProductosApi = true;
        _errorProductosApi = null;
      });
    }

    try {
      final resultados = await Future.wait([
        ApiService.obtenerProductos(),
        ApiService.obtenerCategorias(),
        ApiService.obtenerMarcas(),
      ]);
      final data = resultados[0];
      final categoriasData = resultados[1];
      final marcasData = resultados[2];

      final productosApi = data.map((raw) {
        final row = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final id = int.tryParse(row['id_producto']?.toString() ?? '') ?? 0;
        final precio = double.tryParse(row['precio']?.toString() ?? '0') ?? 0;
        final stock = int.tryParse(row['stock']?.toString() ?? '0') ?? 0;
        final precioOfertaRaw = double.tryParse(row['precio_oferta']?.toString() ?? '');
        final precioOferta = precioOfertaRaw != null && precioOfertaRaw > 0 && precioOfertaRaw < precio
            ? precioOfertaRaw
            : null;
        final imagenRaw = (row['imagen_url']?.toString() ?? '').trim();

        String imagen = imagenRaw;
        if (imagen.isNotEmpty &&
            !imagen.startsWith('http://') &&
            !imagen.startsWith('https://') &&
            !imagen.startsWith('assets/')) {
          imagen = '${ApiService.baseUrl}/$imagen';
        }

        if (imagen.isEmpty) {
          imagen = 'assets/imagenes/logo_adn_imports.png';
        }

        return Producto(
          id: id,
          nombre: row['nombre_producto']?.toString() ?? 'Producto',
          descripcion: row['descripcion']?.toString() ?? '',
          marca: row['nombre_marca']?.toString() ?? 'Sin marca',
          categoria: row['nombre_categoria']?.toString() ?? 'Otros',
          tipoVehiculo: (row['tipo_vehiculo']?.toString() ?? 'Motocicleta / Motokar').trim(),
          compatibilidad: (row['compatibilidad']?.toString() ?? '').trim().isEmpty
              ? 'Consultar compatibilidad según modelo'
              : row['compatibilidad'].toString(),
          precio: precio,
          precioOferta: precioOferta,
          stock: stock,
          imagen: imagen,
        );
      }).where((p) => p.id > 0).toList();

      if (!mounted) return;
      setState(() {
        _productos = productosApi;
        _categorias = categoriasData
            .map((e) => e is Map ? (e['nombre_categoria']?.toString() ?? '') : '')
            .where((e) => e.isNotEmpty)
            .toList();
        _marcas = marcasData
            .map((e) => e is Map ? (e['nombre_marca']?.toString() ?? '') : '')
            .where((e) => e.isNotEmpty)
            .toList();

        if (_category != 'Todos' && !_categorias.contains(_category)) {
          _category = 'Todos';
        }
        if (_brand != 'Todas' && !_marcas.contains(_brand)) {
          _brand = 'Todas';
        }

        _cargandoProductosApi = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoProductosApi = false;
        _errorProductosApi = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  IconData _iconoCategoria(String nombre) {
    final valor = nombre.toLowerCase();
    if (valor.contains('freno')) return Icons.album_outlined;
    if (valor.contains('motor')) return Icons.settings;
    if (valor.contains('llanta') || valor.contains('neum')) return Icons.tire_repair;
    if (valor.contains('luz') || valor.contains('elect')) return Icons.bolt_outlined;
    if (valor.contains('aceite') || valor.contains('lub')) return Icons.water_drop_outlined;
    if (valor.contains('susp')) return Icons.swap_vert_circle_outlined;
    if (valor.contains('acces')) return Icons.extension_outlined;
    if (valor.contains('trans')) return Icons.sync_alt_rounded;
    return Icons.inventory_2_outlined;
  }

  Widget _imagenProducto(String ruta, {BoxFit fit = BoxFit.contain}) {
    return ProductImage(source: ruta, fit: fit);
  }

  Producto _productById(int id) => _productos.firstWhere((p) => p.id == id);

  Future<void> _toggleFavorite(int id) async {
    if (widget.isGuest) {
      _requireAccount('Inicia sesión para guardar productos en Favoritos.');
      return;
    }
    if (_cargandoMisDatos || _favoritosEnProceso.contains(id)) return;
    _favoritosEnProceso.add(id);
    try {
      final idUsuario = await _idCliente();
      if (idUsuario <= 0) throw Exception('Inicia sesión nuevamente.');
      final agregar = !_favorites.contains(id);
      await ApiService.guardarFavorito(
        idUsuario: idUsuario,
        idProducto: id,
        agregar: agregar,
      );
      if (!mounted) return;
      setState(() {
        if (agregar) {
          _favorites.add(id);
        } else {
          _favorites.remove(id);
        }
      });
      await LocalStore.saveFavorites(_favorites);
    } catch (e) {
      if (mounted) _message('No se pudo actualizar Favoritos: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      _favoritosEnProceso.remove(id);
    }
  }

  Future<void> _addCart(int id) async {
    if (_cargandoMisDatos || _carritoEnProceso.contains(id)) return;
    final product = _productById(id);
    final current = _cart[id] ?? 0;
    if (!product.disponible) {
      _message('Este producto está agotado.');
      return;
    }
    if (current >= product.stock) {
      _message('No hay más unidades disponibles de ${product.nombre}.');
      return;
    }
    _carritoEnProceso.add(id);
    try {
      if (!widget.isGuest) {
        final idUsuario = await _idCliente();
        if (idUsuario <= 0) throw Exception('Inicia sesión nuevamente.');
        await ApiService.guardarCantidadCarrito(
          idUsuario: idUsuario,
          idProducto: id,
          cantidad: current + 1,
        );
      }
      if (!mounted) return;
      setState(() => _cart[id] = current + 1);
      await (widget.isGuest
          ? LocalStore.saveGuestCart(_cart)
          : LocalStore.saveCart(_cart));
      if (mounted) _message('${product.nombre} agregado al carrito.');
    } catch (e) {
      if (mounted) _message('No se pudo actualizar el carrito: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      _carritoEnProceso.remove(id);
    }
  }

  Future<void> _changeQty(int id, int delta, [VoidCallback? modalRefresh]) async {
    if (_cargandoMisDatos || _carritoEnProceso.contains(id)) return;
    final product = _productById(id);
    final current = _cart[id] ?? 0;
    final next = current + delta;
    if (next > product.stock) {
      _message('Stock máximo disponible: ${product.stock}.');
      return;
    }
    _carritoEnProceso.add(id);
    try {
      if (!widget.isGuest) {
        final idUsuario = await _idCliente();
        if (idUsuario <= 0) throw Exception('Inicia sesión nuevamente.');
        await ApiService.guardarCantidadCarrito(
          idUsuario: idUsuario,
          idProducto: id,
          cantidad: next,
        );
      }
      if (!mounted) return;
      setState(() {
        if (next <= 0) {
          _cart.remove(id);
        } else {
          _cart[id] = next;
        }
      });
      // La lámina del carrito puede haberse cerrado durante la petición.
      try { modalRefresh?.call(); } catch (_) {}
      await (widget.isGuest
          ? LocalStore.saveGuestCart(_cart)
          : LocalStore.saveCart(_cart));
    } catch (e) {
      if (mounted) _message('No se pudo actualizar el carrito: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      _carritoEnProceso.remove(id);
    }
  }

  // Ignora artículos eliminados del catálogo para evitar errores de búsqueda.
  Map<int, int> get _cartValido {
    final ids = _productos.map((p) => p.id).toSet();
    return {
      for (final entry in _cart.entries)
        if (ids.contains(entry.key) && entry.value > 0)
          entry.key: entry.value,
    };
  }

  int get _cartCount => _cartValido.values.fold(0, (a, b) => a + b);

  double get _cartTotal {
    double total = 0;
    _cartValido.forEach((id, qty) => total += _productById(id).precioFinal * qty);
    return total;
  }

  String _normalizarBusqueda(String texto) {
    const origen = 'áéíóúüñ';
    const destino = 'aeiouun';
    final minusculas = texto.toLowerCase().trim();
    return minusculas.split('').map((letra) {
      final indice = origen.indexOf(letra);
      return indice >= 0 ? destino[indice] : letra;
    }).join();
  }

  void _limpiarBusquedaYFiltros() {
    _searchController.clear();
    setState(() {
      _search = '';
      _category = 'Todos';
      _brand = 'Todas';
      _vehicle = 'Todos';
      _soloDisponibles = false;
      _ordenCatalogo = 'Relevancia';
    });
  }

  List<Producto> get _filteredProducts {
    final texto = _normalizarBusqueda(_search);
    final encontrados = _productos.where((p) {
      final informacion = _normalizarBusqueda(
        '${p.nombre} ${p.marca} ${p.categoria} ${p.descripcion} '
        '${p.compatibilidad} ${p.tipoVehiculo}',
      );
      final coincide = texto.isEmpty || informacion.contains(texto);
      final categoria = _category == 'Todos' || p.categoria == _category;
      final marca = _brand == 'Todas' || p.marca == _brand;
      final vehiculo = _vehicle == 'Todos' || p.tipoVehiculo.contains(_vehicle);
      final disponible = !_soloDisponibles || p.disponible;
      return coincide && categoria && marca && vehiculo && disponible;
    }).toList();
    switch (_ordenCatalogo) {
      case 'Menor precio':
        encontrados.sort((a, b) => a.precioFinal.compareTo(b.precioFinal));
      case 'Mayor precio':
        encontrados.sort((a, b) => b.precioFinal.compareTo(a.precioFinal));
      case 'Nombre A-Z':
        encontrados.sort((a, b) => a.nombre.compareTo(b.nombre));
      default:
        break;
    }
    return encontrados;
  }

  Future<void> _configurarConexion() async {
    final personalizada = await LocalStore.getApiBaseUrl();
    if (!mounted) return;
    var direccionIngresada = personalizada?.isNotEmpty == true
        ? personalizada! : ApiService.baseUrl;
    final nuevaUrl = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Configuración de conexión'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Indica la dirección de la API PHP. En esta PC normalmente es http://localhost/dorada_api.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 15),
            TextFormField(
              initialValue: direccionIngresada,
              onChanged: (valor) => direccionIngresada = valor,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Servidor PHP',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const Text('Restablecer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, direccionIngresada.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (!mounted || nuevaUrl == null) return;
    final valor = nuevaUrl.trim();
    if (valor.isNotEmpty) {
      final uri = Uri.tryParse(valor);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        _message('Ingresa una dirección HTTP o HTTPS válida.');
        return;
      }
    }

    // No dejar la aplicación apuntando a un servidor que no responde.
    final servidorAnterior = await LocalStore.getApiBaseUrl();
    ApiService.configurarServidor(valor);
    try {
      await ApiService.obtenerProductos();
      await LocalStore.saveApiBaseUrl(valor);
      if (!mounted) return;
      _message('Conexión verificada. Catálogo sincronizado con MySQL.');
      await _loadCatalogoApi();
    } catch (e) {
      ApiService.configurarServidor(servidorAnterior);
      if (!mounted) return;
      _message('No se guardó la dirección: el servidor no respondió correctamente. '
          '${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _requireAccount(String text) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline_rounded, size: 35, color: AppColors.goldDark),
            ),
            const SizedBox(height: 16),
            const Text('Cuenta requerida', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.45)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Ahora no')),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onLoginRequested();
            },
            child: const Text('Iniciar sesión'),
          ),
        ],
      ),
    );
  }

  Future<void> _openProduct(Producto product) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) {
          final isFavorite = _favorites.contains(product.id);
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * .91),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 280,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: _imagenProducto(product.imagen),
                            ),
                          ),
                          if (product.precioOferta != null)
                            Positioned(
                              left: 14,
                              top: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(11)),
                                child: const Text('OFERTA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.gold)),
                              ),
                            ),
                          Positioned(
                            right: 12,
                            top: 12,
                            child: IconButton.filledTonal(
                              onPressed: () async {
                                await _toggleFavorite(product.id);
                                if (mounted) refresh(() {});
                              },
                              icon: Icon(
                                isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: isFavorite ? AppColors.danger : AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(10)),
                          child: Text(product.marca, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.goldDark)),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: product.disponible ? const Color(0xFFE8F7EF) : const Color(0xFFFFE9E7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            product.disponible ? 'Disponible' : 'Agotado',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: product.disponible ? AppColors.success : AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(product.nombre, style: const TextStyle(fontSize: 27, height: 1.1, fontWeight: FontWeight.w900, color: AppColors.ink)),
                    const SizedBox(height: 9),
                    Text(product.descripcion, style: const TextStyle(color: AppColors.muted, height: 1.5)),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                      child: Column(
                        children: [
                          _detailRow(Icons.two_wheeler_outlined, 'Vehículo', product.tipoVehiculo),
                          const Divider(height: 18),
                          _detailRow(Icons.build_outlined, 'Compatibilidad', product.compatibilidad),
                          const Divider(height: 18),
                          _detailRow(Icons.inventory_2_outlined, 'Stock', product.disponible ? '${product.stock} unidades' : 'Agotado'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navySoft]),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Precio', style: TextStyle(fontSize: 11, color: Colors.white60)),
                                if (product.precioOferta != null)
                                  Text(
                                    'S/ ${product.precio.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12, color: Colors.white54, decoration: TextDecoration.lineThrough),
                                  ),
                                Text(
                                  'S/ ${product.precioFinal.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: AppColors.gold),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: product.disponible
                                ? () async {
                                    await _addCart(product.id);
                                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                                  }
                                : null,
                            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.ink),
                            icon: const Icon(Icons.add_shopping_cart_rounded),
                            label: const Text('Agregar'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 18, color: AppColors.goldDark),
        ),
        const SizedBox(width: 11),
        SizedBox(width: 92, child: Padding(padding: const EdgeInsets.only(top: 7), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)))),
        Expanded(child: Padding(padding: const EdgeInsets.only(top: 7), child: Text(value, style: const TextStyle(color: AppColors.muted)))),
      ],
    );
  }

  Future<void> _openCart() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * .86),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
                    child: Row(
                      children: [
                        Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.shopping_bag_outlined, color: AppColors.goldDark)),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Mi carrito', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
                        IconButton.filledTonal(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                  ),
                  if (_cartValido.isEmpty)
                    const Expanded(child: _CartEmpty())
                  else
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                        children: _cartValido.entries.map((entry) {
                          final p = _productById(entry.key);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 11),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 74,
                                  height: 74,
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(16)),
                                  child: _imagenProducto(p.imagen),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 4),
                                      Text(p.marca, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                                      const SizedBox(height: 5),
                                      Text('S/ ${p.precioFinal.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.goldDark, fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _qtyButton(Icons.remove_rounded, () => _changeQty(p.id, -1, () => refresh(() {}))),
                                      SizedBox(width: 25, child: Text('${entry.value}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900))),
                                      _qtyButton(Icons.add_rounded, () => _changeQty(p.id, 1, () => refresh(() {}))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  if (_cartValido.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(child: Text('Total del carrito', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700))),
                              Text('S/ ${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: AppColors.goldDark)),
                            ],
                          ),
                          const SizedBox(height: 13),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                if (widget.isGuest) {
                                  _requireAccount('Inicia sesión para confirmar tu compra y guardar el pedido.');
                                  return;
                                }
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CheckoutScreen(
                                      cart: Map<int, int>.from(_cartValido),
                                      products: _productos,
                                      onCompleted: () {
                                        if (!mounted) return;
                                        setState(() => _cart.clear());
                                        _loadCatalogoApi();
                                      },
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text('Continuar compra'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(width: 31, height: 31, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: Icon(icon, size: 17)),
    );
  }

  Future<void> _openFilters() async {
    final brands = ['Todas', ..._marcas];
    String tempCategory = _category;
    String tempBrand = _brand;
    String tempVehicle = _vehicle;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) => Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(20)))),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Icon(Icons.tune_rounded, color: AppColors.goldDark),
                      SizedBox(width: 9),
                      Text('Filtrar productos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _filterTitle('Categoría'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: ['Todos', ..._categorias].map((value) => ChoiceChip(
                      label: Text(value),
                      selected: tempCategory == value,
                      onSelected: (_) => refresh(() => tempCategory = value),
                    )).toList(),
                  ),
                  const SizedBox(height: 18),
                  _filterTitle('Marca'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: brands.map((value) => ChoiceChip(
                      label: Text(value),
                      selected: tempBrand == value,
                      onSelected: (_) => refresh(() => tempBrand = value),
                    )).toList(),
                  ),
                  const SizedBox(height: 18),
                  _filterTitle('Vehículo'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    children: ['Todos', 'Motocicleta', 'Motokar'].map((value) => ChoiceChip(
                      label: Text(value),
                      selected: tempVehicle == value,
                      onSelected: (_) => refresh(() => tempVehicle = value),
                    )).toList(),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => refresh(() {
                            tempCategory = 'Todos';
                            tempBrand = 'Todas';
                            tempVehicle = 'Todos';
                          }),
                          child: const Text('Limpiar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _category = tempCategory;
                              _brand = tempBrand;
                              _vehicle = tempVehicle;
                              _page = 1;
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Aplicar filtros'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterTitle(String text) => Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.ink));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 340),
          reverseDuration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final slide = Tween<Offset>(
              begin: const Offset(.025, .018),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_page),
            child: _selectedPage(),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: .08), blurRadius: 22, offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: NavigationBar(
          selectedIndex: _page,
          onDestinationSelected: (index) {
            if (index != _page) setState(() => _page = index);
            if (index <= 2) _loadCatalogoApi();
            if (index == 2 && !widget.isGuest && !_cargandoMisDatos) {
              _loadLocalData();
            }
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
            NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Productos'),
            NavigationDestination(icon: Icon(Icons.favorite_border_rounded), selectedIcon: Icon(Icons.favorite_rounded), label: 'Favoritos'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Perfil'),
          ],
        ),
      ),
    );
  }

  Widget _selectedPage() {
    switch (_page) {
      case 1:
        return _productsPage();
      case 2:
        return _favoritesPage();
      case 3:
        return _profilePage();
      default:
        return _homePage();
    }
  }

  Widget _homePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RevealOnMount(child: _header()),
          const SizedBox(height: 20),
          RevealOnMount(
            delay: const Duration(milliseconds: 70),
            child: _heroPanel(),
          ),
          const SizedBox(height: 18),
          RevealOnMount(
            delay: const Duration(milliseconds: 130),
            child: _searchBox(submitToProducts: true),
          ),
          const SizedBox(height: 25),
          RevealOnMount(
            delay: const Duration(milliseconds: 190),
            child: _sectionHeader('Compra por categoría', 'Ver todas', () {
            setState(() {
              _category = 'Todos';
              _page = 1;
            });
          }),
          ),
          const SizedBox(height: 12),
          if (_cargandoProductosApi && _categorias.isEmpty)
            const _CatalogLoadingCard()
          else if (_categorias.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      color: AppColors.goldDark, size: 25),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Aún no hay categorías para mostrar. '
                      'Actualiza el catálogo o comprueba la conexión con PHP.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar categorías',
                    onPressed: _cargandoProductosApi ? null : _loadCatalogoApi,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            )
          else
          RevealOnMount(
            delay: const Duration(milliseconds: 230),
            child: SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categorias.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = _categorias[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() {
                    _category = item;
                    _page = 1;
                  }),
                  child: Container(
                    width: 98,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: .03), blurRadius: 12, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 49,
                          height: 49,
                          decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(15)),
                          child: Icon(_iconoCategoria(item), color: AppColors.goldDark, size: 25),
                        ),
                        const SizedBox(height: 8),
                        Text(item, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          ),
          const SizedBox(height: 26),
          RevealOnMount(
            delay: const Duration(milliseconds: 280),
            child: _benefitsStrip(),
          ),
          const SizedBox(height: 27),
          RevealOnMount(
            delay: const Duration(milliseconds: 330),
            child: _sectionHeader('Productos destacados', 'Ver más', () {
              setState(() {
                _category = 'Todos';
                _page = 1;
              });
            }),
          ),
          const SizedBox(height: 12),
          if (_cargandoProductosApi && _productos.isEmpty)
            const _CatalogLoadingCard()
          else if (_productos.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      color: AppColors.goldDark, size: 34),
                  const SizedBox(height: 8),
                  const Text('El catálogo todavía está vacío',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text(
                    'Los productos que registre el administrador en PHP '
                    'aparecerán aquí cuando MySQL esté conectado.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 9),
                  TextButton.icon(
                    onPressed: _cargandoProductosApi ? null : _loadCatalogoApi,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Actualizar catálogo'),
                  ),
                ],
              ),
            )
          else
            RevealOnMount(
              delay: const Duration(milliseconds: 380),
              child: _productGrid(_productos.take(4).toList()),
            ),
        ],
      ),
    );
  }

  Widget _header() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compacto = constraints.maxWidth < 385;
        final logoSize = compacto ? 48.0 : 62.0;
        final actionSize = compacto ? 39.0 : 45.0;
        return Row(
          children: [
            Container(
              width: logoSize,
              height: logoSize,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Image.asset(
                  'assets/imagenes/logo_adn_imports.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(width: compacto ? 8 : 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DORADA MOTORS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compacto ? 15 : 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.isGuest
                        ? "ADN Import's • Catálogo"
                        : 'Hola, ${widget.userName?.split(' ').first ?? 'Cliente'} 👋',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compacto ? 10 : 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _roundAction(
              size: actionSize,
              icon: Icons.notifications_none_rounded,
              onTap: () {
                if (widget.isGuest) {
                  _message('Inicia sesión para ver el estado de tus pedidos.');
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OrdersScreen()),
                  );
                }
              },
            ),
            const SizedBox(width: 7),
            Stack(
              clipBehavior: Clip.none,
              children: [
                _roundAction(
                  size: actionSize,
                  icon: Icons.shopping_cart_outlined,
                  onTap: _openCart,
                ),
                if (_cartCount > 0)
                  Positioned(
                    right: -2,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 19, minHeight: 19,
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_cartCount',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _roundAction({
    required IconData icon,
    required VoidCallback onTap,
    double size = 45,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: size < 42 ? 20 : 22, color: AppColors.ink),
        ),
      ),
    );
  }

  int get _descuentoMaximo {
    var mayor = 0;
    for (final producto in _productos) {
      final oferta = producto.precioOferta;
      if (oferta == null || producto.precio <= 0 || producto.stock <= 0) {
        continue;
      }
      final porcentaje =
          ((producto.precio - oferta) * 100 / producto.precio).round();
      if (porcentaje > mayor) mayor = porcentaje;
    }
    return mayor;
  }

  Widget _heroPanel() {
    final descuento = _descuentoMaximo;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compacto = constraints.maxWidth < 420;
        return Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.navy, Color(0xFF1D3260)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: .16),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -32,
                child: Container(
                  width: 195,
                  height: 195,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: .11),
                  ),
                ),
              ),
              Positioned(
                right: compacto ? -70 : 6,
                bottom: compacto ? -8 : -22,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: compacto ? .16 : .42,
                    child: Image.asset(
                      'assets/imagenes/01_kit_transmision_dtiex.png',
                      width: compacto ? 180 : 205,
                      height: compacto ? 180 : 205,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.two_wheeler_rounded,
                        size: 110,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compacto ? 18 : 23, 23, compacto ? 18 : 24, 22,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: compacto ? double.infinity : 545,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 11, vertical: 7,
                          ),
                          child: Text(
                            'CALIDAD • STOCK • CONFIANZA',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .35,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Todo para tu moto\nen un solo lugar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compacto ? 26 : 30,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 9),
                      const Text(
                        'Repuestos para motocicleta y motokar con precios, '
                        'stock y compatibilidad actualizados.',
                        style: TextStyle(
                          color: Colors.white70, fontSize: 12, height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 17),
                      Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: () => setState(() {
                              _search = '';
                              _searchController.clear();
                              _category = 'Todos';
                              _page = 1;
                            }),
                            icon: const Icon(Icons.storefront_outlined, size: 17),
                            label: const Text('Ver catálogo'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.ink,
                              minimumSize: const Size(0, 46),
                            ),
                          ),
                          if (descuento > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_offer_outlined,
                                      size: 16, color: AppColors.gold),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Hasta $descuento% de ahorro',
                                    style: const TextStyle(
                                      color: Colors.white, fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_productos.isNotEmpty)
                            Text(
                              '${_productos.length} productos disponibles en catálogo',
                              style: const TextStyle(
                                color: Colors.white70, fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _searchBox({required bool submitToProducts}) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: .035),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _search = value),
              onSubmitted: (value) => setState(() {
                _search = value.trim();
                _page = 1;
              }),
              decoration: InputDecoration(
                hintText: 'Buscar repuestos, marcas...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: submitToProducts
                    ? IconButton(
                        tooltip: 'Buscar en catálogo',
                        icon: const Icon(Icons.arrow_forward_rounded),
                        onPressed: () => setState(() => _page = 1),
                      )
                    : (_search.isNotEmpty
                        ? IconButton(
                            tooltip: 'Limpiar búsqueda',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() {
                              _search = '';
                              _searchController.clear();
                            }),
                          )
                        : null),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 54,
          height: 54,
          child: FilledButton(
            onPressed: _openFilters,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.ink,
              padding: EdgeInsets.zero,
            ),
            child: const Icon(Icons.tune_rounded),
          ),
        ),
      ],
    );
  }

  Widget _benefitsStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: const Row(
        children: [
          _Benefit(icon: Icons.verified_outlined, title: 'Calidad', subtitle: 'Marcas confiables'),
          _VerticalDivider(),
          _Benefit(icon: Icons.inventory_2_outlined, title: 'Stock', subtitle: 'Disponibilidad'),
          _VerticalDivider(),
          _Benefit(icon: Icons.support_agent_outlined, title: 'Soporte', subtitle: 'Compra fácil'),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String action, VoidCallback onTap) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
        TextButton(onPressed: onTap, child: Row(mainAxisSize: MainAxisSize.min, children: [Text(action), const SizedBox(width: 2), const Icon(Icons.arrow_forward_rounded, size: 16)])),
      ],
    );
  }

  Widget _productsPage() {
    final products = _filteredProducts;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Catálogo', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900)),
                    SizedBox(height: 2),
                    Text('Encuentra el repuesto ideal para tu vehículo.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _roundAction(icon: Icons.shopping_cart_outlined, onTap: _openCart),
                  if (_cartCount > 0)
                    Positioned(right: -2, top: -4, child: CircleAvatar(radius: 10, backgroundColor: AppColors.gold, child: Text('$_cartCount', style: const TextStyle(fontSize: 8, color: AppColors.ink, fontWeight: FontWeight.w900)))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          _searchBox(submitToProducts: false),
          const SizedBox(height: 12),
          if (_category != 'Todos' || _brand != 'Todas' || _vehicle != 'Todos')
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_category != 'Todos') Chip(label: Text(_category), onDeleted: () => setState(() => _category = 'Todos')),
                if (_brand != 'Todas') Chip(label: Text(_brand), onDeleted: () => setState(() => _brand = 'Todas')),
                if (_vehicle != 'Todos') Chip(label: Text(_vehicle), onDeleted: () => setState(() => _vehicle = 'Todos')),
              ],
            ),
          const SizedBox(height: 15),
          if (_cargandoProductosApi)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: _CatalogLoadingCard(),
            )
          else if (_errorProductosApi != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sin conexión con la API. Revisa Apache y MySQL.',
                      style: const TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ),
                  TextButton(onPressed: _loadCatalogoApi, child: const Text('Reintentar')),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.cloud_done_rounded, size: 16, color: AppColors.success),
                  SizedBox(width: 6),
                  Text(
                    'Catálogo consultado desde PHP + MySQL',
                    style: TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Text('${products.length} producto${products.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink)),
              const Spacer(),
              IconButton(
                tooltip: 'Actualizar productos desde MySQL',
                onPressed: _cargandoProductosApi ? null : _loadCatalogoApi,
                icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.muted),
              ),
              const Text('Catálogo activo', style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                avatar: Icon(
                  Icons.inventory_2_outlined,
                  size: 17,
                  color: _soloDisponibles ? AppColors.goldDark : AppColors.muted,
                ),
                label: const Text('Solo disponibles'),
                selected: _soloDisponibles,
                onSelected: (valor) => setState(() => _soloDisponibles = valor),
              ),
              DropdownButton<String>(
                value: _ordenCatalogo,
                borderRadius: BorderRadius.circular(16),
                underline: const SizedBox.shrink(),
                icon: const Icon(Icons.sort_rounded, size: 18),
                items: const [
                  DropdownMenuItem(value: 'Relevancia', child: Text('Orden: Relevancia')),
                  DropdownMenuItem(value: 'Menor precio', child: Text('Menor precio')),
                  DropdownMenuItem(value: 'Mayor precio', child: Text('Mayor precio')),
                  DropdownMenuItem(value: 'Nombre A-Z', child: Text('Nombre A-Z')),
                ],
                onChanged: (valor) {
                  if (valor != null) setState(() => _ordenCatalogo = valor);
                },
              ),
              if (_search.isNotEmpty ||
                  _category != 'Todos' ||
                  _brand != 'Todas' ||
                  _vehicle != 'Todos' ||
                  _soloDisponibles ||
                  _ordenCatalogo != 'Relevancia')
                TextButton.icon(
                  onPressed: _limpiarBusquedaYFiltros,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
                  label: const Text('Limpiar filtros'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            Column(
              children: [
                const _EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No encontramos productos',
                  text: 'Prueba otra búsqueda, revisa la compatibilidad o limpia los filtros.',
                ),
                TextButton.icon(
                  onPressed: _limpiarBusquedaYFiltros,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Mostrar todo el catálogo'),
                ),
              ],
            )
          else
            _productGrid(products),
        ],
      ),
    );
  }

  Widget _favoritesPage() {
    if (widget.isGuest) {
      return _accountRequiredPage(
        icon: Icons.favorite_border_rounded,
        title: 'Guarda tus favoritos',
        text: 'Inicia sesión para guardar repuestos y encontrarlos rápidamente después.',
      );
    }
    final products = _productos.where((p) => _favorites.contains(p.id)).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mis favoritos', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${products.length} producto${products.length == 1 ? '' : 's'} guardado${products.length == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          Expanded(
            child: products.isEmpty
                ? const _EmptyState(icon: Icons.favorite_border_rounded, title: 'Todavía no tienes favoritos', text: 'Toca el corazón de un producto para guardarlo aquí.')
                : SingleChildScrollView(child: _productGrid(products)),
          ),
        ],
      ),
    );
  }

  Widget _profilePage() {
    if (widget.isGuest) {
      return _accountRequiredPage(
        icon: Icons.person_outline_rounded,
        title: 'Tu cuenta Dorada Motors',
        text: 'Inicia sesión para acceder a pedidos, datos y opciones personales.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 100),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navySoft]),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: .16), blurRadius: 22, offset: const Offset(0, 10))],
            ),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), shape: BoxShape.circle, border: Border.all(color: AppColors.gold.withValues(alpha: .5), width: 2)),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 39),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MI CUENTA', style: TextStyle(fontSize: 9, letterSpacing: 1, color: AppColors.gold, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(widget.userName ?? 'Cliente', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 3),
                      Text(widget.userEmail ?? '', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _profileOption(Icons.person_outline_rounded, 'Mis datos', 'Edita tu perfil y contraseña', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => CuentaScreen(onUpdated: widget.onProfileUpdated)));
          }),
          _profileOption(Icons.receipt_long_outlined, 'Mis pedidos', 'Revisa compras, totales y estados', () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
            if (mounted) _loadCatalogoApi();
          }),
          _profileOption(Icons.location_on_outlined, 'Direcciones', 'Administra tus direcciones de entrega', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const DireccionesScreen()));
          }),
          _profileOption(Icons.help_outline_rounded, 'Ayuda y soporte', 'Envía consultas y revisa sus respuestas', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SoporteScreen()));
          }),
          _profileOption(Icons.settings_outlined, 'Configuración', 'Configura la conexión con el servidor PHP', _configurarConexion),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesión'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileOption(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AppColors.goldDark)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountRequiredPage({required IconData icon, required String title, required String text}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppColors.border)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 88, height: 88, decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle), child: Icon(icon, size: 44, color: AppColors.goldDark)),
                const SizedBox(height: 18),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.45)),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: widget.onLoginRequested, icon: const Icon(Icons.login_rounded), label: const Text('Iniciar sesión / Registrarme'))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _productGrid(List<Producto> products) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        // En teléfonos estrechos, dos columnas recortaban nombres y precios.
        // Se conserva la tarjeta original y se adapta únicamente su distribución.
        final columnas = ancho >= 1180
            ? 4
            : ancho >= 770
                ? 3
                : ancho >= 390
                    ? 2
                    : 1;
        return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnas,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: columnas == 1
            ? 390
            : columnas == 2
                ? 360
                : 385,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        return RevealOnMount(
          delay: Duration(milliseconds: (index % 8) * 42),
          duration: const Duration(milliseconds: 360),
          beginOffset: const Offset(0, .035),
          child: ProductCard(
            product: product,
            favorite: _favorites.contains(product.id),
            onTap: () => _openProduct(product),
            onFavorite: () => _toggleFavorite(product.id),
            onAddCart: () => _addCart(product.id),
          ),
        );
      },
        );
      },
    );
  }
}

class _CatalogLoadingCard extends StatefulWidget {
  const _CatalogLoadingCard();

  @override
  State<_CatalogLoadingCard> createState() => _CatalogLoadingCardState();
}

class _CatalogLoadingCardState extends State<_CatalogLoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final opacity = .45 + (.35 * (1 - (2 * t - 1).abs()));
        return Opacity(
          opacity: opacity,
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E9EF),
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 11,
                      width: 170,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6E9EF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 9,
                      width: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF0F4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Benefit({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.goldDark, size: 21),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 1),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 38, color: AppColors.border);
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _EmptyState({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 70),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 82, height: 82, decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle), child: Icon(icon, size: 39, color: AppColors.goldDark)),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _CartEmpty extends StatelessWidget {
  const _CartEmpty();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(icon: Icons.shopping_cart_outlined, title: 'Tu carrito está vacío', text: 'Agrega productos desde el catálogo para continuar con tu compra.');
  }
}
