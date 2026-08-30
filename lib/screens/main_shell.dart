import 'package:flutter/material.dart';

import '../data/productos_data.dart';
import '../models/producto.dart';
import '../services/local_store.dart';
import '../widgets/product_card.dart';
import 'checkout_screen.dart';
import 'orders_screen.dart';

class MainShell extends StatefulWidget {
  final bool isGuest;
  final String? userName;
  final String? userEmail;
  final VoidCallback onLoginRequested;
  final VoidCallback onLogout;

  const MainShell({
    super.key,
    required this.isGuest,
    this.userName,
    this.userEmail,
    required this.onLoginRequested,
    required this.onLogout,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _page = 0;
  String _search = '';
  String _category = 'Todos';
  String _brand = 'Todas';
  String _vehicle = 'Todos';
  Set<int> _favorites = {};
  Map<int, int> _cart = {};

  final _categories = const [
    ['Motor', Icons.settings],
    ['Frenos', Icons.album_outlined],
    ['Llantas', Icons.tire_repair],
    ['Luces', Icons.lightbulb_outline],
    ['Aceites', Icons.water_drop_outlined],
    ['Eléctrico', Icons.bolt_outlined],
    ['Suspensión', Icons.swap_vert_circle_outlined],
    ['Accesorios', Icons.extension_outlined],
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    final favorites = await LocalStore.getFavorites();
    final cart = await LocalStore.getCart();
    if (!mounted) return;
    setState(() {
      _favorites = favorites;
      _cart = cart;
    });
  }

  Producto _productById(int id) => productosData.firstWhere((p) => p.id == id);

  Future<void> _toggleFavorite(int id) async {
    if (widget.isGuest) {
      _requireAccount('Inicia sesión para guardar productos en Favoritos.');
      return;
    }
    setState(() {
      _favorites.contains(id) ? _favorites.remove(id) : _favorites.add(id);
    });
    await LocalStore.saveFavorites(_favorites);
  }

  Future<void> _addCart(int id) async {
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
    setState(() => _cart[id] = current + 1);
    await LocalStore.saveCart(_cart);
    if (mounted) _message('${product.nombre} agregado al carrito.');
  }

  Future<void> _changeQty(int id, int delta, [VoidCallback? modalRefresh]) async {
    final product = _productById(id);
    final current = _cart[id] ?? 0;
    final next = current + delta;
    if (next <= 0) {
      _cart.remove(id);
    } else if (next <= product.stock) {
      _cart[id] = next;
    } else {
      _message('Stock máximo disponible: ${product.stock}.');
      return;
    }
    setState(() {});
    modalRefresh?.call();
    await LocalStore.saveCart(_cart);
  }

  int get _cartCount => _cart.values.fold(0, (a, b) => a + b);

  double get _cartTotal {
    double total = 0;
    _cart.forEach((id, qty) => total += _productById(id).precioFinal * qty);
    return total;
  }

  List<Producto> get _filteredProducts {
    final text = _search.trim().toLowerCase();
    return productosData.where((p) {
      final searchOk = text.isEmpty ||
          p.nombre.toLowerCase().contains(text) ||
          p.marca.toLowerCase().contains(text) ||
          p.descripcion.toLowerCase().contains(text);
      final categoryOk = _category == 'Todos' || p.categoria == _category;
      final brandOk = _brand == 'Todas' || p.marca == _brand;
      final vehicleOk = _vehicle == 'Todos' || p.tipoVehiculo.contains(_vehicle);
      return searchOk && categoryOk && brandOk && vehicleOk;
    }).toList();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

  void _requireAccount(String text) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_outline, size: 42),
        title: const Text('Cuenta requerida'),
        content: Text(text, textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ahora no')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
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
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) {
          final isFavorite = _favorites.contains(product.id);
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .88),
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
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
                    SizedBox(
                      height: 250,
                      width: double.infinity,
                      child: Image.asset(product.imagen, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(product.nombre, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                        ),
                        IconButton(
                          onPressed: () async {
                            await _toggleFavorite(product.id);
                            if (mounted) refresh(() {});
                          },
                          icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.black87),
                        ),
                      ],
                    ),
                    Text(product.marca, style: const TextStyle(color: Color(0xFFD6A715), fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Text(product.descripcion, style: const TextStyle(color: Color(0xFF4B5563), height: 1.5)),
                    const SizedBox(height: 18),
                    _detailRow(Icons.two_wheeler_outlined, 'Vehículo', product.tipoVehiculo),
                    _detailRow(Icons.build_outlined, 'Compatibilidad', product.compatibilidad),
                    _detailRow(Icons.inventory_2_outlined, 'Stock', product.disponible ? '${product.stock} unidades' : 'Agotado'),
                    const Divider(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.precioOferta != null)
                                Text(
                                  'S/ ${product.precio.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.black45, decoration: TextDecoration.lineThrough),
                                ),
                              Text(
                                'S/ ${product.precioFinal.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Color(0xFFD6A715)),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: product.disponible
                              ? () async {
                                  await _addCart(product.id);
                                  if (context.mounted) Navigator.pop(context);
                                }
                              : null,
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111827)),
                          icon: const Icon(Icons.shopping_cart_outlined),
                          label: const Text('Agregar'),
                        ),
                      ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFFD6A715)),
          const SizedBox(width: 10),
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
          Expanded(child: Text(value, style: const TextStyle(color: Color(0xFF4B5563)))),
        ],
      ),
    );
  }

  Future<void> _openCart() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .82),
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Mi carrito', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900))),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_cart.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.black26),
                            SizedBox(height: 12),
                            Text('Tu carrito está vacío', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: _cart.entries.map((entry) {
                          final p = _productById(entry.key);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(18)),
                            child: Row(
                              children: [
                                SizedBox(width: 70, height: 70, child: Image.asset(p.imagen, fit: BoxFit.contain)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 4),
                                      Text('S/ ${p.precioFinal.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFD6A715), fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _changeQty(p.id, -1, () => refresh(() {})),
                                      icon: const Icon(Icons.remove_circle_outline),
                                    ),
                                    Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _changeQty(p.id, 1, () => refresh(() {})),
                                      icon: const Icon(Icons.add_circle_outline),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  if (_cart.isNotEmpty) ...[
                    const Divider(),
                    Row(
                      children: [
                        const Expanded(child: Text('Total', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                        Text('S/ ${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Color(0xFFD6A715))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111827)),
                        onPressed: () {
                          Navigator.pop(context);
                          if (widget.isGuest) {
                            _requireAccount('Inicia sesión para confirmar tu compra y guardar el pedido.');
                            return;
                          }
                          Navigator.of(this.context).push(
                            MaterialPageRoute(
                              builder: (_) => CheckoutScreen(
                                cart: Map<int, int>.from(_cart),
                                products: productosData,
                                onCompleted: () {
                                  setState(() => _cart.clear());
                                },
                              ),
                            ),
                          );
                        },
                        child: const Text('Continuar compra', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openFilters() async {
    final brands = ['Todas', ...{for (final p in productosData) p.marca}];
    String tempCategory = _category;
    String tempBrand = _brand;
    String tempVehicle = _vehicle;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filtrar productos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 18),
                const Text('Categoría', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: ['Todos', ..._categories.map((e) => e[0] as String)].map((value) {
                    return ChoiceChip(
                      label: Text(value),
                      selected: tempCategory == value,
                      onSelected: (_) => refresh(() => tempCategory = value),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Marca', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: brands.map((value) {
                    return ChoiceChip(
                      label: Text(value),
                      selected: tempBrand == value,
                      onSelected: (_) => refresh(() => tempBrand = value),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Vehículo', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  children: ['Todos', 'Motocicleta', 'Motokar'].map((value) {
                    return ChoiceChip(
                      label: Text(value),
                      selected: tempVehicle == value,
                      onSelected: (_) => refresh(() => tempVehicle = value),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
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
                          Navigator.pop(context);
                        },
                        child: const Text('Aplicar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(child: _selectedPage()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _page,
        indicatorColor: const Color(0xFFFFEDB0),
        onDestinationSelected: (index) => setState(() => _page = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Productos'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Favoritos'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 28),
          const Text('Todo para tu moto\nen un solo lugar', style: TextStyle(fontSize: 30, height: 1.1, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Repuestos para motocicletas y motokar con información de stock y compatibilidad.', style: TextStyle(color: Color(0xFF6B7280), height: 1.4)),
          const SizedBox(height: 20),
          _searchBox(submitToProducts: true),
          const SizedBox(height: 22),
          _offerBanner(),
          const SizedBox(height: 28),
          _sectionHeader('Categorías', 'Ver todas', () {
            setState(() {
              _category = 'Todos';
              _page = 1;
            });
          }),
          const SizedBox(height: 12),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = _categories[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() {
                    _category = item[0] as String;
                    _page = 1;
                  }),
                  child: Container(
                    width: 94,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(color: const Color(0xFFFFF3C6), borderRadius: BorderRadius.circular(14)),
                          child: Icon(item[1] as IconData, color: const Color(0xFFD6A715)),
                        ),
                        const SizedBox(height: 7),
                        Text(item[0] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          _sectionHeader('Productos destacados', 'Ver más', () {
            setState(() {
              _category = 'Todos';
              _page = 1;
            });
          }),
          const SizedBox(height: 12),
          _productGrid(productosData.take(4).toList()),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset('assets/imagenes/logo_adn_imports.png', width: 64, height: 64, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DORADA MOTORS', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              SizedBox(height: 3),
              Text('ADN Import\'s • Moto y Motokar', style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Notificaciones',
          onPressed: () {
            if (widget.isGuest) {
              _message('Inicia sesión para ver el estado de tus pedidos.');
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
            }
          },
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(tooltip: 'Carrito', onPressed: _openCart, icon: const Icon(Icons.shopping_cart_outlined)),
            if (_cartCount > 0)
              Positioned(
                right: 2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(color: Color(0xFFE1B329), shape: BoxShape.circle),
                  child: Text('$_cartCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _searchBox({required bool submitToProducts}) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: submitToProducts ? null : (value) => setState(() => _search = value),
            onSubmitted: submitToProducts
                ? (value) => setState(() {
                      _search = value;
                      _page = 1;
                    })
                : null,
            decoration: InputDecoration(
              hintText: 'Buscar repuestos, marcas...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 56,
          height: 56,
          child: FilledButton(
            onPressed: _openFilters,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE1B329), padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
            child: const Icon(Icons.tune_rounded),
          ),
        ),
      ],
    );
  }

  Widget _offerBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF101A36), Color(0xFF1E316A)]),
        borderRadius: BorderRadius.circular(27),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('OFERTA ESPECIAL', style: TextStyle(color: Color(0xFFE1B329), fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                const Text('Hasta 25% OFF', style: TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('En repuestos seleccionados.', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                  onPressed: () => setState(() {
                    _category = 'Todos';
                    _page = 1;
                  }),
                  child: const Text('Comprar ahora'),
                ),
              ],
            ),
          ),
          const Icon(Icons.two_wheeler, size: 70, color: Color(0xFFE1B329)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String action, VoidCallback onTap) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
        TextButton(onPressed: onTap, child: Text(action, style: const TextStyle(color: Color(0xFFD6A715)))),
      ],
    );
  }

  Widget _productsPage() {
    final products = _filteredProducts;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Productos', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(onPressed: _openCart, icon: const Icon(Icons.shopping_cart_outlined)),
                  if (_cartCount > 0)
                    Positioned(right: 1, top: -2, child: CircleAvatar(radius: 9, backgroundColor: const Color(0xFFE1B329), child: Text('$_cartCount', style: const TextStyle(fontSize: 8, color: Colors.white)))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
          Text('${products.length} producto${products.length == 1 ? '' : 's'} encontrado${products.length == 1 ? '' : 's'}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: Text('No encontramos productos con esos filtros.', style: TextStyle(fontSize: 17, color: Colors.black54))),
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
        icon: Icons.favorite_border,
        title: 'Tus favoritos estarán aquí',
        text: 'Inicia sesión para guardar tus repuestos favoritos.',
      );
    }
    final products = productosData.where((p) => _favorites.contains(p.id)).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mis favoritos', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          Expanded(
            child: products.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_border, size: 72, color: Colors.black26),
                        SizedBox(height: 12),
                        Text('Todavía no tienes favoritos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  )
                : SingleChildScrollView(child: _productGrid(products)),
          ),
        ],
      ),
    );
  }

  Widget _profilePage() {
    if (widget.isGuest) {
      return _accountRequiredPage(
        icon: Icons.person_outline,
        title: 'Inicia sesión',
        text: 'Accede a tus pedidos, datos y opciones de cuenta.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 100),
      child: Column(
        children: [
          const CircleAvatar(radius: 50, backgroundColor: Color(0xFF111827), child: Icon(Icons.person, color: Colors.white, size: 56)),
          const SizedBox(height: 14),
          Text(widget.userName ?? 'Cliente', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(widget.userEmail ?? '', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 28),
          _profileOption(Icons.receipt_long_outlined, 'Mis pedidos', 'Revisa compras y estados', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
          }),
          _profileOption(Icons.location_on_outlined, 'Direcciones', 'La dirección se registra al pedir delivery', () {
            _message('Puedes registrar la dirección al finalizar una compra con Delivery.');
          }),
          _profileOption(Icons.help_outline, 'Ayuda', 'Preguntas y soporte', () {
            showAboutDialog(
              context: context,
              applicationName: 'Dorada Motors',
              applicationVersion: '1.0.0',
              children: const [Text('Aplicación de ADN Import\'s para consultar y comprar repuestos de motocicletas y motokar.')],
            );
          }),
          _profileOption(Icons.settings_outlined, 'Configuración', 'Preferencias de la aplicación', () {
            _message('Configuración lista para futuras preferencias.');
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () async {
                await LocalStore.logout();
                widget.onLogout();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileOption(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: const Color(0xFFFFF3C6), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: const Color(0xFFD6A715)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 15),
          ],
        ),
      ),
    );
  }

  Widget _accountRequiredPage({required IconData icon, required String title, required String text}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 76, color: Colors.black26),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 20),
            FilledButton(onPressed: widget.onLoginRequested, child: const Text('Iniciar sesión / Registrarme')),
          ],
        ),
      ),
    );
  }

  Widget _productGrid(List<Producto> products) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: .64,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          favorite: _favorites.contains(product.id),
          onTap: () => _openProduct(product),
          onFavorite: () => _toggleFavorite(product.id),
          onAddCart: () => _addCart(product.id),
        );
      },
    );
  }
}
